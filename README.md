# RedMed V1 Official

Medical ID band + iPhone app. **No RedMed profile server. No PHI database.**

| Surface | Path | Audience |
|---------|------|----------|
| **Assist** | [`tapper/`](tapper/) → `https://redmed.live/tapper/` | Person who taps the band |
| **Owner** | [`owner/`](owner/) | Wearer with the App Store app (`com.redmed.app`) |

Canonical git remote: **`Roooted1776/RedMed-V1-Official`** (migrated from `frisky`; history preserved when mirrored). Ship branch: `main`.

## Write base

**`https://redmed.live/tapper/`** — Hostinger static origin + Cloudflare DNS/SSL.  
Backup for already-written bands: `https://roooted1776.github.io/tapper/`.

Profile data lives only in the band URL `#d=` fragment (browser decodes on device). Owner profiles stay in Keychain on-device.

## Quick start (Assist)

```bash
# Local
python3 -m http.server 8787
# open http://127.0.0.1:8787/tapper/

# Pre-merge gates
bash scripts/sync-tapper.sh
node scripts/test-d-codec.mjs
node scripts/test-nfc-hardware.mjs
node scripts/test-sw-offline.mjs
node scripts/test-worker-device.mjs

# Stage + deploy to Hostinger
bash scripts/stage-worker-assets.sh
HOSTINGER_API_TOKEN=… node scripts/deploy-hostinger-static.mjs redmed.live

# Smoke (after DNS cutover)
BASE=https://redmed.live bash scripts/smoke-pages.sh
# Origin without public DNS:
BASE=http://195.35.60.70 HOST_HEADER=redmed.live bash scripts/smoke-pages.sh
```

DNS cutover: [`docs/domain.md`](docs/domain.md). Production matrix: [`docs/PRODUCTION.md`](docs/PRODUCTION.md). Agent rules: [`AGENTS.md`](AGENTS.md).

## Parked (Owner) until paid Apple Developer

| Flag | Default | Restore |
|------|---------|---------|
| `nfcHardwareEnabled` | `false` | [`docs/NFC-RESTORE.md`](docs/NFC-RESTORE.md) |
| `associatedDomainsEnabled` | `false` | [`docs/associated-domains-restore.md`](docs/associated-domains-restore.md) |
| `healthKitImportEnabled` | `false` | [`docs/healthkit-restore.md`](docs/healthkit-restore.md) |
| App Store listing | parked | [`docs/APP-STORE.md`](docs/APP-STORE.md) |

Do not market “write from the app” until Tag Reading + Write The Band on blank NTAG216 is proven.

## Ops (not the band host)

- VPS / Traefik / Docker: **ops only** — never Assist `#d=` origin ([`docs/OPS.md`](docs/OPS.md)).
- RedMed MCP (`mcp/redmed-mcp`): Hostinger + SSH + Supabase **ops** tools. Product wall: no ICE / `#d=` / PHI through MCP, Supabase, or VPS.
- Supabase project `RedMed Secure Data` (`mohxobgyjkcmkqxijgeg`): ops/metadata only — **zero medical profiles**.
- Side repos: `Roooted1776.github.io` (Assist backup), `redmed-privacy` (do **not** use as Connect Privacy URL — use live `/Document/`).

## Leftover tooling

[`wrangler.jsonc`](wrangler.jsonc) + [`worker/`](worker/) are **non-product** leftovers. Do not recreate Cloudflare Worker `redmed-emergency` for bands. Product host is Hostinger static.
