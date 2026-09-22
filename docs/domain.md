# RedMed domain — `redmed.live` (Hostinger)

The HTML tap app (passerby shell) ships on a **custom domain**. Production host:
**`https://redmed.live/tapper/`** (Hostinger static deploy). NFC bands should use
that base once DNS is pointed (see **DNS cutover** below).

Profile data stays in `#d=` only. No RedMed PHI backend.

**Do not write an unregistered / placeholder host onto NFC bands.**
`AppConfig.medicalCardCustomDomainTBD` stays `nil` until you choose a domain
and HTTPS + `/tapper/` smoke are green. Until then `medicalCardBaseURL` is the
live interim host:

`https://redmed-emergency.maxaguilaraasted.workers.dev/tapper/`

## Current

| Path | Status |
|------|--------|
| Custom HTML app URL | **`redmed.live`** — Hostinger site `u666300215`. Deploy: `bash scripts/stage-worker-assets.sh` then `node scripts/deploy-hostinger-static.mjs redmed.live` (needs `HOSTINGER_API_TOKEN`, `axios`, `tus-js-client`). Smoke: `BASE=https://redmed.live bash scripts/smoke-pages.sh` after DNS. |
| Cloudflare Worker `redmed-emergency` | **Live interim / backup** — keep until `redmed.live` DNS is green everywhere. Smoke: `BASE=https://redmed-emergency.maxaguilaraasted.workers.dev bash scripts/smoke-pages.sh`. |
| Public GitHub Pages `Roooted1776.github.io/tapper/` | **Backup** for already-written bands. Keep publishing (`scripts/publish-github-io.sh`) so old chips still open. Do not delete. |
| Legacy filename `redmed-emergency.html` | Redirect stub → `/tapper/` (same as `index.html` / `card.html`) |

Smoke on the live interim: RedMed · 911 · Aid, no login. `pages-deploy.yml` **fails** when the write base 404s.

## Publish github.io (backup host)

Repo `Roooted1776/Roooted1776.github.io` already exists. Re-publish:

1. GitHub → that repo → Actions → **Publish tapper** → Run workflow
   (checks out frisky and runs `scripts/publish-github-io.sh`).
2. Or locally: `./scripts/publish-github-io.sh /path/to/Roooted1776.github.io`, then commit and push `main`.
3. Smoke: `BASE=https://roooted1776.github.io bash scripts/smoke-pages.sh`

## DNS cutover (`redmed.live`)

Domain is registered at **Namecheap** (nameservers `dns1.registrar-servers.com`). Hostinger
hosts the static passerby shell; DNS must point at the Hostinger plan IP (shown in hPanel →
Websites → redmed.live → Plan details — verified working: **`195.35.60.70`**).

At Namecheap → Domain List → redmed.live → Advanced DNS:

1. Remove parking records (`A @` → `162.255.119.128`, `CNAME www` → `parkingpage.namecheap.com`).
2. Add **`A @` → `195.35.60.70`** (TTL Automatic).
3. Add **`A www` → `195.35.60.70`** (or `CNAME www` → `redmed.live`).
4. Wait for propagation (minutes–24h). Hostinger issues HTTPS once DNS resolves.

Verify: `BASE=https://redmed.live bash scripts/smoke-pages.sh` and open
`https://redmed.live/tapper/` on a phone (external browser — no app required).

Alternative: point Namecheap nameservers to Hostinger values from Plan details
(often `ns1.dns-parking.com` / `ns2.dns-parking.com`) and manage DNS in hPanel.

## When custom domain is fully green

1. Smoke: `https://redmed.live/tapper/` loads RedMed · 911 · Aid. Bare `/` lands on `/tapper/` and keeps `#d=`.
2. Set `AppConfig.medicalCardCustomDomainTBD` to `https://redmed.live/tapper/` and ship that iOS build.
3. New NFC writes use `redmed.live`. Keep Worker + github.io backup hosts for old bands.
4. Optional: 301 workers.dev / github.io to `redmed.live`; keep old hosts serving until bands are rewritten.

Path stays **`/tapper/`** so SW cache keys and legacy `/get/` → `/tapper/` redirects stay coherent.

## URL contract

| Role | URL |
|------|-----|
| Product HTML app | `https://redmed.live/tapper/` (after DNS) |
| Current AppConfig write base | `https://redmed-emergency.maxaguilaraasted.workers.dev/tapper/` until AppConfig cutover |
| Backup host (old bands) | `https://roooted1776.github.io/tapper/` |

Deploy deps (one-off): `npm install --no-save axios tus-js-client` before running `scripts/deploy-hostinger-static.mjs`.
