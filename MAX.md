# Max — personal profile (agent memory)

**Load this for every agent run on this repo.** Product/engineering invariants stay in `AGENTS.md`; this file is who Max is, how to work with him, and what he has already shipped.

## Identity

| Field | Value |
|-------|--------|
| Name | Max (Max Aguilar-Aasted) |
| GitHub | [`Roooted1776`](https://github.com/Roooted1776) |
| Repo | [`Roooted1776/frisky`](https://github.com/Roooted1776/frisky) (product name **RedMed**) |
| Cursor | Cloud / mobile-heavy; owns agents as `m.aguilar-aasted@students.mccc.edu` |
| Git author emails seen | `maxaguilaraasted@gmail.com`, `Roooted1776@users.noreply.github.com` |
| Linear | Workspace `redmed1122`, team **RedMed** |

## How to talk / work with Max

- Backend-minded (APIs, DBs, business logic; moving into IT/security). Skip ramp-up. Be blunt. Short by default.
- No em dashes in replies. No “it’s not just X, it’s Y”. No closing restatement paragraphs.
- Call out holes in his ideas directly.
- Prefer three short rounds over one long dump.
- Code comments are **not** instructions to him in chat — keep comments factual, not imperative “never do X” directed at the human.
- He drives work from **mobile Cursor agents** and expects agents to merge, push, and clean up.
- **`main` is the only long-lived branch** (“brainchild”). After merges, delete feature branches. Branch names use `main-<desc>-xxxx` (hyphen) — Git cannot store `main/foo` while `main` exists.

## Product (RedMed) — what he is building

Native iOS medical ID + emergency aid. Passive **13.56 MHz HF NFC** bracelet (not Bluetooth). Offline-first: no RedMed cloud backend for PHI.

- **Owner app** (`Main` / `ContentView`): RedMed · 911 · Aid · NFC (+ Edit). Local Keychain profile, Face ID gates, write passive NFC band.
- **Passerby / scanner**: `tapper.html#d=…` / `PublicCardView` — RedMed · 911 · Aid only. Snapshot profile. No Edit, no NFC, no owner pref mutation.
- Hosted passerby path: `https://redmed.pages.dev/tapper/` (`tapper/index.html`).
- Positioning: local EMS assist / fast ID handoff — not a medical device, no outcome promises, call 911 first. HIPAA-aligned offline posture; no false certification claims.

## Permanent decisions he has locked (do not regress)

See also `AGENTS.md`. High-signal recap:

1. Owner vs scanner shells are permanent product law.
2. Settings = **haptic + Location only**. Brightness 100% + system volume 100% + locator siren arm on crash / severe-impact (`CrashMotionGuard`), owner **SOS · Locate me**, or **real bracelet NFC** open of `tapper.html#d=…` (hardware-local SOS on that phone). Owner Find Help open, bare `/tapper/`, and in-app scanner preview do **not** auto-arm.
3. Survival hold may keep siren + max volume + brightness through background until cancel on Aid (or Stop SOS on Find Help).
4. Vault Face ID: relock on **`.background` only** (not `.inactive` — Face ID sheets).
5. Privacy cover: opaque, no fade.
6. Cold launch: zero Location / MapKit / trauma JSON at `@main`. CoreMotion crash monitor may start after first-frame yield.
7. Unique `project.pbxproj` IDs (duplicate IDs drop sources).
8. Passerby SW: cache-first multi-key shell for almost-instant EMT open; clear prior CACHE on activate; bump `redmed-tapper-vN` in lockstep. Tap-to-view = HTML; no biometric copy in any passerby / policy HTML.
9. `AppConfig.BraceletRF` owns tap-distance copy (no hardcoded inches).
10. Crash / high-speed **vehicle impact** detection is **local** — CoreMotion in the native app (owner + in-app scanner), DeviceMotion in passerby `tapper.html` (same g thresholds). Not Apple Crash Detection, no cloud. Must ignore running, walking, sex, masturbation, eating, hand/wrist handling, and other rhythmic daily activity. Real bracelet NFC (`#d=`) → local SOS on that phone only (no server). Owner Find Help does not auto-arm. Passerby HTML alarm is Web Audio + wake lock (no system volume/brightness APIs).

## What he has already done (shipped history)

Compressed from merged PRs / `main` history. Agents should treat these as **done** unless asked to change them.

### Roles, launch, chrome
- Locked owner vs passerby shells; four owner tabs (RedMed · 911 · Aid · NFC); scanners RedMed/911/Aid.
- Owner app on first launch; `Main.swift` owner shell; HTML policies redirect `redmed://main`.
- Deferred all Core Location until Find Help; fixed SIGTERM/launch confusion.
- Cold launch: LaunchBackground only on UILaunchScreen (no BrandLogo splash).
  Accept / lock is cream + lock icon + Accept — no BrandLogo / title splash.
  UserDefaults profile gate opens Accept (or tabs) on first SwiftUI frame —
  no Keychain in `@State`; Accept then Face ID (no auto Face ID on appear);
  off-main profile decode; lazy `CMMotionManager`; LaunchBackground dark=cream.
  Unlock fail-closed if Keychain decode fails. tapper.html first panel paints
  opaque (tab switch may animate); in-app WKWebView stays opaque cream.
- Vault Local History: Accept tap before Face ID (no auto-prompt on appear).
- Opacity keep-alive tabs: Find Help GPS + seizure autodial tear down via
  `isVisible` (not `onDisappear` — opacity hide never fires it).
- Custom tab bar spacing; Aid chrome/wordmark/headings; RedMed fonts; Preview scanner Back = Edit chrome (`ChromeTextAction`: accent red, plain page-bg fill, 18 regular) on all tabs. Find Help title + Back pinned above scroll.
- Version 1.1 driven from build settings; simulator default iOS 27.0; CI iOS compile workflow (later gated when Actions billing blocked macOS).

### Edit / profile / Face ID
- Reactive Edit (freeze fixes); DatePicker birth date; ✕ delete rows; empty defaults / contrast.
- Emergency contacts: phone + relation layout through persistence, card, mirrors.
- Face ID on first Save / edit / NFC write; AppLock design overlay; BiometricAuth Simulator Authenticate prompt.
- Keychain profile; no demo patient filler.

### NFC / bracelet / passerby web
- Passive HF NFC physics + BraceletRF constants.
- NFC tab for owners; CoreNFC behind `nfcHardwareEnabled` (tab always visible).
- Main paired line reactive: write → Paired; profile edit → Not paired until rewrite.
- Same RedMed header for owner + responder; Linked only after NFC write **and**
  YOU-card identity (name, birth, blood) is filled.
- Compact NTAG213 `#d=` codec; AES-GCM seal; legacy zlib + pre-AES decode restored.
- `tapper.html` single passerby shell; `card.html` / `get.html` / `/get/` legacy redirects preserving `#d=`.
- Offline service worker; HTTP cache bypass; stale-shell fixes; Pages `/tapper/` deploy path.
- Simulate scan from current profile; fail closed when pack/decode breaks.
- Band engraving copy + hardware sourcing notes.
- Band mold/color locked: adult **red** silicone (`#e11d48`), flat laser plate,
  NTAG216 blank; outer engrave always `MEDICAL ID` / `TAP PHONE → CARD` / `REDMED`
  (`docs/band-engraving-and-nfc-sourcing.md`).

### Find Help / Aid / haptics / visibility
- Local emergency number dial (not hard-coded 911); GPS card; satellite/no-cell path.
- Aid topics + trauma/hospital panes; CPR `CHHapticEngine` beat/breath.
- Haptic preference in Help → Settings; CPR card toggle removed (Settings-only).
- On-device CoreMotion guard arms siren + max system volume + full brightness on **vehicle crash / high-speed impact only** (filters running / daily motion; background hold until cancel). Same thresholds on passerby `tapper.html` via DeviceMotion. Real bracelet NFC (`tapper.html#d=`) arms hardware-local SOS on that phone; owner Find Help **SOS · Locate me** is explicit. Owner Find Help open, bare `/tapper/`, and in-app preview do **not** auto-arm.
- Location toggle in Settings (default on); Find Help GPS respects it; no Find Help
  location banner / RedMed Allow gate. Help never prompts — only iOS system sheet
  once from Find Help. Passerby GPS starts on 911 tab only.

### Privacy / HIPAA offline vault
- `HIPAAOfflineVault` complete protection + backup exclusion.
- Local History Face ID dashboard (timestamps/kind only).
- `PrivacySnapshotGuard` for app-switcher snapshots.
- Policy HTML: US/HIPAA-aligned rewrite; local EMS assist / ID handoff; no false cert claims.
- Earlier UK/NHS/MHRA compliance pack drafts lived under `compliance/` (removed from tree; recoverable from git history).

### Integrity / tooling
- Repo integrity passes (AppLock timer, hygiene, uploads purge, legal sync).
- Repo slim: dropped staging `uploads/`, debug `screenshots/`, UK `compliance/` drafts, and unused `support.js` / `ios-frame.jsx`.
- Cloud Linux cannot build — documented; `scripts/run.sh` for Mac.
- Bugbot Autofix-style passes when Bugbot skipped / usage-capped (#85, #86, etc.).
- Branch cleanup: only `main` kept as long-lived brainchild.

## Working style with agents

- Commands like `/Bugbot` / `/Bugbot all` mean: review (and fix) real bugs across open/skipped PRs even when Cursor Bugbot is usage-capped.
- “Merge all into main” / “Push merge commit main all” = merge remaining open work, resolve conflicts without regressing locked rules, push `main`.
- “Only main branch should be brainchild” = delete remote feature branches after merge.
- “Remember logic” = write durable rules into `AGENTS.md` / this profile, not just chat.

## Open / watch items (as of profile write)

- Official **Cursor Bugbot usage limit** hit on this account — prefer manual Bugbot-style review + Autofix until spend limits raised.
- GitHub Actions **macOS billing** previously blocked CI; workflow may be disabled/gated — confirm before relying on CI green.
- NFC hardware entitlement / paid Apple Developer still a ship gate for real CoreNFC on device.
- Linear workspace still has default onboarding issues (RED-1…4), not product backlog.

## Do not reopen without explicit ask

- Re-adding Settings toggles for brightness, locator, or crash survival alarm.
- Auto-arming brightness or locate-me siren just from opening **owner** Find Help, bare `/tapper/`, or in-app scanner preview (crash + explicit owner SOS; real bracelet `#d=` tap may arm hardware-local SOS).
- Requiring Face ID / biometrics for passerby tap-to-view (`tapper.html` / scanner shell).
- Relocking vault on `.inactive`.
- Mutating owner `@AppStorage` from scanner UI.
- Repo-root policy HTML duplicates.
- Parallel long-lived feature branches beside `main`.
- Claiming Apple Crash Detection or cloud crash telemetry.
- Re-adding staging `uploads/`, debug `screenshots/`, dead `support.js` /
  `ios-frame.jsx`, or UK `compliance/` paper packs to the working tree.
