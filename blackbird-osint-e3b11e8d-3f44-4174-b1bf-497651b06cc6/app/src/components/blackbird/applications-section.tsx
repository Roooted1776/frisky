import { CtaExportSample } from "./cta-export-sample";

const APPS = [
  {
    body: "Trace accounts across social and web platforms for incident response and threat intel.",
    title: "Digital investigations",
  },
  {
    body: "Map a handle across networks before you write the briefing.",
    title: "Social research",
  },
  {
    body: "Cross-check declared identities against public account footprints.",
    title: "Compliance checks",
  },
] as const;

export function ApplicationsSection() {
  return (
    <section className="bb-apps" id="applications">
      <div className="bb-apps__visual">
        <img
          alt="Abstract platform constellation visualization"
          className="bb-apps__image"
          src="/assets/constellation.jpg"
        />
      </div>
      <div className="bb-apps__panels">
        <h2 className="bb-apps__title">Where it earns its keep.</h2>
        <ul className="bb-apps__list">
          {APPS.map((app) => (
            <li className="bb-apps__item" key={app.title}>
              <h3>{app.title}</h3>
              <p>{app.body}</p>
            </li>
          ))}
        </ul>
        <CtaExportSample />
      </div>
    </section>
  );
}
