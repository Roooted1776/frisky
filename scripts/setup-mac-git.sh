#!/usr/bin/env bash
# Dual-Mac git: run on the MacBook AND the Mac Mini from Terminal.app.
# Hub is GitHub HTTPS. This script does not copy Cloud Agent tokens.
set -euo pipefail

REPO_SLUG="Roooted1776/frisky"
REPO_HTTPS="https://github.com/${REPO_SLUG}.git"
CLONE_DIR="${FRISKY_HOME:-$HOME/Documents/frisky}"
WANT_NAME="Max"
# GitHub-verified author on this repo (squash-merge / Desktop). Not Cursor login.
WANT_EMAIL="maxaguilaraasted@gmail.com"
WANT_LOGIN="Roooted1776"

ok() { printf 'OK  %s\n' "$*"; }
warn() { printf 'WARN  %s\n' "$*"; }
die() { printf 'FAIL  %s\n' "$*" >&2; exit 1; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  die "MacBook / Mac Mini only. Cloud git is already authenticated; do not run this here."
fi

if ! command -v git >/dev/null 2>&1; then
  die "git missing. Install Xcode Command Line Tools: xcode-select --install"
fi

if ! command -v gh >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing gh via Homebrew…"
    brew install gh
  else
    die "Install Homebrew (https://brew.sh), then: brew install gh"
  fi
fi

if ! gh auth status -h github.com >/dev/null 2>&1; then
  echo "Log in as ${WANT_LOGIN}."
  echo "GitHub.com → HTTPS → yes to git credentials → browser."
  gh auth login -h github.com -p https -w
fi

login="$(gh api user --jq .login)"
[[ "$login" == "$WANT_LOGIN" ]] || die "gh is ${login}, need ${WANT_LOGIN}. Run: gh auth logout && gh auth login"
ok "gh auth = ${login}"
gh auth setup-git >/dev/null
ok "git credential helper wired to gh"

if [[ ! -d "${CLONE_DIR}/.git" ]]; then
  echo "Cloning ${REPO_SLUG} → ${CLONE_DIR}"
  mkdir -p "$(dirname "$CLONE_DIR")"
  gh repo clone "$REPO_SLUG" "$CLONE_DIR"
fi

cd "$CLONE_DIR"
[[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" == "true" ]] || die "${CLONE_DIR} is not a git repo"

origin="$(git remote get-url origin)"
case "$origin" in
  *github.com/Roooted1776/frisky*) ;;
  *) die "origin is ${origin} — expected ${REPO_HTTPS}" ;;
esac
git remote set-url origin "$REPO_HTTPS"
ok "origin = $(git remote get-url origin)"

extra="$(git remote | grep -v '^origin$' || true)"
if [[ -n "$extra" ]]; then
  die "extra remotes: ${extra}. Remove them (only origin). See docs/DUAL-MAC.md"
fi
ok "no extra remotes"

name="$(git config --local --get user.name || true)"
email="$(git config --local --get user.email || true)"
# Pin dual-Mac identity. Overwrite school / mrmax115 / Cursor Agent / any non-match.
# Cursor/Grok may stay on m.aguilar-aasted@students.mccc.edu — that is OK (docs/DUAL-MAC.md).
if [[ -z "$name" || "$name" == "Cursor Agent" || "$name" != "$WANT_NAME" ]]; then
  git config --local user.name "$WANT_NAME"
  name="$WANT_NAME"
fi
if [[ -z "$email" || "$email" != "$WANT_EMAIL" ]]; then
  git config --local user.email "$WANT_EMAIL"
  email="$WANT_EMAIL"
fi
ok "identity ${name} <${email}>"

git fetch origin
ok "fetch"

if [[ -n "$(git status --porcelain)" ]]; then
  warn "uncommitted changes — not pulling. Commit or stash on this Mac first."
  git status -sb
else
  git checkout main >/dev/null 2>&1 || die "cannot checkout main"
  git pull --ff-only origin main
  ok "main = $(git rev-parse --short HEAD) (ff-only pull)"
fi

git push --dry-run origin main:main
ok "push dry-run (main)"

host="$(scutil --get ComputerName 2>/dev/null || hostname)"
ok "${host} can push/pull ${REPO_HTTPS} from this network"
echo
echo "Next: GitHub Desktop → this folder only. Pull main before Xcode."
