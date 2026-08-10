# Lawful basis — special-category health data

## Controller analysis (current architecture)

For **on-device profile data the user types**, the individual is generally the
controller of their own data. RedMed publishes software; it does **not** today
receive or host that profile on RedMed servers.

UK GDPR still matters for:

- How the app is designed (privacy by design / default)
- Any analytics, crash reporters, support email intake, marketing lists
- NFC/web card that discloses health data to strangers by design
- Future NHS contracts where a trust becomes controller and RedMed processor

## Lawful basis options (pick with counsel)

| Processing | Art. 6 (candidate) | Art. 9 special category (candidate) |
|------------|--------------------|-------------------------------------|
| User stores own emergency ID on device | Consent (6(1)(a)) and/or contract (6(1)(b)) | Explicit consent (9(2)(a)) and/or vital interests narrowly (9(2)(c)) — prefer explicit consent + clear UI |
| Bystander reads NFC card in emergency | Vital interests / public interest debate — **do not DIY**; counsel must confirm narrative | Same — emergency disclosure is the product’s point; document it |
| Location on Find 911 | Consent via OS permission + in-app purpose limit | Not always special category; treat carefully if combined with health profile |
| Support email containing health info | Legitimate interests or consent | Explicit consent or other Art. 9 condition |

**Do not** claim “we don’t process personal data because there’s no server.”
On-device and chip processing still count.

## Record of processing

Maintain a ROPA entry even if volume is low. Update when you add accounts,
cloud, or NHS tenancy.
