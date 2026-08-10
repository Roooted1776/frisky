# DPIA — RedMed (UK GDPR Art. 35 style)

**Document ID:** RM-DPIA-001  
**Date:** 2026-08-10  
**Status:** Draft  
**DPO / reviewer:** _TBD_

## 1. Need for a DPIA

Special-category health data (Art. 9) is processed on-device and may be placed on
an NFC chip readable by third parties. High risk to rights if lost/stolen band
or inaccurate data used in an emergency → DPIA appropriate before UK scale-up.

## 2. Description of processing

| Item | Detail |
|------|--------|
| Data | Name, blood type, allergies, meds, conditions, emergency contacts, optional photo; location while Find 911 is open; seizure timer state |
| Subjects | Profile owners; minors via guardian; bystanders who view NFC/web card |
| Purpose | Emergency ID storage/display; SOS assist (location display, dial assist) |
| Controllers | Typically the individual for their own device data; RedMed as app publisher for any residual operator processing (today: none for profile storage) |
| Recipients | Anyone who taps the NFC chip or opens a shared card link; OS vendors for permission prompts; no RedMed server |
| Retention | Until user clears app data / rewrites or discards band |
| International transfers | None by RedMed (no backend). NFC/web card may be read anywhere |

## 3. Consultation

CSO (clinical risk), legal counsel, and if selling to NHS: customer IG lead.

## 4. Necessity / proportionality

Processing is what the user enters for emergency identification. Location is
limited to Find 911 visibility. No advertising use. Proportional **if** claims
stay inside intended purpose and users are warned the chip is world-readable.

## 5. Risks and measures

| Risk | Impact | Measure |
|------|--------|---------|
| Lost bracelet discloses health data | High | Clear Privacy notice; no false “encrypted chip” claim |
| Inaccurate self-report | High | Disclaimers; user duty to update |
| Location over-collection | Medium | When-in-use; stop updates off Find 911 |
| Future cloud sync without notice | High | Block until notice + DPIA update |
| NHS org deployment without DSPT | High | DSPT before trust contracts |

## 6. Decision

_Proceed with UK consumer offering under documented residual risk / proceed only
after counsel review / do not proceed_ — **decision TBD**.

Signed: ________ Date: ________
