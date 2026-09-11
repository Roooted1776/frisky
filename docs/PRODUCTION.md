# Production readiness — RedMed

Last checked against `main` after Load From Band + empty-funnel Save pass (2026-09). App Store submit is **parked** (no paid listing / Connect app yet). Keep `docs/APP-STORE.md` for later; do not treat it as a current ship checklist.

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
| Owner Face ID gate | Post-Agree once (first launch / policy bump / after Erase), returning cold re-entry once per process (cream over warm Main), then Edit / Save / Erase / Load From Band (`force: true`). **Not** viewing the YOU card. Same-session resume does not re-prompt. No Face ID toggle on Before you continue (Haptic only). Profile restores under Face ID cream (device-unlocked Keychain) without a second view unlock |
| Clear vs Erase | Edit has field-level Clear only (blood type / birth date) — no Clear-all. Partial clear + Save can persist; blank-all + Save refuses empty (alert: Use Erase to Wipe when stored, else fill-first; no Face ID). Full wipe is Help → **Erase All User Data** (Face ID). Band is not wiped remotely |
| Empty-funnel Save | Fresh / Erase empty funnel: Fill → Edit (Face ID) → Save (Face ID `force: true`) → `persist()`. Empty draft Save refused (no blank Keychain / no gate flip). Blank-over-stored same refuse; Erase is the wipe path |
| Load From Band | Code PASS; UI on when CoreNFC hardware flag is true. Path: read → empty alert / match→link / mismatch+existing→Replace / empty funnel→adopt. Face ID before `authenticateAndLinkMatchingBand` and `authenticateAndAdopt` → `adoptBandSnapshot`. Write ungated. Portal Tag Reading still required for device sessions — see `docs/NFC-RESTORE.md` |
| Crash motion | Foreground + `.inactive` only. Starts after owner Main paints. Stops CoreMotion on `.background` (no short grace / `beginBackgroundTask` linger — parked). Restarts on `.active`. Does **not** stop on `.inactive` (Face ID on post-Agree / Edit / Save / Erase / Load From Band, Control Center, switcher peek) — that keep-listening path is the only intentional “still around for a moment” behavior. Armed siren (`audio` UIBackgroundMode) is independent. No motion background mode. Scanner / tapper never start it. |
| Keychain profile | `WhenPasscodeSetThisDeviceOnly`, **no** biometry ACL (`kSecAttrAccessControl` never set). Face ID is UI-only (`BiometricAuth`), not SecItem. Save fail-closed; never synchronizable. Legacy `biometryCurrentSet` rows migrate once on load — never write a new bound item |
| Location | On as part of Agree (no in-app toggle). When-In-Use after post-Agree Face ID. GPS start/stop are Find Help only. Off switch is iOS Settings |
| Owner tabs | RedMed · 911 · Aid · NFC; scanners never see NFC |
| NFC Preview + Scan | Preview uses `fullScreenCover(item:)` after pack — no empty-cover race. In-repo CoreNFC parked (`nfcHardwareEnabled = false`, no TAG entitlement, no usage string); restore via `docs/NFC-RESTORE.md`. Portal Tag Reading still required for device Write. Storefront “write from the app” stays off until Write is proven on blank NTAG216 — blank chips + Share honesty until then (`docs/ADVERTISING.md`) |
| Passerby shell | One file `tapper/index.html`; Xcode copies it to the app bundle as `tapper.html` at build; repo-root `tapper.html` redirects to `/tapper/` |
| Offline shell | SW cache precaches HTML + pheart / BrandLogo / BrandWordmark |
| Band URI contract | Write only `medicalCardBaseURL + #d=` base64url; vendor/social/short URLs rejected |
| AES-GCM on chip | Public client key by design (EMS decrypts with no account) |
| Hospital search | Native: MapKit / Apple Maps. Passerby: OpenStreetMap Overpass (`overpass-api.de`). Disclosed in Help 4.3 |
| ATS | Arbitrary loads + local networking **false** |
| Snapshot / pasteboard | Privacy cover + secure pasteboard clear on background |
| Consent | `ConsentGateView` on first launch or policy bump (**4.13**); Agree + checkbox only on that page (no Face ID there); Face ID runs after Agree and on every cold re-entry (cream over warm Main; restore races underneath); When-In-Use once when still notDetermined; same-session resume does not re-prompt; never on tapper |
| Apple Health import | Parked (`healthKitImportEnabled = false`) |
| iOS CI | Push/PR on `RedMed-Xcode/**` (unsigned Simulator compile). Manual `workflow_dispatch` still works. No XCTest |
| `#d=` codec | `node scripts/test-d-codec.mjs` — AES / zlib / compact / URI lockstep |
| Open PRs | Squash only into `main` |

## Blocked / not green

| Area | Status |
|------|--------|
| Band write host | Live: `https://roooted1776.github.io/tapper/` (smoke green 2026-08-31). In-repo CoreNFC parked (`nfcHardwareEnabled = false`, no TAG entitlement, no `NFCReaderUsageDescription`). Portal Tag Reading on `com.redmed.app` still required. Associated Domains is parked (`associatedDomainsEnabled = false`, no `applinks:` key) so Automatic Signing works on a personal/free team for that capability. Safari still tries `redmed://band#d=` before SOS. Restore Associated Domains via `docs/associated-domains-restore.md`. Write-from-app storefront gate: `docs/ADVERTISING.md` / `docs/NFC-RESTORE.md` |
| `redmed.pages.dev` | 404 until CF secrets / Git connect |
| XCTest | No iOS test target. Codec lockstep is Node, not XCTest |
| App Store package | `PrivacyInfo.xcprivacy` + export flag exist; listing is parked |

## Parked until paid Apple Developer + listing

Not doing these in git until you have the Program and an app ID:

1. NFC Tag Reading on App ID `com.redmed.app` (portal + Xcode capability), then restore in-repo flag, entitlement, and usage string — see `docs/NFC-RESTORE.md`.
2. Associated Domains on App ID `com.redmed.app`, then restore in-repo flag + `applinks:` — see `docs/associated-domains-restore.md`.
3. HealthKit entitlement — keep `healthKitImportEnabled = false`.
4. `AppConfig.appStoreURL` is `nil` (no placeholder listing).
5. App Store Connect package / Archive.

Legal policies stay in `Document/Document.html`. User acknowledgments stay on `ConsentGateView` (first launch / policy bump; Agree this process stays in Main). Face ID runs **after** Agree — not on Before You Continue, and not as an app-open cream lock in front of Main.

Custom HTML domain is still TBD (`docs/domain.md`). Write base `/tapper/` is green.
