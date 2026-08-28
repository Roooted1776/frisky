# AGENTS.md

## Cursor Cloud specific instructions

**Personal profile / memory:** read [`MAX.md`](./MAX.md) first for who Max is,
how he works, and what he has already shipped. Product invariants below stay
authoritative for code; `MAX.md` is the durable personal + history memory.

This repository is a **native iOS/SwiftUI app** (RedMed), located under `RedMed-Xcode/`. It
builds and runs **only on macOS with Xcode 15+** (prefer Xcode 27 / iOS 27.0 Simulator) and an
iOS 17+ Simulator or physical iPhone. Deployment target remains 17.0.

**It cannot be built, run, linted, or tested in the Cursor Cloud Linux VM.** There is no way to
set up a working runtime here:

- Xcode is macOS-only and cannot be installed on Linux.
- Every source file in `RedMed-Xcode/RedMed/` imports iOS-only frameworks (`SwiftUI`, `UIKit`,
  `CoreNFC`, `MapKit`, `LocalAuthentication`, `MessageUI`, `WebKit`, `CoreLocation`). Swift-for-Linux
  does not ship these frameworks, so even installing a Linux Swift toolchain does not enable a build.
- The iOS Simulator is macOS-only.

**There are no dependencies to install:** no Swift Package Manager, CocoaPods, Carthage, or npm.
The app has no backend, database, or web service.

**Roles / shells (permanent — do not regress):**
- **Owner app** (`Main` → `ContentView`, `isScannerSession == false`): tabs are
  **RedMed · 911 · Aid · NFC**. Edit is available on RedMed. NFC tab is always
  visible for owners; `AppConfig.nfcHardwareEnabled` only gates CoreNFC
  write/read sessions, never tab chrome. Owner writes the passive HF NFC band
  from the NFC tab (Face ID gated) as `medicalCardBaseURL#d=` only
  (`AppConfig.OwnerBandURI`) — no vendor cloud, no social/short URL, no BLE.
  Launch path is Face ID lock then Main (those tabs). No extra pages before Face ID. After unlock, a clickwrap (`ConsentGateView`) appears before Main on **every** Face ID unlock (boot, and any re-lock/re-unlock) — never in front of Face ID, never on passerby tapper.
- **Scanner / passerby shell** (`PublicCardView` / bracelet tap → `tapper.html#d=…`,
  `isScannerSession == true`): tabs are **RedMed · 911 · Aid** only — **no Edit**,
  **no NFC**. Profile is a snapshot; mutations must not touch owner Keychain or
  owner `@AppStorage` / UserDefaults prefs. Hosted passerby path is
  `AppConfig.medicalCardBaseURL` (currently `https://roooted1776.github.io/tapper/`,
  from `tapper/index.html`). Custom HTML host is TBD (`AppConfig.medicalCardCustomDomainTBD = nil`). Flip
  AppConfig only after `docs/domain.md` cutover is green. Do not write an
  unregistered host onto bands. `redmed.pages.dev` stays
  optional until Cloudflare secrets / Pages Git connect land.
  **Tap-to-view never requires Face ID / biometrics / passcode / login** — owner biometrics gate
  edit, NFC write, vault, and app unlock only. Passerby HTML never asks.
  **Nothing blocks the tap card** (YOU card / Preview / Scan / band tap): no
  privacy veil, no native overlay stealing taps, no login. Safari opens
  `tapper.html#d=` immediately.
  Native **Help** chrome is on Edit, 911, Aid, NFC, and in-app scanner screens.
  Not on the Face ID lock shell. Not a bottom dock on the owner RedMed tab
  (that dock was removed). Scanner Help is **policies only** (no Settings,
  Erase, or Write to NFC) so it cannot mutate owner Keychain or `@AppStorage`.
  Passerby `tapper.html` has no Help button.
