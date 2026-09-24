# RedMed domain — `redmed.live`

Stack (do not mix roles):

| Layer | Who | Job |
|-------|-----|-----|
| **Registrar** | Namecheap | Own the domain only. Custom nameservers → Cloudflare. |
| **DNS + edge SSL** | Cloudflare | Authoritative DNS, orange-cloud proxy, visitor HTTPS. **Not** a Worker recreate. |
| **Origin** | Hostinger static | File host for `tapper/` only. **No Hostinger domain product.** **No RedMed server / DB.** |

Production write base:

**`https://redmed.live/tapper/`**

No RedMed server. No database. No HIPAA backend. Profile data stays in the
band URL `#d=` fragment only — the browser decodes it on the phone.

`AppConfig.medicalCardCustomDomainTBD` / `medicalCardBaseURL` is
`https://redmed.live/tapper/`.

## Current

| Path | Status |
|------|--------|
| Product HTML app | Hostinger site `u666300215`, files in `public_html` / plan IP **`195.35.60.70`**. Deploy: `bash scripts/stage-worker-assets.sh` then `node scripts/deploy-hostinger-static.mjs redmed.live` (`HOSTINGER_API_TOKEN`). |
| Hostinger domain product | **None** — domains portfolio is empty. Website hostname `redmed.live` lives on the hosting plan only. |
| Public DNS | Namecheap parking until Cloudflare NS cutover (`dns1`/`dns2.registrar-servers.com`). |
| Cloudflare DNS + SSL | **Cutover ready** — `node scripts/setup-cloudflare-dns.mjs` (needs `CLOUDFLARE_API_TOKEN`), then Namecheap Custom DNS → Cloudflare NS. Verify: `bash scripts/verify-cf-dns-cutover.sh`. |
| Cloudflare Worker `redmed-emergency` | **Not used** for the product shell. Do not recreate for bands. |
| Public GitHub Pages `Roooted1776.github.io/tapper/` | **Backup** for already-written bands. Keep publishing (`scripts/publish-github-io.sh`). |

Smoke after DNS: `BASE=https://redmed.live bash scripts/smoke-pages.sh`.
Origin check (DNS independent): `BASE=http://195.35.60.70 HOST_HEADER=redmed.live bash scripts/smoke-pages.sh`.
CI (`Pages tapper deploy`) also hard-smokes the github.io backup and soft-warns while
Namecheap still parks public DNS.

## Publish github.io (backup host)

Repo `Roooted1776/Roooted1776.github.io` already exists. Re-publish:

1. GitHub → that repo → Actions → **Publish tapper** → Run workflow
   (checks out frisky and runs `scripts/publish-github-io.sh`).
2. Or locally: `./scripts/publish-github-io.sh /path/to/Roooted1776.github.io`, then commit and push `main`.
3. Smoke: `BASE=https://roooted1776.github.io bash scripts/smoke-pages.sh`

## DNS / SSL cutover (`redmed.live`)

### Goal

```
Visitor HTTPS → Cloudflare (edge cert + Always Use HTTPS)
             → Hostinger origin 195.35.60.70 (static files only)
Namecheap keeps the registration invoice; DNS answers come from Cloudflare.
```

### 1. Cloudflare API (agent / Max)

Create an API token: [dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens)

- Template **Edit zone DNS**, plus permission **Zone → Zone Settings → Edit** (SSL).
- Account: the one with `account_id` in `wrangler.jsonc` (`a2d8a74738a0280eb9d5a3e77acd59ea`).

```bash
export CLOUDFLARE_API_TOKEN=…   # also add as Cloud Agent / CI secret when ready
node scripts/setup-cloudflare-dns.mjs redmed.live
```

That script:

1. Creates/finds zone `redmed.live` (full setup).
2. Upserts proxied **A** `@` and `www` → `195.35.60.70` (orange cloud).
3. Sets SSL/TLS encryption mode → **Flexible** (Hostinger origin serves HTTP without forcing HTTPS today — avoids redirect loops).
4. Turns **Always Use HTTPS** on at the edge.
5. Prints the two Cloudflare nameservers.

Dashboard equivalent (if you skip the token): Onboard `redmed.live` → Free plan → same A records proxied → SSL/TLS Overview → Flexible → Edge Certificates → Always Use HTTPS = On.

### 2. Namecheap (Max — registrar only)

1. Domain List → **Manage** → `redmed.live`.
2. If DNSSEC is on, turn it **off** before changing NS.
3. Nameservers → **Custom DNS** → paste the two Cloudflare nameservers from step 1.
4. Save. Leave Advanced DNS empty/unused — Cloudflare is authoritative after NS switch.
5. Do **not** point Namecheap A records at Hostinger if NS already moved to Cloudflare (those records would be ignored).

### 3. Verify

```bash
bash scripts/verify-cf-dns-cutover.sh
# or piecewise:
dig +short NS redmed.live          # *.ns.cloudflare.com
dig +short redmed.live A           # Cloudflare anycast (or 195.35.60.70 if gray)
BASE=https://redmed.live bash scripts/smoke-pages.sh
```

### 4. Optional later: Full (strict)

After Hostinger has a valid cert for `redmed.live` (or install a Cloudflare Origin CA cert on the plan), change Cloudflare SSL mode from **Flexible** → **Full (strict)**. Day-1 Flexible is intentional so public HTTPS works while origin is HTTP-only.

**Do not** recreate Worker `redmed-emergency` just for SSL — Cloudflare DNS/SSL in front of Hostinger static is enough.

**Do not** buy/transfer the domain onto Hostinger — hosting already serves the hostname; domains portfolio stays empty.

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
