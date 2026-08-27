# App Store audit — RedMed (complete)

Audited against [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) (8 Jun 2026) and Connect product-page rules for Medical apps in US / UK / EEA. Code baseline: `main` after #416–#419.

**Verdict:** Ready to Archive and submit TestFlight / Review **as a local medical ID**, if Connect answers match this file and listing copy does not claim diagnosis, dispatch, or vital-sign measurement.

## Sign-off

| Item | Status |
|------|--------|
| 2.1 Completeness (no login) | Pass |
| 2.3 Metadata (when screenshots match build) | Pass — you supply screenshots |
| 2.5 Hardware / public APIs | Pass |
| 4.2 Minimum functionality | Pass |
| 5.1.1 / 5.1.2 Privacy — no collection, no share | Pass |
| 5.1.3 HealthKit / no PHI in iCloud | Pass (Health parked; Keychain + excluded vault) |
| 5.1.5 Location not used as emergency dispatch | Pass if listing matches |
| 1.4.1 Medical / physical harm | Pass **only** with the copy below |
| 1.1.6 No false device features | Pass if GPS is not “sent to 911” |
| Privacy manifest in repo | Pass — tick target membership in Xcode |
| Export compliance | Pass — `ITSAppUsesNonExemptEncryption = false` |
| Regulated medical device (Connect 2026) | Declare **No** |
| NFC / Health entitlements | Parked — disclose in Review notes |

## Connect — fill exactly

| Field | Value |
|-------|--------|
| Name | RedMed |
| Subtitle | Medical ID on your iPhone and band |
| Category | Medical |
| Secondary | optional Health & Fitness — avoid if you want fewer device questions |
| Bundle ID | com.redmed.app |
| SKU | redmed |
| Age | Medical/treatment information = Infrequent or Frequent → **12+** minimum. Not 4+ |
| Sign-in required | No |
| Sign in with Apple | Not applicable |
| Demo account | Not applicable — Face ID on the review device |
| Encryption | Exempt / documentation not required |
| Tracking | No |
| App Privacy | **Data Not Collected** |
| Regulated medical device (US/UK/EEA) | **No** |
| Contact | help.RedMed@gmail.com |
| Privacy policy URL | Hosted Help / Privacy page (same copy as in-app `Help.html`) |
| Support URL | same |

### Promotional text (optional)

Medical ID in Keychain. Face ID to edit. 911 and first-aid on the phone. Optional NFC band for a passerby tap. Nothing is uploaded to RedMed.

### Description (paste)

RedMed stores your medical ID on this iPhone — name, contacts, allergies, medications, and conditions — behind Face ID. There is no RedMed account and no RedMed server.

911 opens the system phone app. If you allow Location, the 911 tab can show coordinates for you to read to dispatch. RedMed does not place the call for you and does not send your location or profile to anyone.

Aid is first-aid reference. It is not a diagnosis or a treatment plan. Check with a doctor before medical decisions. In an emergency call your local emergency number.

An optional NFC bracelet can carry a tap-to-view card for a helper. Hardware write is included when Apple Tag Reading is enabled on this app; this build can preview the card on the phone.

RedMed is not a regulated medical device and is not affiliated with Apple.

### Keywords

medical ID, ICE, emergency, first aid, NFC, allergies, medications, 911

### What’s New (1.1)

Face ID unlock, on-device medical ID, 911 and Aid tabs, NFC preview. Privacy cover in the app switcher. No account.

## Notes for Review (paste into App Review Information)

RedMed is a personal medical ID. The owner stores name, contacts, allergies, medications, and conditions in the iPhone Keychain behind Face ID. There is no RedMed server and no login.

911 uses the system phone sheet (tel:). GPS, if allowed, is shown on this iPhone for the owner to read to dispatch. It is never attached to the call and never uploaded.

Aid topics are first-aid reference, not a diagnosis. The crash/SOS alarm only raises brightness and volume on this phone.

NFC hardware write is off in this build (nfcHardwareEnabled = false) until Tag Reading is enabled on App ID com.redmed.app. Preview and Scan use a bundled HTML card. Live bracelets, when written later, open https://roooted1776.github.io/tapper/#d=… with the payload only in the URL fragment.

HealthKit import is off (healthKitImportEnabled = false). The Health purpose string remains because HealthKit.framework is linked for a future optional import of birth date and blood type only.

This app is not a regulated medical device. It does not diagnose, treat, or measure vitals.

Review device test:
1. Cold launch → Face ID or passcode → I Agree (first launch).
2. Fill ID → Save → kill app → relaunch; profile still there.
3. 911: optional location; Call uses the system sheet.
4. Aid: open a topic. Stop SOS if the alarm was armed.
5. NFC: Preview / Scan (simulate).
6. Home: cream cover, no PHI in the snapshot.
7. Help → Erase all RedMed data (Face ID) clears this phone, not a physical band.

## Guideline map (full)

**1. Safety**
- 1.1 Objectionable content — N/A.
- 1.1.6 — Do not describe GPS as transmitted to 911 or SOS as a monitored service.
- 1.2 UGC — N/A (profile is the owner’s own data).
- 1.4.1 — Medical apps get extra scrutiny. No accuracy claims for sensors. Remind users to check with a doctor. No FDA clearance to attach.
- 1.4.2 Dosage calculators — RedMed does not calculate doses.
- 1.5 / 1.6 Developer information — contact in Help + Connect.

**2. Performance**
- 2.1 — Complete without a backend. Face ID on the reviewer’s device.
- 2.3 — Screenshots = cream lock, owner ID, 911, Aid, NFC Preview. No pre-rendered fake live-write if hardware is off.
- 2.5.4 — NFC purpose string present; entitlement parked; notes say so.

**3. Business** — free, no IAP, no account.

**4. Design**
- 4.2 — Native owner app + bundled card, not a URL wrapper.
- 4.5 Apple trademarks — “Face ID” / “Apple Health” as feature names only.

**5. Legal**
- 5.1.1(i)–(v) — purpose strings for Face ID, Location, Health, NFC match use.
- 5.1.1(ix) — healthcare; submit from the paid team 33F9FQ4VBU.
- 5.1.2 — no third-party share.
- 5.1.3 — no Health write; no PHI in iCloud.
- 5.1.5 — location only for on-screen 911 coordinates.
- 5.2 IP — owner content + original Aid copy.

## Binary already on main (#419)

- `RedMed-Xcode/RedMed/PrivacyInfo.xcprivacy`
- `Info.plist`: export flag, NFCReaderUsageDescription, location string limited to on-device coords
- Version 1.1 (2), category Medical in build settings

After Pull: Xcode → `PrivacyInfo.xcprivacy` → File inspector → Target Membership → RedMed. Then Product → Archive.

## Not git (you in Connect / Apple Developer)

1. Tick PrivacyInfo on the target (above).
2. Archive + TestFlight on team 33F9FQ4VBU.
3. Privacy policy URL live (Help.html already in the app).
4. Six screenshots (6.7" and 6.1") that match this build.
5. Replace `AppConfig.appStoreURL` id0000000000 after Connect assigns an ID (setup QR only — never the band).
6. NFC Tag Reading / HealthKit on the App ID only when you flip the AppConfig flags.
7. Do not pull `wire-privacy-info-target` (broken pbxproj).
