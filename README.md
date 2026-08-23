# RedMed (frisky)

Native iOS medical ID + emergency aid app. Shipable source of truth is
`RedMed-Xcode/` (SwiftUI, iOS 17+, Xcode 15+).
Cursor, Claude, and other LLM programs should open this repo at `/Users/claude/Documents/frisky` (the local project root).

## Canonical tree

| Path | Role |
|------|------|
| `MAX.md` | **Max’s personal profile + shipped history** (agent memory) |
| `AGENTS.md` | Permanent product/engineering rules for agents |
| `RedMed-Xcode/RedMed/Main.swift` | **Owner app** shell (`ContentView`) — edit profile, Aid, NFC, Help |
| `tapper/index.html` (+ root `tapper.html`) | **Passerby / scanner** — bracelet tap at `https://roooted1776.github.io/tapper/` (custom host cutover: `docs/domain.md`); RedMed · 911 · Aid (no Edit / NFC) |
| `card.html` / `get.html` / `get/` | Legacy redirects → `/tapper/` (keeps `#d=` for old bands) |
| `RedMed-Xcode/RedMed/Help.html` + `legal-doc.css` | Owner Help policies (Privacy, Terms, Security in one bundled file). Legacy `PrivacyPolicy` / `TOS` / `security` redirect into it. `HowItWorks.html` still redirects `redmed://main`. |
| `pheart.png` + `assets/` / `BrandLogo.png` / `BrandWordmark.png` | Heart mark (`#fff7f7` around the circle). App icon, YOU-card logo, Pages / SW paths |
| `docs/band-engraving-and-nfc-sourcing.md` | Band engraving + NFC hardware notes |
| `docs/NFC-RESTORE.md` | CoreNFC hardware restore notes (entitlement + flag) |
| `docs/domain.md` | Custom domain (`getredmed.com`) purchase + Pages cutover |

No other product HTML. Owner UI is native SwiftUI only. Do not reintroduce
`uploads/`, `screenshots/`, or UK `compliance/` drafts — git history has them.

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
