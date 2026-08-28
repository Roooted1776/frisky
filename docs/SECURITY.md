# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| `main` (1.1.x) | Yes |
| Older tags / abandoned feature branches | No |

RedMed is a local-only iOS medical ID + emergency assist app. There is no RedMed profile backend. Treat `main` as production: Cloudflare Pages serves the passerby card from it.

## Threat model (short)

| Asset | Intentional exposure | Defended |
|-------|----------------------|----------|
| Owner profile on device | Never leaves phone | Keychain `WhenPasscodeSetThisDeviceOnly` + `biometryCurrentSet` ACL, Face ID / passcode gates, parked LAContext cleared on background, RAM purge, snapshot cover, vault file protection |
| Passerby `#d=` payload | Any phone that taps the band | Safe DOM render (`textContent`), length caps, phone sanitization, CSP + security headers on Pages. **No Face ID / biometrics / login / passcode** on `tapper.html` — tap-to-view is ungated |
| AES-GCM on the band | Packing / obfuscation only | Public client key by design — EMS must decrypt with no account. Not confidentiality against a deliberate tap |
| GPS | On-device display only | When-In-Use; never uploaded to RedMed |
| Apple Health characteristics | Owner opt-in read of birth date + blood type | HealthKit read-only; never written back; never uploaded; never on passerby tapper |

## Reporting a vulnerability

1. Prefer a private [GitHub security advisory](https://github.com/Roooted1776/frisky/security/advisories/new) on `Roooted1776/frisky`.
2. Or email `help.RedMed@gmail.com` with steps to reproduce. Do **not** attach real medical payloads or live API keys.
3. You should get an initial reply within a few days. Fixes land on `main` via PR; we do not run a paid bug bounty.

In-scope: XSS or HTML injection via `#d=`, Keychain / vault bypass, Face ID gate bypass, service-worker cache poisoning of the shell, credential or secret leaks in the repo, privilege escalation from scanner shell into owner Keychain.

Out of scope: cloning a passive NFC band (same as photocopying a wallet medical card), social engineering the owner, physical device access after unlock, third-party OS bugs (including iOS Background Tag Reading opening a written NDEF URI on a deliberate ~1–2″ tap even when the phone is off or locked — Apple path, not RedMed).

## Hardening checklist (repo)

- Passerby HTML: `textContent` for PHI fields; no `eval`; zlib inflate capped; CSP + `nosniff` / `frame-ancestors` / referrer policy via `_headers` (live on Pages paths) + matching meta CSP (`upgrade-insecure-requests`).
- Owner: `OwnerAppLock` + `BiometricAuth` (reuse duration **always 0** for UI — Apple's max is 300s and would skip the owner gate off a recent device unlock; parked LAContext for SecItem only, cleared on background / erase / lock); scanner snapshots use `ProfileData(persisting: false)`. Apple does not timeout `evaluatePolicy`. RedMed backstops: 4.5s/5s watchdogs when the scene is `.active` (no sheet), 60s when `.inactive` (slow passcode vs ghost sheet), and a 90s `BiometricAuth.timedOut` if the callback never fires — without it, a hung sheet permanently bricks any caller that hard-guards re-entrancy on its own busy flag (Vault History unlock, Erase, NFC write) until the app is force-quit. Face ID locks after 5 failed matches until the device passcode succeeds. The UIKit app-switcher cream cover (`SnapshotSafeCover`) skips the lock shell so a hung Face ID evaluate cannot hide **Proceed**.
- Passerby `tapper.html` / in-app Preview: never call `BiometricAuth`, WebAuthn, or any login gate — band tap must open RedMed · 911 · Aid with zero authentication.
- Keychain profile: `SecAccessControl` with `WhenPasscodeSetThisDeviceOnly` + `biometryCurrentSet` (re-enroll invalidates). `KeychainStore.save` writes bound items only — it does not fall back to an unbound `WhenUnlockedThisDeviceOnly` blob if the ACL write fails (Edit Save returns false). Legacy unbound items still load, then migrate best-effort via bound save. Never synchronizable.
- Edit fields: no autocorrect / spellcheck / smart dashes / content type; smart insert-delete off; password rules nil; input assistant bar groups cleared — reduce system dictionary / autofill learning of PHI.
- ATS: `NSAllowsArbitraryLoads` and `NSAllowsLocalNetworking` explicit false (app is local-only for PHI; band URL is HTTPS).
- Vault: `HIPAAOfflineVault` complete protection + backup exclusion; basename-only file paths; history timestamps/kind only (unlock fail / NFC fail / capture cover — no field values).
- Help → Erase all RedMed data (Face ID): deletes Keychain profile + vault; does not remote-wipe the band.
- No analytics / crash SDKs that phone home PHI.
