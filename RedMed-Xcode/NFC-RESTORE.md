# NFC owner tab (no Apple NFC entitlement)

Owner app ships the **NFC Bracelet** tab end-to-end in UI:

- Face ID → hold-to-band overlay → `braceletLinked`
- My ID bracelet entry points
- Scanners / Preview / `card.html` stay **RedMed + 911 + Aid only** (no NFC write)

`RedMed.entitlements` stays empty. Do **not** add
`com.apple.developer.nfc.readersession.formats` or `NFCReaderUsageDescription`.
The write overlay is a local demo (`Task.sleep`); it does not open a CoreNFC session.
