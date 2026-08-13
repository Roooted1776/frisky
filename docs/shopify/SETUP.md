# RedMed Shopify — stand up the store

You create the Shopify account (email + card). This folder is the import pack:
**blank** and **custom-engraved** silicone bands with **NXP NTAG216**. App writes
the chip. No medical cloud. No social-media NFC SaaS. No Bluetooth.

## Before you sell

| Gate | Status |
|------|--------|
| Blank NTAG216 samples verified on a physical iPhone | Do this first (CXJ / Asia) |
| Paid Apple Developer + CoreNFC entitlement | Required — `AppConfig.nfcHardwareEnabled` is still `false` |
| Real App Store URL | Replace placeholder `id0000000000` in app + store copy |
| Factory can laser outer + per-order reverse | See `docs/band-engraving-and-nfc-sourcing.md` + `custom-fulfillment.md` |

Do not take orders until Write works on device. Selling a brick band kills trust.

## SKUs

| Product | Handle | Price (CSV) | Chip | Laser |
|---------|--------|-------------|------|-------|
| RedMed Band | `redmed-band` | $24 | Blank NTAG216 | Outer standard (or stock blank) |
| RedMed Band — Custom | `redmed-band-custom` | $39 | Blank NTAG216 | Outer + reverse (name / ICE / allergy / blood) |

Colors: Black, Red. Chip **never** pre-encoded.

## Create the shop (20 min)

1. https://www.shopify.com → Start free trial → store name e.g. `redmed-band`
2. **Online Store → Themes → Dawn** (default). Publish. Do not install a “medical ID” / NFC link app.
3. **Settings → Payments** — Shopify Payments / whatever your region allows
4. **Settings → Shipping** — one zone US (or US+intl); custom SKU may need longer handling time (e.g. 5–10 business days)
5. **Settings → Policies** — blank + custom final-sale-after-laser; no RedMed server for PHI
6. **Products → Import** → upload `products.csv`
7. Assign a product template on **RedMed Band — Custom** and paste
   `custom-band-form.liquid` into the product form (line item properties)
8. **Online Store → Pages** — copy from `pages.md`
9. **Navigation** — Home, Shop, How it works, FAQ, Contact
10. Checkout collects shipping address + custom line properties on the Custom
    SKU only. Do **not** add a separate “health profile” app or account system.

## What you are selling

- Physical silicone wristband + **NXP NTAG216**, 13.56 MHz HF NFC
- Chip ships **empty / unlocked** — owner Write in RedMed
- Custom SKU = laser text on the band face only (ops data for the factory)
- Passerby / EMT: intentional tap (~1–2″) opens `tapper.html#d=…`
- Walk-by (~6–8″) does not fire

## What you are not selling

- Hosted medical record / tap-for-profile SaaS
- Pre-written social / Instagram NFC bands
- Bluetooth / GPS trackers
- Payment / access-control wristbands
- A regulated medical device or outcome promise

## Homepage (Dawn) — one composition

Brand first. First viewport only:

1. **RedMed**
2. *Medical ID on your wrist. Written by your phone.*
3. *Passive NFC band. No Bluetooth. No server for your profile.*
4. CTAs: **Buy the band** · **Custom engrave** · **Get the app**
5. One edge-to-edge band photo

Below the fold: How it works → Blank vs Custom → FAQ.

## Apps to skip

- NFC link management / dynamic URL / medical profile cloud
- Upsell quizzes that build a hosted health record
- Anything that encodes `#d=` or a short-link onto the chip at the factory

## Ops loop

1. Sample 10 blank NTAG216 → Write full profile → confirm capacity
2. Import CSV; wire custom form; set handling time on Custom
3. Each Custom order → `custom-fulfillment.md` → factory email
4. Chip stays blank until customer Write

## Files

| File | Use |
|------|-----|
| `products.csv` | Products → Import (blank + custom) |
| `pages.md` | Pages / theme sections |
| `custom-band-form.liquid` | Line item properties on Custom product |
| `custom-fulfillment.md` | Laser ops from order → factory |
| `../band-engraving-and-nfc-sourcing.md` | Engraving rules + factory brief |
