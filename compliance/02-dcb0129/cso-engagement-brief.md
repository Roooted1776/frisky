# CSO engagement brief — send to candidates

**Document ID:** RM-CSO-002
**Purpose:** outbound brief for clinical safety consultancies and independent
clinicians. Fill the bracketed fields, then send. Pairs with
[`cso-appointment.md`](cso-appointment.md), which is the internal record filled
on signature.

---

## The product in one paragraph

RedMed is a native iOS app plus a passive NFC bracelet. The user types their own
emergency medical information — name, blood type, allergies, medications,
conditions, emergency contacts, organ donor status — and it is stored and
displayed on their device. A rescuer can tap the bracelet with any phone to see
that card without installing anything. The app also has a GPS screen the user
reads coordinates from when calling emergency services, a manually-started
seizure stopwatch that prompts a call at 5:00, and a general public first-aid
reference section.

It does not diagnose, treat, triage, or recommend care for an individual, and it
holds no clinical record. There is no RedMed server: nothing is transmitted to
us. The intended purpose is controlled by a signed document (RM-IP-001) that
also bans specific marketing claims.

## What we need from you

A named Clinical Safety Officer under **DCB0129** (manufacture of health IT
systems). Deploying trusts will run DCB0160 on their side; we are the
manufacturer.

Deliverables:

| # | Deliverable | Notes |
|---|-------------|-------|
| 1 | Agreed severity / likelihood matrix | We have not set scales — that is your call |
| 2 | Scored hazard log | Ten hazards seeded (H01–H10); expect to add and re-cut them |
| 3 | Residual risk acceptance | Documented, per hazard |
| 4 | Clinical safety case report | Against a named build, not "the app" in general |
| 5 | Release review | For any change touching emergency flows, sensors, storage, or claims |

You hold a veto on releases that change clinical risk without controls, and a
route to escalate to leadership independently.

## The hazards already on the table

Seeded from actual product behaviour, unscored, waiting for you:

1. Outdated or wrong self-reported profile shown to a rescuer.
2. Passive NFC chip readable by anyone who taps it — by design, no encryption.
3. User delays calling 999/911 because the app feels like it is doing something.
4. GPS wrong or unavailable when the user reads it to a dispatcher.
5. Seizure timer mistaken for seizure *detection*; or the 5:00 dial prompt firing unexpectedly.
6. First-aid reference content stale or misapplied.
7. Marketing drifting into diagnosis or treatment claims.
8. Rescuer-side scanner session reaching owner edit controls.
9. Permission or launch gating delaying emergency use.
10. No server means no remote wipe of a lost bracelet.

Full log with causes, harms and current controls:
[`hazard-log.md`](hazard-log.md).

## Competence we are looking for

- Clinical risk management experience for health IT, as a clinician or through
  equivalent hands-on DCB0129 practice.
- Comfortable signing a safety case for a **consumer-facing, non-device**
  product — this is deliberately not a CDS tool, and the safety argument is
  about misuse, over-reliance, and stale data rather than algorithm accuracy.
- Willing to be named in DTAC submissions and in the safety case report.
- Independent enough to say no.

Registration with a clinical body is welcome but we are not treating any single
named training course as a hard gate — competence and the willingness to sign
are what matter.

## Shape of the engagement

- **Model:** fractional / contract, not employment.
- **Initial effort:** we estimate 3–6 days to reach a signed safety case, spread
  over the first weeks.
- **Ongoing:** light retainer, triggered per release that touches emergency
  flows, sensors, storage, network behaviour, or claims.
- **Rate:** _[insert your budget or ask for theirs]_
- **Start:** _[date]_

## What we will give you on day one

- This repo's `compliance/` folder in full — intended purpose, clinical risk
  management plan, hazard log, safety case skeleton, DPIA, lawful basis.
- The iOS source, and a build to run.
- Direct access to the founder; no gatekeeping.
- An honest statement of what is not done yet — see
  [`../00-gap-status.md`](../00-gap-status.md), which is deliberately blunt.

## Things you should know before quoting

- The app currently has **no persistence in the shipping build** — the profile
  lives in memory. A staged branch adds Keychain storage, NFC read/write, a
  motion-triggered assist heuristic, an 8-second SOS countdown, and an optional
  HTTPS POST of profile and location to a third-party endpoint. **Which of these
  ships is an open decision**, and it changes the hazard profile substantially.
  We will tell you which tree you are signing against before you start. See
  [`../08-execution-plan.md`](../08-execution-plan.md), Gate 0.
- We are pre-revenue and pre-NHS-sale. This is groundwork for a first pilot
  conversation, not a live deployment.

## Contact

_[Name, role, email, phone]_

---

Until [`cso-appointment.md`](cso-appointment.md) is filled and signed, RedMed
makes **no** DCB0129 compliance claim in sales material or DTAC.
