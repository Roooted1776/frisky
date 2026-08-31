# Cold Start Speed Audit

**Launch lock is gone.** Current path is `RedMedApp` → `PrivacySnapshotGuard` →
`ConsentGateView` → `Main` → `ContentView`. Face ID is Edit / Save / Erase only.
Do not treat the `OwnerAppLock` notes below as current product.

The rest of this file is a **historical** read-through of the cream-lock launch path
(key-window races, `evaluatePolicy` during `.inactive`, Proceed / FacePage). Keep it
for why those bugs existed. New work should not remount `OwnerAppLock`.

---

Original audit of the owner app's then-current cold-launch path (`RedMedApp` →
`PrivacySnapshotGuard` → `OwnerAppLock` → `ConsentGateView` → `Main` →
`ContentView`). This was a **read-through audit**, not a profiled one: the app cannot
be built or run in this environment (Xcode/Simulator are macOS-only — see
`AGENTS.md`). Cross-checked against the cold-launch invariants in `AGENTS.md` at
the time — those invariants already forbade the lock; the code had not caught up.

## Summary

The cold-launch path is already heavily tuned — the current code and its comments reflect several
prior optimization passes (`main-setup-funnel`, `xcode-sim-start-lag`, PRs #407–#409, and others
merged into `main`). No blocking bug was found. This audit did not change any `.swift` file; it
documents what is already correct and flags a couple of low-risk, low-value items for later.

## Fixed since the first pass of this audit (PRs #407–#409)

A real user report of a consistent ~8-9s cream-screen wait on every cold launch (not just
occasionally) motivated a second look, since the state below described the launch path as already
correct. Three issues were found and fixed:

1. **`evaluatePolicy` could be called before any window was key.** `OwnerAppLock.onAppear` fired
   Face ID immediately (correctly, per the `.active`-wait history below), but on cold launch that
   can happen before `UIWindowScene` has a key window — and a call made that early has been
   observed to never complete (no success, no error) until the watchdog kills it, on every launch
   rather than occasionally. Fixed by gating the call on `hasKeyWindow` and retrying from
   `UIWindow.didBecomeKeyNotification`.
