# RedMed (frisky)

Native iOS medical ID + emergency aid app. Shipable source of truth is
`RedMed-Xcode/` (SwiftUI, iOS 17+, Xcode 15+).

## Canonical tree

| Path | Role |
|------|------|
| `RedMed-Xcode/` | **Owner app** — edit profile, Aid treatments, NFC write; only `.xcodeproj`; CI/`run.sh` |
| `card.html` | **Passerby scan page** — bracelet tap opens `card/#d=…` (read-only; no Edit/NFC) |
| `get.html` | Packaging / App Store setup landing only (no health data) |
| `uploads/` | Staged / experimental Swift — **not** in the Xcode project (see `uploads/README.md`) |
| `code_and_design/` | Claude canvas + stale Swift snapshot — **no** `.xcodeproj` (see its README) |
| `Main.dc.html` / `code_and_design/Main.dc.html` | Claude design canvas for the owner UI (keep in sync) |
| `RedMed.html` / `RedMed-standalone.html` | Bundled HTML previews of that canvas |
| Legal HTML (`PrivacyPolicy`, `TOS`, `security`, `HowItWorks`) | **Body text** lives in `RedMed-Xcode/RedMed/`; root copies must match except CSS href (`assets/legal-doc.css` for web) |
| `compliance/` | MHRA / DTAC / cyber pack drafts |

Do not open a PR with `base: main` and `compare: main` — pick a feature
branch from the compare dropdown (or push one first).

## Branch naming

Git cannot store `main/foo` while a branch named `main` exists (ref file vs
directory clash). Use `main-<desc>-xxxx` (hyphen), not `main/<desc>-xxxx`.

## Build (macOS only)

```bash
./scripts/run.sh
# or
open RedMed-Xcode/RedMed.xcodeproj
```

Linux / Cursor Cloud cannot build or run this app (no Xcode / iOS Simulator).
CI (`.github/workflows/ios-build.yml`) compile-checks on `macos-latest` when
`RedMed-Xcode/**` changes.
