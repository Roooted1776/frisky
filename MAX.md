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
  Console `[ColdLaunch]` (DEBUG only): `app.init` → `firstFrame` — if both fire late after Xcode’s “Running…”, lag is still install/attach.
- Face ID test path: **Run Without Debugging** / **RedMed-NoDebug** (debugger attach skews the sheet).
- Product: Before You Continue = Agree only (covers location + motion while the app is open). Face ID once immediately after Agree (first launch / policy bump / after Erase), then iOS Location Allow once. Returning opens skip consent **and** that post-Agree Face ID. Face ID also on Edit / Save / Erase (+ Load From Band if present). **Not** before opening / viewing the YOU card. No cream `OwnerAppLock`. Face ID is UI-only — Keychain is `WhenPasscodeSetThisDeviceOnly` with **no** biometry ACL. Edit field Clear (blood / DOB) only — blank-all Save is not a wipe (points at Erase). Band is the product.

## Cold start (shipping)

Returning opens skip consent and post-Agree Face ID — go straight to Main with the YOU card. Do **not** pay a fixed Face ID stagger before Keychain restore — restore ASAP after first paint. Fresh / Erase: Agree (no Face ID on that page) → Face ID → Main. Edit / Save / Erase (+ Load From Band) still Face ID.