2. **Watchdog timeout was long for the no-sheet failure mode.** 8s (`.task`) / 8.5s (GCD fallback)
   assumed a real Face ID/passcode interaction might be in progress and shouldn't be interrupted.
   When the actual failure is "no sheet ever presented" there's nothing in-progress to interrupt,
   so both were shortened to 4.5s / 5s. Later (#427) those short budgets
   only fire when the scene is `.active` (no sheet); an `.inactive` evaluate
   waits out a 60s total budget so a live passcode sheet is not torn down
   at 4.5s, then cancels so a ghost sheet cannot hang forever. Apple has no
   `evaluatePolicy` timeout — 60s is RedMed's. `BiometricAuth`'s hang clock
   is 90s so it cannot undercut that unlock budget.
3. **Redundant warm-up `Task.detached` spawns landed in the same instant as `evaluatePolicy`.**
   `.utility` priority didn't rule out contention with the system Face ID sheet's very first
   presentation tick. Deduped the shell-cache warm-up to one scheduled task
   (`PasserbyHTMLCardView.scheduleShellWarmOnce()`) and staggered both it and the Keychain
   prefetch 300ms past the `evaluatePolicy` call.

None of these were confirmed with a profiler — same static-analysis caveat as the rest of this
doc. If the cream hang recurs, the next step is still the Instruments trace described below,
now with `RedMedSignpost`'s `coldLaunchWindow` / `faceIDEvaluate` intervals and the `DEBUG`-only
`[OwnerAppLock]` console logging (added alongside fix 1) available to localize it precisely.

## Stuck cream screen after Face ID succeeds (this pass)

A user report of a stuck cold-launch screen (initially described as black, confirmed to actually
be flat cream — the `LockEntryPage` shell) where the Face ID sheet visibly appeared and dismissed
but the app never proceeded past it. Root cause: `OwnerAppLock`'s `isAuthenticating` flag was
overloaded to mean both "LAContext evaluate in flight" (its documented purpose, read by both
watchdogs and the FacePage-vs-LockEntryPage switch) *and*, implicitly, "still busy after Face ID
succeeded" — it was left `true` for the entire async profile-decode/Keychain-read phase between a
successful `evaluatePolicy` and `gate` flipping to `.unlocked`. Two consequences:

1. If that decode phase ran long, the watchdogs (`.task(id: authGeneration)` / the GCD fallback)
   treated it as a hung Face ID sheet and called `BiometricAuth.cancelInFlight()` — a no-op by then
   since the live context was already cleared, but the intent was wrong and left no distinct
   diagnostic for "profile load stalled" vs. "Face ID never got a sheet."
2. Tapping the resulting **Proceed** button called `unlockWithFaceID()` again — re-prompting an
   already-passed Face ID and abandoning the first attempt's still-in-flight `applyUnlockSuccess`
   task rather than retrying the actual stuck step.

Fixed by adding a separate `isLoadingProfile` flag, set the moment Face ID succeeds and cleared
when the decode finishes (or a fresh Face ID attempt starts). The watchdogs now flag a stall during
this window as `profileLoadFailed` instead of a Face ID hang, and Proceed calls a dedicated
`retryStuckProfileLoad()` that re-awaits the decode instead of restarting biometrics. Not confirmed
with a profiler/device repro — same caveat as the rest of this doc — but the prior behavior was a
readable logic bug independent of timing.

## Broader cold-start / cream-page sweep (this pass)

Following the fix above, re-read the full cold-launch chain end to end (`RedMedApp` →
`PrivacySnapshotGuard` → `OwnerAppLock` → `ConsentGateView` → `Main` → `ContentView` →
`RedMedView` → the `tapper.html` WKWebView shell) looking specifically for the same bug shape —
a boolean doing double duty across two different phases, or a screen that can end up blank with no
watchdog to recover it. Nothing else at that severity turned up:

- `ConsentGateView` is a synchronous, user-driven gate (no `await`, no hang surface).
- `ContentView` / `RedMedView` mount is fully synchronous; `RedMedView`'s own async paths
  (`syncPackedPayload` / `refreshDurablePayload`) always paint a placeholder immediately and
  already have a "Couldn't load your medical card — Try again" fallback (`packFinished`) if the
  AES pack never resolves.
- `PrivacySnapshotGuard`'s cover logic (`mustCover`) is gated on `hasBeenActive`, so it cannot
  paint over the pre-first-frame gap the way the historical cream-hang bugs did.

One smaller, lower-confidence item found and **left as-is**: `PasserbyHTMLWebView.Coordinator`
(`PasserbyHTMLCardView.swift`) retries a failed shell load up to twice
(`scheduleRecovery`/`loadAttempts < 2`) but has no user-facing fallback if both retries fail —
the WKWebView (already colored cream via `webView.backgroundColor`) is simply left as-is with no
"Try again" affordance, unlike `RedMedView`'s own `packFinished` fallback for a failed AES pack.
This only triggers on a genuine repeated local WKWebView load failure (e.g. the WebContent process
dying twice in a row), not the Keychain/Face ID path — much rarer than the bug above, and there is
no reported symptom matching it. Not fixed this pass: doing so safely needs a small plumbing change
(a closure/binding from the coordinator up to `RedMedView` to trigger the same kind of fallback UI),
and in an environment with no Xcode/Simulator to build against, that's not worth the added risk
without a concrete report to fix against.

## GPU/CPU render-load follow-up (this pass)

A related report asked for a general CPU/GPU load pass. Checked every `.drawingGroup()` call in
the app (7 total: `Theme.swift` ×4, `ContentView.swift`, `TopicDetailView.swift`,
`ConsentGateView.swift`) against a bug class found in `HelpMenuView`'s Settings toggles: a live
`Toggle` inside a `redmedBox()`'s flattened default rendered correctly but stopped responding to
taps. Confirmed that was the only occurrence — `PrimaryButton`, `OutlineButton`'s unlock button,
the tab bar background, the CPR pulse circle, and the animated heart mark all flatten purely
static/decorative content with the actual tap target (a `Button`) outside the flattened boundary,
which is the correct, safe pattern. No further GPU-load bug of that kind found; no other CPU/GPU
load issue surfaced by static reading beyond what's already itemized below.

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
