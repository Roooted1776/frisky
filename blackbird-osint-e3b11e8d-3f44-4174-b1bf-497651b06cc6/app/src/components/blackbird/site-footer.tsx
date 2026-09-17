export function SiteFooter() {
  return (
    <footer className="bb-footer">
      <div className="bb-footer__inner">
        <p className="bb-footer__brand">Blackbird</p>
        <p className="bb-footer__meta">
          Open-source OSINT by{" "}
          <a
            href="https://www.linkedin.com/in/lucas-antoniaci/"
            rel="noopener noreferrer"
            target="_blank"
          >
            Lucas Antoniaci
          </a>
        </p>
        <p className="bb-footer__links">
          <a
            href="https://github.com/p1ngul1n0/blackbird"
            rel="noopener noreferrer"
            target="_blank"
          >
            GitHub
          </a>
          <span aria-hidden="true">·</span>
          <a href="#signal">Top</a>
        </p>
      </div>
    </footer>
  );
}
