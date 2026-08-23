# RedMed (frisky)

Native iOS medical ID + emergency aid app. **Source of truth is git `main`** at
`Roooted1776/frisky`. On your MacBook, open only:

```text
/Users/claude/Documents/frisky
```

Fetch/Pull **main** in GitHub Desktop so that folder matches origin. Do not keep a
second clone. Build with:

```bash
open RedMed-Xcode/RedMed.xcodeproj
# or
./scripts/run.sh
```

## How the tree is organized (Mac Finder + git)

| Path | Role |
|------|------|
| `RedMed-Xcode/` | **Owner app** — SwiftUI, Xcode project, bundled resources |
| `tapper/` + root `tapper.html` + `sw.js` | **Passerby shell** for bracelet taps (GitHub Pages / Cloudflare) |
| `card.html` · `get.html` · `get/` | Legacy redirects → `/tapper/` (preserve `#d=`) |
| `assets/` + root brand PNGs | Pages / SW brand assets (CI requires root + `tapper/` copies) |
| `docs/` | Product notes (domain, NFC restore, band sourcing) |
| `scripts/` | `run.sh`, Pages deploy / smoke, `sync-tapper.sh` |
| `.github/workflows/` | iOS compile CI + Pages deploy |
| `AGENTS.md` · `MAX.md` · `SECURITY.md` | Agent rules, history, security model |

**Do not reintroduce** `uploads/`, `screenshots/`, or UK `compliance/` packs.

### Why some files look “duplicated”

These copies are **required**, not clutter:

| File | Copies |
|------|--------|
| `tapper.html` | repo root · `tapper/index.html` · `RedMed-Xcode/RedMed/tapper.html` (must stay byte-identical — `scripts/sync-tapper.sh` + Pages CI) |
| Brand logos | root · `tapper/` · `assets/` · app bundle (Pages + YOU-card + SW) |
| `sw.js` | root · `tapper/` · app bundle (CACHE name must bump in lockstep) |

### Owner app — Xcode navigator groups

Sources stay **flat on disk** under `RedMed-Xcode/RedMed/` so `project.pbxproj`
paths and `Bundle.main` resource names stay simple and do not break. In Xcode
they are already grouped:

| Group | Files (on disk, same folder) |
|-------|------------------------------|
| **App Shell** | `RedMedApp`, `Main`, `ContentView`, `OwnerAppLock`, `LockEntryPage`, `FacePage`, `Theme`, `AppConfig` |
| **Tab · RedMed** | `RedMedView`, `EditProfileView`, `ProfileData`, `MedicationData` |
| **Tab · 911** | `EmergencyView`, `EmergencyNumber`, `NearbyHospitals`, `LocationAccessSuggester`, `SatelliteFieldUI` |
| **Tab · Aid** | `AidView`, `TopicDetailView` |
| **Tab · NFC** | `NFCView`, `NFCBandManager`, `NFCWriter`, `NFCReader`, `ProfileNFCCodec` |
| **Scanner** | `PublicCardView`, `PasserbyHTMLCardView` |
| **Vault & Privacy** | `KeychainStore`, `BiometricAuth`, `HIPAAOfflineVault`, `VaultHistory*`, `PrivacySnapshotGuard`, `SecurePasteboard` |
| **Survival Alarm** | `CrashMotionGuard`, `BrightnessBoost`, `VolumeBoost`, `LocatorBeacon`, `HapticEngine`, `AudioSessionGate` |
| **Help & Settings** | `HelpMenuView`, `AppSettings` |
| **Policies** | `Help.html`, legacy policy redirects, `legal-doc.css` |
| **Passerby Bundle** | `tapper.html`, `card.html`, `sw.js`, brand PNGs |
| **Support** | `Assets.xcassets`, `Info.plist`, `RedMed.entitlements` |

Moving Swift into nested Finder folders requires rewriting every `pbxproj` path
at once or sources silently drop from the target. Prefer the groups above until
a coordinated folder move is done on Mac + verified with a device build.

## Sync MacBook ↔ git

1. GitHub Desktop → repo at `/Users/claude/Documents/frisky`
2. **Fetch origin** → **Pull** `main` (only long-lived branch)
3. Open `RedMed-Xcode/RedMed.xcodeproj` and build

After agent PRs are squash-merged into `main`, always Pull — local is not the
source of truth until it matches origin.

## Build (macOS only)

```bash
./scripts/run.sh
# or
open RedMed-Xcode/RedMed.xcodeproj
```

Linux / Cursor Cloud cannot build the iOS app. CI compiles on `macos-latest` when
`RedMed-Xcode/**` changes.
