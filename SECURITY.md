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
| Owner profile on device | Never leaves phone | Keychain `WhenPasscodeSetThisDeviceOnly`, Face ID / passcode gates, RAM purge on background, snapshot cover, vault file protection |
| Passerby `#d=` payload | Any phone that taps the band | Safe DOM render (`textContent`), length caps, phone sanitization, CSP + security headers on Pages. **No Face ID / biometrics / login / passcode** on `tapper.html` — tap-to-view is ungated |
| AES-GCM on the band | Packing / obfuscation only | Public client key by design — EMS must decrypt with no account. Not confidentiality against a deliberate tap |
| GPS | On-device display only | When-In-Use; never uploaded to RedMed |

## Reporting a vulnerability

1. Prefer a private [GitHub security advisory](https://github.com/Roooted1776/frisky/security/advisories/new) on `Roooted1776/frisky`.
2. Or email `help.RedMed@gmail.com` with steps to reproduce. Do **not** attach real medical payloads or live API keys.
3. You should get an initial reply within a few days. Fixes land on `main` via PR; we do not run a paid bug bounty.

In-scope: XSS or HTML injection via `#d=`, Keychain / vault bypass, Face ID gate bypass, service-worker cache poisoning of the shell, credential or secret leaks in the repo, privilege escalation from scanner shell into owner Keychain.

Out of scope: cloning a passive NFC band (same as photocopying a wallet medical card), social engineering the owner, physical device access after unlock, third-party OS bugs (including iOS Background Tag Reading opening a written NDEF URI on a deliberate ~1–2″ tap even when the phone is off or locked — Apple path, not RedMed).

## Hardening checklist (repo)

- Passerby HTML: `textContent` for PHI fields; no `eval`; zlib inflate capped; CSP + `nosniff` / `frame-ancestors` / referrer policy via `_headers` (live on Pages paths) + matching meta CSP (`upgrade-insecure-requests`).
- Owner: `OwnerAppLock` + `BiometricAuth` (reuse duration 0); scanner snapshots use `ProfileData(persisting: false)`.
- Passerby `tapper.html` / in-app Preview: never call `BiometricAuth`, WebAuthn, or any login gate — band tap must open RedMed · 911 · Aid with zero authentication.
- Keychain profile: `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` + non-synchronizable. Load of a legacy `WhenUnlockedThisDeviceOnly` blob re-saves under the stronger class (best-effort migration).
- Vault: `HIPAAOfflineVault` complete protection + backup exclusion; basename-only file paths; history timestamps/kind only (unlock fail / NFC fail / capture cover — no field values).
- Help → Erase all RedMed data (Face ID): deletes Keychain profile + vault; does not remote-wipe the band.
- No analytics / crash SDKs that phone home PHI.
