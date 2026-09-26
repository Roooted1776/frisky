# Owner parked capabilities (Phase 4)

Keep these **false / empty** until paid Apple Developer Program + portal capabilities exist. Do not flip flags in a Cloud Agent Linux session.

| Switch | Location | Restore |
|--------|----------|---------|
| `nfcHardwareEnabled = false` | `owner/RedMed/AppConfig.swift` | [`NFC-RESTORE.md`](NFC-RESTORE.md) |
| `associatedDomainsEnabled = false` | `AppConfig.swift` | [`associated-domains-restore.md`](associated-domains-restore.md) |
| `healthKitImportEnabled = false` | `AppConfig.swift` | [`healthkit-restore.md`](healthkit-restore.md) |
| Empty entitlements dict | `owner/RedMed/RedMed.entitlements` | Flip with flags in lockstep |
| No `NFCReaderUsageDescription` | `Info.plist` | With NFC restore |
| `appStoreURL = nil` | `AppConfig.swift` | After Connect URL exists |

## Prove before storefront “write from the app”

1. Portal Tag Reading on `com.redmed.app`
2. In-repo flag + entitlement + usage string together
3. Device Write The Band on blank **NTAG216** with read-back verify
4. `node scripts/test-nfc-hardware.mjs` → 51/51
5. Associated Domains only after AASA is live JSON on `https://redmed.live`

Until then: blank chips + Share honesty only ([`ADVERTISING.md`](ADVERTISING.md)).