- Product HTML is only (1) one passerby file `tapper.html` (identical in `tapper/index.html`,
  repo root, and the app bundle; legacy `card.html` / `get.html` / `/get/` redirect to `/tapper/`, preserving `#d=`) and
  (2) policy pages bundled solely under `RedMed-Xcode/RedMed/`: one `Help.html`
  (Privacy + TOS + Security, in-file anchors) plus `legal-doc.css`. Legacy
  `PrivacyPolicy.html` / `TOS.html` / `security.html` redirect into `Help.html`.
  `HowItWorks.html` redirects into `redmed://main`. Policies CTA to the owner
  app; they do not host owner edit UI. Do not reintroduce repo-root copies of
  the policy HTML. Owner Help menu is Settings + Privacy / TOS / Security only (no
  in-app How It Works / MainInfoView, no Local History row, no local tapper.html
  WebView). Help is on Edit (modal bar) plus 911 / Aid / NFC (top chrome).
  Owner RedMed tab is Edit-only — no bottom Help dock. Scanner Help is
  policies only. NFC Preview (under Scan) / NFC Scan open bundled
  `tapper.html#d=` (`?src=app`, no SOS auto-arm);
  live band taps use `AppConfig.medicalCardBaseURL#d=` (currently
  `https://roooted1776.github.io/tapper/#d=`; custom host after domain cutover).

- **Bracelet tap (physics, not a setting):** `AppConfig.BraceletRF` is the single
  source of truth — intentional tap ~1–2″, walk-by ~6–8″ does not fire, reliable
  coupling dies past ~4″, passive 13.56 MHz HF NFC (not Bluetooth). Product chip
  is **NXP NTAG216** only: ISO 14443A Type 2, NDEF blank unlocked, no factory
  pre-encode, no lock. Do not source NTAG213, MIFARE, LF, or UHF. Laser face is
  **MED ID** only. NFC tab / bracelet copy must use `BraceletRF` helpers, not
  hardcoded inches.
  Tap opens the HTML shell for EMT / helper — passive, no app install.
  **iOS Background Tag Reading** can still open `tapper.html#d=` later — phone
  can be off or locked; a deliberate tap (phone top ~1–2″) still works for owner
  or any passerby — wrist + pocket usually fine; clasp pressed can pop Safari;
  write does not change likelihood. Band stays **passive — no battery** (not
  AirTag / BLE / recurring cell). RedMed cannot disable that OS path; do not
  claim “no background NFC” without the BTR caveat
  (`BraceletRF.backgroundTagReadingSummary`).

**Settings vs automatic (permanent):**
- Haptic feedback + Location toggles (`AppSettings` / `HapticEngine.enabledKey`)
  live on `ConsentGateView`'s "Before you continue" screen, not Help — moved
  there so they're set on the screen the owner already sees every unlock
  instead of a separate Help → Settings trip. No other toggles there, and
  Help no longer has a Settings section at all.
- **Brightness + sound are survival-alarm only (not Settings):**
  arm `BrightnessBoost` + `VolumeBoost` + `LocatorBeacon` only when (1) on-device crash /
  hard-impact detection (`CrashMotionGuard`) fires for **vehicle crash /
  high-speed impact only** (not running or daily activity), (2) owner taps
  **SOS · Locate me** on Find Help, or (3) a **real bracelet NFC tap** opens
  passerby `tapper.html#d=…` (hardware-local SOS on that phone — no server; bare
  `/tapper/` without `#d=` and in-app scanner preview do **not** auto-arm).
  Opening owner Find Help must not force brightness, max volume, or play the
  siren by itself. Do not add Settings off switches for the survival alarm.
- **LocatorBeacon** / **BrightnessBoost** / **VolumeBoost** survival hold may keep sounding /
  max brightness / max system volume in background until the user taps “Stop the alarm” on Aid
  (or Stop SOS alarm on Find Help).

**Vault / privacy (permanent):**
- `VaultHistoryView` Face ID unlock: explicit **Accept** tap first (no auto
  prompt on appear); relock on `.background` only. Do **not**
  lock on `.inactive` — LAContext / system auth sheets put the scene inactive
  and would discard a successful unlock via `authGeneration`.
