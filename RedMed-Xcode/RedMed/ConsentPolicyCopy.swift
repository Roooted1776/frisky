import Foundation

/// Privacy, Security, and Terms shown as one block on Before you continue.
/// Keep in lockstep with Help.html Version 4.1.
enum ConsentPolicyCopy {
    static let text = #"""
Privacy

Effective August 2026

Version 4.1 (United States)

Law US federal and state privacy law (including CCPA/CPRA for California residents)

Applies to people in the United States who use the RedMed app or a RedMed NFC band

In short
RedMed keeps your medical ID on your phone and, if you write one, on your band. We run no profile server. We never receive your allergies, meds, conditions, contacts, or GPS. Anyone who deliberately taps the band can read the card — treat it like a printed medical ID. Not a medical device. Not "HIPAA certified." Call 911 first in a real emergency.

This Privacy page explains what RedMed does and does not hold about you. Read it with Terms and Security.

1. Who we are

For any personal information we do control, RedMed is operated by an individual based in the State of New Jersey, United States ("RedMed", "we", "us"), not a registered company. There is no separate corporate entity behind RedMed at this time.

Contact: help.RedMed@gmail.com.

2. What RedMed is

RedMed is a consumer app for a local emergency medical ID: store self-reported details on your iPhone, optionally write them to a passive NFC band, call for help, and show on-device first-aid while waiting for professionals.

It is not a hospital portal, not an electronic health record, not insurance software, and not a promise that EMS will arrive or that anyone will get a particular medical result. Full limits are in Terms.

3. HIPAA — local only, not certified

HIPAA regulates covered entities and their business associates when they handle protected health information ("PHI").

RedMed is not a covered entity and is not a business associate for your RedMed profile. We do not treat patients, process claims, or run an EHR. Your profile never lands on a RedMed server.

That local-only design is HIPAA-aligned for RedMed as operator — we never create, receive, maintain, or transmit your profile as PHI on our systems. It is not a purchased "HIPAA certified" badge, and we do not market RedMed as a HIPAA-covered product.

If EMS or hospital staff tap the band and later enter what they see into their systems, that organization's HIPAA rules may apply to its copy. RedMed does not push data into a hospital EHR and does not become their business associate for bracelet contents.

This page is not a HIPAA Notice of Privacy Practices.

4. What information exists

• Medical ID (self-reported): name, birth date, blood type, allergies, medications, conditions — fields a responder may need fast.

• Emergency contacts: names, relationships, and phones you choose to list. Tell those people you listed them.

• Location: coordinates and heading shown only while Find Help is open, so you can read them to a dispatcher.

• Apple Health (optional): if you tap Fill from Apple Health, RedMed reads birth date and blood type from HealthKit on this iPhone. Read-only. Never written back to Health. Never sent to us.

• Support email: if you write us, we see the address and message you send.

• Motion data (crash/impact alarm): while the App is unlocked, it can read your iPhone's motion sensors to detect a possible vehicle crash or severe impact and trigger a local alarm. See Terms §7. This processing happens only in memory on your device to evaluate the last few seconds of motion — it is never stored, logged, or sent to us.

Providing a profile is optional. Leaving fields blank is fine; an empty card is less useful in an emergency.

5. Where it lives

Your profile stays on your iPhone Keychain and, if you write one, on the band's NFC chip. It is not uploaded, synced, or backed up to any RedMed server — we do not operate one for profiles.

On iOS we use the WhenPasscodeSetThisDeviceOnly Keychain class bound to biometryCurrentSet (Face ID / Touch ID): readable only after a successful owner biometric, and excluded from iCloud and encrypted backups. It does not sync to your other Apple devices. Enrolling a new Face ID invalidates the stored profile.

When someone taps the band, nothing is fetched from us. The card is built from what is on the chip (#d= in the URL fragment).

6. The band is readable by design

RedMed writes a passive NXP NTAG216 HF NFC chip (13.56 MHz, ISO 14443A Type 2). No battery. No Bluetooth. The phone powers it only during a close write or tap.

Anyone who deliberately taps the band can open the card — no app, no account, no password. New writes use AES-GCM packing with a public client key shared by the app and the passerby page. That hides casual plaintext in the fragment; it is not confidentiality against a responder (or anyone else) who opens the URL.

Treat the band like a wallet medical ID. Do not put anything on it that you would not accept a stranger reading. Leave sensitive fields blank if you prefer.

Casual walk-by distance will not fire the band. A deliberate ~1–2″ antenna tap can. Separately, iOS Background Tag Reading can open the card on that kind of tap even when the phone is off or locked — Apple's path, not RedMed. Payment terminals speak EMV and do not open the RedMed card. More detail: Security.

7. Location (Find Help)

Find Help shows coordinates only while that screen is open. GPS starts when Find Help needs it and stops when you leave or close the app. Location is not used for ads, profiling, or background tracking, and is never sent to us.

Location defaults on (toggle on the "Before you continue" screen shown after Face ID). RedMed does not show an in-app location gate. The first time Find Help needs GPS, iOS may show its own When-In-Use Allow dialog — Apple requires that tap; we cannot auto-accept it.

The Call button opens the system Phone app to your regional emergency number only. RedMed does not attach name, medical fields, contacts, GPS, or any other profile data to that call.

8. Who else can see data

• Anyone who taps your band (or opens a card link with your #d=) can read the self-reported ID on it. That local handoff is the product.

• Your phone's OS apps — Phone, Messages, Maps, Share Sheet — when you use them. Apple's rules apply there. Dispatchers hear or read what you say or type, not a RedMed server copy.

• No ad networks, no analytics IDs, no data brokers, no account signup. We do not sell personal information or share it for cross-context behavioral advertising.

9. How long it lasts

We keep none of your RedMed profile, because we receive none. It stays on your phone and band until you remove it.

On the phone: Help → Erase all RedMed data (Face ID), clear fields in Edit and save, or delete the app. On the band: overwrite the chip or dispose of the band securely. We cannot wipe a band remotely — there is no link from us to the chip.

Support emails are kept only as long as needed to answer you, then deleted.

10. Your rights (United States)

Most controls are on your device: edit to correct, erase or delete the app to remove, rewrite or discard the band. You do not need our permission.

For anything we do hold (for example a support email), write help.RedMed@gmail.com. We will respond within a reasonable time and within any deadline required by the law that applies to you.

California (CCPA/CPRA). Residents may have rights to know, access, delete, correct, and opt out of "sale" or "sharing," and to limit use of sensitive personal information, subject to exceptions. RedMed does not sell personal information and does not share it for cross-context advertising. There is no RedMed profile database to disclose. For limited records we may hold, email us with "California Privacy Request" in the subject line. We will not discriminate against you for exercising privacy rights.

Other state privacy laws may grant similar rights. Use the same address; we will handle requests as required.

11. Automated decisions

None. RedMed does not score, triage, or risk-rate you. The seizure stopwatch is a timer you start; it does not detect seizures.

12. Cookies and cache

The passerby card may keep its static shell in browser Cache Storage so a later tap opens offline. Medical fields stay in the URL #d= fragment and are not written into that cache. No advertising or analytics cookies. The owner profile lives in Keychain, not web localStorage.

13. Children and people you support

RedMed is not directed to children under 13, and we do not knowingly collect their information on RedMed servers. Only an adult who meets the eligibility rules in Terms §16 may create a profile for a child or an adult they support. That adult is responsible for accuracy and for what goes on the band. A child's band is as readable as an adult's.

14. Changes

We may update this page. The Effective date above shows the latest revision. Material changes will appear in the app where practicable.

15. Contact

help.RedMed@gmail.com

Security

Effective August 2026

Version 4.1 (United States)

Read with Privacy and Terms

How RedMed protects the iPhone app, the passerby card, and the NFC band in the United States

In short
Profile stays on your phone (Keychain) and on the band if you write one. No RedMed profile backend. Owner Face ID gates edit, write, unlock, and local history. Band tap needs no Face ID — EMS must read it cold. Packing on the chip is obfuscation, not a private vault.

This page describes how RedMed approaches security. It is informational, not a warranty, and does not change the medical-device, no-outcome, or liability terms in Terms.

1. What we defend

Security work focuses on: keeping patient ID off RedMed servers; protecting on-device storage; hosted page integrity for the passerby card; and safe rendering of untrusted #d= payloads. We do not try to make a passive NFC ID confidential against a deliberate close tap — that would break the EMS handoff.

2. On-device profile

• Profile fields in iOS Keychain with WhenPasscodeSetThisDeviceOnly and biometryCurrentSet (Face ID). Legacy unbound blobs migrate on next load.

• Readable only while unlocked; excluded from iCloud and encrypted backups.

• Local history / vault files use complete file protection and backup exclusion.

• Owner Face ID / biometrics gate app unlock, Edit, NFC write, and Local History. Erase still prompts.

• Passerby tapper.html never asks for Face ID, passcode, or login — tap opens the card from #d=.

• App-switcher snapshots are covered while profile data is in memory so live fields are not cached in the system snapshot.

• Help → Erase all RedMed data deletes Keychain profile and vault files on this iPhone. The physical band is not wiped remotely.

3. NFC band

Writes use AES-GCM packing with a public client key shared by the app and tapper.html. Any phone that loads the card can decrypt. A private key would defeat "tap with no account." Cloning a tag is like photocopying a wallet medical card.

Walk-by distance will not fire the band; a deliberate ~1–2″ antenna tap can. RedMed does not background-scan. The band stays passive — no battery. iOS Background Tag Reading can still open the card on that deliberate tap when the phone is off or locked. Payment / POS terminals use EMV and do not open the RedMed card.

The card page renders fields with textContent, length caps, and phone sanitization. There is no RedMed profile server.

4. Location

GPS starts only on Find Help (When-In-Use). Coordinates stay on-device for display. We do not receive, log, or retain them. Accurate coordinates and a successful 911 call are not guaranteed.

5. Crash / severe-impact alarm

The on-device motion monitor described in Terms §7 runs entirely on the phone: no network call, no upload, no RedMed server involvement. It evaluates a short rolling window of motion sensor data to estimate whether a severe impact occurred, then discards it. A false trigger or a missed trigger is a known limitation of on-device motion heuristics, not a data-security failure — see Terms §7, §13, and §14 for the corresponding disclaimers and liability limits.

6. HIPAA alignment (operator)

Same posture as Privacy: no profile on our systems → RedMed is outside the covered-entity / BA path for that profile. Device Keychain and no backend are the controls. They are not a hospital Security Rule program and not a "HIPAA certified" claim.

7. Report a vulnerability

Open a private GitHub security advisory on Roooted1776/frisky for XSS in #d= rendering, Keychain / vault bypass, or owner unlock gate bypass. Or email help.RedMed@gmail.com. Do not file public issues with live keys or real medical payloads. See docs/SECURITY.md.

8. Trust root

There is no RedMed profile server. The trust root is the owner's iPhone: Keychain, biometrics gates, RAM purge on background, vault file protection, and the band fragment if written.

9. Contact

help.RedMed@gmail.com

Terms

Effective August 2026

Version 4.1 (United States)

Governing law Laws of the State of New Jersey, United States

Applies to people in the United States who use the RedMed app or a RedMed NFC band

Important
RedMed is a local EMS assist: medical ID on your phone and band, help calling 911, and on-device Aid while you wait. It is not a medical device, not medical advice, and it does not promise any medical outcome. Call 911 first when life is on the line.

1. Who we are

RedMed is provided by an individual based in the State of New Jersey, United States ("RedMed", "we", "us"), not a registered company. Contact: help.RedMed@gmail.com.

2. Agreement

These Terms govern the RedMed iPhone app and any associated passive NFC medical band programmed through the app (together, the "App").

By downloading, installing, opening, or using the App — as the person who creates a profile, or as anyone who views a card by tapping a band or opening a #d= link — you agree to these Terms and to Privacy. If you do not agree, do not use the App.

In the owner iPhone app, after Face ID, first launch (and any material policy change) requires an explicit I-agree tap before the App is usable. A passerby who only views a band card agrees by opening that card.

Nothing here limits rights you cannot waive under US consumer-protection law. Where a term conflicts with a non-waivable statutory right, that right wins.

3. What the App does

• Medical ID — store self-reported name, birth date, blood type, allergies, meds, conditions, and contacts on your phone; optionally write them to a passive NFC band.

• Find Help — dial the regional emergency number, show coordinates to read aloud, optional seizure stopwatch you start yourself.

• Aid — general first-aid / CPR guidance on-device while waiting for professionals.

• Band tap — any phone that taps a written band can open the emergency card in a browser with no app install and no login.

That is an assist. It is not care delivery and not a promise that EMS will arrive or that a hospital will use the information.

RedMed runs no servers for your profile. After setup, the band card is rendered from the chip fragment, not fetched from us.

No promised result. We do not warrant that EMS will arrive, that a bystander will act, that a tap will succeed, that GPS will be accurate, that Aid content fits the situation, or that anyone will survive or improve because RedMed was used.

4. HIPAA pointer

As explained in Privacy: your profile never leaves your device or band for RedMed's systems. RedMed is not a HIPAA covered entity or business associate for that profile, and we do not market "HIPAA certified." Do not use RedMed as a substitute for records kept by your clinicians, hospitals, or insurers.

5. Accuracy is on you

You control what you enter. RedMed does not verify allergies, meds, conditions, or blood type. Keep the profile and band current when facts change. Responders should verify critical details when they can and use their own judgment.

6. Find Help and location

Location and compass are used only while Find Help is visible, to display coordinates you can read to 911. Defaults on (toggle on the "Before you continue" screen shown after Face ID). First GPS use may trigger iOS's When-In-Use Allow dialog — we cannot skip it.

The optional seizure stopwatch is started by you. At five minutes it may open the dialer. It does not detect seizures and must never delay an earlier call when one is needed.

RedMed does not use Apple's Emergency SOS via satellite, Apple Crash Detection API, or carrier satellite messaging — see §7 for RedMed's own, separate crash/impact alarm. Find Help may open Phone or Messages, or describe those built-in steps when there is no cell signal; RedMed does not operate those radios. Coordinates stay on-device and are not sent to us.

7. Automatic crash / severe-impact alarm

Separately from Find Help, the App can run an on-device motion monitor (built by RedMed, not Apple's Crash Detection) that watches your iPhone's motion sensors while the App is unlocked. If it detects a sudden, severe impact consistent with a vehicle crash or comparable event, it can automatically trigger a local alarm — maximum screen brightness, maximum device volume, and an audible siren — to draw attention and help you or a bystander find the phone and call for help. You can stop the alarm at any time with the on-screen "Stop the alarm" control.

The alarm is local and automatic only. It does not call 911, does not message anyone, does not transmit your location or any data to RedMed or anyone else, and does not detect every crash or every severe impact. It is tuned to avoid triggering during ordinary daily motion (walking, running, exercise, and other normal handling of the phone), which means it can also fail to trigger during an actual crash, and it can trigger by mistake during unrelated hard impacts (for example, a dropped phone or a hard fall). Do not rely on the alarm instead of calling 911 if you are able to call. Motion data used to evaluate a possible impact is processed only in memory on your device for this purpose and is not stored or transmitted.

Using the alarm as a substitute for a monitored medical device, a certified crash-detection system, or a direct call to 911 is outside its intended purpose and at your own risk.

8. No medical advice

Aid content is general public information, similar to material from public-health sources. It is for education while you wait for EMS. It is not personalized medical advice and creates no clinician-patient relationship.

YOU ACKNOWLEDGE THAT REDMED DOES NOT PROMISE OR WARRANT ANY PARTICULAR RESULT — INCLUDING THAT HELP WILL BE REACHED, THAT RESPONDERS WILL USE THE INFORMATION, THAT TREATMENT WILL BE CORRECT, OR THAT HARM WILL BE AVOIDED. Use of Aid or Find Help is at your own risk and never replaces calling 911.

9. Not a medical device

The App and band are not medical devices under the Federal Food, Drug, and Cosmetic Act or FDA rules for their current purpose: consumer storage and display of self-reported emergency ID, plus a convenience assist for contacting emergency services. RedMed is not FDA-cleared, approved, or registered as a device for diagnosis, treatment, cure, mitigation, or prevention of disease.

RedMed does not diagnose, treat, monitor vitals, or provide clinical decision support. The band is a passive NFC tag — the digital equivalent of a wallet medical ID — not a therapeutic instrument. The crash/impact alarm in §7 is a local attention-getting signal, not a monitor, diagnostic tool, or treatment system.

Using RedMed as if it were a monitor, alarm, or treatment system is outside the intended purpose and at that person's sole risk.

10. Call 911 first

Nothing in the App should delay calling 911. Prefer calling before reading Aid or writing a band. If you are deaf, hard of hearing, or speech-impaired, use TTY 911, relay, or text-to-911 where available.

11. Helping someone else

Many US states have Good Samaritan laws that can limit civil liability for people who render emergency aid in good faith. Those laws vary. This is general information, not legal advice. RedMed does not represent that any particular action taken with the App will be protected under any state's law.

12. Availability

We aim to keep the App working as described, but we do not promise uninterrupted service or that GPS, NFC, compass, motion sensors, or other device features will work on every phone or in every situation. Those features come from your device and OS.

13. Disclaimers

TO THE MAXIMUM EXTENT PERMITTED BY LAW, THE APP AND ANY BAND ARE PROVIDED "AS IS" AND "AS AVAILABLE," WITHOUT WARRANTIES OF ANY KIND, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE, AND NON-INFRINGEMENT. WITHOUT LIMITING THE FOREGOING, REDMED DISCLAIMS ANY WARRANTY THAT THE APP OR BAND WILL (A) FUNCTION AS A MEDICAL DEVICE; (B) DETECT, DIAGNOSE, TREAT, OR PREVENT ANY CONDITION; (C) REACH EMS OR ANY THIRD PARTY; (D) PRODUCE ANY PARTICULAR MEDICAL OR RESCUE OUTCOME; (E) DETECT A REAL CRASH OR SEVERE IMPACT, OR AVOID TRIGGERING THE ALARM IN §7 WHEN NO CRASH OCCURRED; OR (F) BE ERROR-FREE, AVAILABLE, OR COMPATIBLE WITH EVERY DEVICE OR NETWORK. SOME STATES DO NOT ALLOW LIMITATIONS ON IMPLIED WARRANTIES, SO SOME OF THE ABOVE MAY NOT APPLY TO YOU.

14. Limitation of liability

TO THE MAXIMUM EXTENT PERMITTED BY LAW, REDMED AND ITS OFFICERS, DIRECTORS, EMPLOYEES, AND AGENTS WILL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, EXEMPLARY, OR PUNITIVE DAMAGES, OR FOR ANY LOSS OF DATA, PROFITS, OR BUSINESS, OR FOR ANY CLAIM ARISING FROM PERSONAL INJURY, WRONGFUL DEATH, FAILED RESCUE, DELAYED CARE, RELIANCE ON SELF-REPORTED PROFILE DATA, AID CONTENT, GPS/COORDINATES, NFC READ FAILURE, A MISSED OR FALSE TRIGGER OF THE CRASH/IMPACT ALARM IN §7, OR THE ACTS OR OMISSIONS OF EMS, BYSTANDERS, OR OTHER THIRD PARTIES, ARISING OUT OF OR RELATED TO YOUR USE OF THE APP OR A BAND, WHETHER BASED IN CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT PRODUCT LIABILITY, OR OTHERWISE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

TO THE MAXIMUM EXTENT PERMITTED BY LAW, OUR TOTAL LIABILITY FOR ANY CLAIM ARISING OUT OF OR RELATED TO THESE TERMS OR THE APP WILL NOT EXCEED THE GREATER OF (A) THE AMOUNT YOU PAID US FOR THE APP OR BAND IN THE TWELVE MONTHS BEFORE THE CLAIM OR (B) FIFTY US DOLLARS (US $50).

Nothing here excludes liability that cannot be excluded under applicable law, including fraud or death or personal injury caused by negligence where such exclusion is prohibited. Where a limitation is partially unenforceable, it applies to the maximum extent allowed.

15. Your responsibility

Use the App only as permitted by these Terms and applicable law. If you use it in the course of a business, you agree to defend and indemnify RedMed against claims, losses, and reasonable attorneys' fees arising from your use in breach of these Terms, except to the extent caused by our willful misconduct.

16. Eligibility

You must be at least 18 years old, or the age of majority in your jurisdiction, and have capacity to enter a binding contract, to create and manage your own profile or to accept these Terms on behalf of a child or another adult. A parent, guardian, or caregiver who is under that age may not use the App to create a profile for someone else. If you create or manage a profile for a child or an adult you support, you confirm you have authority to do so and you are responsible for accuracy. See Privacy §13 for our position on data from children under 13.

17. Physical bands

If you buy a band from us or an authorized seller:

• Medical information is written to a passive NXP NTAG216 at 13.56 MHz (ISO 14443A Type 2, NDEF blank unlocked). No battery, no Bluetooth, no sensors. Laser face: MED ID only.

• Any smartphone that deliberately taps it can read the card, including under iOS Background Tag Reading when the phone is off or locked. That is intentional so responders need no app.

• The payload uses AES-GCM packing with a public client key (not confidentiality). Treat the band like a printed medical ID.

• Rewrite the band after you change your profile.

• Returns and refunds follow checkout terms and applicable state law. Overwrite or erase the chip before returning when you can — we cannot wipe it remotely.

18. Changes

We may revise these Terms. If a change materially affects your rights, we will tell you in the App or by a contact you gave us before it takes effect. Material changes require you to re-accept these Terms in the App before you can keep using it. You may stop using the App. The Effective date above shows the latest revision.

19. Disputes

Contact us first at help.RedMed@gmail.com. We will try in good faith to resolve any dispute informally for at least 30 days before either side starts a formal proceeding. Except where prohibited or as provided in §20 (Arbitration), these Terms are governed by the laws of the State of New Jersey, without regard to conflict-of-law rules, and any dispute not subject to arbitration is brought exclusively in the state or federal courts located in New Jersey. You may have additional rights under the laws of your state of residence.

20. Arbitration and class action waiver

Please read this section carefully. It affects your legal rights, including your right to file a lawsuit in court.

You and RedMed agree to resolve any dispute, claim, or controversy arising out of or relating to these Terms, the Privacy or Security pages, or your use of the App or a band (a "Claim") by binding individual arbitration under the Consumer Arbitration Rules of the American Arbitration Association (AAA), rather than in court, except that either side may bring an individual claim in small claims court if it qualifies, and either side may seek injunctive relief in court for misuse of intellectual property.

Class action waiver. Claims must be brought in your individual capacity, not as a plaintiff or class member in any purported class, collective, consolidated, or representative proceeding. The arbitrator may not consolidate more than one person's claims and may not otherwise preside over any form of a representative or class proceeding. If this class action waiver is found unenforceable as to a particular Claim, that Claim (and only that Claim) may proceed in court, and the rest of this arbitration agreement still applies to all other Claims.

This arbitration agreement does not apply to Claims that cannot be subject to mandatory arbitration under applicable law, and nothing here limits any non-waivable right you have under such law. You may opt out of this arbitration agreement by emailing help.RedMed@gmail.com with the subject line "Arbitration Opt-Out" within 30 days of first accepting these Terms, including your name and that you opt out; if you opt out, disputes are resolved under §19 instead.

21. Severability

If any provision is held invalid or unenforceable, the rest stays in effect.

22. Contact

help.RedMed@gmail.com
"""#
}
