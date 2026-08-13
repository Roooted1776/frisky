# RedMed Shopify — stand up the store

You create the Shopify account (email + card). This folder is the import pack:
blank **NXP NTAG216** silicone band only. App writes the chip. No medical data
on Shopify. No social-media NFC SaaS. No Bluetooth.

## Before you sell

| Gate | Status |
|------|--------|
| Blank NTAG216 samples verified on a physical iPhone | Do this first (CXJ / Asia) |
| Paid Apple Developer + CoreNFC entitlement | Required — `AppConfig.nfcHardwareEnabled` is still `false` |
| Real App Store URL | Replace placeholder `id0000000000` in app + store copy |
| Factory can laser outer face blank (no `#d=` QR) | See `docs/band-engraving-and-nfc-sourcing.md` |

Do not take orders until Write works on device. Selling a brick band kills trust.

## Create the shop (15 min)

1. https://www.shopify.com → Start free trial → store name e.g. `redmed-band`
2. **Online Store → Themes → Dawn** (default). Publish. Do not install a “medical ID” app.
3. **Settings → Payments** — Shopify Payments / whatever your region allows
4. **Settings → Shipping** — one zone US (or US+intl); flat rate or free over $X
5. **Settings → Policies** — paste Privacy / Terms that match the app: no RedMed
   server for PHI; band is blank hardware; profile stays on-chip / on-phone
6. **Products → Import** → upload `products.csv` from this folder
7. **Online Store → Pages** — create pages from `pages.md` (Home sections,
   How it works, Shipping, FAQ)
8. **Online Store → Navigation** — Home, Shop, How it works, FAQ, Contact
9. **Settings → Checkout** — collect shipping address only. Do **not** add
   custom checkout fields for allergies, blood type, DOB, or ICE phone.

## What you are selling

- Physical blank silicone wristband with **NXP NTAG216**, 13.56 MHz HF NFC
- Chip ships **empty / unlocked** — owner programs it in the RedMed iOS app
- Passerby / EMT: intentional phone tap (~1–2″) opens `tapper.html#d=…` — no
  app install, no login, no RedMed cloud
- Walk-by (~6–8″) does not fire (HF physics)

## What you are not selling

- A hosted medical record or “tap for profile” SaaS
- Pre-written social / Instagram NFC bands
- Bluetooth / GPS trackers
- A card-reader / payment wristband
- A regulated medical device or outcome promise

## Homepage (Dawn) — one composition

Brand first. First viewport only:

1. **RedMed** (wordmark / logo from repo `BrandLogo.png` / `BrandWordmark`)
2. One line: *Medical ID on your wrist. Written by your phone.*
3. One sentence: *Passive NFC band. No Bluetooth. No server for your profile.*
4. CTA: **Buy the band** + secondary **Get the app**
5. One product photo of the band (edge-to-edge), not a dashboard of features

Below the fold: How it works (3 steps) → What’s on the chip → What’s not → FAQ.

## Apps to skip

- Any NFC “link management” / dynamic URL / medical profile cloud
- Upsell quiz that asks for health data
- Review widgets that require PHI anecdotes

## Ops loop

1. Sample 10 blank NTAG216 from CXJ → write full profile in app → confirm capacity
2. Set retail price (CSV starts at **$24** — change before publish)
3. Order blank stock + laser outer face only for first production batch
4. Fulfill from your address or a simple 3PL; chip stays blank until customer Write

## Files

| File | Use |
|------|-----|
| `products.csv` | Shopify Admin → Products → Import |
| `pages.md` | Copy into Online Store → Pages / theme sections |
| `../band-engraving-and-nfc-sourcing.md` | Factory + engraving brief |
