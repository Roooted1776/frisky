# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| `main` (1.1.x) | Yes |
| Older tags / abandoned feature branches | No |

RedMed is a local-only iOS medical ID + emergency assist app. There is no RedMed profile backend. Treat `main` as production: Cloudflare Pages must serve the passerby card from this repo’s `get/` at `https://redmed.pages.dev/get/`.

## Threat model (short)

| Asset | Intentional exposure | Defended |
|-------|----------------------|----------|
| Owner profile on device | Never leaves phone | Keychain `WhenUnlockedThisDeviceOnly`, Face ID / passcode gates, RAM purge on background, snapshot cover, vault file protection |
| Passerby `#d=` payload | Any phone that taps the band | Safe DOM render (`textContent`), length caps, phone sanitization, CSP + security headers on Pages |
| AES-GCM on the band | Packing / obfuscation only | Public client key by design — EMS must decrypt with no account. Not confidentiality against a deliberate tap |
| GPS | On-device display only | When-In-Use; never uploaded to RedMed |

## Production deploy check (do this after every Pages change)

```bash
curl -sI https://redmed.pages.dev/get/ | tr -d '\r' | grep -iE 'content-security-policy|x-frame-options|referrer-policy|x-content-type-options'
curl -sL https://redmed.pages.dev/get/ | head -c 400   # must be the medical card shell, not a marketing setup page
curl -sI https://redmed.pages.dev/get/sw.js | head -5   # must be 200, not 404
```

If `/get/` is a setup landing page, or `sw.js` / `card.html` 404, bracelet taps are broken — redeploy this repo’s root (or `get/` output) to the `redmed` Pages project.

## Reporting a vulnerability

1. Prefer a private [GitHub security advisory](https://github.com/Roooted1776/frisky/security/advisories/new) on `Roooted1776/frisky`.
2. Or email `help.RedMed@gmail.com` with steps to reproduce. Do **not** attach real medical payloads or live API keys.
3. You should get an initial reply within a few days. Fixes land on `main` via PR; we do not run a paid bug bounty.

In-scope: XSS or HTML injection via `#d=`, Keychain / vault bypass, Face ID gate bypass, service-worker cache poisoning of the shell, credential or secret leaks in the repo, privilege escalation from scanner shell into owner Keychain, wrong production shell at `medicalCardBaseURL`.

Out of scope: cloning a passive NFC band (same as photocopying a wallet medical card), social engineering the owner, physical device access after unlock, third-party OS bugs.

## Hardening checklist (repo)

- Passerby HTML: `textContent` for PHI fields; no `eval`; zlib inflate capped; CSP + `nosniff` / `frame-ancestors` / referrer policy via `_headers` (verify live — meta CSP cannot enforce `frame-ancestors`).
- Owner: `OwnerAppLock` + `BiometricAuth` (reuse duration 0); scanner snapshots use `ProfileData(persisting: false)`.
- Keychain: update-or-add (never delete-then-add).
- Vault: `HIPAAOfflineVault` complete protection + backup exclusion; basename-only file paths; UI lock purges in-RAM events.
- SW: fan HTML shells only into shell keys; bump `redmed-get-vN` in lockstep across `sw.js`, `get/sw.js`, and the bundled copy.
- No analytics / crash SDKs that phone home PHI.
