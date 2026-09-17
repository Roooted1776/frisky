import { createFileRoute } from "@tanstack/react-router";

import { ApplicationsSection } from "@/components/blackbird/applications-section";
import { CapabilitiesSection } from "@/components/blackbird/capabilities-section";
import { CloseSection } from "@/components/blackbird/close-section";
import { HowSection } from "@/components/blackbird/how-section";
import { SiteFooter } from "@/components/blackbird/site-footer";
import { SiteNav } from "@/components/blackbird/site-nav";
import { ScrollScrub } from "@/components/scroll-scrub/scroll-scrub";
import { scrollScrubScenes, scrollScrubTheme } from "@/scroll-scrub-scenes";

export const Route = createFileRoute("/")({
  component: Index,
});

function Index() {
  return (
    <div className="bb-page">
      <SiteNav />
      <main>
        <ScrollScrub scenes={scrollScrubScenes} theme={scrollScrubTheme} />
        <CapabilitiesSection />
        <HowSection />
        <ApplicationsSection />
        <CloseSection />
      </main>
      <SiteFooter />
    </div>
  );
}
