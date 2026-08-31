# RedMed advertising

GTM lock. Product code stays in Swift / `tapper/`. This file is what agents
and humans may put on ads, landing pages, Shopify, and TikTok captions.

v1 buyer is the **wearer or their family**. Not EMS. Not a hospital.
EMS is a trust channel (they see the tap). They are not the customer.

Paid ads and “available now” posts stay off until the gate below is green.

Full claim bans also live in [`DO-NOT.md`](DO-NOT.md). Hardware sequence:
[`band-engraving-and-nfc-sourcing.md`](band-engraving-and-nfc-sourcing.md).
Do not put a storefront, course LMS, or ad pixel in this repo.

---

## Ship-before-ads gate

**$0 paid media** until every line is true. Organic build-in-public with no
buy CTA is fine.

| Gate | How you know it is green |
|------|--------------------------|
| Live HTTPS `/tapper/` | `BASE=https://<host> ./scripts/smoke-pages.sh` returns OK. `AppConfig.medicalCardBaseURL` is that host. github.io is **404** until `Roooted1776.github.io` is published ([`domain.md`](domain.md)). |
| App Store listing | Paid Apple Developer. Real `apps.apple.com` ID. `AppConfig.appStoreURL` is that URL, not `nil`, not a placeholder. |
| NFC write on hardware | NFC Tag Reading on App ID `com.redmed.app`. `nfcHardwareEnabled = true`. Owner iPhone Write → second phone Safari opens the card. Simulator does not count. |
| Sample bands in hand | 1–10 wine/burgundy NTAG216 silicone, laser `MED ID`, NDEF blank unlocked. Proven write on a physical iPhone. |
| Somewhere to buy | Shopify (or equivalent) **after** the samples write. No storefront in this git tree. LLC or a real support domain beats `help.RedMed@gmail.com` + a public repo named `frisky`. |

Do not skip to Shopify, Meta, or Google while NFC is parked, the listing is
parked, or the band host 404s. That is advertising a product that cannot tap.

---

## Positioning

**One line:** Tap the band. Medical ID opens. No app, no login.

**For whom:** People who already know they might be found down (epilepsy,
anaphylaxis, diabetes, heart, anticoagulants, autism / non-speaking, elderly
parent). Caregivers buying for someone else.

**Not for:** Hospitals as a system. “HIPAA certified.” Child SKU in v1.
Android owners as **writers** (any phone can *read* a tap; only iPhone writes).

**What we are:** A better ICE bracelet. Self-reported medical ID on the iPhone
Keychain and, if written, on a passive NXP NTAG216. Passerby / EMT opens
Safari. No RedMed profile server.

**What we are not:** A medical network, a dispatch service, a MedicAlert
hotline, an EHR, a facility wristband program.

### Allowed copy

- Self-reported medical ID
- Passive NFC (no battery, not Bluetooth)
- Any phone can tap
- Data stays on the chip and the iPhone
- Not a substitute for calling emergency services
- Intentional tap ~1–2 inches (use `AppConfig.BraceletRF` helpers, not invented inches)

### Banned (ads, landing, Shopify, captions, one-pagers)

- HIPAA certified / HIPAA compliant product
- Encrypted bracelet / locked to your phone / unreadable without Face ID
- Sends GPS or profile to 911
- Medical device / diagnoses / detects seizures / crash-proof
- Fake App Store URL or “available now” before Connect exists
- Walk-by tap at 6–8 inches (reliable coupling dies past ~4 inches; walk-by does not fire)
- Lives saved / we dispatch help
- Android can fill and write the band

Lead with the tap, not “attention to detail.”

---

## Hero creative (only ad that matters)

Film on **hardware** after the gate. Do not film the Simulator. Do not film
the owner Edit screen as the ad.

**Length:** 15–20 s total. The tap-to-card moment is under 5 s.

**Dummy profile only.** No real PHI.

### Shot list

1. Wine / burgundy adult silicone on a wrist. Laser plate reads `MED ID` only.
2. Locked iPhone, or a second phone that is not the owner’s. Show the lock
   screen or home screen so the viewer sees this is not “open the app.”
3. Top of the phone to the plate, ~1–2 inches. One deliberate tap.
4. Safari opens the RedMed card (name, allergies, meds, contacts, Call).
5. Hold on the card. Cut.

**Do not show:** Face ID, Edit / Save, NFC Write chrome, owner Help, crash
siren, “HIPAA,” encryption, a 911 autodial.

**Audio / caption (pick one, stay inside allowed copy):**

