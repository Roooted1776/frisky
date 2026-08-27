# App Store audit — RedMed (complete)

Audited against [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) (8 Jun 2026) and Connect product-page rules for Medical apps in US / UK / EEA. Code baseline: `main` after #416–#420 plus 5.1.1 Privacy URL.

**Verdict:** Ready to Archive and submit TestFlight / Review **as a local medical ID**, if Connect answers match this file and listing copy does not claim diagnosis, dispatch, or vital-sign measurement.

## Sign-off

| Item | Status |
|------|--------|
| 2.1 Completeness (no login) | Pass |
| 2.3 Metadata (when screenshots match build) | Pass — you supply screenshots |
| 2.5 Hardware / public APIs | Pass |
| 4.2 Minimum functionality | Pass |
| 5.1.1 Privacy policy in-app + Connect URL | Pass — Help → Privacy and `https://roooted1776.github.io/privacy/` |
| 5.1.1(iii)–(v) Minimize / respect deny / no account | Pass |
| 5.1.2 Sharing | Pass — no third-party SDKs |
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
| Bundle ID | com.redmed.app |
| Age | Medical/treatment information present → **12+** minimum. Not 4+ |
| Sign-in required | No |
| Demo account | Not applicable — Face ID on the review device |
| Encryption | Exempt |
| Tracking | No |
| App Privacy | **Data Not Collected** |
| Privacy Policy URL | **https://roooted1776.github.io/privacy/** |
| Support URL | mailto:help.RedMed@gmail.com or the same Pages host |
| Regulated medical device (US/UK/EEA) | **No** |
| Contact | help.RedMed@gmail.com |

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

## Notes for Review (paste into App Review Information)

RedMed is a personal medical ID. The owner stores name, contacts, allergies, medications, and conditions in the iPhone Keychain behind Face ID. There is no RedMed server and no login.

Privacy policy: https://roooted1776.github.io/privacy/ and Help → Privacy in the app. RedMed collects no profile or location. Guideline 5.1.1: no account, Location is optional, Erase deletes on-device data only.

911 uses the system phone sheet (tel:). GPS, if allowed, is shown on this iPhone for the owner to read to dispatch. It is never attached to the call and never uploaded.

Aid topics are first-aid reference, not a diagnosis. The crash/SOS alarm only raises brightness and volume on this phone.

NFC hardware write is off in this build (nfcHardwareEnabled = false) until Tag Reading is enabled on App ID com.redmed.app. Preview and Scan use a bundled HTML card.

HealthKit import is off. This app is not a regulated medical device.

## 5.1.1 checklist

- (i) Policy in Connect + in-app Help → Privacy.
- Collect: none to RedMed; owner-entered ID stays on device / optional band.
- Third parties: none. Apple OS APIs only.
- Delete: Help → Erase all RedMed data. Band must be overwritten locally.
- Withdraw: iOS Settings → RedMed; 911 works without Location.
- (v) No login.
- (ix) Submit from team 33F9FQ4VBU.

## After Pull

Xcode → `PrivacyInfo.xcprivacy` → Target Membership → RedMed. Product → Archive on 33F9FQ4VBU.
Confirm https://roooted1776.github.io/privacy/ returns 200 after Pages deploy from `main`.
Do not pull `wire-privacy-info-target`.
