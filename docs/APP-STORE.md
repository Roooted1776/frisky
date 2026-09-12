# App Store audit — RedMed (parked)

**Not submitting.** No paid App Store listing / Connect app yet. Leave NFC and HealthKit parked. Do not encode a fake `apps.apple.com` URL. Restore this checklist when a paid Program and app ID exist.

**Privacy source of truth:** in-app Help → Policies → Privacy (`RedMed-Xcode/RedMed/Document/Document.html`).

This repo is **public**. Do not list a jsDelivr `@main` URL of `Roooted1776/redmed-privacy` as Connect’s privacy policy — that is a second git tree with a days-long CDN cache. Pick a tagged / hashed document on the live band host after `/tapper/` is green — **same Privacy wording as Help**, not a rewrite.

Hosted Privacy URL is `/Document/` (same `Document.html` as in-app Help). `/privacy` redirects there — do not keep a rewritten stub.

**Support mail:** `help.RedMed@gmail.com` is troubleshooting only. Do not ask users for full medical profiles. Delete threads when resolved.

Connect App Privacy nutrition label: **Data Not Collected**. Tracking: No.

## Sign-off

Ready to Archive as a local medical ID only after the band host is live. No diagnosis, dispatch, or vital-sign claims.
Listing must not promise live bracelet write until NFC entitlement is restored.
Do not promise secret encryption on the chip — tap-to-view is ungated by design.

**Claims wall:** Connect promotional text stays on store / transfer / display
+ Share honesty only while Write is parked — [`FDA-CLAIMS-WALL.md`](FDA-CLAIMS-WALL.md).
Counsel audit: **no** in-repo App Store copy claims write-from-app (listing
parked; review notes + Promotional Text below are pack/Share only).

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
| Privacy Policy URL | TBD — must serve the **same** Help → Privacy text (`Document/Document.html`); never a second policy tree |
| Support | help.RedMed@gmail.com + `support/index.html` (troubleshooting only — never request full profiles; delete threads when resolved) |
| Regulated medical device | No |
| Contact | help.RedMed@gmail.com |

## Promotional Text (locked draft — paste only this)

Subtitle stays **Medical ID on your iPhone**. Description / promos while
Write is parked:

> RedMed stores your self-reported emergency ID on this iPhone. Share Band
> URL and Preview pack a helper card from what you typed — they do not write
> a chip. When NFC write returns, a passive RedMed band can carry the same
> card for anyone to tap. Not a medical device. Not HIPAA certified. Call
> emergency services first.

**Do not** add: write from the app, program with Shortcuts, HIPAA compliant,
clinical thresholds, crash/seizure detection boasts, or “available to write
now.”

## Review notes (paste)

RedMed is a personal medical ID on this iPhone (Keychain). Before You Continue is Agree + checkbox only (no Face ID). After Agree on first launch / policy bump / after Erase, Face ID runs once then Main; returning cold opens skip Before You Continue but Face ID once over warm Main (same-session resume does not re-prompt). Face ID also gates Edit, Save, Erase, and Load From Band — not a second view-unlock after cold-open Face ID, not 911, Aid, NFC write, or band tap. Edit has field-level Clear only (blood type / birth date); blank-all + Save does not wipe Keychain — full wipe is Help → Erase All User Data. Empty-funnel first fill still Face IDs on Save when fields are filled. No RedMed server, no login. Privacy: Help → Privacy. SOS · Locate Me opens tel: to the regional emergency number immediately (no in-app confirm). Crash / impact detect is RedMed's own CoreMotion path for app users while RedMed is on screen (default thresholds) — not Apple Crash Detection, no motion background mode. Locking the phone or leaving the app stops new detection even if RedMed was open. For lock, background, or force-quit, owners should use iPhone Crash Detection if the device supports it; RedMed does not sense those events. Crash detection uses US Crash Detection timing (10s alert + 30s countdown) then tel: unless Stop. An armed SOS siren can keep sounding. GPS stays on-screen and is never attached to the call. Nearby hospitals in the app uses Apple Maps; a band tap uses OpenStreetMap Overpass on that phone. Aid is first-aid reference — follow the dispatcher. Seizure timer does not auto-dial; it shows a Call button at 5:00. NFC write and Load From Band UI are parked in this build (pack-only Write + Share Band URL + Preview; no CoreNFC session). `#d=` on a written band is readable by any phone that taps it. Not a regulated medical device. Review device: enroll Face ID or a passcode so post-Agree / cold re-entry / Edit / Save / Erase can complete (Load From Band appears only after NFC Tag Reading is restored).
