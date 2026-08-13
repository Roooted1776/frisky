# NFC Tag Reading

CoreNFC write/read is wired in production via `NFCBandManager` (owns
`NFCWriter` / `NFCReader`) — real `NFCNDEFReaderSession` sessions with write +
read-back verify, NDEF URI strip, and CryptoKit AES-GCM via `ProfileNFCCodec`.

**Target band:** passive, rewritable, NFC Forum **Type 2** (NXP NTAG213+ /
prefer NTAG216). Owner **Write** on the NFC tab programs the chip; locked or
non-NDEF tags are rejected with a clear error.

When hardware is off (`AppConfig.nfcHardwareEnabled = false`), `NFCBandManager`
still simulates Write/Scan by packing the compact `tapper.html#d=` URL. Real
CoreNFC has **no** Simulator fake-success: if hardware is enabled and NFC is
unavailable, write fails and the band is not marked linked.

## Currently enabled (code + entitlement)

`AppConfig.nfcHardwareEnabled = true` and
`com.apple.developer.nfc.readersession.formats` → `NDEF` are on in
`RedMed.entitlements`.

**Do not hide the owner NFC tab** if you park the flag again — owners always get
RedMed · 911 · Aid · NFC; scanners never get NFC. The flag only blocks
`NFCWriter` / `NFCReader` sessions (simulate path stays).

Owner NFC page keeps **both** capabilities on one screen: Write and Scan
(opens the same `tapper.html#d=` page helpers see).

## RF / hardware contract

- Bracelet is **passive** HF NFC at **13.56 MHz** (`AppConfig.BraceletRF`) —
  ISO 14443 / NFC Forum Type 2 / NTAG213+ NDEF. No battery, no BLE.
- Chip must be **rewritable** (NDEF not permanently locked). Factory-blank or
  overwriteable stub only — see `docs/band-engraving-and-nfc-sourcing.md`.
- **Owner data independence:** `NFCWriter` / `ProfileNFCCodec` write only
  `https://redmed.pages.dev/tapper/#d=…` (`AppConfig.OwnerBandURI.isValidWriteURL`).
  No vendor tag-management cloud, no social/short-link redirect, no App Store
  URL on the chip, no BLE. Profile lives in `#d=` only; Pages serves the shell.
- “Paired phone” means this iPhone wrote + verified the chip and stored a local
  link flag. RedMed does **not** keep an active RF session or background-scan
  the band (different from Bluetooth pairing on ~2.4 GHz). iOS Background Tag
  Reading is a separate Apple OS path — see below.
- **Distance is physics, not a setting** (`AppConfig.BraceletRF`):
  - Intentional tap: ~1–2″ to the phone antenna
  - Walk-by / no-fire margin: ~6–8″ (already dead past ~4″ of reliable ISO 14443)
  - Do not market these as a tunable read range
  - `NFCBandManager` / `NFCWriter` / `NFCReader` only `begin()` after Write or Scan
  - Deliberate stranger tap must still open the emergency card
- Do **not** source LF (~125 kHz) or UHF chips — CoreNFC cannot program them.
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

## Portal checklist (device install)

Code-side enable is done. Device signing still needs the App ID capability:

1. Confirm `AppConfig.nfcHardwareEnabled = true`
2. Confirm `com.apple.developer.nfc.readersession.formats` → `NDEF` in
   `RedMed.entitlements`
3. Developer portal → App ID `com.redmed.app` → enable **NFC Tag Reading**
4. Xcode → Signing & Capabilities → **Near Field Communication Tag Reading**
5. Confirm `Info.plist` has `NFCReaderUsageDescription`
6. Device test on **verified blank NTAG216** stock: Write → second phone Safari
   tap → emergency card

Free Apple Developer teams cannot ship the NFC entitlement — paid Program required.

Hardware ship order (not app architecture): blank NTAG216 verified → entitlement
live on device → factory MOQ. See `band-engraving-and-nfc-sourcing.md` and
Linear RED-19.

## Park again (optional)

1. Set `AppConfig.nfcHardwareEnabled = false`
2. Comment out the NFC key/array in `RedMed.entitlements` (leave the rest empty)
3. Keep `NFCReaderUsageDescription` and the CoreNFC source files
