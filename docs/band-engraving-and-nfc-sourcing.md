# Band engraving + NFC / QR sourcing

Product note for physical RedMed bracelets. Matches the shipping model:
passive NTAG NDEF URI → `https://redmed.pages.dev/card/#d=…` (profile only in
the fragment; no RedMed backend).

## Recommendation (short)

**Do not pair the band with a third-party QR/NFC “profile” SaaS** (Seritag
Linking, Tap NFC cloud, Linktree, bit.ly / branded short-links that hold medical
data, MedicAlert-style hosted records, etc.). Those put emergency health data
(or a live dependency) on someone else’s servers and contradict the no-server
Privacy/ToS claim.

**Buy blank, rewritable NXP NTAG216 silicone (or metal-plate) wristbands** and
program them only through the RedMed app. Laser-engrave static medical-ID text
plus a **setup** QR — never the `#d=` medical payload.

| Need | Spec |
|------|------|
| Chip | **NXP NTAG216** (888 B user memory). NTAG215 is OK for short profiles; NTAG213 fails most real cards (`ProfileNFCCodec` warns above ~140 B / ~480 B). |
| RF | 13.56 MHz HF, ISO 14443 Type 2, NDEF writable, **not locked at factory** |
| Avoid | LF 125 kHz, UHF, MIFARE Classic-only, pre-encoded vendor URLs, password-locked UID products you cannot overwrite from CoreNFC |
| UK / EU sourcing (blank or custom print, chip empty) | [Seritag](https://seritag.com/nfc-tags/wristbands) (UK), [Flexcard Print](https://flexcardprint.co.uk/product/silicone-rfid-wristbands/) (UK quote), [Shop NFC](https://shopnfc.com/en/nfc-wristbands/54-nfc-silicone-wristbands-premium.html), [NFC Tag Shop](https://www.nfc-tag-shop.de/en/NFC-Wristbands/NFC-silicone-bands/) |
| Factory NDEF | Leave **empty** (or a harmless stub). Owner overwrites on first Write in the NFC tab. |
| QR encode | `https://redmed.pages.dev/get.html` only — App Store / setup landing. **Do not** QR-encode `card/#d=…`. |

Seritag is fine as a **hardware** vendor. Skip their tag-management / redirect
platform for RedMed medical payloads.

Prototype (1–10): Seritag stock NTAG216 silicone. Production (100+): Flexcard or
equivalent UK silicone house — NTAG216, laser + optional pad-print logo, chip
blank, MOQ quote.

---

## Engraving text

Character budget is tight on a 15–20 mm face. Prefer laser on the clasp plate or
a flat tag face; silicone emboss alone is hard to read in low light.

### Outer face (rescuer sees first)

```
MEDICAL ID
TAP PHONE → CARD
```

Optional third line if space: `REDMED`

### Inner / reverse (owner-specific — fill per customer)

```
[GIVEN SURNAME]
ICE [PHONE]
ALLERGY: [ONE LINE]
BLOOD [TYPE]
```

Rules for the variable lines:

- **Name** — surname + given, all caps, no DOB on the face (DOB lives on-chip).
- **ICE** — one primary mobile, digits only or `+44…`. No “Mom / Dad” without a number.
- **ALLERGY** — single worst line (`PENICILLIN`, `PEANUT ANAPHYLAXIS`). Extra allergies stay on-chip.
- **BLOOD** — only if known (`O+`, `A-`). Else omit the line; do not engrave `UNKNOWN`.

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
ICE +447700900123
ALLERGY: PENICILLIN
BLOOD O+
```

### Optional condition line (only if allergy line is empty)

```
COND: EPILEPSY
```

or `COND: T1 DIABETES` — one token, no essay.

### What not to engrave

- Full med list, address, NHS number, email, password, “encrypted” claims
- The live `#d=` URL or a QR of the medical card (too long; world-readable without a deliberate tap)
- Vendor short-links that 302 to a hosted profile

---

## QR on the band

| Location | Encodes | Why |
|----------|---------|-----|
| Outer face, small | `https://redmed.pages.dev/get.html` | Owner setup / App Store path (`get.html`). Safe if scanned by a stranger — no health data. |
| Chip (NDEF) | `https://redmed.pages.dev/card/#d=<base64url>` | Written by RedMed; rescuer tap opens the card. |

If the plate only fits one mark, prioritise **engraved text** over QR. NFC is the
primary rescue path; QR is a setup affordance, not a backup medical record.

---

## Factory / print shop brief (copy-paste)

> Silicone (or metal face) wristband, adult size, red or black. Embed **NXP
> NTAG216**, 13.56 MHz, ISO 14443A, **NDEF unlocked / blank**. Laser outer face:
> `MEDICAL ID` / `TAP PHONE → CARD` / `REDMED`. Laser reverse with per-unit
> variable: name, ICE phone, one allergy line, blood type. Optional QR to
> `https://redmed.pages.dev/get.html` only. Do **not** pre-program medical URLs
> or lock the chip. Sample 10 before production MOQ.

---

## Why not “QR/NFC services”

RedMed already owns the tap URL (`AppConfig.medicalCardBaseURL`). A redirect SaaS
adds: another DPIA party, outage risk on the critical path, and a product story
that no longer matches “we run no servers for your profile.” Hardware-only
vendors + Cloudflare Pages static `card.html` / `get.html` stay aligned.
