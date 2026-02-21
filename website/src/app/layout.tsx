import "./globals.css";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Orange | Voice-to-Action for macOS",
  description: "Control your Mac apps with voice."
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