- Owner app lock is **Face ID / Touch ID with device passcode fallback** before Main (`allowPasscode: true`, `force: true` — every open prompts, never skip via this-process success). Front page is
  `LockEntryPage`: flat cream only (no BrandLogo, no spinner, no hangtime chrome). Path: open →
  Face ID or passcode → Main. No hanging mark / lock watermark / FaceIDFrame clip on
  that shell. Passerby `tapper.html` never has Face ID,
  passcode, login, or any page in front of the card. No glyph, no Help on
  `LockEntryPage`. After cancel / mismatch, **Face** (`FacePage`) with a
  **Proceed** CTA replaces that shell (not a bottom dock) — cream + Proceed,
  no hanging mark. Proceed must cancel any hung / leftover `LAContext` and,
  only when one was actually live, wait a beat (~0.28s wall clock, not just
  the next run loop turn) before `evaluatePolicy` — a same-turn retry after
  userCancel fails immediately with no sheet and no system success animation
  (dead button). A fresh first attempt with nothing in flight skips the wait.
  `FacePage` has no visible "Face" title text — cream + status line + CTA only.
  Never show a "Looking for Face ID" hang line; while evaluating, keep the
  flat cream shell so the system Face ID / passcode sheet is the only UI.
  `BiometricAuth.Outcome.unavailable(UnavailableReason)` (lockout / not
  enrolled / no device passcode / biometry not available) is distinct from
  `.notVerified` (a scan that just didn't match) — retrying `evaluatePolicy`
  never fixes an unavailable state (no sheet even shows), so `FacePage`
  swaps its CTA to **Open Settings** with a reason-specific message instead
  of a **Proceed** that can only ever fail the same way again. Apple locks
  Face ID after **5 unsuccessful matches** until the device passcode succeeds
  (system-wide). `.deviceOwnerAuthentication` should still offer passcode;
  `unavailable(.lockout)` is for `canEvaluatePolicy` failing outright.
  Reuse duration stays **0** (Apple max is 300s — a non-zero value would skip
  the owner gate off a recent device unlock). Edit, Save, NFC
  write, vault unlock, and Erase all re-prompt Face ID every time (`force: true`).
  **Re-lock whenever the owner leaves** so the next open always prompts:
  true `.background` always (purge PHI + `gate = .locked`). Do **not**
  relock on `.inactive` — that swapped live pages for `LockEntryPage`
  cream under Control Center / app-switcher peek. `SnapshotSafeCover`
  is the switcher thumbnail only (`holdSwitcherCover` until re-entry).
  On the next `.active`, relock if still unlocked, drop the cover, Face ID.
  Never relock on `.inactive` while Face ID / a system auth sheet is up
  (`BiometricAuth.isEvaluating` or `isAuthenticating`) — that sheet itself
  puts the scene `.inactive` and must not kill the prompt. VaultHistoryView
  stays `.background`-only. Do
  **not** play `LockOpen.mp4` or `FaceIDFrame.mp4`. Clip never gates Face ID.
  Fresh install unlocks into empty tabs after auth. Owner RedMed tab then
  shows a native **setup funnel** (Fill medical ID → Save → Write the band)
  instead of an empty YOU card. Not an extra page before Face ID. Not on
  passerby tapper.
  Owner pages + passerby tapper: cream fill only (no page BrandLogo). **No hanging
  decorative brand marks** anywhere (no lock watermark, no Aid pane wordmarks, no
  privacy-cover logo) — page BrandWordmark headers on NFC / topic sheets only;
  YOU-card BrandLogo is the medical header mark (tapper `.rm-header`; owner RedMed
  tab uses the same row natively — logo + name + Linked/Not linked — with Edit
  trailing, HTML header hidden in `app-embed` so it is not double-headed).
- `PrivacySnapshotGuard` cover must appear opaque with **no** opacity fade;
  app-switcher snapshots can capture mid-transition PHI. Capture cover **only
  while PHI is in RAM**. Non-capture cover is true **`.background` only** (with
  PHI) — never on `.inactive` (Face ID / LAContext blanks the UI mid-unlock),
  never over the lock / Unlock shell, and **never over the tap card** (NFC
  Preview / Scan / `PasserbyHTMLCardView`). After unlock while still
  sharing, cover again; copy should say screen sharing, not a vague
  “Profile hidden”.
- `HIPAAOfflineVault`: complete file protection + backup exclusion; history
  events are timestamps/kind only (no field values).
- **Apple Health import (optional, owner only):** `HealthKitProfileImport`
  reads birth date and blood type into Edit draft. Read-only. Never writes
  to Health. Never runs on passerby / scanner. Persist still requires Save
  (Face ID on first fill). Do not add Health write, clinical records, or
  background delivery. Currently **parked**
  (`AppConfig.healthKitImportEnabled = false`, no HealthKit key in
  `RedMed.entitlements`) — personal/free Apple Developer teams cannot
  provision the HealthKit capability, so it failed automatic signing the
  same way CoreNFC and Associated Domains did. See
  `docs/healthkit-restore.md`.

**Cold launch:** Do **not** create `CLLocationManager`, start GPS / MapKit /
trauma JSON, or show a Location banner at `@main`. First launch opens a cream
shell (`redmedBg` / `LaunchBackground` on `UILaunchScreen`, no BrandLogo splash) with
**zero Keychain** on the first frame — `OwnerAppLock` always starts locked
(flat cream / `redmedBg`, no BrandLogo) so Main never mounts before Face ID / passcode.
A UserDefaults gate (`ProfileData.storedProfileGateKey`, set on persist /
Keychain presence) hints whether a blob is expected for prefetch / fail-closed
load; SecItem confirms off-main. Auto Face ID on every owner launch **immediately**
(including cold-start `.inactive` — do **not** wait for `.active` or the cream
hangs with no sheet; that wait was the cream hang), but **not** before a
window is key — `tryAutoUnlockIfActive` also gates on `hasKeyWindow` and
retries from `UIWindow.didBecomeKeyNotification` if `onAppear` fires too
early, because an `evaluatePolicy` call made before any window is key has
been observed to never complete (no success, no error) until the 4.5s/5s
watchdogs kill it — a *different* cream hang than the `.active`-wait one,
now seen on every cold launch instead of occasionally. Apple does **not**
timeout `evaluatePolicy` (no LA API for it). RedMed backstops: **4.5s/5s**
only when the scene is `.active` (no sheet — nothing to interrupt);
**60s total** when `.inactive` while evaluating so a slow passcode after a
Face ID miss is not torn down at 4.5s, but a ghost sheet cannot hang
forever; **90s** `BiometricAuth.timedOut` if the callback never fires
(Erase / vault / NFC write) — must stay above the 60s unlock budget.
Apple's passcode sheet has no OS timeout — 60s is ours.
`didAutoPromptThisLock` blocks re-prompt while the Face ID sheet holds
`.inactive`). Prefetch still starts in the same `onAppear` tick and inside the
unlock pipeline (single-flight overlap with Face ID). After cancel / mismatch
the **Face** page (`FacePage`) shows **Proceed**. Fresh install unlocks into empty tabs after
auth; returning owners load Keychain. Owner pages + tapper: cream fill, no page
BrandLogo. Unlock overlaps Keychain decode + AES `#d=` pack + tapper.html
string warm with Face ID and skips unlock animation so tabs paint on the next
frame after biometrics. WKWebView warm starts **only after** `gate = .unlocked`
— warming during Face ID / before the Keychain await steals MainActor and
leaves a blank cream / white hang after auth. Parked Face ID decode unlocks
on the same MainActor turn (no deferred `Task` hop). Do not call Keychain in
`@State` defaults.
Location defaults on (Before you continue) with **no RedMed location gate / banner / Allow popup** — Help must not
call `requestWhenInUseAuthorization`. When-In-Use + GPS start on Find Help only
when Location is enabled (`AppSettings.locationEnabled` + `LocationManager.start`);
iOS may show its system Allow sheet once (cannot auto-accept). Passerby
`tapper.html` must not call `geolocation` until the 911 tab opens. CoreMotion crash
monitoring starts after unlock; do not construct
`CMMotionManager` at `CrashMotionGuard` shared init or during Face ID. `ContentView` lazy
tab mounting mounts RedMed only on cold start (911 / Aid / NFC on first visit,
kept alive after with opacity). Opacity keep-alive **does not** fire
`onDisappear` on tab switch — any side effect that must stop when leaving a
tab (Find Help GPS, seizure timer, etc.) needs an explicit `isVisible`
(or equivalent) hook from `ContentView`, not `onDisappear` alone. Keychain
profile decode runs off-main (prefetched during Face ID) and must **fail closed**
(stay locked) if a stored blob was expected but decode returns false — never
unlock into an empty profile that can overwrite Keychain. Empty Keychain after
auth (fresh install) may open empty Main. Vault prep runs off the main thread
after first paint. CoreMotion crash monitoring starts after unlock — not during
Face ID. `UILaunchScreen` must use `LaunchBackground` (same as `redmedBg`,
including dark appearance) — never an empty dict (system black).
`PrivacySnapshotGuard` must not cover until the scene has been `.active`
once (cold start begins `.inactive` and would otherwise blank the first
paint); store content as a `@ViewBuilder` closure, do not eagerly evaluate
it in `init`.

