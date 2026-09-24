#!/usr/bin/env bash
# Dual-Mac My Machines worker: run on MacBook Air AND Mac Mini (Terminal.app).
# Agent loop stays in Cursor cloud; tools run on this Mac. Do not run on Linux Cloud.
# Docs: https://cursor.com/docs/cloud-agent/self-hosted/my-machines
set -euo pipefail

CLONE_DIR="${FRISKY_HOME:-$HOME/Documents/frisky}"
WANT_REMOTE_HINT="github.com/Roooted1776/frisky"

usage() {
  cat <<'EOF'
Usage:
  setup-mac-worker.sh status
  setup-mac-worker.sh install
  setup-mac-worker.sh login
  setup-mac-worker.sh start <macbook-air|mac-mini> [--computer-use]
  setup-mac-worker.sh debug

Names (must match worker= / machine= when targeting from Slack/GitHub/agents UI):
  macbook-air  — laptop
  mac-mini     — always-on; use --computer-use for Xcode / GUI

Same Cursor account as Desktop / cursor.com/agents / this phone session.
EOF
}

ok() { printf 'OK  %s\n' "$*"; }
warn() { printf 'WARN  %s\n' "$*"; }
die() { printf 'FAIL  %s\n' "$*" >&2; exit 1; }

require_darwin() {
  [[ "$(uname -s)" == "Darwin" ]] || die "MacBook Air / Mac Mini only. Linux Cloud Agents already run managed; do not start a worker here."
}

ensure_agent_cli() {
  if command -v agent >/dev/null 2>&1; then
    return 0
  fi
  warn "Cursor CLI (agent) not on PATH. Installing…"
  curl https://cursor.com/install -fsS | bash
  # Common install locations; refresh PATH for this shell.
  export PATH="${HOME}/.local/bin:${HOME}/.cursor/bin:${PATH}"
  command -v agent >/dev/null 2>&1 || die "agent still missing after install. Open a new Terminal tab and retry."
}

require_clone() {
  [[ -d "${CLONE_DIR}/.git" ]] || die "No clone at ${CLONE_DIR}. Run: ~/Documents/frisky/scripts/setup-mac-git.sh"
  cd "$CLONE_DIR"
  local origin
  origin="$(git remote get-url origin 2>/dev/null || true)"
  case "$origin" in
    *"${WANT_REMOTE_HINT}"*) ;;
    *) die "origin is ${origin:-empty} — expected ${WANT_REMOTE_HINT}" ;;
  esac
}

cmd_status() {
  require_darwin
  if command -v agent >/dev/null 2>&1; then
    ok "agent = $(command -v agent) ($(agent --version 2>/dev/null || echo unknown))"
  else
    warn "agent CLI not installed (run: $0 install)"
  fi
  if [[ -d "${CLONE_DIR}/.git" ]]; then
    ok "clone = ${CLONE_DIR} (origin $(git -C "$CLONE_DIR" remote get-url origin))"
  else
    warn "clone missing at ${CLONE_DIR}"
  fi
  if command -v agent >/dev/null 2>&1; then
    echo "--- agent worker debug ---"
    agent worker debug || warn "worker debug failed (login or network?)"
  fi
}

cmd_install() {
  require_darwin
  ensure_agent_cli
  ok "agent --version → $(agent --version)"
}

cmd_login() {
  require_darwin
  ensure_agent_cli
  echo "Sign in with the SAME Cursor account used on Desktop and cursor.com/agents."
  agent login
  ok "logged in"
}

cmd_start() {
  require_darwin
  local name="${1:-}"
  local computer_use=0
  shift || true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --computer-use) computer_use=1 ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown flag: $1" ;;
    esac
    shift
  done
  case "$name" in
    macbook-air|mac-mini) ;;
    *) die "name must be macbook-air or mac-mini (got: ${name:-empty})" ;;
  esac
  ensure_agent_cli
  require_clone
  local -a args=(worker)
  if [[ "$computer_use" -eq 1 ]]; then
    args+=(--computer-use)
    if [[ "$name" == "mac-mini" ]]; then
      ok "computer-use: after first start, grant Accessibility + Screen Recording to Cursor Computer Use"
    fi
  fi
  args+=(start --name "$name" --worker-dir "$CLONE_DIR")
  echo "Starting My Machines worker name=${name} dir=${CLONE_DIR}"
  echo "Keep this Terminal window open. Target from agents UI or worker=${name}."
  exec agent "${args[@]}"
}

cmd_debug() {
  require_darwin
  ensure_agent_cli
  require_clone
  agent worker debug
}

main() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    status) cmd_status ;;
    install) cmd_install ;;
    login) cmd_login ;;
    start) cmd_start "$@" ;;
    debug) cmd_debug ;;
    -h|--help|help|"") usage; [[ -n "$cmd" ]] || exit 1 ;;
    *) die "unknown command: $cmd (try --help)" ;;
  esac
}

main "$@"
