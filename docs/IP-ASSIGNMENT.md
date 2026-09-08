# RedMed IP assignment

One-page confirmatory assignment: **frisky / RedMed code, tapper HTML, brand, and band design → the LLC** (or a to-be-formed NJ entity). Cheap. Stops “who owns the app?” with a contractor or cousin.

**Print and sign:** [docs/ip-assignment.html](ip-assignment.html) → File → Print (one US Letter page). Fill blanks. Wet ink or DocuSign.

This file is how-to. The HTML is the instrument. Do not put a signed copy with a home address on this public repo.

Not legal advice. If you take money, add members, or fight someone, have NJ counsel look at it.

## This week

1. **Form the LLC** (do this first if you can). NJ Business Formation (njportal.com) Certificate of Formation. Single-member is fine. Pick a name that clears (`RedMed LLC`, `Red Med ID LLC`, or whatever the name search allows). ~$125. Same day if the name is free.
2. **EIN.** IRS EIN online. Free. Same sitting.
3. **Fill and sign** `docs/ip-assignment.html`. Assignor is Maximilian Aguilar-Aasted. Assignee is the LLC legal name and state. Schedule A: write **None** unless a cousin already wrote code or drew the logo — then they sign the contributor block too.
4. **Keep the original** with the Certificate of Formation and a single-member operating agreement. That OA is a separate paper (not in this repo).
5. **If the LLC is not formed yet:** you can still sign. The instrument holds the IP in trust and requires a short-form confirmation within 10 days after formation. Prefer forming first so the assignee exists.

**Do not** change in-app Help (`Document.html` Privacy §1 / Terms §1) from “individual in New Jersey, not a registered company” until the LLC exists **and** this assignment is signed. Then a follow-up PR with the legal name. Claiming an entity that does not exist is a lie.

Apple Developer / App ID `com.redmed.app` / GitHub stay in your personal account until the Company can hold them. Section 3 is the promise to move them. That is not automatic (Apple org accounts want D-U-N-S).

## What this covers

| Bucket | What |
|--------|------|
| Code | `Roooted1776/frisky`, `RedMed-Xcode` (SwiftUI), bundle ID `com.redmed.app` |
| Tapper | `tapper/` HTML/JS, redirects, SW, Pages host copies |
| Brand | REDMED / RedMed / MED ID, BrandLogo, BrandWordmark, cream UI, wine/burgundy |
| Band | Adult wine/burgundy silicone, laser `MED ID`, NXP NTAG216, blank NDEF — same as `docs/band-engraving-and-nfc-sourcing.md` |
| Future | Later RedMed work by Max assigns on creation |

Not transferred: wearer medical profiles (Keychain / `#d=`). Those are not yours.

## Contractor / cousin

Max assigning his own IP does **not** take what someone else wrote. Anyone else who authored code, brand, or band design signs the **contributor** block on the same page **before** repo write access. Copy the page for each extra person.

AI agent commits (Cursor, Claude, etc.) are treated as work at Max’s direction. That is the Assignor warranty. A human contributor still signs.

## After it is signed

- Staple to formation papers. Not a git commit.
- Company gate in `docs/ADVERTISING.md` still needs insurance, FDA/BAA decisions, and an invoice path before facility outbound. This paper is only ownership.
- Follow-up (separate PR): Help operator line → LLC name; Apple / GitHub / domains when the Company can hold them.