**Xcode project:** `project.pbxproj` object IDs must stay unique. Duplicate
`AAAA`/`AABB` IDs silently drop sources from the target (seen when Haptic /
Brightness collided with HIPAA vault files).
`IPHONEOS_DEPLOYMENT_TARGET` must be a literal `17.0` in **all four** build
configs — both project-level and both **target-level** (`PBXNativeTarget
"RedMed"`). Target-level settings override project-level, so a target-level
`$(RECOMMENDED_IPHONEOS_DEPLOYMENT_TARGET)` silently drops the app to whatever
the installed Xcode recommends (15.0 on Xcode 26.6) and breaks the build on
iOS 16+ API — `UnevenRoundedRectangle` in `ContentView`, `Locale.region` in
`EmergencyNumber`. Never use `$(RECOMMENDED_…)` here; it re-breaks on every
runner Xcode bump.

**Passerby SW:** shell fetch is **cache-first** (multi-key: `/tapper/`,
`index.html`, etc.) for **almost-instant** EMT / helper open when Cache
Storage has any shell copy — never wait on network in that case. Background
`cache: 'reload'` refresh updates the bucket while online. First visit (empty
cache) waits on network, then stores under every shell key. On activate,
delete every prior `CACHE` name so deploys clear stale decrypt/layout. Bump
`CACHE` (`redmed-tapper-vN`) in lockstep across `sw.js`, `tapper/sw.js`, and the
bundled copy on every SW / decrypt deploy. Register the SW ASAP in `tapper.html`
(not on `window.load`). Legacy zlib inflate is bounded (64 KiB) in Swift +
streaming bound in `tapper.html`. Passerby HTML **arms local SOS only on a real
bracelet NFC open with `#d=`** (hardware-local on that phone; no server). Bare
`/tapper/` and in-app preview do not auto-arm. Bare `/tapper/` without `#d=`
shows a **No patient** empty state (not a blank YOU chart); 911 / Aid remain.
Explicit Stop / SOS toggle and DeviceMotion crash share that on-device alarm. iOS may need a gesture to unmute
AudioContext / grant motion. Native still owns system volume / brightness boost.

