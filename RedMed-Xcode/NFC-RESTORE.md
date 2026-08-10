# NFC Tag Reading

CoreNFC write/read is wired in production (`NFCWriter` / `NFCReader`). Simulator
cannot do real NFC — on Simulator / when `readingAvailable` is false the UI
shows an error and does **not** fake a successful link.

## RF / hardware contract

- Bracelet is **passive** HF NFC at **13.56 MHz** (`AppConfig.BraceletRF`) —
  ISO 14443 / NTAG213+ NDEF. No battery, no BLE.
- “Paired phone” means this iPhone wrote + verified the chip and stored a local
  link flag. The phone does **not** keep an active RF session or background-scan
  the band (different from Bluetooth pairing on ~2.4 GHz).
- **Distance is physics, not a setting** (`AppConfig.BraceletRF`):
  - Intentional tap: ~1–2″ to the phone antenna
  - Walk-by / no-fire margin: ~6–8″ (already dead past ~4″ of reliable ISO 14443)
  - Do not market these as a tunable read range
  - `NFCWriter` / `NFCReader` only `begin()` after Write or Scan
  - Deliberate stranger tap must still open the emergency card
- Do **not** source LF (~125 kHz) or UHF chips — CoreNFC cannot program them.
- Payment POS may share 13.56 MHz but speaks EMV, not RedMed NDEF URLs
  (`ignoredByPaymentPOS`) — protocol, not distance.
- Note: unlocked iPhones can still run Apple’s own Background Tag Reading if the
  antenna is pressed against an NDEF tag (~1–2″). RedMed cannot disable that OS
  path; it is unrelated to walk-by and is not started by this app.

## Portal / signing checklist

1. Developer portal → App ID `com.redmed.app` → enable **NFC Tag Reading**
2. Xcode → Signing & Capabilities → **Near Field Communication Tag Reading**
3. Confirm `RedMed.entitlements` has `com.apple.developer.nfc.readersession.formats` = `NDEF`
4. Confirm `Info.plist` has `NFCReaderUsageDescription`
5. Device test: write band → second phone Safari tap → emergency card

Free Apple Developer teams cannot ship the NFC entitlement — paid Program required.
