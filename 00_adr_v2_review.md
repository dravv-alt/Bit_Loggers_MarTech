# 00 · ADR v2.0 Review and Plan Impact
Reviewed: ADR v2.0 (15 records, 2 Nov 2026) against PRD v1.0 and my previous plan (files 01–07).
Markers: `[ASSUMPTION]`, `[BLOCKER]`, `TBD` as before. "Resolution" is what the revised plan does; you can overrule any of it.

## A. What v2.0 changes (and where the plan absorbed it)
| ADR | Change | Plan impact |
|---|---|---|
| 002 | Two lifecycles: `campaign.operational_status` and `campaign_version.governance_status`; rejection kills only the version | Schema + state tables rewritten (05) |
| 003 | Deferred circular FKs; composite-FK approval guard on schedule; **triggers rejected** | My triggers removed; replaced by grants, column-level grants and composite FKs (05) |
| 004 | Outbox with `available_at`, SKIP LOCKED, provider dedupe header, DLQ | Column rename, DLQ status added (05) |
| 005 | Idempotency on every POST/PUT/PATCH, 7-day retention, `Idempotent-Replay` header | Retention 72 h → 7 days; exemption proposed for autosave/heartbeat (F-09) |
| 006 | Heartbeat lease (2 min, renew 60 s), `LEASE_EXPIRED` vs `VERSION_CONFLICT`, 15 s autosave buffer | Lease table gains session id; autosave is local-first on mobile (07) |
| 007 | Approval tiers (Tier 2 if budget > $50,000) | `approval_tier` column, two decision FKs on schedule, new role (F-11) |
| 008 | Context-anchored threads, `is_internal_only` notes | New tables; sync/push filtering rules (F-16) |
| 009 | Async AI summary per version, rule-based fallback | `ai_proposal_summary` table; fallback card works offline |
| 010 | One endpoint: `POST /campaigns/{id}/versions/{vid}/decisions` | Replaces `/approve`, `/reject`, `/request-changes` everywhere |
| 011 | Read replica, materialised views, Redis cache | Replaced by Timescale continuous aggregates; replica/Redis deferred (F-13) |
| 012 | `TSTZRANGE` + GiST exclusion | Adopted with a fix (F-07) |
| 013 | Staging sandbox + semantic diff + editorial patches | Adopted with a safety rewrite (F-01) |
| 014 | Pause/resume, runtime controls, auto-pause breaker | Operational lifecycle + worker; threshold gaps (F-12) |
| 015 | Dynamic Priority Scoring queue + escalation | Adopted after fixing contradictions (F-08) |

## B. Findings (ranked by how much damage they can do)

### Critical: change the design if you agree
**F-01 · ADR-013 "minor patch" breaks the approval guarantee.**
The ADR patches the *approved baseline* in place without re-review. That contradicts v2.0's own invariant "historical versions are strictly immutable", and it undermines ADR-002's point: an approval must refer to exactly what the reviewer saw. A "spelling" edit that turns "5% off" into "50% off" is still a text edit. Three further gaps: (a) the 5% budget rule is not stated as cumulative, so repeated 4% edits drift freely; (b) a 4.1% budget change (49,000 → 51,000) can cross the $50,000 Tier-2 threshold and bypass finance; (c) "cosmetic" and "internal tag" have no testable definition.
**Resolution:** keep the sandbox (it fixes the real starvation problem) but implement minor edits as an append-only `version_patch` overlay, not an update to the version row. A conservative classifier decides major vs minor: anything touching numbers, URLs, currency, percentages, objective, audience, channel or tier count is major; drift is measured against the approved baseline, not the previous patch. **Feature flag defaults OFF**, so every submit is a formal new version (safe behaviour) until organizers rule. [BLOCKER B-08]

**F-02 · Missing states.** `PENDING_TIER_2_APPROVAL` (ADR-007) is in neither enum. Rejection text says the campaign "transitions to CHANGES_REQUESTED", which is not an `operational_status` value.
**Resolution:** add `PENDING_TIER_2_APPROVAL` to `governance_status`. "Changes requested" at campaign level is a derived display label from the latest version, not a stored operational value.

**F-03 · `draft_version_id` contradicts immutability.** A version row cannot be both a mutable working draft and immutable. ADR-006 already defines a separate `campaign_draft_buffer`.
**Resolution:** the working draft is one `campaign_draft` row per campaign (same thing as the buffer). Version rows are created only at submission. `draft_version_id` is dropped. Consequence: PRD FR-02 / AC-02 ("every saved revision creates a version") becomes "every submission creates a version"; recorded in PRD-CR-02.

