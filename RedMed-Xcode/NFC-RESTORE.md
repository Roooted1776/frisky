# Restoring real CoreNFC (vs simulated owner tab)

Owner app currently ships a **simulated** NFC Bracelet tab:
Face ID → demo “Hold to band” overlay → `braceletLinked`. No
`NFCNDEFWriterSession`, no NFC entitlement, no `NFCReaderUsageDescription`.

Ped / EMS tap and in-app Preview scanner stay **RedMed + 911 + Aid only** —
no NFC write UI (`ContentView.showsNFC` / `scannerSafeTab`).

## Ped / EMS NFC tap (required product behavior)

When a stranger taps the bracelet, the NDEF URI opens **`card.html#d=…`**
in their phone browser (no RedMed app required). That page **must** expose
the same three tabs as the owner app and the in-app Preview scanner:

| Tab | What they get |
|-----|----------------|
| **RedMed** | Read-only medical profile from `#d=` |
| **911** | Call 911 + local GPS / what to tell dispatch |
| **Aid** | Roadside aid panes (including Seizure, Hypothermia, Heat) |

Hard rules for that tap surface:

- **All three tabs viewable** — RedMed, 911, Aid. Do not ship a medical-only card.
- **No Edit** on RedMed.
- **No NFC / write / pair UI** — writing is owner-app only after Face ID.
- Keep `card.html` and in-app `PublicCardView` → `ContentView` (scanner session) in sync.

`PublicCardView` is the in-app preview of that same shell (snapshot profile,
`isScannerSession = true`).

## Already restored (simulated)

- `RedMed/NFCView.swift` in the Xcode target
- `AppTab.nfc`, owner tab bar item, My ID bracelet entry points
- `ProfileData.braceletLinked`
- Owner-only: Face ID before simulated write; `braceletLinked` only after success
- Scanners / `#d=` taps: RedMed + 911 + Aid only (no NFC tab, no Edit)

## Real CoreNFC checklist (paid team)

### 1. Paid team + capability

1. Developer portal → App ID `com.redmed.app` → enable **NFC Tag Reading**
2. Xcode → Signing & Capabilities → **Near Field Communication Tag Reading**

### 2. Entitlement + usage string

`RedMed/RedMed.entitlements`:

```xml
<key>com.apple.developer.nfc.readersession.formats</key>
<array>
    <string>NDEF</string>
</array>
```

`RedMed/Info.plist` (usage only — never put `com.apple.developer.*` here):

```xml
<key>NFCReaderUsageDescription</key>
<string>RedMed writes your emergency card to your NFC bracelet.</string>
```

### 3. Wire real write

Replace `NFCWriteOverlay`’s `Task.sleep` demo with `NFCNDEFWriterSession`
(and optional read-back). Simulator still cannot do NFC — keep the demo path
under `#if targetEnvironment(simulator)` if useful.

### 4. What the band must contain

Write an NDEF URI whose HTTPS page is **`card.html`** with profile in `#d=`
(see `uploads/Services/ProfileLinkBuilder.swift` for the encoding pattern).
After unarchive, confirm on a physical iPhone:

1. Write band from owner app
2. Tap with a second phone (Safari) → RedMed, 911, and Aid all switchable
3. No edit controls; profile matches last write

Historical references: branch `nfc` (frozen at `80185c6`); earlier park commit
`7a0fbc6`.
