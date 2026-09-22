# Agents

Product working notes for humans: `MAX.md`.
Dual-Mac / git identity: `docs/DUAL-MAC.md`.

## Who can work this repo

| Agent | Role | How it lands code |
| --- | --- | --- |
| **Grok (xAI)** | Owner-side agent. GitHub connector on `Roooted1776`. Reads/writes this repo, opens/merges PRs, keeps `main` current. | Commits via GitHub as `Roooted1776`. Do not invent a separate Grok GitHub user. |
| **Cursor Agent** | Cloud + local IDE agent. Linux Cloud Agent covers the static Worker / **tapper** shell only. MacBook Air / Mini **My Machines** workers (`macbook-air`, `mac-mini`) run tool calls on that Mac for iOS / Xcode — see `docs/DUAL-MAC.md` §0. | PRs from `cursor/*` or `main-*` branches. **Owner** app (`owner/`) is macOS/Xcode, not the Linux Cloud Agent. |
| **Owner (Max)** | Source of truth for product calls. | MacBook Air + Mini clones at `~/Documents/frisky` → `main`. |

Grok is in this repo. Treat instructions here as binding when Grok edits RedMed.

## Surfaces (do not mix)

Two folders, two audiences — never cross owner-only features into tapper.

| Surface | Folder | Audience | Scope |
| --- | --- | --- | --- |
| **Tapper** | `tapper/` | Passerby / responder | Tap pages, band `#d=` decode, RedMed · 911 · Aid web shell only. No NFC tab, Edit, Face ID, Keychain, or App Store flows. No-auth, no-ads. |
| **Owner** | `owner/` | App Store wearer | Native iOS / SwiftUI (`com.redmed.app`). Profile, Edit, NFC Write/Scan, Face ID chrome, Keychain, HealthKit import. **Not** HIPAA-certified — local-only ICE card. |

- **Tapper (static Hostinger shell)** — Product write base `https://redmed.live/tapper/` (`docs/domain.md`). Stage with `scripts/stage-worker-assets.sh` → `dist/passerby`; deploy with `node scripts/deploy-hostinger-static.mjs redmed.live` (`HOSTINGER_API_TOKEN`). Serves `tapper/`, redirect stubs (`index.html`, `redmed-emergency.html`, …), `sw.js`, `Document/`, `assets/`. No app build. No RedMed server / DB. Local: `python3 -m http.server`. CI: `.github/workflows/pages-deploy.yml`. Before merge: `bash scripts/sync-tapper.sh`, `node scripts/test-d-codec.mjs`, and `node scripts/test-worker-device.mjs`.
- **Owner (native iOS app)** — `owner/RedMed.xcodeproj`. macOS only. `ios-build.yml` on `macos-latest`. Xcode copies `tapper/index.html` into the bundle as `tapper.html` for NFC Preview only — that copy is read-only embed, not a second shell fork.

Keep `sw.js`, `tapper/sw.js`, and `owner/RedMed/sw.js` CACHE versions in lockstep.

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
