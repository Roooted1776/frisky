# 5. Usability / accessibility — WCAG 2.2 AA

**Document ID:** RM-A11Y-001  
**Method:** static review of `RedMed-Xcode/RedMed` SwiftUI sources (no Simulator
in this environment). **Not** a certified audit.

NHS buyers score accessibility hard. Commission an external WCAG 2.2 AA audit
before large trust deals; fix gaps in a **separate product PR** (not via this
docs pack).

## Scope

Owner app: My ID, Find Help, Aid, NFC; scanner/public card shell; system sheets.

## Likely passes / strengths

- Uses SwiftUI controls in many places (inherits system behaviour better than
  fixed web pixels — but see the measured facts below, custom `.system(size:)`
  is pervasive).
- Semantic `NavigationView` / buttons for primary actions.

## Measured facts (shipping tree, 2026-08-10)

Corrects an earlier note in this file which said `accessibilityLabel` /
`accessibilityHint` were "already used". That is true of the staged `uploads/`
sources only — nine files there carry them — and **not** of what ships.

- **Zero** `accessibility*` modifiers across all of `RedMed-Xcode/RedMed/*.swift`.
  No labels, hints, traits, or element grouping anywhere in the shipping target.
- Hard-coded `.system(size:)` in **nine** files, ranging down to **9 pt**.

Assume an external audit starts from nothing. Brief for commissioning one:
[audit-brief.md](audit-brief.md).

## Gaps to verify / fix (code audit findings)

| ID | Issue | WCAG-ish | Where to look |
|----|-------|----------|---------------|
| A01 | Many hard-coded font sizes (9–13pt) | 1.4.4 Resize text | Aid / Emergency / cards |
| A02 | Colour meaning (accent red) without text/icon redundancy | 1.4.1 | Status / tabs |
| A03 | Contrast of muted grey on cream/pink backgrounds | 1.4.3 | `.redmedMuted` on `.redmedBg` |
| A04 | Emoji-only pane cues | 1.1.1 / 4.1.2 | Aid pane cards |
| A05 | Timer / GPS numeric updates — VoiceOver announcement | 4.1.3 | Seizure strip, GPS card |
| A06 | Decorative dividers vs structure | 1.3.1 | Card stacks |
| A07 | Hit target size on dense trauma grid | 2.5.8 (2.2) | CommonTraumaGrid |
| A08 | Motion / animation with Reduce Motion | 2.3.3 | Springs / pane expand |
| A09 | Focus order in custom tab bar | 2.4.3 | CustomTabBar |
| A10 | Legal HTML bundles — separate web WCAG pass | multiple | Privacy/TOS HTML |

## Required buyer evidence

- [ ] External WCAG 2.2 AA report (app + any web card)
- [ ] Remediation log with dates
- [ ] Retest statement

## Rule

Do **not** drive drive-by Swift refactors from this doc set. Schedule a11y fixes
as product work after audit prioritisation.
