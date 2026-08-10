#!/usr/bin/env bash
# Fast simulator launch: warm derived data, skip rebuild when sources unchanged.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJ="$ROOT/RedMed-Xcode/RedMed.xcodeproj"
SCHEME="RedMed"
BUNDLE_ID="com.redmed.app"
DD="$ROOT/.derivedData"
APP="$DD/Build/Products/Debug-iphonesimulator/RedMed.app"
STAMP="$DD/.last-install.stamp"
SRC_DIR="$ROOT/RedMed-Xcode/RedMed"

pick_simulator() {
  if [[ -n "${SIM:-}" ]]; then
    echo "$SIM"
    return
  fi
  for candidate in "iPhone 17 Pro" "iPhone 17" "iPhone 16 Pro" "iPhone 16" "iPhone 15 Pro" "iPhone 15"; do
    if xcrun simctl list devices available 2>/dev/null | grep -Fq "$candidate ("; then
      echo "$candidate"
      return
    fi
  done
  xcrun simctl list devices available 2>/dev/null \
    | sed -n 's/^[[:space:]]*\(iPhone[^()]*\) (.*/\1/p' \
    | head -1
}

needs_build() {
  [[ ! -d "$APP" ]] && return 0
  local newest_src
  newest_src="$(find "$SRC_DIR" "$PROJ" -type f \( -name '*.swift' -o -name '*.plist' -o -name '*.html' -o -name '*.css' -o -name 'project.pbxproj' \) -print0 \
    | xargs -0 stat -f '%m' 2>/dev/null | sort -n | tail -1)"
  local app_mtime
  app_mtime="$(stat -f '%m' "$APP" 2>/dev/null || echo 0)"
  [[ "$newest_src" -gt "$app_mtime" ]]
}

needs_install() {
  [[ ! -f "$STAMP" ]] && return 0
  [[ ! -d "$APP" ]] && return 0
  local app_mtime stamp_mtime
  app_mtime="$(stat -f '%m' "$APP")"
  stamp_mtime="$(stat -f '%m' "$STAMP")"
  [[ "$app_mtime" -gt "$stamp_mtime" ]]
}

SIMULATOR="$(pick_simulator)"
if [[ -z "$SIMULATOR" ]]; then
  echo "No available iPhone simulator found." >&2
  exit 1
fi

echo "Simulator: $SIMULATOR"

# Boot + show UI immediately so the wait feels shorter.
open -a Simulator >/dev/null 2>&1 || true
xcrun simctl boot "$SIMULATOR" 2>/dev/null || true
xcrun simctl bootstatus booted -b >/dev/null 2>&1 || true

if needs_build; then
  echo "Building..."
  xcodebuild -project "$PROJ" -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,name=$SIMULATOR" \
    -derivedDataPath "$DD" \
    -parallelizeTargets \
    -quiet \
    build
else
  echo "Build skipped (sources unchanged)."
fi

if needs_install; then
  echo "Installing..."
  xcrun simctl install booted "$APP"
  touch "$STAMP"
else
  echo "Install skipped (app unchanged)."
fi

# Pre-grant location so Find 911 works without the system prompt (simulator only).
echo "Granting location..."
xcrun simctl privacy booted grant location "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl location booted set "${LOCATION:-37.3317,-122.0301}" 2>/dev/null || true

echo "Launching..."
xcrun simctl launch --terminate-running-process booted "$BUNDLE_ID" >/dev/null
