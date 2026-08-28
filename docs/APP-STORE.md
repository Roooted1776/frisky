# App Store audit — RedMed

Shape A for this build: on-device medical ID + 911 + first-aid reference.
NFC Tag Reading and HealthKit stay parked (`nfcHardwareEnabled = false`).
Do not encode a fake `apps.apple.com` URL.

**Privacy Policy URL:** https://cdn.jsdelivr.net/gh/Roooted1776/redmed-privacy@main/index.html
**Support URL:** use `support/index.html` on a public host (same jsDelivr repo, or Pages).

Source: https://github.com/Roooted1776/redmed-privacy
In-app: Help → Privacy.

Connect App Privacy nutrition label: **Data Not Collected**. Tracking: No.

## Sign-off

Ready to Archive as a local medical ID. No diagnosis, dispatch, or vital-sign claims.
Listing must not promise live bracelet write until NFC entitlement is restored and `https://roooted1776.github.io/tapper/` (or the custom host) returns RedMed · 911 · Aid.

| Field | Value |
|-------|--------|
| Name | RedMed |
| Subtitle | Medical ID on your iPhone |
| Category | Medical |
| Age | 12+ |
| Sign-in | No |
| Encryption | Exempt |
| Tracking | No |
| App Privacy | Data Not Collected |
| Privacy Policy URL | https://cdn.jsdelivr.net/gh/Roooted1776/redmed-privacy@main/index.html |
| Support | help.RedMed@gmail.com + public Support page |
| Regulated medical device | No |
| Contact | help.RedMed@gmail.com |

## Review notes (paste)

RedMed is a personal medical ID on this iPhone (Keychain, Face ID). No RedMed server, no login. Privacy: https://cdn.jsdelivr.net/gh/Roooted1776/redmed-privacy@main/index.html and Help → Privacy. 911 uses tel:; GPS stays on-screen. Aid is first-aid reference — follow the dispatcher. Seizure timer does not auto-dial; it shows a Call button at 5:00. NFC write is parked in this build (preview uses bundled HTML). Not a regulated medical device. Review device: enroll Face ID or a passcode so Unlock can complete.
