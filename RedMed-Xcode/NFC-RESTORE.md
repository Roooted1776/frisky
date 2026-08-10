# Unhide Apple NFC flags (after paid Developer Program)

Owner NFC UI is live now. Apple capability flags are **commented in place**
so signing stays free-team safe. When you have the license, unhide them.

## What is already on

- `NFCView` in the target, `AppTab.nfc`, My ID bracelet entry points
- Face ID → demo hold-to-band overlay → `braceletLinked`
- Scanners / Preview / `card.html`: **RedMed + 911 + Aid only** (no NFC write)

## What is hidden (easy to restore)

| File | Marker |
|------|--------|
| `RedMed/RedMed.entitlements` | `<!-- UNHIDE WITH APPLE DEV LICENSE: … -->` around NDEF formats |
| `RedMed/Info.plist` | same marker around `NFCReaderUsageDescription` |
| `RedMed/NFCView.swift` | `// UNHIDE WITH APPLE DEV LICENSE:` above `import CoreNFC` |

## Unhide checklist

1. Developer portal → App ID `com.redmed.app` → enable **NFC Tag Reading**
2. Xcode → Signing & Capabilities → **Near Field Communication Tag Reading**
3. Uncomment the entitlement block in `RedMed.entitlements`
4. Uncomment `NFCReaderUsageDescription` in `Info.plist`
5. Uncomment `import CoreNFC` in `NFCView.swift`
6. Replace `NFCWriteOverlay`’s `Task.sleep` demo with `NFCNDEFWriterSession`
   (see `uploads/Services/NFCWriter.swift` for a full write + read-back pattern)
7. Device test: write band → second phone Safari tap → RedMed / 911 / Aid, no Edit, no NFC tab

Simulator still cannot do real NFC — keep the demo overlay under
`#if targetEnvironment(simulator)` if you want.
