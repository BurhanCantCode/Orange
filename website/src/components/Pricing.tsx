export default function Pricing() {
  return (
    <section className="container py-20">
      <div className="mx-auto max-w-4xl rounded-3xl border border-black/10 bg-white/75 p-8">
        <h2 className="text-3xl font-semibold">Private Beta Access</h2>
        <p className="mt-3 text-black/75">
          Orange is currently BYOK-only. There are no paid plans in this phase. Bring your own Anthropic API key,
          and Orange runs with your credentials.
        </p>

        <div className="mt-6 grid gap-4 md:grid-cols-2">
          <article className="rounded-2xl border border-black/10 bg-white p-5">
            <h3 className="text-xl font-semibold">What you get</h3>
            <ul className="mt-3 list-disc space-y-1 pl-5 text-sm text-black/75">
              <li>Native macOS app + bundled sidecar</li>
              <li>Hold-to-talk voice workflow</li>
              <li>Mail, Slack, browser, Finder, Calendar focus</li>
              <li>Safety confirmations for high-risk actions</li>
            </ul>
          </article>

          <article className="rounded-2xl border border-black/10 bg-white p-5">
            <h3 className="text-xl font-semibold">What you need</h3>
            <ul className="mt-3 list-disc space-y-1 pl-5 text-sm text-black/75">
              <li>An Anthropic API key</li>
              <li>macOS permissions: Accessibility, Microphone, Screen Recording</li>
              <li>Private beta invite</li>
            </ul>
          </article>
        </div>
      </div>
    </section>
  );
}
