# 6. DTAC — refreshed NHS England form

**Use:** refreshed DTAC (post Feb 2026). **Do not** use the old form after
**6 Apr 2026**.

Official entry point:
https://transform.england.nhs.uk/key-tools-and-info/digital-technology-assessment-criteria-dtac/
(also linked from NHS Innovation Service news, Mar 2026).

DTAC is completed **per buyer / procurement**. There is no central “DTAC
certified” badge.

## Evidence map (attach to the form)

| DTAC domain (typical) | RedMed evidence |
|-----------------------|-----------------|
| Clinical safety | `../02-dcb0129/` — CSO appointment, CRMP, hazard log, safety case |
| Data protection / IG | `../03-data-protection/` — DPIA, lawful basis, UK notice, DSPT if required |
| Technical security | `../04-tech-cyber/` — CE/+, pen test, MFA narrative, NCSC mapping |
| Usability / accessibility | `../05-accessibility-wcag/` — audit + fixes |
| Interoperability | Mostly N/A today (no NHS Spine / FHIR EHR). State on-device + NFC NDEF / URL card explicitly |
| Intended purpose / medical device | `../01-intended-purpose-mhra.md` — non-device posture |

## Supplier checklist before submitting

- [ ] Intended purpose signed
- [ ] Named CSO + safety case for **this** app version
- [ ] DPIA reviewed
- [ ] Privacy notice matches shipping behaviour
- [ ] CE certificate (Plus if buyer asks)
- [ ] Pen test report (or scheduled with date)
- [ ] WCAG 2.2 AA audit (or scheduled with honest interim)
- [ ] Form filled on **refreshed** template only
- [ ] Version / release hash recorded on the form

## Honesty rule

If a control is “planned”, say planned with a date. Buyers smell fiction.
