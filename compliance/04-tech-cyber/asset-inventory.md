# Asset inventory — Cyber Essentials scope

**Document ID:** RM-CE-002
**Fill this before opening the IASME questionnaire.** The usual reason a
first-time application stalls is that the applicant cannot describe their own
scope. CE certifies the **organisation**, so everything below is in scope unless
you can justify a boundary — and "we only make an iOS app" is not a boundary.

CE is annual. Diarise the expiry the day the certificate arrives.

---

## Legal entity

| Field | Value |
|-------|-------|
| Certifying entity name | _TBD_ |
| Companies House number | _TBD_ |
| Registered address | _TBD_ |
| Head count (incl. contractors) | _TBD_ |
| Certification body chosen | _TBD_ |
| Self-assessment or Plus | _TBD_ |
| Target date | _TBD_ |

## Endpoints

Every device that touches source, signing keys, email, or customer data —
including personal devices used for work, which CE does not let you exclude.

| Device | Owner | OS + version | Auto-update on | Disk encryption | MFA on account | In scope |
|--------|-------|--------------|----------------|-----------------|----------------|----------|
| _Mac build machine_ | | macOS | | FileVault | | Yes |
| _iPhone test device_ | | iOS | | | | Yes |
| | | | | | | |

## Cloud and SaaS accounts

Known from the repo and the build process — confirm and extend.

| Service | Purpose | Admin owner | MFA enforced | Privileged users | Notes |
|---------|---------|-------------|--------------|------------------|-------|
| GitHub | Source, PRs, Actions | _TBD_ | _TBD_ | _TBD_ | Branch protection state? Actions secrets? |
| Apple Developer Program | Signing, provisioning, App Store Connect | _TBD_ | _TBD_ | _TBD_ | NFC entitlement currently unclaimed |
| Email / identity tenancy | Business email, SSO if any | _TBD_ | _TBD_ | _TBD_ | |
| Static hosting (public card page) | Renders NFC payload, if used | _TBD_ | _TBD_ | _TBD_ | Confirm whether this exists in production |
| Password manager | Credential storage | _TBD_ | _TBD_ | _TBD_ | |
| Anything else with a login | | | | | |

## The five CE controls — evidence to gather

| Control | What the assessor wants | Status |
|---------|-------------------------|--------|
| Firewalls | Boundary and host firewalls on, default deny inbound, no unnecessary open ports | _TBD_ |
| Secure configuration | Default passwords changed, unused accounts and software removed, device lock | _TBD_ |
| Security update management | All software vendor-supported and patched within 14 days for critical / high | _TBD_ |
| User access control | Named accounts, least privilege, separate admin accounts, MFA on all cloud services, joiner/leaver process | _TBD_ |
| Malware protection | Anti-malware or approved-application allowlisting on each in-scope device | _TBD_ |

## Notes specific to RedMed

- The **iOS binary is not a CE boundary** the way a SaaS VPC is. Do not try to
  scope the app itself; scope the company.
- There is currently **no production backend**, which genuinely shrinks scope —
  say so plainly on the questionnaire rather than inventing infrastructure.
- If the staged `uploads/` tree ships, an outbound third-party alert endpoint
  enters the picture. That is a supplier relationship and a data flow, and it
  will need to appear here. See [`../08-execution-plan.md`](../08-execution-plan.md),
  Gate 0.
- `uploads/google-api-key` was a tracked empty placeholder; it is removed and
  gitignored. `GoogleGeocoder` remains a stub that makes no network call and
  holds no key.

## Certificate

| Field | Value |
|-------|-------|
| Certificate number | _TBD_ |
| Level (CE / CE Plus) | _TBD_ |
| Issue date | _TBD_ |
| **Expiry date** | _TBD_ |
| Stored at | _Private evidence store — not this repo_ |

Do not claim Cyber Essentials anywhere until that certificate number exists.
