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

## Doc vs product mismatches to fix in a *legal* PR later (not this pack)

- Privacy/ToS still describe some SOS/motion behaviours that may not match the
  current Find 911 UI. Reconcile copy with shipping app before NHS or UK launch.
- Location gate / permission UX should match what the notice promises.

## Action

Counsel produces UK notice version; product owner publishes without changing
Swift until a dedicated copy PR.