**F-04 · ADR-003 rejects triggers, my plan used them.** I had triggers for immutability, self-approval and reviewer role.
**Resolution:** removed. Immutability = `REVOKE UPDATE/DELETE` plus *column-level* `GRANT UPDATE (governance_status, submitted_at)` on versions. Self-approval = `campaign_owner_id` column + composite FK to `campaign(id, owner_id)` + `CHECK (reviewer_id <> campaign_owner_id)`. Reviewer role = composite FK `(reviewer_id, reviewer_role) → user_role`. All declarative. Table owner must be the migrator role, never the app role, otherwise grants are meaningless.

**F-05 · Schedule guard only covers one decision.** The ADR-003 composite FK binds a schedule to a single decision, but ADR-007 needs Tier 1 and Tier 2.
**Resolution:** `campaign_version.required_tiers` is a generated column (`2` when budget > $50,000, else `1`). The schedule carries `tier1_decision_id` (required) and `tier2_decision_id` (nullable), each with its own composite FK, plus `CHECK (required_tiers = 1 OR tier2_decision_id IS NOT NULL)`. A version needing Tier 2 fails closed until Tier 2 exists. Threshold is USD-only in v1 (`CHECK (currency='USD')`) because the generated expression cannot convert currencies. [ASSUMPTION B-12]

**F-06 · Role proliferation vs PRD.** v2.0 adds Finance Executive (Tier 2), Senior Reviewer/Lead (escalation) and a manager override (expedite). PRD v1.0 says two roles and lists approval hierarchies and multiple approvers as out of scope.
**Resolution:** RBAC is data-driven (roles and permissions are rows). Stage 1 ships MARKETER and REVIEWER only. `FINANCE_EXECUTIVE`, `SENIOR_REVIEWER` (superset of REVIEWER) and `MANAGER` arrive in Stage 6 behind a migration. Record as PRD-CR-02. [BLOCKER B-09: confirm role list]

### High
**F-07 · ADR-012 exclusion constraint has no `WHERE status='ACTIVE'`.** A cancelled schedule would block its slot forever. Also nothing ties `schedule.channel` to the version's channel, and ADR-013 leaves open what happens to a schedule when a newer version is approved.
**Resolution:** partial exclusion constraint; composite FK `(version_id, campaign_id, channel)`; swap rule: if `SCHEDULED`, cancel the old schedule and insert a new one for the new version in one transaction (same window); if `RUNNING`, swap is blocked until paused. [ASSUMPTION; BLOCKER B-07]

**F-08 · ADR-015 internal contradictions.**
1. The verification case (V4 with 3 prior change requests) has `N_changes = 3`, which the same ADR says auto-routes to the ESCALATED track, so it never sits in the general queue where the aging test expects it.
2. Churn of exactly 18.00 requires `N_diffs = 0`; any diff adds to it.
3. "Mathematically guarantees" no starvation is not true: aging is capped at 40 while fresh high-urgency, high-impact proposals can score up to 60 with no churn. A low-score, high-churn proposal tops out near 10.
4. `λ`, `B_max` and `W_tier` are undefined; a launch date in the past gives maximum urgency.
5. Churn counts reviewer-requested changes against the author, which the author cannot control.
**Resolution:** implement DPS exactly as specified but add an SLA-breach track (hard guarantee: after `SLA_HOURS` [TBD] in queue, ordering becomes oldest-first), validate launch date ≥ now + minimum lead [TBD], tie-break by `submitted_at`, store all components for transparency, and expose parameters as config. Fix the verification example. [BLOCKER B-11: parameter values]

**F-09 · Idempotency on every PUT collides with autosave and heartbeat.** At 15 s autosave and 60 s heartbeat, a 7-day retention table with stored responses would grow fast and cost bandwidth.
**Resolution:** amend ADR-005: PUTs that are idempotent by construction (autosave guarded by `If-Match` draft revision, lease heartbeat) are exempt. All creating/transitioning POST/PATCH calls keep the mandatory key.

**F-10 · Provider-side dedupe is not universal.** ADR-004 sends `Idempotency-Key: event:recipient:channel` to SendGrid/FCM/APNs. I am not aware that these accept that header with replay semantics (verify per provider). The index also says "at-least-once" and "zero duplicate alerts", which conflict.
**Resolution:** our guarantee is the unique `dedupe_key` on `notification_delivery` plus at-least-once sending; send the header where a provider honours it. Wording becomes "at-least-once, duplicate-suppressed".

