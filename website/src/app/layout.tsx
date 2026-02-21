import "./globals.css";
import type { Metadata } from "next";
import { Analytics } from "@vercel/analytics/next";
import { Syncopate, Space_Grotesk } from 'next/font/google';

const syncopate = Syncopate({ subsets: ['latin'], weight: ['400', '700'], variable: '--font-display' });
const spaceGrotesk = Space_Grotesk({ subsets: ['latin'], weight: ['400', '500', '600', '700'], variable: '--font-body' });

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? "https://doerai-eta.vercel.app"),
  title: "Orange // Execution",
  description: "Silicon Valley grade executed Voice-to-Action for macOS.",
  icons: {
    icon: [{ url: "/orange_favicon.png", type: "image/png" }],
    shortcut: ["/orange_favicon.png"],
    apple: [{ url: "/orange_favicon.png", type: "image/png" }],
  },
  openGraph: {
    title: "Orange // Execution",
    description: "Silicon Valley grade executed Voice-to-Action for macOS.",
    type: "website",
    images: ["/orange_og_image.png"],
  },
  twitter: {
    card: "summary_large_image",
    title: "Orange // Execution",
    description: "Silicon Valley grade executed Voice-to-Action for macOS.",
    images: ["/orange_og_image.png"],
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${syncopate.variable} ${spaceGrotesk.variable} dark scroll-smooth`}>
      <body className="antialiased font-body bg-[#030305] text-white selection:bg-orange-500 selection:text-white cursor-none overflow-x-hidden">
        {children}
        <Analytics />
      </body>
    </html>
  );
}
