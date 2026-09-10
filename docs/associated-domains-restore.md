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
| RedMed installed, other person's `#d=` (or empty owner funnel) | Ungated in-app tap card above ConsentGate — no Face ID, no Before You Continue, no Keychain write, no SOS |
| RedMed **not** installed | Safari card + band-tap SOS auto-arm (passerby / EMT unchanged) |

AASA is live (`apple-app-site-association` + `.well-known/`, paths
`/tapper`, `/tapper/`, `/tapper/*`, plus `components` / `appIDs`). After
restore + merge, re-run Publish tapper / `scripts/publish-github-io.sh` so
github.io picks up the widened AASA.

**Safari fallback (AASA stale / UL miss / entitlement parked):** passerby
`tapper` tries `redmed://band#d=` before SOS auto-arm. Installed RedMed
claims it (same quiet rules via `onOpenURL`). No app → page stays put → SOS
arms after ~650ms. Custom scheme needs no Associated Domains entitlement.

## Currently parked (personal team signing)

`AppConfig.associatedDomainsEnabled = false` and `RedMed.entitlements` has
no `applinks:` key (NFC Tag Reading may already be present — add
`applinks:`, do not wipe the NFC key). Personal / free Apple Developer
teams cannot provision Associated Domains, so Automatic Signing fails
("Cannot create a iOS App Development provisioning profile") while the
entitlement is present — the same class of problem as CoreNFC
(`docs/NFC-RESTORE.md`).

Leave `onContinueUserActivity` in place — no-op without the entitlement.
Without the entitlement, wrist proximity can Safari-open again on a phone
that has RedMed installed. Safari `redmed://band` is the remaining claim
path.

## Rejected: local-network / BLE band ranging

Do **not** add Bonjour, Multipeer, Wi‑Fi Aware, CoreBluetooth, or "find bands
nearby." NTAG216 is **passive** — no battery, no radio. It never appears on a
local network. HF NFC physics + Universal Links are the controls.

## Restore (paid Program)

1. Put `com.apple.developer.associated-domains` → `applinks:roooted1776.github.io`
   back in `RedMed.entitlements`.
2. Set `AppConfig.associatedDomainsEnabled = true`.
3. Developer portal → App ID `com.redmed.app` → enable **Associated Domains**.
4. Xcode → Signing & Capabilities → **Associated Domains** (same `applinks:`).
5. Build with a paid Apple Developer Program team (not a personal / free team).
6. After custom domain cutover (`docs/domain.md`), update `applinks:` host and
   both AASA files together.

## Device tests

1. RedMed installed + tap **own** wrist band → app foreground (or already
   open stays put), **no Safari**, no SOS auto-arm, no tap card.
2. RedMed installed + tap **another** RedMed band → ungated in-app tap card
   (no Face ID / Before You Continue / login), no Keychain write, no SOS.
3. RedMed **not** installed + tap any band → Safari card + SOS auto-arm
   (no login, no biometrics, no start screen).
4. After custom domain cutover (`docs/domain.md`), update `applinks:` host and
   both AASA files together.

## Park again (personal team only)

1. Remove `com.apple.developer.associated-domains` from `RedMed.entitlements`
   (leave an empty `<dict></dict>` if NFC / HealthKit are also parked).
2. Set `AppConfig.associatedDomainsEnabled = false`.
3. Leave `onContinueUserActivity` in place — no-op without the entitlement.
4. Without the entitlement, wrist proximity can Safari-open again on a phone
   that has RedMed installed.
