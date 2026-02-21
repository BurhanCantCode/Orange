"use client";

import { FormEvent, useMemo, useState } from "react";
import Link from "next/link";

const supportedApps = [
  { name: "Safari / Chrome", status: "Supported", detail: "Open URL, search, tab navigation" },
  { name: "Slack", status: "Supported", detail: "Draft and reply with confirmation" },
  { name: "Mail / Gmail", status: "Supported", detail: "Draft + guarded send flow" },
  { name: "Finder", status: "Supported", detail: "Create, rename, move, navigate" },
  { name: "Calendar", status: "Supported", detail: "Create and update events" },
];

type WaitlistState = "idle" | "submitting" | "success" | "error";

export default function HomePage() {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [useCase, setUseCase] = useState("");
  const [state, setState] = useState<WaitlistState>("idle");
  const [message, setMessage] = useState("");

  const canSubmit = useMemo(() => {
    return name.trim().length > 1 && email.includes("@");
  }, [name, email]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!canSubmit || state == "submitting") {
      return;
    }

    setState("submitting");
    setMessage("");

    try {
      const response = await fetch("/api/waitlist", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          name: name.trim(),
          email: email.trim(),
          use_case: useCase.trim(),
          source: "website_home",
        }),
      });
      const payload = await response.json();
      if (!response.ok) {
        throw new Error(payload?.detail ?? "Signup failed");
      }

      setState("success");
      setMessage("Request received. We will email your private-beta token.");
      setUseCase("");
    } catch (error) {
      setState("error");
      if (error instanceof Error) {
        setMessage(error.message);
      } else {
        setMessage("Waitlist request failed.");
      }
    }
  }

  return (
    <main className="min-h-screen bg-[radial-gradient(circle_at_20%_0%,rgba(255,128,42,0.22),transparent_45%),radial-gradient(circle_at_85%_10%,rgba(255,214,170,0.18),transparent_42%),linear-gradient(180deg,#090909_0%,#111111_100%)] text-white">
      <section className="mx-auto max-w-6xl px-6 pb-14 pt-24 md:px-10 md:pt-28">
        <div className="grid gap-10 md:grid-cols-[1.2fr_1fr]">
          <div>
            <p className="inline-flex rounded-full border border-orange-300/30 bg-orange-500/10 px-3 py-1 text-xs uppercase tracking-[0.18em] text-orange-200">
              Private Beta - BYOK Anthropic
            </p>
            <h1 className="mt-6 font-['Space_Grotesk'] text-5xl font-semibold leading-tight md:text-6xl">
              Install Orange, add your Anthropic key, and run voice commands across Mac apps.
            </h1>
            <p className="mt-5 max-w-xl text-base text-white/75 md:text-lg">
              No payments or account plans in this phase. Orange is local-first with a bundled sidecar runtime and safety confirmations for risky actions.
            </p>

            <div className="mt-8 flex flex-wrap items-center gap-3">
              <Link
                href="/download"
                className="rounded-xl bg-orange-500 px-5 py-3 text-sm font-semibold text-black transition hover:bg-orange-400"
              >
                Download Beta DMG
              </Link>
              <Link
                href="/pricing"
                className="rounded-xl border border-white/25 px-5 py-3 text-sm font-semibold text-white transition hover:border-orange-300 hover:text-orange-200"
              >
                BYOK Details
              </Link>
            </div>

            <div className="mt-10 grid gap-3 sm:grid-cols-3">
              <Metric label="Latency target" value="p95 < 4s" />
              <Metric label="Distribution" value="Signed DMG" />
              <Metric label="Provider" value="Anthropic only" />
            </div>
          </div>

          <form
            onSubmit={handleSubmit}
            className="rounded-3xl border border-white/15 bg-black/30 p-6 backdrop-blur"
          >
            <h2 className="text-xl font-semibold">Request private-beta access</h2>
            <p className="mt-2 text-sm text-white/70">
              Share your work email. We will send install access and onboarding notes.
            </p>

            <label className="mt-5 block text-sm text-white/80">
              Name
              <input
                value={name}
                onChange={(event) => setName(event.target.value)}
                className="mt-2 w-full rounded-xl border border-white/20 bg-black/40 px-3 py-2 text-sm outline-none focus:border-orange-300"
                placeholder="Jane Doe"
                autoComplete="name"
              />
            </label>

            <label className="mt-4 block text-sm text-white/80">
              Work email
              <input
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                className="mt-2 w-full rounded-xl border border-white/20 bg-black/40 px-3 py-2 text-sm outline-none focus:border-orange-300"
                placeholder="jane@company.com"
                type="email"
                autoComplete="email"
              />
            </label>

            <label className="mt-4 block text-sm text-white/80">
              Primary use case
              <textarea
                value={useCase}
                onChange={(event) => setUseCase(event.target.value)}
                className="mt-2 h-24 w-full resize-none rounded-xl border border-white/20 bg-black/40 px-3 py-2 text-sm outline-none focus:border-orange-300"
                placeholder="Slack triage, email drafting, calendar updates..."
              />
            </label>

            <button
              className="mt-5 w-full rounded-xl bg-white px-4 py-2.5 text-sm font-semibold text-black disabled:cursor-not-allowed disabled:opacity-50"
              disabled={!canSubmit || state === "submitting"}
              type="submit"
            >
              {state === "submitting" ? "Submitting..." : "Join Waitlist"}
            </button>

            {message ? (
              <p className={`mt-3 text-sm ${state === "success" ? "text-green-300" : "text-orange-200"}`}>
                {message}
              </p>
            ) : null}
          </form>
        </div>
      </section>

      <section className="mx-auto max-w-6xl px-6 pb-14 md:px-10">
        <div className="overflow-hidden rounded-3xl border border-white/10 bg-black/25">
          <div className="grid grid-cols-[1.2fr_0.6fr_1.2fr] border-b border-white/10 px-5 py-3 text-xs uppercase tracking-[0.18em] text-white/55">
            <p>App</p>
            <p>Status</p>
            <p>Coverage</p>
          </div>
          {supportedApps.map((item) => (
            <div
              key={item.name}
              className="grid grid-cols-[1.2fr_0.6fr_1.2fr] border-b border-white/5 px-5 py-3 text-sm text-white/80 last:border-b-0"
            >
              <p>{item.name}</p>
              <p className="text-orange-200">{item.status}</p>
              <p className="text-white/65">{item.detail}</p>
            </div>
          ))}
        </div>
      </section>
    </main>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-2xl border border-white/15 bg-black/25 px-4 py-3">
      <p className="text-xs uppercase tracking-[0.16em] text-white/50">{label}</p>
      <p className="mt-1 text-lg font-semibold text-orange-100">{value}</p>
    </div>
  );
}
