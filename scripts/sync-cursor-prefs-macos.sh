#!/usr/bin/env bash
# Dual-Mac Cursor prefs: MacBook AND Mac Mini.
# Copies theme/colors (settings.json), keybindings, and snippets between machines.
# Does not touch Cloud Agent tokens, mcp.json secrets, or state.vscdb.
set -euo pipefail

CLONE_DIR="${FRISKY_HOME:-$HOME/Documents/frisky}"
USER_DIR="${HOME}/Library/Application Support/Cursor/User"
BUNDLE_DIR="${CLONE_DIR}/.local/cursor-user"
HOST="$(scutil --get ComputerName 2>/dev/null || hostname -s)"

ok() { printf 'OK  %s\n' "$*"; }
warn() { printf 'WARN  %s\n' "$*"; }
die() { printf 'FAIL  %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: sync-cursor-prefs-macos.sh <export|import|status> [bundle-dir]

MacBook and Mac Mini are peers. Same script on both.

  export   Quit Cursor first. Copy settings/keybindings/snippets → bundle.
  import   Quit Cursor first. Apply bundle → this Mac's Cursor User folder.
  status   Show theme keys on this Mac and whether a bundle exists.

Default bundle: ~/Documents/frisky/.local/cursor-user (gitignored).
Carry the folder (AirDrop / USB) or run export on one Mac and import on the other
after the folder is present. Profiles UI also works: Export Profile → Import Profile.

Colors live in settings.json:
  workbench.colorTheme
  workbench.colorCustomizations
EOF
  exit 2
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  die "MacBook / Mac Mini only. Cursor.app User prefs are not on this cloud agent."
fi

cmd="${1:-}"
[[ -n "$cmd" ]] || usage
shift || true
if [[ $# -gt 0 ]]; then
  BUNDLE_DIR="$1"
fi

cursor_running() {
  pgrep -x Cursor >/dev/null 2>&1 || pgrep -f '/Applications/Cursor.app' >/dev/null 2>&1
}

require_quit() {
  if cursor_running; then
    die "Quit Cursor.app first (Dock → Quit). Open prefs mid-copy corrupts User state."
  fi
}

show_theme() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    warn "no settings.json at ${f}"
    return
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$f" <<'PY'
import json, sys
path = sys.argv[1]
try:
    data = json.load(open(path))
except Exception as e:
    print(f"  (unreadable settings.json: {e})")
    raise SystemExit(0)
for k in (
    "workbench.colorTheme",
    "workbench.preferredDarkColorTheme",
    "workbench.preferredLightColorTheme",
    "workbench.colorCustomizations",
):
    if k in data:
        v = data[k]
        if isinstance(v, dict):
            print(f"  {k}: {{{len(v)} keys}}")
        else:
            print(f"  {k}: {v}")
if "workbench.colorTheme" not in data and "workbench.colorCustomizations" not in data:
    print("  (no colorTheme / colorCustomizations keys yet)")
PY
  else
    warn "python3 missing — open settings.json by hand for theme keys"
  fi
}

case "$cmd" in
  status)
    echo "Machine: ${HOST}"
    echo "User:    ${USER_DIR}"
    echo "Bundle:  ${BUNDLE_DIR}"
    echo "This Mac theme:"
    show_theme "${USER_DIR}/settings.json"
    if [[ -f "${BUNDLE_DIR}/settings.json" ]]; then
      echo "Bundle theme:"
      show_theme "${BUNDLE_DIR}/settings.json"
      [[ -f "${BUNDLE_DIR}/SOURCE.txt" ]] && echo "Source:  $(cat "${BUNDLE_DIR}/SOURCE.txt")"
    else
      warn "no bundle yet — run export on the Mac whose colors you want"
    fi
    ;;
  export)
    require_quit
    [[ -d "$USER_DIR" ]] || die "missing ${USER_DIR} — open Cursor once on this Mac first"
    mkdir -p "$BUNDLE_DIR/snippets"
    # settings + keybindings (colors are inside settings.json)
    if [[ -f "${USER_DIR}/settings.json" ]]; then
      cp -f "${USER_DIR}/settings.json" "${BUNDLE_DIR}/settings.json"
      ok "settings.json"
    else
      die "no settings.json — pick a theme once in Cursor, then re-export"
    fi
    if [[ -f "${USER_DIR}/keybindings.json" ]]; then
      cp -f "${USER_DIR}/keybindings.json" "${BUNDLE_DIR}/keybindings.json"
      ok "keybindings.json"
    else
      warn "no keybindings.json (ok)"
      rm -f "${BUNDLE_DIR}/keybindings.json"
    fi
    rm -rf "${BUNDLE_DIR}/snippets"
    if [[ -d "${USER_DIR}/snippets" ]]; then
      cp -R "${USER_DIR}/snippets" "${BUNDLE_DIR}/snippets"
      ok "snippets/"
    else
      mkdir -p "${BUNDLE_DIR}/snippets"
      warn "no snippets/ (ok)"
    fi
    printf '%s\n' "${HOST}" > "${BUNDLE_DIR}/SOURCE.txt"
    date -u +"%Y-%m-%dT%H:%M:%SZ" > "${BUNDLE_DIR}/EXPORTED_AT.txt"
    ok "exported from ${HOST} → ${BUNDLE_DIR}"
    echo "Theme in bundle:"
    show_theme "${BUNDLE_DIR}/settings.json"
    echo
    echo "Next: on the other Mac (MacBook or Mini), put this folder at"
    echo "  ${BUNDLE_DIR}"
    echo "then: ${CLONE_DIR}/scripts/sync-cursor-prefs-macos.sh import"
    ;;
  import)
    require_quit
    [[ -f "${BUNDLE_DIR}/settings.json" ]] || die "no bundle at ${BUNDLE_DIR}/settings.json — export on the other Mac first"
    mkdir -p "${USER_DIR}/snippets"
    # backup current
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    bak="${USER_DIR}/.frisky-prefs-bak-${stamp}"
    mkdir -p "$bak"
    [[ -f "${USER_DIR}/settings.json" ]] && cp -f "${USER_DIR}/settings.json" "${bak}/settings.json"
    [[ -f "${USER_DIR}/keybindings.json" ]] && cp -f "${USER_DIR}/keybindings.json" "${bak}/keybindings.json"
    [[ -d "${USER_DIR}/snippets" ]] && cp -R "${USER_DIR}/snippets" "${bak}/snippets"
    ok "backup → ${bak}"

    cp -f "${BUNDLE_DIR}/settings.json" "${USER_DIR}/settings.json"
    ok "settings.json (theme/colors)"
    if [[ -f "${BUNDLE_DIR}/keybindings.json" ]]; then
      cp -f "${BUNDLE_DIR}/keybindings.json" "${USER_DIR}/keybindings.json"
      ok "keybindings.json"
    fi
    if [[ -d "${BUNDLE_DIR}/snippets" ]]; then
      rm -rf "${USER_DIR}/snippets"
      cp -R "${BUNDLE_DIR}/snippets" "${USER_DIR}/snippets"
      ok "snippets/"
    fi
    src="$(cat "${BUNDLE_DIR}/SOURCE.txt" 2>/dev/null || echo unknown)"
    ok "imported onto ${HOST} from ${src}"
    echo "Theme now:"
    show_theme "${USER_DIR}/settings.json"
    echo
    echo "Re-open Cursor.app. Extensions are not copied — install any missing theme extension if the colorTheme name is unknown."
    ;;
  *)
    usage
    ;;
esac
