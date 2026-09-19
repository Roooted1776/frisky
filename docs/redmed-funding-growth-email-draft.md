# RedMed Funding/Growth — email draft (View B)

Ready-to-paste subject + body for the **RedMed Funding/Growth** Cursor/Grok bot. Recognition training only. Not materials-management sell.

Canonical wiring + claim checklist: [`biweekly-funding-bot-email.md`](biweekly-funding-bot-email.md). Playbook: [`ems-station-outreach.md`](ems-station-outreach.md).

**Do not send live** until Gmail MCP is auth’d on that bot **and** you supply `{{RECIPIENTS}}`. Do not commit the live recipient list, From/Reply-To secrets, or OAuth tokens into this repo.

---

## Ready-to-paste draft

### Subject

```
RedMed ID band — 60-second tap brief for your crew
```

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

### Subject variants (rotate bi-weekly; same claims)

1. `If you see a black RedMed wristband — tap like this`
2. `Station leave-behind: RedMed medical ID tap (no app)`
3. `Skills-night friendly: how to open a RedMed ICE card`

---

## Placeholders (fill before send)

| Token | Fill with |
|-------|-----------|
| `{{FIRST_NAME}}` | Training officer / contact first name, or drop the greeting name |
| `{{RECIPIENTS}}` | Station emails (NJ + IL View B list) — **not in git** |
| `{{SENDER_NAME}}` | Founder display name |
| `{{REPLY_TO}}` | Outreach reply address (prefer non-`help.RedMed@gmail.com`) |
| `{{FROM_EMAIL}}` | Same or dedicated outreach From once company gate has a domain |

---

## Claim gate (abort send if any fail)

Allowed: top of phone → RedMed plate ~1–2 in; Safari card; no app; no login; self-reported ICE; call emergency services first; not a hospital chart; walk-by / pay terminals do not open; ask View A quote; optional skills-night demo box.

Forbidden: HIPAA compliant/certified; medical device; EHR; BA; host/upload PHI; write-from-app / Shortcuts coaching; clinical thresholds / CDS; checkout QR; paid Meta to hospital staff; LMS funnel; materials-management / GPO outbound before company gate; patient lists.

---

## How to run / schedule on **RedMed Funding/Growth**

Exact name of the bot: **RedMed Funding/Growth** (slash included). Not “Funding”, not “Funding Growth”.

### A. Create or rename the Automation (one-time)

1. Sign into Cursor as the Grok Bot identity: `m.aguilar-aasted@students.mccc.edu` ([`DUAL-MAC.md`](DUAL-MAC.md)).
2. Open **Cursor → Automations** (https://cursor.com/automations).
3. Create a new Automation **or** rename an existing one so the display name is exactly:
   `RedMed Funding/Growth`
4. Model: Grok (same family as other RedMed Grok runs). Repo: `Roooted1776/frisky`.
5. Paste the agent prompt from [`biweekly-funding-bot-email.md`](biweekly-funding-bot-email.md) (section “Agent prompt”).
6. Enable **Gmail MCP** on that Automation / agent via **Cursor** OAuth (not a separate Grok Gmail plugin — “app blocked” is expected).

### B. Auth Gmail (blocker until done)

1. In the agent/Automation MCP settings, connect **Gmail**.
2. Complete Cursor’s OAuth. Confirm a test draft or send to your own address once.
3. Do **not** chase xAI webhooks or a second Gmail OAuth path.

### C. Schedule bi-weekly send

**Preferred — Automations schedule UI**

1. On **RedMed Funding/Growth**, set schedule to every **2 weeks**, Monday **14:00 America/New_York**.
2. Trigger prompt: “Run the bi-weekly View B station recognition email from `docs/redmed-funding-growth-email-draft.md` (or `docs/biweekly-funding-bot-email.md`). Substitute placeholders. Pass claim checklist. Send via Gmail MCP only if recipients are configured.”

**Fallback — long-lived Cloud Agent + `subscribe_timer`**

1. Open a Cloud Agent logged in as the same identity, named or instructed as **RedMed Funding/Growth**.
2. Subscribe a timer (Cursor subscriptions MCP):
   - `name`: `redmed-funding-growth-biweekly-station-email`
   - `cron`: `0 18 */14 * *` (≈ every 14 days at 18:00 UTC ≈ 14:00 ET outside DST edges)
   - `prompt`: same as the agent prompt in `biweekly-funding-bot-email.md`
3. Leave that agent alive so timer follow-ups can fire. Prefer Automations UI when available.

### D. One-shot manual send (after recipients exist)

1. Open **RedMed Funding/Growth**.
2. Paste:

```
Send the draft in docs/redmed-funding-growth-email-draft.md
to these recipients: <paste list>.
Use Subject + Body (plain text). Substitute {{FIRST_NAME}} / {{SENDER_NAME}} / {{REPLY_TO}}.
Pass the claim checklist. Gmail MCP only. Do not invent claims.
```

3. Confirm the agent shows To + Subject + Body before send.

### E. What not to build

- No in-repo cron, xAI webhook, Mailchimp, SendGrid, or newsletter service
- No live send without recipients + Gmail auth
- No PHI requests; no materials-management outbound before company gate
- No live email lists or OAuth tokens in git
