"use client";

type CtaExportSampleProps = {
  href?: string;
  className?: string;
};

/** Capabilities CTA - framed outline stamp. */
export function CtaExportSample({
  href = "https://github.com/p1ngul1n0/blackbird",
  className = "",
}: CtaExportSampleProps) {
  return (
    <a
      className={`bb-cta-export ${className}`.trim()}
      href={href}
      rel="noopener noreferrer"
      target="_blank"
    >
      Export sample
    </a>
  );
}
