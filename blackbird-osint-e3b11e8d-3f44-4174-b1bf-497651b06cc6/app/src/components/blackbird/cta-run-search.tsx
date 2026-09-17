"use client";

type CtaRunSearchProps = {
  href?: string;
  className?: string;
};

/** Primary CTA - solid crimson block, sharp corners, mono tracking. */
export function CtaRunSearch({
  href = "https://github.com/p1ngul1n0/blackbird",
  className = "",
}: CtaRunSearchProps) {
  return (
    <a
      className={`bb-cta-run ${className}`.trim()}
      href={href}
      rel="noopener noreferrer"
      target="_blank"
    >
      Run a search
    </a>
  );
}
