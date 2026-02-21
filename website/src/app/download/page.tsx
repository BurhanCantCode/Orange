const latestRelease = {
  version: "0.9.0-beta.1",
  publishedAt: "2026-02-21",
  dmgName: "Orange-0.9.0-beta.1.dmg",
  sha256: "f3c4b1989a6d1ed0df8ac7d94730c3eb6cc4ef6f0933f1f0e42d7f0d8e6c9a81",
  size: "182 MB"
};

export default function DownloadPage() {
  return (
    <main className="container py-20">
      <section className="rounded-3xl border border-black/10 bg-white/70 p-8">
        <h1 className="text-4xl font-semibold">Orange Private Beta Download</h1>
        <p className="mt-3 max-w-2xl text-black/70">
          This build is signed and intended for invited beta users. Installation requires macOS Sonoma or newer.
        </p>

        <div className="mt-8 grid gap-3 text-sm md:grid-cols-2">
          <p>
            <span className="font-semibold">Version:</span> {latestRelease.version}
          </p>
          <p>
            <span className="font-semibold">Published:</span> {latestRelease.publishedAt}
          </p>
          <p>
            <span className="font-semibold">DMG:</span> {latestRelease.dmgName}
          </p>
          <p>
            <span className="font-semibold">Size:</span> {latestRelease.size}
          </p>
        </div>

        <p className="mt-4 break-all rounded-xl border border-black/10 bg-black/[0.03] p-3 text-xs">
          <span className="font-semibold">SHA-256:</span> {latestRelease.sha256}
        </p>

        <a
          href={`/releases/${latestRelease.dmgName}`}
          className="mt-6 inline-flex rounded-xl bg-black px-5 py-2 text-sm font-semibold text-white"
        >
          Download DMG
        </a>
      </section>
    </main>
  );
}
