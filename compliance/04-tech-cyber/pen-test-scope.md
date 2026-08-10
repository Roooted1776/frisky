# Penetration test — proposed scope

## In scope

- iOS app threat model: local data at rest, Keychain/biometrics, clipboard GPS,
  NFC NDEF contents, URL/deep link handlers, backup exposure
- Companion web card / hosted static pages if used for NFC payload rendering
- Company GitHub, CI, signing certificates, secrets handling
- Any API endpoints if/when added (none for profile storage today)

## Out of scope (until they exist)

- RedMed multi-tenant cloud API
- NHS network connectivity / HSCN

## Deliverables buyers want

- Remediations tracker
- Retest of highs/criticals
- Executive summary suitable to attach to DTAC / PAQ

Commission an CREST / CHECK-equivalent firm if the buyer requires it.
