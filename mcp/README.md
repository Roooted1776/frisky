# RedMed MCP (`mcp/`)

Cursor **stdio** MCP server for RedMed ops against Supabase project
`mohxobgyjkcmkqxijgeg`.

## Product wall

- Assist at `https://redmed.live/tapper/` stays **no-auth, no DB**.
- Band ICE profiles live in `#d=` (and Owner Keychain) — **not** Supabase.
- Do **not** add tools that store or read medical card / `#d=` payloads.

## Tools (v1)

| Tool | Purpose |
|------|---------|
| `redmed_ping` | Process health + which env vars are set (no key material) |
| `supabase_project_info` | Project URL/ref + API health check |
| `supabase_list_tables` | Public tables via PostgREST OpenAPI (needs secret key) |

## Env

Copy [`.env.example`](.env.example) → `.env` (gitignored), or set Cursor secrets:

| Name | Role |
|------|------|
| `SUPABASE_URL` | Optional; defaults to `https://mohxobgyjkcmkqxijgeg.supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY` | `sb_publishable_…` (RLS) |
| `SUPABASE_SECRET_KEY` | `sb_secret_…` (MCP process only; bypasses RLS) |

Never commit real keys. Rotate any key that was pasted into chat.

## Run

```bash
cd mcp
npm install
export SUPABASE_PUBLISHABLE_KEY=…
export SUPABASE_SECRET_KEY=…
npm start          # stdio MCP (Cursor spawns this)
npm run smoke      # non-stdio reachability check
npm run typecheck
```

Cursor wires this via [`.cursor/mcp.json`](../.cursor/mcp.json) (`redmed` entry).

## Out of scope (for later)

- Remote Streamable HTTP (`mcp.redmed.live` / VPS)
- Migrations / product tables
- Arbitrary SQL tools
