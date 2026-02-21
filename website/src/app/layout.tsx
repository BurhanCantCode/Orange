import "./globals.css";
import type { Metadata } from "next";
import { Analytics } from "@vercel/analytics/next";
import { Syncopate, Space_Grotesk } from 'next/font/google';

const syncopate = Syncopate({ subsets: ['latin'], weight: ['400', '700'], variable: '--font-display' });
const spaceGrotesk = Space_Grotesk({ subsets: ['latin'], weight: ['400', '500', '600', '700'], variable: '--font-body' });

export const metadata: Metadata = {
  title: "Orange // Execution",
  description: "Silicon Valley grade executed Voice-to-Action for macOS.",
  openGraph: {
    images: ["/orange_og_image.png"],
  },
  icons: {
    icon: "/orange_favicon.png",
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
