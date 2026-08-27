# Cold Start Speed Audit

Static code audit of the owner app's cold-launch path (`RedMedApp` → `PrivacySnapshotGuard`
→ `OwnerAppLock` → `ConsentGateView` → `Main` → `ContentView`). This is a **read-through audit**,
not a profiled one: the app cannot be built or run in this environment (Xcode/Simulator are
macOS-only — see `AGENTS.md`), so there are no Instruments traces or wall-clock numbers here.
Findings are based on tracing what actually executes between process start and first interactive
frame, cross-checked against the cold-launch invariants already documented in `AGENTS.md`.

## Summary

The cold-launch path is already heavily tuned — the current code and its comments reflect several
prior optimization passes (`main-setup-funnel`, `xcode-sim-start-lag`, and others merged into
`main`). No blocking bug was found. This audit did not change any `.swift` file; it documents what
is already correct and flags a couple of low-risk, low-value items for later.

## What's already right

- **Zero I/O before first frame.** `RedMedApp` constructs `ProfileData()` (no Keychain touch —
  decode is deferred to unlock) and mounts a cream shell (`redmedBg` / `LaunchBackground`) with no
  `CLLocationManager`, `CMMotionManager`, or GPS/MapKit work. `LocationAccessSuggester` and
  `CrashMotionGuard` both lazily construct their system objects (`CLLocationManager`,
  `CMMotionManager`) on first real use, not in `init`/`shared`.
- **Face ID fires immediately**, including while the scene is still `.inactive` on cold launch
  (`OwnerAppLock.tryAutoUnlockIfActive` / the historical "wait for `.active`" cream-hang bug is
  fixed and guarded by `didAutoPromptThisLock`).
- **Real work overlaps the Face ID sheet instead of following it.** `beginUnlockPrefetch()` starts
  a `.utility` Keychain read + JSON decode + AES `#d=` pack while the system Face ID sheet is up,
  parked in a lock-protected `UnlockPrefetchBox` so the unlock success path can adopt it
  synchronously (no `await`, no extra MainActor hop). `.utility` (not `.userInitiated`) is used
  deliberately so this prefetch doesn't contend with the Face ID sheet itself for CPU — documented
  and correct.
- **WKWebView warm-up is correctly sequenced after first paint, not before.** `warmShellCache()`
  (string-only: reads and caches `tapper.html`'s text) is safe to run during Face ID and does.
  Actually constructing a `WKWebView` (`PasserbyWebViewPool.warmFullShell()`) is deferred ~800ms
  after `gate == .unlocked`, with an explicit note that gating this on a "shell did finish" signal
  instead of a flat delay was tried and regressed (WebKit stealing MainActor mid–first-paint). The
  flat delay is the pragmatic choice given that history.
- **Tab mounting is lazy.** `ContentView` only mounts the RedMed tab on cold start; 911/Aid/NFC
  mount on first visit and are kept alive via opacity (not rebuilt), so switching tabs after cold
  start doesn't pay a fresh WKWebView/CoreMotion/CoreLocation cost.
- **No synchronous blocking primitives** (`DispatchSemaphore`, `.wait()`) or eager
  `UserDefaults.synchronize()` calls anywhere in the launch path.
- **Static data catalogs are lazy by construction.** `AidTopicCatalog.topics`, `SuggestionCatalog`'s
  medication/allergy/condition arrays, and `CountryDialCode.all` are `static let`s — Swift
  initializes these lazily and exactly once, on first access, not at process start. `AidTopicCatalog`
  also has an explicit off-main `warmUp()` prefetch called after Aid's first paint, so even that
  first access doesn't land on the main thread.
- **Vault prep is off the hot path.** `HIPAAOfflineVault.prepare()` (directory creation + file
  protection attributes) runs `.utility` and is deliberately delayed 1.5s after the `.task` fires,
  well clear of first paint and the Face ID window.
- **Build settings are unremarkable in a good way** — Debug is incremental/`-Onone` (expected for
  dev iteration), and nothing in `project.pbxproj` forces a slow Release configuration
  (no stray `GCC_OPTIMIZATION_LEVEL = 0` or disabled dead-code stripping on the Release side).
- Only one custom framework is explicitly linked (`HealthKit`); everything else imported
  (`CoreNFC`, `CoreLocation`, `CoreMotion`, `LocalAuthentication`, `WebKit`, `CoreHaptics`,
  `MapKit`) is a system framework, so dyld has little extra to resolve at launch beyond what the
  feature set requires.

## Minor, low-risk items

1. **Fixed: bundled `pheart.png` was 1024x1024 truecolor (659 KB)** — the `<img id="rmLogo">`
   fallback shown only if `BrandLogo.png` fails to resolve, displayed at 72 CSS px (216 @3x). The
   bundled copy was ~4.7x the linear resolution (~22x the pixels) that ever paints on screen,
   forcing WKWebView to decode a needlessly large RGBA bitmap on any load that hits the fallback.
   Resized to 216x216 (44 KB), matching the web-served copies' target size; `render_brand_assets.swift`
   updated so a future asset regen doesn't reintroduce the oversized copy.
2. **`tapper.html` is ~113 KB of markup/CSS/JS**, string-cached in RAM once
   (`PasserbyShellCache.warm()`) but still parsed by WebKit on every WKWebView load (pool warm-up
   included). This is unavoidable given the shared owner/passerby shell architecture and is already
   mitigated as much as is practical without a real profiling pass: reading is off-main, and both
   webview slots (embed vs. full) are pre-warmed opportunistically rather than on the critical path.

## What would make this audit stronger

This pass is static-only. The next useful step, which needs a Mac, is an Instruments "App Launch"
trace on a physical device across a few cold launches (with and without a stored Keychain profile)
to get real numbers for: time to first frame, time to Face ID sheet, time to unlocked tabs, and
time to the RedMed WKWebView's first meaningful paint. That would confirm or correct the above and
give a baseline for regressions.
