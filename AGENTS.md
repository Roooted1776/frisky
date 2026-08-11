# AGENTS.md

## Cursor Cloud specific instructions

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

**Roles:** The owner uses the native SwiftUI app under `RedMed-Xcode/` (edit
profile, Aid treatments, NFC write). A passerby who taps the bracelet opens the
hosted scan page `card.html` (`AppConfig.medicalCardBaseURL`) — read-only RedMed /
Help / Aid, no Edit, no NFC write. `get.html` is packaging / App Store setup only
(no health data). Design canvas for the owner UI: `Main.dc.html`.

**Cold launch:** Do **not** start Core Location *updates* / MapKit / trauma JSON at
`@main`, and do **not** block or replace the main tabs with a Location gate.
First launch opens the owner tabs immediately. Suggest Location via the in-app
banner; request When-In-Use only when the user taps Allow or opens Find Help —
continuous GPS and hospital lookup still start only when that UI is visible
(privacy + time-to-first-frame). Newer sources under `uploads/` use lazy tab
mounting (switch + CustomTabBar), default RedMed, and async trauma catalog
warm-up for the same reason.

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
