# RedMed domain — `redmed.live` (Hostinger static)

The HTML tap app (passerby shell) ships as **static files on Hostinger**.
Production write base:

**`https://redmed.live/tapper/`**

No RedMed server. No database. No HIPAA backend. Profile data stays in the
band URL `#d=` fragment only — the browser decodes it on the phone.

`AppConfig.medicalCardCustomDomainTBD` / `medicalCardBaseURL` is
`https://redmed.live/tapper/`.

## Current

| Path | Status |
|------|--------|
| Product HTML app | **`https://redmed.live/tapper/`** — Hostinger site `u666300215`, files in `public_html`. Deploy: `bash scripts/stage-worker-assets.sh` then `node scripts/deploy-hostinger-static.mjs redmed.live` (needs `HOSTINGER_API_TOKEN`, `axios`, `tus-js-client`). |
| Public GitHub Pages `Roooted1776.github.io/tapper/` | **Backup** for already-written bands. Keep publishing (`scripts/publish-github-io.sh`). Do not delete. |
| Legacy filename `redmed-emergency.html` | Redirect stub → `/tapper/` (same as `index.html` / `card.html`) |
| Cloudflare DNS + SSL | **Planned soon** — nameservers + orange-cloud HTTPS in front of Hostinger origin. Not a Worker recreate. |
| Cloudflare Worker `redmed-emergency` | **Not used** for the product shell. Do not recreate for bands. |

Smoke after DNS: `BASE=https://redmed.live bash scripts/smoke-pages.sh`.
Origin check (DNS independent): `BASE=http://195.35.60.70 HOST_HEADER=redmed.live bash scripts/smoke-pages.sh`.

## Publish github.io (backup host)

Repo `Roooted1776/Roooted1776.github.io` already exists. Re-publish:

1. GitHub → that repo → Actions → **Publish tapper** → Run workflow
   (checks out frisky and runs `scripts/publish-github-io.sh`).
2. Or locally: `./scripts/publish-github-io.sh /path/to/Roooted1776.github.io`, then commit and push `main`.
3. Smoke: `BASE=https://roooted1776.github.io bash scripts/smoke-pages.sh`

## DNS / SSL cutover (`redmed.live`)

Domain is registered at **Namecheap** (nameservers still `dns1.registrar-servers.com`
parking). Hostinger already serves the static shell at plan IP **`195.35.60.70`**.

**Planned (in a day or two): Cloudflare DNS + SSL** — move nameservers to Cloudflare,
point `@` / `www` at Hostinger origin `195.35.60.70`, enable Cloudflare proxy (orange
cloud) for HTTPS. Keep Hostinger as the static file origin only — no RedMed server,
no database, no Worker required for bands.

Until that lands, `https://redmed.live` stays on Namecheap parking. Origin smoke
(independent of public DNS):

```bash
BASE=http://195.35.60.70 HOST_HEADER=redmed.live bash scripts/smoke-pages.sh
```

After Cloudflare DNS/SSL is live:

```bash
dig +short redmed.live A    # Cloudflare proxy IPs (or 195.35.60.70 if DNS-only)
BASE=https://redmed.live bash scripts/smoke-pages.sh
```

**Do not** recreate Worker `redmed-emergency` just for SSL — Cloudflare DNS/SSL in
front of Hostinger static is enough.

Optional interim (skip if waiting on Cloudflare): at Namecheap Advanced DNS, point
`A @` / `www` → `195.35.60.70` so Hostinger can issue its own cert before the CF move.


## Product rules

1. Smoke: `https://redmed.live/tapper/` loads RedMed · 911 · Aid. Bare `/` lands on `/tapper/` and keeps `#d=`.
2. New NFC writes use `redmed.live` (`AppConfig.medicalCardBaseURL`).
3. Keep github.io backup for old bands.
4. Path stays **`/tapper/`** so SW cache keys and legacy `/get/` → `/tapper/` redirects stay coherent.

## URL contract

| Role | URL |
|------|-----|
| Product HTML app (write base) | `https://redmed.live/tapper/` |
| Hostinger origin IP | `195.35.60.70` (Host: `redmed.live`) |
| Backup host (old bands) | `https://roooted1776.github.io/tapper/` |

Deploy deps (one-off): `npm install --no-save axios tus-js-client` before running `scripts/deploy-hostinger-static.mjs`.