- “Locked phone. Unconscious. Tap the band.”
- “Tap the band. Medical ID opens. No app, no login.”

Use this same file for organic, Meta, TikTok, and Search landing. Do not
shoot a second concept until this one has been run.

This Linux environment cannot film an iPhone. The file above is the brief;
shoot it on device after Write works.

---

## Channels (after the gate)

Order is locked. Do not invert it.

1. **Owned demo.** The 15–20 s tap video. Landing: tap video + what is on the
   band + iPhone required to write + not a medical device. App Store is the
   software CTA. Shopify is the band CTA. Do not turn bare `/tapper/` (No
   patient empty state) into a storefront.
2. **Google Search first paid dollar.** Exact / phrase: `nfc medical id
   bracelet`, `medical id wristband nfc`, `ice bracelet nfc`,
   `road id alternative`. No treatment keywords (`epilepsy cure`, etc.).
3. **Meta / Instagram / TikTok second.** Demo ads only. Health is restricted:
   **do not target by medical condition.** Age + caregiver / parent interests,
   then lookalikes from purchasers. Boost the same organic tap video.
4. **Apple Search Ads** only after the listing is live. Query: medical ID,
   ICE, NFC medical.
5. **Skip v1:** Google Display, programmatic, podcasts, billboards, EMS
   magazine print, free-course funnels, retargeting pixels on the tap card.

### Budget shape (when you actually spend)

- 70% Google Search + Apple Search Ads
- 30% short-form demo (Meta / TikTok)
- Kill the short-form line if CPA > band margin after 2 weeks
- Cap learning spend. Kill any ad that uses a banned claim.

### Offer

- **SKU:** wine adult silicone + NTAG216 + laser `MED ID`. One color. No child SKU.
- **App:** free or cheap. Margin is the band. No SaaS for a local-only profile.
- **No subscription.** No server to justify one.
- Price against Road ID (~$30–70) plus a small NFC premium. Not luxury device pricing.

### Measurement

KPI is **band orders** and **App Store downloads**. Not “lives saved.” Not
field tap counts (you will not have them).

Pixels and conversion APIs belong on the **store and the App Store listing
only**. Never on the passerby medical card.

`tapper/index.html` (bundled as `tapper.html`) must not load Meta Pixel, GA4,
TikTok Pixel, or any other tracker. Help already says no ad networks on that
shell. `scripts/smoke-pages.sh` fails the tree if those strings land in the
shell. Cloudflare CSP `connect-src` is `'self'` plus Overpass only; do not
widen it for ads.

---

## First responders (trust, not ads)

Park any course LMS, giveaway funnel, and “free training → software demo →
hardware upsell.” EMTs do not buy patient bracelets. They are time-poor.
Unknown courses get ignored. Bands they cannot write (or that 404) burn
reputation.

After you can write a real band:

- Visit ~10 local NJ / IL stations.
- 60-second brief (below). Leave the one-pager (below). Not a syllabus.
- Ask for one quote you can use on DTC ads. Do not ask them to sell bands.
- Reddit / EMS Facebook: answer what they actually look for on a body. No dump.

### 60-second station brief (say this)

If you see a wine wristband with **MED ID** lasered on the plate: hold the
**top** of the phone to that plate, about an inch or two. Safari opens a
medical card. No app to install. No login. Allergies, meds, conditions,
contacts, and a Call button.

Walk-by will not fire. Payment terminals will not open this card. It is
self-reported ICE, not a hospital record. Call emergency services first.

### One-pager (print / leave at the station)

```
RED MED ID band

If you see a wine / burgundy wristband lasered MED ID:

1. Hold the top of the phone to the metal plate (~1–2 inches).
2. Safari opens a medical card. No app. No login.
3. Allergies, medications, conditions, contacts, Call.

Walk-by does not fire. Card readers / pay terminals do not open this card.
Self-reported ICE. Not a hospital chart. Call emergency services first.
```

No LMS. No QR to a course. No “scan to buy.” Optional: App Store URL only
after it is a real listing.

---

## Facility motion (parked)

Zero ad spend and zero outbound to hospitals until this is a **second
company**, not a Facebook campaign:

- LLC, product liability insurance, counsel on FDA “medical device” for
  facility-issued ID bands
- A decision to sign BAAs (Help.html today: RedMed is not a BA)
- A different SKU (lot tracking; pre-encode fights the blank-NDEF owner-write model)
- GPO / materials-management sales, not ads

v1 is DTC. Doing both at once splits budget and forces conflicting claims.
