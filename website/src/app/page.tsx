import Hero from "@/components/Hero";
import FeatureGrid from "@/components/FeatureGrid";
import Pricing from "@/components/Pricing";
import Footer from "@/components/Footer";
import SupportedApps from "@/components/SupportedApps";

export default function HomePage() {
  return (
    <main>
      <Hero />
      <FeatureGrid />
      <SupportedApps />
      <Pricing />
      <Footer />
    </main>
  );
}
