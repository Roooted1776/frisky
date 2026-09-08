# Security

RedMed’s security model is described in the in-app **Help** security section (`RedMed-Xcode/RedMed/Help.html`) and in App Store privacy nutrition labels / the site privacy pages.

Short facts:

- The NFC band is **readable by design** — anyone who can tap it can open the passerby medical card. Do not put secrets you would not show a first responder on the band.
- Owner profile on the phone is Keychain-backed and local-only; there is no RedMed cloud for medical ID.
- **Face ID is UI-only.** Profile Keychain is `WhenPasscodeSetThisDeviceOnly` with **no biometry ACL** (`KeychainStore` never sets `kSecAttrAccessControl`). Readable while this iPhone is unlocked; excluded from iCloud Keychain and encrypted backups. Face ID / passcode gates post-Agree, Edit, Save, Erase, and Load From Band — not viewing the YOU card, not Keychain `SecItem` itself. Do not re-bind blobs to `biometryCurrentSet`.
- This project does **not** claim HIPAA certification.

## Reporting issues

- Prefer a [GitHub security advisory](https://github.com/Roooted1776/frisky/security/advisories) on this repo, or
- Email **help.RedMed@gmail.com**.
