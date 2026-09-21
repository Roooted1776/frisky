# RedMed domain — custom host TBD

The HTML tap app (passerby shell) ships on a **custom domain**. The name is
**TBD** — not locked to `getredmed.com` or any other pick.

Profile data stays in `#d=` only. No RedMed PHI backend.

**Do not write an unregistered / placeholder host onto NFC bands.**
`AppConfig.medicalCardCustomDomainTBD` stays `nil` until you choose a domain
and HTTPS + `/tapper/` smoke are green. Until then `medicalCardBaseURL` is the
live interim host:

`https://redmed-emergency.maxaguilaraasted.workers.dev/tapper/`

## Current

| Path | Status |
|------|--------|
| Custom HTML app URL | **TBD** — set `AppConfig.medicalCardCustomDomainTBD` when ready |
| Cloudflare Worker `redmed-emergency` | **Live interim** — NFC write base. Smoke: `BASE=https://redmed-emergency.maxaguilaraasted.workers.dev bash scripts/smoke-pages.sh`. Deploys via Workers Builds / `wrangler deploy` when `CLOUDFLARE_API_TOKEN` is set. |
| Public GitHub Pages `Roooted1776.github.io/tapper/` | **Backup** for already-written bands. Keep publishing (`scripts/publish-github-io.sh`) so old chips still open. Do not delete. |
| Legacy filename `redmed-emergency.html` | Redirect stub → `/tapper/` (same as `index.html` / `card.html`) |

Smoke on the live interim: RedMed · 911 · Aid, no login. `pages-deploy.yml` **fails** when the write base 404s.

## Publish github.io (backup host)

Repo `Roooted1776/Roooted1776.github.io` already exists. Re-publish:

1. GitHub → that repo → Actions → **Publish tapper** → Run workflow
   (checks out frisky and runs `scripts/publish-github-io.sh`).
2. Or locally: `./scripts/publish-github-io.sh /path/to/Roooted1776.github.io`, then commit and push `main`.
3. Smoke: `BASE=https://roooted1776.github.io bash scripts/smoke-pages.sh`

## When you pick the domain

1. Register the custom domain (Cloudflare Registrar recommended so DNS + Worker stay together).
2. Attach it as a custom domain on Worker `redmed-emergency` that serves `tapper/`.
3. Wait for HTTPS **Active**.
4. Smoke: `https://<your-domain>/tapper/` loads RedMed · 911 · Aid. Bare `/` must land on `/tapper/` and keep `#d=`.
5. Optional: 301 old workers.dev / github.io URLs to the custom host; keep serving old hosts so already-written bands still open.
6. Set `AppConfig.medicalCardCustomDomainTBD` to `https://<your-domain>/tapper/` and ship that build.
7. New NFC writes use the custom host. Old workers.dev / github.io bands keep working if those hosts stay up.

Path stays **`/tapper/`** so SW cache keys and legacy `/get/` → `/tapper/` redirects stay coherent.

## URL contract

| Role | URL |
|------|-----|
| Product HTML app | Custom domain, **TBD** |
| Current AppConfig write base | `https://redmed-emergency.maxaguilaraasted.workers.dev/tapper/` |
| Backup host (old bands) | `https://roooted1776.github.io/tapper/` |

`getredmed.com` / `redmed.band` are examples only — not locked. Skip premium names (`redmed.com`, etc.) unless you buy them.
