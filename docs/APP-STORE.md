# App Store review — RedMed

Use this with `docs/PRODUCTION.md`. Product: local-only medical ID + emergency assist. No account. No RedMed profile backend.

## App Store Connect answers

| Question | Answer |
|----------|--------|
| Category | Medical |
| Age | 12+ (medical info + emergency calling). Not 4+ |
| Sign in / account | None. No Sign in with Apple. No account deletion API |
| Data collection (nutrition label) | **Data Not Collected** — PHI, GPS, Health, Face ID stay on-device. Nothing is uploaded to RedMed |
| Tracking | No. No ATT prompt |
| Encryption export | Exempt. `ITSAppUsesNonExemptEncryption = false`. HTTPS + Apple CryptoKit / Keychain. Band `#d=` AES-GCM uses a **public client key** so EMS can decode with no account — packing, not a product cipher |
| HealthKit | Capability **parked**. Code path off (`healthKitImportEnabled = false`). Purpose string stays because HealthKit.framework is linked for the future import |
| NFC Tag Reading | Capability **parked** until paid App ID has the entitlement. In-app Write/Scan simulate. Purpose string is in Info.plist for the CoreNFC binary |
| Demo account | Not applicable |
| Contact | help.RedMed@gmail.com |

## Notes for Review (paste into App Review Information)

RedMed is a personal medical ID. The owner stores name, contacts, allergies, meds, and conditions in the iPhone Keychain (Face ID). There is no RedMed server and no login.

911 uses the system phone sheet (`tel:`). GPS, if allowed, is shown on-device for the owner to read to dispatch — it is never attached to the call and never uploaded.

Aid topics are first-aid reference, not a diagnosis. The crash/SOS alarm raises brightness and volume on this phone only.

NFC hardware write is off in this build (`nfcHardwareEnabled = false`) until Apple enables Tag Reading on App ID `com.redmed.app`. Preview/Scan use a bundled HTML card. Live bracelets, when written later, open `https://roooted1776.github.io/tapper/#d=…` with the payload only in the URL fragment.

## Reviewer device test

1. Cold launch → Face ID or passcode → I Agree (first time).
2. Fill medical ID → Save (Face ID) → profile stays after kill/relaunch.
3. 911 tab: location optional; Call uses the system sheet.
4. Aid: open a topic; Stop the alarm if SOS was armed.
5. NFC tab: Preview / Scan (simulate). Write is pack-only until entitlement.
6. Home / app switcher: cream privacy cover, no PHI in the snapshot.
7. Help → Erase all RedMed data (Face ID) clears Keychain + vault, not a physical band.

## Still not git

Paid Apple Developer team `33F9FQ4VBU` / App ID `com.redmed.app`: enable NFC Tag Reading + HealthKit when you want those features, then flip the AppConfig flags.
Replace `AppConfig.appStoreURL` `id0000000000` after Connect assigns an ID (setup QR only).
Archive + TestFlight from Xcode on that team. Screenshots and listing copy live in App Store Connect, not this repo.
