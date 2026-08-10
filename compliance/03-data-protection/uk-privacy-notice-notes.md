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

## Claim hygiene vs product — recheck at Gate 0

The v1.1 notice asserted safeguards that **do not exist in the shipping tree**
(`RedMed-Xcode/`): Keychain storage, a salted PBKDF2 PIN digest, "Clear All Data",
and browser `localStorage` on the web build. Verified absent — the shipping
`ProfileData` is an in-memory `@Published` object with hard-coded demo values, and
`grep` finds no `UserDefaults`, Keychain, `FileManager`, or `localStorage` in either
the iOS tree or `RedMed.html`.

Those specific claims were **removed** rather than restated. The v2.0 text asserts
only what is true in both source trees: data goes to your device and your band, and
never to a RedMed server. Once the `uploads/` decision in
[`../08-execution-plan.md`](../08-execution-plan.md) is made, revisit §5, §10 and §15
of the Policy — if `uploads/` ships, the Keychain and PIN specifics can go back in
and **§9 must be rewritten**, because `ThirdPartyEmergencyClient` posts special
category data off-device.

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
