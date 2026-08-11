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
  **RedMed · Help · Aid · NFC**. Edit is available on RedMed. NFC tab is always
  visible for owners; `AppConfig.nfcHardwareEnabled` only gates CoreNFC
  write/read sessions, never tab chrome.
- **Scanner / passerby shell** (`PublicCardView` / bracelet tap → `get.html#d=…`,
  `isScannerSession == true`): tabs are **RedMed · Help · Aid** only — **no Edit**,
  **no NFC**. Profile is a snapshot; mutations must not touch owner Keychain or
  owner `@AppStorage` / UserDefaults prefs. Hosted at
  `https://redmed.pages.dev/get/` from `get/index.html`.
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

**Settings vs automatic (permanent):**
- Help → Settings exposes **only** haptic feedback + Location (`AppSettings` /
  `HapticEngine.enabledKey`). No other toggles there.
- **Always automatic (not Settings):** Find Help / scanner brightness → 100%
  (`BrightnessBoost`); owner Find Help locate-me beep every 5s
  (`LocatorBeacon`); on-device crash / hard-impact detection
  (`CrashMotionGuard`) that arms the same siren + brightness. Do not add off
  switches for these.
- **LocatorBeacon** Find Help path is owner-only — never arm Find Help siren
  when `isScannerSession == true`. Crash survival hold may keep sounding in
  background until the user cancels (“I'm OK”).
- **BrightnessBoost** restores the prior brightness + idle-timer on
  `.inactive`/`.background` for normal Find Help / scanner hosts; crash
  survival hold skips that pause until cancelled.

**Vault / privacy (permanent):**
- `VaultHistoryView` Face ID unlock: relock on `.background` only. Do **not**
  lock on `.inactive` — LAContext / system auth sheets put the scene inactive
  and would discard a successful unlock via `authGeneration`.
- `PrivacySnapshotGuard` cover must appear opaque with **no** opacity fade;
  app-switcher snapshots can capture mid-transition PHI.
- `HIPAAOfflineVault`: complete file protection + backup exclusion; history
  events are timestamps/kind only (no field values).

**Cold launch:** Do **not** create `CLLocationManager`, start GPS / MapKit /
trauma JSON, or show a Location banner at `@main`. First launch opens RedMed
tabs immediately with zero Location API. Location nudge lives in Help →
Settings; When-In-Use + GPS start on Find Help only when Location is enabled
(`AppSettings.locationEnabled` + `LocationManager.start`). CoreMotion crash
monitoring may start after first-frame yield (no Location). Newer sources under
`uploads/` use lazy tab mounting (switch + CustomTabBar), default RedMed, and
async trauma catalog warm-up for the same reason.

**Xcode project:** `project.pbxproj` object IDs must stay unique. Duplicate
`AAAA`/`AABB` IDs silently drop sources from the target (seen when Haptic /
Brightness collided with HIPAA vault files).

**Passerby SW:** shell fetch is network-first; on non-ok HTTP **or** network
failure, fall back to Cache Storage. Bump `CACHE` (`redmed-get-vN`) in lockstep
across `sw.js`, `get/sw.js`, and the bundled copy on every SW / decrypt deploy.
Legacy zlib inflate is bounded (64 KiB) in Swift + streaming bound in `get.html`.

**Repo hygiene:** `main` is the only long-lived branch. After merges, delete
feature branches on the remote; do not leave parallel “brainchild” branches.

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
