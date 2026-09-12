# Max

Working notes. Product invariants live in `AGENTS.md`.

## Xcode (device)

- One repo / one branch: `Roooted1776/frisky` → `main`. Pull → **Product → Clean Build Folder** → Run.
- **Xcode Run → phone lag is mostly Debug install + debugger attach — not the App Store binary.**
  Pre-app (before first cream / `@main`): SplashBoard + install + LLDB attach. App source ~1MB — not install bloat.
  Scheme `enableGPUValidationMode` must stay `"1"` (Disabled). `"2"` re-enables Metal API Validation (2cb8eaf flipped it wrong).
- Fair cold-start check (pick one):
  1. Scheme **RedMed-NoDebug** → Run (same Debug build, **no LLDB**), or
  2. **Product → Perform Action → Run Without Debugging**, or
  3. Scheme Run → **Release** / Archive.
  If NoDebug / Without Debugging is fast and normal Debug Run is slow → attach, not Swift.
  Console ColdLaunch: `app.init` → `firstFrame` — if cream sits with **no** ColdLaunch lines yet after Xcode’s “Running…”, lag is still install/attach.
  Multi-second `app.init` → `firstFrame` **with** ColdLaunch lines under Debug Run is still usually LLDB stalling MainActor — confirm with NoDebug. Consent **4.15** forces Before You Continue + Face ID once (policy bump) — that is *after* firstFrame, not install lag. Returning cold opens after that Agree still Face ID once over warm Main (not a second Before You Continue).
- Console noise to ignore (Apple / Simulator, not RedMed bugs):
  - `PointerUI.pointeruid` non-launching port
  - `Got a keyboard will change frame notification, but keyboard was not even present`
  - `Reading from public effective user settings`
  - `com.apple.CoreMotion.plist` / `NSCocoaErrorDomain Code=257` (Managed Preferences — CMMotionManager still works; starts after Face ID unlock)
  - Face ID `evaluatePolicy raw callback: success=true` is success, not an error
  - `Gesture: System gesture gate timed out` during Face ID sheet
  - `WebContent[…] Unable to hide query parameters from script (missing data)` (WebKit internal)
  - Do **not** ignore `sandbox_extension_issue_file` / `WebContent Couldn't open <private>` after the passerby Caches `loadFileURL` staging — those meant bundle-baseURL `loadHTMLString` and should be gone
- Face ID test path: **Run Without Debugging** / **RedMed-NoDebug** (debugger attach skews the sheet).
- Product: Before You Continue = Agree only (covers location + motion while the app is open). Face ID once immediately after Agree (first launch / policy bump / after Erase), then iOS Location Allow once. Returning cold opens skip Before You Continue but Face ID once on cream over warm Main (restore races underneath; no fixed sleep; no background relock). Face ID also on Edit / Save / Erase (+ Load From Band if present). **Not** a second gate after that Face ID to view the YOU card. No `OwnerAppLock` relock. Face ID is UI-only — Keychain is `WhenPasscodeSetThisDeviceOnly` with **no** biometry ACL. Edit field Clear (blood / DOB) only — blank-all Save is not a wipe (points at Erase). Band is the product. Storefront / dept “write from the app” off until Tag Reading + Write The Band on blank NTAG216; until then blank chips + Share honesty only — no Shortcuts write copy. Crash detect: owner foreground + `.inactive` only (parked; no background window). Find Help points at iPhone Crash Detection for lock/killed.

## Cold start (shipping)

Returning cold open: Face ID once over warm Main (prefetch/restore already running — do **not** pay a fixed Face ID stagger). WK / Taptic / 50 Hz motion / rose wash wait until the scene is `.active` — Face ID cream is `.inactive`, so a 400ms sleep alone still landed mid-sheet. Leftover Keychain ACL migrate is deferred ~300ms after cream drop. Aid / Edit catalogs prefetch after interactive. Fresh / Erase / policy bump: Agree (no Face ID on that page) → Face ID → Main. Same-session resume does not re-prompt. Edit / Save / Erase (+ Load From Band) still Face ID.
Consent-pending path: Keychain MainActor adopt waits for Agree (not RedMedApp.task —
that raced cream drop). Document.html WK warm waits ~500ms past gate appear so
cream drop + ack layout win.
