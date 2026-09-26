#!/usr/bin/env bash
# Mirror this clone (with history) to Roooted1776/RedMed-V1-Official.
# Cloud Agent git tokens may lack push on the new repo — run on Max's Mac
# after `gh auth login` as Roooted1776.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
REMOTE_URL="${1:-https://github.com/Roooted1776/RedMed-V1-Official.git}"

if ! git remote get-url v1 >/dev/null 2>&1; then
  git remote add v1 "$REMOTE_URL"
else
  git remote set-url v1 "$REMOTE_URL"
fi

echo "Pushing all branches + tags to $REMOTE_URL …"
git push v1 --all
git push v1 --tags
echo "Done. Set GitHub default branch to main on RedMed-V1-Official."
echo "Optional: archive frisky README to point here."
