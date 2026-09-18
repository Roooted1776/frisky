# Bi-weekly RedMed Funding/Growth bot email (View B recognition)

Claim-safe station outreach email + how the **RedMed Funding/Growth** Grok/Cursor bot sends it every two weeks.

Locked sources: [`ems-station-outreach.md`](ems-station-outreach.md), [`redmed-funding-growth-email-draft.md`](redmed-funding-growth-email-draft.md), [`ADVERTISING.md`](ADVERTISING.md) (View B), [`FDA-CLAIMS-WALL.md`](FDA-CLAIMS-WALL.md), [`DO-NOT.md`](DO-NOT.md), [`DUAL-MAC.md`](DUAL-MAC.md).

Bot display name (exact): **RedMed Funding/Growth**

Canonical copy is this repo (`docs/`). Do **not** commit API keys, OAuth tokens, or live email lists.

---

## Verdict from repo + Cursor search

| Asked for | Found in frisky / Cursor? |
|-----------|---------------------------|
| Automation named **RedMed Funding/Growth** | **No** — only accessible Automation at last check: `Security Reviewer (1)` |
| Grok / Funding bot code, xAI API, newsletter, cron jobs, webhooks | **No** send pipeline in-repo (intentional) |
| “Grok Bot” | Login identity only — [`DUAL-MAC.md`](DUAL-MAC.md): Cursor / Grok Bot = `m.aguilar-aasted@students.mccc.edu` |
| Email send path | **Cursor Gmail MCP** (not a separate Grok Gmail OAuth). DUAL-MAC: Grok Gmail plugin “app blocked” is expected |
| Recipients list | **Missing** — placeholders below; keep out of git |
| Bi-weekly schedule | **Missing** — wire via Cursor Automation / agent timer (below) |

Do **not** add Mailchimp, SendGrid, Meta, LMS, or an xAI-only parallel stack. Chosen path = **RedMed Funding/Growth** Cursor/Grok Automation + Gmail MCP, matching dual-Mac guidance.

---

## Schedule

| Field | Value |
|-------|--------|
| Cadence | Bi-weekly |
| Default send | Every other **Monday 14:00 America/New_York** (adjust once) |
| Cron (UTC, if agent timer) | `0 18 */14 * *` ≈ every 14 days at 18:00 UTC (maps to ~14:00 ET outside DST edge cases — prefer Automation “every 2 weeks” UI if available) |
| Alt calendar anchors | 1st + 15th: `0 18 1,15 * *` (UTC) |
| From (placeholder) | `{{FROM_EMAIL}}` — prefer a named outreach address once company gate has a real support/invoice domain; **not** `help.RedMed@gmail.com` for blast (that inbox is troubleshooting-only) |
| To | `{{RECIPIENTS}}` — comma-separated station / training-officer contacts (NJ + IL list from View B playbook) |
| BCC (optional) | Founder archive: `{{ARCHIVE_BCC}}` |
| Reply-to | `{{REPLY_TO}}` |

**Gate:** Until company gate is green (LLC, IP, liability insurance, FDA counsel on facility-issued bands, BAA decision, invoice path), this email is **recognition training only**. No materials-management / GPO / hospital-admin sell. No paid Meta to facility staff. No checkout QR. No EHR / HIPAA / medical-device claims.

---

## Email copy (paste as-is)

Same draft lives standalone in [`redmed-funding-growth-email-draft.md`](redmed-funding-growth-email-draft.md). Keep both in sync.

### Subject

```
RedMed ID band — 60-second tap brief for your crew
```

### Subject variants (rotate bi-weekly; same claims)

1. `If you see a black RedMed wristband — tap like this`
2. `Station leave-behind: RedMed medical ID tap (no app)`
3. `Skills-night friendly: how to open a RedMed ICE card`

### Body (plain text)

```
Hi {{FIRST_NAME}},

Quick recognition brief for your station — not a product pitch for materials management.

If you see a black wristband with the RedMed logo-print face:

1. Hold the top of the phone to the metal plate (~1–2 inches).
2. Safari opens a medical card. No app. No login.
3. Allergies, medications, conditions, contacts, Call.

Walk-by does not fire. Card readers / pay terminals do not open this card.
Self-reported ICE. Not a hospital chart. Call emergency services first.

We are not asking you to sell bands or host patient data with us.
If a short quote from your crew about what you look for on a body would help
families understand ICE on scene, reply with one line we can use on wearer ads.
Dummy-profile demo bands for skills night are available on request (same blank SKU).

Thanks for the work you do,
{{SENDER_NAME}}
RedMed
{{REPLY_TO}}
```

Use HTML only if the Gmail send path supports it. Keep the same sentences; no badges, no “HIPAA”, no “medical device”, no App Store checkout CTA for facilities, no pixel/tracking links.

---

## Claim checklist (bot must pass before send)

Allowed (from FDA wall / View B):

