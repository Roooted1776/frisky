# Production readiness — RedMed

Last audited against `main` (v1.1 / build 2). Product is local-only medical ID + emergency assist. No profile backend.

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
| Keychain profile | `WhenPasscodeSetThisDeviceOnly` + `biometryCurrentSet`; legacy migrate on load; never synchronizable |
| Owner tabs | RedMed · 911 · Aid · NFC; scanners never see NFC |
| NFC Preview + Scan | Both use `fullScreenCover(item:)` after pack — no empty-cover race |
| Passerby shell | Identical triple: `tapper.html` / `tapper/index.html` / `RedMed-Xcode/RedMed/tapper.html` |
| Offline shell | SW `redmed-tapper-v118` precaches HTML + pheart / BrandLogo / BrandWordmark |
| Band URI contract | Write only `medicalCardBaseURL + #d=` base64url; vendor/social/short URLs rejected |
| AES-GCM on chip | Public client key by design (EMS decrypts with no account) |
| ATS | Arbitrary loads + local networking **false** |
| Snapshot / pasteboard | Privacy cover + secure pasteboard clear on background |
| Live github.io | `/tapper/`, assets, SW return 200 |
| Open PRs | Must be none before ship; squash only into `main` |

## Blockers before App Store / hardware NFC

These cannot be finished in git alone.

1. **Paid Apple Developer + NFC Tag Reading**
   - `RedMed.entitlements` is currently **empty** (no `com.apple.developer.nfc.readersession.formats`).
   - `AppConfig.nfcHardwareEnabled = false` — intentional until the capability is on App ID `com.redmed.app`.
   - After Apple enables NFC: add entitlement in Xcode → set `nfcHardwareEnabled = true` → real Write/Scan on NXP NTAG216.
   - See `docs/NFC-RESTORE.md`.

2. **App Store listing ID**
   - `AppConfig.appStoreURL` still uses placeholder `id0000000000`.
   - Replace after App Store Connect assigns a real app ID (setup QR only — never written to the band).

3. **Signing / CI**
   - iOS build workflow is **manual only** (`workflow_dispatch`) — GitHub Actions billing was blocking runners.
   - Restore push/PR triggers after Billing is green; Archive from Xcode on the paid team for TestFlight.

4. **Custom domain (optional)**
   - Band base is `https://roooted1776.github.io/tapper/` until `getredmed.com` DNS + Pages custom domain are green.
   - Do **not** flip `medicalCardBaseURL` while the domain NXDOMAINs — existing bands would break.

## Soft polish (not ship-stoppers)

- Stale remote branches (`fix-preview-button-link`, `organize-swift-folders`, …): delete after merge; sole long-lived branch is `main`.
- GitHub Pages does not apply Cloudflare `_headers` / `_redirects`; meta CSP + JS redirects cover github.io. CF remains preferred when `redmed.pages.dev` / custom domain is live.
- Help → Privacy / Terms / Security are full copy in `Help.html`; thin redirect stubs exist for deep links.
- Device QA matrix (required once): Face ID unlock, Edit save, Preview, Simulate Scan, 911 call sheet, Aid, erase, background snapshot cover, real band write after NFC entitlement.

## Ship sequence

1. Pull `main` into `/Users/claude/Documents/frisky` (GitHub Desktop Fetch → Pull).
2. Xcode Archive on paid team with NFC capability when ready.
3. Flip `nfcHardwareEnabled` only after entitlement is present and a blank NTAG216 verifies.
4. Set real `appStoreURL` from App Store Connect.
5. Tag release on `main` (e.g. `v1.1.0`); Pages deploy stays automatic from `main`.

## Do not ship with

- Experimental long-lived branches merged via merge-commit (squash only).
- `nfcHardwareEnabled = true` without NFC entitlement (runtime session failures).
- `medicalCardBaseURL` pointed at a dead host.
- Secrets, analytics SDKs, or network profile upload (product rule: local only).
