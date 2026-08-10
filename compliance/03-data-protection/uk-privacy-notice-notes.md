# UK privacy notice — drafting notes

Existing in-app / bundled notice: `RedMed-Xcode/RedMed/PrivacyPolicy.html`
(and web mirrors). This file is **notes for a UK-facing revision**, not a code
change.

## Must-have UK GDPR / DPA 2018 blocks

1. Identity and contact of controller / publisher; UK contact if targeting UK.
2. Categories of personal data (health = special category).
3. Purposes + lawful bases (Art. 6 and Art. 9).
4. Recipients: anyone who taps the band; OS; no RedMed profile server.
5. Retention and deletion (Clear All Data; rewrite/discard band).
6. International transfers (none by RedMed today — say so).
7. Rights: access, erasure, restriction, objection, complaint to ICO.
8. Automated decision-making: state none (or describe if you add scores).
9. NFC world-readable warning — already present; keep prominent.
10. Children’s / guardian use.

## Claim hygiene vs intended purpose

Notice must not imply clinical diagnosis, monitoring, or NHS care delivery.
Align wording with `../01-intended-purpose-mhra.md`.

## Doc vs product — reconciled 2026-08-10 (copy PR)

Shipping Find 911 (`EmergencyView`): GPS while screen open; seizure stopwatch
that may open `tel://911` at 5:00; **no** motion-assist SOS countdown.
`LocationLaunchGateView` asks When-In-Use before main tabs (system dialog via
`requestWhenInUseAuthorization`). Bundled Privacy/ToS under
`RedMed-Xcode/RedMed/` updated to match; counsel still owes a full UK notice pass.

## Action

Counsel produces final UK notice version on top of the reconciled base; product
owner publishes. No Swift changes required for that publish step.
