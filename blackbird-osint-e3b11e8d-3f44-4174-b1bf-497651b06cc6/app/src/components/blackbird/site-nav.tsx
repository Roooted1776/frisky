"use client";

import { CtaReadDocs } from "./cta-read-docs";
import { CtaRunSearch } from "./cta-run-search";

export function SiteNav() {
  return (
    <header className="bb-nav">
      <a className="bb-nav__brand" href="#signal">
        <img
          alt=""
          className="bb-nav__mark"
          height={28}
          src="/assets/brand/logo-sm.png"
          width={28}
        />
        <span className="bb-nav__name">Blackbird</span>
      </a>
      <nav aria-label="Primary" className="bb-nav__links">
        <a href="#capabilities">Capabilities</a>
        <a href="#how">How it works</a>
        <a href="#applications">Applications</a>
      </nav>
      <div className="bb-nav__actions">
        <CtaReadDocs className="bb-nav__docs" />
        <CtaRunSearch className="bb-nav__run" />
      </div>
    </header>
  );
}
