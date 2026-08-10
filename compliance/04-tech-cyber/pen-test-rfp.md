# Penetration test — request for quote

**Document ID:** RM-PT-002
**Purpose:** send to firms for comparable quotes. Pairs with
[`pen-test-scope.md`](pen-test-scope.md) (internal scope reasoning).
**Send to:** three CREST-member firms minimum. NHS buyers commonly ask for CREST
or CHECK-equivalent, so an unaccredited test can fail the procurement question
even when the testing itself was sound.

---

## 1. Who we are

RedMed — pre-revenue UK health-tech, native iOS app plus a passive NFC emergency
ID bracelet. Legal entity: _[insert]_. Testing is commissioned to support NHS
supplier assurance (DTAC) and general product security.

## 2. Target — read this before quoting

The target is **smaller than a typical mobile engagement**. There is no backend,
no user accounts, no API, and no server we operate. Please quote against what is
actually here rather than a standard mobile-app template.

### 2a. Shipping build (`RedMed-Xcode/`) — the primary target

| Surface | Detail |
|---------|--------|
| Platform | Native iOS 17+, SwiftUI, portrait only |
| Data at rest | **None.** Profile is in-memory only for the session — no `UserDefaults`, no Keychain, no file writes |
| Network | **None.** No outbound calls of any kind |
| Auth | `LAContext.deviceOwnerAuthentication` (Face ID / Touch ID / passcode) gating profile edit and bracelet write |
| NFC | Entitlement and usage string currently commented out; write path is a local demo overlay |
| Outbound URL handling | `tel://` dial to emergency numbers; `https://maps.google.com/?q=<lat>,<lng>` built for display; SMS composer pre-fill |
| Permissions | Location When-In-Use; Face ID |
| Bundled web content | `PrivacyPolicy.html`, `TOS.html`, `HowItWorks.html`, `security.html`, `legal-doc.css` rendered in-app |
| Static data | Bundled trauma-hospital JSON, medication reference data |

Areas we specifically want looked at: the biometric gate and whether the
"scanner session" separation can be bypassed to reach owner edit or NFC write
controls; injection or spoofing through NDEF payload content and the URL the
bracelet resolves to; the SMS and maps URL construction from GPS values;
anything the bundled WebKit content can reach; backup and snapshot exposure of
profile data held in memory; and clipboard handling of coordinates.

### 2b. Staged build (`uploads/`) — **quote as a separate option**

Not currently in the Xcode project. A decision on whether it ships is open. If
included it adds:

- Keychain persistence of the medical profile (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`).
- Live CoreNFC read and write.
- `CMMotionManager` motion-assist heuristic (opt-in, screen-visible only).
- An 8-second SOS countdown state machine.
- **Outbound HTTPS POST** of name, blood type, allergies, conditions,
  medications and GPS to a caller-supplied third-party URL (inert while
  unconfigured). Transport security, endpoint trust, failure handling and data
  minimisation on this path are the priority if it is in scope.

**Please price 2a and 2b separately** so we can decide with numbers in hand.

### 2c. Corporate and supply chain

- GitHub organisation and repositories, branch protection, Actions workflows,
  secrets handling.
- Apple Developer account and code signing / provisioning.
- Email tenancy and identity provider; MFA coverage.
- Endpoints used for development and builds.
- Any static hosting used to render the public card page from the NFC payload.

### 2d. Out of scope

- Multi-tenant cloud API (does not exist).
- HSCN / NHS network connectivity (does not exist).
- Physical NFC tag cloning as a hardware exercise — we accept the tag is passive
  and world-readable **by design**; we want the *consequences* assessed, not a
  demonstration that an unencrypted tag can be read.
- Denial of service.

## 3. Standard and approach

- OWASP MASVS / MSTG for the mobile component; OWASP ASVS for any web surface.
- Grey-box: we will provide source, a build, and a walkthrough.
- Please state assumed days, seniority mix, and whether retest is included.

## 4. Deliverables

1. Technical report with reproducible findings and CVSS or equivalent ratings.
2. Executive summary written to be **attached to a DTAC submission** and read by
   an NHS information governance reviewer — this matters to us as much as the
   technical detail.
3. Remediation tracker we can work through.
4. **Retest of highs and criticals**, with a written retest statement.

## 5. What we will provide

- Full source access, both trees.
- Signed test build (TestFlight or ad-hoc) plus a physical NFC bracelet on request.
- A written walkthrough of the emergency flows.
- Named engineering contact for the duration.

## 6. Commercial

- Preferred window: _[dates]_.
- Report needed by: _[date]_.
- Quote should state: day rate, total days, retest terms, accreditation
  (CREST / CHECK), insurance, and whether testers are UK-based.
- Please confirm handling and retention of any personal data encountered — the
  app holds special category health data, and we will need that in writing.

## 7. Contact

_[Name, role, email, phone]_

---

**Note for whoever sends this:** confirm the Gate 0 decision in
[`../08-execution-plan.md`](../08-execution-plan.md) first. Quoting 2a and then
shipping 2b means paying twice.
