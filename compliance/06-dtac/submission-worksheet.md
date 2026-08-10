# DTAC submission worksheet (working copy)

Fill answers offline, then transfer into the official refreshed NHS England
DTAC form. Not a substitute for the real form.

**Pre-filled 2026-08-10** from the shipping tree (`RedMed-Xcode/`) at commit
`03d85eb`. Every remaining `________` is genuinely external — it needs a
signature, a certificate, a report, or a buyer. Confirm the pre-filled answers
still hold against whatever build you actually submit, and re-check them against
the Gate 0 decision in [`../08-execution-plan.md`](../08-execution-plan.md).

## Product

- Name: RedMed
- Version / build: **1.1 (2)** — commit SHA ________ (fill from the actual release
  build; the version alone does not identify what a buyer assessed)
- Supplier legal entity: ________
- Contact: ________
- Intended purpose summary: store/display self-reported emergency medical ID on device and optionally on a passive NFC bracelet; assist the user in contacting emergency services (GPS display, dial assist, manually-started timer); general public first-aid reference
- Medical device?: No (per RM-IP-001) — reassess if purpose changes
- Intended purpose signed by / date: ________ (Move 1)

## Clinical safety

- CSO name: ________ (Move 2)
- CSO registration / competence basis: ________
- DCB0129 artefacts attached: clinical risk management plan ✅ drafted · hazard log ⚠️ seeded, **unscored until CSO** · safety case ⚠️ skeleton
- DCB0160: supplier is manufacturer only; deploying trust runs DCB0160
- Key residual risks: ________ (CSO output — ten hazards seeded as H01–H10, see `../02-dcb0129/hazard-log.md`)

## Data protection

- Data controller: ________ (confirm — user-entered data never reaches us in the shipping build)
- Personal data processed: special category (health) — name, DOB, blood type, allergies, medications, conditions, emergency contacts, organ donor status
- Where it lives: on the user's device only. Shipping build holds it **in memory for the session** — no `UserDefaults`, no Keychain, no file writes, no backend
- Transfers out of the device: **none** in the shipping build. NFC bracelet content is user-initiated and world-readable by design
- International transfers: none
- DPIA attached: Y — `../03-data-protection/dpia.md` (signature ________)
- Lawful basis: see `../03-data-protection/lawful-basis.md`
- UK privacy notice: drafted; **counsel UK pass still open** ________
- DSPT status: N/A / in progress / published (org: ________) — required only if selling into NHS orgs or processing their data
- ICO registration (if required): ________
- Retention / deletion: user-controlled on device; no server-side copy to delete. **No remote wipe of a lost bracelet** (hazard H10)

## Technical security

- Architecture: native iOS 17+ app, no backend, no API, no user accounts
- Cyber Essentials: none / CE / CE+ (cert date ________) — Move 3a
- Pen test date / firm: ________ (Move 3b)
- Remote accounts / MFA: ________ — see `../04-tech-cyber/mfa-and-accounts.md` and the asset inventory
- Authentication in app: device-owner biometric / passcode (`LAContext.deviceOwnerAuthentication`) gates profile edit and bracelet write
- Encryption in transit: N/A in shipping build (no network calls)
- Encryption at rest: OS-level device encryption only; no app-managed store in the shipping build
- NCSC cloud security principles: see `../04-tech-cyber/ncsc-sscop-mapping.md` — largely N/A absent a hosted service; state that plainly rather than answering aspirationally

## Interoperability

- NHS Spine / FHIR / EPR integration: none. No write-back, no clinical record
- NHS login: not used
- Standards: NFC NDEF payload / URL card only
- State explicitly on the form that this is an on-device product with no NHS system integration — do not leave it blank and invite the question

## Accessibility

- WCAG 2.2 AA audit date / firm: ________ (Move 4)
- Current position, honestly: **no external audit yet**; static review only. Shipping tree has zero `accessibility*` modifiers and hard-coded font sizes down to 9 pt
- Open critical issues: ________ (post-audit)
- Accessibility statement published: ________
- Remediation plan / dates: ________

## Buyer

- NHS org: ________
- Procurement route: ________ (see `../07-buying-routes.md`)
- Which DTAC form version they want: ________ (refreshed form only — old one retired 6 Apr 2026)
- Additional annexes requested: ________
- Form submitted date: ________

---

## Honesty check before you send

- [ ] Every blank above is either filled or marked "planned" **with a date**
- [ ] Nothing claims a certificate, audit, or appointment that does not exist
- [ ] The version / SHA on the form matches the build the evidence was produced against
- [ ] The accessibility and clinical safety answers match `../00-gap-status.md`
      rather than a more flattering version of it
