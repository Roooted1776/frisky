# FDA 520(o) / wellness claims wall

**Audience:** Arrival Day Pack (blank NTAG216 + Pack/Share) and station
sell / leave-behinds. Agents and humans paste from here. Not legal advice;
counsel owns device / HIPAA classification.

**Product gate while Write is parked:** public claims stay at **store /
transfer / display** of self-reported emergency ID, plus **Share honesty**
(Share Band URL / Preview pack `#d=` — not a chip write, not Linked). No
write-from-app. No Shortcuts coaching. No clinical-threshold marketing.

Primary FDA guidance (read before any new claim):

| Doc | URL |
|-----|-----|
| General Wellness: Policy for Low Risk Devices | https://www.fda.gov/regulatory-information/search-fda-guidance-documents/general-wellness-policy-low-risk-devices |
| Changes to Existing Medical Software Policies Resulting from Section 3060 of the 21st Century Cures Act (`Guidance-Devices-3060`) | https://www.fda.gov/media/109622/download |
| Clinical Decision Support Software | https://www.fda.gov/media/109618/download |

Also: [`ADVERTISING.md`](ADVERTISING.md) (banned ad copy),
[`DO-NOT.md`](DO-NOT.md), [`APP-STORE.md`](APP-STORE.md),
[`NFC-RESTORE.md`](NFC-RESTORE.md),
[`FOUNDER-WHY.md`](FOUNDER-WHY.md) (About / station / Pack why — categories
only, no chart dump).

---

## Lane (locked)

**Cures Act §520(o)(1)(D)** (as implemented in FDA’s §3060 software
guidance): software functions that **solely** transfer, store, convert
formats, and display medical device data / results — **without**
interpreting or analyzing those data to support clinical decision-making —
are pulled out of the FD&C Act “device” definition for that function.

**General Wellness** (low-risk policy): stays out of active FDA device
enforcement when intended use / claims stay lifestyle / general wellness
and the product is low risk. Disease / clinical decision claims do not.

**RedMed Arrival Day story that matches those lanes:**

- User-entered emergency ID on iPhone Keychain (store / display).
- Pack Band URL / Share Band URL / Preview: pack the same `#d=` URI Write
  will use later (transfer / display of user-entered text). Not analysis.
- Blank unlocked NTAG216 silicone: passive store-and-display when written;
  until Write is proven, sell blank + Share honesty only.
- Station brief: how to **tap and read** a card someone already wears. Not
  triage. Not EHR. Not dispatch.

**[GUESS — counsel confirm]** Blank NTAG216 + Pack/Share of
**user-entered** emergency info stays out of the device lane **if**
marketing never claims interpretation, analysis, diagnosis, monitoring,
clinical decision support, or outcomes. One wrong station email (“we
analyze allergies for your protocol,” “HIPAA-compliant hospital ICE,”
“clinical thresholds on the band”) can drag scrutiny. Do not invent claims
and ask counsel later.

Crash / impact alarm, Aid first-aid text, and the seizure stopwatch are
**owner-app assists**, not Arrival Day Pack / station sell claims. Do not
put them on Shopify, station one-pagers, or App Store promotional text
while this wall is in force. (In-app Help / Medical Disclaimer already
disclaim device / outcome language.)

---

## Allowed public claims (Arrival Day Pack + station)

Use these or shorter equivalents. Do not embroider.

| Surface | Allowed line |
|---------|----------------|
| Pack / Share honesty | Share Band URL and Preview pack a `#d=` helper card from what you typed. They do **not** write the chip and do **not** mark Linked. |
| Blank SKU | Blank NXP NTAG216. Passive NFC. No battery. No Bluetooth. You enter the info. |
| Store / display | Self-reported medical ID on your iPhone (and on the band when write is available). |
| Tap / read | Any phone can tap a written band; Safari shows the card. No app. No login. |
| Station brief | Top of the phone to the RedMed plate (~1–2 inches). Self-reported ICE. Call emergency services first. |
| Negatives (ok) | Not a medical device. Not “HIPAA certified / compliant.” Not a hospital chart. Not dispatch. |

---

## Forbidden while Write is parked

Do **not** put these on Shopify, App Store promotional text, captions,
station email, one-pagers, or dept pitch decks:

1. **“Medical device”** (or FDA-cleared / registered / approved device) as a
   product boast — Help/Terms may say *not* a medical device; marketing
   does not debate device status beyond that denial.
2. **“HIPAA compliant” / “HIPAA certified” / “HIPAA-aligned product.”**
3. **Write-from-app** — “write from the app,” “program the band in RedMed,”
   “NFC write available now,” until Tag Reading + Write The Band are proven
   on blank NTAG216 ([`NFC-RESTORE.md`](NFC-RESTORE.md)).
4. **Shortcuts / NFC Tools coaching** as the product write path.
5. **Clinical thresholds / coaching in sell copy** — seizure “at 5:00”
   marketing, triage scores, risk ratings, “detects seizures,” protocol
   automation, CDS-style “if allergy X then…”.
6. Interpret / analyze / diagnose / monitor vitals / clinical decision
   support / lives saved / we dispatch.
7. Asking stations or wearers to **email / upload / host PHI on RedMed**.

When Write flips green, reopen write-from-app storefront copy only. Do not
quietly add clinical-threshold ads.

---

## Counsel answers (repo audit)

### Any App Store copy still saying write-from-app?

**No.** Connect listing is parked (`docs/APP-STORE.md`: no paid listing /
fake `apps.apple.com` ID). In-repo fields:

- Sign-off: “Listing must not promise live bracelet write until NFC
  entitlement is restored.”
- Review notes: pack-only Write + Share Band URL + Preview; no CoreNFC
  session.
- Locked **Promotional Text** draft in `APP-STORE.md` is store / Share
  honesty only — no write-from-app sentence.

There is nothing live on App Store Connect to scrub. Do not paste write
claims into Connect when the listing opens until the write checklist is
green.

### Covered-entity creep if stations ask RedMed to host PHI?

**Yes — walk.** Today’s posture: no profile server, no BA, Help says
operator is outside covered-entity / BA for the wearer’s local profile.
If a station asks RedMed to **host, maintain, or receive** bracelet /
patient PHI (portal, inbox “send us their allergies,” shared drive,
vendor short-link SaaS), that is covered-entity / BA creep. Refuse. Do not
sign a BAA to paper over a host you do not run. Recognition training +
blank/owner-write SKU only ([`ADVERTISING.md`](ADVERTISING.md) view B).

Support mail (`help.RedMed@gmail.com`) stays troubleshooting only — never
request full medical profiles; delete threads when resolved.

---

## Station email / one-pager discipline

Before any outbound to a station:

1. Paste only from **Allowed public claims** above or the 60s brief /
   one-pager in [`ADVERTISING.md`](ADVERTISING.md).
2. No HIPAA badge. No “medical device.” No write-from-app. No Shortcuts.
3. No ask for patient lists or PHI copies.
4. If they want hosted records or EHR ingest: **walk.**

One wrong sentence in a station thread is enough to invite device or HIPAA
scrutiny the Arrival Day Pack does not need.
