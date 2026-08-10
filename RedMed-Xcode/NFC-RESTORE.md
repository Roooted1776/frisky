# Restoring the NFC bracelet feature

NFC was removed from the app because **Near Field Communication Tag Reading
requires a paid Apple Developer Program membership** — it is not available to
free personal teams. This file is the checklist for putting it back once that
membership is active.

Nothing was thrown away. The full feature is preserved two ways:

- **Branch `nfc`** — a snapshot of `main` at commit `80185c6`, with every NFC
  file intact, including the `fullScreenCover` change to `NFCView.swift`.
- **Commit `7fcc66a`** — the removal, written as one self-contained commit
  against that same point, so it can be reverted cleanly.

## 1. Bring the code back

```sh
git revert 7fcc66a
```

One command. Prefer this over merging the `nfc` branch — `nfc` is frozen at
`80185c6` and `main` moves on, so merging it will conflict on files that have
changed since. Use `nfc` only as a read-only reference.

That restores `NFCView.swift`, `NFCView.inactive.swift`, the target membership,
`AppTab.nfc`, the tab bar item, `ProfileData.braceletLinked`, the MyIDView
bracelet entry points, and the bracelet copy in `PublicCardView` /
`EmergencyView` / `Info.plist`.

The longer `main` runs without NFC, the more the revert will conflict. If it
gets messy, the removal commit is still the best description of what to undo —
read it as a checklist rather than fighting the merge.

## 2. Fix the entitlement — it was in the wrong file

This part the revert does **not** get right, and it is very likely why NFC never
worked before.

`com.apple.developer.nfc.readersession.formats` was sitting in `Info.plist`.
`com.apple.developer.*` keys are **entitlements**, not Info.plist keys — it did
nothing there. After reverting, delete it from `RedMed/Info.plist` and put it in
`RedMed/RedMed.entitlements`, which is currently an empty `<dict/>`:

```xml
<key>com.apple.developer.nfc.readersession.formats</key>
<array>
    <string>NDEF</string>
</array>
```

## 3. Add the missing usage string

`NFCReaderUsageDescription` is required in `RedMed/Info.plist` for
`NFCNDEFReaderSession`, and it is not currently there. Without it the reader
session fails at runtime:

```xml
<key>NFCReaderUsageDescription</key>
<string>RedMed writes your emergency card to your NFC bracelet.</string>
```

## 4. Enable the capability

1. Developer portal → Certificates, Identifiers & Profiles → your App ID
   (`com.redmed.app`) → enable **NFC Tag Reading**.
2. Xcode → target `RedMed` → Signing & Capabilities → **+ Capability** →
   **Near Field Communication Tag Reading**.
3. Let Xcode regenerate the provisioning profile.

## 5. Activate the real implementation

`NFCView.swift` is the UI-only stub — the write button is disabled and
`beginWrite()` is a no-op. The working CoreNFC implementation is
`NFCView.inactive.swift`, which is **not** in the Xcode target.

Copy `NFCView.inactive.swift` over `NFCView.swift` (drop its 10-line header
comment). Do not add both to the target — they each define `NFCView` and
`NFCWriteOverlay`.

Note that the restored implementation is still a **demo**: `NFCWriteOverlay`
simulates a successful write with a 2-second `Task` rather than running a real
`NFCNDEFWriterSession`, and `beginWrite()` has a comment marking where `LAContext`
biometric auth belongs. Wiring up real CoreNFC is step 6, and it needs a physical
iPhone — NFC does not work in the Simulator.
