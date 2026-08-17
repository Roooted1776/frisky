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
- Hosted passerby path: `https://getredmed.com/tapper/` (`tapper/index.html`; legacy `pages.dev` — `docs/domain.md`).
- Positioning: local EMS assist / fast ID handoff — not a medical device, no outcome promises, call 911 first. HIPAA-aligned offline posture; no false certification claims.

## Permanent decisions he has locked (do not regress)

See also `AGENTS.md`. High-signal recap:

1. Owner vs scanner shells are permanent product law.
2. **Owner band data independence:** owner Write packs only
   `https://getredmed.com/tapper/#d=…` (`AppConfig.OwnerBandURI`). No vendor
   tag-management cloud, no social/short-link URL on the chip, no BLE. Pages
   hosts the static shell; PHI stays in the fragment.
3. Settings = **haptic + Location only**. Brightness 100% + system volume 100% + locator siren arm on crash / severe-impact (`CrashMotionGuard`), owner **SOS · Locate me**, or **real bracelet NFC** open of `tapper.html#d=…` (hardware-local SOS on that phone). Owner Find Help open, bare `/tapper/`, and in-app scanner preview do **not** auto-arm.
4. Survival hold may keep siren + max volume + brightness through background until cancel on Aid (or Stop SOS on Find Help).
5. Vault Face ID: relock on **`.background` only** (not `.inactive` — Face ID sheets).
6. Owner lock: every launch is cream atmosphere + muted `LockOpen.mp4` behind
   a Face ID–sized medical mark (`FaceIDFrame.mp4`, else `LockMedGlyph` — not
   BrandLogo, not Apple Face ID scan) under auto Face ID before Main (Proceed
   + Agreement cream dock ~25% after cancel / mismatch; Agreement opens the
   Privacy / TOS / Security slideshow). Video never delays Face ID or Main
   (no overlay, no ready/end wait). Fresh install
   unlocks into empty tabs after auth. Owner pages + tapper: cream fill only —
   no page BrandLogo. **No hanging decorative brand marks** (lock watermark, Aid
   pane wordmarks, privacy-cover logo gone). NFC / topic sheets keep one page
   BrandWordmark header; tapper YOU-card BrandLogo stays as the medical header.
   Privacy cover: opaque, no fade; capture only while PHI in RAM; non-capture
   cover **`.background` only** (never `.inactive` / Face ID sheets) — never over
   the lock / Unlock shell, and **never over the tap card** (Preview / Scan /
   passerby YOU card).
7. Cold launch: zero Location / MapKit / trauma JSON at `@main`. CoreMotion crash monitor may start after first-frame yield.
8. Unique `project.pbxproj` IDs (duplicate IDs drop sources).
9. Passerby SW: cache-first multi-key shell for almost-instant EMT open; clear prior CACHE on activate; bump `redmed-tapper-vN` in lockstep. Tap-to-view = HTML; no biometric copy in any passerby / policy HTML.
10. `AppConfig.BraceletRF` owns tap-distance + iOS Background Tag Reading copy
   (no hardcoded inches). BTR can still open `tapper.html` on a deliberate tap
   even if the phone is off or locked (~1–2″); write does not change likelihood;
   band stays passive — **no battery** (reject AirTag-style cells / recurring
   demand). Do not claim “no background NFC” without the Apple OS caveat.
11. Crash / high-speed **vehicle impact** detection is **local** — CoreMotion in the native app (owner + in-app scanner), DeviceMotion in passerby `tapper.html` (same g thresholds). Not Apple Crash Detection, no cloud. Must ignore running, walking, sex, masturbation, eating, hand/wrist handling, and other rhythmic daily activity. Real bracelet NFC (`#d=`) → local SOS on that phone only (no server). Owner Find Help does not auto-arm. Passerby HTML alarm is Web Audio + wake lock (no system volume/brightness APIs).
12. **Hardware ship is not app architecture.** Blank **NXP NTAG216**, 13.56 MHz,
   ISO 14443A Type 2, NDEF unlocked / empty (no pre-encode, no lock) → NFC
   entitlement live on device → factory MOQ. Not NTAG213, MIFARE, LF, or UHF.
   Band mold: adult wine/burgundy silicone (`#6B1E2F`) + flat laser plate; face
   engrave `MED ID` only. No Shopify / custom-chip / storefront stacks as the
   hardware path.

## What he has already done (shipped history)

Compressed from merged PRs / `main` history. Agents should treat these as **done** unless asked to change them.

