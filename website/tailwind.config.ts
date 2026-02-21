import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        ink: "#171717",
        cream: "#fbf6ec",
        citrus: "#ff9f1a",
        mint: "#13c2a3"
      }
    }
  },
  plugins: []
};

export default config;
