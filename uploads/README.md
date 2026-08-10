# Upload staging — not the Xcode target

Experimental / WIP Swift and assets land here. **Nothing under `uploads/` is
compiled by `RedMed-Xcode/RedMed.xcodeproj`.**

Shipable source of truth: `../RedMed-Xcode/`.
If a change belongs in the app, copy it into that tree and wire it in the
canonical `project.pbxproj` — do not point Xcode at this folder.
