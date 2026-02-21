from __future__ import annotations

from core.config import SCHEMA_VERSION_CURRENT, settings
from core.event_bus import EventBus
from core.schemas import (
    Action,
    ActionPlan,
    ModelInfo,
    ModelsResponse,
    ProviderStatusResponse,
    ProviderValidationRequest,
    ProviderValidationResponse,
    PlanRequest,
    PlanSimulationRequest,
    PlanSimulationResponse,
    StreamEvent,
)
from macos_use_adapter.adapter import MacOSUseAdapter


RISKY_ACTIONS = {"run_applescript"}
RISKY_KEY_COMBOS = {"enter"}
HIGH_RISK_TERMS = {"send", "delete", "purchase", "buy", "post", "submit"}


class PlannerService:
    def __init__(self, event_bus: EventBus, adapter: MacOSUseAdapter | None = None) -> None:
        self._event_bus = event_bus
        self._adapter = adapter or MacOSUseAdapter()

    async def plan(self, request: PlanRequest) -> ActionPlan:
        await self._event_bus.publish(
            StreamEvent(
                session_id=request.session_id,
                event="planning_started",
                message="Planning actions from transcript",
                progress=10,
                severity="info",
            )
        )

        adapter_result = await self._adapter.plan_actions(
            transcript=request.transcript,
            active_app_name=(request.app.name if request.app else None),
            _ax_tree_summary=request.ax_tree_summary,
        )

        for warning in getattr(adapter_result, "warnings", []):
            await self._event_bus.publish(
                StreamEvent(
                    session_id=request.session_id,
                    event="planning_warning",
                    message=warning,
                    progress=40,
                    severity="warning",
                )
            )

        await self._event_bus.publish(
            StreamEvent(
                session_id=request.session_id,
                event="planning_generated",
                message=f"Generated {len(adapter_result.actions)} actions",
                progress=65,
                severity="info",
            )
        )

        risk_level, requires_confirmation = self._compute_risk(adapter_result.actions, transcript=request.transcript)

        plan = ActionPlan(
            schema_version=SCHEMA_VERSION_CURRENT,
            session_id=request.session_id,
            actions=adapter_result.actions,
            confidence=adapter_result.confidence,
            risk_level=risk_level,
            requires_confirmation=requires_confirmation,
            summary=adapter_result.summary if not getattr(adapter_result, "recovery_guidance", None) else f"{adapter_result.summary}. {adapter_result.recovery_guidance}",
        )

        await self._event_bus.publish(
            StreamEvent(
                session_id=request.session_id,
                event="planning_completed",
                message="Plan ready",
                progress=100,
                severity="info",
            )
        )
        return plan

    async def simulate(self, request: PlanSimulationRequest) -> PlanSimulationResponse:
        adapter_result = await self._adapter.plan_actions(
            transcript=request.transcript,
            active_app_name=(request.app.name if request.app else None),
            _ax_tree_summary=None,
        )
        risk_level, requires_confirmation = self._compute_risk(adapter_result.actions, transcript=request.transcript)
        warnings = getattr(adapter_result, "warnings", [])
        recovery_guidance = getattr(adapter_result, "recovery_guidance", None)
        return PlanSimulationResponse(
            schema_version=SCHEMA_VERSION_CURRENT,
            session_id=request.session_id,
            is_valid=len(warnings) == 0 and len(adapter_result.actions) > 0,
            parse_errors=warnings,
            risk_level=risk_level,  # type: ignore[arg-type]
            requires_confirmation=requires_confirmation,
            summary=adapter_result.summary,
            proposed_actions_count=len(adapter_result.actions),
            recovery_guidance=recovery_guidance,
        )

    async def validate_provider(self, request: ProviderValidationRequest) -> ProviderValidationResponse:
        result = await self._adapter.validate_provider_key(request.api_key)
        return ProviderValidationResponse(
            provider=request.provider,
            valid=result.valid,
            reason=result.reason,
            account_hint=result.account_hint,
        )

    def provider_status(self) -> ProviderStatusResponse:
        return ProviderStatusResponse(
            provider="anthropic",
            key_configured=self._adapter.current_api_key() is not None,
            model_simple=settings.model_simple,
            model_complex=settings.model_complex,
            health=True,
        )

    def models(self) -> ModelsResponse:
        routing: list[ModelInfo] = [
            ModelInfo(app=None, model=settings.model_simple, reason="Default model for short/simple tasks"),
            ModelInfo(app=None, model=settings.model_complex, reason="Default model for complex multi-step tasks"),
        ]
        for app, model in settings.model_overrides.items():
            routing.append(ModelInfo(app=app, model=model, reason="App-specific override"))
        return ModelsResponse(
            schema_version=SCHEMA_VERSION_CURRENT,
            routing=routing,
            feature_flags={
                "enable_remote_llm": "true" if settings.enable_remote_llm else "false",
                "safety_strictness": settings.safety_strictness,
                "provider": settings.provider,
            },
        )

    @staticmethod
    def _compute_risk(actions: list[Action], *, transcript: str) -> tuple[str, bool]:
        high = False
        medium = False
        for action in actions:
            if action.destructive:
                high = True
                continue
            if action.kind in RISKY_ACTIONS:
                high = True
                continue
            if action.kind == "key_combo" and (action.key_combo or "").lower() in RISKY_KEY_COMBOS:
                medium = True
        lowered = transcript.lower()
        if any(term in lowered for term in HIGH_RISK_TERMS):
            medium = True

        strictness = settings.safety_strictness.lower()
        if strictness == "strict" and medium:
            high = True

        if high:
            return "high", True
        if medium:
            return "medium", True
        return "low", False
