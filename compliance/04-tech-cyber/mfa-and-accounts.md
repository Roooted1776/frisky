# MFA and accounts

## Current product

RedMed owner profile is **on-device**. Edit unlock uses device biometrics /
passcode (`LocalAuthentication`) — that is device auth, not RedMed cloud MFA.

## Rules

- If you add RedMed accounts / cloud: MFA mandatory before NHS sales.
- Admin surfaces (GitHub, Apple Developer, email, analytics): MFA now.
- No shared passwords for org admin.

## DTAC line

Document “no remote user accounts in vCurrent; device biometrics gate edits;
org MFA on developer/admin tenants.” Update when accounts ship.
