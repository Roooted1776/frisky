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
- **In-app Face ID only on the owner RedMed page** (Edit / Save). 911, Aid, NFC, and app launch do not prompt. Tapper: no biometrics, no acknowledgement.
- No cream lock in front of Main. `SnapshotSafeCover` is the app-switcher cream.
- NFC Tag Reading + HealthKit + Associated Domains are **parked** (personal/free Apple team). NFC tab stays visible; write is Preview packed card.
- Seizure timer **never auto-dials**. At 5:00 it shows Call (`tel:`). GPS stays on-screen — never uploaded, never attached to `tel:`.
- Survival alarm (brightness / volume / siren) on crash or SOS only — not Settings, not Apple Crash Detection.

## Shipped (Aug 2026, keep this current)

- Face ID lock: file-level `AuthBudget` (generic types cannot nest `static let`). 1s/1.5s no-sheet, 60s inactive passcode, 90s hang clock.
- Debug-on-device: Main Thread Checker / TPC / view+queue debug / Metal validation / `ENABLE_DEBUG_DYLIB` off. `print()` → `os.Logger`. Log streaming. No SwiftUI preview dylib.
- Load: no `CLLocationManager` retained on consent; crash-motion + vault after Before you continue paints; tapper.html string warm 300ms after first paint, WKWebView only after unlock.
- App Store honesty on `main`: parked NFC copy, no autodial (native + all three `tapper.html`), Aid first-aid disclaimer, support page.
- iOS CI is **workflow_dispatch only** (billing). Trigger it after Swift/scheme changes.

## Xcode on his Mac

After a pull: **Product → Clean Build Folder**, Stop, Run. Face ID test path: **Run Without Debugging**. Runtime Issue breakpoints live in xcuserdata (not git) — delete them if it still says Paused on iPhone.
