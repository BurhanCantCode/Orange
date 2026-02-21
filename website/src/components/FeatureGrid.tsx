const features = [
  { title: "Voice -> Action", body: "Fast hold-to-talk workflow with transcript and action timeline." },
  { title: "Safety Guard", body: "Confirm before send/delete/purchase actions." },
  { title: "Cross-App", body: "Mail, Slack, browser, Finder, and Calendar focused quality." },
  { title: "Local-First", body: "On-device defaults with optional managed cloud models." }
];

export default function FeatureGrid() {
  return (
    <section className="container pb-20">
      <div className="grid gap-4 md:grid-cols-2">
        {features.map((feature) => (
          <article key={feature.title} className="rounded-2xl border border-black/10 bg-white/60 p-6">
            <h3 className="mb-2 text-xl font-semibold">{feature.title}</h3>
            <p className="text-black/70">{feature.body}</p>
          </article>
        ))}
      </div>
    </section>
  );
}
