# Blackbird — design brief

## Design read
For cybersecurity investigators and OSINT researchers who want fast, quiet certainty: a dark signal room that feels precise, not theatrical.

## Concept spine
**Archive dossier.** The page is a living case file. Scroll opens the dossier; each chapter stamps another page of evidence onto a single continuous camera push through a constellation of platform nodes.

## Delivery tier
`cinema` — Lenis + GSAP, scroll-scrub journey as Tier-1, chapter reveals with transform-only motion.

## Locked palette
- Background: `#0e141c` (ink navy, not pure graphite)
- Surface: `#161d28`
- Ink / text: `#e7e2d8` (bone)
- Muted: `#8a919c`
- Accent: `#c23b4a` (muted crimson — blackbird wing tip / alert stamp)
Defense: cool ink navy + bone keeps the ops-room calm; one crimson stamp is the only heat. Avoids graphite+orange, neon cyan, beige+brass, and purple glow.

## Locked type
- Display / UI: Satoshi (clean grotesk)
- Mono / data labels: JetBrains Mono
No serif. Technical dossier voice.

## Animation mode
Animation mode: animated-website

### Journey shape
`single-shot` — one continuous ~15s film of a username signal resolving into a platform constellation, then a sealed dossier. One subject, ever closer. No world hops.

### Journey (chapters over one film)
1. **Signal** — Drop a username or email into the dark. Focal: a single glowing handle glyph centered in void. Headline: "Find the accounts." Body: Search by username or email across platforms in one pass. Tags: OSINT, free AI.
2. **Sweep** — Nodes bloom across a dark grid. Focal: constellation of platform marks orbiting center. Headline: "Map the footprint." Body: WhatsMyName-backed coverage with filters you control. Tags: filters, metadata.
3. **Match** — Profiles lock into frames. Focal: stacked profile cards resolving from noise. Headline: "Extract what is public." Body: Names, locations, images, and other public details pulled automatically. Tags: profiles, export.
4. **Insight** — Soft analysis overlay crystallizes (no PII shown). Focal: abstract analysis lattice over the constellation. Headline: "Read the pattern." Body: Free AI summaries of platform behavior and technical posture. Daily limits. Tags: AI, privacy-safe.
5. **Export** — Dossier seals and stamps. Focal: sealed case folder / PDF-CSV stamp centered. Headline: "Ship the dossier." Body: Export found accounts as PDF, CSV, or raw HTTP responses. Tags: PDF, CSV, HTTP.

Journey enacts the spine: scroll fills the dossier page by page while the camera never cuts.

### World grammar
Byte-identical style: dark seamless charcoal-navy void, soft technical grid fading into black, cool bone speculars, single crimson accent light from upper-left, matte metal / glass surfaces, center-safe subject with generous negative space for HTML copy. Slow steady push-in + gentle orbit. No cuts, no shake, locked exposure, no on-screen text/logos/watermarks.

### Mobile framing
All focal subjects stay in the center 60% safe area. Lighter mobile encode (720p) of the same film.

### Delivery budget
Desktop clips ≤32 MiB total. Mobile clips ≤16 MiB total.

## Combinatorial pick (boards)
- Theme paradigm: Deep Dark (ink navy twist)
- Background character: technical grid dissolving into cinematic darkness
- Typography character: clean grotesk (Satoshi-like)
- Hero architecture: cinematic centered minimalist (copy over film)
- Section system: asymmetric premium flow
- Signature components: vertical rhythm lines · product UI panel stack · off-grid editorial · layered image crop frames
- Narrative spine: archive/dossier
- Second-read moment: one oversized numeral as structure (How it works step "01")

## Section plan (post-journey content)
1. **Journey** — scroll-scrub chapters (centered statement over film)
2. **Capabilities** — asymmetric feature list with icon crop frames (top-left lead)
3. **How it works** — numbered editorial stack with oversized numeral (off-grid)
4. **Applications** — horizontal proof strips / panel stack (image-as-canvas)
5. **Close** — full-bleed CTA band with sealed-dossier plate (bottom-left over image)

Layout families: journey overlay · asymmetric list · numbered editorial · panel stack · full-bleed CTA. No consecutive repeats. Eyebrow budget: ceil(5/3)=2 max.

## Asset plan
- Single-shot storyboard (6-panel) → scroll-scrub film + posters
- Logo/monogram (blackbird mark) + favicon head kit
- Custom icon set (6–8 glyphs: search, network, profile, AI, filter, export)
- Section plates (2 atmospheric textures)
- Content stills: platform constellation, metadata extract, sealed dossier
- Launch cover / OG (app-cover.md, concurrent with film)

## CTA inventory (bespoke chrome each)
1. **Run a search** — primary nav/hero: solid crimson block, sharp corners, mono tracking
2. **Read the docs** — secondary: bone underline + arrow, no fill
3. **Export sample** — capabilities: framed outline stamp button
4. **Start investigating** — close band: oversized headline-linked CTA (text-as-button)

## Brand constraints
Free rein. Design the Blackbird identity from the open-source OSINT product brief. No existing logo/fonts provided. Do not claim Higgsfield branding.

## Publish
Not opted in at intake (background agent default). Deploy live only.
