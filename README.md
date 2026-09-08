# RedMed (frisky)

Local-only medical ID for iPhone, built around an NFC **band as the product**.

- Fill your medical ID in the app, write it to the band, and anyone who taps the band opens a passerby card (`tapper`) — no account, no Face ID on the tap card.
- Profile stays on-device (Keychain). There is no cloud sync and no server-side medical store.
- Face ID / passcode: once after Agree (first launch / policy bump / after Erase), plus Edit, Save, Clear (empty fields + Save), Erase, Load From Band — **not** viewing the YOU card, not later cold launches, not 911 / Aid / NFC write, and not the band tap card.
- **Clear vs Erase:** blanking fields in Edit and Save does **not** wipe Keychain (`persist()` refuses empty-over-stored). Full wipe is Help → **Erase All User Data** (Face ID). The physical band is not wiped remotely.
- Privacy / TOS / security copy lives in-app Help (`Help.html`) and on the site privacy pages.

## Build

Open `RedMed-Xcode/RedMed.xcodeproj` in Xcode (iOS 17+). Product HTML for the passerby card is under `tapper/`; redirects keep legacy `card` / `get` URLs working.

## Owner

[Roooted1776](https://github.com/Roooted1776) — repo: [frisky](https://github.com/Roooted1776/frisky).

See `AGENTS.md` for agent/contributor invariants.
