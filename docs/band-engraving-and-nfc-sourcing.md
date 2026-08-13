# Band engraving + NFC / QR sourcing

Product note for physical RedMed bracelets. Matches the shipping model:
passive NTAG NDEF URI → `https://redmed.pages.dev/tapper/#d=…` (profile only in
the fragment; no RedMed backend).

**Mold, color, and engraving below are locked product law.** Do not reopen for
vendor preference, “also black,” metal-plate SKUs, or optional outer lines
without an explicit product change.

---

## Locked mold + color

| Field | Locked choice |
|-------|----------------|
| Form | **Adult silicone wristband** with a **flat laser face** (clasp plate or tag plate, ~15–20 mm readable width). Soft silicone emboss alone is **not** the face. |
| Size | Adult (adjustable / standard adult circumference). No child SKU in v1. |
| Color | **Red** silicone only — match brand accent `#e11d48` (`Color.redmedAccent`) as close as the house stock allows (medical-alert red). **No black, navy, clear, or multi-color v1.** |
| Chip seat | Embedded **NXP NTAG216**, 13.56 MHz HF, ISO 14443 **Type 2**, NDEF **unlocked / blank** at factory. |
| Finish | Matte or satin silicone OK; no glitter, glow, or dual-tone. |
| Logo print | Optional pad-print wordmark only if laser outer text already fits; logo never replaces engraving. |

Prototype (1–10): Seritag (or equivalent) **red** NTAG216 silicone with a laserable plate.  
Production (100+): Flexcard or equivalent UK silicone house — same mold/color/chip, MOQ quote.

---

## Locked engraving brief

Laser only on the metal/hard plate face. Character budget is tight.

### Outer face (every unit — fixed, rescuer sees first)

```
MEDICAL ID
TAP PHONE → CARD
REDMED
```

All three lines are **required**. Do not drop `REDMED`. Do not substitute slogans,
URLs, or vendor names.

### Inner / reverse (per customer — variable)

```
[GIVEN SURNAME]
ICE [PHONE]
ALLERGY: [ONE LINE]
BLOOD [TYPE]
```

Rules:

- **Name** — given + surname, all caps, no DOB on the face (DOB lives on-chip).
- **ICE** — one primary mobile, digits only or `+1…` / `+44…`. No “Mom / Dad” without a number.
- **ALLERGY** — single worst line (`PENICILLIN`, `PEANUT ANAPHYLAXIS`). Extra allergies stay on-chip.
- **BLOOD** — only if known (`O+`, `A-`). Else omit the line; do not engrave `UNKNOWN`.
- If allergy is empty and one condition matters: replace allergy line with
  `COND: EPILEPSY` or `COND: T1 DIABETES` — one token, no essay.

### Example (filled)

**Outer**

```
MEDICAL ID
TAP PHONE → CARD
REDMED
```

**Inner**

```
JANE DOE
ICE +14475551212
ALLERGY: PENICILLIN
BLOOD O+
```

### What not to engrave

- Full med list, address, email, password, “encrypted” claims
- The live `#d=` URL or a QR of the medical card
- Vendor short-links that 302 to a hosted profile
- Any color/mold variant callouts on the face

---

## Chip + QR (locked with the mold)

| Need | Spec |
|------|------|
| Chip | **NXP NTAG216** (888 B user memory). NTAG215 OK for short profiles; NTAG213 fails most real cards (`ProfileNFCCodec` warns above ~140 B / ~480 B). |
| RF | 13.56 MHz HF, ISO 14443 Type 2, NDEF writable, **not locked at factory** |
| Avoid | LF 125 kHz, UHF, MIFARE Classic-only, pre-encoded vendor URLs, password-locked UID products you cannot overwrite from CoreNFC |
| Factory NDEF | Leave **empty** (or a harmless stub). Owner overwrites on first Write in the NFC tab. |
| QR (optional, outer only) | App Store listing URL only (`AppConfig.appStoreURL`). **Do not** QR-encode `tapper/#d=…`. If the plate only fits one mark, **engraved text wins** — omit QR. |
| Chip (NDEF) | `https://redmed.pages.dev/tapper/#d=<base64url>` — written by RedMed app only. |

**Do not** pair the band with a third-party QR/NFC “profile” SaaS (Seritag Linking,
Tap NFC cloud, Linktree, bit.ly medical short-links, MedicAlert-style hosted
records, etc.). Hardware vendor OK; their redirect platform is not.

UK / EU blank/red silicone sources: [Seritag](https://seritag.com/nfc-tags/wristbands),
[Flexcard Print](https://flexcardprint.co.uk/product/silicone-rfid-wristbands/),
[Shop NFC](https://shopnfc.com/en/nfc-wristbands/54-nfc-silicone-wristbands-premium.html),
[NFC Tag Shop](https://www.nfc-tag-shop.de/en/NFC-Wristbands/NFC-silicone-bands/).

---

## Factory / print shop brief (copy-paste)

> **RedMed band — locked v1**
>
> Adult **red** silicone wristband (closest stock to `#e11d48`), adjustable.
> Flat laser clasp/tag plate (~15–20 mm). Embed **NXP NTAG216**, 13.56 MHz,
> ISO 14443A Type 2, **NDEF unlocked / blank**. No black/other colors. No
> metal-only band SKU.
>
> Laser **outer** (every unit, all three lines):
> `MEDICAL ID` / `TAP PHONE → CARD` / `REDMED`
>
> Laser **reverse** (per unit): given+surname, `ICE` + phone, one
> `ALLERGY:` or `COND:` line, `BLOOD` type if known.
>
> Optional small QR to App Store listing only — omit if text does not fit.
> Do **not** pre-program medical URLs or lock the chip.
> Sample 10 before production MOQ.

---

## Why not “QR/NFC services”

RedMed already owns the tap URL (`AppConfig.medicalCardBaseURL`). A redirect SaaS
adds: another DPIA party, outage risk on the critical path, and a product story
that no longer matches “we run no servers for your profile.” Hardware-only
vendors + Cloudflare Pages static `tapper.html` (passerby scan; legacy `card.html`
redirects) + policy HTML stay aligned.
