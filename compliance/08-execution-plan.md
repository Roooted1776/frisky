# 8. Execution plan — the five moves that leave this repo

**Document ID:** RM-EXEC-001
**As of:** 2026-08-10
**Covers:** sign intended purpose → appoint CSO → Cyber Essentials + pen test →
WCAG audit → fill refreshed DTAC for a real buyer.

Everything in `compliance/` up to now is paper you can write alone. These five
are the ones that need a signature, a hire, an invoice, or a buyer. This file is
the driver: what to send, to whom, what comes back, and where it lands.

Costs are **indicative bands for UK suppliers, not quotes**, and pricing moves.
Confirm current figures with the body / firm before budgeting.

---

## Gate 0 — freeze the scope first (blocks Move 1)

**Do not sign RM-IP-001 until you decide which source tree ships.** The repo
currently holds two, and they are not the same product.

| | `RedMed-Xcode/RedMed/` (in the Xcode project) | `uploads/` (staged, **0 files referenced by `RedMed.xcodeproj`**) |
|---|---|---|
| Profile storage | In-memory only (`ProfileData` is `@Published` with demo defaults; no `UserDefaults`, no Keychain, no files) | `KeychainStore` / `ProfileStore` — `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` |
| NFC | Entitlement + `NFCReaderUsageDescription` commented out; write is a local demo overlay | `NFCReader` / `NFCWriter` |
| Motion | None | `MotionAssistMonitor` — CoreMotion, 2.8 g peak + 1.2 s sustain heuristic |
| SOS | Manual dial only | `EmergencySOSController` — 8-second countdown state machine |
| Network egress | None | `ThirdPartyEmergencyClient` — HTTPS POST of name, blood type, allergies, conditions, medications, GPS to a caller-supplied URL (no-op while `AppConfig.thirdPartyEmergencyAlertURL` is empty) |

The compliance pack was written against the **left** column, and is accurate for
it. If `uploads/` merges, four of the five moves below change materially:

- **Intended purpose** — a motion heuristic that fires an alert sits much closer
  to *monitoring* than "store, display, assist dial". Reopen RM-IP-001 before,
  not after.
- **DPIA / lawful basis** — "no RedMed servers, nothing leaves the device" stops
  being true the moment that POST URL is configured. Special category data
  (health) to a third-party endpoint needs its own controller/processor
  analysis, a transfer position, and a named recipient in the privacy notice.
- **Pen test** — adds network egress, Keychain at rest, and NFC read/write to
  the target list. Different scope, different quote.
- **DTAC** — the technical and IG answers are written from the shipping tree.

**Decision required (owner: founder / product):**

- [ ] Ship the current Xcode tree as-is for the first buyer conversation → sign against it, keep `uploads/` out.
- [ ] Merge `uploads/` first → re-run steps 1–3 of the pack against the merged build **before** signing anything.
- [ ] Record the decision and the commit SHA in the table at the bottom of this file.

Baseline at time of writing: `03d85eb` (`main`).

---

## Critical path

```
Gate 0 (scope freeze)
   └─> Move 1  Sign RM-IP-001            ── gates ──> Move 2, Move 5
          └─> Move 2  Appoint CSO         ── gates ──> Move 5
   ├─> Move 3a Cyber Essentials  ─┐
   ├─> Move 3b Pen test          ─┼─ all three run in parallel ─> Move 5
   └─> Move 4  WCAG audit        ─┘
```

Moves 3a, 3b and 4 depend only on Gate 0. **Start them the same week you sign** —
they are the long-lead items, and Move 5 cannot close without them.

| Move | Owner | Blocks on | Indicative lead time |
|------|-------|-----------|----------------------|
| 1 Intended purpose signed | Founder / product | Gate 0 | Same day |
| 2 CSO appointed | Founder | Move 1 | 3–8 weeks to contract, then 2–4 weeks to first safety case |
| 3a Cyber Essentials | Ops / founder | Gate 0 | 1–3 weeks (self-assessment); CE Plus adds 2–6 weeks |
| 3b Pen test | Eng | Gate 0, test build | 2–4 weeks to schedule, 1–2 weeks to report, + retest |
| 4 WCAG 2.2 AA audit | Product | Gate 0, test build | 2–4 weeks to schedule, 2–3 weeks to report |
| 5 DTAC for a named buyer | Founder | 1–4 + a buyer | Buyer's clock |

