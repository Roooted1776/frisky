# Associated Domains (Universal Links)

`RedMedApp.onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` exists so a
device that already has RedMed installed opens the app (foreground only,
same as tapping the icon) instead of Safari when its *own* band is tapped.
Nothing renders from the intercepted URL — the owner already has full app
access, and the tapped `#d=` payload is deliberately dropped.

## Currently parked (personal team signing)

`RedMed.entitlements` has **no** `com.apple.developer.associated-domains` key.
Free / personal Apple Developer teams cannot provision the **Associated
Domains** capability — Xcode automatic signing fails the whole build with
"Cannot create a iOS App Development provisioning profile" while the
entitlement is present but the account is a personal team. Same class of
problem as CoreNFC — see `docs/NFC-RESTORE.md` for the parked-entitlement
pattern this mirrors.

While parked, `onContinueUserActivity` never fires. A phone with RedMed
installed tapping its own band behaves exactly like a passerby's phone:
Safari opens the hosted `tapper.html#d=…` card. This is not a functional
regression for anyone else — passerby tap-to-view was always Safari-only.

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
4. Device test: with RedMed installed, tap the owner's own band → app comes
   to the foreground instead of Safari opening `tapper.html`.
5. If the custom domain (`docs/domain.md`) goes live before this is
   restored, update the `applinks:` host and `apple-app-site-association`
   together.

## Park again (optional)

1. Remove `com.apple.developer.associated-domains` from `RedMed.entitlements`.
2. Leave `onContinueUserActivity` in place — it is a no-op without the
   entitlement.
