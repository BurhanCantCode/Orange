const rows = [
  { app: "Mail / Gmail", workflows: "Draft, reply, send (with confirmation)", beta: "High" },
  { app: "Slack", workflows: "Reply in active thread, channel-safe prompts", beta: "High" },
  { app: "Safari / Chrome", workflows: "Open URL, search, fill simple inputs", beta: "High" },
  { app: "Finder", workflows: "Create folder, rename, navigation", beta: "Medium" },
  { app: "Calendar", workflows: "Create event from natural language", beta: "Medium" }
];

export default function SupportedApps() {
  return (
    <section className="container pb-20">
      <div className="rounded-3xl border border-black/10 bg-white/65 p-6">
        <h2 className="text-2xl font-semibold">Private Beta Supported Apps</h2>
        <p className="mt-2 text-sm text-black/70">
          v1 beta is intentionally narrow. We prioritize reliability in this core set before long-tail app support.
        </p>
        <div className="mt-5 overflow-x-auto">
          <table className="w-full min-w-[620px] border-collapse text-left text-sm">
            <thead>
              <tr className="border-b border-black/10">
                <th className="pb-2 pr-3 font-semibold">App</th>
                <th className="pb-2 pr-3 font-semibold">Beta Workflows</th>
                <th className="pb-2 font-semibold">Readiness</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr key={row.app} className="border-b border-black/5">
                  <td className="py-3 pr-3 font-medium">{row.app}</td>
                  <td className="py-3 pr-3 text-black/75">{row.workflows}</td>
                  <td className="py-3">{row.beta}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </section>
  );
}
