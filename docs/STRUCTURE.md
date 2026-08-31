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
├── RedMed-Xcode/          # native owner app
├── tapper/                # passerby shell + shell-relative PNGs
├── assets/                # canonical brand PNGs / SVG
├── docs/                  # all long-form docs (this file, MAX, SECURITY, product notes)
├── scripts/               # run, deploy, smoke, tapper guard
├── Pages surface files    # tapper.html, redirects, sw, wrangler (see table)
└── .github/workflows/
```

## docs/

| File | Role |
|------|------|
| `../MAX.md` | Max profile + shipped history (agent memory; linked from `AGENTS.md`) |
| `docs/SECURITY.md` | Advisory pointer into Help.html |
| `docs/STRUCTURE.md` | This map |
| `docs/domain.md` | getredmed.com cutover |
| `docs/NFC-RESTORE.md` | CoreNFC entitlement restore |
| `docs/band-engraving-and-nfc-sourcing.md` | Hardware |

## Code organization (logical)

Xcode groups under target **RedMed**. Disk stays flat under `RedMed-Xcode/RedMed/`
so `pbxproj` paths and `Bundle.main` basename loads stay stable.

Pull `main` on the MacBook after merges.
