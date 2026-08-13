# NFC Tag Reading

CoreNFC write/read is wired in production via `NFCBandManager` (owns
`NFCWriter` / `NFCReader`) — real `NFCNDEFReaderSession` sessions with write +
read-back verify, NDEF URI strip, and CryptoKit AES-GCM via `ProfileNFCCodec`.
When hardware is off, `NFCBandManager` still simulates Write/Scan by packing the
compact `tapper.html#d=` URL (flat array → AES-GCM → Base64url; legacy zlib still
decodes). Real CoreNFC has **no** Simulator fake-success: if hardware is enabled
and NFC is unavailable, write fails and the band is not marked linked.

## Currently disabled (hardware sessions only)

CoreNFC write/read sessions are off via `AppConfig.nfcHardwareEnabled = false`.
**Do not hide the owner NFC tab** when flipping this — owners always get
RedMed · 911 · Aid · NFC; scanners never get NFC. The flag only blocks
`NFCWriter` / `NFCReader` sessions (simulate path stays).
Owner NFC page keeps **both** capabilities on one screen: user Setup/Write and
tap Scan / Simulate scan (opens the same `tapper.html#d=` page helpers see).
Files that make hardware work stay in the tree (`NFCWriter`, `NFCReader`,
`NFCBandManager`, `ProfileNFCCodec`, `PasserbyHTMLCardView`, bundled `tapper.html`,
`NFCReaderUsageDescription` in Info.plist) — entitlement stays commented.
`RedMed.entitlements` keeps the NFC key commented so free/unsigned builds still
sign. Flip both when you have a paid Apple Developer Program license and a
physical iPhone to test.

## RF / hardware contract

- Bracelet is **passive** HF NFC at **13.56 MHz** (`AppConfig.BraceletRF`) —
  ISO 14443 / NTAG213+ NDEF. No battery, no BLE.
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
  is Apple’s OS path — screen on, unlocked, top of phone ~1–2″ from the band.
  Wrist + pocket is usually fine. Phone pressed to the clasp while unlocked can
  pop Safari / `tapper.html`. Same for any passerby. Writing the chip does not
  make that more or less likely. RedMed cannot disable that OS path; it is
  unrelated to walk-by and is not started by this app. Product copy lives in
  `AppConfig.BraceletRF.backgroundTagReadingSummary`.

## Enable checklist

1. Set `AppConfig.nfcHardwareEnabled = true`
2. Uncomment `com.apple.developer.nfc.readersession.formats` → `NDEF` in
   `RedMed.entitlements`
3. Developer portal → App ID `com.redmed.app` → enable **NFC Tag Reading**
4. Xcode → Signing & Capabilities → **Near Field Communication Tag Reading**
5. Confirm `Info.plist` has `NFCReaderUsageDescription`
6. Device test: write band → second phone Safari tap → emergency card

Free Apple Developer teams cannot ship the NFC entitlement — paid Program required.
