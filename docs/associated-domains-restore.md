# Associated Domains (Universal Links)

## Problem this solves

A phone that **already has RedMed installed** should open the **app** on a
band tap — not Safari. Own matching band → foreground Main only (no SOS).
Other person's `#d=` → in-app tap card (scanner shell, no Keychain write, no
SOS). Passerby phones without RedMed still get Safari; the card opens, and
SOS is **explicit** (SOS · Locate Me) — band tap never auto-arms the siren
(pocket/clasp must not scream).

AASA is already live (`apple-app-site-association` + `.well-known/`,
paths `/tapper/*`). The entitlement is what is parked.

## Rejected: local-network / BLE band ranging

Do **not** add Bonjour, Multipeer, Wi‑Fi Aware, CoreBluetooth scanning, or
"find bands nearby" to suppress SOS. Product chip is **passive NXP
NTAG216** — no battery, no BLE, no Wi‑Fi. It never appears on a local
network and cannot advertise a location. HF NFC only couples at
deliberate antenna range (`AppConfig.BraceletRF`). Proximity physics,
no band-tap auto-arm, and Universal Links are the controls.

## Currently parked (personal team signing)

`RedMed.entitlements` has **no** `com.apple.developer.associated-domains` key.
Free / personal Apple Developer teams cannot provision the **Associated
Domains** capability — Xcode automatic signing fails the whole build with
"Cannot create a iOS App Development provisioning profile" while the
entitlement is present but the account is a personal team. Same class of
problem as CoreNFC — see `docs/NFC-RESTORE.md` for the parked-entitlement
pattern this mirrors.

While parked, `onContinueUserActivity` never fires. Safari may still open
from Background Tag Reading; SOS does **not** auto-arm on that page
(`shouldAutoArm` is false). Explicit SOS · Locate Me still works.

## Restore (paid Program)

1. Add back to `RedMed.entitlements`:
   ```xml
   <key>com.apple.developer.associated-domains</key>
   <array>
       <string>applinks:roooted1776.github.io</string>
   </array>
   ```
2. Confirm `apple-app-site-association` (repo root and `.well-known/`) is
   served over HTTPS at the domain root with the correct `appID` (Team ID +
   `com.redmed.app`) and `paths` limited to `/tapper/*`.
3. Xcode → Signing & Capabilities → **Associated Domains** should show the
   host with no errors once the team has a paid Apple Developer Program
   membership.
4. Device tests:
   - RedMed installed + tap **own** band (matches Keychain) → app
     foreground, no Safari, no SOS, no foreign card sheet.
   - RedMed installed + tap **another** RedMed band → in-app tap card
     (no Keychain write, no SOS).
   - RedMed **not** installed + tap any band → Safari card, no auto-arm;
     helper taps SOS · Locate Me for siren + `tel:`.
5. If the custom domain (`docs/domain.md`) goes live before this is
   restored, update the `applinks:` host and `apple-app-site-association`
   together.

## Park again (optional)

1. Remove `com.apple.developer.associated-domains` from `RedMed.entitlements`.
2. Leave `onContinueUserActivity` in place — it is a no-op without the
   entitlement.
