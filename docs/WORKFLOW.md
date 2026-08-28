# Workflow

1. Short-lived branch + PR → **squash-merge into `main` only**.
2. GitHub Desktop → Fetch → Pull **`main`** into `/Users/claude/Documents/frisky` only. No other clone.
3. Delete the feature branch after merge. Do not keep parallel remotes (`wire-privacy-info-target` is unsafe).
4. Before **every Archive**: Xcode → `PrivacyInfo.xcprivacy` → File inspector → Target Membership → **RedMed**.
5. Open `RedMed-Xcode/RedMed.xcodeproj` from that same folder.

See `docs/DO-NOT.md`.
