"use client";

import { motion } from "framer-motion";

export default function Hero() {
  return (
    <section className="container py-20">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
        className="rounded-3xl border border-black/10 bg-white/70 p-10 backdrop-blur"
      >
        <p className="mb-3 inline-block rounded-full bg-citrus/20 px-3 py-1 text-xs font-semibold uppercase tracking-wide">
          Native macOS agent
        </p>
        <h1 className="mb-4 text-5xl font-semibold leading-tight">
          Speak once. Orange executes across your Mac.
        </h1>
        <p className="max-w-2xl text-lg text-black/70">
          Hold a hotkey, say what you want, and Orange plans, confirms, and executes actions in Mail, Slack,
          browser, Finder, and Calendar.
        </p>
      </motion.div>
    </section>
  );
}
