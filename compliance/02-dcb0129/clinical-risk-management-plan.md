# Clinical risk management plan (CRMP)

**Document ID:** RM-CRMP-001  
**Standard:** DCB0129  
**Product:** RedMed  
**Intended purpose:** see `../01-intended-purpose-mhra.md`  
**CSO:** _TBD_  
**Version:** 0.1 draft

## 1. Scope

Clinical risk management for manufacture of RedMed health IT: iOS app, on-device
profile storage, NFC write/read of emergency ID, Find Help location display,
seizure timer assist, roadside first-aid reference content.

Out of scope until purpose changes: diagnosis, treatment algorithms, NHS EPR
integration, remote monitoring.

## 2. Organisation

| Role | Responsibility |
|------|----------------|
| CSO | Clinical risk authority; hazard log; safety case |
| Product owner | Scope / intended purpose control; release gating |
| Engineering | Implement agreed controls; no silent claim drift |
| Support | Incident intake for clinical incidents |

## 3. Process

1. **Hazard ID** — workshops on new features, claim changes, incidents.
2. **Estimate** — severity × likelihood (CSO method; record in hazard log).
3. **Control** — eliminate / reduce / inform; prefer design over warning text.
4. **Residual risk** — CSO accepts or rejects before release.
5. **Monitor** — post-market: App Store reviews, support tickets, near misses.
6. **Change control** — any feature touching health claims or emergency flows
   re-enters hazard analysis before ship.

## 4. Risk acceptability

Define thresholds with the CSO (example placeholder — replace):

| Residual risk | Action |
|---------------|--------|
| Low | Accept with monitoring |
| Medium | Accept only with documented justification |
| High / intolerable | Do not release |

## 5. Configuration

Safety case and hazard log are versioned with product releases. Tag app builds
that are covered (e.g. App Store version / git tag).

## 6. Related documents

- Intended purpose RM-IP-001
- Hazard log RM-HL-001
- Clinical safety case report RM-CSCR-001
