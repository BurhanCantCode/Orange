from __future__ import annotations

import os

from fastapi.testclient import TestClient

from app import main as app_main
from app.main import app
from core.schemas import Action
from macos_use_adapter.adapter import AdapterResult


client = TestClient(app)


def test_health() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_plan_requires_api_key(monkeypatch) -> None:
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    payload = {
        "schema_version": 1,
        "session_id": "session-missing-key",
        "transcript": "open Safari",
        "app": {"name": "Finder", "bundle_id": "com.apple.finder"},
    }
    response = client.post("/v1/plan", json=payload)
    assert response.status_code == 400
    body = response.json()
    assert body["detail"]["error_code"] == "missing_api_key"


def test_plan_invalid_key_format(monkeypatch) -> None:
    monkeypatch.setenv("ANTHROPIC_API_KEY", "not-a-valid-key")
    payload = {
        "schema_version": 1,
        "session_id": "session-invalid-key",
        "transcript": "open Safari",
        "app": {"name": "Finder", "bundle_id": "com.apple.finder"},
    }
    response = client.post("/v1/plan", json=payload)
    assert response.status_code == 401
    body = response.json()
    assert body["detail"]["error_code"] == "invalid_api_key_format"


def test_plan_returns_actions_with_valid_key(monkeypatch) -> None:
    monkeypatch.setenv("ANTHROPIC_API_KEY", "sk-ant-test-plan-key")

    async def fake_plan_with_anthropic(*, transcript: str, active_app_name: str | None, ax_tree_summary: str | None, api_key: str) -> AdapterResult:  # noqa: ARG001
        return AdapterResult(
            actions=[Action(id="a1", kind="open_app", target="Safari", expected_outcome="Safari opened")],
            confidence=0.9,
            summary="Open Safari",
            warnings=[],
        )

    monkeypatch.setattr(app_main._planner._adapter, "_plan_with_anthropic", fake_plan_with_anthropic)

    payload = {
        "schema_version": 1,
        "session_id": "session-valid-key",
        "transcript": "open Safari",
        "app": {"name": "Finder", "bundle_id": "com.apple.finder"},
    }
    response = client.post("/v1/plan", json=payload)
    assert response.status_code == 200

    body = response.json()
    assert body["session_id"] == "session-valid-key"
    assert body["actions"]
    assert body["actions"][0]["kind"] == "open_app"


def test_provider_status_and_validate_endpoints(monkeypatch) -> None:
    monkeypatch.setenv("ANTHROPIC_API_KEY", "sk-ant-status-key")

    status_response = client.get("/v1/provider/status")
    assert status_response.status_code == 200
    status_body = status_response.json()
    assert status_body["provider"] == "anthropic"
    assert status_body["key_configured"] is True
    assert "model_simple" in status_body
    assert "model_complex" in status_body
    assert status_body["health"] is True

    # Invalid format should fail before network call.
    validate_response = client.post(
        "/v1/provider/validate",
        json={"provider": "anthropic", "api_key": "invalid-key-format"},
    )
    assert validate_response.status_code == 200
    validate_body = validate_response.json()
    assert validate_body["provider"] == "anthropic"
    assert validate_body["valid"] is False


def test_verify_failure_returns_corrective_action() -> None:
    plan = {
        "schema_version": 1,
        "session_id": "session-verify",
        "actions": [
            {
                "id": "a1",
                "kind": "click",
                "target": "Send button",
                "timeout_ms": 3000,
                "destructive": False,
            }
        ],
        "confidence": 0.8,
        "risk_level": "medium",
        "requires_confirmation": True,
    }
    payload = {
        "schema_version": 1,
        "session_id": "session-verify",
        "action_plan": plan,
        "execution_result": "failure",
        "reason": "Element not found",
    }

    response = client.post("/v1/verify", json=payload)
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "failure"
    assert len(body["corrective_actions"]) == 1


def test_plan_simulate_requires_api_key(monkeypatch) -> None:
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    payload = {
        "schema_version": 1,
        "session_id": "session-sim-no-key",
        "transcript": "open Safari and go to openai.com",
        "app": {"name": "Finder"},
    }
    response = client.post("/v1/plan/simulate", json=payload)
    assert response.status_code == 400


def test_models_endpoint() -> None:
    response = client.get("/v1/models")
    assert response.status_code == 200
    body = response.json()
    assert body["schema_version"] == 1
    assert isinstance(body["routing"], list)
    assert isinstance(body["feature_flags"], dict)


def test_telemetry_round_trip() -> None:
    event = {
        "session_id": "session-t1",
        "stage": "executing",
        "status": "success",
        "latency_ms": 123,
    }
    post_response = client.post("/v1/telemetry", json=event)
    assert post_response.status_code == 200
    assert post_response.json()["status"] == "accepted"

    get_response = client.get("/v1/telemetry?limit=1")
    assert get_response.status_code == 200
    body = get_response.json()
    assert len(body["events"]) == 1
    assert body["events"][0]["session_id"] == "session-t1"