### Roles, launch, chrome
- Locked owner vs passerby shells; four owner tabs (RedMed · 911 · Aid · NFC); scanners RedMed/911/Aid.
- Owner app on first launch; `Main.swift` owner shell; HTML policies redirect `redmed://main`.
- Deferred all Core Location until Find Help; fixed SIGTERM/launch confusion.
- Cold launch: LaunchBackground only on UILaunchScreen (no system BrandLogo).
  Every owner launch: auto Face ID over cream + muted LockOpen.mp4 behind the
  Face ID–frame medical mark (`FaceIDFrame.mp4`, else glyph; no decorative
  BrandLogo; Proceed + Agreement cream dock ~25% after cancel / mismatch). Clip never gates
  Face ID or Main (no overlay; that was the cream hang). Face ID starts on the first interactive frame (not cold
  `.inactive` — that SpringBoard overlay left Face ID done but the owner
  still had to tap the app to open). App lock reuses a just-completed
  device Face ID so that scan opens Main. Prefetch still starts
  in the same `onAppear` tick and inside the unlock pipeline. Fresh install
  unlocks into empty tabs after auth. Keychain decode + AES `#d=` pack +
  tapper.html string warm overlap Face ID; WKWebView warm only after unlock
  (Face ID–overlap WebKit stole MainActor → white/cream hang after auth).
  Parked Keychain adopt unlocks on the same MainActor turn (no Task hop). No
  unlock fade. Lock shell on first frame — no Keychain in `@State`; CoreMotion
  after unlock. PrivacySnapshotGuard never covers lock / Unlock — only while
  PHI is in RAM. Owner pages + tapper: cream fill only (no page BrandLogo).
  Unlock fail-closed if an expected Keychain blob fails to decode.
- Vault Local History: Accept tap before Face ID (no auto-prompt on appear).
- Opacity keep-alive tabs: Find Help GPS + seizure autodial tear down via
  `isVisible` (not `onDisappear` — opacity hide never fires it).
- Custom tab bar spacing; Aid content-first (no hanging pane wordmarks); RedMed
  fonts; Preview scanner Back = Edit chrome (`ChromeTextAction`: accent red,
  plain page-bg fill, 18 regular) on all tabs. Find Help title + Back pinned
  above scroll.
- Version 1.1 driven from build settings; simulator default iOS 27.0; CI iOS compile workflow (later gated when Actions billing blocked macOS).

### Edit / profile / Face ID
- Reactive Edit (freeze fixes); DatePicker birth date; ✕ delete rows; empty defaults / contrast.
- Emergency contacts: phone + relation layout through persistence, card, mirrors.
- Face ID on first Save / edit / NFC write; AppLock design overlay; BiometricAuth Simulator Authenticate prompt.
- Keychain profile; no demo patient filler.

### NFC / bracelet / passerby web
- Passive HF NFC physics + BraceletRF constants (Type 2 / rewritable NTAG).
- Owner Write gated to `OwnerBandURI` (`#d=` only — no vendor cloud / social / BLE).
- NFC tab for owners; CoreNFC on via `nfcHardwareEnabled` + NDEF entitlement
  (tab always visible; scanners never get NFC).
- Main paired line reactive: write → Paired; profile edit → Not paired until rewrite.
- Same RedMed header for owner + responder; Linked only after NFC write **and**
  YOU-card identity (name, birth, blood) is filled.
- Compact NTAG213 `#d=` codec; AES-GCM seal; legacy zlib + pre-AES decode restored.
- `tapper.html` single passerby shell; `card.html` / `get.html` / `/get/` legacy redirects preserving `#d=`.
- Offline service worker; HTTP cache bypass; stale-shell fixes; Pages `/tapper/` deploy path.
- Simulate scan from current profile; fail closed when pack/decode breaks.
- Band engraving copy + hardware sourcing notes.
- Band mold/color locked: adult **wine/burgundy** silicone (`#6B1E2F`), flat
  laser plate, NTAG216 blank; face engrave is **`MED ID` only** (no reverse
  personalization) (`docs/band-engraving-and-nfc-sourcing.md`).

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
- **Hardware ship (RED-19):** code has `nfcHardwareEnabled` + NDEF entitlement; still need verified blank NTAG216 stock, App ID NFC Tag Reading on paid Apple Developer, then factory MOQ.
- Linear workspace still has default onboarding issues (RED-1…4), not product backlog.

## Do not reopen without explicit ask

- Shopify / e-commerce / storefront packs, custom chip firmware, or other “hardware architecture” as a substitute for blank NTAG216 + entitlement + factory MOQ.
- Re-adding Settings toggles for brightness, locator, or crash survival alarm.
- Auto-arming brightness or locate-me siren just from opening **owner** Find Help, bare `/tapper/`, or in-app scanner preview (crash + explicit owner SOS; real bracelet `#d=` tap may arm hardware-local SOS).
- Requiring Face ID / biometrics for passerby tap-to-view (`tapper.html` / scanner shell).
- Covering or overlaying the tap card (Preview / Scan / YOU card) — privacy
  veil, tab-bar shadow hits, dual-scroll, login, or Face ID.
- Relocking vault on `.inactive`.
- Mutating owner `@AppStorage` from scanner UI.
- Repo-root policy HTML duplicates.
- Parallel long-lived feature branches beside `main`.
- Claiming Apple Crash Detection or cloud crash telemetry.
- Writing vendor tag-management / social / short-link URLs (or BLE) to the band
  instead of `medicalCardBaseURL#d=`.
- Re-adding staging `uploads/`, debug `screenshots/`, dead `support.js` /
  `ios-frame.jsx`, or UK `compliance/` paper packs to the working tree.
