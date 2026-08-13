# Shopify page + section copy

Paste into Dawn (or equivalent). Keep medical claims tight: local EMS assist /
fast ID handoff — not a device, no outcome promises.

---

## Home — hero (first viewport only)

**Brand:** RedMed  
**Headline:** Medical ID on your wrist. Written by your phone.  
**Support:** Passive NFC band. No Bluetooth. No server for your profile.  
**Primary CTA:** Buy the band  
**Secondary CTAs:** Custom engrave · Get the app  

Do not put stats, feature grids, or health quizzes in the first viewport.

---

## Home — Blank vs Custom

| | Blank ($24) | Custom ($39) |
|--|-------------|--------------|
| Chip | Blank NTAG216 | Blank NTAG216 |
| Outer laser | Standard MEDICAL ID copy | Same |
| Reverse | None | Name, ICE, allergy/cond, blood |
| Who writes NFC | You, in the app | You, in the app |

Engraving is backup for no-NFC moments. Full card lives on-chip after Write.

---

## Home — How it works (below fold)

1. **Write** — RedMed app programs the blank NTAG216 chip (Face ID).
2. **Wear** — Band stays silent until someone taps a phone to it.
3. **Tap** — EMT or helper opens the card in the browser. No install. No login.

Walk-by (~6–8″) does not fire. Intentional tap is ~1–2″.

---

## Page: How it works

**Title:** How RedMed works

RedMed is an iPhone app plus a blank NFC wristband.

- The band is **passive** 13.56 MHz HF NFC (NXP NTAG). Not Bluetooth.
- Your profile is packed onto the chip by the app as an encrypted fragment on a
  static Pages URL. RedMed does not host your medical record on a server.
- A passerby tap opens the card on *their* phone. Tap-to-view never asks for
  Face ID.
- Owner Face ID gates edit, NFC write, vault, and app unlock only.

Hardware you buy here ships **unwritten**. You write it.

---

## Page: Shipping & returns

**Title:** Shipping & returns

- Ships as blank hardware. Chip is empty until you write it in the app.
- [Set your carrier + SLA here]
- Returns: unused / unengraved bands within [X] days. Written or customized
  bands are final sale once the NDEF has been programmed (or state your policy).

---

## Page: FAQ

**Is my medical data on Shopify / your servers?**  
No. Shopify only sells the physical band. The app writes the chip on your
iPhone. Passerby view reads the chip — no RedMed account.

**Bluetooth?**  
No. Passive HF NFC only.

**Will it go off when my phone is nearby?**  
No background pair. The band does nothing until a phone’s NFC antenna is within
about 1–2″ (or you start Write/Scan in the app). Walk-by at 6–8″ does not fire.

**Card readers / Apple Pay?**  
Payment terminals speak EMV. They do not open your RedMed card.

**Social media NFC band?**  
No. We do not pre-encode Instagram or vendor short-links. The app owns the write.

**Android?**  
Owner write is iPhone / CoreNFC. Passerby tap works on modern NFC phones in the
browser.

**Custom engraving — is that my medical record in Shopify?**  
No. Those fields are laser instructions for the physical band (world-visible
text). The chip stays blank until you Write in the app. We do not host a
medical profile or encode your card URL at the factory.

**Can I change engraving later?**  
Laser is permanent. Order a new Custom band (or wear Blank and keep detail
on-chip only).

**Medical device?**  
No. Call emergency services first. RedMed is a local ID / assist handoff.

---

## Footer links

Privacy Policy · Terms · How it works · FAQ · Contact  
App Store (replace placeholder ID when live) · `https://redmed.pages.dev/tapper/`
is the passerby shell — not a storefront.
