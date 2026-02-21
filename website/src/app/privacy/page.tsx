export default function PrivacyPage() {
  return (
    <main className="container py-20">
      <article className="max-w-3xl rounded-3xl border border-black/10 bg-white/70 p-8">
        <h1 className="text-3xl font-semibold">Privacy (Private Beta)</h1>
        <p className="mt-4 text-sm text-black/75">
          Orange captures microphone input, screenshots, and accessibility metadata only to execute user-requested
          actions. In beta, limited operational logs are collected for reliability and safety analysis.
        </p>
        <h2 className="mt-6 text-xl font-semibold">Data Collected</h2>
        <ul className="mt-3 list-disc space-y-2 pl-5 text-sm text-black/75">
          <li>Transcripts from hold-to-talk sessions.</li>
          <li>Planner and execution telemetry (latency, status, error codes).</li>
          <li>Optional waitlist contact details for private beta onboarding.</li>
        </ul>
        <h2 className="mt-6 text-xl font-semibold">Retention</h2>
        <p className="mt-3 text-sm text-black/75">
          Beta data is retained only as needed to operate the service and improve command reliability. You can request
          account deletion by contacting support.
        </p>
      </article>
    </main>
  );
}
