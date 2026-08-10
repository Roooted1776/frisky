# 3. Data protection

| Artefact | File |
|----------|------|
| DPIA | [dpia.md](dpia.md) |
| UK privacy notice draft notes | [uk-privacy-notice-notes.md](uk-privacy-notice-notes.md) |
| Lawful basis (special category) | [lawful-basis.md](lawful-basis.md) |
| DSP Toolkit | [dspt-checklist.md](dspt-checklist.md) |

**Architecture fact that drives everything:** RedMed currently has **no
operator-side servers** holding medical profiles. Processing is on-device and on
the user’s passive NFC chip. That shrinks (does not eliminate) UK GDPR duties
when you offer the app in the UK.

If you later add accounts, cloud sync, analytics, or NHS org tenancy, rewrite
this pack before go-live.
