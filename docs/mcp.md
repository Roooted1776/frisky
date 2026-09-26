# RedMed MCP

Ops-facing Model Context Protocol server for agents. Package lives in [`mcp/`](../mcp/).

## Project

| | |
|--|--|
| Supabase project | `mohxobgyjkcmkqxijgeg` |
| API URL | `https://mohxobgyjkcmkqxijgeg.supabase.co` |
| Dashboard | https://supabase.com/dashboard/project/mohxobgyjkcmkqxijgeg |
| Transport (v1) | **Cursor stdio** only (`npx tsx src/index.ts` from `mcp/`) |

## Product wall

Assist (`tapper/` → `https://redmed.live/tapper/`) stays no-auth / no RedMed DB.
Band ICE profiles stay in `#d=` (+ Owner Keychain). **Do not** put medical card
payloads in Supabase or expose them through MCP tools.

## Secrets

Set (never commit):

- `SUPABASE_URL` (optional; defaults to the project URL above)
- `SUPABASE_PUBLISHABLE_KEY` (`sb_publishable_…`)
- `SUPABASE_SECRET_KEY` (`sb_secret_…`, MCP process only)

See [`mcp/.env.example`](../mcp/.env.example). Rotate any key that appeared in chat
before treating it as production-trusted.

Cursor entry: [`.cursor/mcp.json`](../.cursor/mcp.json) → `redmed`.

## Tools (v1)

- `redmed_ping`
- `supabase_project_info`
- `supabase_list_tables`

No arbitrary SQL in v1.

## Hosting note

Hostinger for `redmed.live` is **Premium Web Hosting** (static Assist). There is no
VPS VM on that account for a remote MCP yet. Remote Streamable HTTP
(`mcp.redmed.live`) is a later step.
