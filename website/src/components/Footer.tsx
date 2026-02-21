import Link from "next/link";

export default function Footer() {
  return (
    <footer className="border-t border-black/10 py-8 text-sm text-black/60">
      <div className="container flex flex-wrap items-center justify-between gap-3">
        <p>© {new Date().getFullYear()} Orange. Built for macOS.</p>
        <nav className="flex gap-4">
          <Link href="/download" className="hover:text-black">
            Download
          </Link>
          <Link href="/privacy" className="hover:text-black">
            Privacy
          </Link>
          <Link href="/terms" className="hover:text-black">
            Terms
          </Link>
        </nav>
      </div>
    </footer>
  );
}
