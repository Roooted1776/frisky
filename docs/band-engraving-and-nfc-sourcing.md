# Band engraving + NFC / QR sourcing

Product note for physical RedMed bracelets. Matches the shipping model:
passive NTAG NDEF URI → `AppConfig.medicalCardBaseURL#d=…` (currently
`https://roooted1776.github.io/tapper/#d=…`; `getredmed.com` only after
`docs/domain.md` cutover). Profile only in the fragment; no RedMed backend.

**Mold, color, and face art below are locked product law.** Do not reopen for
vendor preference, wine/burgundy revival, laser-`MED ID`-only faces, or other
art without an explicit product change.

The owner app enforces data independence: NDEF writes are
`AppConfig.OwnerBandURI`-gated (`medicalCardBaseURL#d=` only — no vendor cloud,
no social/short URL, no BLE).

## Ship sequence (locked)

**No new app architecture for hardware.** The owner NFC tab already writes
passive Type 2 NDEF. Hardware work is procurement + Apple portal + factory:

1. **Verified blank NTAG216 stock** — sample 1–10 **black** silicone
   (`#232425`). Prove unlocked NDEF, CoreNFC Write, second-phone
   Safari → `tapper.html#d=`.
2. **NFC entitlement live** — paid Apple Developer; App ID NFC Tag Reading;
   `AppConfig.nfcHardwareEnabled` + `RedMed.entitlements` (see `NFC-RESTORE.md`).
3. **Factory MOQ** — only after 1 and 2. Same mold/color/chip + face-art brief
   below. Sample 10 before production MOQ.

Do not substitute Shopify / storefront / custom firmware for that sequence.
Do not MOQ before blank stock and entitlement are proven on a physical iPhone.
**Blank chips + Share honesty** may sell before Write is proven; storefront /
dept “write from the app” stays **off** until Tag Reading + Write The Band
are live on a blank NTAG216. Do **not** ship “buy blank + Shortcuts / NFC
Tools” as the product path. Paid ads stay at **$0** until this sequence plus
a live `/tapper/` and a real App Store listing are green
([`docs/ADVERTISING.md`](ADVERTISING.md)).

---

## Locked mold + color + face art

| Field | Locked choice |
|-------|----------------|
| Form | **Adult silicone wristband**, adjustable (holes + clasp). Adult circumference — **240 mm** locked for Garic / reorder unless Max changes it. |
| Size | Adult. No child SKU in v1. |
| Color | **Black** silicone only — `#232425`. Wine/burgundy is dead. Not navy, clear, or multi-color v1. |
| Chip seat | Embedded **NXP NTAG216**, 13.56 MHz HF, ISO 14443A **Type 2**, NDEF **unlocked / blank** at factory. No pre-encode, no lock. Band comes complete. No battery. |
| Finish | Matte or satin silicone OK; no glitter, glow, or dual-tone. |
| Face art | **Logo-print** (not laser `MED ID`): RedMed circular heart logo + **RedMed** wordmark (`Red` Pantone **4058 C** / heart accents Pantone **191 C** / `Med` + icon white Pantone White C) at **30×9 mm** on the black band face. Matches factory art proof. |

Prototype (1–10): black `#232425` NTAG216 silicone with the locked logo-print face.  
Production (100+): same mold/color/chip/face art, MOQ quote.

---

## Locked face-art brief

Pad/print the BrandLogo heart + RedMed wordmark at **30×9 mm**. No laser `MED ID` plate for this SKU.

Medical detail lives on-chip via owner Write (`tapper.html#d=`), not on the face.

### What not to put on the face

- Laser-only `MED ID` (old SKU — dead)
- Wine/burgundy silicone
- Multi-line medical essays, ICE phones, allergy lists, blood type
- The live `#d=` URL or a QR of the medical card
- Vendor short-links / non-RedMed URLs
- Factory pre-encode of any URL (chip stays blank)

---

## Chip + QR (locked with the mold)

| Need | Spec |
|------|------|
| Chip | **NXP NTAG216** only (888 B user memory). Not NTAG213, MIFARE, LF, or UHF. |
| RF | 13.56 MHz HF, ISO 14443A Type 2, NDEF **blank unlocked** — no factory pre-encode, no lock |
| Avoid | NTAG213, MIFARE, LF 125 kHz, UHF, pre-encoded vendor URLs, password-locked UID products you cannot overwrite from CoreNFC |
| Factory NDEF | Leave **empty** (or a harmless stub). Owner overwrites on first Write in the NFC tab (`OwnerBandURI` / `#d=` only). |
| QR (optional, outer only) | Only a live App Store URL (`AppConfig.appStoreURL`). Currently `nil` — **omit QR** until a listing exists. **Do not** QR-encode `tapper/#d=…`. If the face only fits one mark, the **logo-print 30×9 mm** mark wins. |
| Chip (NDEF) | `AppConfig.medicalCardBaseURL#d=<base64url>` — currently `https://roooted1776.github.io/tapper/#d=` (`OwnerBandURI`). `getredmed.com` after domain cutover. |

**Do not** pair the band with a third-party QR/NFC “profile” SaaS (Seritag Linking,
Tap NFC cloud, Linktree, bit.ly medical short-links, MedicAlert-style hosted
records, etc.). Hardware vendor OK; their redirect platform is not. The app
refuses non-`#d=` owner writes.

UK / EU blank black silicone sources (verify #232425): [Seritag](https://seritag.com/nfc-tags/wristbands),
[Flexcard Print](https://flexcardprint.co.uk/product/silicone-rfid-wristbands/),
[Shop NFC](https://shopnfc.com/en/nfc-wristbands/54-nfc-silicone-wristbands-premium.html),
[NFC Tag Shop](https://www.nfc-tag-shop.de/en/NFC-Wristbands/NFC-silicone-bands/).

---

## Factory / print shop brief (copy-paste)

> **RedMed band — locked v1**
>
> Adult **black** silicone wristband (`#232425`), adjustable (**240 mm**).
> Logo-print face: RedMed heart + wordmark at **30×9 mm** (Pantone 4058 C /
> 191 C / White C). Embed **NXP NTAG216**, 13.56 MHz, ISO 14443A Type 2,
> **NDEF unlocked / blank**. No wine/burgundy. No metal-only band SKU.
>
> Face art is logo-print — not laser `MED ID`.
>
> No reverse personalization. Optional small QR to App Store listing only —
> omit if the logo-print mark does not fit with it. Do **not** pre-program
> medical URLs or lock the chip. Sample 10 before production MOQ.

---

## Why not “QR/NFC services”

RedMed already owns the tap URL (`AppConfig.medicalCardBaseURL`). A redirect SaaS
adds: another DPIA party, outage risk on the critical path, and a product story
that no longer matches “we run no servers for your profile.” Hardware-only
vendors + Cloudflare Pages static `tapper.html` (passerby scan; legacy `card.html`
redirects) + policy HTML stay aligned. Owner Write is
`AppConfig.OwnerBandURI`-gated so the chip cannot carry a vendor/social URL.
