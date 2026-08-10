# 1. Intended purpose (MHRA / UK MDR)

**Document ID:** RM-IP-001  
**Status:** Draft for sign-off  
**Date:** 2026-08-10  
**Product:** RedMed iOS app + passive NFC emergency ID bracelet  
**Decision owner:** [Name / role — required before NHS sales]

---

## Decision

RedMed’s **intended purpose** is:

> Store and display self-reported emergency medical identification on the user’s
> device and, if they choose, on a passive NFC bracelet; and assist the user in
> contacting emergency services (SOS assist) by showing location/context tools
> and general public first-aid reference.

RedMed **is not** intended to:

- diagnose any condition;
- treat, cure, or manage disease;
- provide clinical decision support that recommends, prioritises, or selects a
  diagnosis or treatment for an individual;
- replace NHS 111, 999, or professional clinical judgement;
- operate as a medical device under UK MDR / UKCA for the current scope.

**Classification posture:** non-medical-device consumer / wellness-adjacent
emergency ID software **provided intended purpose and marketing stay inside this
document**. If marketing or features drift into clinical decision support, stop
and reassess under UK MDR before release.

---

## What the product does (in-scope)

| Capability | Purpose language (allowed) | Forbidden drift |
|------------|----------------------------|-----------------|
| Medical profile on device | Store / display emergency ID | “Detects conditions”, “clinical record of truth” |
| Passive NFC band | Share emergency ID on tap | “Monitors patient”, “alerts clinicians automatically” |
| Find 911 GPS | Show coordinates so user can tell 999/911 | “Locates trauma pathway”, “dispatch recommendation” |
| Seizure timer | Help user time an event; prompt to call at 5:00 | “Detects seizures”, “diagnoses epilepsy” |
| Roadside Aid / CPR timer | General public first-aid information | Personalised treatment plan, triage algorithm |
| Call / dial assist | Help user open Phone to call emergency services | Automated clinical triage |

---

## Regulatory logic (blunt)

- MHRA cares about **claims + function**, not your App Store category.
- UK MDR medical device includes software with a medical purpose (diagnosis,
  prevention, monitoring, prediction, prognosis, treatment, alleviation).
- Pure **storage/display of user-entered ID** plus **general information** stays
  outside that fence **if you do not claim medical purpose**.
- “Assist SOS” (dial, show GPS, timer) is assistive logistics — keep it that way.
- Crossing into **CDS** (rules that recommend what to do for *this* patient) =
  UK MDR / UKCA path. Do not DIY that jump.

This document is the control. Marketing, App Store text, sales decks, and
in-app copy must match it.

---

## Claim control

**Allowed phrases**

- Emergency medical ID / bracelet
- Store and share your emergency information
- Help you call emergency services
- General first-aid information
- Not a medical device; not a substitute for 999 / 911

**Banned phrases (unless MHRA path is opened)**

- Diagnoses / detects / predicts [condition]
- Treats / manages [condition]
- Clinical decision support / triage / risk score for care
- “Prescribed by” / “clinically validated treatment”
- Replaces clinician / ambulance decision-making

**Review cadence:** any App Store, website, pitch, or UI string that touches
health claims → check against this file before ship.

---

## Sign-off

A signature is only meaningful against a **named build**. Fill the binding
first, then sign. See [08-execution-plan.md](08-execution-plan.md), Move 1 — and
settle Gate 0 before you sign, because the staged `uploads/` tree would change
the answers on this page.

**Build binding**

| Field | Value |
|-------|-------|
| Source tree signed against | _TBD — `RedMed-Xcode/` or merged `uploads/`_ |
| Commit SHA | _TBD_ |
| Release version / build | _TBD_ |

**Signatures**

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Product / founder | | | |
| Clinical Safety Officer (once appointed) | | | |
| Legal counsel (recommended before UK NHS sales) | | | |

Signing also accepts the claim control above as a live constraint: App Store
copy, website, decks and UI strings get checked against the allowed / banned
phrase lists before ship, and someone owns that check.

Revisit this decision if you add: automated triage, condition detection from
sensors, clinician workflow, NHS Spine / EPR write-back, or treatment dosing.
