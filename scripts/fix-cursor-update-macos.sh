#!/usr/bin/env bash
# Repair Cursor desktop ShipIt on MacBook and Mac Mini.
# Run from Terminal.app (not Cursor). Cloud VMs cannot do this for you.
set -euo pipefail

die() { printf 'FAIL  %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK  %s\n' "$*"; }
warn() { printf 'WARN  %s\n' "$*"; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  die "macOS only. Cursor.app lives on the Macs, not in this cloud agent."
fi

APP="/Applications/Cursor.app"
SHIPIT_CACHE="${HOME}/Library/Caches/com.todesktop.230313mzl4w4u92.ShipIt"
CURSOR_CACHE="${HOME}/Library/Caches/Cursor"
UPDATER_CACHE="${HOME}/Library/Application Support/Caches/cursor-updater"
MODE="${1:-diagnose}"

quit_cursor() {
  osascript -e 'tell application "Cursor" to quit' >/dev/null 2>&1 || true
  sleep 2
  killall Cursor ShipIt 2>/dev/null || true
  sleep 1
}

diagnose() {
  echo "== Cursor update diagnose =="
  if [[ -d "$APP" ]]; then
    ok "found ${APP}"
    echo "xattr:"
    xattr -l "$APP" 2>&1 | sed 's/^/  /' || true
  else
    warn "no ${APP} — install from https://cursor.com/download into /Applications"
  fi

  extras="$(mdfind 'kMDItemCFBundleIdentifier == "com.todesktop.230313mzl4w4u92"' 2>/dev/null || true)"
  if [[ -n "$extras" ]]; then
    echo "Cursor bundles Spotlight sees:"
    while IFS= read -r line; do
      [[ -n "$line" ]] && printf '  %s\n' "$line"
    done <<< "$extras"
  fi

  for d in "$SHIPIT_CACHE" "$CURSOR_CACHE" "$UPDATER_CACHE"; do
    if [[ -e "$d" ]]; then
      warn "cache present: $d"
    else
      ok "no cache: $d"
    fi
  done

  if pgrep -x Cursor >/dev/null 2>&1; then
    warn "Cursor is running. Quit it (Cmd+Q) before repair."
  else
    ok "Cursor is not running"
  fi
}

repair() {
  echo "== repair (quit + clear ShipIt caches) =="
  quit_cursor
  rm -rf "$SHIPIT_CACHE" "$CURSOR_CACHE" "$UPDATER_CACHE"
  ok "cleared ShipIt / Cursor updater caches"
  if [[ -d "$APP" ]]; then
    if xattr -dr com.apple.quarantine "$APP" 2>/dev/null; then
      ok "stripped com.apple.quarantine"
    else
      warn "quarantine strip failed (often com.apple.macl). Clean reinstall is the fix."
    fi
  fi
  echo
  echo "Reopen Cursor. If update still fails, run: $0 reinstall-prep"
}

reinstall_prep() {
  echo "== reinstall-prep =="
  quit_cursor
  rm -rf "$SHIPIT_CACHE" "$CURSOR_CACHE" "$UPDATER_CACHE"
  if [[ -d "$APP" ]]; then
    trash="${HOME}/.Trash/Cursor.app"
    rm -rf "$trash"
    mv "$APP" "$trash"
    ok "moved ${APP} → ~/.Trash"
  else
    warn "${APP} already gone"
  fi
  echo
  echo "1. Empty Trash."
  echo "2. Download https://cursor.com/download"
  echo "3. Install one copy into /Applications. Do not run from the DMG or Downloads."
  echo "4. Open /Applications/Cursor.app"
  echo "Chats/settings stay in ~/Library/Application Support/Cursor and ~/.cursor"
}

case "$MODE" in
  diagnose) diagnose ;;
  repair) repair ;;
  reinstall-prep) reinstall_prep ;;
  *)
    die "usage: $0 diagnose|repair|reinstall-prep"
    ;;
esac
