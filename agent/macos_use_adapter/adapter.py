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
    warnings: list[str]
    recovery_guidance: str | None = None


@dataclass
class ProviderValidationResult:
    valid: bool
    reason: str | None = None
    account_hint: str | None = None


class ProviderConfigurationError(RuntimeError):
    def __init__(self, message: str, *, status_code: int, error_code: str) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.error_code = error_code


class MacOSUseAdapter:
    """
    Adapter boundary for vendored macOS-use.

    This layer reuses upstream prompt primitives (SystemPrompt) and provides a
    deterministic fallback plan when provider output is unparsable.
    """

    def __init__(self) -> None:
        self._vendor_loaded = False
        self._important_rules = ""
        self._load_vendor_prompt_rules()

    _allowed_action_kinds = {
        "click",
        "type",
        "key_combo",
        "scroll",
        "open_app",
        "run_applescript",
        "select_menu_item",
        "wait",
    }

    @property
    def provider_name(self) -> str:
        return "anthropic"

    def current_api_key(self) -> str | None:
        return settings.provider_api_key()

    async def validate_provider_key(self, api_key: str) -> ProviderValidationResult:
        key = api_key.strip()
        if not key:
            return ProviderValidationResult(valid=False, reason="API key is empty")
        if not key.startswith("sk-ant-"):
            return ProviderValidationResult(valid=False, reason="API key format is invalid")

        if not settings.enable_remote_llm:
            return ProviderValidationResult(valid=True, reason="Remote provider calls are disabled")

        url = f"{settings.anthropic_api_base.rstrip('/')}/v1/models"
        headers = {
            "x-api-key": key,
            "anthropic-version": "2023-06-01",
        }
        try:
            async with httpx.AsyncClient(timeout=12.0) as client:
                response = await client.get(url, headers=headers)
        except httpx.RequestError:
            return ProviderValidationResult(valid=False, reason="Network error while validating key")

        if response.status_code == 200:
            return ProviderValidationResult(
                valid=True,
                account_hint=f"Key accepted ({self._key_hint(key)})",
            )
        if response.status_code in {401, 403}:
            return ProviderValidationResult(valid=False, reason="API key is invalid or unauthorized")
        if response.status_code == 429:
            return ProviderValidationResult(
                valid=False,
                reason="API key is valid but quota/rate limit was exceeded",
                account_hint=self._key_hint(key),
            )
        if response.status_code >= 500:
            return ProviderValidationResult(valid=False, reason="Anthropic service is temporarily unavailable")

        return ProviderValidationResult(valid=False, reason=f"Provider rejected key ({response.status_code})")

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
        if not settings.enable_remote_llm:
            return self._deterministic_plan(transcript=transcript, app_name=active_app_name, warnings=["Remote planner disabled"])

        key = self.current_api_key()
        if not key:
            raise ProviderConfigurationError(
                "Anthropic API key not configured. Please add your key in Orange settings.",
                status_code=400,
                error_code="missing_api_key",
            )
        if not key.startswith("sk-ant-"):
            raise ProviderConfigurationError(
                "Anthropic API key format is invalid.",
                status_code=401,
                error_code="invalid_api_key_format",
            )

        return await self._plan_with_anthropic(
            transcript=transcript,
            active_app_name=active_app_name,
            ax_tree_summary=_ax_tree_summary,
            api_key=key,
        )

    async def _plan_with_anthropic(
        self,
        *,
        transcript: str,
        active_app_name: str | None,
        ax_tree_summary: str | None,
        api_key: str,
    ) -> AdapterResult:
        model = self._select_model(transcript, active_app_name=active_app_name)
        prompt = self._build_provider_prompt(
            transcript=transcript,
            active_app_name=active_app_name,
            ax_tree_summary=ax_tree_summary,
        )

        payload: dict[str, Any] = {
            "model": model,
            "temperature": 0,
            "max_tokens": 900,
            "system": "You are Orange planner. Return only valid JSON. Do not include markdown.",
            "messages": [
                {"role": "user", "content": prompt},
            ],
        }

        url = f"{settings.anthropic_api_base.rstrip('/')}/v1/messages"
        headers = {
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        }

        try:
            async with httpx.AsyncClient(timeout=24.0) as client:
                response = await client.post(url, headers=headers, json=payload)
        except httpx.RequestError as exc:
            raise ProviderConfigurationError(
                f"Network error while contacting Anthropic: {exc.__class__.__name__}",
                status_code=503,
                error_code="provider_network_error",
            ) from exc

        if response.status_code in {401, 403}:
            raise ProviderConfigurationError(
                "Anthropic API key is invalid or unauthorized.",
                status_code=401,
                error_code="invalid_api_key",
            )
        if response.status_code == 429:
            raise ProviderConfigurationError(
                "Anthropic quota or rate limit exceeded.",
                status_code=429,
                error_code="provider_quota_exceeded",
            )
        if response.status_code >= 500:
            raise ProviderConfigurationError(
                "Anthropic service is temporarily unavailable.",
                status_code=503,
                error_code="provider_unavailable",
            )
        if response.status_code >= 300:
            raise ProviderConfigurationError(
                f"Anthropic returned unexpected status {response.status_code}.",
                status_code=502,
                error_code="provider_bad_response",
            )

        body = response.json()
        content_text = self._extract_text_content(body)
        if not content_text:
            return self._deterministic_plan(
                transcript=transcript,
                app_name=active_app_name,
                warnings=["Provider returned empty content"],
            )

        parsed_payload = self._extract_json_payload(content_text)
        if parsed_payload is None:
            return self._deterministic_plan(
                transcript=transcript,
                app_name=active_app_name,
                warnings=["Provider response was not valid JSON"],
            )

        actions, warnings = self._coerce_actions(parsed_payload.get("actions", []))
        if not actions:
            warnings = warnings or ["Provider returned no valid actions"]
            return AdapterResult(
                actions=[
                    Action(
                        id="a1",
                        kind="wait",
                        timeout_ms=1000,
                        expected_outcome="Awaiting user clarification",
                    )
                ],
                confidence=0.2,
                summary="Unable to parse safe actions from planner output",
                warnings=warnings,
                recovery_guidance="Try a shorter command or mention the app and target explicitly.",
            )

        confidence = self._clamp_confidence(parsed_payload.get("confidence"))
        summary = str(parsed_payload.get("summary") or "Anthropic generated plan")
        return AdapterResult(actions=actions, confidence=confidence, summary=summary, warnings=warnings)

    def _extract_text_content(self, payload: dict[str, Any]) -> str | None:
        content = payload.get("content")
        if not isinstance(content, list):
            return None
        parts: list[str] = []
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text" and isinstance(block.get("text"), str):
                parts.append(block["text"])
        joined = "\n".join(parts).strip()
        return joined or None

    def _extract_json_payload(self, text: str) -> dict[str, Any] | None:
        stripped = text.strip()
        try:
            parsed = json.loads(stripped)
            if isinstance(parsed, dict):
                return parsed
        except json.JSONDecodeError:
            pass

        match = re.search(r"\{[\s\S]*\}", stripped)
        if not match:
            return None
        try:
            parsed = json.loads(match.group(0))
            if isinstance(parsed, dict):
                return parsed
        except json.JSONDecodeError:
            return None
        return None

    def _coerce_actions(self, raw_actions: list[dict[str, Any]]) -> tuple[list[Action], list[str]]:
        actions: list[Action] = []
        warnings: list[str] = []
        for idx, raw in enumerate(raw_actions, start=1):
            if not isinstance(raw, dict):
                warnings.append(f"Action #{idx} is not an object")
                continue
            kind = str(raw.get("kind") or "").strip()
            if kind not in self._allowed_action_kinds:
                warnings.append(f"Rejected unknown action kind '{kind or 'missing'}' at index {idx}")
                continue
            try:
                actions.append(
                    Action(
                        id=str(raw.get("id") or f"a{idx}"),
                        kind=kind,  # type: ignore[arg-type]
                        target=cast_optional_str(raw.get("target")),
                        text=cast_optional_str(raw.get("text")),
                        key_combo=cast_optional_str(raw.get("key_combo")),
                        app_bundle_id=cast_optional_str(raw.get("app_bundle_id")),
                        timeout_ms=cast_int(raw.get("timeout_ms"), default=3000),
                        destructive=bool(raw.get("destructive", False)),
                        expected_outcome=cast_optional_str(raw.get("expected_outcome")),
                    )
                )
            except Exception as exc:
                warnings.append(f"Rejected invalid action at index {idx}: {exc}")
                continue
        return actions, warnings

    def _build_provider_prompt(
        self,
        *,
        transcript: str,
        active_app_name: str | None,
        ax_tree_summary: str | None,
    ) -> str:
        app_name = active_app_name or "Unknown"
        ax_preview = (ax_tree_summary or "")[:3500]
        app_pack = self._app_prompt_pack(app_name)
        vendor_rules = self._important_rules[:2400] if self._important_rules else ""
        return (
            "Plan safe macOS actions for this user request.\n"
            "Return strictly JSON with shape: "
            '{"summary":"...", "confidence":0.0-1.0, "actions":[{"id":"a1","kind":"open_app|click|type|key_combo|scroll|run_applescript|select_menu_item|wait","target":null,"text":null,"key_combo":null,"app_bundle_id":null,"timeout_ms":3000,"destructive":false,"expected_outcome":null}]}\n'
            "Use the fewest actions needed.\n"
            f"Active app: {app_name}\n"
            f"User transcript: {transcript}\n"
            f"AX summary: {ax_preview}\n"
            f"App-specific guidance: {app_pack}\n"
            f"Safety rules excerpt: {vendor_rules}\n"
        )

    def _select_model(self, transcript: str, *, active_app_name: str | None) -> str:
        if active_app_name:
            override = settings.model_overrides.get(active_app_name.lower())
            if override:
                return override
        complexity_markers = [" and ", " then ", "after", "before", "reply", "send", "purchase"]
        lower = transcript.lower()
        is_complex = len(lower.split()) > 10 or any(marker in lower for marker in complexity_markers)
        return settings.model_complex if is_complex else settings.model_simple

    def _app_prompt_pack(self, app_name: str) -> str:
        key = app_name.lower()
        packs = {
            "mail": "Prefer semantic compose/reply flows; require confirmation before send.",
            "gmail": "Focus reply box detection and avoid pressing send without explicit user confirmation.",
            "slack": "Prioritize active thread composer; avoid posting to wrong channel.",
            "safari": "Use cmd+l for address bar and confirm page load target.",
            "google chrome": "Use cmd+l for omnibox and verify URL matches intent.",
            "finder": "Prefer menu actions for create/rename/move and avoid destructive operations by default.",
            "calendar": "Use event title/date/time verification before final save.",
        }
        return packs.get(key, "Use safest deterministic actions and avoid irreversible operations.")

    @staticmethod
    def _clamp_confidence(value: Any) -> float:
        try:
            confidence = float(value)
        except Exception:
            confidence = 0.7
        return max(0.0, min(1.0, confidence))

    def _deterministic_plan(self, *, transcript: str, app_name: str | None, warnings: list[str]) -> AdapterResult:
        text = transcript.strip().lower()
        app_name = (app_name or "").strip()

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
                confidence=0.82,
                summary=f"Open {target}",
                warnings=warnings,
                recovery_guidance="Fell back to deterministic planner due to provider output issues.",
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
                confidence=0.75,
                summary=f"Navigate to {url}",
                warnings=warnings,
                recovery_guidance="Fell back to deterministic planner due to provider output issues.",
            )

        return AdapterResult(
            actions=[
                Action(
                    id="a1",
                    kind="type",
                    text=transcript,
                    expected_outcome="Transcript typed in focused input",
                )
            ],
            confidence=0.55,
            summary="Type transcript in focused field",
            warnings=warnings,
            recovery_guidance="Fell back to deterministic planner due to provider output issues.",
        )

    @staticmethod
    def _key_hint(key: str) -> str:
        tail = key[-4:] if len(key) >= 4 else "****"
        return f"••••{tail}"

    @property
    def vendor_loaded(self) -> bool:
        return self._vendor_loaded

    @property
    def vendor_rules(self) -> str:
        return self._important_rules



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