---

## Move 1 — Sign the intended purpose

**Artifact:** [`01-intended-purpose-mhra.md`](01-intended-purpose-mhra.md) (RM-IP-001).

The document is written and needs no further drafting. Signing means three
things, and the third is the one people skip:

1. Fill the sign-off table with real names and dates.
2. Bind it to a build — record the commit SHA and version so "signed" means
   signed against *something*. A signature with no build reference cannot be
   defended when a buyer asks what changed.
3. Accept the claim control as a live constraint: every App Store string,
   landing page, pitch deck and UI label now gets checked against the allowed /
   banned phrase lists before it ships. That is the actual cost of signing.

**Cost:** nil, unless you take the recommended counsel pass (£500–£1,500 for a
short regulatory-positioning review; optional now, expected before NHS sales).

**Done when:** table filled, SHA recorded, and someone owns the claim review.

---

## Move 2 — Appoint a Clinical Safety Officer

**Artifacts:** [`02-dcb0129/cso-engagement-brief.md`](02-dcb0129/cso-engagement-brief.md)
(send this out), [`cso-appointment.md`](02-dcb0129/cso-appointment.md) (fill on
signature).

This is the longest pole and the one that cannot be faked. A named, competent
CSO is what turns the hazard log from a seed list into a scored artifact a trust
can run DCB0160 against.

**Where they come from:** clinical safety consultancies that supply fractional
CSOs to health-tech suppliers; independent clinicians (often NHS informatics or
digital clinical safety leads) contracting part-time; a clinical advisor already
in your network who holds the competence.

**What you are buying:** hazard log scoring against an agreed severity /
likelihood matrix, residual risk acceptance, a clinical safety case report for a
named build, and a release veto. Ten seeded hazards (H01–H10) are waiting for
them in [`hazard-log.md`](02-dcb0129/hazard-log.md).

**Cost:** fractional CSO day rates commonly £600–£1,200/day; initial engagement
for a product this size is typically 3–6 days spread over the first months, then
a small retainer per release that touches emergency flows.

**Done when:** appointment table filled, hazard log fully scored with residual
risk accepted, safety case report signed against a named build.

---

## Move 3a — Cyber Essentials

**Artifacts:** [`04-tech-cyber/cyber-essentials.md`](04-tech-cyber/cyber-essentials.md),
[`asset-inventory.md`](04-tech-cyber/asset-inventory.md) (fill before you start
the questionnaire).

CE certifies the **organisation**, not the app binary. The certifying body is
IASME, via accredited certification bodies. Self-assessment first; CE Plus is a
hands-on technical audit on top and is what NHS supplier conversations usually
want.

The single thing that stalls first-time applicants is not knowing their own
scope. Fill the asset inventory before you open the questionnaire — every
endpoint, every cloud tenancy, every account that can reach source or signing
keys, and the patch / MFA position for each.

**Cost:** self-assessment is size-banded — a micro-entity sits at the bottom of
the range (roughly £300–£600 + VAT). CE Plus is quoted per scope and commonly
runs £1,400–£3,000+.

**Done when:** certificate PDF exists, stored in a private evidence store (not
git), with its expiry diarised — CE is annual.

---

## Move 3b — Penetration test

**Artifacts:** [`04-tech-cyber/pen-test-rfp.md`](04-tech-cyber/pen-test-rfp.md)
(send this to firms for quotes), [`pen-test-scope.md`](04-tech-cyber/pen-test-scope.md).

Send the RFP to three CREST-member firms for comparable quotes. NHS buyers who
care will ask for CREST or CHECK-equivalent; a cheap unaccredited test tends to
fail the procurement question even when the testing was fine.

