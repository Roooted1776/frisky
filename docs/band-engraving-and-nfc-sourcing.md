# Band engraving + NFC / QR sourcing

Product note for physical RedMed bracelets. Matches the shipping model:
passive NTAG NDEF URI → `https://redmed.pages.dev/tapper/#d=…` (profile only in
the fragment; no RedMed backend).

**Mold, color, and engraving below are locked product law.** Do not reopen for
vendor preference, “also black,” metal-plate SKUs, or extra face copy without an
explicit product change.

The owner app enforces data independence: NDEF writes are
`AppConfig.OwnerBandURI`-gated (`medicalCardBaseURL#d=` only — no vendor cloud,
no social/short URL, no BLE).

---

## Locked mold + color

| Field | Locked choice |
|-------|----------------|
| Form | **Adult silicone wristband** with a **flat laser face** (clasp plate or tag plate, ~15–20 mm readable width). Soft silicone emboss alone is **not** the face. |
| Size | Adult (adjustable / standard adult circumference). No child SKU in v1. |
| Color | **Wine / burgundy** silicone only — target `#6B1E2F` (fashionable deep wine; practical dirt/hide). Not bright app accent `#e11d48`, not pink, not cherry, not purple plum. Closest house stock to wine-burgundy. **No black, navy, clear, or multi-color v1.** |
| Chip seat | Embedded **NXP NTAG216**, 13.56 MHz HF, ISO 14443 **Type 2**, NDEF **unlocked / blank** at factory. |
| Finish | Matte or satin silicone OK; no glitter, glow, or dual-tone. |
| Logo print | Optional pad-print wordmark only if laser `MED ID` already fits; logo never replaces engraving. |

Prototype (1–10): Seritag (or equivalent) **wine/burgundy** NTAG216 silicone with a laserable plate.  
Production (100+): Flexcard or equivalent UK silicone house — same mold/color/chip, MOQ quote.

---

## Locked engraving brief

Laser only on the metal/hard plate face. Character budget is tight.

### Face text (every unit — fixed)

```
MED ID
```

That is the **only** engraved copy. No second line, no `REDMED`, no tap
instructions, no name / ICE / allergy / blood on the plate. Medical detail lives
on-chip via owner Write in the NFC tab (`tapper.html#d=`).

Do not substitute slogans, URLs, or vendor names.

### What not to engrave

- Multi-line medical-ID essays, ICE phones, allergy lists, blood type
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
| Factory NDEF | Leave **empty** (or a harmless stub). Owner overwrites on first Write in the NFC tab (`OwnerBandURI` / `#d=` only). |
| QR (optional, outer only) | App Store listing URL only (`AppConfig.appStoreURL`). **Do not** QR-encode `tapper/#d=…`. If the plate only fits one mark, **`MED ID` wins** — omit QR. |
| Chip (NDEF) | `https://redmed.pages.dev/tapper/#d=<base64url>` — written by RedMed app only (`OwnerBandURI`). |

**Do not** pair the band with a third-party QR/NFC “profile” SaaS (Seritag Linking,
Tap NFC cloud, Linktree, bit.ly medical short-links, MedicAlert-style hosted
records, etc.). Hardware vendor OK; their redirect platform is not. The app
refuses non-`#d=` owner writes.

UK / EU blank wine/burgundy silicone sources: [Seritag](https://seritag.com/nfc-tags/wristbands),
[Flexcard Print](https://flexcardprint.co.uk/product/silicone-rfid-wristbands/),
[Shop NFC](https://shopnfc.com/en/nfc-wristbands/54-nfc-silicone-wristbands-premium.html),
[NFC Tag Shop](https://www.nfc-tag-shop.de/en/NFC-Wristbands/NFC-silicone-bands/).

---

## Factory / print shop brief (copy-paste)

> **RedMed band — locked v1**
>
> Adult **wine / burgundy** silicone wristband (closest stock to `#6B1E2F` —
> fashionable deep wine, not bright `#e11d48`), adjustable.
> Flat laser clasp/tag plate (~15–20 mm). Embed **NXP NTAG216**, 13.56 MHz,
> ISO 14443A Type 2, **NDEF unlocked / blank**. No black/other colors. No
> metal-only band SKU.
>
> Laser face (every unit, this text only):
> `MED ID`
>
> No reverse personalization. Optional small QR to App Store listing only —
> omit if `MED ID` does not fit with it. Do **not** pre-program medical URLs or
> lock the chip. Sample 10 before production MOQ.

---

## Why not “QR/NFC services”

RedMed already owns the tap URL (`AppConfig.medicalCardBaseURL`). A redirect SaaS
adds: another DPIA party, outage risk on the critical path, and a product story
that no longer matches “we run no servers for your profile.” Hardware-only
vendors + Cloudflare Pages static `tapper.html` (passerby scan; legacy `card.html`
redirects) + policy HTML stay aligned. Owner Write is
`AppConfig.OwnerBandURI`-gated so the chip cannot carry a vendor/social URL.
