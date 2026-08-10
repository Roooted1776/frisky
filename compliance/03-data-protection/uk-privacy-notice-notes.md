# UK privacy notice + terms — drafting notes

Bundled/published copies: `PrivacyPolicy.html` and `TOS.html`, kept byte-identical in
three places — repo root, `RedMed-Xcode/RedMed/` (iOS bundle), and
`code_and_design/RedMed-Xcode/RedMed/`. Edit one, copy to all three.

## Status: UK rewrite landed (v2.0, Aug 2026) — counsel review still outstanding

Both documents were rewritten from US-default framing to UK law. **This is a
solicitor-ready draft, not a solicitor-approved document.** Both footers say so.

## Must-have UK GDPR / DPA 2018 blocks

| # | Block | State |
|---|-------|-------|
| 1 | Identity and contact of controller | Structure in place; **entity placeholders unfilled** |
| 2 | Categories of personal data (health = special category) | Done — Policy §3 |
| 3 | Purposes + lawful bases (Art. 6 and Art. 9) | Done — Policy §4, Art. 6(1)(a)/(b) + Art. 9(2)(a) |
| 4 | Recipients | Done — Policy §8 |
| 5 | Retention and deletion | Done — Policy §10 |
| 6 | International transfers | Done — Policy §9, IDTA / UK–US data bridge for Maps |
| 7 | Rights + ICO complaint route | Done — Policy §11, ICO address and helpline |
| 8 | Automated decision-making: state none | Done — Policy §12 |
| 9 | NFC world-readable warning | Done — Policy §6, kept prominent |
| 10 | Children / guardian use | Done — Policy §14, MCA 2005 referenced |
| 11 | PECR local storage position | Done — Policy §13, strictly-necessary exemption |

## What changed in the Terms

US consumer-contract boilerplate does not survive contact with UK law. Removed or
reworked:

- **Liability exclusion for "loss of life, personal injury"** — void under
  Consumer Rights Act 2015 s.65 and UCTA 1977 s.2(1). Replaced with an express
  non-exclusion list (death/personal injury by negligence, fraud, CRA statutory
  rights, Consumer Protection Act 1987).
- **"As is / no warranties / merchantability"** — cannot displace CRA 2015
  ss.34–36 for digital content or ss.9–11 for goods. Replaced by a positive
  statutory-rights section and a narrower availability disclaimer.
- **Broad consumer indemnity incl. "attorneys' fees"** — on the CRA 2015 Sch. 2
  grey list. Narrowed to business users.
- **Good Samaritan statutes** → Social Action, Responsibility and Heroism Act
  2015 s.4, with the England-and-Wales-only caveat stated.
- **Vague governing law** → England and Wales, preserving the consumer's right to
  their home-nation courts.
- **Added:** trader disclosure (Companies Act 2006 / E-Commerce Regs 2002),
  14-day cancellation and 30-day right to reject for bands, ADR signposting,
  UK MDR non-device statement.
- **999 / 112** replace 911 in all advisory copy; NHS 111, Relay UK 18000, 999
  BSL and emergency SMS added for non-voice users.

## Open — must be filled before publication

- [ ] Registered company name, number, registered office, VAT number
- [ ] ICO registration number + data protection fee paid (Data Protection
      (Charges and Information) Regulations 2018)
- [ ] Named ADR provider, or a statement that none is used
- [ ] Solicitor pass on both documents
- [ ] Confirm Google Maps transfer route actually in use (IDTA vs UK–US data
      bridge) if a Maps key is ever configured

## Claim hygiene vs product — reconciled twice

**v2.0 (at commit `c741c3e`).** The v1.1 notice asserted safeguards that did not
exist in the shipping tree: Keychain storage, a salted PBKDF2 PIN digest, "Clear
All Data", and browser `localStorage`. All verified absent at the time — the
shipping `ProfileData` was an in-memory object with hard-coded demo values. Those
claims were removed rather than restated.

**v2.1 (after `d9ee1a4`, "Fix profile persistence, NFC stubs, and related bugs").**
That commit landed *after* the notice merged and changed the facts underneath it:

| Change | Effect on the notice |
|--------|----------------------|
| `KeychainStore` + `ProfileData.persist()` now in the shipping tree | §5 was **understating** a good control. Now states Keychain, `WhenUnlockedThisDeviceOnly`, and exclusion from iCloud/backups. |
| Demo values replaced with empty fields on first launch | "only what you choose to enter" is now literally true. Added to §15. |
| Profile now survives app restart | §10 and §11 rewritten — erasure is a real operation now, where before there was nothing to erase. |

Once the `uploads/` decision in [`../08-execution-plan.md`](../08-execution-plan.md)
is made, revisit §5, §10 and §15 again — if `uploads/` ships, **§9 must be
rewritten**, because `ThirdPartyEmergencyClient` posts special category data
off-device.

## Erasure gap — Art. 17 asserted, not implemented

`KeychainStore.delete(account:)` exists and is **never called from anywhere**.
There is no "Clear All Data" control in the shipping UI.

Today a user can only erase by blanking every field and saving (which overwrites
the stored blob) or by deleting the App (which drops its Keychain entry on iOS
10.3+). The notice now describes exactly that, and no more. But "delete the whole
app" is a poor answer to a right-to-erasure request, and an IG reviewer will say
so.

**Product fix:** wire a Clear All Data control to the existing
`KeychainStore.delete` and clear the `@Published` fields. Small, and it closes an
Art. 17 gap on special category data. Not done here — this pack does not change
app code.

Notice must not imply clinical diagnosis, monitoring, or NHS care delivery. Aligned
with [`../01-intended-purpose-mhra.md`](../01-intended-purpose-mhra.md).

## Product blocker surfaced by this rewrite

The Terms and Policy now tell UK users to call **999**. The app does not.
`tel://911` is hard-coded in four places in the shipping tree — `AidView.swift:50`,
`TopicDetailView.swift:158`, `EmergencyView.swift:166` and `:349` — plus
`EmergencyView.swift:12` for contact dialling, and the feature is named "Find 911"
throughout the UI. On a UK handset `tel://911` does not reach the emergency
services.

Legal copy cannot fix this. It needs a product change: locale-aware emergency
number, or a UK build. Until then the documents are accurate about the law and
optimistic about the software. **Do not publish to UK users, and do not put these
documents in front of an NHS buyer, until the dialler is locale-aware** — an IG
reviewer who taps through the app will find it.
