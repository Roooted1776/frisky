# Workflow

1. Short-lived branch + PR → **squash-merge into `main` only**.
2. On the Mac you will open Xcode (MacBook Air **or** Mini): Fetch → Pull **`main`** into `~/Documents/frisky` only. One clone per machine. Hub is GitHub HTTPS — see [`DUAL-MAC.md`](DUAL-MAC.md) (My Machines workers: `macbook-air` / `mac-mini`).
3. Delete the feature branch after merge. Do not keep parallel remotes (`wire-privacy-info-target` is unsafe).
4. Before **every Archive**: Xcode → `PrivacyInfo.xcprivacy` → File inspector → Target Membership → **RedMed**.
5. Open `owner/RedMed.xcodeproj` from that same folder.
   - Legacy path `RedMed-Xcode/` is a **symlink → `owner/`** so Xcode Recents that still point at `RedMed-Xcode/RedMed.xcodeproj` keep working.
   - If you see “missing the internal project data file” / no `project.pbxproj`: a zombie `RedMed-Xcode/` directory (empty `.xcodeproj` shell) is blocking the symlink. Run `bash scripts/fix-stale-redmed-xcode.sh`, then open `owner/RedMed.xcodeproj` (or the repaired symlink path).

See `docs/DO-NOT.md`.
