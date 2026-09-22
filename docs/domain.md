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
| Cloudflare Worker `redmed-emergency` | **Not used.** Product host is Hostinger. Do not recreate for bands. |

Smoke after DNS: `BASE=https://redmed.live bash scripts/smoke-pages.sh`.
Origin check (DNS independent): `BASE=http://195.35.60.70 HOST_HEADER=redmed.live bash scripts/smoke-pages.sh`.

## Publish github.io (backup host)

Repo `Roooted1776/Roooted1776.github.io` already exists. Re-publish:

1. GitHub → that repo → Actions → **Publish tapper** → Run workflow
   (checks out frisky and runs `scripts/publish-github-io.sh`).
2. Or locally: `./scripts/publish-github-io.sh /path/to/Roooted1776.github.io`, then commit and push `main`.
3. Smoke: `BASE=https://roooted1776.github.io bash scripts/smoke-pages.sh`

## DNS cutover (`redmed.live`) — required for phones

Domain is registered at **Namecheap** (nameservers `dns1.registrar-servers.com`).
Hostinger already serves the shell at plan IP **`195.35.60.70`**. Until DNS
points there, `https://redmed.live` stays on Namecheap parking and times out.

At Namecheap → Domain List → **redmed.live** → **Advanced DNS**:

1. Remove parking records (`A @` → `162.255.119.128`, `CNAME www` → `parkingpage.namecheap.com`).
2. Add **`A @` → `195.35.60.70`** (TTL Automatic).
3. Add **`A www` → `195.35.60.70`** (or `CNAME www` → `redmed.live`).
4. Wait for propagation (minutes–24h). Hostinger issues HTTPS once DNS resolves.

Verify:

```bash
dig +short redmed.live A    # must print 195.35.60.70
BASE=https://redmed.live bash scripts/smoke-pages.sh
```

Open `https://redmed.live/tapper/` on a phone (external browser — no app).

Alternative: point Namecheap nameservers to Hostinger values from Plan details
and manage DNS in hPanel.

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
