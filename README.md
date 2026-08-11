# RedMed (frisky)

Native iOS medical ID + emergency aid app. Shipable source of truth is
`RedMed-Xcode/` (SwiftUI, iOS 17+, Xcode 15+).

## Canonical tree

| Path | Role |
|------|------|
| `RedMed-Xcode/` | **Owner app** — edit profile, Aid treatments, NFC write; only `.xcodeproj`; CI/`run.sh` |
| `card.html` | **Passerby scan page** — bracelet tap opens `card/#d=…` (read-only; no Edit/NFC) |
| Legal HTML (`PrivacyPolicy`, `TOS`, `security`, `HowItWorks`) | **Only other HTML** — body text in `RedMed-Xcode/RedMed/`; root copies match except CSS href (`assets/legal-doc.css` for web) |
| `uploads/` | Staged / experimental Swift — **not** in the Xcode project (see `uploads/README.md`) |
| `compliance/` | MHRA / DTAC / cyber pack drafts |

No other product HTML. Owner UI is native SwiftUI only.

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
