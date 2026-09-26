# RedMed V1 go-live audit

**Checked:** 2026-09-26 against sprint branch `cursor/redmed-v1-golive-c874`  
**Canonical repo:** `Roooted1776/RedMed-V1-Official` (mirror from `frisky`)

## Scorecard

| Surface | Deployable? | Notes |
|---------|-------------|-------|
| Assist code (`tapper/`, SW, `#d=` tests) | **Yes** | CI gates: d-codec, nfc-hardware (51), sw-offline, worker-device |
| Public `https://redmed.live/tapper/` | **No (parking)** | Hostinger parked HTML; NS = dns-parking |
| Origin `195.35.60.70` + Host `redmed.live` | **Parking HTML** | Must attach/deploy real static files |
| Backup `roooted1776.github.io/tapper/` | **Yes** | Live Assist while custom domain parks |
| Owner iOS | Compile yes / NFC no | Flags parked; restore docs ready |
| Ops MCP (`mcp/redmed-mcp`) | **Landed** | Product wall: no ICE/`#d=`/PHI |
| Supabase `mohxobgyjkcmkqxijgeg` | Empty | Ops only — keep free of medical data |
| VPS `2010795` | Ops only | Not Assist origin |

## Invariants (must stay green)

- Assist no-auth, no-ads; path `/tapper/`
- No profile backend / no PHI on servers
- SOS = full sound + light; never arm on band tap alone
- No `redmed://band#d=` handoff
- NTAG216 unlocked only; 51 NFC static checks
- SW CACHE lockstep across `sw.js`, `tapper/sw.js`, `owner/RedMed/sw.js`
- Face ID UI-only; Keychain `WhenPasscodeSetThisDeviceOnly` without biometry ACL

## Go-live remaining (Max + agent)

1. Hostinger: un-park website / deploy staged `dist/passerby` (`HOSTINGER_API_TOKEN`)
2. Cloudflare DNS script + Namecheap Custom NS
3. Smoke: `BASE=https://redmed.live bash scripts/smoke-pages.sh`
4. AASA JSON (not parking) at `/apple-app-site-association` + `.well-known/`
5. Mirror-push history to `RedMed-V1-Official` if Cloud Agent token lacks git push (use `scripts/mirror-to-v1.sh` on a Mac)
6. CI secrets on V1 remote: `HOSTINGER_API_TOKEN`, `CLOUDFLARE_API_TOKEN`
7. Paid Apple Program → NFC + Associated Domains restore → App Store (`docs/APP-STORE.md`)

## Side repos

| Repo | Role |
|------|------|
| `RedMed-V1-Official` | Canonical product |
| `frisky` | Legacy name — point README at V1 after mirror |
| `Roooted1776.github.io` | Assist backup |
| `redmed-privacy` | Not Connect Privacy URL |
