from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
import json
from pathlib import Path
import re
import sys
from typing import Any

import httpx
from core.config import settings
from core.schemas import Action


@dataclass
class AdapterResult:
    actions: list[Action]
    confidence: float
    summary: str


class MacOSUseAdapter:
    """
    Adapter boundary for vendored macOS-use.

    For now this layer reuses upstream prompt primitives (SystemPrompt) and
    provides deterministic action planning heuristics as a safe baseline.
    """

    def __init__(self) -> None:
        self._vendor_loaded = False
        self._important_rules = ""
        self._load_vendor_prompt_rules()

    def _load_vendor_prompt_rules(self) -> None:
        vendor_path = settings.vendor_macos_use
        if not vendor_path.exists():
            return

        sys.path.insert(0, str(vendor_path))
        try:
            from mlx_use.agent.prompts import SystemPrompt  # type: ignore

            prompt = SystemPrompt(
                action_description=(
                    "open_app, click, type, key_combo, scroll, run_applescript, select_menu_item, wait"
                ),
                current_date=datetime.now(),
                max_actions_per_step=4,
            )
            self._important_rules = prompt.important_rules()
            self._vendor_loaded = True
        except Exception:
            self._important_rules = self._load_rules_from_source(vendor_path)
            self._vendor_loaded = bool(self._important_rules)
        finally:
            if str(vendor_path) in sys.path:
                sys.path.remove(str(vendor_path))

    @staticmethod
    def _load_rules_from_source(vendor_path: Path) -> str:
        """
        Parse upstream prompts.py as a dependency-light fallback.

        This keeps Orange aligned with macOS-use guidance even when optional
        upstream runtime dependencies are unavailable in local environments.
        """
        prompt_file = vendor_path / "mlx_use" / "agent" / "prompts.py"
        if not prompt_file.exists():
            return ""

        content = prompt_file.read_text(encoding="utf-8")
        match = re.search(
            r"def important_rules\\(self\\) -> str:\\n\\s+\"\"\".*?\"\"\"\\n\\s+text = \"\"\"(.*?)\"\"\"",
            content,
            flags=re.DOTALL,
        )
        if not match:
            return ""
        return match.group(1).strip()

    async def plan_actions(
        self,
        *,
        transcript: str,
        active_app_name: str | None,
        _ax_tree_summary: str | None,
    ) -> AdapterResult:
        openai_result = await self._plan_with_openai(
            transcript=transcript,
            active_app_name=active_app_name,
            ax_tree_summary=_ax_tree_summary,
        )
        if openai_result is not None:
            return openai_result

        text = transcript.strip().lower()
        app_name = (active_app_name or "").strip()

        if text.startswith("open "):
            target = transcript.strip()[5:].strip()
            return AdapterResult(
                actions=[
                    Action(
                        id="a1",
                        kind="open_app",
                        target=target,
                        expected_outcome=f"{target} is frontmost",
                    )
                ],
                confidence=0.92,
                summary=f"Open {target}",
            )

        url_match = re.search(r"(https?://\S+|\b\w+\.com\b)", text)
        if "go to" in text and url_match:
            raw_url = url_match.group(1)
            url = raw_url if raw_url.startswith("http") else f"https://{raw_url}"
            browser_target = app_name if app_name in {"Safari", "Google Chrome"} else "Safari"
            return AdapterResult(
                actions=[
                    Action(id="a1", kind="open_app", target=browser_target, expected_outcome="Browser opened"),
                    Action(id="a2", kind="key_combo", key_combo="cmd+l", expected_outcome="Address bar focused"),
                    Action(id="a3", kind="type", text=url, expected_outcome=f"URL entered: {url}"),
                    Action(id="a4", kind="key_combo", key_combo="enter", expected_outcome="Page loads"),
                ],
                confidence=0.86,
                summary=f"Navigate to {url}",
            )

        if "reply" in text and "slack" in text:
            response_text = self._extract_reply_text(transcript) or "I'll be there."
            return AdapterResult(
                actions=[
                    Action(id="a1", kind="click", target="Last message thread", expected_outcome="Thread selected"),
                    Action(id="a2", kind="click", target="Message composer", expected_outcome="Input focused"),
                    Action(id="a3", kind="type", text=response_text, expected_outcome="Reply text entered"),
                    Action(
                        id="a4",
                        kind="key_combo",
                        key_combo="enter",
                        destructive=True,
                        expected_outcome="Message sent",
                    ),
                ],
                confidence=0.78,
                summary="Reply in Slack thread",
            )

        # Safe default that keeps control deterministic and auditable.
        return AdapterResult(
            actions=[
                Action(
                    id="a1",
                    kind="type",
                    text=transcript,
                    expected_outcome="Transcript typed in focused input",
                )
            ],
            confidence=0.6,
            summary="Type transcript in focused field",
        )

    async def _plan_with_openai(
        self,
        *,
        transcript: str,
        active_app_name: str | None,
        ax_tree_summary: str | None,
    ) -> AdapterResult | None:
        if not settings.enable_remote_llm:
            return None

        api_key = settings_openai_api_key()
        if not api_key:
            return None

        model = self._select_model(transcript)
        prompt = self._build_openai_prompt(
            transcript=transcript,
            active_app_name=active_app_name,
            ax_tree_summary=ax_tree_summary,
        )
        payload: dict[str, Any] = {
            "model": model,
            "temperature": 0,
            "response_format": {"type": "json_object"},
            "messages": [
                {"role": "system", "content": "You are Orange planner. Return only valid JSON."},
                {"role": "user", "content": prompt},
            ],
        }

        try:
            async with httpx.AsyncClient(timeout=20.0) as client:
                response = await client.post(
                    "https://api.openai.com/v1/chat/completions",
                    headers={
                        "Authorization": f"Bearer {api_key}",
                        "Content-Type": "application/json",
                    },
                    json=payload,
                )
                if response.status_code >= 300:
                    return None

                body = response.json()
                content = body["choices"][0]["message"]["content"]
                if not isinstance(content, str):
                    return None
                parsed = json.loads(content)
                actions = self._coerce_actions(parsed.get("actions", []))
                if not actions:
                    return None

                confidence = self._clamp_confidence(parsed.get("confidence"))
                summary = str(parsed.get("summary") or "LLM generated plan")
                return AdapterResult(actions=actions, confidence=confidence, summary=summary)
        except Exception:
            return None

    def _coerce_actions(self, raw_actions: list[dict[str, Any]]) -> list[Action]:
        actions: list[Action] = []
        for idx, raw in enumerate(raw_actions, start=1):
            if not isinstance(raw, dict):
                continue
            try:
                actions.append(
                    Action(
                        id=str(raw.get("id") or f"a{idx}"),
                        kind=str(raw.get("kind") or "type"),
                        target=cast_optional_str(raw.get("target")),
                        text=cast_optional_str(raw.get("text")),
                        key_combo=cast_optional_str(raw.get("key_combo")),
                        app_bundle_id=cast_optional_str(raw.get("app_bundle_id")),
                        timeout_ms=cast_int(raw.get("timeout_ms"), default=3000),
                        destructive=bool(raw.get("destructive", False)),
                        expected_outcome=cast_optional_str(raw.get("expected_outcome")),
                    )
                )
            except Exception:
                continue
        return actions

    def _build_openai_prompt(
        self, *, transcript: str, active_app_name: str | None, ax_tree_summary: str | None
    ) -> str:
        app_name = active_app_name or "Unknown"
        ax_preview = (ax_tree_summary or "")[:3500]
        return (
            "Plan safe macOS actions for this user request.\n"
            "Return strictly JSON with shape: "
            '{"summary":"...", "confidence":0.0-1.0, "actions":[{"id":"a1","kind":"open_app|click|type|key_combo|scroll|run_applescript|select_menu_item|wait","target":null,"text":null,"key_combo":null,"app_bundle_id":null,"timeout_ms":3000,"destructive":false,"expected_outcome":null}]}\n'
            "Use the fewest actions needed.\n"
            f"Active app: {app_name}\n"
            f"User transcript: {transcript}\n"
            f"AX summary: {ax_preview}\n"
        )

    def _select_model(self, transcript: str) -> str:
        complexity_markers = [" and ", " then ", "after", "before", "reply", "send", "purchase"]
        lower = transcript.lower()
        is_complex = len(lower.split()) > 10 or any(marker in lower for marker in complexity_markers)
        return settings.model_complex if is_complex else settings.model_simple

    @staticmethod
    def _clamp_confidence(value: Any) -> float:
        try:
            confidence = float(value)
        except Exception:
            confidence = 0.7
        return max(0.0, min(1.0, confidence))

    @staticmethod
    def _extract_reply_text(transcript: str) -> str | None:
        patterns = [r"saying\s+(.+)$", r"reply\s+(.+)$"]
        for pattern in patterns:
            match = re.search(pattern, transcript, flags=re.IGNORECASE)
            if match:
                return match.group(1).strip().strip('"')
        return None

    @property
    def vendor_loaded(self) -> bool:
        return self._vendor_loaded

    @property
    def vendor_rules(self) -> str:
        return self._important_rules


def settings_openai_api_key() -> str | None:
    import os

    value = os.getenv("OPENAI_API_KEY", "").strip()
    return value or None


def cast_optional_str(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def cast_int(value: Any, *, default: int) -> int:
    try:
        return int(value)
    except Exception:
        return default
