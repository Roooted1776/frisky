# RedMed (frisky)

Native iOS medical ID + emergency aid. **Source of truth:** git `main` at
`Roooted1776/frisky`. Mac path only:

```text
/Users/claude/Documents/frisky
```

## Fetch / pull `main` (Mac)

After every remote squash-merge, update the Mac clone:

**GitHub Desktop**

1. Open the **frisky** repository.
2. **Fetch origin**
3. **Pull** branch **main**

**Terminal**

```bash
cd /Users/claude/Documents/frisky
git fetch origin
git checkout main
git pull origin main
```

Do not create a second clone. Do not pull feature branches as the long-lived
working tree — `main` only.

Build:

```bash
open RedMed-Xcode/RedMed.xcodeproj
# or
./scripts/run.sh
```

## Root vs folders

**Root stays thin** (Pages + agent entrypoints only):

| Path | Role |
|------|------|
| `README.md` · `AGENTS.md` · `MAX.md` | Landing + agent rules + Max memory |
| `tapper.html` · `index.html` · `card.html` · `get.html` · `get/` | Passerby URLs / `#d=` redirects |
| `sw.js` · `_headers` · `_redirects` · `wrangler.toml` | SW + Cloudflare |

**Everything else is in a folder:**

| Folder | Contents |
|--------|----------|
| `RedMed-Xcode/` | Owner app (SwiftUI + Xcode) |
| `tapper/` | Hosted shell + shell-relative brand PNGs |
| `assets/` | Canonical brand photos |
| `docs/` | `STRUCTURE.md`, `SECURITY.md`, domain / NFC / band notes |
| `scripts/` | run, deploy, smoke, sync-tapper |
| `.github/` | CI workflows |

Full map: [`docs/STRUCTURE.md`](docs/STRUCTURE.md). Security: [`docs/SECURITY.md`](docs/SECURITY.md).

## Build (macOS only)

```bash
./scripts/run.sh
```

Linux / Cursor Cloud cannot build the iOS app. CI compiles on `macos-latest` when
`RedMed-Xcode/**` changes (when billing allows).
