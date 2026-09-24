# RedMed tree map

Single source of truth: **git `main`** → `Roooted1776/frisky`.
Local path (one clone per machine): **`~/Documents/frisky`** on MacBook and Mac Mini. See [`DUAL-MAC.md`](DUAL-MAC.md).

## Root (intentionally small)

Only what must live at the deploy / GitHub surface:

| Path | Why at root |
|------|-------------|
| `README.md` | GitHub landing (product + run/deploy + dead-host note) |
| `AGENTS.md` | Cursor / agent rules (must be easy to find) |
| `tapper.html` · `index.html` · `card.html` · `get.html` · `get/` · `redmed-emergency.html` | Identical `#d=` redirect stubs → `/tapper/` (`scripts/write-tapper-redirects.sh`) |
| `sw.js` · `_headers` · `_redirects` · `scripts/stage-worker-assets.sh` · `scripts/deploy-hostinger-static.mjs` · `scripts/setup-cloudflare-dns.mjs` · `scripts/verify-cf-dns-cutover.sh` | Hostinger static deploy + Cloudflare DNS/SSL cutover for `redmed.live` / SW |
| `wrangler.jsonc` · `worker/` | Optional leftover Worker tooling — product host is Hostinger (`docs/domain.md`) |
| `apple-app-site-association` · `.well-known/apple-app-site-association` | Universal Links — identical, both locations required (Apple checks root, then `.well-known/`) |
| `.gitignore` · `.github/` · `.cursor/` | tooling |

No brand PNGs at repo root — canonical in `assets/`, shell-relative copies in `tapper/`.

## Folders

```text
frisky/
├── README.md · AGENTS.md · MAX.md
├── owner/                 # App Store wearer app (SwiftUI) + Document/ policy source
├── tapper/                # tap pages only — passerby shell, no owner-app features
├── worker/                # redmed-emergency HTMLRewriter (device aspect hint)
├── Document/              # hosted Help: index.html = full policy; Document.html = redirect
├── privacy/               # /privacy bounce → /Document/#privacy (_redirects + privacy/index.html)
├── support/               # App Store Connect Support URL (scripts/publish-github-io.sh)
├── assets/                # canonical brand PNGs / SVG
├── docs/                  # all long-form docs (this file, MAX, SECURITY, product notes)
├── scripts/               # run, deploy, smoke, sync-document, write-tapper-redirects, #d= codec
├── Pages surface files    # identical redirect stubs, sw, wrangler (see table)
└── .github/workflows/
```

## docs/

| File | Role |
|------|------|
| `../MAX.md` | Max profile + shipped history (agent memory; linked from `AGENTS.md`) |
| `docs/SECURITY.md` | Pointer into Help → Security / `/Document/#security` (not a second threat model) |
| `docs/STRUCTURE.md` | This map |
| `docs/DUAL-MAC.md` | MacBook + Mini: Cursor ShipIt repair, prefs/colors sync, `gh` HTTPS push/pull |
| `docs/domain.md` | `redmed.live` Namecheap → Cloudflare DNS/SSL → Hostinger static |
| `docs/NFC-RESTORE.md` | CoreNFC entitlement restore |
| `docs/band-engraving-and-nfc-sourcing.md` | Hardware |
| `docs/ADVERTISING.md` | Two ad views: wearer/family (DTC) and facility/EMS; shared gate + banned claims |
| `docs/ems-station-outreach.md` | View B station playbook (60s brief + one-pager). Recognition training only until company gate |
| `docs/redmed-funding-growth-email-draft.md` | Paste-ready bi-weekly View B email for the **RedMed Funding/Growth** bot |
| `docs/biweekly-funding-bot-email.md` | Same email + Cursor Automation / Gmail MCP wiring. No live lists or tokens in git |
| `docs/FDA-CLAIMS-WALL.md` | §520(o) / General Wellness claims wall — Arrival Day Pack + station sell |
| `docs/IP-ASSIGNMENT.md` | How-to: confirmatory IP assignment (code, tapper, brand, band → LLC) |
| `docs/ip-assignment.html` | Printable one-page instrument (sign; do not commit the signed copy) |
| `docs/SPEC-EXHIBIT-A-PO-QC.md` | Pre-50 factory PO / QC rider how-to (freight line, 5-day QC, no Deposit 2 without written accept/reject) |
| `docs/spec-exhibit-a-po-qc-rider.html` | Printable bilingual EN/中文 rider (sign; do not commit the filled copy) |
| `docs/FOUNDER-WHY.md` | Careful founder-why paste (categories only) — About / station insert / Arrival Day Pack |

Hosted `/Document/` stays lockstep with `owner/RedMed/Document/` via `scripts/sync-document.sh`: `Document/index.html` is the full policy; `Document/Document.html` is a thin hash-preserving redirect to `/Document/` (one tree, no twin full copy). Band tap Help opens `/Document/` straight — no start screen. `/privacy` redirects there.

## Surfaces (tapper vs owner)

| | `tapper/` | `owner/` |
| --- | --- | --- |
| **Who** | Stranger who tapped the band | Wearer with the App Store app |
| **What** | Web tap pages (`/tapper/#d=…`), 911 · Aid | SwiftUI app: Edit, NFC, Keychain, Face ID |
| **Claims** | No ads, no auth, no trackers | General Wellness ICE card — **not** HIPAA-certified |
| **Do not put here** | NFC tab, Edit, owner Keychain, App Store copy | Passerby-only redirect stubs, Worker device hints |

Xcode bundles `tapper/index.html` as read-only `tapper.html` for NFC Preview — one source file, not a fork.

## Code organization (logical)

Xcode groups under target **RedMed**. Disk stays flat under `owner/RedMed/`
except policies: `Document/Document.html` + `Document/legal-doc.css` (Xcode group
`Document`, path = Document). `Bundle.main` loads by basename; WKWebView read
access is the Document folder so the stylesheet resolves. Legacy
`RedMed/Help.html` is a hash-preserving redirect stub (not bundled).

Pull `main` on whichever Mac you are about to open Xcode on.
