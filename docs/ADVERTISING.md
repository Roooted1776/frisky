# RedMed advertising

GTM lock. Product code stays in Swift / `tapper/`. This file is what agents
and humans may put on ads, landing pages, Shopify, one-pagers, and captions.

Two views. Separate buyers, creative, and channels. Shared claim bans and
shared “do not tap-track the medical card.” Do not mash them into one ad.

| View | Buyer | Job | Money |
|------|-------|-----|--------|
| **A. Wearer / family** | Person at risk, or the caregiver who buys for them | Locked phone, unconscious, stranger needs the card | Shopify band + App Store |
| **B. Facility / EMS** | Station, agency, or facility that wants staff to *recognize and tap* a `MED ID` band, or (later) issue bands | Faster ICE on scene. Not an EHR. Not dispatch | Outbound / PO. Not Facebook |

Paid ads and “available now” stay off until the **shared product gate** is
green. View B has a **second company gate** on top of that.

Full claim bans also live in [`DO-NOT.md`](DO-NOT.md). Hardware sequence:
[`band-engraving-and-nfc-sourcing.md`](band-engraving-and-nfc-sourcing.md).
Do not put a storefront, course LMS, or ad pixel in this repo.

---

## Shared product gate

**$0 paid media on either view** until every line is true. Organic
build-in-public with no buy CTA is fine.

| Gate | How you know it is green |
|------|--------------------------|
| Live HTTPS `/tapper/` | `BASE=https://<host> ./scripts/smoke-pages.sh` returns OK. `AppConfig.medicalCardBaseURL` is that host. github.io is **404** until `Roooted1776.github.io` is published ([`domain.md`](domain.md)). |
| App Store listing | Paid Apple Developer. Real `apps.apple.com` ID. `AppConfig.appStoreURL` is that URL, not `nil`, not a placeholder. |
| NFC write on hardware | NFC Tag Reading on App ID `com.redmed.app`. `nfcHardwareEnabled = true`. Owner iPhone Write → second phone Safari opens the card. Simulator does not count. |
| Sample bands in hand | 1–10 wine/burgundy NTAG216 silicone, laser `MED ID`, NDEF blank unlocked. Proven write on a physical iPhone. |
| Somewhere to buy (view A) | Shopify (or equivalent) **after** the samples write. No storefront in this git tree. |

Do not skip to Shopify, Meta, Google, or hospital outbound while NFC is
parked, the listing is parked, or the band host 404s.

### Shared banned copy (both views)

- HIPAA certified / HIPAA compliant product
- Encrypted bracelet / locked to your phone / unreadable without Face ID
- Sends GPS or profile to 911
- Medical device / diagnoses / detects seizures / crash-proof
- Fake App Store URL or “available now” before Connect exists
- Walk-by tap at 6–8 inches (reliable coupling dies past ~4 inches; walk-by does not fire)
- Lives saved / we dispatch help
- Android can fill and write the band
- Mixing views: do not tell families “hospitals use this,” and do not tell
  facilities “download on the App Store and check out.”

### Shared allowed copy (both views)

- Self-reported medical ID
- Passive NFC (no battery, not Bluetooth)
- Any phone can tap
- Data stays on the chip and the iPhone
- Not a substitute for calling emergency services
- Intentional tap ~1–2 inches (`AppConfig.BraceletRF`, not invented inches)

### Shared measurement rule

No Meta Pixel, GA4, TikTok Pixel, or any tracker on `tapper/index.html`
(bundled `tapper.html`). A band tap is PHI in the fragment. `smoke-pages.sh`
fails the tree if those strings land. CSP `connect-src` is `'self'` plus
Overpass only; do not widen it for ads.

Conversion pixels: **view A store / App Store listing only.** View B does
not get a pixel on the card either. KPI is never “lives saved.”

---

## Hero creative (both views, one shoot)

Film on **hardware** after the product gate. Dummy profile only. No real PHI.
Do not film the Simulator. Do not film Edit / Face ID / NFC Write chrome.

Shoot **one** tap. Cut **two** ads from it. Do not invent a second concept.

**Length:** 15–20 s each. The tap-to-card moment is under 5 s.

### Shared footage

1. Wine / burgundy adult silicone. Laser plate reads `MED ID` only.
2. Top of a phone to the plate, ~1–2 inches. One deliberate tap.
3. Safari opens the card (name, allergies, meds, contacts, Call). Hold. Cut.

### View A cut (wearer / family)

Open on a locked iPhone, or a second phone that is not “open the RedMed app.”
Band on a wrist. Then the shared tap. End on the card.

Caption (pick one):

- “Locked phone. Unconscious. Tap the band.”
- “Tap the band. Medical ID opens. No app, no login.”

CTA: buy the band / get the iPhone app. iPhone required to **write**. Any
phone can **read**.

### View B cut (facility / EMS)

Open on gloved hands / a radio / a nametag. No patient face. Then the same
tap, framed as a medic’s phone. End on the card. No “buy now.”

Caption (pick one):

- “MED ID on the wrist. Top of the phone to the plate.”
- “No app. No login. Allergies and contacts in Safari.”

CTA: none in paid social. This cut is for the station one-pager, a demo
email, or a trade leave-behind. If you run it as a paid ad you are selling
to the wrong buyer.

**Do not show in either cut:** Face ID, Edit / Save, owner Help, crash
siren, “HIPAA,” encryption, a 911 autodial, a hospital EHR, a checkout.

