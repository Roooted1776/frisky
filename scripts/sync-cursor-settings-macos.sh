#!/usr/bin/env bash
# Copy Cursor user settings (theme + color customizations) MacBook ↔ Mini.
# Both machines are peers. Cloud agents cannot read either Mac.
# Run from Terminal.app on the Macs.
#
# On the Mac that looks right:
#   ~/Documents/frisky/scripts/sync-cursor-settings-macos.sh export
# Copy the tarball to the other Mac (AirDrop / USB / scp), then:
#   ~/Documents/frisky/scripts/sync-cursor-settings-macos.sh import [path-to-tarball]
#
# Colors live in User/settings.json:
#   workbench.colorTheme, workbench.colorCustomizations,
#   workbench.tokenColorCustomizations, editor.tokenColorCustomizations
set -euo pipefail

ok() { printf 'OK  %s\n' "$*"; }
warn() { printf 'WARN  %s\n' "$*"; }
die() { printf 'FAIL  %s\n' "$*" >&2; exit 1; }

CLONE_DIR="${FRISKY_HOME:-$HOME/Documents/frisky}"
BUNDLE_DIR="${CLONE_DIR}/.local/cursor-user-sync"
BUNDLE_NAME="cursor-user-sync.tar.gz"
DEFAULT_BUNDLE="${BUNDLE_DIR}/${BUNDLE_NAME}"
USER_DIR="${CURSOR_USER_DIR:-$HOME/Library/Application Support/Cursor/User}"
DOT_DIR="${CURSOR_DOT_DIR:-$HOME/.cursor}"
CURSOR_BIN="${CURSOR_BIN:-/Applications/Cursor.app/Contents/Resources/app/bin/cursor}"
MODE="${1:-}"
ARG2="${2:-}"

if [[ "$(uname -s)" != "Darwin" && "${FRISKY_ALLOW_NON_DARWIN:-}" != "1" ]]; then
  die "MacBook / Mac Mini only. This cloud VM has no Mini Cursor profile to import."
fi

require_user_dir() {
  [[ -d "$USER_DIR" ]] || die "no Cursor User dir at ${USER_DIR}. Open Cursor once on this Mac first."
}

quit_cursor_hint() {
  if pgrep -x Cursor >/dev/null 2>&1; then
    warn "Cursor is running. Quit it (Cmd+Q) before import so files are not overwritten on exit."
  fi
}

summarize_colors() {
  local settings="$1"
  [[ -f "$settings" ]] || { warn "no settings.json to summarize"; return 0; }
  if ! command -v python3 >/dev/null 2>&1; then
    warn "python3 missing; skip color summary"
    return 0
  fi
  python3 - "$settings" <<'PY'
import json, sys
path = sys.argv[1]
try:
    data = json.load(open(path, encoding="utf-8"))
except Exception as e:
    print(f"  (could not parse settings.json: {e})")
    raise SystemExit(0)
keys = [
    "workbench.colorTheme",
    "workbench.preferredDarkColorTheme",
    "workbench.preferredLightColorTheme",
    "workbench.iconTheme",
    "window.autoDetectColorScheme",
]
print("  color / theme keys:")
for k in keys:
    if k in data:
        print(f"    {k} = {data[k]!r}")
for k in ("workbench.colorCustomizations", "workbench.tokenColorCustomizations", "editor.tokenColorCustomizations"):
    v = data.get(k)
    if isinstance(v, dict):
        print(f"    {k}: {len(v)} entries")
    elif v is not None:
        print(f"    {k}: present")
if not any(k in data for k in keys) and not any(
    k in data for k in ("workbench.colorCustomizations", "workbench.tokenColorCustomizations", "editor.tokenColorCustomizations")
):
    print("    (no theme/color keys found — default theme or UI-only profile)")
PY
}

list_extensions() {
  local out="$1"
  if [[ -x "$CURSOR_BIN" ]]; then
    "$CURSOR_BIN" --list-extensions >"$out" 2>/dev/null || true
  elif command -v cursor >/dev/null 2>&1; then
    cursor --list-extensions >"$out" 2>/dev/null || true
  else
    warn "cursor CLI not found; extensions list skipped"
    : >"$out"
  fi
}

export_bundle() {
  require_user_dir
  mkdir -p "$BUNDLE_DIR"
  local staging
  staging="$(mktemp -d "${TMPDIR:-/tmp}/cursor-sync.XXXXXX")"
  trap 'rm -rf "$staging"' RETURN

  mkdir -p "$staging/User" "$staging/dot-cursor"
  [[ -f "$USER_DIR/settings.json" ]] && cp "$USER_DIR/settings.json" "$staging/User/"
  [[ -f "$USER_DIR/keybindings.json" ]] && cp "$USER_DIR/keybindings.json" "$staging/User/"
  if [[ -d "$USER_DIR/snippets" ]]; then
    mkdir -p "$staging/User/snippets"
    cp -R "$USER_DIR/snippets/." "$staging/User/snippets/" 2>/dev/null || true
  fi
  # Profiles carry theme + UI chrome when used.
  if [[ -d "$USER_DIR/profiles" ]]; then
    mkdir -p "$staging/User/profiles"
    cp -R "$USER_DIR/profiles/." "$staging/User/profiles/" 2>/dev/null || true
  fi

  # Dotfiles: MCP + permissions. Skip auth tokens / large state DBs.
  for f in mcp.json argv.json ide_state.json permissions.json cli-config.json; do
    [[ -f "$DOT_DIR/$f" ]] && cp "$DOT_DIR/$f" "$staging/dot-cursor/"
  done

  list_extensions "$staging/extensions.txt"
  {
    echo "exportedAt=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "host=$(hostname -s 2>/dev/null || hostname)"
    echo "userDir=${USER_DIR}"
  } >"$staging/MANIFEST.txt"

  local dest="${ARG2:-$DEFAULT_BUNDLE}"
  mkdir -p "$(dirname "$dest")"
  tar -C "$staging" -czf "$dest" .
  ok "exported → ${dest}"
  echo "Contents:"
  tar -tzf "$dest" | sed 's/^/  /' | head -40
  echo "Colors from settings.json:"
  summarize_colors "$staging/User/settings.json"
  if [[ -s "$staging/extensions.txt" ]]; then
    ok "extensions listed: $(wc -l <"$staging/extensions.txt" | tr -d ' ')"
  fi
  echo
  echo "Next: AirDrop/scp that tarball to the other Mac, then:"
  echo "  $0 import ${dest}"
}

