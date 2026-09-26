# RedMed ops stack

Ops is separate from the Assist band write path. **Never** put ICE profiles, Assist `#d=` payloads, or medical card data through MCP, Supabase, or the VPS.

## Topology

| Layer | Role |
|-------|------|
| **Assist origin** | Hostinger shared static (`redmed.live` / plan IP `195.35.60.70`) |
| **DNS + edge SSL** | Cloudflare (cutover: `scripts/setup-cloudflare-dns.mjs`) |
| **Registrar** | Namecheap (NS → Cloudflare after cutover) |
| **Backup Assist** | `Roooted1776.github.io` via `scripts/publish-github-io.sh` |
| **VPS** | Hostinger KVM `2010795` / `srv2010795.hstgr.cloud` / `2.25.249.204` — Docker/Traefik for **ops tools only** |
| **Supabase** | Project `mohxobgyjkcmkqxijgeg` (`RedMed Secure Data`) — ops/metadata only; no PHI |
| **MCP** | In-repo `mcp/redmed-mcp` (v0.2) + Cursor Hostinger product MCPs |

## VPS (ops only)

- SSH: `hostinger-vps` → `root@2.25.249.204` with `~/.ssh/hostinger_vps` (helper `hostinger-vps` in `~/.local/bin` when installed).
- Companion: `hostinger-vps-ssh` MCP for SFTP/rich SSH.
- Hostinger product MCP (`Hostinger-vps`): power, firewall, snapshots — not shell.
- Confirm before destructive changes (reboot, recreate, firewall wipe, `rm -rf`).

**Do not** point `redmed.live` A records at the VPS for Assist in this sprint. Assist stays on Hostinger static.

## Secrets matrix

| Secret | Where | Used for |
|--------|-------|----------|
| `HOSTINGER_API_TOKEN` | CI + agent env + MCP | Static deploy, website APIs |
| `CLOUDFLARE_API_TOKEN` | CI + agent env | DNS/SSL cutover script |
| SSH `hostinger_vps` | Max machines + agent | VPS shell |
| Supabase service role | Ops only (never Assist client) | Ops tables if any |
| Supabase anon key | Only if a future non-PHI ops UI needs it | Never band decode |

Store in 1Password / CI secrets. Do not commit tokens.

## RedMed MCP product wall

Tools in `mcp/redmed-mcp` may call Hostinger API, SSH, and Supabase **status**. They must refuse:

- Decoding or storing Assist `#d=` fragments
- Reading/writing Owner ICE / Keychain-shaped profiles
- Shipping medical data to Supabase or VPS disk

See `mcp/redmed-mcp/README.md` and `AGENTS.md` § Product wall.

## Stack status

```bash
# Prefer MCP tool redmed_stack_status when Cursor is connected to redmed-mcp
node mcp/redmed-mcp/bin/redmed-stack-status.mjs
```

## Side repos

| Repo | Role |
|------|------|
| `Roooted1776/RedMed-V1-Official` | Canonical product (this tree) |
| `Roooted1776/frisky` | Legacy name — archive or redirect to V1 after mirror |
| `Roooted1776/Roooted1776.github.io` | Assist Pages backup |
| `Roooted1776/redmed-privacy` | Standalone privacy HTML — **not** Connect Privacy URL |