This Linux environment cannot film an iPhone. Shoot on device after Write
works.

---

## View A — wearer / family (DTC)

**One line:** Tap the band. Medical ID opens. No app, no login.

**For whom:** People who already know they might be found down (epilepsy,
anaphylaxis, diabetes, heart, anticoagulants, autism / non-speaking, elderly
parent). Caregivers buying for someone else.

**Not for:** Hospitals as a system. Child SKU in v1. Android owners as
**writers**.

**What we are:** A better ICE bracelet. Self-reported medical ID on the
iPhone Keychain and, if written, on a passive NXP NTAG216. Passerby / EMT
opens Safari. No RedMed profile server.

**What we are not:** A medical network, a dispatch service, a MedicAlert
hotline, an EHR.

### Channels (after the product gate)

Order is locked. Do not invert it.

1. **Owned demo.** View A cut. Landing: tap video + what is on the band +
   iPhone required to write + not a medical device. App Store = software CTA.
   Shopify = band CTA. Do not turn bare `/tapper/` (No patient) into a store.
2. **Google Search first paid dollar.** Exact / phrase: `nfc medical id
   bracelet`, `medical id wristband nfc`, `ice bracelet nfc`,
   `road id alternative`. No treatment keywords (`epilepsy cure`, etc.).
3. **Meta / Instagram / TikTok second.** View A cut only. Health is
   restricted: **do not target by medical condition.** Age + caregiver /
   parent interests, then lookalikes from purchasers.
4. **Apple Search Ads** only after the listing is live. Query: medical ID,
   ICE, NFC medical.
5. **Skip:** Google Display, programmatic, podcasts, billboards, EMS magazine
   as a DTC channel, free-course funnels, pixels on the tap card.

### Budget (view A)

- 70% Google Search + Apple Search Ads
- 30% short-form demo (Meta / TikTok)
- Kill short-form if CPA > band margin after 2 weeks
- Cap learning spend. Kill any ad that uses a banned claim
- Do not fund view B from this mix

### Offer (view A)

- **SKU:** wine adult silicone + NTAG216 + laser `MED ID`. One color.
- **App:** free or cheap. Margin is the band. No SaaS for a local-only profile.
- **No subscription.** No server to justify one.
- Price against Road ID (~$30–70) plus a small NFC premium.

KPI: band orders + App Store downloads.

---

## View B — facility / EMS

This is a **sales motion**, not a Facebook campaign. Help.html today: RedMed
is an individual in NJ, not a covered entity, not a BA, not an FDA device.
You cannot honestly sell “hospital ICE infrastructure” on that posture.

### Company gate (on top of the product gate)

Zero outbound to materials management / GPO / hospital admin, and **$0 paid
media aimed at facilities**, until:

- LLC (or equivalent), product liability insurance
- Counsel on FDA “medical device” for *facility-issued* ID bands
- A written decision on BAAs (today’s Help text says you will not sign)
- A SKU story that matches the chip: **blank NDEF, wearer/staff writes from
  an iPhone**, not a pre-encoded vendor cloud and not an EHR push
- Support domain and a real invoice path (not `help.RedMed@gmail.com` only)

Until that gate is green, view B is **recognition training only**: staff
learn to tap a band a *patient already wears* (view A product). You are not
selling the hospital a system.

### Who actually pays

| Who | Do they buy? | What you offer |
|-----|----------------|----------------|
| Street EMS / fire | Almost never a bracelet PO | 60s tap brief + one-pager. Quote for view A ads. |
| Hospital / clinic admin | Only after the company gate | Lot of the same wine `MED ID` band + “staff tap” card. Owner-write still. No BA, no EHR, no HIPAA badge. |
| EMS educator / training officer | Maybe a box of demos | Dummy-profile bands for skills night. Same SKU. |

Do not run a course LMS or “free training → software demo → hardware
upsell.” Time-poor medics ignore unknown courses. Giveaways of bands that
404 burn the station.

### Channels (after the company gate)

1. **In person first.** 10 local NJ / IL stations (script below). Then, if
   the company gate is green, materials management / volunteer coordinator
   by referral. Not cold Meta.
2. **Leave-behind.** View B cut + one-pager. No checkout QR. App Store URL
   only if it is a real listing (for the *wearer’s* iPhone, said out loud).
3. **Skip:** Facebook/TikTok prospecting at “hospital staff,” Google Display
   on clinical keywords, trade-mag ads before you can invoice, webinar funnels.

If you spend paid media on view B before the company gate, you are lying
about who you are (an LLC with insurance) or about what the product is
(an EHR / BA / medical device).

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

Ask for one quote you can use on **view A** ads. Do not ask them to sell
bands. Reddit / EMS Facebook: answer what they actually look for on a body.
No affiliate dump.

### Offer (view B, only after company gate)

Same physical SKU as view A unless counsel says a facility-issued band needs
lot tracking. Still NTAG216, wine, laser `MED ID`, blank unlocked, owner
Write. Pre-encode and vendor short-links stay forbidden
([`band-engraving-and-nfc-sourcing.md`](band-engraving-and-nfc-sourcing.md)).

No subscription. No “HIPAA mode.” No RedMed server for profiles. If they
need a BA and an EHR ingest, **walk**. That is a different product.

KPI: demo nights run, quotes collected, (after company gate) POs. Not
impressions.
