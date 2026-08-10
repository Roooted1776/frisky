# AGENTS.md

## Cursor Cloud specific instructions

This repository is a **native iOS/SwiftUI app** (RedMed), located under `RedMed-Xcode/`. It
builds and runs **only on macOS with Xcode 15+** and an iOS 17+ Simulator or physical iPhone.

**It cannot be built, run, linted, or tested in the Cursor Cloud Linux VM.** There is no way to
set up a working runtime here:

- Xcode is macOS-only and cannot be installed on Linux.
- Every source file in `RedMed-Xcode/RedMed/` imports iOS-only frameworks (`SwiftUI`, `UIKit`,
  `CoreNFC`, `MapKit`, `LocalAuthentication`, `MessageUI`, `WebKit`, `CoreLocation`). Swift-for-Linux
  does not ship these frameworks, so even installing a Linux Swift toolchain does not enable a build.
- The iOS Simulator is macOS-only.

**There are no dependencies to install:** no Swift Package Manager, CocoaPods, Carthage, or npm.
The app has no backend, database, or web service.

**Cold launch:** Do **not** start Core Location *updates* / MapKit / trauma JSON at
`@main`. Asking When-In-Use authorization once after first frame (install prompt)
is OK — continuous GPS and hospital lookup still start only when Find 911 / that
UI is visible (privacy + time-to-first-frame). Newer sources under `uploads/` use
lazy tab mounting (switch + CustomTabBar), default My ID, and async trauma catalog
warm-up for the same reason.

**Consequence for cloud agents:** the update script is intentionally a no-op. Code review and static
edits to the `.swift` files are possible, but do not attempt to build/run/test here. Any actual
build, run, or manual testing must happen on macOS + Xcode:

```
./scripts/run.sh                       # fastest: boot sim, incremental build, launch
open RedMed-Xcode/RedMed.xcodeproj   # then Run (Cmd+R) against an iOS 17+ Simulator
# or, headless:
xcodebuild -project RedMed-Xcode/RedMed.xcodeproj -scheme RedMed \
  -destination 'platform=iOS Simulator,name=iPhone 15' build
```

`scripts/run.sh` keeps derived data in `.derivedData/`, skips rebuild when Swift/resources
are unchanged, and skips reinstall when the built app is unchanged. Override simulator with
`SIM="iPhone 17 Pro" ./scripts/run.sh`. Location is pre-granted on the simulator (Apple Park
coords); override with `LOCATION="40.7128,-74.0060" ./scripts/run.sh`.

On a **physical iPhone**, iOS requires a one-time Allow tap — that cannot be bypassed from code.

NFC write and Face ID flows only work on a physical iPhone, not the Simulator.
