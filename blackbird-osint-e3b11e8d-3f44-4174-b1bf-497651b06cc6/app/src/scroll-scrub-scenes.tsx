/**
 * Blackbird scroll-scrub journey - single-shot film with one scene entry.
 * Film carries the five dossier beats visually; HTML chapters after expand them.
 */
import type {
  ScrollScrubScene,
  ScrollScrubTheme,
} from "@/components/scroll-scrub/scroll-scrub";
import { CtaReadDocs } from "@/components/blackbird/cta-read-docs";
import { CtaRunSearch } from "@/components/blackbird/cta-run-search";

export const scrollScrubTheme: ScrollScrubTheme = {
  accent: "#c23b4a",
  background: "#0e141c",
  ink: "#e7e2d8",
  muted: "#8a919c",
};

export const scrollScrubScenes: ScrollScrubScene[] = [
  {
    actions: (
      <>
        <CtaRunSearch />
        <CtaReadDocs />
      </>
    ),
    align: "left",
    body: "Search usernames or emails across platforms. Pull public metadata. Export the dossier.",
    clip: "/assets/world/scene-01.mp4",
    id: "signal",
    kicker: "Blackbird",
    label: "Signal",
    linger: 0.18,
    mobileClip: "/assets/world/scene-01-mobile.mp4",
    mobilePoster: "/assets/world/scene-01-mobile-poster.png",
    poster: "/assets/world/scene-01-poster.png",
    scroll: 5.2,
    tags: ["OSINT", "WhatsMyName", "Free AI"],
    title: "Find the accounts.",
  },
];