- Top of phone to RedMed plate ~1–2 inches; Safari card; no app; no login
- Self-reported ICE; call emergency services first
- Not a hospital chart; walk-by / pay terminals do not open this card
- Ask for a **View A** ad quote; optional demo box for skills night

Forbidden (abort send if model invents these):

- HIPAA compliant / certified; medical device; EHR; BA; host/upload PHI
- Write-from-app / Shortcuts write coaching; clinical thresholds / CDS
- Checkout QR; paid Meta to hospital staff; LMS / webinar funnel
- Outbound to materials management / GPO / hospital admin before company gate
- Asking for patient lists

---

## How the RedMed Funding/Growth bot triggers send

### What exists today

1. **Grok Bot** = Cursor login surface (`m.aguilar-aasted@students.mccc.edu` per [`DUAL-MAC.md`](DUAL-MAC.md)), not an in-repo xAI webhook.
2. **Gmail** for agents = Cursor Gmail MCP. Authorize in Cursor. Do not chase a separate Grok Gmail plugin OAuth.
3. **Repo copy** = this file + `redmed-funding-growth-email-draft.md` + `ems-station-outreach.md` under `docs/`.
4. **Automation named RedMed Funding/Growth** = **not created yet** (create/rename in Automations UI).

### Minimal viable wiring (no new vendor)

1. Create or rename a **Cursor Automation** whose display name is exactly **RedMed Funding/Growth**. Same Grok/Cursor identity as above.
2. Attach **Gmail MCP** to that agent (Cursor auth). Confirm send works to a test address once.
3. Schedule bi-weekly:
   - Preferred: Cursor Automations schedule = every 2 weeks, Monday 14:00 ET.
   - Fallback on a long-lived Cloud Agent: `subscribe_timer` with `name: redmed-funding-growth-biweekly-station-email`, `cron: "0 18 */14 * *"`, prompt = the agent prompt below.
4. Fill secrets / placeholders **outside git**:
   - `{{RECIPIENTS}}` list (start with the 10 local NJ/IL stations from View B)
   - `{{FROM_EMAIL}}` / `{{REPLY_TO}}` / `{{SENDER_NAME}}`
5. On each fire, the agent:
   - Reads `docs/redmed-funding-growth-email-draft.md` (or this file) for subject + body
   - Substitutes placeholders
   - Runs claim checklist
   - Sends via Gmail MCP (one message per recipient or BCC batch — prefer one-by-one with `{{FIRST_NAME}}` if known)
   - Logs send date + recipient count outside git (no PHI, no full medical profiles)
6. Do **not** commit API keys, OAuth tokens, or live email lists into `frisky`.

Step-by-step UI checklist: [`redmed-funding-growth-email-draft.md`](redmed-funding-growth-email-draft.md) § “How to run / schedule”.

### Agent prompt (paste into RedMed Funding/Growth automation)

```
You are RedMed Funding/Growth. Bi-weekly View B recognition email only.

1. Open docs/redmed-funding-growth-email-draft.md
   (fallback: docs/biweekly-funding-bot-email.md).
2. Use Subject + Body (plain text). Substitute placeholders from your configured
   recipient list / from / reply-to. Do not invent new product claims.
3. Pass the claim checklist in that doc. If anything fails, do not send; note why.
4. Send via Cursor Gmail MCP. Do not use a separate Grok Gmail OAuth.
5. Recognition training only until company gate is green (see docs/ems-station-outreach.md).
6. After send, record date, recipient count, and subject used. No PHI. No full medical profiles. Do not commit the log to git.
```

### Gaps before live send

| Gap | Why it blocks live send |
|-----|-------------------------|
| `{{RECIPIENTS}}` station contact list | No addresses in repo |
| Create Automation named exactly **RedMed Funding/Growth** and schedule it | Name is intent only; no Automation UUID yet |
| Gmail MCP auth on that agent | Namespace needsAuth until Cursor OAuth completes |
| `{{FROM_EMAIL}}` / `{{REPLY_TO}}` / `{{SENDER_NAME}}` | Prefer non-`help.RedMed@gmail.com` for outreach blasts |
| Optional: confirm ET timezone + first Monday | Avoid double-send on DST / overlapping timers |

---

## What we are not building

- No in-repo cron scripts, webhooks, or newsletter service
- No LMS, Meta ads to hospital staff, ad pixels on tapper
- No EHR / HIPAA product claims, no PHI host request
- No live recipient lists in git

---

## Related

- Standalone paste draft + run steps: [`redmed-funding-growth-email-draft.md`](redmed-funding-growth-email-draft.md)
- Playbook: [`ems-station-outreach.md`](ems-station-outreach.md)
- [`ADVERTISING.md`](ADVERTISING.md) View B, [`FDA-CLAIMS-WALL.md`](FDA-CLAIMS-WALL.md) station email discipline, [`DUAL-MAC.md`](DUAL-MAC.md) Grok + Gmail MCP
