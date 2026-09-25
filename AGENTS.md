# Agents

Product working notes for humans: `MAX.md`.
Dual-Mac / git identity: `docs/DUAL-MAC.md`.

## Who can work this repo

| Agent | Role | How it lands code |
| --- | --- | --- |
| **Grok (xAI)** | Owner-side agent. GitHub connector on `Roooted1776`. Reads/writes this repo, opens/merges PRs, keeps `main` current. | Commits via GitHub as `Roooted1776`. Do not invent a separate Grok GitHub user. |
| **Cursor Agent** | Cloud + local IDE agent. Linux Cloud Agent covers the static Worker / **Assist** shell (`tapper/` path) only. MacBook Air / Mini **My Machines** workers (`macbook-air`, `mac-mini`) run tool calls on that Mac for iOS / Xcode — see `docs/DUAL-MAC.md` §0. | PRs from `cursor/*` or `main-*` branches. **Owner** app (`owner/`) is macOS/Xcode, not the Linux Cloud Agent. |
| **Owner (Max)** | Source of truth for product calls. | MacBook Air + Mini clones at `~/Documents/frisky` → `main`. |

Grok is in this repo. Treat instructions here as binding when Grok edits RedMed.

## Surfaces (do not mix)

Two folders, two audiences — never cross owner-only features into Assist.

| Surface | Folder / URL | Audience | Scope |
| --- | --- | --- | --- |
| **Assist** | `tapper/` → `https://redmed.live/tapper/` | The person **tapping** the band (passerby / responder) | Tap pages, band `#d=` decode, RedMed · 911 · Aid web shell only. No NFC tab, Edit, Face ID, Keychain, or App Store flows. No-auth, no-ads. Folder + URL path stay `tapper/` so already-written bands keep working. |
| **Owner** | `owner/` | The person with the **app on their phone** (App Store wearer) | Native iOS / SwiftUI (`com.redmed.app`). Profile, Edit, NFC Write/Scan, Face ID chrome, Keychain, HealthKit import. **Not** HIPAA-certified — local-only ICE card. |

- **Assist (static Hostinger shell)** — Product write base `https://redmed.live/tapper/` (`docs/domain.md`). Stage with `scripts/stage-worker-assets.sh` → `dist/passerby`; deploy with `node scripts/deploy-hostinger-static.mjs redmed.live` (`HOSTINGER_API_TOKEN`). Serves `tapper/`, redirect stubs (`index.html`, `redmed-emergency.html`, …), `sw.js`, `Document/`, `assets/`. No app build. No RedMed server / DB. Local: `python3 -m http.server`. CI: `.github/workflows/pages-deploy.yml`. Before merge: `bash scripts/sync-tapper.sh`, `node scripts/test-d-codec.mjs`, and `node scripts/test-worker-device.mjs`.
- **Owner (native iOS app)** — `owner/RedMed.xcodeproj`. macOS only. `ios-build.yml` on `macos-latest`. Xcode copies `tapper/index.html` into the bundle as `tapper.html` for NFC Preview only — that copy is read-only embed, not a second shell fork.
- **Own-band / Assist SOS** — SOS exists so helpers can find someone on a **dark rainy night after a motorist ejects from a vehicle**: **full sound + full light**. It arms only when the helper toggles **SOS · Locate Me**, or when collision is detected using **US Crash Detection** timing (Apple Support 104959: 10s alert + 30s countdown → `tel:` unless Stop) — not Apple's Crash Detection API. Band tap never auto-arms SOS. After the owner writes their custom band and has RedMed installed, Associated Domains (Universal Links) claims the tap — never a `redmed://` handoff carrying `#d=` (custom schemes are not exclusive; any app registering `redmed` would get the profile). NFC write ships only with Associated Domains (enforced by `test-nfc-hardware.mjs`). No distance / BLE ranging.

Keep `sw.js`, `tapper/sw.js`, and `owner/RedMed/sw.js` CACHE versions in lockstep.

## Git identity

Verified author on this repo: `Max <maxaguilaraasted@gmail.com>` (`scripts/setup-mac-git.sh`).
`mrmax115@gmail.com` and the MCCC school address are aliases / login emails — not the git author unless Max changes `setup-mac-git.sh`.

Gmail for automations: Cursor Gmail MCP, not a separate Grok Gmail plugin.

## Invariants Grok must not break

- Band is the product. No fake “write from the app” storefront copy until Tag Reading + write-on-blank NTAG216 ships.
- No HIPAA-certified / fake App Store ID claims.
- Face ID is UI-only. Keychain stays `WhenPasscodeSetThisDeviceOnly` with no biometry ACL.
- Assist at `https://redmed.live/tapper/` is no-auth, no-ads. `#d=` codec lockstep tests must stay green.
- SOS = full sound + full light; arms only on SOS toggle or US Crash Detection collision timing — never on band tap alone. Owner phone with RedMed + written band: applinks (Universal Links) claim the tap — no `redmed://band#d=` handoff. No fake band-distance ranging.
- Band is factory blank NDEF-unlocked NXP NTAG216 — no permanent lock bytes, ever. `scripts/test-nfc-hardware.mjs` (51 checks) must stay green.
- One repo, one branch for shipping: `Roooted1776/frisky` `main`.

## NFC hardware contract

`scripts/test-nfc-hardware.mjs` statically enforces the bracelet hardware
contract on Linux CI (no Xcode needed) — 51 checks, must all pass before
merge (`pages-deploy.yml` and `ios-build.yml` both run it). Rule detail for
IDE agents: `.cursor/rules/nfc-hardware.mdc`.

- **Chip**: product band is **NXP NTAG216** only (13.56 MHz, ISO 14443A
  Type 2, NDEF blank unlocked). Never NTAG213/215, MIFARE, LF, or UHF.
- **Tap geometry**: deliberate antenna tap ~1–2″ (`AppConfig.BraceletRF`);
  walk-by (~6–8″) must never fire a session. RedMed only starts CoreNFC on
  an explicit Write/Scan action, never on mere proximity.
- **Write gate**: `NFCBandManager.writeBand` refuses scanner sessions, a
  busy session, and an empty profile before touching CoreNFC; enforces the
  850-byte NTAG216 cap; `NFCWriter.writeURL` refuses anything that is not a
  `medicalCardBaseURL#d=` URL. Parked builds (`AppConfig.nfcHardwareEnabled
  == false`) only pack a URL — never open a live session, never mark Linked.
- **NDEF contract**: hand-built Well Known Type "U" record (keeps `#d=`
  intact for iOS Background Tag Reading); single-record message checked
  against tag capacity before writing; `queryNDEFStatus` handled
  exhaustively (`.notSupported` / `.readOnly` / `.readWrite` / `@unknown`).
- **Read-back**: every write is followed by a `readNDEF` read-back compared
  via `NFCURICodec.match`; `writeVerified` (not just `writeSucceeded`) gates
  `linkBracelet`.
- **No permanent lock bytes**: band ships factory blank and unlocked
  (`factoryLock = false`, `isRewritable = true`); a `.readOnly` tag is
  refused, never force-written; RedMed never calls a lock/permalock API.
- **CoreNFC session type**: `NFCNDEFReaderSession` only — never
  `NFCTagReaderSession` (raw tag access, lock-byte capable). No Simulator
  fake-success path anywhere.
