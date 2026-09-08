# Security

Engineer-facing threat model for RedMed. User-facing copy lives in
`RedMed-Xcode/RedMed/Help.html` (§Security). Product “do not claim” rules:
`docs/DO-NOT.md`. Broader audit trail: `docs/AUDIT.md`.

## Posture (short)

- **Band is readable by design.** Anyone who deliberately taps (~1–2″) can open
  the passerby card. Do not put secrets you would not show a first responder.
- **No RedMed profile cloud.** Owner PHI is Keychain + RAM; band PHI is the
  `#d=` fragment only. Passerby shell is static HTML + SW.
- **Not HIPAA certified.** Local-only ≠ covered-entity / BA program. Help says
  this out loud; do not market otherwise.
- **AES on the chip is packing, not a vault.** Public client key so EMS decrypts
  with no account. Trust boundary is physical band + intentional tap.

## Keychain (`KeychainStore.swift`)

| Property | Value |
|----------|--------|
| Class | `kSecClassGenericPassword` |
| Accessibility | `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` |
| Biometry ACL | **None** (`kSecAttrAccessControl` never set on new writes) |
| Sync | `kSecAttrSynchronizable = false` (no iCloud Keychain, no encrypted backup) |
| Service | `com.redmed.app.profile` |

**Contract:** blob is readable whenever this iPhone is unlocked. Face ID is
**UI-only** (`BiometricAuth`) on post-Agree (once), Edit, Save, Erase, and Load
From Band — not a SecItem ACL. Keychain `load` does not prompt. Viewing the YOU
card does not prompt. 911 / Aid / NFC write / returning launch / tapper do not.

**Legacy:** old `biometryCurrentSet` rows still load. One interactive migrate
(`allowInteractive: true` on owner `restoreOnLaunch`) rewrites to the unbound
form; never write a new biometry ACL. Mid-migrate crash leaves PHI on
`account.migrating`; `load` / `exists` still see it.

**Fail-closed saves:** `persist()` refuses empty RAM over a stored blob. Erase
deletes Keychain first. `exists` unknown SecItem errors → `false` (empty funnel,
not a locked ghost). Scanner / `persists == false` snapshots never touch owner
Keychain.

**Notes** stay Keychain-only (`NFCChipProfile` has no `notes` field).

## `#d=` codec (`ProfileNFCCodec.swift` ↔ `tapper/index.html`)

Wire (new writes):

1. Flat positional array (no JSON keys) — blood / allergies / meds / emergency
   phone / name / dob / conditions / contacts / donor / updated? /
   pregnant? / deafOrVisionImpaired?
2. UTF-8 JSON array sealed with AES-256-GCM (CryptoKit / WebCrypto)
3. Bytes `0x02 \|\| nonce(12) \|\| ciphertext+tag` → base64url after `#d=`

Key material: `SHA-256("RedMed-NFC-AES-GCM-v1")` — public, embedded in both
Swift and tapper. Tamper-without-reseal fails `AES.GCM.open` / WebCrypto decrypt.
Anyone who loads `tapper.html` can forge a valid `#d=`. That is intentional.

Legacy decode still accepts: named JSON objects, pre-AES compact arrays, `0x01`
zlib (and bare zlib), plaintext `{`/`[` first byte. Caps: `MAX_STR=200`,
`MAX_LIST=40`, encoded ≤ 8192, inflate ≤ 64 KiB (both sides).

Write gate (`AppConfig.OwnerBandURI.isValidWriteURL`): exact
`medicalCardBaseURL` + non-empty `#d=` + base64url charset only — rejects
vendor/social/short hosts, query smuggling, second `#`, whitespace.

Lockstep: `node scripts/test-d-codec.mjs` (AES / zlib / compact / URI).

## Tapper XSS surface (`tapper/index.html`)

Profile fields are untrusted once they leave the owner phone (band tap, shared
URL, crafted `#d=`). Controls:

| Sink | Mitigation |
|------|------------|
| YOU card name / blood / lists / contacts | `textContent` + `createElement` only — no `innerHTML` on profile paths |
| `sanitizeProfile` / `sanitizePhone` | type coerce, `MAX_STR`/`MAX_LIST`, phones → `\d+` only (≤20) before `tel:` |
| Aid topic sheets + Overpass hospital rows | `innerHTML` **only** after `esc()` (`& < > "`); Maps `href` is lat/lon numbers + `esc` |
| In-app `__REDMED_PROFILE` embed | `embedProfileJSON` escapes `<` → `\u003c` (+ U+2028/2029) before splice into `<script>` |
| WKWebView navigation | file/about allow; http(s)/tel/mailto/redmed open outside or cancel; default deny. No `WKScriptMessageHandler` |
| CSP (meta + `_headers`) | `default-src 'self'`; `object-src 'none'`; `frame-ancestors 'none'`; `connect-src 'self' https://overpass-api.de` |
| SW cache | shell HTML only; `#d=` is a fragment (never an HTTP cache key); activate drops old `CACHE` names |

**Residual (accepted):**

- CSP keeps `script-src 'unsafe-inline'` / `style-src 'unsafe-inline'` — decrypt,
  locale, SOS, and SW register are inline. Host compromise of the Pages/github.io
  origin is still game over for the shell; field XSS is the surface we harden.
- Public AES key → forged `#d=` can paint any card content (still textContent /
  esc). Integrity of *whose* band is physical custody, not crypto.
- Overpass hospital names/addresses are third-party strings — must stay behind
  `esc()`; do not raw-`innerHTML` Overpass JSON.

## What is out of scope

- Making a passive NTAG216 confidential against a deliberate tap
- HIPAA certification / BA agreements for bracelet contents
- Stopping iOS Background Tag Reading (Apple path; document the caveat)
- Server-side medical ID (there is none)

## Reporting

- Prefer a [GitHub security advisory](https://github.com/Roooted1776/frisky/security/advisories)
  — XSS in `#d=` rendering, Keychain bypass, or owner Face ID gate bypass
  (post-Agree / Edit / Save / Erase / Load From Band)
- Or email **help.RedMed@gmail.com**
- Do not file public issues with live keys or real medical payloads
