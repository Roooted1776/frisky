import { CtaStartInvestigating } from "./cta-start-investigating";

export function CloseSection() {
  return (
    <section className="bb-close" id="close">
      <img
        alt=""
        aria-hidden="true"
        className="bb-close__plate"
        src="/assets/dossier.jpg"
      />
      <div className="bb-close__copy">
        <p className="bb-close__kicker">Open source. Free AI limits.</p>
        <h2 className="bb-close__title">Seal the case file.</h2>
        <p className="bb-close__body">
          Blackbird is built by Lucas Antoniaci. Grab it, run the sweep, export
          what you find.
        </p>
        <CtaStartInvestigating />
      </div>
    </section>
  );
}
