# Gap status — is RedMed “NHS compliant”?

**Short answer: No.** Not yet. There is no NHS stamp for a consumer App Store
build. NHS buyers expect a completed **DTAC pack** with live evidence. This repo
now has the **templates and programme**; humans still own appointments, audits,
and procurement.

**As of:** 2026-08-10  
**Product basis:** `RedMed-Xcode/` — on-device medical ID, NFC band, Find 911 GPS,
seizure stopwatch (auto-opens `tel://911` at 5:00), roadside Aid. No RedMed
servers. No motion-assist SOS product.

| # | Requirement | Status | Blocker |
|---|-------------|--------|---------|
| 1 | MHRA intended purpose signed (`01-…`) | Draft ready | Founder / product sign-off |
| 2 | DCB0129 CSO + scored hazard log + safety case | Templates only | Appoint Clinical Safety Officer |
| 3 | UK GDPR notice + DPIA + lawful basis | Notice + Terms rewritten to UK law (v2.0) | Fill entity/ICO details; solicitor pass; fix `tel://911` |
| 4 | DSPT | Not started | Only if selling into NHS orgs / processing org data |
| 5 | Cyber Essentials (+), pen test, NCSC mapping | Checklists only | Buy CE; commission pen test |
| 6 | WCAG 2.2 AA external audit | Static notes only | External auditor + remediation PR |
| 7 | Refreshed DTAC form submitted to a buyer | Worksheet only | Complete after 1–6; use post-Apr-2026 form |
| 8 | Buying route / pilot trust | Guidance only | Commercial outreach |

**How to close 1–7:** [08-execution-plan.md](08-execution-plan.md) — sequence,
owners, lead times, indicative costs, and the outbound briefs to send.

## Gate 0 — open decision that blocks the signature

The repo holds **two source trees**, and they are not the same product. The
Xcode project references `RedMed-Xcode/` only; `uploads/` is staged and
unreferenced. `uploads/` adds Keychain persistence, live CoreNFC, a CoreMotion
assist heuristic, an 8-second SOS countdown, and an optional HTTPS POST of
profile + GPS to a third-party endpoint.

This pack is written against the **shipping** tree and is accurate for it. If
`uploads/` ships, the intended purpose, DPIA, pen test scope and DTAC answers
all change. **Decide before signing anything** — see 08-execution-plan.md,
Gate 0.

## Gate 0b — the app dials 911, the UK dials 999

The UK legal rewrite (Aug 2026) landed `PrivacyPolicy.html` and `TOS.html` v2.0
under UK GDPR / DPA 2018 / Consumer Rights Act 2015. Both now tell users to call
**999**. The app still hard-codes `tel://911` — `AidView.swift:50`,
`TopicDetailView.swift:158`, `EmergencyView.swift:166` and `:349` — and the
feature is called "Find 911" throughout the UI.

On a UK handset that number does not reach the emergency services. This is a
**product change, not a copy change**: locale-aware emergency dialling, or a
separate UK build. Until it ships, the legal documents describe software that
does not exist, and no UK user or NHS buyer should be shown either.

See [03-data-protection/uk-privacy-notice-notes.md](03-data-protection/uk-privacy-notice-notes.md).

## What already helps

- Local-only architecture (no profile backend) shrinks IG / cyber surface.
- Explicit non-device / not-medical-advice language in ToS and UI.
- Find 911 GPS starts only while that screen is visible.
- Scanner session separates owner edit/NFC write from public card view.
- Assurance folder under `compliance/` maps 1→7 in order.

## What does **not** count as NHS compliance

- Having privacy HTML in the app bundle
- Saying “not a medical device” without a signed intended-purpose control
- Filling markdown worksheets without a named CSO and buyer-facing DTAC form
- US HIPAA framing alone (UK buyers want UK GDPR / DPA 2018 + ICO rights) — the
  Aug 2026 rewrite closed this, but a UK notice with unfilled entity and ICO
  placeholders is still not a published notice

## Finish line (definition of done for “NHS-ready”)

1. `01-intended-purpose-mhra.md` signed  
2. Named CSO; hazard log scored; clinical safety case for **this** build  
3. Counsel-approved UK privacy notice + Terms live (entity, company number and
   ICO registration filled in); DPIA signed; emergency dialling reaches 999  
4. Cyber Essentials (Plus if asked) + pen test report on file  
5. WCAG 2.2 AA audit + critical fixes shipped  
6. Refreshed DTAC filled for a real buyer with version/hash  
7. Pilot agreement that matches intended purpose (ID + SOS assist, not CDS)

Until then, market as a **consumer emergency ID tool**, not an NHS-assured
product.
