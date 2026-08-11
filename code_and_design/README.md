# Design mirror — not the app

Open **`../RedMed-Xcode/RedMed.xcodeproj`** to build RedMed.

This folder holds Claude canvas HTML (`Main.dc.html`) and a **stale Swift
snapshot** under `RedMed-Xcode/`. There is intentionally **no** `.xcodeproj`
here — the nested project used to share `com.redmed.app` with an incomplete
source set and fooled people into building the wrong tree.
