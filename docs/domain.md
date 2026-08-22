# RedMed domain — getredmed.com

Locked pick for the hosted passerby shell (replacing interim hosts as the
**write** base). Profile data stays in `#d=` only — no RedMed PHI backend.

**Current (2026-08-21):** AppConfig writes
`https://roooted1776.github.io/tapper/` (public GitHub Pages user site —
shell only, no PHI). Smoke green: RedMed · 911 · Aid.

`https://redmed.pages.dev/tapper/` is still **404** until
`CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` land (or Pages project
`redmed` connects to this repo). `getredmed.com` does not resolve. Do not
flip AppConfig to `getredmed.com` first.

## Buy (you must do this — agents cannot pay)

1. Cloudflare Dashboard → **Domain Registration** → register **`getredmed.com`**
   (at-cost .com; DNS stays in the same account as Pages).
2. Optional same cart: **`redmed.band`** (short NFC base). Not required for v1.
3. Skip **`redmed.com`** until Afternic quotes a BIN (premium, quote-only).

Do not merge or ship NFC writes to the custom host until steps below show green.
`AppConfig.medicalCardBaseURL` must stay on a live host
(`https://roooted1776.github.io/tapper/` today) until step 3 (HTTPS Active +
`/tapper/` smoke) is green — a premature flip writes dead URLs onto bands
while DNS is still NXDOMAIN.

## Attach to Pages (cutover)

1. Cloudflare Pages project **`redmed`** → **Custom domains** → add
   `getredmed.com` and `www.getredmed.com`.
2. Finish DNS (Cloudflare Registrar usually auto-configures). Wait for HTTPS
   **Active**.
3. Smoke: `https://getredmed.com/tapper/` loads RedMed · 911 · Aid (same shell as
   today). Bare `https://getredmed.com/` must land on `/tapper/` and keep `#d=`.
4. Optional: Cloudflare **Redirect Rules** — `redmed.pages.dev/*` and
   `roooted1776.github.io/*` → `https://getredmed.com/$1` (301). Keep serving
   prior hosts either way so bands already written still open.
5. Ship the app build that sets
   `AppConfig.medicalCardBaseURL = "https://getredmed.com/tapper/"`.
   Until then, leave it on the live interim host.
6. New NFC writes use the custom host. Old `github.io` / `pages.dev` bands keep
   working if those hosts stay up.

## Publish paths (interim)

| Path | Status |
|------|--------|
| Public GitHub Pages `Roooted1776/Roooted1776.github.io` | **Live** — AppConfig write base |
| Cloudflare Pages project `redmed` (`redmed.pages.dev`) | Blocked — missing CF secrets / Git connect |
| Custom host `getredmed.com` | Not registered (NXDOMAIN) |

Public shell publish (no PHI): `./scripts/publish-github-io.sh` copies HTML/SW/assets
into the user Pages repo; Actions assembles chunked uploads when needed.

## URL contract

| Role | URL |
|------|-----|
| Current AppConfig write base | `https://roooted1776.github.io/tapper/` |
| Cloudflare Pages (when secrets land) | `https://redmed.pages.dev/tapper/` |
| Locked custom host (after cutover) | `https://getredmed.com/tapper/` |
| Optional short alias (if bought) | `https://redmed.band/` → same Pages project |

Path stays **`/tapper/`** so SW cache keys and legacy `/get/` → `/tapper/` redirects
stay coherent.

## Rejected / taken (do not chase)

`redmed.com` (Afternic), `redmed.app`, `redmed.io`, `redmed.health`, `redmed.org`,
`redmed.co`, `red-med.com`.