import_bundle() {
  local src="${ARG2:-$DEFAULT_BUNDLE}"
  [[ -f "$src" ]] || die "bundle not found: ${src}"
  quit_cursor_hint
  mkdir -p "$USER_DIR" "$DOT_DIR"

  local staging
  staging="$(mktemp -d "${TMPDIR:-/tmp}/cursor-sync.XXXXXX")"
  trap 'rm -rf "$staging"' RETURN
  tar -C "$staging" -xzf "$src"

  local backup="${BUNDLE_DIR}/backup-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$backup/User" "$backup/dot-cursor"
  [[ -f "$USER_DIR/settings.json" ]] && cp "$USER_DIR/settings.json" "$backup/User/" || true
  [[ -f "$USER_DIR/keybindings.json" ]] && cp "$USER_DIR/keybindings.json" "$backup/User/" || true
  ok "pre-import backup → ${backup}"

  if [[ -d "$staging/User" ]]; then
    mkdir -p "$USER_DIR"
    # settings + keybindings + snippets + profiles
    [[ -f "$staging/User/settings.json" ]] && cp "$staging/User/settings.json" "$USER_DIR/"
    [[ -f "$staging/User/keybindings.json" ]] && cp "$staging/User/keybindings.json" "$USER_DIR/"
    if [[ -d "$staging/User/snippets" ]]; then
      mkdir -p "$USER_DIR/snippets"
      cp -R "$staging/User/snippets/." "$USER_DIR/snippets/"
    fi
    if [[ -d "$staging/User/profiles" ]]; then
      mkdir -p "$USER_DIR/profiles"
      cp -R "$staging/User/profiles/." "$USER_DIR/profiles/"
    fi
  fi

  if [[ -d "$staging/dot-cursor" ]]; then
    for f in mcp.json argv.json permissions.json cli-config.json; do
      [[ -f "$staging/dot-cursor/$f" ]] && cp "$staging/dot-cursor/$f" "$DOT_DIR/"
    done
  fi

  ok "imported settings into ${USER_DIR}"
  echo "Colors now on this Mac:"
  summarize_colors "$USER_DIR/settings.json"

  if [[ -s "$staging/extensions.txt" ]]; then
    local n
    n="$(wc -l <"$staging/extensions.txt" | tr -d ' ')"
    echo
    echo "Theme extensions (install if colors look wrong):"
    if [[ -x "$CURSOR_BIN" ]] || command -v cursor >/dev/null 2>&1; then
      local cli="$CURSOR_BIN"
      [[ -x "$cli" ]] || cli="cursor"
      while IFS= read -r ext; do
        [[ -z "$ext" ]] && continue
        echo "  installing ${ext}"
        "$cli" --install-extension "$ext" >/dev/null 2>&1 || warn "could not install ${ext}"
      done <"$staging/extensions.txt"
      ok "tried to install ${n} extensions"
    else
      warn "no cursor CLI — install these ${n} extensions manually (theme packs matter for colors):"
      sed 's/^/  /' "$staging/extensions.txt"
    fi
  fi

  echo
  echo "Reload Cursor: Cmd+Shift+P → Developer: Reload Window"
  echo "If theme still wrong: Cmd+K Cmd+T and pick the exported theme name from settings."
}

status_cmd() {
  echo "== Cursor user settings =="
  echo "User dir: ${USER_DIR}"
  if [[ -d "$USER_DIR" ]]; then
    ok "User dir exists"
    for f in settings.json keybindings.json; do
      if [[ -f "$USER_DIR/$f" ]]; then
        ok "$f ($(wc -c <"$USER_DIR/$f" | tr -d ' ') bytes)"
      else
        warn "missing $f"
      fi
    done
    echo "Colors:"
    summarize_colors "$USER_DIR/settings.json"
  else
    warn "User dir missing"
  fi
  if [[ -f "$DEFAULT_BUNDLE" ]]; then
    ok "local bundle: ${DEFAULT_BUNDLE} ($(wc -c <"$DEFAULT_BUNDLE" | tr -d ' ') bytes)"
  else
    warn "no local bundle at ${DEFAULT_BUNDLE}"
  fi
}

case "$MODE" in
  export) export_bundle ;;
  import) import_bundle ;;
  status) status_cmd ;;
  *)
    cat >&2 <<EOF
usage: $0 export [dest.tar.gz]
       $0 import [src.tar.gz]
       $0 status

export on the Mac that has the good prefs/colors (MacBook or Mini).
import on the other Mac after copying the tarball.
EOF
    exit 1
    ;;
esac
