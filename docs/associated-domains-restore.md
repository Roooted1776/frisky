# Associated Domains (Universal Links)

## Problem this solves

The wearer's band on their wrist must not **Safari-hijack their own iPhone**
when the phone is nearby (pocket / clasp / Background Tag Reading). That is
not only the SOS siren — opening the full passerby card on the owner's phone
is the interference.

**Fix:** Associated Domains. Hosted `/tapper/` is a Universal Link. With
RedMed installed, iOS opens the **app** instead of Safari.

| Phone | Band tap |
| --- | --- |
| RedMed installed, `#d=` matches owner Keychain | App foreground only — no Safari, no SOS, no card sheet |
| RedMed installed, other person's `#d=` | In-app tap card (no Keychain write, no SOS) — does not steal the helper path |
| RedMed **not** installed | Safari card + band-tap SOS auto-arm (passerby / EMT unchanged) |

AASA is live (`apple-app-site-association` + `.well-known/`, paths
`/tapper`, `/tapper/`, `/tapper/*`, plus `components` / `appIDs`). Entitlement
is in `RedMed.entitlements`. After merge, re-run Publish tapper /
`scripts/publish-github-io.sh` so github.io picks up the widened AASA.

## Rejected: local-network / BLE band ranging

Do **not** add Bonjour, Multipeer, Wi‑Fi Aware, CoreBluetooth, or "find bands
nearby." NTAG216 is **passive** — no battery, no radio. It never appears on a
local network. HF NFC physics + Universal Links are the controls.

## Signing note (paid Program)

`applinks:roooted1776.github.io` is in `RedMed.entitlements`. The App ID
`com.redmed.app` must have **Associated Domains** enabled on a **paid** Apple
Developer Program team. Personal / free teams cannot provision that capability
— Automatic Signing fails until the capability is on the App ID or you park
the entitlement again (empty `<dict></dict>`, same pattern as CoreNFC).

## Device tests

1. RedMed installed + tap **own** wrist band → app foreground (or already
   open stays put), **no Safari**, no SOS auto-arm.
2. RedMed installed + tap **another** RedMed band → in-app tap card, no
   Keychain write, no SOS.
3. RedMed **not** installed + tap any band → Safari card + SOS auto-arm.
4. After custom domain cutover (`docs/domain.md`), update `applinks:` host and
   both AASA files together.

## Park again (personal team only)

1. Remove `com.apple.developer.associated-domains` from `RedMed.entitlements`
   (leave an empty `<dict></dict>` if NFC / HealthKit are also parked).
2. Leave `onContinueUserActivity` in place — no-op without the entitlement.
3. Without the entitlement, wrist proximity can Safari-open again on a phone
   that has RedMed installed.
