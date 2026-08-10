# Restoring the NFC bracelet feature

NFC Tag Reading needs a **paid Apple Developer Program membership**.
It is parked until that is active. Do not re-enable entitlements or the
NFC tab on a free personal team.

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

## What is parked on this branch

- `RedMed/NFCView.swift` — on disk, **not** in the Xcode target (header notes why)
- Empty `RedMed.entitlements` (no NFC entitlement)
- No `AppTab.nfc`, no bracelet UI on My ID
- Owner app tabs: RedMed / 911 / Aid only

Historical references (older snapshots):

- Branch `nfc` — frozen at `80185c6`
- Commit `7fcc66a` — earlier self-contained removal (pre–merge-conflict fixes)

Prefer restoring against **current** `main` using the checklist below rather
than a blind `git revert` of `7fcc66a` (the tree has moved on).

## Restore checklist

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

### 3. App wiring

- Add `NFCView.swift` back to the RedMed target
- Restore `AppTab.nfc`, tab bar item, My ID bracelet entry points,
  `ProfileData.braceletLinked`
- Owner-only: Face ID before write; mark `braceletLinked` only after a
  successful write
- Scanners / `#d=` taps: still RedMed + 911 + Aid only (no NFC tab, no Edit)

### 4. What the band must contain

Write an NDEF URI whose HTTPS page is **`card.html`** with profile in `#d=`
(see `uploads/Services/ProfileLinkBuilder.swift` for the encoding pattern).
After unarchive, confirm on a physical iPhone:

1. Write band from owner app
2. Tap with a second phone (Safari) → RedMed, 911, and Aid all switchable
3. No edit controls; profile matches last write

### 5. Real CoreNFC

The parked `NFCView.swift` is still a **demo** overlay (`Task.sleep`). Wire a
real `NFCNDEFWriterSession` (and optional read-back) on device — Simulator
cannot do NFC.
