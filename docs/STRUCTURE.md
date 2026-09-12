# RedMed tree map

Single source of truth: **git `main`** → `Roooted1776/frisky`.
Local Mac path: **`/Users/claude/Documents/frisky`** only.

## Root (intentionally small)

Only what must live at the deploy / GitHub surface:

| Path | Why at root |
|------|-------------|
| `README.md` | GitHub landing (product + run/deploy + dead-host note) |
| `AGENTS.md` | Cursor / agent rules (must be easy to find) |
| `tapper.html` · `index.html` · `card.html` · `get.html` · `get/` | Pages URLs + `#d=` redirects |
| `sw.js` · `_headers` · `_redirects` · `wrangler.toml` | Cloudflare / SW |
| `.gitignore` · `.github/` · `.cursor/` | tooling |

## Folders

```text
frisky/
├── README.md · AGENTS.md · MAX.md
├── RedMed-Xcode/          # native owner app (+ Document/ policies)
├── tapper/                # passerby shell + shell-relative PNGs
├── Document/              # hosted Help policies (lockstep copy of Xcode Document/)
├── assets/                # canonical brand PNGs / SVG
├── docs/                  # all long-form docs (this file, MAX, SECURITY, product notes)
├── scripts/               # run, deploy, smoke, tapper guard, #d= codec test
├── Pages surface files    # tapper.html, redirects, sw, wrangler (see table)
└── .github/workflows/
```

## docs/

| File | Role |
|------|------|
| `../MAX.md` | Max profile + shipped history (agent memory; linked from `AGENTS.md`) |
| `docs/SECURITY.md` | Advisory pointer into Document.html |
| `docs/STRUCTURE.md` | This map |
| `docs/domain.md` | getredmed.com cutover |
| `docs/NFC-RESTORE.md` | CoreNFC entitlement restore |
| `docs/band-engraving-and-nfc-sourcing.md` | Hardware |
| `docs/ADVERTISING.md` | Two ad views: wearer/family (DTC) and facility/EMS; shared gate + banned claims |
| `docs/IP-ASSIGNMENT.md` | How-to: confirmatory IP assignment (code, tapper, brand, band → LLC) |
| `docs/ip-assignment.html` | Printable one-page instrument (sign; do not commit the signed copy) |

Hosted `/Document/` is a lockstep copy of `RedMed-Xcode/RedMed/Document/` (`scripts/sync-document.sh`). Band tap Help opens it straight — no start screen. `/privacy` redirects there.

## Code organization (logical)

Xcode groups under target **RedMed**. Disk stays flat under `RedMed-Xcode/RedMed/`
except policies: `Document/Document.html` + `Document/legal-doc.css` (Xcode group
`Document`, path = Document). `Bundle.main` loads by basename; WKWebView read
access is the Document folder so the stylesheet resolves. Legacy
`RedMed/Help.html` is a hash-preserving redirect stub (not bundled).

Pull `main` on the MacBook after merges.
