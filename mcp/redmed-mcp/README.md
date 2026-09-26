# redmed-mcp v0.2

Cursor MCP server for **RedMed ops** (Hostinger API status, SSH exec helper hooks, Supabase project health).

## Product wall (do not break)

This MCP must **never**:

- Accept, decode, store, or log Assist `#d=` fragments or ICE medical profiles
- Write medical data to Supabase, VPS disk, or Hostinger files
- Treat the VPS as the Assist write origin (`redmed.live/tapper/` stays Hostinger static)

Ops-only Supabase project: `mohxobgyjkcmkqxijgeg` (`RedMed Secure Data`). Keep tables free of PHI.

## Tools

| Tool | Purpose |
|------|---------|
| `redmed_stack_status` | DNS / origin / github.io / Supabase project summary (read-only) |
| `hostinger_ssh_exec` | Run a **non-destructive** command on the ops VPS over SSH (blocked patterns enforced) |
| `supabase_ops_status` | Project ref + table count (no row reads of medical data) |

Hostinger product MCPs (websites, DNS, VPS power) remain on Cursor’s Hostinger plugin — this package complements them.

## Run

```bash
cd mcp/redmed-mcp && npm ci
export HOSTINGER_API_TOKEN=…   # optional for richer status
export REDMED_SSH_HOST=2.25.249.204
export REDMED_SSH_KEY=~/.ssh/hostinger_vps
node bin/redmed-mcp.mjs
```

CLI status without MCP:

```bash
node bin/redmed-stack-status.mjs
```

## Cursor entry

See repo [`.cursor/mcp.json`](../../.cursor/mcp.json) — server id `redmed`.
