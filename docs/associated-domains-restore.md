# Associated Domains (Universal Links)

## Problem this solves

A phone that **already has RedMed installed** must not open Safari and
auto-arm the SOS siren when it taps **any** RedMed band (owner's own wrist
band, or another band nearby). Accidental clasp / pocket taps are the
usual trigger via iOS Background Tag Reading.

**Fix:** Associated Domains. The hosted `/tapper/` URL becomes a Universal
Link. With RedMed installed, iOS brings the **app** to the foreground
instead of Safari. `RedMedApp.onContinueUserActivity` drops the URL /
`#d=` — no decode into RAM, no SOS auto-arm. Owner already has the YOU
card; use NFC Scan (`?src=app`, no auto-arm) to read someone else's band.

Phones **without** RedMed still get Safari + band-tap SOS auto-arm
(passerby / EMT path unchanged).

AASA is already live (`apple-app-site-association` + `.well-known/`,
paths `/tapper/*`). The entitlement is what is parked.

## Rejected: local-network / BLE band ranging

Do **not** add Bonjour, Multipeer, Wi‑Fi Aware, CoreBluetooth scanning, or
"find bands nearby" to suppress SOS. Product chip is **passive NXP
NTAG216** — no battery, no BLE, no Wi‑Fi. It never appears on a local
network and cannot advertise a location. HF NFC only couples at
deliberate antenna range (`AppConfig.BraceletRF`). Proximity physics and
Universal Links are the controls; inventing a radio the band does not
have will not work.

## Currently parked (personal team signing)

`RedMed.entitlements` has **no** `com.apple.developer.associated-domains` key.
Free / personal Apple Developer teams cannot provision the **Associated
Domains** capability — Xcode automatic signing fails the whole build with
"Cannot create a iOS App Development provisioning profile" while the
entitlement is present but the account is a personal team. Same class of
problem as CoreNFC — see `docs/NFC-RESTORE.md` for the parked-entitlement
pattern this mirrors.

While parked, `onContinueUserActivity` never fires. A phone with RedMed
installed tapping any RedMed band behaves like a passerby's phone:
Safari opens the hosted `tapper.html#d=…` card and may auto-arm SOS.
Passerby tap-to-view was always Safari-only; the gap is owner
self-trigger until this entitlement is restored.

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
   - RedMed installed + tap **own** band → app foreground, no Safari, no SOS.
   - RedMed installed + tap **another** RedMed band → same (app foreground,
     `#d=` dropped). Use in-app NFC Scan to view that profile.
   - RedMed **not** installed + tap any band → Safari card + SOS auto-arm.
5. If the custom domain (`docs/domain.md`) goes live before this is
   restored, update the `applinks:` host and `apple-app-site-association`
   together.

## Park again (optional)

1. Remove `com.apple.developer.associated-domains` from `RedMed.entitlements`.
2. Leave `onContinueUserActivity` in place — it is a no-op without the
   entitlement.
