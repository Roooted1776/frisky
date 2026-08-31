# App Store audit — RedMed (parked)

**Not submitting.** No paid App Store listing / Connect app yet. Leave NFC and HealthKit parked. Do not encode a fake `apps.apple.com` URL. Restore this checklist when a paid Program and app ID exist.

**Privacy source of truth:** in-app Help → Privacy (`RedMed-Xcode/RedMed/Help.html`).

This repo is **public**. Do not list a jsDelivr `@main` URL of `Roooted1776/redmed-privacy` as Connect’s privacy policy — that is a second git tree with a days-long CDN cache. Pick a tagged / hashed document on the live band host after `/tapper/` is green.

Do **not** use `https://roooted1776.github.io/privacy/` until that host exists and serves it.

Connect App Privacy nutrition label: **Data Not Collected**. Tracking: No.

## Sign-off

Ready to Archive as a local medical ID only after the band host is live. No diagnosis, dispatch, or vital-sign claims.
Listing must not promise live bracelet write until NFC entitlement is restored.
Do not promise secret encryption on the chip — tap-to-view is ungated by design.

| Field | Value |
|-------|--------|
| Name | RedMed |
| Subtitle | Medical ID on your iPhone |
| Category | Medical |
| Age | 12+ |
| Sign-in | No |
| Encryption | Exempt (CryptoKit AES-GCM pack + public client key; `ITSAppUsesNonExemptEncryption` = false) |
| Tracking | No |
| App Privacy | Data Not Collected |
| Privacy Policy URL | TBD — bundled Help.html until a live host serves it |
| Support | help.RedMed@gmail.com + `support/index.html` |
| Regulated medical device | No |
| Contact | help.RedMed@gmail.com |

## Review notes (paste)

RedMed is a personal medical ID on this iPhone (Keychain). Face ID gates Edit, Save, and Erase only — not app launch, 911, Aid, NFC write, or band tap. No RedMed server, no login. Privacy: Help → Privacy. SOS · Locate Me opens tel: to the regional emergency number immediately (no in-app confirm). Crash / impact detect is RedMed's own CoreMotion path while the owner app is in the foreground — not Apple Crash Detection, no motion background mode. Crash detection uses US Crash Detection timing (10s alert + 30s countdown) then tel: unless Stop. An armed SOS siren can keep sounding. GPS stays on-screen and is never attached to the call. Nearby hospitals in the app uses Apple Maps; a band tap uses OpenStreetMap Overpass on that phone. Aid is first-aid reference — follow the dispatcher. Seizure timer does not auto-dial; it shows a Call button at 5:00. NFC write is parked in this build (preview uses bundled HTML). `#d=` on a written band is readable by any phone that taps it. Not a regulated medical device. Review device: enroll Face ID or a passcode so Edit / Save / Erase can complete.
