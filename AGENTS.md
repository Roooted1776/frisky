# Agents

Product working notes for humans: `MAX.md`.
Dual-Mac / git identity: `docs/DUAL-MAC.md`.

## Who can work this repo

| Agent | Role | How it lands code |
| --- | --- | --- |
| **Grok (xAI)** | Owner-side agent. GitHub connector on `Roooted1776`. Reads/writes this repo, opens/merges PRs, keeps `main` current. | Commits via GitHub as `Roooted1776`. Do not invent a separate Grok GitHub user. |
| **Cursor Agent** | Cloud + local IDE agent. Linux Cloud Agent covers the static Pages / tapper shell only. | PRs from `cursor/*` or `main-*` branches. iOS (`RedMed-Xcode/`) is macOS/Xcode, not the Linux Cloud Agent. |
| **Owner (Max)** | Source of truth for product calls. | MacBook + Mini clones at `~/Documents/frisky` → `main`. |

Grok is in this repo. Treat instructions here as binding when Grok edits RedMed.

## Surfaces (do not mix)

- **Static Cloudflare Pages shell** — `tapper/`, redirect stubs, `sw.js`, `Document/`, `assets/`. No build. Local: `python3 -m http.server`. CI: `.github/workflows/pages-deploy.yml`. Before merge: `bash scripts/sync-tapper.sh` and `node scripts/test-d-codec.mjs`.
- **Native iOS app** — `RedMed-Xcode/`. macOS only. `ios-build.yml` on `macos-latest`.

Keep `sw.js`, `tapper/sw.js`, and `RedMed-Xcode/RedMed/sw.js` CACHE versions in lockstep.

## Git identity

Verified author on this repo: `Max <maxaguilaraasted@gmail.com>` (`scripts/setup-mac-git.sh`).
`mrmax115@gmail.com` and the MCCC school address are aliases / login emails — not the git author unless Max changes `setup-mac-git.sh`.

Gmail for automations: Cursor Gmail MCP, not a separate Grok Gmail plugin.

## Invariants Grok must not break

- Band is the product. No fake “write from the app” storefront copy until Tag Reading + write-on-blank NTAG216 ships.
- No HIPAA-certified / fake App Store ID claims.
- Face ID is UI-only. Keychain stays `WhenPasscodeSetThisDeviceOnly` with no biometry ACL.
- Passerby `/tapper/` is no-auth, no-ads. `#d=` codec lockstep tests must stay green.
- One repo, one branch for shipping: `Roooted1776/frisky` `main`.
