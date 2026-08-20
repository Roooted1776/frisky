# RedMed domain — getredmed.com

Locked pick for the hosted passerby shell (replacing `redmed.pages.dev` as the
**write** base). Profile data stays in `#d=` only — no RedMed PHI backend.

**Current (2026-08-20):** AppConfig still writes `https://redmed.pages.dev/tapper/`.
That path is 404 until Pages publishes (GitHub secrets `CLOUDFLARE_API_TOKEN` +
`CLOUDFLARE_ACCOUNT_ID`, or connect Pages project `redmed` to this repo).
`getredmed.com` does not resolve. Do not flip AppConfig first.

## Buy (you must do this — agents cannot pay)

1. Cloudflare Dashboard → **Domain Registration** → register **`getredmed.com`**
   (at-cost .com; DNS stays in the same account as Pages).
2. Optional same cart: **`redmed.band`** (short NFC base). Not required for v1.
3. Skip **`redmed.com`** until Afternic quotes a BIN (premium, quote-only).

Do not merge or ship NFC writes to the custom host until steps below show green.
`AppConfig.medicalCardBaseURL` must stay on `https://redmed.pages.dev/tapper/`
until step 3 (HTTPS Active + `/tapper/` smoke) is green — a premature flip
writes dead URLs onto bands while DNS is still NXDOMAIN.

## Attach to Pages (cutover)

1. Cloudflare Pages project **`redmed`** → **Custom domains** → add
   `getredmed.com` and `www.getredmed.com`.
2. Finish DNS (Cloudflare Registrar usually auto-configures). Wait for HTTPS
   **Active**.
3. Smoke: `https://getredmed.com/tapper/` loads RedMed · 911 · Aid (same shell as
   today). Bare `https://getredmed.com/` must land on `/tapper/` and keep `#d=`.
4. Optional: Cloudflare **Redirect Rules** — `redmed.pages.dev/*` →
   `https://getredmed.com/$1` (301). Keep Pages serving both hosts either way so
   bands already written with `pages.dev` still open.
5. Ship the app build that sets
   `AppConfig.medicalCardBaseURL = "https://getredmed.com/tapper/"`.
   Until then, leave it on `https://redmed.pages.dev/tapper/`.
6. New NFC writes use the custom host. Old `pages.dev` bands keep working.

## URL contract

| Role | URL |
|------|-----|
| Current AppConfig write base | `https://redmed.pages.dev/tapper/` |
| Locked custom host (after cutover) | `https://getredmed.com/tapper/` |
| Keep serving after cutover | `https://redmed.pages.dev/tapper/` (old bands) |
| Optional short alias (if bought) | `https://redmed.band/` → same Pages project |

Path stays **`/tapper/`** so SW cache keys and legacy `/get/` → `/tapper/` redirects
stay coherent.

## Rejected / taken (do not chase)

`redmed.com` (Afternic), `redmed.app`, `redmed.io`, `redmed.health`, `redmed.org`,
`redmed.co`, `red-med.com`.