**F-11 · ADR-014 thresholds are inconsistent.** "CPA > 300% of projected" (3×) vs "300% over target" (4×); decision text has no duration but the open item says 3 consecutive hours, while the test expects a pause within 60 s of one batch. Spend-rate baseline is undefined. PRD excludes real ad publishing, so no live telemetry exists unless it comes from our own email launch or imported/sample data. Resume after a breaker trip has no guard.
**Resolution:** [ASSUMPTION] breach = CPA > 4× target for 3 consecutive hourly buckets (open-item wording); the 60 s test uses a batch containing three breaching hourly buckets. Telemetry sources = email launch events, CSV import, sample data. Resume after a breaker pause needs a reviewer or manager acknowledgement. Runtime knobs can only be tightened; loosening needs a new version. [BLOCKER B-10]

### Medium
**F-12 · ADR-011 adds Redis and read replicas; Timescale already solves most of it.** Continuous aggregates give incrementally refreshed rollups. Resolution: `campaign_telemetry` hypertable → `campaign_metric_rollups` continuous aggregate; cached summary stored in a table; read replica and Redis deferred until measured need (Stage 10). Its numbers (<50 ms, <10 ms, 200 concurrent queries) are proposed targets, measured in Stage 10.

**F-13 · ADR-006 details.**
- The lease holder must be (user, session/device), otherwise the same user on two phones silently shares one lease.
- 60 s heartbeat on a 120 s lease tolerates one missed beat; acceptable because `LEASE_EXPIRED` is recoverable.
- 15 s server autosave costs battery and data on mobile: save locally on every debounced change, upload only when dirty, foreground and online.
- "409 LEASE_EXPIRED (or 423 LOCKED)" is ambiguous: use 409 `LEASE_EXPIRED` and 409 `LEASE_HELD`.

**F-14 · ADR-010 claims "the database is never hit" for invalid requests.** Role, ownership, version and state checks need reads. Reword to "no writes occur". Also the new order puts the reason check last, so a request with both a wrong state and an empty reason returns 409 first. The ADR also references tests T-01..T-06 that are not defined; I defined them in 03.

**F-15 · ADR-008 internal notes can leak.** `is_internal_only` must be filtered in every channel that carries content: API lists, the offline **sync change feed** (data sitting on the marketer's phone), push payloads, email notifications, mention notifications, analytics exports. Plan filters in a single policy function and adds a leak test for each channel.

### Low
- ADR-009 context names Twilio; SMS is not a requirement. Ignore.
- ADR-009 no longer mentions marketer AI proposal assist (PRD FR-10); kept in scope behind the same interface.
- Status labels are inconsistent (index shows Accepted/Updated; header says all Proposed).
- The 5% budget tolerance and "internal tag" exemptions need finance sign-off (ADR open items).

## C. New or changed blockers
| ID | Decision needed | Needed before | Default until answered |
|---|---|---|---|
| B-07 | Version swap when a newer version is approved while campaign is SCHEDULED/RUNNING | Stage 4 | SCHEDULED: atomic re-schedule; RUNNING: blocked |
| B-08 | Are editorial patches allowed without re-review (conflicts with PRD FR-06 and ADR-002)? | Stage 3 flag-on | Flag OFF, all submits are new versions |
| B-09 | Final role list (Finance Executive, Senior Reviewer, Manager) | Stage 6 | Roles as data, added by migration |
| B-10 | Breaker thresholds, duration, resume authority | Stage 9 | See F-11 |
| B-11 | DPS parameters (λ, B_max, W_tier, SLA hours, min lead time) | Stage 6 | Config values TBD, placeholders in tests only |
| B-12 | Currency handling for the $50,000 threshold | Stage 1 schema | USD only |
| B-13 | ESP: ADRs name SendGrid | Stage 8 | [ASSUMPTION] SendGrid, verify batch/event limits in current docs |
| B-14 | May authors read internal notes after completion? | Stage 7 | No |
| B-15 | Budget tolerance for minor edits (ADR says 5%) | Stage 3 flag-on | 0% |

Existing blockers B-01..B-06 from file 01 still stand, except B-01, which now has a proposed answer (SendGrid).

## D. PRD change requests to record
- **PRD-CR-01** Email campaign launch (from before).
- **PRD-CR-02** ADR v2.0 deviations: dual lifecycle (PRD §5), sandbox and submission-created versions (FR-02, FR-06, AC-02), unified decisions endpoint (§8), approval tiers and extra roles (§2, §9 items 7–8), review queue ranking, runtime controls and breaker, KPI/metric ingestion model.
