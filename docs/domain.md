# RedMed domain — custom host TBD

The HTML tap app (passerby shell) ships on a **custom domain**. The name is
**TBD** — not locked to `getredmed.com` or any other pick.

Profile data stays in `#d=` only. No RedMed PHI backend.

**Do not write an unregistered / placeholder host onto NFC bands.**
`AppConfig.medicalCardCustomDomainTBD` stays `nil` until you choose a domain
and HTTPS + `/tapper/` smoke are green. Until then `medicalCardBaseURL` is the
live interim host:

`https://roooted1776.github.io/tapper/`

## Current (2026-08-31)

| Path | Status |
|------|--------|
| Custom HTML app URL | **TBD** — set `AppConfig.medicalCardCustomDomainTBD` when ready |
| Public GitHub Pages `Roooted1776.github.io/tapper/` | **Live interim** — NFC write base. Repo `Roooted1776/Roooted1776.github.io` (Actions → Publish tapper copies from frisky). Do not flip `medicalCardBaseURL` onto another host until that host's `/tapper/` smoke is green. |
| Cloudflare Pages `redmed.pages.dev` | Optional; 404 until CF secrets / Git connect |

Smoke on the live interim: RedMed · 911 · Aid, no login. `pages-deploy.yml` **fails** when the write base 404s.

## Publish github.io

Repo `Roooted1776/Roooted1776.github.io` already exists. Re-publish:

1. GitHub → that repo → Actions → **Publish tapper** → Run workflow
   (checks out frisky and runs `scripts/publish-github-io.sh`).
2. Or locally: `./scripts/publish-github-io.sh /path/to/Roooted1776.github.io`, then commit and push `main`.
3. Smoke: `BASE=https://roooted1776.github.io bash scripts/smoke-pages.sh`

Do not change `AppConfig.medicalCardBaseURL` until that smoke is green.

## When you pick the domain

1. Register the custom domain (Cloudflare Registrar recommended so DNS + Pages stay together).
2. Attach it to the Pages project that serves `tapper/`.
3. Wait for HTTPS **Active**.
4. Smoke: `https://<your-domain>/tapper/` loads RedMed · 911 · Aid. Bare `/` must land on `/tapper/` and keep `#d=`.
5. Optional: 301 old github.io / pages.dev URLs to the custom host; keep serving old hosts so already-written bands still open.
6. Set `AppConfig.medicalCardCustomDomainTBD` to `https://<your-domain>/tapper/` and ship that build.
7. New NFC writes use the custom host. Old github.io bands keep working if that host stays up.

Path stays **`/tapper/`** so SW cache keys and legacy `/get/` → `/tapper/` redirects stay coherent.

## URL contract

| Role | URL |
|------|-----|
| Product HTML app | Custom domain, **TBD** |
| Current AppConfig write base | `https://roooted1776.github.io/tapper/` |
| Cloudflare Pages (optional) | `https://redmed.pages.dev/tapper/` |

`getredmed.com` / `redmed.band` are examples only — not locked. Skip premium names (`redmed.com`, etc.) unless you buy them.
