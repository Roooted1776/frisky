# Max

Maximilian Aguilar-Aasted. GitHub **Roooted1776**. X **DNS404**. Ships RedMed himself.

## How he works

- **One repo, one branch:** `Roooted1776/frisky` → `main` only. Squash-merge short PRs; delete the branch. No parallel remotes.
- **One Mac clone:** `/Users/claude/Documents/frisky`. Pull `main` after every merge. Do not open a second clone.
- **Fix in git, not copy-paste.** He builds in Xcode on a physical iPhone. He has no sandbox shell — land the compile, then tell him Pull → Clean Build Folder → Run.
- **Terse.** Product talk, not ports/paths/tool names. Do what he meant.
- **Invariants live in `AGENTS.md`.** This file is personal + history. If they conflict, `AGENTS.md` wins for code unless he just changed the product in git.

## Product (do not regress)

RedMed is a **native iOS/SwiftUI** medical ID (`RedMed-Xcode/`). Local only: Keychain + a passive NXP NTAG216 band (`#d=` AES-GCM). The band is the product, not optional. No RedMed server, no login, no passerby Face ID.

- Owner tabs: **RedMed · 911 · Aid · NFC**. Scanner / tapper: **RedMed · 911 · Aid** (no Edit, no NFC).
- Owner open/return is Face ID only (system prompt). First start: Face ID → Before you continue → Agree → Main. Later cold open / Home / app-switch: Face ID → Main. That gate is not optional. Edit / Save / Erase still Face ID unless the Before you continue Face ID switch is off. 911, Aid, NFC write, and tapper do not prompt. Tapper: no biometrics, no acknowledgement.
- No LockEntryPage / FacePage / Proceed. Locked layer is the launch heart (cream + BrandLogo, same as `UILaunchScreen`). Cream cover while locked hides PHI. `ConsentGateView` on first start / policy bump / after Erase only (`redmed.consentAcceptedVersion` == 4.1 skips ack). `SnapshotSafeCover` is the app-switcher cream.
- Profile restores from Keychain on owner Main appear (device-unlocked Keychain — no Face ID to view). One Face ID is possible after this build to migrate an old biometry Keychain item, then never again to view.
- NFC Tag Reading + HealthKit + Associated Domains are **parked** (personal/free Apple team). NFC tab stays visible; write is Preview packed card.
- Seizure timer **never auto-dials**. At 5:00 it shows Call (`tel:`). GPS stays on-screen — never uploaded, never attached to `tel:`.
- Survival alarm (brightness / volume / siren) on crash or SOS only — not Settings, not Apple Crash Detection.

## Shipped (Aug 2026, keep this current)

- Owner Face ID: `OwnerAppLock` system prompt only. Relock on Home / app-switch. Simulator auto-succeeds same-turn; device never does. Unlock / Edit / Save / Erase completions hop `Task { @MainActor }` (LA's main queue is not the MainActor executor). 90s hang clock in `BiometricAuth`.
- Face ID toggle on Before you continue: Edit / Save / Erase only (`authenticateForOwnerAction`). Open/return always prompts. Crash motion stops on relock, starts on unlock (siren already armed is left alone).
- Before you continue: first start / policy bump / after Erase. Haptic, Location, Face ID toggles default on. That page may present the iOS Location Allow sheet. Help never prompts Location.
- Erase all user data is on owner Help, then ack, then Main. Scanner Help stays policies only.
- ICE phones display US as `(XXX) XXX-XXXX`. Tab bar: labels scale to the slot; bar sits 3pt off the home indicator. Type fits its box on every screen. In-app tapper is a live copy of `tapper/index.html`.
- Load: Face ID on the launch heart. Keychain+JSON prefetch runs after evaluate is in flight; unlock applies it before Main mounts so the first frame is the YOU card. RedMed mounts first; 911 / Aid / NFC stagger-mount after that paint (GPS / Preview WK still gated on the front tab). No second WKWebView on Agree. Crash-motion from owner Main appear (and from relock-unlock). Keychain device-unlocked restore. Before you continue / `CLLocationManager` only on first start, a policy bump, or after Erase.
- HealthKit + NFC Tag Reading + Associated Domains parked. NFC tab visible; write is Preview packed card.
- App Store honesty: parked NFC copy, no autodial, Aid disclaimer, MapKit hospital search may leave the phone, siren may play in background.
- Debug-on-device: Main Thread Checker / TPC / view+queue debug / Metal validation / `ENABLE_DEBUG_DYLIB` off. `print()` → `os.Logger`.
- iOS CI is **workflow_dispatch only** (billing). Trigger it after Swift/scheme changes.

## Xcode on his Mac

After a pull: **Product → Clean Build Folder**, Stop, Run. Face ID test path: **Run Without Debugging**. Runtime Issue breakpoints live in xcuserdata (not git) — delete them if it still says Paused on iPhone.
