const tiers = [
  { name: "Free", price: "$0", details: "10 commands/day, BYOK" },
  { name: "Pro", price: "$12/mo", details: "Unlimited commands, managed key" },
  { name: "Team", price: "$20/seat", details: "Shared settings and billing" }
];

export default function Pricing() {
  return (
    <section className="container pb-24">
      <h2 className="mb-6 text-3xl font-semibold">Pricing</h2>
      <div className="grid gap-4 md:grid-cols-3">
        {tiers.map((tier) => (
          <article key={tier.name} className="rounded-2xl border border-black/15 bg-white/70 p-6">
            <h3 className="text-xl font-semibold">{tier.name}</h3>
            <p className="mt-2 text-2xl">{tier.price}</p>
            <p className="mt-2 text-black/70">{tier.details}</p>
          </article>
        ))}
      </div>
    </section>
  );
}
