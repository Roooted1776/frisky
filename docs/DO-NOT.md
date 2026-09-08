# Do not

Permanent product rules. Do not ship copy or URLs that break these.

- **Do not** market GPS as sent to 911. Coordinates stay on this iPhone for the owner to read. `tel:` does not attach location or profile.
- **Do not** call RedMed HIPAA-certified or a medical device. Local-only ≠ certification. ICE card ≠ FDA device.
- **Do not** encode `apps.apple.com/id0000000000` (or any fake listing ID) on a QR, band, or in `AppConfig.appStoreURL`. That value is `nil` until Connect assigns a real ID.
- **Do not** open a second clone of this repo. Only `/Users/claude/Documents/frisky` → `Roooted1776/frisky` → `main`.
- **Do not** call the bracelet "encrypted" or "locked to your phone." `#d=` packing uses a public client key so any phone can open the card. The band is the credential.
- **Do not** bind the owner profile Keychain to Face ID / Touch ID via `SecAccessControl` / `biometryCurrentSet` (or any biometry ACL). Face ID is **UI-only** (`BiometricAuth`). Keychain stays `WhenPasscodeSetThisDeviceOnly` with **no** access control — readable while this iPhone is unlocked, excluded from iCloud/backups. Legacy ACL rows may migrate once; never write a new bound item. Do not claim the phone profile is "unreadable without Face ID."
- **Do not** spend paid ads, ship “available now,” or stand up Shopify until the gate in [`docs/ADVERTISING.md`](ADVERTISING.md) is green (live `/tapper/`, real App Store ID, physical NFC write, 1–10 sample bands). Help → Ships When Ready (Terms §12) — no date promise in ads or captions.
- **Do not** put Meta Pixel, GA4, TikTok Pixel, or any ad/analytics tracker on `tapper/index.html` (or the bundled `tapper.html`). Conversion pixels belong on the store / listing only.
- **Do not** mash the two advertising views into one claim. View A is wearer / family (Shopify + App Store). View B is facility / EMS (station brief, then PO only after the company gate in `docs/ADVERTISING.md`). Do not tell families “hospitals use this.” Do not tell facilities the App Store is their checkout. No course LMS / giveaway funnel.
- **Do not** add BLE, Bonjour, Multipeer, Wi‑Fi Aware, or “search local networks for nearby bands.” NTAG216 is passive HF NFC — no battery, no radio to advertise. Owner wrist proximity must not Safari-hijack a phone that has RedMed — that is **Associated Domains** plus the Safari `redmed://band` handoff before SOS (`docs/associated-domains-restore.md`), not fake ranging. Do not remove passerby Safari SOS auto-arm to paper over a missing applinks entitlement.

- **Do not** ask support mailers for a full medical profile. `help.RedMed@gmail.com` is for app/band troubleshooting only. Delete support threads when resolved — that inbox is the only path from users to the operator.
- **Do not** fork a second Privacy policy. Source of truth is in-app Help → Policies → Privacy (`RedMed-Xcode/RedMed/Document/Document.html`). When Connect or the band host needs a Privacy Policy URL, serve that same Privacy text (tagged/hashed on the live host) — never a separate git tree or rewritten public page.
