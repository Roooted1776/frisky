# Custom band — laser fulfill

Per order on **RedMed Band — Custom**. Chip always blank. Engraving only.

## From the Shopify order

Read line item properties:

| Property | Laser line |
|----------|------------|
| `Name` | `[GIVEN SURNAME]` |
| `ICE` | `ICE [PHONE]` |
| `Allergy` | `ALLERGY: [ONE LINE]` — skip if empty |
| `Condition` | `COND: [TOKEN]` — only if Allergy empty |
| `Blood` | `BLOOD [TYPE]` — skip if empty / omitted |

Normalize before send to factory: trim, uppercase, strip emoji, max lengths
from the product form.

## Outer face (every unit)

```
MEDICAL ID
TAP PHONE → CARD
REDMED
```

## Factory email (copy)

```
Custom RedMed band — order #[ORDER]

Color: [Black|Red]
Chip: NXP NTAG216, 13.56 MHz, NDEF EMPTY unlocked — do not encode URL

Outer laser:
MEDICAL ID
TAP PHONE → CARD
REDMED

Reverse laser:
[NAME]
ICE [PHONE]
ALLERGY: [LINE]    OR    COND: [TOKEN]
BLOOD [TYPE]       (omit line if blank)

No #d= QR. Optional App Store QR only if plate has room.
```

## Privacy / ops

- Engraving text is **on the physical band** (world-visible). It is not a RedMed
  cloud profile. Do not pipe Shopify fields into Seritag Linking, Tap NFC, or
  any redirect SaaS.
- After ship, you can redact properties in order notes if you want less residue
  in Shopify admin — optional.
- Custom / lasered = final sale (state that in returns policy).

## Pricing anchor

| SKU | Retail (CSV) |
|-----|----------------|
| Blank | $24 |
| Custom engraved | $39 |
