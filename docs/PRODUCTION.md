# Production readiness — RedMed

Last audited against `main`. App Store submit is **parked** (no paid listing / Connect app yet). Keep `docs/APP-STORE.md` for later; do not treat it as a current ship checklist.

## Permanent rule: local, always loadable

| Surface | Where data lives | How the shell loads |
|---------|------------------|---------------------|
| **Owner app** (RedMed / Preview / Scan) | Keychain + RAM only | Bundled `tapper.html` via `loadHTMLString` — **no network** |
| **Band / passerby phone** | `#d=` fragment only | Hosted static shell; **SW cache-first** after first open (works offline) |
| **PHI on servers** | Never | No profile API, no analytics SDKs that phone home |

Do not add a profile backend. Do not require login to view a tapped card. Do not wait on network when a cached or bundled shell exists.

## Green (code + hosted shell)

| Area | Status |
|------|--------|
| Owner Face ID gate | Unlock → Keychain load with parked LAContext; WK warm **only after** unlock |
| Keychain profile | `WhenPasscodeSetThisDeviceOnly` + `biometryCurrentSet`; save fail-closed; never synchronizable |
| Owner tabs | RedMed · 911 · Aid · NFC; scanners never see NFC |
| NFC Preview + Scan | Both use `fullScreenCover(item:)` after pack — no empty-cover race |
| Passerby shell | Identical triple: `tapper.html` / `tapper/index.html` / `RedMed-Xcode/RedMed/tapper.html` |
| Offline shell | SW cache precaches HTML + pheart / BrandLogo / BrandWordmark |
| Band URI contract | Write only `medicalCardBaseURL + #d=` base64url; vendor/social/short URLs rejected |
| AES-GCM on chip | Public client key by design (EMS decrypts with no account) |
| ATS | Arbitrary loads + local networking **false** |
| Snapshot / pasteboard | Privacy cover + secure pasteboard clear on background |
| Consent after Face ID | `ConsentGateView` on **every** unlock (not first-launch only); never before lock, never on tapper |
| Apple Health import | Parked (`healthKitImportEnabled = false`) |
| App Store package | `PrivacyInfo.xcprivacy` + export flag + `docs/APP-STORE.md` |
| Open PRs | Squash only into `main` |

## Parked until paid Apple Developer + listing

Not doing these in git until you have the Program and an app ID:

1. NFC Tag Reading entitlement — keep `nfcHardwareEnabled = false` and empty `RedMed.entitlements`.
2. HealthKit entitlement — keep `healthKitImportEnabled = false`.
3. `AppConfig.appStoreURL` is `nil` (no placeholder listing).
4. App Store Connect package / Archive.

Legal policies stay in Help.html. User acknowledgments stay on `ConsentGateView` after Face ID.

Custom HTML domain is still TBD (`docs/domain.md`); bands stay on github.io until HTTPS is green.
