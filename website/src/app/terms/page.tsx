export default function TermsPage() {
  return (
    <main className="container py-20">
      <article className="max-w-3xl rounded-3xl border border-black/10 bg-white/70 p-8">
        <h1 className="text-3xl font-semibold">Terms (Private Beta)</h1>
        <p className="mt-4 text-sm text-black/75">
          Orange is provided as a private beta product. Features may change and availability is not guaranteed.
        </p>
        <h2 className="mt-6 text-xl font-semibold">User Responsibilities</h2>
        <ul className="mt-3 list-disc space-y-2 pl-5 text-sm text-black/75">
          <li>You are responsible for reviewing and approving high-risk actions.</li>
          <li>You agree not to use Orange for unlawful or abusive automation.</li>
          <li>You are responsible for securing your account and API credentials.</li>
        </ul>
        <h2 className="mt-6 text-xl font-semibold">Limitations</h2>
        <p className="mt-3 text-sm text-black/75">
          The software is provided “as is” during beta. Orange is not liable for indirect damages, data loss, or
          workflow disruption arising from beta usage.
        </p>
      </article>
    </main>
  );
}
