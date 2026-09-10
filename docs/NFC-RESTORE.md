# NFC Tag Reading

CoreNFC write/read is wired in production via `NFCBandManager` (owns
`NFCWriter` / `NFCReader`) — real `NFCNDEFReaderSession` sessions with write +
read-back verify, NDEF URI strip, and CryptoKit AES-GCM via `ProfileNFCCodec`.

**Target band:** blank unlocked **NXP NTAG216**, 13.56 MHz, ISO 14443A Type 2,
NDEF empty at factory. No pre-encode, no lock. Not NTAG213, MIFARE, LF, or UHF.
Owner **Write** on the NFC tab programs the chip; locked or non-NDEF tags are
rejected with a clear error. Face art is logo-print RedMed heart + wordmark on black `#232425` (30×9 mm) — not laser MED ID.

When hardware is off (`AppConfig.nfcHardwareEnabled = false`), `NFCBandManager`
still simulates Write/Scan by packing the compact `tapper.html#d=` URL. Real
CoreNFC has **no** Simulator fake-success: if hardware is enabled and NFC is
unavailable, write fails and the band is not marked linked.

**Linked** after a real CoreNFC write **and** matching read-back
(`writeVerified`), or after owner **Load From Band** persist()s the chip.
Written-but-unverified stays Not linked.

## Currently restored (in-repo)

`AppConfig.nfcHardwareEnabled = true`,
`RedMed.entitlements` has `com.apple.developer.nfc.readersession.formats`
→ `TAG`, and `Info.plist` has `NFCReaderUsageDescription` (Write + Load
From Band copy below). Owner NFC tab stays visible with Write The Band, Preview,
and **Load From Band** (Share Band URL hidden). Real `NFCNDEFReaderSession` still needs paid
Program + **NFC Tag Reading** on App ID `com.redmed.app` (portal + Xcode
capability are not git). Keep flag, entitlement, and usage string in
lockstep if parking again.

**Do not hide the owner NFC tab** — owners always get RedMed · 911 · Aid ·
NFC; scanners never get NFC. The flag only gates CoreNFC sessions and the
Load From Band button (Pack Band URL + Share Band URL + Preview when
parked — no Write label). Linked after a real write + matching read-back,
or Load From Band.

**Write-from-app storefront gate:** storefront / dept “write from the app”
stays off until Tag Reading is live on the App ID **and** Write The Band is
proven on a blank NTAG216 (device test below). Until then: sell **blank chips
only** + **Share honesty** — Share Band URL / Preview pack the same `#d=`
Write will use; they do not write the chip and do not mark Linked. Do **not**
tell owners to program the chip with Shortcuts / NFC Tools. Factory “NDEF
blank unlocked” is the chip procurement + blank SKU spec.

When hardware is on, owner NFC keeps **Write The Band**, **Preview**, and
**Load From Band** on one screen (Share Band URL is hidden). Load path:
read chip → empty-band alert / match→link / mismatch+existing→Replace
confirm / empty funnel→adopt. Face ID (`force: true`) before link and
adopt. Write stays ungated. Preview does not persist. After a verified
write: **Linked** — anyone can tap this band to open your card. Parked
(flag off): **Pack Band URL** + Share Band URL + Preview — no Write
button.

## RF / hardware contract

- Bracelet is **passive** HF NFC at **13.56 MHz** (`AppConfig.BraceletRF`) —
  **NXP NTAG216**, ISO 14443A Type 2, NDEF blank unlocked. No battery, no BLE.
  Not NTAG213, MIFARE, LF, or UHF. Factory does not pre-encode or lock.
- Chip must be **rewritable** (NDEF not permanently locked). Factory-blank or
  overwriteable stub only — see `docs/band-engraving-and-nfc-sourcing.md`.
- **Owner data independence:** `NFCWriter` / `ProfileNFCCodec` write only
  `AppConfig.medicalCardBaseURL#d=…` (`OwnerBandURI.isValidWriteURL`). Current
  base is `https://roooted1776.github.io/tapper/`. Flip to `getredmed.com` only after
  `docs/domain.md` cutover is green. No vendor tag-management cloud, no
  social/short-link redirect, no App Store URL on the chip, no BLE. Profile
  lives in `#d=` only; Pages serves the shell.
- `#d=` packing uses a public client key shared with `tapper.html`. The band
  is the credential — any phone that taps it can read the card.
- “Paired phone” means this iPhone wrote + verified the chip and stored a local
  link flag. RedMed does **not** keep an active RF session or background-scan
  the band (different from Bluetooth pairing on ~2.4 GHz). iOS Background Tag
  Reading is a separate Apple OS path — see below.
- **Distance is physics, not a setting** (`AppConfig.BraceletRF`):
  - Intentional tap: ~1–2″ to the phone antenna
  - Walk-by / no-fire margin: ~6–8″ (already dead past ~4″ of reliable ISO 14443)
  - Do not market these as a tunable read range
  - `NFCBandManager` / `NFCWriter` / `NFCReader` only `begin()` after Write or Load From Band
  - Deliberate stranger tap must still open the emergency card
- Do **not** source NTAG213, MIFARE, LF (~125 kHz), or UHF chips.
- Payment POS may share 13.56 MHz but speaks EMV, not RedMed NDEF URLs
  (`ignoredByPaymentPOS`) — protocol, not distance.
- **iOS Background Tag Reading (not RedMed):** what can still open the URL later
  is Apple’s OS path — phone can be off or locked; a deliberate tap (top of
  phone ~1–2″ from the band) still works. Wrist + pocket is usually fine. Phone
  pressed to the clasp can pop Safari / `tapper.html`. Same for any passerby.
  Writing the chip does not make that more or less likely. Band stays passive
  (no battery — not AirTag). RedMed cannot disable that OS path; it is unrelated
  to walk-by and is not started by this app. Product copy lives in
  `AppConfig.BraceletRF.backgroundTagReadingSummary`.

## Restore (paid Program + device)

In-repo flag, entitlement, and usage string are restored. Still do portal +
Xcode + device after a paid Program can provision NFC Tag Reading:

1. `AppConfig.nfcHardwareEnabled = true` (done)
2. `com.apple.developer.nfc.readersession.formats` → `TAG` in
   `RedMed.entitlements` (done; do not use `NDEF`; Apple disallows it and Xcode
   rewrites the file during the build)
3. Developer portal → App ID `com.redmed.app` → enable **NFC Tag Reading**
4. Xcode → Signing & Capabilities → **Near Field Communication Tag Reading**
5. `NFCReaderUsageDescription` in `Info.plist` (done):
   `RedMed writes your medical ID onto your NFC bracelet and can load a written band into this iPhone. Tag reading starts only when you tap Write or Load From Band.`
6. Device test on **verified blank NTAG216** stock: Write → second phone Safari
   tap → emergency card. Linked only if read-back matches.

Free Apple Developer teams cannot ship the NFC entitlement — paid Program required.

Hardware ship order (not app architecture): blank NTAG216 verified → entitlement
live on device → factory MOQ. See `band-engraving-and-nfc-sourcing.md` and
Linear RED-19.

## Park again (optional)

1. Set `AppConfig.nfcHardwareEnabled = false`
2. Remove only `com.apple.developer.nfc.readersession.formats` from
   `RedMed.entitlements` (leave any other keys, e.g. future `applinks:`)
3. Remove `NFCReaderUsageDescription` from `Info.plist`
4. Keep the CoreNFC source files
