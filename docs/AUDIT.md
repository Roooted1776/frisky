# RedMed codebase audit

**Repo:** [Roooted1776/frisky](https://github.com/Roooted1776/frisky)  
**Default branch:** `main` @ `90d4b0b` (“Skip WebKit pre-warm on the NFC tab.”)  
**Date:** 2026-08-31  
**Follow-up:** same day. In-repo cleanup of findings that did not need a new host or paid Apple team.  
**Method:** static read of Swift / HTML / CI / docs on this tree, plus live HTTP probes. No iOS build (this environment is Linux; Xcode is macOS-only). No secrets were found that needed rotation.

This is RedMed: a native iOS medical ID plus a static passerby HTML shell. There is no application server and no profile API. Confirmed from `AppConfig.swift`, `ProfileData.swift`, `tapper/index.html`, and the absence of any backend package.

---

## Follow-up (landed)

Code is the Face ID story: `OwnerAppLock` on owner open/return, Save / Erase prompt, Edit open does not. Docs, Help 4.2, Info.plist, and support now say that. Crash motion keeps running across relock. Location toggle is honored on Agree. Overpass is named in Help / Satellite / Info.plist; `_headers` `connect-src` allows `https://overpass-api.de`. `KeychainStore.exists` fails closed. Launch screen is cream-only. README, PRODUCTION, APP-STORE, domain, SECURITY match. pages-deploy fails when github.io smoke fails. Actions pinned to SHAs. Privacy/support URLs no longer point at jsDelivr `@main` of `redmed-privacy`.

**Still open (needs Max, not git):**

1. Stand up `Roooted1776.github.io` (or CF Pages + custom domain) so `/tapper/` returns RedMed · 911 · Aid. Do not flip `AppConfig.medicalCardBaseURL` onto another 404.
2. Restore push/PR iOS CI after billing. Add `#d=` Swift/JS round-trip tests.
3. Leave NFC / HealthKit / Associated Domains parked until a paid Apple team can provision them.

---

## Executive summary

No committed secrets, no XSS in profile render, no autodial, no scanner write into owner Keychain. The serious remaining problem is operational: **the URL written onto bands is 404.**

**Highest-severity facts:**

1. **The URL written onto bands is 404.** `AppConfig.medicalCardBaseURL` is `https://roooted1776.github.io/tapper/`. Live GET is GitHub’s 404 page. `Roooted1776/Roooted1776.github.io` does not exist. `https://redmed.pages.dev/tapper/` is also 404. NFC write is parked, so this build cannot mint new dead bands — but any earlier write to that host is a dead tap. pages-deploy now **fails** that smoke (no longer warn-only).
2. **iOS CI does not gate merges.** `.github/workflows/ios-build.yml` is `workflow_dispatch` only. There are zero XCTest / JS unit tests. Encode/decode of `#d=` is duplicated in Swift and JS with no round-trip vectors.
3. **Passerby hospital search sends GPS to `overpass-api.de`.** Native uses MapKit. Help 4.2 names both. Residual: the public OSM API still sees a rescuer’s coordinates on a band tap — disclosed, not removed.
4. **`OwnerAppLock` is live** and Face-IDs every owner open / return. That is the product (commit `b2a38cf`). Docs now match. Crash motion no longer stops on relock.

No critical in-repo security hole was safe and unambiguous to patch as a remote exploit. Remaining work is the dead host and tests.

---

## 1. What the project is

RedMed is a **local-only medical ID**:

| Surface | What it is | Data |
|---------|------------|------|
| Owner iOS app (`RedMed-Xcode/`) | SwiftUI tabs: RedMed · 911 · Aid · NFC | Profile in Keychain. Notes stay on-device. |
| Passerby shell (`tapper/index.html`) | Static HTML: RedMed · 911 · Aid. No Edit, no NFC, no Face ID | Snapshot in URL `#d=` only |
| Band | Passive NXP NTAG216, NDEF URI | `medicalCardBaseURL#d=<base64url>` |

There is no login, no profile backend, no analytics SDK. `docs/DO-NOT.md` and `Help.html` correctly refuse “HIPAA certified” and “encrypted band” marketing.

Repo name is `frisky`. GitHub visibility is **public**. Empty root `README.md` was filled in the follow-up. No license.

### Tree (what actually matters)

```
frisky/
├── RedMed-Xcode/RedMed/     42 Swift files, one app target, flat folder
├── tapper/index.html        canonical passerby shell
├── tapper.html              #d=-preserving redirect to /tapper/
├── sw.js, tapper/sw.js, RedMed-Xcode/RedMed/sw.js   must stay byte-identical
├── card.html, get.html, get/, index.html            legacy redirects
├── _headers, _redirects, wrangler.toml              Cloudflare Pages only
├── scripts/                 run, deploy, smoke, publish-github-io, sync-tapper
├── docs/                    product notes (several stale vs code)
└── .github/workflows/       ios-build.yml, pages-deploy.yml
```

Xcode copies `tapper/index.html` → bundle `tapper.html` at build (`project.pbxproj` “Bundle passerby tapper”). `scripts/sync-tapper.sh` enforces one shell + SW lockstep (`redmed-tapper-v136` at audit time).

---

## 2. How it is meant to run / deploy

**Owner app (macOS + Xcode only):**

```
./scripts/run.sh
# or
xcodebuild -project RedMed-Xcode/RedMed.xcodeproj -scheme RedMed \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' build
```

Deployment target is literal `17.0` in all four `pbxproj` configs. `RedMed.entitlements` is an empty dict. `AppConfig.nfcHardwareEnabled = false`, `healthKitImportEnabled = false`, `appStoreURL = nil`. NFC tab stays visible; Write/Scan are pack-only preview.

**Passerby shell (this Linux VM can serve it):**

```
python3 -m http.server 8787 --bind 127.0.0.1
BASE=http://127.0.0.1:8787 ./scripts/smoke-pages.sh
```

`#d=` decrypt needs a secure context (HTTPS or localhost). LAN HTTP shows a warning (`tapper/index.html` `secureCryptoOk()`).

**Intended live hosts** (`docs/domain.md`, `AppConfig.medicalCardBaseURL`):

| Host | Claimed role | Probed 2026-08-31 |
|------|----------------|-------------------|
| `https://roooted1776.github.io/tapper/` | Live band write base | **HTTP 404** |
| `https://redmed.pages.dev/tapper/` | Optional CF Pages | **HTTP 404** |
| Custom domain | `medicalCardCustomDomainTBD = nil` | not set |

`scripts/publish-github-io.sh` copies the shell into a checkout of `Roooted1776.github.io`. That repository **does not exist** (`gh repo view` cannot resolve it). `.github/workflows/pages-deploy.yml` on `main` skips Cloudflare when secrets are missing and **warns** (does not fail) when github.io smoke fails. Recent `Pages tapper deploy` runs on `main` are green in 7–11s.

---

## Findings

Severity is impact × how sure the evidence is. “By design” items are still listed when they are a real threat-model fact or they contradict what the app tells the user.

### Critical

None found. No private keys, tokens, or `.pem` in the tree. CI Cloudflare credentials are `${{ secrets.* }}`. `.cursor/mcp.json` uses `${env:CURSOR_GITHUB_TOKEN}`. Profile XSS is `textContent` / `esc()`. `tel:` is tap-only.

### High

#### H1. Band write base is a dead host

**Evidence**

- `AppConfig.medicalCardBaseURL` returns `https://roooted1776.github.io/tapper/` when `medicalCardCustomDomainTBD` is nil (`AppConfig.swift` 24–33).
- `OwnerBandURI.isValidWriteURL` requires that exact prefix (`AppConfig.swift` 65–67).
- Live: `curl -sI https://roooted1776.github.io/tapper/` → `HTTP/2 404` (`server: GitHub.com`). Same for site root.
- `gh repo view Roooted1776/Roooted1776.github.io` → repository does not exist.
- `https://redmed.pages.dev/tapper/` → 404.
- `pages-deploy.yml` 90–103: github.io smoke failure is `::warning::` then exit 0.
- `docs/APP-STORE.md` 11 already admitted `roooted1776.github.io/privacy/` 404s and “user Pages unpublished.”

**Why it matters**

A passerby tap opens whatever host is on the chip. If that host 404s, `#d=` is sitting in the fragment with no shell to decrypt it. NFC is parked (`nfcHardwareEnabled = false`), so this build will not mint new bands — but the documented “live interim” is fiction, and CI will not turn red when it stays fiction.

**Do not fix by flipping `AppConfig` to a placeholder.** Publish a real HTTPS `/tapper/` first (`docs/domain.md` cutover), then point the flag.

#### H2. No merge gate for Swift; no encode/decode tests

**Evidence**

- `.github/workflows/ios-build.yml` 3–12: automatic triggers removed for billing; `on: workflow_dispatch` only.
- `gh run list`: recent `main` runs are **Pages tapper deploy** only. No iOS build on the last ten pushes.
- Zero `*Test*.swift`, zero `XCTest`, no test target in `project.pbxproj`, no `Package.swift`, no JS test runner.
- `ProfileNFCCodec` (Swift) and `decodeProfile()` (`tapper/index.html` ~2185) share `KEY_LABEL = "RedMed-NFC-AES-GCM-v1"`, `0x02` AES-GCM, `0x01` zlib, two compact-array layouts, and legacy JSON — by comment only.
- What *does* run: `scripts/sync-tapper.sh` (tabs + `cmp` of three `sw.js` copies) and `scripts/smoke-pages.sh` (11 HTTP needles + no-auth string scan). Neither decrypts a `#d=`.

**Why it matters**

A Swift compile break or a Swift/JS schema drift (pregnant / deaf flags, compact index swap) can land on `main` unnoticed. `AGENTS.md` still says ios-build runs on `RedMed-Xcode/**` pushes; `MAX.md` line 33 is the accurate note (dispatch only). Branch protection was not readable (`403` on the protection API); repo `rulesets` is `[]`. From files alone, merges are not gated by a compile.

#### H3. Passerby hospital search uploads GPS to a third party; legal copy says Apple Maps

**Evidence**

- Native: `NearbyHospitals.swift` uses `MKLocalSearch` / MapKit (Apple).
- Passerby: `tapper/index.html` 2658–2665 builds an Overpass query with `lat,lon` and `fetch('https://overpass-api.de/api/interpreter?data=' + …)`.
- Meta CSP allows it: `connect-src 'self' https://overpass-api.de` (`tapper/index.html` 13).
- User-facing copy does not:
  - `Help.html` 92, 99: “Find Nearby Hospitals … asks Apple Maps”
  - `AppConfig.Satellite.localOnlyLine` (232–233): same Apple Maps claim
  - `Info.plist` `NSLocationWhenInUseUsageDescription` (46–47): Apple Maps
  - `TopicDetailView.swift` 221: Apple Maps

**Why it matters**

Consent version 4.2 (`ConsentGateView` / `Help.html`) names Apple Maps (owner app) and OpenStreetMap Overpass (band tap). A helper on the 911/Aid shell who taps hospitals still sends coordinates to `overpass-api.de` (public OSM API, not Apple, not RedMed). Disclosed, not removed.

**Follow-up:** Help 4.2 / Satellite / Info.plist name Apple Maps (owner app) and OpenStreetMap Overpass (band tap). `_headers` `connect-src` includes `https://overpass-api.de`. The third-party GPS send is unchanged; the disclosure hole is closed.

#### H4. App-open Face ID is mounted; crash detection dies when the app relocks

**Evidence**

```37:41:RedMed-Xcode/RedMed/RedMedApp.swift
private struct LaunchRoot: View {
    var body: some View {
        OwnerAppLock {
            ConsentGateView { Main() }
        }
    }
}
```

- `OwnerAppLock.swift` 8–11, 81–139, 175–178: Face ID on every cold open and after leave; `relock` calls `CrashMotionGuard.shared.stopMonitoring()` (line 138); 250 ms `.inactive` timer can relock from app switcher.
- `CrashMotionGuard.swift` 74–76: stop is CoreMotion only; an already-armed siren keeps going.
- `AGENTS.md` / `MAX.md`: “No cream lock in front of Main. Face ID is Edit / Save / Erase only. Not app launch.”
- `Help.html` 80, 142, 155: same Edit/Save/Erase story; “app launch … do not prompt.”
- `PRODUCTION.md` 19, 29: documents app-open Face ID as “green,” and cites a Before-you-continue **Face ID toggle that does not exist** (`ConsentGateView` only has Haptic + Location).
- Edit open is **not** gated: `RedMedView.requestEdit()` 119–122. Save is: `EditProfileView.save()` 673–675. Erase is: `HelpMenuView.requestErase()` ~421.

**Why it matters**

This is stricter privacy for the owner phone and worse emergency access on that same phone. A helper who opens the **app** (not the band) hits Face ID. Crash / high-impact monitoring only runs while the owner session is unlocked. The band tap path stays ungated — if the band host is up (see H1).

This is a product fork, not a one-line bug. Do not “fix” it in passing. Pick one story and make `AGENTS.md`, `MAX.md`, `PRODUCTION.md`, `Help.html`, `Info.plist` `NSFaceIDUsageDescription`, and `support/index.html` match the code.

**Follow-up:** kept `OwnerAppLock` (shipped in `b2a38cf`). Docs / Help 4.2 / Info.plist / support match: unlock + Save + Erase; not Edit open. Relock no longer calls `stopMonitoring()`.

---

### Medium

#### M1. Consent “Location” toggle is overwritten on Agree

`ConsentGateView.enterApp()` (159–175) sets `locationEnabled = true` and calls `LocationAccessSuggester.requestWhenInUseIfNeeded()` even if the user flipped Location off. Commit `ab8bad2` (“request location on Agree”) made this explicit.

`AGENTS.md` says When-In-Use starts on Find Help only and Help must not call `requestWhenInUseAuthorization`. Help.html 91 still says the first system Allow sheet is when Find Help needs GPS.

The toggle is not a real choice. Either honor it or remove it.

**Follow-up:** `enterApp()` no longer forces `locationEnabled = true`. `requestWhenInUseIfNeeded()` already no-ops when Location is off.

#### M2. `#d=` AES-GCM uses a public client key (integrity, not identity)

`ProfileNFCCodec.swift` 39–42, 54–55, 88: `keyLabel = "RedMed-NFC-AES-GCM-v1"` → SHA-256 → AES-256-GCM. Same label in `tapper/index.html` 1784. CryptoKit `seal` uses a random 12-byte nonce + 16-byte tag (`encodePayload` 258–271). Tamper-without-reseal fails `AES.GCM.open`.

Anyone who loads `tapper.html` can forge a valid `#d=`. `AppConfig.OwnerBandURI.packingHonestySummary` and `Help.html` 85 say this out loud. Trust boundary is **physical band + intentional tap**, not cryptography. Fine for EMS-with-no-account. Do not market the chip as confidential (`docs/DO-NOT.md`).

Legacy decode still accepts plaintext JSON and zlib (`decodePayload` 275–303). Smoke tests use plaintext `#d=` on purpose. A copied URL is as good as a tap.

#### M3. Keychain is device-unlocked, not biometry-bound

`KeychainStore.swift` 7–12, 65–66: `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`, no `kSecAttrAccessControl`, `kSecAttrSynchronizable = false`. Face ID is UI-only (`BiometricAuth`). `load` can interactively migrate one leftover `biometryCurrentSet` row (`KeychainStore` 162–179; `ProfileData.restoreOnLaunch` 353–355).

An unlocked iPhone + a process that can call SecItem can read the blob. That is the stated contract. Device wipe / no backup → profile gone (band snapshot is the durability story — blocked by H1 today).

`persist()` refuses empty RAM over a stored blob (`ProfileData` 237–242). Erase deletes Keychain first (481–490). `snapshot()` / `persists == false` keeps scanner mutations off owner Keychain (191–209). `NFCBandManager.writeBand` returns immediately when `isScannerSession` (51–52). Scan applies to a cover payload, not `ProfileData.apply` on the owner object.

#### M4. App Store / support privacy URL is jsDelivr `@main` of a second repo

`AppConfig.supportURL` / `privacyPolicyURL` (45–46), `privacy/index.html`, `docs/APP-STORE.md` 6–8: `https://cdn.jsdelivr.net/gh/Roooted1776/redmed-privacy@main/…`.

`Roooted1776/redmed-privacy` is public. jsDelivr `@main` tracks whatever lands on that default branch, cached for days. In-app Help uses bundled `Help.html` (not these URLs). Connect’s privacy URL, if you submit, is a CDN of a different git tree. Compromise or a sloppy push there changes the listed policy without a frisky commit.

Those two `AppConfig` strings are unused in Swift (grep). Dead config pointing at the CDN.

**Follow-up:** both strings now point at this repo. `privacy/index.html` no longer meta-refreshes to `redmed-privacy`. Connect URL stays TBD until a live host.

#### M5. `pages-deploy.yml` fail-open + floating action tags

- Missing `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID` → skip deploy, workflow success (63–80).
- github.io smoke warn-only (90–103) — this is why H1 is green on `main`.
- `actions/checkout@v4` / `@v5`, `cloudflare/wrangler-action@v3` — major tags, not SHAs.

**Follow-up:** github.io smoke **fails** the job. Actions pinned to SHAs (`checkout` v4.2.2 / v5.0.0, `wrangler-action` v3). Cloudflare skip on missing secrets is unchanged (optional host).

No SPM / CocoaPods / npm lockfile in this repo, so there is no app dependency CVE surface. Risk is Actions supply chain and the dead host.

#### M6. Crash-motion false positives are possible; autodial is not

`CrashMotionGuard` thresholds (`CrashMotionThresholds`): 16 g peak, 24 g during “busy,” jerk ≥ 140 g/s, freefall path. Comments exclude running / daily motion. No Apple Crash Detection fusion. Arms brightness + volume + siren only (`applyArm` 105–119). Does not call `tel:`.

`EmergencyView` 14–18 / 150–163 and `SeizureTimerStrip` 122: Call is an explicit button. `PublicEmergencyAid.dial()` opens `EmergencyNumber.dialURL`. SOS (`FindHelpSOSButton` 98–116) only `armSOS()` / `disarm()`.

Tapper SOS auto-arm (`shouldAutoArm`, ~3472): requires `#d=` that decoded, `paintedFromBand`, and not `?src=app`. Bare `/tapper/` and in-app preview do not arm.

Residual: a hard drop of the phone can still siren. That is documented risk, not a logic hole.

---

### Low

#### L1. Info.plist / support copy vs actual Face ID and NFC

**Follow-up:** Info.plist Face ID string is unlock / save / erase. Support no longer claims NFC write or Edit open prompt. Launch screen BrandLogo removed (cream `LaunchBackground` only).

#### L2. JS field caps vs Swift encode

`tapper/index.html` 1777–1780: `MAX_STR = 200`, `MAX_LIST = 40`. Swift `compactArray` / `encodePayload` has no field caps; only `maxEncodedLength = 8192` and NTAG216 ~850 byte warning (`capacityNote` 245–253). Over-long owner fields can pack on-device and truncate in the passerby card.

#### L3. `KeychainStore.exists` default branch is a tautology

```239:251:RedMed-Xcode/RedMed/KeychainStore.swift
        switch status {
        case errSecSuccess, errSecInteractionNotAllowed, errSecAuthFailed:
            return true
        case errSecItemNotFound:
            // ...
        default:
            return status != errSecItemNotFound
        }
```

`default` is only reached when status is not `errSecItemNotFound`, so it always returns `true`. An unexpected SecItem error hides the empty-profile funnel (`prefersLockOnLaunch` / `hasStoredProfile()`). Fail closed (return `false`) would match “don’t know.”

**Follow-up:** `default` returns `false`.

#### L4. Empty README, stub SECURITY.md, public repo named frisky

**Follow-up:** README filled. `docs/SECURITY.md` points at Help + advisory path. `docs/PRODUCTION.md` rewritten (no fake Face ID toggle; github.io listed as 404). `docs/cold-start-audit.md` matches the lock path; AGENTS now does too.

#### L5. AASA team ID is public; Associated Domains entitlement is empty

`.well-known/apple-app-site-association` and root `apple-app-site-association`: `appID` `33F9FQ4VBU.com.redmed.app`. Expected for Universal Links. Entitlement is not in `RedMed.entitlements` (parked). No secret.

#### L6. `pbxproj` sequential `AAAA`/`AABB` IDs

`AGENTS.md` already warns: duplicate IDs silently drop sources. Current IDs are unique. Next file add without a unique hex will re-break the target. Process risk, not a current collision.

#### L7. Simulator biometrics auto-succeed

`BiometricAuth.authenticate` 95–104: `#if targetEnvironment(simulator)` → `.success` same-turn. Device path still evaluates. Dev-only.

#### L8. `force:` is a no-op

`BiometricAuth.authenticate` 89: `_ = force`. Call sites pass `force: true` for documentation. Reuse duration is 0 (296–298). Not a skip flag.

---

### Info (working controls — do not regress)

| Control | Evidence |
|---------|----------|
| No `print()` of PHI | Swift `print(` grep empty; `os.Logger` in `RedMedSignpost` is lock diagnostics, `.public` strings like `generation=` |
| Vault history is kind + timestamp | `VaultHistoryStore.swift` header; no field values |
| Notes stay off the chip | `NFCChipProfile` has no `notes`; `PersistedProfile.notes` is Keychain-only |
| Snapshot / capture cover | `PrivacySnapshotGuard` — `.background` + capture only, never tap card, no opacity fade |
| Secure pasteboard | `SecurePasteboard` local-only + expiry; cleared on relock |
| ATS | `NSAllowsArbitraryLoads` / local networking **false** |
| WKWebView | No `WKScriptMessageHandler`. Navigation: file/about allow; http(s)/tel/mailto/redmed open outside or cancel; default deny (`PasserbyHTMLCardView` 827–856) |
| Script embed | `embedProfileJSON` escapes `<` to `\u003c` (220–226) |
| SW cache | `sw.js` only caches HTML containing `data-tab="medical"`; `#d=` is not an HTTP cache key; activate deletes old `CACHE` names |
| Zlib bound | Swift 64 KiB destination (`maxInflatedBytes`); JS `MAX_INFLATED = 65536` |
| Scanner isolation | `isScannerSession` hides NFC / Edit; Help owner tools gated; `persist()` no-ops when `persists == false` |
| Lazy tabs + GPS | `EmergencyView` takes `isVisible`; GPS start/stop on that flag (`79–88`), not `onDisappear` alone |
| NFC preview cover | `fullScreenCover(item:)` after pack (`NFCView` / `NFCBandManager.ScannedCardSession`) |
| Linked flag | `setBraceletPaired(true)` requires `nfcHardwareEnabled` (`ProfileData` 458–459); simulate never sets Linked |
| Consent / Help | Bundled `Help.html` + `legal-doc.css` only; no repo-root policy copies |
| `IPHONEOS_DEPLOYMENT_TARGET` | Literal `17.0` × 4 |
| No app dependencies | No SPM / CocoaPods / npm |

---

## 3. Architecture / maintainability

Single target, 42 Swift files, no modules. Boundaries are conventions (`isScannerSession`, `persists`, `AppConfig` kill switches), not packages. That is fine at this size and easy to break with one missed `guard`.

**Live vs dead**

| Symbol | Status |
|--------|--------|
| `OwnerAppLock` | Live — wraps launch |
| `FacePage`, `LockEntryPage`, `VaultHistoryView`, `MainInfoView` | Deleted (comments only) |
| `VaultHistoryStore` | Live, no UI |
| `HealthKitProfileImport` | Stub (`isAvailable` false) |
| `card.html` / `get.html` / `get/` | Redirects to `/tapper/` |
| `AppConfig.supportURL` / `privacyPolicyURL` | Unused in Swift |

**Config** is compile-time `AppConfig` + a few `UserDefaults` / `@AppStorage` keys (`consent`, haptics, location, stored-profile gate). No `.env`.

**Doc drift (authoritative tension)**

| Topic | Code | AGENTS / MAX | PRODUCTION / Help |
|-------|------|--------------|-------------------|
| App-open Face ID | Yes (`OwnerAppLock`) | Yes (follow-up) | Yes |
| Face ID on Edit open | No | No | No |
| Face ID toggle on consent | Does not exist | — | PRODUCTION no longer claims it |
| Location prompt | Agree if Location on | Agree if on; GPS on Find Help | Help 4.2 |
| iOS CI on push | No | Dispatch only | — |
| github.io live | 404 | Claimed URL, noted 404 | domain.md 404 |
| Repo visibility | Public | — | APP-STORE.md public |

Treat **code** as what ships. Follow-up aligned AGENTS to the lock Max shipped (`b2a38cf`).

---

## 4. Operational risk

| Risk | Detail |
|------|--------|
| Band host | H1. No `Roooted1776.github.io`. Manual `publish-github-io.sh` has nowhere to copy. |
| pages.dev | Optional; secrets missing; 404 today. `_headers` now allows Overpass `connect-src`. |
| SW stale cache | Mitigated by `CACHE` bump + activate delete. Drift caught by `sync-tapper.sh` if someone runs it. |
| Host cutover | Old bands keep the old host forever. `docs/domain.md` says keep old hosts up. Today the old host is already down. |
| Backups | Keychain + vault excluded from backup by design. Wipe = empty app. Band is the backup — only if H1 is fixed and the chip was actually written. |
| Erase | Cannot wipe a physical band (`ProfileData.eraseAllLocalData` comment 479). |
| Rate limits | No RedMed API. Overpass can 429 / 15s timeout (`tapper/index.html` 2647–2649). Native MapKit has a 15s watchdog (`NearbyHospitals.swift` 66–71). |
| Logging | No PHI logs found. Location is displayed, not logged. |
| Background audio | `UIBackgroundModes: audio` for the survival siren. |
| Cold start | `docs/cold-start-audit.md` covers Face ID window / key-window races. Matches current lock path. |
| Public repo | Source + public AES label + team ID + personal `MAX.md` handles are world-readable. AES label was already public-by-design. |

HIPAA: `Help.html` 60–65 is careful (operator-aligned, not certified). The type name `HIPAAOfflineVault` is a file-protection helper, not a compliance program.

---

## 5. Tests and CI (detail)

| Check | When | Fail closed? | What it proves |
|-------|------|--------------|----------------|
| `scripts/sync-tapper.sh` | pages-deploy job + local | Yes | One shell; three `sw.js` identical |
| `scripts/smoke-pages.sh` | pages-deploy (github.io **fail-closed**; pages.dev fail if CF ran) | Mixed | Tabs exist; no Face ID strings in tapper; brand PNGs |
| `ios-build.yml` | Manual | N/A (not on PR) | Simulator compile, unsigned |
| XCTest / codec vectors | Missing | — | — |

`smoke-pages.sh` against `https://roooted1776.github.io` on 2026-08-31: static no-auth scan passed (local file); **all 11 HTTP checks 404**.

---

## Recommended next actions

Still blocked on Max / billing / Apple, not this follow-up.

1. **Stand up the passerby host.** Create `Roooted1776.github.io` (or connect Pages `redmed` and put HTTPS in front of a real domain). Run `scripts/publish-github-io.sh` / CF deploy. Smoke until `/tapper/` returns RedMed · 911 · Aid. Only then write bands. Do not change `AppConfig.medicalCardBaseURL` to a host that is still 404. pages-deploy will stay red until this is done.
2. **Restore iOS CI on `RedMed-Xcode/**` after billing.** Add XCTest (or a tiny Swift/JS shared vector file) for: AES `#d=` round-trip, legacy zlib/JSON, compact-array current vs legacy detection, `OwnerBandURI.isValidWriteURL`, empty-`persist()` guard.
3. Leave NFC / HealthKit / Associated Domains parked until a paid Apple team can provision them. Do not claim live Write.

## Code changes in the follow-up

Swift: honor Location toggle; `KeychainStore.exists` fail-closed; crash monitor stays up across relock. Copy: Help 4.2, Info.plist, support, launch screen. Docs: AGENTS / MAX / PRODUCTION / domain / APP-STORE / README / SECURITY. CI: fail-closed github.io smoke; pin Actions SHAs; Overpass in `_headers`.

---

## Files read (primary)

`AppConfig.swift`, `RedMedApp.swift`, `OwnerAppLock.swift`, `BiometricAuth.swift`, `KeychainStore.swift`, `ProfileData.swift`, `ProfileNFCCodec.swift`, `ContentView.swift`, `RedMedView.swift`, `EditProfileView.swift`, `ConsentGateView.swift`, `CrashMotionGuard.swift`, `EmergencyView.swift`, `EmergencyNumber.swift`, `NFCBandManager.swift`, `NFCReader.swift`, `NFCWriter.swift`, `PasserbyHTMLCardView.swift`, `PrivacySnapshotGuard.swift`, `HelpMenuView.swift`, `NearbyHospitals.swift`, `LocationAccessSuggester.swift`, `HIPAAOfflineVault.swift`, `VaultHistoryStore.swift`, `SecurePasteboard.swift`, `RedMedSignpost.swift`, `Info.plist`, `RedMed.entitlements`, `PrivacyInfo.xcprivacy`, `Help.html`, `tapper/index.html`, `sw.js`, `_headers`, `_redirects`, `wrangler.toml`, `.github/workflows/*`, `scripts/*`, `docs/PRODUCTION.md`, `docs/domain.md`, `docs/APP-STORE.md`, `docs/SECURITY.md`, `docs/STRUCTURE.md`, `AGENTS.md`, `MAX.md`, `support/index.html`, `privacy/index.html`, AASA files.

Probes: `gh repo view` (frisky public; `Roooted1776.github.io` missing; `redmed-privacy` public), `gh run list`, `curl` github.io / pages.dev / jsDelivr, `scripts/smoke-pages.sh` against github.io.
