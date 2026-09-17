const CAPABILITIES = [
  {
    body: "WhatsMyName-backed coverage across a wide range of online platforms, from one username or email.",
    icon: "/assets/icons/icon-network.png",
    title: "Wide platform sweep",
  },
  {
    body: "Automatically pull names, locations, images, and other public details from discovered profiles.",
    icon: "/assets/icons/icon-profile.png",
    title: "Metadata extraction",
  },
  {
    body: "Built-in AI analysis API with daily limits. Behavioral and technical summaries. No personal data shared.",
    icon: "/assets/icons/icon-insight.png",
    title: "Free AI insights",
  },
  {
    body: "Tailor searches with --filter by property name and value. Export PDF, CSV, or raw HTTP responses.",
    icon: "/assets/icons/icon-filter.png",
    title: "Filters and exports",
  },
] as const;

export function CapabilitiesSection() {
  return (
    <section
      className="bb-capabilities"
      id="capabilities"
      style={{ backgroundImage: "url(/assets/plate-grid.jpg)" }}
    >
      <div className="bb-capabilities__inner">
        <div className="bb-capabilities__intro">
          <h2 className="bb-capabilities__title">Built for thorough sweeps.</h2>
          <p className="bb-capabilities__lede">
            Open-source OSINT for investigators who need speed without losing
            the receipt trail.
          </p>
        </div>
        <ul className="bb-capabilities__list">
          {CAPABILITIES.map((item) => (
            <li className="bb-capabilities__item" key={item.title}>
              <img
                alt=""
                className="bb-capabilities__icon"
                height={48}
                src={item.icon}
                width={48}
              />
              <div>
                <h3>{item.title}</h3>
                <p>{item.body}</p>
              </div>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
