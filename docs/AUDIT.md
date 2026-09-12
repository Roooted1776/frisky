# RedMed codebase audit

**Repo:** [Roooted1776/frisky](https://github.com/Roooted1776/frisky)  
**Checked:** 2026-09-08 against `main` (post Document.html + entitlements conflict fix)  
**Method:** static read of Swift / HTML / CI / docs on this tree, plus live HTTP probes. No iOS Simulator here (Linux VM). No secrets found that needed rotation.

RedMed is a native iOS medical ID plus a static passerby HTML shell. There is no application server and no profile API.

---

## Current posture

No committed secrets, no XSS in profile render (`textContent` / `esc()`), no autodial on SOS auto-arm, no scanner write into owner Keychain. **The band write host is live.** In-repo CoreNFC is parked (flag + entitlement + usage string); restore via `docs/NFC-RESTORE.md`. Portal Tag Reading + proven Write on blank NTAG216 remain. Storefront / dept “write from the app” stays off until that checklist is green — blank chips + Share honesty only.

| Area | Status |
|------|--------|
| Passerby host | `https://roooted1776.github.io/tapper/` live (HTTP 200, smoke-pages green) |
| CoreNFC | In-repo parked (`nfcHardwareEnabled = false`, no TAG entitlement, no `NFCReaderUsageDescription`). Restore via `docs/NFC-RESTORE.md`. Portal Tag Reading on `com.redmed.app` still required for device Write |
| Associated Domains | Parked (`associatedDomainsEnabled = false`, no `applinks:`). Safari still tries `redmed://band#d=` before SOS |
| HealthKit | Parked (`healthKitImportEnabled = false`) |
| `redmed.pages.dev` | 404 until CF secrets / Git connect |
| iOS CI | Push/PR on `RedMed-Xcode/**` (unsigned Simulator compile). Not XCTest |
| `#d=` codec | `node scripts/test-d-codec.mjs` on pages-deploy + local |
| Policies | Bundled `Document/Document.html` + `legal-doc.css`. Legacy `Help.html` is a hash-preserving redirect stub (not bundled) |
| Notes | Ride both Keychain and chip (`NFCChipProfile.notes`, compact index 12) |
| Face ID | Post-Agree once, returning cold re-entry cream once/process, Edit / Save / Erase / Load From Band. No cream lock in front of Main. Keychain is device-unlocked, **no** biometry ACL |
| Entitlements | Empty dict / NFC parked (not TAG); no applinks; no HealthKit |
| Write-from-app storefront | Off until Tag Reading + Write The Band on blank NTAG216. Until then: blank chips + Share honesty |

**Still needs Max (not this tree):**

1. Paid Apple Developer: NFC Tag Reading on App ID `com.redmed.app` (portal + Xcode). In-repo CoreNFC is parked (`nfcHardwareEnabled = false`, no TAG entitlement, no usage string) — restore all three together via `docs/NFC-RESTORE.md`. Storefront / dept “write from the app” stays off until Tag Reading + Write The Band are proven on blank NTAG216 — until then blank chips + Share honesty only (`docs/ADVERTISING.md`).
2. Restore Associated Domains after paid Program (`docs/associated-domains-restore.md`).
3. Leave HealthKit parked until a paid team can provision it.
4. Do not re-bind Keychain to `biometryCurrentSet` (Face ID stays UI-only).
5. XCTest target is still missing; codec lockstep is Node.

---

## Accepted residuals (not bugs)

- **Public AES packing key** (`RedMed-NFC-AES-GCM-v1`). Anyone who loads tapper can forge a valid `#d=`. Trust boundary is physical band + intentional tap. Do not market the chip as confidential (`docs/DO-NOT.md`).
- **Passerby hospital search** POSTs coordinates to `overpass-api.de`. Native uses MapKit. Disclosed in Document.html / Satellite / Info.plist. Not removed.
- **CSP `unsafe-inline`** for decrypt / SOS / SW register. Host compromise of github.io is still game over for the shell; field XSS is the surface we harden.
- **Crash-motion false positives** can siren. Thresholds are vehicle-crash-only. SOS tap autodials; crash waits US 10s+30s; band-tap auto-arm is siren only.
- **No background crash sensing.** CoreMotion is owner foreground + `.inactive` only (`stopMonitoring()` on `.background`). Short post-Home window is parked (`docs/DO-NOT.md`). Find Help / support / Terms point at iPhone Crash Detection for lock/killed.

---

## In-repo controls (do not regress)

| Control | Evidence |
|---------|----------|
| No PHI `print()` | Swift `print(` grep empty |
| Vault history | Removed — do not remount |
| Snapshot / capture cover | `PrivacySnapshotGuard` — `.background` + capture only, never tap card, no opacity fade |
| ATS | Arbitrary loads + local networking **false** |
| WKWebView Help | `Document.html` + `legal-doc.css` only |
| WKWebView tapper | No `WKScriptMessageHandler`. file/about allow; http(s)/tel/mailto/redmed open outside or cancel; default deny |
| SW cache | Shell HTML only; `#d=` is a fragment; activate drops old `CACHE` names (`redmed-tapper-v152`) |
| Zlib bound | Swift 64 KiB; JS `MAX_INFLATED = 65536` |
| Scanner isolation | `isScannerSession` hides NFC / Edit; `persist()` no-ops when `persists == false` |
| Linked flag | `setBraceletPaired(true)` requires `nfcHardwareEnabled` |
| `IPHONEOS_DEPLOYMENT_TARGET` | Literal `17.0` × 4 (never `$(RECOMMENDED_…)`) |
| iOS CI | `.github/workflows/ios-build.yml` on push/PR for `RedMed-Xcode/**` |
| Pages smoke | github.io fail-closed; Actions SHA-pinned |

Engineer threat model: `docs/SECURITY.md`. Restore playbooks: `docs/NFC-RESTORE.md`, `docs/associated-domains-restore.md`, `docs/healthkit-restore.md`.

---

## Closed in-repo (do not reopen)

- `#476` stripped `OwnerAppLock`. Do not remount as an app-wide or YOU-card cream lock.
- `#474` named Overpass. Location is on as part of Agree (no in-app toggle). When-In-Use after post-Agree Face ID. GPS still starts only on Find Help.
- `#d=` extract strips at `&` (match tapper `#d=…&tab=aid`); decode fail-closed on non-base64url; write gate rejects `&`.
- `KeychainStore.exists` unknown SecItem errors → `false`.
- Encode clips to tapper `MAX_STR` / `MAX_LIST`.
- Privacy URLs point at this repo (`Document/Document.html`), not jsDelivr `redmed-privacy`.
- pages-deploy github.io smoke fails the job. Checkout / wrangler pinned to SHAs.