Scope depends entirely on Gate 0. The current shipping tree is a genuinely small
target — no backend, no persistence, no network calls — and should price near
the bottom of the range. The `uploads/` tree is a materially larger one.

**Cost:** UK day rates commonly £900–£1,500. A mobile app plus small corporate
estate is typically 3–8 days plus reporting, so roughly £4,000–£12,000, with
retest of highs/criticals often included or lightly charged.

**Done when:** report on file, remediation tracker with dates, highs and
criticals retested and closed, executive summary suitable to attach to DTAC.

---

## Move 4 — WCAG 2.2 AA audit

**Artifact:** [`05-accessibility-wcag/audit-brief.md`](05-accessibility-wcag/audit-brief.md)
(the auditor pack — screens, assistive-tech matrix, what to hand over).

Expect this to come back worse than the pack currently implies. Two measured
facts about the shipping tree:

- **Zero** `accessibility*` modifiers across all of `RedMed-Xcode/RedMed/*.swift`.
  The existing note in `05-accessibility-wcag/README.md` saying labels and hints
  are "already used" is true of `uploads/` only — nine files there carry them —
  and not of what ships. That note is now corrected.
- Hard-coded `.system(size:)` in nine files, down to **9 pt**. Fixed sizes that
  small are a Dynamic Type and 1.4.4 finding on sight.

Budget remediation time, not just audit time. Fixes go in a **product PR**, not
this docs pack — that rule stands.

**Cost:** an external WCAG 2.2 AA audit of a mobile app with this screen count
commonly runs £3,000–£8,000; retest after remediation is usually a smaller
follow-on fee.

**Done when:** report received, criticals fixed and shipped, retest statement on
file, remediation log dated.

---

## Move 5 — Fill the refreshed DTAC for a real buyer

**Artifacts:** [`06-dtac/README.md`](06-dtac/README.md),
[`submission-worksheet.md`](06-dtac/submission-worksheet.md) (now pre-filled
with everything knowable from the repo — remaining blanks are all external).

DTAC is per buyer and per procurement. There is no badge, and filling one
speculatively with no buyer on the other end is wasted effort. Use the
**refreshed** NHS England form only; the old one retired 6 Apr 2026.

Sequence: get a buyer (see [`07-buying-routes.md`](07-buying-routes.md)) → ask
which form version and which supporting annexes they want → transfer the
worksheet answers → attach evidence from Moves 1–4 → record version and build
hash on the form.

**Cost:** nil beyond your own time, plus whatever the buyer's IG and clinical
safety review pulls out of you.

**The honesty rule still governs:** anything not done is "planned" with a date.
A half-empty DTAC with dated commitments survives buyer scrutiny. An
optimistically-filled one does not survive the follow-up questions.

---

## Evidence register

Fill as each move lands. Certificates and reports go in a **private** evidence
store; this table records that they exist and where.

| # | Evidence | Status | Date | Location / reference |
|---|----------|--------|------|----------------------|
| 1 | RM-IP-001 signed | Not started | | |
| 2 | CSO contract + appointment record | Not started | | |
| 2 | Hazard log scored, residual risk accepted | Not started | | |
| 2 | Clinical safety case for named build | Not started | | |
| 3a | Cyber Essentials certificate | Not started | | |
| 3a | Cyber Essentials Plus certificate | Not started | | |
| 3b | Pen test report + retest statement | Not started | | |
| 4 | WCAG 2.2 AA audit report | Not started | | |
| 4 | A11y remediation log + retest | Not started | | |
| 5 | Refreshed DTAC submitted | Not started | | |

## Scope-freeze record

| Field | Value |
|-------|-------|
| Decision (Gate 0) | _TBD_ |
| Commit SHA signed against | _TBD_ |
| Version / build | _TBD_ |
| Decided by | _TBD_ |
| Date | _TBD_ |

Re-open this file whenever a release changes emergency flows, sensors, storage,
network egress, or claims. Any of those invalidates a signature above.
