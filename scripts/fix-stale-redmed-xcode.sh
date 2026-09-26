#!/usr/bin/env bash
# Fix Xcode "missing project.pbxproj" when Recents still open the pre-rename path
# RedMed-Xcode/RedMed.xcodeproj. Canonical project is owner/RedMed.xcodeproj;
# RedMed-Xcode is a compatibility symlink → owner (see docs/WORKFLOW.md).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LEGACY="$ROOT/RedMed-Xcode"
CANON="$ROOT/owner"
PBX="$CANON/RedMed.xcodeproj/project.pbxproj"

ok() { printf 'OK  %s\n' "$*"; }
warn() { printf 'WARN  %s\n' "$*"; }
die() { printf 'FAIL  %s\n' "$*" >&2; exit 1; }

test -f "$PBX" || die "canonical project missing: $PBX (pull main first)"

# Prefer the tracked symlink from git. If a local directory blocks it (zombie
# .cursor leftovers or an empty RedMed.xcodeproj shell), replace with symlink.
if [[ -L "$LEGACY" ]]; then
  target="$(readlink "$LEGACY")"
  if [[ "$target" == "owner" || "$target" == "$CANON" ]]; then
    ok "RedMed-Xcode → owner"
  else
    warn "RedMed-Xcode symlink points at $target (expected owner); rewriting"
    rm -f "$LEGACY"
    ln -s owner "$LEGACY"
    ok "rewrote RedMed-Xcode → owner"
  fi
elif [[ -d "$LEGACY" ]]; then
  warn "removing zombie RedMed-Xcode/ directory (pre-rename leftover)"
  # Empty/broken .xcodeproj packages cause the exact dialog in the screenshot.
  if [[ -d "$LEGACY/RedMed.xcodeproj" && ! -f "$LEGACY/RedMed.xcodeproj/project.pbxproj" ]]; then
    warn "found empty RedMed.xcodeproj (no project.pbxproj)"
  fi
  rm -rf "$LEGACY"
  ln -s owner "$LEGACY"
  ok "replaced zombie dir with RedMed-Xcode → owner"
elif [[ -e "$LEGACY" ]]; then
  die "RedMed-Xcode exists but is not a directory or symlink: $LEGACY"
else
  ln -s owner "$LEGACY"
  ok "created RedMed-Xcode → owner"
fi

test -f "$LEGACY/RedMed.xcodeproj/project.pbxproj" \
  || die "symlink did not expose project.pbxproj"

ok "open either:"
printf '    %s\n' "$CANON/RedMed.xcodeproj"
printf '    %s\n' "$LEGACY/RedMed.xcodeproj"
printf '\nIf Xcode Recents still fail: File → Close Project, then open the path above.\n'
