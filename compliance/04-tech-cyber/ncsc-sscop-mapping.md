# NCSC Software Security Code of Practice — mapping (draft)

Map RedMed engineering practice to NCSC SSCoP themes. Fill evidence links as you
grow. This is a living checklist for DTAC technical narrative.

| Theme (paraphrased) | RedMed today | Gap / action |
|---------------------|--------------|--------------|
| Secure design | On-device; minimal attack surface | Keep “no server” unless threat model updated |
| Secure implementation | SwiftUI / iOS permissions | Dependency / secret scanning in CI |
| Vulnerability disclosure | _TBD_ contact | Publish security.txt / contact |
| Update / patch | App Store releases | Document release SLA |
| Identity / access | Device biometrics for edit | Cloud MFA if accounts added |
| Data protection | Local profile; NFC cleartext by design | User warnings; no false encryption claims |
| Logging / monitoring | No backend telemetry by design | If analytics added, DPIA + minimise |
| Supply chain | Xcode, Apple, GitHub | SBOM / signed commits optional hardening |

Attach CE cert + pen test when available.
