# Apple HIG Writing & Microcopy Reference

In Apple Human Interface Guidelines, text is an integral component of the visual design. Poor writing destroys elegance; clear writing establishes authority.

---

## 1. Non-Negotiable Voice & Tone Principles

1. **Direct, Conversational & Polite**: Write in plain, natural human language. Avoid robotic phrasing, corporate jargon, and buzzwords.
2. **Action-Oriented Verbs**: Every control, button, or menu item must describe its explicit action with a verb:
   - Use **"Approve Version"**, not **"OK"** or **"Submit Action"**.
   - Use **"Schedule Flight"**, not **"Proceed"**.
   - Use **"Discard Draft"**, not **"Yes, I want to delete"**.
3. **No Engineering Leaks**: Never expose backend infrastructure tags, database jargon, or requirement codes to client users:
   - ❌ `[FR-08] Internal Flight Calendar` -> ✅ **"Omnichannel Flight Schedule"**
   - ❌ `[ACID] Transactional Outbox Worker (4s Poll Loop) [SKIP LOCKED]` -> ✅ **"Automated Dispatch Engine · Active"**
   - ❌ `Idempotency Key: 8a7c1b...` -> ✅ **"Audit Correlation ID: #8A7C1B"** (or tuck into developer inspection drawers)
   - ❌ `TimescaleDB Hypertable Ledger` -> ✅ **"Immutable Activity History"**

---

## 2. Punctuation & Typography Standards

1. **Sentence Case Everywhere**:
   - Navigation titles, buttons, section headers, row labels, and descriptions are all written in **Sentence case** (e.g., *"Active campaigns"*, *"Schedule flight"*, *"Total revenue"*).
   - Never use Title Case for buttons or table headers (*"Schedule The Campaign Now"* ❌).
   - Never use tracked all-caps for labels (*"CAMPAIGN TITLE"* ❌).
2. **Eliminate Template Punctuation**:
   - Never glue meta strings with middle dots: `v1 · Alice · $12,000 · Social · Pending` ❌.
   - Use dedicated columns, subhead rows, and tabular alignment.
   - Never glue arrows to link buttons: `Learn more →` ❌. Use clean verbs or native disclosure chevrons (`Icon(Icons.chevron_right)`).

---

## 3. Humanized Error States & Recovery

Apple HIG requires error messaging to follow three mandatory rules:
1. **State Clearly What Happened**: Explain the issue in terms of user goals, not technical stack traces.
2. **Never Blame the User**: Avoid accusatory phrases like *"You entered an invalid date"*. Instead write: *"The end date must be after the start date."*
3. **Always Provide a Constructive Path Forward**: Offer an immediate recovery action (e.g. `[Retry Connection]`, `[Pick New Date]`, `[Request Reviewer Lease]`).

### Example Comparisons:

| Scenario | AI Slop / Engineering Bleed | Apple HIG Mastercopy |
| :--- | :--- | :--- |
| **Outbox SMTP Timeout** | `EmailProviderGatewayTimeout: MockSMTP unreachable (504)` | *"Unable to connect to email service. The dispatch will automatically retry in 4 seconds."* |
| **Edit Lock Conflict** | `409 LEASE_CONFLICT: User Marcus holds active lock until 14:02:11` | *"Marcus is currently editing this proposal. You will be notified as soon as it becomes available."* |
| **Optimistic Version Mismatch** | `Optimistic concurrency error: Expected v1, found v2` | *"This campaign was updated by another team member. Tap to refresh the latest changes."* |
| **Empty State** | `0 items returned from query` | *"No scheduled flights for this date. All channel lanes are open for booking."* |
