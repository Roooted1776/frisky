#!/bin/bash
# RedMed MCP stdio launcher for Cursor / Claude Desktop / Perplexity local connectors.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export PATH="/opt/homebrew/opt/node@22/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"
# Prefer process env; fall back to local secret files (never printed).
if [[ -z "${HOSTINGER_API_TOKEN:-}" && -f "${HOME}/.config/hostinger-mcp/api_token" ]]; then
  export HOSTINGER_API_TOKEN="$(tr -d '\n' < "${HOME}/.config/hostinger-mcp/api_token")"
fi
if [[ -z "${REDMED_MCP_TOKEN:-}" && -f "${HOME}/.config/redmed-mcp/token" ]]; then
  export REDMED_MCP_TOKEN="$(tr -d '\n' < "${HOME}/.config/redmed-mcp/token")"
fi
export REDMED_VPS_HOST="${REDMED_VPS_HOST:-hostinger-vps}"
export REDMED_VPS_USER="${REDMED_VPS_USER:-root}"
export REDMED_VPS_IDENTITY="${REDMED_VPS_IDENTITY:-${HOME}/.ssh/hostinger_vps}"
export REDMED_EXEC_MODE="${REDMED_EXEC_MODE:-ssh}"
exec /opt/homebrew/opt/node@22/bin/npx tsx src/index.ts
