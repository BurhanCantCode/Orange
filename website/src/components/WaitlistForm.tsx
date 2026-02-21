"use client";

import { FormEvent, useState } from "react";

type WaitlistResponse = {
  status: string;
  beta_access: boolean;
  beta_token?: string | null;
};

export default function WaitlistForm() {
  const [email, setEmail] = useState("");
  const [name, setName] = useState("");
  const [statusText, setStatusText] = useState("Join the private beta");
  const [loading, setLoading] = useState(false);

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setLoading(true);
    setStatusText("Submitting...");
    try {
      const response = await fetch("/api/waitlist", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          email,
          full_name: name || undefined,
          source: "website"
        })
      });
      const body = (await response.json()) as WaitlistResponse & { detail?: string };
      if (!response.ok) {
        setStatusText(body.detail ?? "Unable to submit. Try again.");
        return;
      }

      if (body.beta_access && body.beta_token) {
        setStatusText(`Accepted. Your beta token: ${body.beta_token}`);
      } else {
        setStatusText("Added to waitlist. We’ll email you when your invite is ready.");
      }
      setEmail("");
      setName("");
    } catch {
      setStatusText("Network error. Try again.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <form onSubmit={onSubmit} className="mt-8 grid gap-3 rounded-2xl border border-black/10 bg-white/70 p-4 md:grid-cols-[1fr_1fr_auto]">
      <input
        type="text"
        value={name}
        onChange={(event) => setName(event.target.value)}
        placeholder="Full name"
        className="rounded-xl border border-black/15 bg-white px-3 py-2 text-sm outline-none ring-citrus/30 focus:ring"
      />
      <input
        type="email"
        required
        value={email}
        onChange={(event) => setEmail(event.target.value)}
        placeholder="Email"
        className="rounded-xl border border-black/15 bg-white px-3 py-2 text-sm outline-none ring-citrus/30 focus:ring"
      />
      <button
        type="submit"
        disabled={loading}
        className="rounded-xl bg-black px-4 py-2 text-sm font-semibold text-white transition hover:bg-black/85 disabled:opacity-60"
      >
        {loading ? "Submitting..." : "Request Invite"}
      </button>
      <p className="md:col-span-3 text-xs text-black/70">{statusText}</p>
    </form>
  );
}
