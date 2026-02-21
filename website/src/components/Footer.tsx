export default function Footer() {
  return (
    <footer className="border-t border-black/10 py-8 text-center text-sm text-black/60">
      © {new Date().getFullYear()} Orange. Built for macOS.
    </footer>
  );
}
