# Max

Working notes. Product invariants live in `AGENTS.md`.

## Xcode (device)

- One repo / one branch: `Roooted1776/frisky` → `main`. Pull → **Product → Clean Build Folder** → Run.
- **Xcode Run → phone lag is mostly Debug install + debugger attach — not the App Store binary.**
- Fair cold-start check: Scheme Run → **Release**, or Archive; also **Product → Perform Action → Run Without Debugging**.
- Face ID test path: **Run Without Debugging** (debugger attach skews the sheet).
- Product: Before You Continue = Agree only (covers location + motion while the app is open). Face ID once immediately after Agree (first launch / policy bump / after Erase), then iOS Location Allow once. Returning opens skip consent **and** that post-Agree Face ID. Face ID also on Edit / Save / Erase (+ Load From Band if present). **Not** before opening / viewing the YOU card. No cream `OwnerAppLock`. Face ID is UI-only — Keychain is `WhenPasscodeSetThisDeviceOnly` with **no** biometry ACL. Edit field Clear (blood / DOB) only — blank-all Save is not a wipe (points at Erase). Band is the product.

## Cold start (shipping)

Returning opens skip consent and post-Agree Face ID — go straight to Main with the YOU card. Do **not** pay a fixed Face ID stagger before Keychain restore — restore ASAP after first paint. Fresh / Erase: Agree (no Face ID on that page) → Face ID → Main. Edit / Save / Erase (+ Load From Band) still Face ID.
