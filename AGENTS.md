# AGENTS.md

## Cursor Cloud specific instructions

**Personal profile / memory:** read [`MAX.md`](./MAX.md) first for who Max is,
how he works, and what he has already shipped. Product invariants below stay
authoritative for code; `MAX.md` is the durable personal + history memory.

This repository is a **native iOS/SwiftUI app** (RedMed), located under `RedMed-Xcode/`. It
builds and runs **only on macOS with Xcode 15+** (prefer Xcode 27 / iOS 27.0 Simulator) and an
iOS 17+ Simulator or physical iPhone. Deployment target remains 17.0.

**It cannot be built, run, linted, or tested in the Cursor Cloud Linux VM.** There is no way to
set up a working runtime here:

- Xcode is macOS-only and cannot be installed on Linux.
- Every source file in `RedMed-Xcode/RedMed/` imports iOS-only frameworks (`SwiftUI`, `UIKit`,
  `CoreNFC`, `MapKit`, `LocalAuthentication`, `MessageUI`, `WebKit`, `CoreLocation`). Swift-for-Linux
  does not ship these frameworks, so even installing a Linux Swift toolchain does not enable a build.
- The iOS Simulator is macOS-only.

**There are no dependencies to install:** no Swift Package Manager, CocoaPods, Carthage, or npm.
The app has no backend, database, or web service.

**Roles / shells (permanent — do not regress):**
- **Owner app** (`Main` → `ContentView`, `isScannerSession == false`): tabs are
  **RedMed · 911 · Aid · NFC**. Edit is available on RedMed. NFC tab is always
  visible for owners; `AppConfig.nfcHardwareEnabled` only gates CoreNFC
  write/read sessions, never tab chrome. Owner writes the passive HF NFC band
  from the NFC tab (Face ID gated).
- **Scanner / passerby shell** (`PublicCardView` / bracelet tap → `get.html#d=…`,
  `isScannerSession == true`): tabs are **RedMed · 911 · Aid** only — **no Edit**,
  **no NFC**. Profile is a snapshot; mutations must not touch owner Keychain or
  owner `@AppStorage` / UserDefaults prefs. Hosted at
  `https://redmed.pages.dev/get/` from `get/index.html`.
  **Tap-to-view never requires Face ID / biometrics** — owner biometrics gate
  edit, NFC write, vault, and app unlock only. Passerby HTML never asks.
- Product HTML is only (1) one passerby file `get.html` (identical in `get/index.html`,
  repo root, and the app bundle; legacy `card.html` redirects to `/get/`, preserving `#d=`) and
  (2) policy pages bundled solely under `RedMed-Xcode/RedMed/` (`PrivacyPolicy`,
  `TOS`, `security`, `HowItWorks`, `legal-doc.css`). `HowItWorks.html` redirects
  into `redmed://main`. Policies CTA to the owner app; they do not host owner
  edit UI. Do not reintroduce repo-root copies of the policy HTML. Owner How It
  Works / band setup lives in `Main.swift` (`MainInfoView`).

- **Bracelet tap (physics, not a setting):** `AppConfig.BraceletRF` is the single
  source of truth — intentional tap ~1–2″, walk-by ~6–8″ does not fire, reliable
  coupling dies past ~4″, passive 13.56 MHz HF NFC (not Bluetooth). NFC tab /
  How It Works copy must use `BraceletRF` helpers, not hardcoded inches.
  Tap opens the HTML shell for EMT / helper — passive, no app install.

**Settings vs automatic (permanent):**
- Help → Settings exposes **only** haptic feedback + Location (`AppSettings` /
  `HapticEngine.enabledKey`). No other toggles there.
- **Brightness + sound are survival-alarm only (not Settings, not auto on Find Help / scanner):**
  arm `BrightnessBoost` + `VolumeBoost` + `LocatorBeacon` only when (1) on-device crash /
  hard-impact detection (`CrashMotionGuard`) fires for **vehicle crash /
  high-speed impact only** (not running or daily activity), or (2) the owner
  taps **SOS · Locate me** on Find Help. Opening Find Help or the scanner
  shell must not force brightness, max volume, or play the siren by itself. Do not add
  Settings off switches for the survival alarm.
- **LocatorBeacon** / **BrightnessBoost** / **VolumeBoost** survival hold may keep sounding /
  max brightness / max system volume in background until the user taps “Stop the alarm” on Aid
  (or Stop SOS alarm on Find Help).

**Vault / privacy (permanent):**
- `VaultHistoryView` Face ID unlock: relock on `.background` only. Do **not**
  lock on `.inactive` — LAContext / system auth sheets put the scene inactive
  and would discard a successful unlock via `authGeneration`.
- `PrivacySnapshotGuard` cover must appear opaque with **no** opacity fade;
  app-switcher snapshots can capture mid-transition PHI.
- `HIPAAOfflineVault`: complete file protection + backup exclusion; history
  events are timestamps/kind only (no field values).

