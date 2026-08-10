# Hazard log (seed)

**Document ID:** RM-HL-001  
**Product:** RedMed  
**CSO:** _TBD — scores and residual risk are not valid until CSO completes them_

Severity / likelihood scales: define with CSO. Columns below are seeds from
current product behaviour. Do not invent “mitigated in code” claims without
checking the live app.

| ID | Hazard | Cause | Potential clinical harm | Initial risk | Controls (current / planned) | Residual | Status |
|----|--------|-------|-------------------------|--------------|------------------------------|----------|--------|
| H01 | Outdated / wrong profile shown to rescuer | User never updates; wrong person edits | Wrong allergy/meds → harmful treatment by others | _CSO_ | Self-report disclaimer; edit gated; no clinical verification | _CSO_ | Open |
| H02 | NFC chip readable by anyone | Passive design | Privacy breach; stigma | _CSO_ | Informed consent in ToS/Privacy; no chip encryption by design | _CSO_ | Open |
| H03 | User delays calling 999/911 because they use the app | Over-reliance on Aid / timer / GPS | Delayed EMS | _CSO_ | Intended purpose + ToS: call emergency services first; Aid copy | _CSO_ | Open |
| H04 | GPS wrong / unavailable | Permission denied; indoor; OS failure | Dispatcher gets bad location | _CSO_ | Display only while Find Help open; accuracy shown; user reads aloud | _CSO_ | Open |
| H05 | Seizure timer false confidence / unexpected auto-dial | User thinks timer detects seizures; or 5:00 opens Phone unexpectedly | Delayed call or unwanted dial | _CSO_ | No detection claims; manual Start only; copy “→ 911 at 5:00”; opens tel:// only | _CSO_ | Open |
| H06 | First-aid content wrong / misapplied | Stale content; user error | Injury | _CSO_ | General public info disclaimer; not personalised CDS | _CSO_ | Open |
| H07 | Marketing claims diagnosis/treatment | Sales / App Store drift | Regulatory + clinical misuse | _CSO_ | RM-IP-001 claim control; CSO review of marketing | _CSO_ | Open |
| H08 | Scanner sees owner edit UI | Session confusion | Profile tampering | _CSO_ | Scanner session locks edit/NFC write (product behaviour) | _CSO_ | Open |
| H09 | Location prompt / gate blocks emergency use | Auth UX | Delay | _CSO_ | Document UX; keep GPS start only on Find Help | _CSO_ | Open |
| H10 | No RedMed server → no remote wipe of lost band | Architecture | Persistent PII on lost bracelet | _CSO_ | Privacy notice; user education; physical security of band | _CSO_ | Open |

Add rows for every release that changes emergency flows, sensors, or claims.