**Repo hygiene:** `main` is the only long-lived branch. After merges, delete
feature branches on the remote; do not leave parallel “brainchild” branches.
Keep the tree product-only: `RedMed-Xcode/`, passerby `tapper*` / legacy
`get*` redirects / `sw.js` / `card.html` / `_headers`, `assets/` + root logo,
`docs/` product notes,
`scripts/`, `.github/`, and agent docs. Do not re-add staging `uploads/`,
debug `screenshots/`, dead `support.js` / `ios-frame.jsx`, or UK
`compliance/` paper packs.

**Debugger note:** `Thread 1: signal SIGTERM` at `mach_msg2_trap` is usually
Xcode Stop / Simulator killing the process — not a Swift crash. Look for
`EXC_BAD_ACCESS` / fatalError / assertion if it is a real fault.

**Passerby web shell IS runnable on Linux / Cursor Cloud.** Only the native iOS app can't run
here — the static passerby shell (`tapper.html` / `tapper/index.html`, `get*`/`card.html`
redirects, `sw.js`, brand PNGs) can be served and smoke-tested on this Linux VM with the
pre-installed `python3` (no npm, no wrangler, no build step):

```
python3 -m http.server 8787 --bind 127.0.0.1   # or ./scripts/deploy-pages.sh (same server)
BASE=http://127.0.0.1:8787 ./scripts/smoke-pages.sh   # page-load + redirect smoke (11 checks)
```

