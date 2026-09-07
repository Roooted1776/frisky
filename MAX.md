# Max

Working notes. Product invariants live in `AGENTS.md`.

## Xcode (device)

- One repo / one branch: `Roooted1776/frisky` → `main`. Pull → **Product → Clean Build Folder** → Run.
- **Xcode Run → phone lag is mostly Debug install + debugger attach — not the App Store binary.**
- Fair cold-start check: Scheme Run → **Release**, or Archive; also **Product → Perform Action → Run Without Debugging**.
- Face ID test path: **Run Without Debugging** (debugger attach skews the sheet).
- Product: Face ID on consent (first launch / policy bump) + Edit / Save / Erase (+ Load From Band if present). **Not** before opening / viewing the YOU card. No cream `OwnerAppLock`. Band is the product.

## Cold start (shipping)

Returning opens skip consent. Do **not** pay a fixed Face ID stagger before Keychain restore — restore ASAP after first paint. Consent Face ID still runs on first launch / policy bump before Agree.
