#!/usr/bin/env bash
# Resolve the 3 conflicts in PR #16 (main-faster-app-launch-7ce4 <- main).
# Run from the repo root. Does NOT commit or push.
set -euo pipefail

git rev-parse --abbrev-ref HEAD | grep -qx 'main-faster-app-launch-7ce4' \
  || { echo "Not on main-faster-app-launch-7ce4"; exit 1; }

git fetch origin
git merge origin/main --no-commit --no-ff || true

EXPECTED="RedMed-Xcode/RedMed/EmergencyView.swift
uploads/Services/NetworkPathMonitor.swift
uploads/Views/LocationView.swift"
ACTUAL=$(git diff --name-only --diff-filter=U | sort)
if [ "$ACTUAL" != "$EXPECTED" ]; then
  echo "Conflict set changed since this script was written."
  echo "expected:"; echo "$EXPECTED"
  echo "actual:";   echo "$ACTUAL"
  echo "Re-check the resolutions before proceeding. Run 'git merge --abort' to back out."
  exit 1
fi

# 1) EmergencyView.swift — take main's side.
#    main deleted @State showPublicCard AND the "Scan emergency bracelet" button
#    that set it, so keeping the branch's .sheet(isPresented: $showPublicCard)
#    would not compile. The branch's other change here (LocationManager
#    coarse-to-fine + stop()) is already on main verbatim, so nothing is lost.
git checkout --theirs -- RedMed-Xcode/RedMed/EmergencyView.swift
git add RedMed-Xcode/RedMed/EmergencyView.swift

# 2) + 3) Comment-only conflicts. Keep both lines: each states a different fact.
python3 - <<'PY'
import re, sys

edits = {
  "uploads/Services/NetworkPathMonitor.swift":
    "/// Constructed with LocationView (lazy tab), so it does not run at cold launch.\n"
    "/// Start explicitly after first paint — do not begin NWPathMonitor in `init`.\n",
  "uploads/Views/LocationView.swift":
    "            // After first layout — don't compete with cold-start paint for the main thread.\n"
    "            // GPS first; path monitor + SOS after first paint.\n",
}

HUNK = re.compile(r"^<<<<<<< .*?\n.*?^>>>>>>> .*?\n", re.S | re.M)

fail = False
for path, replacement in edits.items():
    src = open(path, encoding="utf-8").read()
    hunks = HUNK.findall(src)
    if len(hunks) != 1:
        print(f"ERROR: {path} has {len(hunks)} conflict hunks, expected 1", file=sys.stderr)
        fail = True
        continue
    open(path, "w", encoding="utf-8").write(HUNK.sub(lambda _: replacement, src, count=1))
    print("resolved", path)

sys.exit(1 if fail else 0)
PY
git add uploads/Services/NetworkPathMonitor.swift uploads/Views/LocationView.swift

# Verify: no unmerged paths, no leftover markers anywhere in the tree.
if [ -n "$(git diff --name-only --diff-filter=U)" ]; then
  echo "FAIL: unmerged paths remain:"; git diff --name-only --diff-filter=U; exit 1
fi
if git grep -nE '^(<<<<<<< |=======$|>>>>>>> )' -- '*.swift' ; then
  echo "FAIL: conflict markers remain"; exit 1
fi

echo
echo "All 3 conflicts resolved and staged. Nothing committed."
echo "Review with:  git diff --cached"
echo "Then commit:  git commit --no-edit"
echo "Back out:     git merge --abort"
