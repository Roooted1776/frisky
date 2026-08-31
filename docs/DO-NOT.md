# Do not

Permanent product rules. Do not ship copy or URLs that break these.

- **Do not** market GPS as sent to 911. Coordinates stay on this iPhone for the owner to read. `tel:` does not attach location or profile.
- **Do not** call RedMed HIPAA-certified or a medical device. Local-only ≠ certification. ICE card ≠ FDA device.
- **Do not** encode `apps.apple.com/id0000000000` (or any fake listing ID) on a QR, band, or in `AppConfig.appStoreURL`. That value is `nil` until Connect assigns a real ID.
- **Do not** open a second clone of this repo. Only `/Users/claude/Documents/frisky` → `Roooted1776/frisky` → `main`.
- **Do not** call the bracelet "encrypted" or "locked to your phone." `#d=` packing uses a public client key so any phone can open the card. The band is the credential.
- **Do not** spend paid ads, ship “available now,” or stand up Shopify until the gate in [`docs/ADVERTISING.md`](ADVERTISING.md) is green (live `/tapper/`, real App Store ID, physical NFC write, 1–10 sample bands).
- **Do not** put Meta Pixel, GA4, TikTok Pixel, or any ad/analytics tracker on `tapper/index.html` (or the bundled `tapper.html`). Conversion pixels belong on the store / listing only.
- **Do not** mash the two advertising views into one claim. View A is wearer / family (Shopify + App Store). View B is facility / EMS (station brief, then PO only after the company gate in `docs/ADVERTISING.md`). Do not tell families “hospitals use this.” Do not tell facilities the App Store is their checkout. No course LMS / giveaway funnel.
