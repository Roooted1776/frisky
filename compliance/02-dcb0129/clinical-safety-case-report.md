# Clinical safety case report (skeleton)

**Document ID:** RM-CSCR-001  
**Standard:** DCB0129  
**Product / version:** RedMed iOS _[version TBD]_  
**CSO:** _TBD_  
**Status:** Incomplete — not for buyer submission until CSO signs

## 1. Executive summary

_CSO completes:_ product, intended purpose, residual clinical risk statement,
recommendation (safe to deploy / with conditions / not safe).

## 2. System description

- On-device emergency medical ID storage and display
- Optional passive NFC bracelet programming
- Find Help: location display for user relay to emergency services
- Seizure timer assist (no detection)
- Roadside Aid: general first-aid reference
- Architecture: no RedMed backend; no remote clinical data store

## 3. Intended purpose and contraindications

Pointer: `../01-intended-purpose-mhra.md`.  
Contraindication: use as sole emergency response; use as diagnostic/treatment tool.

## 4. Clinical risk management

Pointer: CRMP + hazard log. Summarise top hazards and residual risk.

## 5. Evidence of controls

List controls actually present (UI copy, disclaimers, session locks). Do not
claim unimplemented controls.

## 6. Testing / validation relevant to safety

Manual scenarios: wrong profile, denied location, offline phone, NFC tap by
stranger, seizure timer at 5:00. Record dates/results when run.

## 7. Outstanding issues

Open hazard rows; claim-control watch items.

## 8. Conclusion and CSO declaration

I, _Name_, Clinical Safety Officer, have reviewed the clinical risk for this
version of RedMed and _accept / do not accept_ residual risk for manufacture
release.

Signature / date: ________
