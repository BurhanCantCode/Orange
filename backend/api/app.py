from __future__ import annotations

from datetime import datetime, timezone
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, EmailStr

app = FastAPI(title="Orange Backend API", version="0.1.0")


class AuthTokenRequest(BaseModel):
    email: EmailStr


class UsageResponse(BaseModel):
    user_id: str
    period: str
    commands_used: int
    command_limit: int


class StripeWebhookPayload(BaseModel):
    event_type: str
    customer_id: str
    subscription_status: str | None = None


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/auth/token")
def issue_token(request: AuthTokenRequest) -> dict[str, str]:
    # Scaffold response. Replace with Supabase JWT flow.
    return {
        "access_token": f"dev-token-{request.email}",
        "token_type": "bearer",
        "issued_at": datetime.now(tz=timezone.utc).isoformat(),
    }


@app.get("/usage/current", response_model=UsageResponse)
def usage_current(user_id: str) -> UsageResponse:
    return UsageResponse(
        user_id=user_id,
        period="monthly",
        commands_used=0,
        command_limit=300,
    )


@app.post("/stripe/webhook")
def stripe_webhook(payload: StripeWebhookPayload) -> dict[str, str]:
    if not payload.event_type:
        raise HTTPException(status_code=400, detail="Missing event type")
    return {"status": "accepted"}
