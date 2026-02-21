import { NextResponse } from "next/server";

export async function POST(request: Request) {
  const payload = await request.json();
  const backendBase = process.env.ORANGE_BACKEND_URL ?? "http://127.0.0.1:8000";

  try {
    const response = await fetch(`${backendBase}/beta/waitlist`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(payload),
      cache: "no-store"
    });
    const body = await response.json();
    return NextResponse.json(body, { status: response.status });
  } catch {
    return NextResponse.json({ detail: "Backend unavailable" }, { status: 503 });
  }
}