**Cold launch:** Do **not** create `CLLocationManager`, start GPS / MapKit /
trauma JSON, or show a Location banner at `@main`. First launch opens a cream
shell (`redmedBg` / `LaunchBackground`) with **zero Keychain** on the first
frame — `OwnerAppLock` defers `hasStoredProfile` until after paint, then shows
the lock UI; Face ID runs only after the owner taps **Accept** (never auto on
appear). Do not call Keychain in `@State` defaults. Location nudge lives in Help →
Settings; When-In-Use + GPS start on Find Help only when Location is enabled
(`AppSettings.locationEnabled` + `LocationManager.start`). CoreMotion crash
monitoring may start after first-frame yield (no Location); do not construct
`CMMotionManager` at `CrashMotionGuard` shared init. `ContentView` lazy
tab mounting mounts RedMed only on cold start (911 / Aid / NFC on first visit,
kept alive after with opacity). Opacity keep-alive **does not** fire
`onDisappear` on tab switch — any side effect that must stop when leaving a
tab (Find Help GPS, seizure autodial, etc.) needs an explicit `isVisible`
(or equivalent) hook from `ContentView`, not `onDisappear` alone. Keychain
profile decode runs off-main after Face ID unlock and must **fail closed**
(stay locked) if decode returns false — never unlock into an empty profile
that can overwrite Keychain. Vault prep runs off the main thread after first
paint. `UILaunchScreen` must use `LaunchBackground` (same as `redmedBg`,
including dark appearance) — never an empty dict (system black).
`PrivacySnapshotGuard` must not cover until the scene has been `.active`
once (cold start begins `.inactive` and would otherwise blank the first
paint); store content as a `@ViewBuilder` closure, do not eagerly evaluate
it in `init`.

**Xcode project:** `project.pbxproj` object IDs must stay unique. Duplicate
`AAAA`/`AABB` IDs silently drop sources from the target (seen when Haptic /
Brightness collided with HIPAA vault files).

**Passerby SW:** shell fetch is **cache-first** (multi-key: `/get/`,
`index.html`, etc.) for **almost-instant** EMT / helper open when Cache
Storage has any shell copy — never wait on network in that case. Background
`cache: 'reload'` refresh updates the bucket while online. First visit (empty
cache) waits on network, then stores under every shell key. On activate,
delete every prior `CACHE` name so deploys clear stale decrypt/layout. Bump
`CACHE` (`redmed-get-vN`) in lockstep across `sw.js`, `get/sw.js`, and the
bundled copy on every SW / decrypt deploy. Register the SW ASAP in `get.html`
(not on `window.load`). Legacy zlib inflate is bounded (64 KiB) in Swift +
streaming bound in `get.html`. Passerby HTML never touches brightness or audio.

**Repo hygiene:** `main` is the only long-lived branch. After merges, delete
feature branches on the remote; do not leave parallel “brainchild” branches.
Keep the tree product-only: `RedMed-Xcode/`, passerby `get*` / `sw.js` /
`card.html` / `_headers`, `assets/` + root logo, `docs/` product notes,
`scripts/`, `.github/`, and agent docs. Do not re-add staging `uploads/`,
debug `screenshots/`, dead `support.js` / `ios-frame.jsx`, or UK
`compliance/` paper packs.

**Debugger note:** `Thread 1: signal SIGTERM` at `mach_msg2_trap` is usually
Xcode Stop / Simulator killing the process — not a Swift crash. Look for
`EXC_BAD_ACCESS` / fatalError / assertion if it is a real fault.

**Consequence for cloud agents:** the update script is intentionally a no-op. Code review and static
edits to the `.swift` files are possible, but do not attempt to build/run/test here. Any actual
build, run, or manual testing must happen on macOS + Xcode:

```
./scripts/run.sh                       # fastest: boot iOS 27.0 sim, incremental build, launch
open RedMed-Xcode/RedMed.xcodeproj   # then Run (Cmd+R) against an iOS 27.0 Simulator
# or, headless:
xcodebuild -project RedMed-Xcode/RedMed.xcodeproj -scheme RedMed \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' build
```

`scripts/run.sh` keeps derived data in `.derivedData/`, skips rebuild when Swift/resources
are unchanged, and skips reinstall when the built app is unchanged. Defaults to iOS 27.0;
override with `SIM="iPhone 17 Pro" SIM_OS=27.0 ./scripts/run.sh`. Location is pre-granted on
the simulator (Apple Park coords); override with `LOCATION="40.7128,-74.0060" ./scripts/run.sh`.

**Compile checking without a Mac:** `.github/workflows/ios-build.yml` builds the app on a
GitHub `macos-latest` runner for every push to `main` and every PR that touches
`RedMed-Xcode/**`, so Swift compile errors surface in CI even when the change was authored
somewhere that cannot build. It only compiles — it does not run the app, the Simulator UI, NFC,
or Face ID, and it is not a substitute for testing behaviour on a device. Note the path filter:
macOS runner minutes bill at 10x on private repos, so doc/HTML-only changes deliberately skip it.

On a **physical iPhone**, iOS requires a one-time Allow tap — that cannot be bypassed from code.

NFC write and Face ID flows only work on a physical iPhone, not the Simulator.
