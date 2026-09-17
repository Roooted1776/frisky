const STEPS = [
  {
    body: "Drop a username or email into the dark. One pass starts the sweep.",
    n: "01",
    title: "Signal",
  },
  {
    body: "Platforms light up across the grid. Filters keep the noise out.",
    n: "02",
    title: "Sweep",
  },
  {
    body: "Public profile details resolve into the case file automatically.",
    n: "03",
    title: "Match",
  },
  {
    body: "Optional AI summaries read the platform pattern. Daily limits apply.",
    n: "04",
    title: "Insight",
  },
  {
    body: "Ship PDF, CSV, or HTTP responses. The dossier is ready to move.",
    n: "05",
    title: "Export",
  },
] as const;

export function HowSection() {
  return (
    <section className="bb-how" id="how">
      <div className="bb-how__inner">
        <h2 className="bb-how__title">How the dossier fills.</h2>
        <ol className="bb-how__list">
          {STEPS.map((step, index) => (
            <li
              className={`bb-how__step${index === 0 ? " bb-how__step--lead" : ""}`}
              key={step.n}
            >
              <span aria-hidden="true" className="bb-how__num">
                {step.n}
              </span>
              <div className="bb-how__copy">
                <h3>{step.title}</h3>
                <p>{step.body}</p>
              </div>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}
