# RedMed (frisky)

Native iOS medical ID + emergency aid app. Shipable source of truth is
`RedMed-Xcode/` (SwiftUI, iOS 17+, Xcode 15+).

## Canonical tree

| Path | Role |
|------|------|
| `RedMed-Xcode/RedMed/Main.swift` | **Owner app** — edit profile, Aid, NFC, How It Works (`MainInfoView`) |
| `get.html` | **Passerby scan** — bracelet tap; compact `#d=` payload; links back to `redmed://main` for owners |
| `card.html` | Legacy redirect → `get.html` (older bands) |
| Policy HTML (`PrivacyPolicy`, `TOS`, `security`) | Legal docs only; CTA redirects into the app (`Main.swift`) |
| `HowItWorks.html` | Thin redirect stub → `redmed://main` / App Store (content is Swift) |
| `uploads/` | Staged / experimental Swift — **not** in the Xcode project (see `uploads/README.md`) |
| `compliance/` | MHRA / DTAC / cyber pack drafts |

Passerby HTML is `get.html` (plus legacy `card.html` redirect). Owner UI is native SwiftUI only.

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
