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
| Owner Face ID gate | Owner RedMed user page (stored ID) then Edit / Save / Erase (`force: true`). No cream lock in front of Main — 911 / Aid / NFC stay reachable. Relock the RedMed view on `.background` only. No Face ID toggle on Before you continue (Haptic + Location only). Profile restores on Main appear (device-unlocked Keychain); Face ID gates display of the YOU card |
| Crash motion | Starts after owner Main paints. Stops CoreMotion on `.background`. Restarts on `.active`. Does not stop on `.inactive` (Face ID on RedMed user page / Edit / Save / Erase). Armed siren is independent. Scanner / tapper never start it. |
| Keychain profile | `WhenPasscodeSetThisDeviceOnly`, no biometry ACL; save fail-closed; never synchronizable |
| Location toggle | Honored on Agree. When-In-Use sheet may fire at Agree if Location is on. GPS start/stop is Find Help only |
| Owner tabs | RedMed · 911 · Aid · NFC; scanners never see NFC |
| NFC Preview + Scan | Both use `fullScreenCover(item:)` after pack — no empty-cover race. Parked Share Band URL is live `medicalCardBaseURL#d=` (Shortcuts / NFC Tools). Never Linked from share |
| Passerby shell | One file `tapper/index.html`; Xcode copies it to the app bundle as `tapper.html` at build; repo-root `tapper.html` redirects to `/tapper/` |
| Offline shell | SW cache precaches HTML + pheart / BrandLogo / BrandWordmark |
| Band URI contract | Write only `medicalCardBaseURL + #d=` base64url; vendor/social/short URLs rejected |
| AES-GCM on chip | Public client key by design (EMS decrypts with no account) |
| Hospital search | Native: MapKit / Apple Maps. Passerby: OpenStreetMap Overpass (`overpass-api.de`). Disclosed in Help 4.3 |
| ATS | Arbitrary loads + local networking **false** |
| Snapshot / pasteboard | Privacy cover + secure pasteboard clear on background |
| Consent | `ConsentGateView` every cold start; stored version **4.7** is legal record only (does not skip ack); never Face ID on that path; never on tapper |
| Apple Health import | Parked (`healthKitImportEnabled = false`) |
| iOS CI | `workflow_dispatch` only (billing). Does not gate merges |
| `#d=` codec | `node scripts/test-d-codec.mjs` — AES / zlib / compact / URI lockstep |
| Open PRs | Squash only into `main` |

## Blocked / not green

| Area | Status |
|------|--------|
| Band write host | Live: `https://roooted1776.github.io/tapper/` (smoke green 2026-08-31). CoreNFC write is still parked. NFC tab Share Band URL is that host + `#d=` for a blank NTAG216. Linked still needs paid NFC Tag Reading |
| `redmed.pages.dev` | 404 until CF secrets / Git connect |
| XCTest | No iOS test target. Codec lockstep is Node, not XCTest |
| App Store package | `PrivacyInfo.xcprivacy` + export flag exist; listing is parked |

## Parked until paid Apple Developer + listing

Not doing these in git until you have the Program and an app ID:

1. NFC Tag Reading entitlement — keep `nfcHardwareEnabled = false` and empty `RedMed.entitlements`.
2. HealthKit entitlement — keep `healthKitImportEnabled = false`.
3. `AppConfig.appStoreURL` is `nil` (no placeholder listing).
4. App Store Connect package / Archive.

Legal policies stay in Help.html. User acknowledgments stay on `ConsentGateView` (every cold start; Agree this process stays in Main). Face ID is not in front of that screen.

Custom HTML domain is still TBD (`docs/domain.md`). Write base `/tapper/` is green. Do not flip `nfcHardwareEnabled` until the paid NFC entitlement can sign.