Use `127.0.0.1` (not a LAN IP) so `#d=` decode works. The medical card renders from `#d=` with
**no server**: `decodeProfile` in `tapper.html` accepts a base64url payload whose first byte is
`{`/`[` as **plaintext JSON** (AES-GCM `0x02` and zlib `0x01` are the other two paths), so a quick
`#d=<base64url(JSON)>` (fields: `name,dob,blood,donor,updated,allergies,meds,conditions,contacts`)
renders a full RedMed · 911 · Aid card in Chrome without the owner app or any real encryption. This
is the fastest way to eyeball tapper/SW/redirect changes here. Cloudflare `_headers` / `_redirects`
are **not** honored by `http.server` (Pages-only), so the legacy `/get.html` etc. serve their
in-file meta-refresh HTML rather than a 30x here. Note SOS auto-arm still needs a real `#d=` band
tap on hardware, so the survival alarm is not exercised by this local render.

**Consequence for cloud agents:** the update script is intentionally a no-op (both `python3` and
`node` are already in the base image; the iOS app has no installable deps). Code review and static
edits to the `.swift` files are possible, but do not attempt to build/run/test the iOS app here.
Any actual iOS build, run, or manual testing must happen on macOS + Xcode:

```
./scripts/run.sh                       # fastest: boot iOS 27.0 sim, incremental build, launch
open RedMed-Xcode/RedMed.xcodeproj   # then Run (Cmd+R) against an iOS 27.0 Simulator
# or, headless:
xcodebuild -project RedMed-Xcode/RedMed.xcodeproj -scheme RedMed \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' build
```

`scripts/run.sh` keeps derived data in `.derivedData/`, skips rebuild when Swift/resources
are unchanged, and skips reinstall when the built app is unchanged. Defaults to iOS 27.0;
override with `SIM="iPhone 17 Pro" SIM_OS=27.0 ./scripts/run.sh`. Location is pre-granted on
the simulator (Apple Park coords); override with `LOCATION="40.7128,-74.0060" ./scripts/run.sh`.

**Compile checking without a Mac:** `.github/workflows/ios-build.yml` builds the app on a
GitHub `macos-latest` runner for every push to `main` and every PR that touches
`RedMed-Xcode/**`, so Swift compile errors surface in CI even when the change was authored
somewhere that cannot build. It only compiles — it does not run the app, the Simulator UI, NFC,
or Face ID, and it is not a substitute for testing behaviour on a device. Note the path filter:
macOS runner minutes bill at 10x on private repos, so doc/HTML-only changes deliberately skip it.

On a **physical iPhone**, iOS requires a one-time Allow tap — that cannot be bypassed from code.

NFC write and Face ID flows only work on a physical iPhone, not the Simulator.
