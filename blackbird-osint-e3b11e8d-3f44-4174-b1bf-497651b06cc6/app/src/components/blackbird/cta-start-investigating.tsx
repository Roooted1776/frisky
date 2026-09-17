"use client";

type CtaStartInvestigatingProps = {
  href?: string;
  className?: string;
};

/** Close-band CTA - oversized headline-linked text button. */
export function CtaStartInvestigating({
  href = "https://github.com/p1ngul1n0/blackbird",
  className = "",
}: CtaStartInvestigatingProps) {
  return (
    <a
      className={`bb-cta-start ${className}`.trim()}
      href={href}
      rel="noopener noreferrer"
      target="_blank"
    >
      Start investigating
    </a>
  );
}
