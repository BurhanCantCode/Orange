import { NextRequest, NextResponse } from "next/server";

export async function POST(request: NextRequest) {
  const payload = await request.text();

  if (!payload) {
    return NextResponse.json({ error: "Empty payload" }, { status: 400 });
  }

  return NextResponse.json({ status: "accepted" }, { status: 200 });
}
