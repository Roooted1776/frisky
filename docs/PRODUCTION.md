# Production readiness — RedMed

Last checked against `main` after the 2026-08-31 audit follow-up. App Store submit is **parked** (no paid listing / Connect app yet). Keep `docs/APP-STORE.md` for later; do not treat it as a current ship checklist.

## Permanent rule: local, always loadable

| Surface | Where data lives | How the shell loads |
|---------|------------------|---------------------|
| **Owner app** (RedMed / Preview / Scan) | Keychain + RAM only | Bundled `tapper.html` via `loadHTMLString` — **no network** |
| **Band / passerby phone** | `#d=` fragment only | Hosted static shell; **SW cache-first** after first open (works offline) |
| **PHI on servers** | Never | No profile API, no analytics SDKs that phone home |

Do not add a profile backend. Do not require login to view a tapped card. Do not wait on network when a cached or bundled shell exists.

## True today

| Area | Status |
|------|--------|
| Owner Face ID | Open/return always (`OwnerAppLock`, cream, no heart). Save / Erase prompt again. Opening Edit does not. No consent Face ID toggle |
| Keychain profile | `WhenPasscodeSetThisDeviceOnly`, no biometry ACL; save fail-closed; never synchronizable |
| Location toggle | Honored on Agree. When-In-Use sheet may fire at Agree if Location is on. GPS start/stop is Find Help only |
| Owner tabs | RedMed · 911 · Aid · NFC; scanners never see NFC |
| NFC Preview + Scan | Both use `fullScreenCover(item:)` after pack — no empty-cover race |
| Passerby shell | One file `tapper/index.html`; Xcode copies it to the app bundle as `tapper.html` at build; repo-root `tapper.html` redirects to `/tapper/` |
| Offline shell | SW cache precaches HTML + pheart / BrandLogo / BrandWordmark |
| Band URI contract | Write only `medicalCardBaseURL + #d=` base64url; vendor/social/short URLs rejected |
| AES-GCM on chip | Public client key by design (EMS decrypts with no account) |
| Hospital search | Native: MapKit / Apple Maps. Passerby: OpenStreetMap Overpass (`overpass-api.de`). Disclosed in Help 4.2 |
| ATS | Arbitrary loads + local networking **false** |
| Snapshot / pasteboard | Privacy cover + secure pasteboard clear on background |
| Consent | `ConsentGateView` first start / policy bump only; stored version **4.2** skips ack; Face ID still runs every owner entry; never on tapper |
| Apple Health import | Parked (`healthKitImportEnabled = false`) |
| iOS CI | `workflow_dispatch` only (billing). Does not gate merges |
| Open PRs | Squash only into `main` |

## Blocked / not green

| Area | Status |
|------|--------|
| Band write host | `https://roooted1776.github.io/tapper/` is **404**. `Roooted1776.github.io` does not exist. NFC write is parked, so this build cannot mint new dead bands |
| `redmed.pages.dev` | 404 until CF secrets / Git connect |
| `#d=` tests | No XCTest / JS round-trip vectors |
| App Store package | `PrivacyInfo.xcprivacy` + export flag exist; listing is parked |

## Parked until paid Apple Developer + listing

Not doing these in git until you have the Program and an app ID:

1. NFC Tag Reading entitlement — keep `nfcHardwareEnabled = false` and empty `RedMed.entitlements`.
2. HealthKit entitlement — keep `healthKitImportEnabled = false`.
3. `AppConfig.appStoreURL` is `nil` (no placeholder listing).
4. App Store Connect package / Archive.

Legal policies stay in Help.html. User acknowledgments stay on `ConsentGateView` after Face ID.

Custom HTML domain is still TBD (`docs/domain.md`). Do not write bands until a real HTTPS `/tapper/` is green.
