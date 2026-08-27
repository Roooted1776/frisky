# Production readiness — RedMed

Last audited against `main` after #416–#419. App Store Review sign-off: `docs/APP-STORE.md`.

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
| First-launch consent | After Face ID only (`ConsentGateView`); never before lock, never on tapper |
| Apple Health import | Parked (`healthKitImportEnabled = false`) |
| App Store package | `PrivacyInfo.xcprivacy` + export flag + `docs/APP-STORE.md` |
| Open PRs | Squash only into `main` |

## Blockers before live NFC / listing ID

These cannot be finished in git alone.

1. **Paid Apple Developer + NFC Tag Reading** — entitlements empty; `nfcHardwareEnabled = false`.
2. **App Store listing ID** — `AppConfig.appStoreURL` placeholder `id0000000000` (setup QR only).
3. **Signing** — Archive from Xcode on team `33F9FQ4VBU`.
4. **Custom HTML domain** — still TBD; bands stay on github.io until HTTPS is green (`docs/domain.md`).

## Ship sequence

1. Pull `main` into `/Users/claude/Documents/frisky`.
2. Tick `PrivacyInfo.xcprivacy` on the RedMed target.
3. Archive on the paid team.
4. Fill Connect from `docs/APP-STORE.md` (including **not** a regulated medical device).
5. Flip NFC / Health flags only after those capabilities exist on the App ID.
6. Set real `appStoreURL` after Connect assigns an ID.
7. Tag release on `main`.
