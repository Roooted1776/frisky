# Security

RedMed is local-only. No RedMed server, no login, no passerby Face ID.

## What is actually secret

- **Owner profile on this iPhone:** Keychain item `WhenPasscodeSetThisDeviceOnly` + `biometryCurrentSet`. Face ID / passcode every open. Re-enrolling biometrics invalidates the item.
- **The physical band:** anyone who taps it (or who has the `#d=` URL) can read the card. That is the product. EMT / helper phones must work with no account.

## What is not a secret

`#d=` AES-GCM uses a **public client key** (`RedMed-NFC-AES-GCM-v1` → SHA-256) embedded in the app and in `tapper.html`. Packing stops casual hex dumps. It does **not** stop someone who has the URL, a photo of the address bar, Safari history, or the bracelet in hand.

Legacy `#d=` (raw JSON / zlib) still decodes. Do not market the chip as encrypted-at-rest or HIPAA-certified.

**iOS Background Tag Reading** can open `tapper.html#d=` while the phone is locked. RedMed cannot disable that OS path.

## Export compliance

`ITSAppUsesNonExemptEncryption` is **false**. `#d=` uses Apple CryptoKit AES-GCM (OS crypto), not a proprietary cipher. App Store Connect treat this as **exempt**. Do not flip the key to true unless Apple issues an `ITSEncryptionExportComplianceCode` after you file non-exempt docs.

Annual US self-classification may still apply for exempt encryption. That is paperwork, not an Info.plist flag.

## Parked capabilities

Personal/free teams: `RedMed.entitlements` is empty. NFC Tag Reading, HealthKit, and Associated Domains stay off. Do not keep unused Health / NFC usage strings in `Info.plist` while those entitlements are absent — restore the strings with the capability (`docs/NFC-RESTORE.md`, `docs/healthkit-restore.md`).
