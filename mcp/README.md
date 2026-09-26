# RedMed MCP (`mcp/`)

Cursor **stdio** + optional **Streamable HTTP** MCP for RedMed ops against
Supabase `mohxobgyjkcmkqxijgeg`, Hostinger (static Assist + VPS), and SSH/local
shell on the KVM.

## Product wall

- Assist at `https://redmed.live/tapper/` stays **no-auth, no DB**.
- Band ICE profiles live in `#d=` (and Owner Keychain) — **not** Supabase.
- Do **not** add tools that store or read medical card / `#d=` payloads.

## Tools (v0.2)

| Tool | Purpose |
|------|---------|
| `redmed_ping` | Process health + which env vars are set (no secrets) |
| `redmed_stack_status` | Supabase + Hostinger VPS/websites + shell probe |
| `supabase_project_info` | Project URL/ref + API health check |
| `supabase_list_tables` | Public tables via PostgREST OpenAPI (secret key) |
| `hostinger_vps_info` | VPS control-plane snapshot (API) |
| `hostinger_websites` | Hostinger websites (default `redmed.live`) |
| `hostinger_ssh_exec` | Non-interactive VPS shell (SSH or local) |
| `hostinger_ssh_probe` | Hostname + uptime check |

## Env

Copy [`.env.example`](.env.example) → `.env` (gitignored), or set Cursor secrets.

| Name | Role |
|------|------|
| `SUPABASE_URL` | Optional; defaults to project URL |
| `SUPABASE_PUBLISHABLE_KEY` | `sb_publishable_…` (RLS) |
| `SUPABASE_SECRET_KEY` | `sb_secret_…` (MCP process only) |
| `HOSTINGER_API_TOKEN` | Hostinger REST (or `~/.config/hostinger-mcp/api_token`) |
| `REDMED_VPS_HOST` / `USER` / `IDENTITY` | SSH target (Mini) |
| `REDMED_EXEC_MODE` | `ssh` (default) or `local` (VPS container) |
| `REDMED_MCP_TOKEN` | Bearer secret for remote HTTP |

Never commit real keys. Rotate any key that was pasted into chat.

## Run (stdio — Cursor)

```bash
cd mcp
npm install
npm start          # stdio MCP
npm run smoke      # live backends check
npm run typecheck
```

Cursor: [`.cursor/mcp.json`](../.cursor/mcp.json) → `redmed`.

## Run (HTTP — VPS)

```bash
REDMED_MCP_TOKEN=… REDMED_EXEC_MODE=local npm run start:http
# or: docker compose up -d  (see Dockerfile)
```

Public URL (canonical): `https://mcp.redmed.live/mcp`  
Interim (live now): `https://srv2010795.hstgr.cloud/mcp`  
Cursor entries: `redmed` (stdio), `redmed-remote` (live VPS HTTPS),
`redmed-remote-canonical` (`mcp.redmed.live` after DNS).
Bearer: `${env:REDMED_MCP_TOKEN}` (also `~/.config/redmed-mcp/token` + `~/.zshrc`).

DNS for the canonical host (Cloudflare **DNS-only** A → `2.25.249.204`):

```bash
export CLOUDFLARE_API_TOKEN=…   # Zone:DNS:Edit on redmed.live
node scripts/upsert-mcp-dns.mjs
```
