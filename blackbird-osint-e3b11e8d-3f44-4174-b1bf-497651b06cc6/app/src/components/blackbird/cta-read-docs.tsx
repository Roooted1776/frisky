"use client";

type CtaReadDocsProps = {
  href?: string;
  className?: string;
};

/** Secondary CTA - bone underline + arrow, no fill. */
export function CtaReadDocs({
  href = "https://blackbird-osint.herokuapp.com/",
  className = "",
}: CtaReadDocsProps) {
  return (
    <a
      className={`bb-cta-docs ${className}`.trim()}
      href={href}
      rel="noopener noreferrer"
      target="_blank"
    >
      Read the docs
      <span aria-hidden="true" className="bb-cta-docs__arrow">
        →
      </span>
    </a>
  );
}
