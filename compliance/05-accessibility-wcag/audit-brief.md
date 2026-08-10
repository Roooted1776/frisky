# WCAG 2.2 AA audit — auditor brief

**Document ID:** RM-A11Y-002
**Purpose:** send to accessibility auditors for quotes, then hand to the
appointed firm as their scoping pack. Pairs with [`README.md`](README.md)
(internal static review and known gaps).

---

## 1. What is being audited

RedMed — native iOS app (SwiftUI, iOS 17+, portrait only) plus a small set of
HTML legal pages rendered inside the app via WebKit. There is also a passive NFC
bracelet whose tap resolves to a public card view.

Standard: **WCAG 2.2 AA**, applied to a native mobile app. We expect you to work
from WCAG 2.2 AA plus mobile-specific guidance rather than pretending the app is
a web page, and to tell us where a criterion maps awkwardly.

This is for **NHS supplier assurance (DTAC)**, so the report needs to survive an
NHS accessibility reviewer, and we will need a statement we can attach.

## 2. Screen inventory

Owner-side app, four tabs behind a custom tab bar:

| Screen | Source | What it does |
|--------|--------|--------------|
| Tab shell + custom tab bar | `ContentView.swift` | Custom `TabBarItem` controls, not a system `TabView` — focus order and labelling need attention |
| My ID | `MyIDView.swift` | Medical profile card: name, DOB, blood type, allergies, medications, conditions, contacts, organ donor status |
| Edit profile | `EditProfileView.swift` | Form entry for all of the above, behind a biometric gate |
| Find Help | `EmergencyView.swift` | Live GPS coordinates card, emergency dial buttons, seizure stopwatch that prompts a call at 5:00, nearby-hospital list |
| Aid | `AidView.swift` | First-aid topic panes, expanding cards, emoji-led pane cues |
| Aid topic detail | `TopicDetailView.swift` | Symptoms and care steps for a topic, plus a dial control |
| NFC | `NFCView.swift` | Bracelet pairing and write flow (owner only; hidden in scanner sessions) |
| Public card | `PublicCardView.swift` | Read-only card a rescuer sees; scanner session hides all owner controls |
| Help / legal | `HelpMenuView.swift` | WebKit host for the bundled HTML below |

Bundled HTML rendered in-app: `PrivacyPolicy.html`, `TOS.html`,
`HowItWorks.html`, `security.html`, shared `legal-doc.css`. **These need a web
WCAG pass in their own right** — please price that as part of the engagement.

System surfaces in the flows: Face ID / Touch ID / passcode prompt, location
permission prompt, Phone hand-off, SMS composer, MapKit views.

## 3. Known state — please do not treat this as a clean slate

We ran a static review of the shipping sources. Two measured facts you should
price against:

- **There are zero `accessibility*` modifiers in the entire shipping tree**
  (`RedMed-Xcode/RedMed/*.swift`). No labels, no hints, no traits, no
  `accessibilityElement` grouping anywhere. Assume nothing has been done.
- **Hard-coded `.system(size:)` font sizes in nine files, down to 9 pt.** Dynamic
  Type behaviour is likely poor across the board.

Our own suspected gaps, for your triage rather than as findings:

| ID | Issue | Criterion | Where |
|----|-------|-----------|-------|
| A01 | Hard-coded small font sizes (9–13 pt) | 1.4.4 | Aid, Emergency, cards |
| A02 | Accent red carrying meaning without text or icon redundancy | 1.4.1 | Status, tabs |
| A03 | Muted grey on cream / pink backgrounds | 1.4.3 | `.redmedMuted` on `.redmedBg` in `Theme.swift` |
| A04 | Emoji-only pane cues | 1.1.1, 4.1.2 | Aid panes |
| A05 | Timer and GPS numeric updates not announced | 4.1.3 | Seizure strip, GPS card |
| A06 | Decorative dividers standing in for structure | 1.3.1 | Card stacks |
| A07 | Hit target size on dense trauma grid | 2.5.8 | Trauma grid |
| A08 | Animations vs Reduce Motion | 2.3.3 | Spring animations, pane expand |
| A09 | Focus order in the custom tab bar | 2.4.3 | `CustomTabBar` |
| A10 | Bundled legal HTML | multiple | Web pass |

## 4. Assistive technology matrix

Please cover, and say explicitly which you tested on real devices:

- VoiceOver — full task walkthrough, not spot checks.
- Dynamic Type through to the largest accessibility sizes, including whether
  layouts break or truncate.
- Bold Text, Increase Contrast, Reduce Transparency, Reduce Motion,
  Differentiate Without Colour.
- Voice Control and Switch Control for the primary emergency flows.
- Display zoom, and portrait-only lock as it interacts with 1.3.4.

## 5. Task-based testing, not just screen sweeps

Audit these end-to-end journeys, since they are the ones that matter under
stress:

1. Enter a full medical profile from empty, through the biometric gate.
2. Open Find Help, read the GPS coordinates aloud, and place a call.
3. Start the seizure timer and reach the 5:00 call prompt.
4. Find and follow a first-aid topic to its care steps.
5. Pair and write the NFC bracelet.
6. **Rescuer journey** — tap the bracelet, land on the public card, read
   someone's allergies and medications on an unfamiliar phone.

Journey 6 deserves weight out of proportion to its size. The rescuer is a
stranger, possibly panicking, possibly with their own access needs, using a
phone that is not theirs and an app they have never seen.

## 6. Deliverables

1. Full WCAG 2.2 AA audit report, findings mapped to criteria and levels, with
   reproduction steps and device / OS versions.
2. Severity-prioritised remediation list we can turn into engineering tickets —
   we will fix in a product PR, so specific beats general.
3. A statement suitable to attach to an NHS DTAC submission.
4. **Retest after remediation**, with a written retest statement. Please quote
   this as a line item.

## 7. What we provide

- Signed test build (TestFlight), with sample profile data.
- Source access.
- A physical NFC bracelet for the rescuer journey, on request.
- Named product contact.

## 8. Commercial

- Preferred window: _[dates]_.
- Report needed by: _[date]_.
- Please state: whether auditors with lived experience of disability are
  involved, device coverage, and whether the web pass on the bundled HTML is
  included or extra.

## 9. Contact

_[Name, role, email, phone]_

---

**Note for whoever sends this:** confirm the Gate 0 decision in
[`../08-execution-plan.md`](../08-execution-plan.md) first — the staged
`uploads/` tree adds screens (app lock, bracelet setup, CPR timer, scanned card,
consent) that are not in the inventory above.
