# 01 · Project Memory and Decision Trace (revised for ADR v2.0)
**Project:** Campaign Management & Intelligence Platform (Bit Loggers · MAL 4)
**Baselines:** PRD v1.0 · ADR v2.0 (2 Nov 2026) · findings in `00_adr_v2_review.md` (F-xx references below)
**Stack:** Flutter (Android + iOS) · PostgreSQL + TimescaleDB · Measure SDK (measure.sh) for client performance
**Markers:** `[ASSUMPTION]` default chosen, safe to change · `[BLOCKER]` decision needed before the dependent stage · `TBD` unknown, not invented.

---
## Part A · Decision Trace

### D-01 TimescaleDB scope
- **Context:** You want TimescaleDB for audit logging, version history and similar data; transactional logic stays relational.
- **Options:** everything in hypertables · hypertables only for append-only time-ordered data · skip Timescale.
- **Decision:** Plain tables for `campaign`, `campaign_version`, `approval_decision`, `campaign_schedule`, `campaign_draft`, locks, idempotency, outbox, queue, notifications. Hypertables: `audit_event`, `diagnostic_event`, `campaign_telemetry`, `email_event`. Continuous aggregate: `campaign_metric_rollups`.
- **Rationale:** Hypertable unique keys must include the time column, and (to my knowledge) other tables cannot hold FKs referencing a hypertable. Our invariants depend on FKs into versions and decisions.
- **Unknowns:** [ASSUMPTION] behaviour as stated holds on the pinned image; verify in task T1-08.
- **Consequence:** "Version history" = `campaign_version` rows (authoritative) + `VERSION_CREATED` / `PATCH_APPLIED` audit events (timeline). Needs a new ADR-016 (Timescale for append-only data) because ADR v2.0 does not mention it.

### D-02 Backend stack (OQ-13)
- **Decision:** [ASSUMPTION] Python 3.12, FastAPI, psycopg 3 (async), hand-written SQL for invariant-critical transitions, Alembic, pytest + testcontainers. Dart client generated from OpenAPI.
- **Rationale:** Explicit SQL and locking; easy test control. **Consequence:** two languages. Hosting: TBD (B-04).

### D-03 Process model (ADR-001)
- **Decision:** One codebase, three processes: `api`, `worker` (outbox, delivery, AI, queue recompute, circuit breaker, maintenance), `launcher` (email sends). Postgres rows as queues (`FOR UPDATE SKIP LOCKED`), no broker. Add import-linter style dependency checks so modules call each other only through interfaces (ADR-001 verification).

### D-04 Authentication (OQ-10)
- **Decision:** [ASSUMPTION] email + password (argon2id), 15 min access JWT, rotating refresh tokens with reuse detection, tokens in secure storage; role read from DB per request (≤ 60 s cache).

### D-05 RBAC and declarative integrity (ADR-003, ADR-007; F-04, F-06)
- **Context:** ADR-003 rejects triggers. ADR-007 adds tiers. PRD says two roles.
- **Decision:** Roles/permissions are data. Stage 1 = MARKETER, REVIEWER. Later: FINANCE_EXECUTIVE (Tier 2), SENIOR_REVIEWER (superset of REVIEWER), MANAGER (expedite override). One role per user [ASSUMPTION A-02]. Enforcement: route permission → resource policy → in-transaction guards → declarative DB constraints (owner/role composite FKs, column-level grants). No triggers.
- **Consequence:** App role must never own tables. A CI test fails if a route lacks a declared permission.

### D-06 Dual lifecycle (ADR-002; F-02, F-03)
- **Decision:** `campaign.operational_status` ∈ DRAFT, PUBLISHED, SCHEDULED, RUNNING, PAUSED, COMPLETED, CANCELLED; `campaign_version.governance_status` ∈ DRAFT (unused), SUBMITTED, PENDING_TIER_2_APPROVAL, CHANGES_REQUESTED, APPROVED, REJECTED. `active_version_id` = approved baseline. Version rows exist only from submission; the working draft lives in `campaign_draft`.
- **Consequence:** Campaign "needs changes" is a derived label. Rejection ends only that version (resolves OQ-01).

### D-07 Sandbox and semantic diff (ADR-013; F-01)
- **Decision:** Editing never touches `active_version_id`. Submit classifies the diff against the **approved baseline**. Major (or flag OFF) → new immutable version, SUBMITTED. Minor (flag ON only) → append-only `version_patch` overlay + `PATCH_APPLIED` audit; effective content read via `version_effective`. Changes that alter `required_tiers` are always major.
- **Assumptions:** one version in review at a time; submit blocked while a version is pending [ASSUMPTION]; "withdraw submission" not specified: TBD. Budget tolerance default 0% (ADR proposes 5%).
- **Blockers:** B-08, B-15.

### D-08 Approval tiers (ADR-007; F-05)
- **Decision:** `required_tiers` generated from budget (> $50,000 → 2), USD only. Decision tier is derived from the version's governance status and the caller's role, never from the request body. `UNIQUE (version_id, approval_tier)`. Schedule carries two decision FKs. Four-eyes between tier-1 and tier-2 approvers: not required [ASSUMPTION].

### D-09 Unified decision endpoint (ADR-010; F-14)
- **Decision:** `POST /campaigns/{id}/versions/{vid}/decisions`, body `{type, reason, policy_reference?}`. Order: 401 → 403 (role for current tier, then owner) → 404 → 422 VERSION_MISMATCH → 409 NOT_AWAITING_REVIEW → 422 REASON_REQUIRED. All inside one transaction with `campaign` row locked; failures roll back with no writes.

### D-10 Idempotency (ADR-005; F-09)
- **Decision:** Key required on creating/transitioning POST/PATCH; 7-day retention; `Idempotent-Replay: true` on replays. PUTs that are idempotent by construction (autosave with `If-Match`, lease heartbeat) are exempt (proposed amendment to ADR-005). Stage introduced: 5.

### D-11 Concurrency (ADR-006; F-13)
- **Decision:** Lease keyed by (user, session); 120 s lease, 60 s heartbeat. Errors: 409 `LEASE_EXPIRED` (client re-acquires silently), 409 `LEASE_HELD` (shows holder), 409 `VERSION_CONFLICT` (true drift). Autosave: local-first, server upload every 15 s only when dirty + foreground + online, guarded by `If-Match` draft revision.

### D-12 Outbox and delivery (ADR-004; F-10)
- **Decision:** `available_at`, `PROCESSING` with lease, statuses incl. `DEAD` (DLQ) with triage endpoint. Guarantee wording: at-least-once, duplicate-suppressed via unique `dedupe_key`. Provider idempotency header sent only where honoured (verify per provider).

### D-13 Offline policy
- **Decision:** Offline read + local draft editing + queued `SUBMIT_DRAFT`. Online-only: decisions, scheduling, lease, pause/resume/cancel, runtime controls, launch controls. Rationale unchanged: decisions on stale data defeat version-bound approval.

### D-14 Internal notes and sync (ADR-008; F-15)
- **Decision:** `is_internal_only` filtered by one policy function used by API, sync feed, push, email and mentions; per-channel leak tests. Post-completion access for authors: B-14, default no.

### D-15 Analytics (ADR-011; F-12)
- **Decision:** `version_kpi_targets` (immutable) vs `campaign_telemetry` → continuous aggregate `campaign_metric_rollups`; dashboard payload cached in a table (5 min TTL); Redis and read replica deferred. KPI formulas unchanged (CTR = clicks/impressions; CVR = conversions/clicks; ROI = (revenue−spend)/spend; CPA = spend/conversions; AOV = revenue/orders; divide-by-zero → null) [ASSUMPTION, OQ-09].

### D-16 Calendar (ADR-012; F-07)
- **Decision:** `time_window tstzrange` with GiST exclusion `WHERE status='ACTIVE'`; channel taken from the version via composite FK; channel is a lookup table (e.g., EMAIL_NEWSLETTER), not a fixed enum [ASSUMPTION]. Version swap on SCHEDULED campaign = atomic reschedule (B-07).

### D-17 Runtime controls and breaker (ADR-014; F-11)
- **Decision:** Pause/resume/cancel on `operational_status`; `campaign_runtime_controls` tighten-only; breaker worker evaluates hourly buckets, writes audit event with actor type `CIRCUIT_BREAKER`, pauses campaign and any running launch in the same transaction. Resume after breaker needs reviewer/manager acknowledgement. Thresholds per B-10.

### D-18 Review queue (ADR-015; F-08)
- **Decision:** `review_work_queue` with DPS components stored; recompute urgency/aging every 5 min; tracks GENERAL / ESCALATED / SLA_BREACH; atomic "claim next" using SKIP LOCKED. Parameters are config (B-11).

### D-19 AI (ADR-009)
- **Decision:** `AIProposalSummarizer` interface; summary job triggered by outbox event on submission; stored in `ai_proposal_summary`; model string `gemini-4-argon`; rule-based fallback card computed from version fields (also on the client, so it works offline). Marketer proposal assist (PRD FR-10) stays behind the same interface with a timeout.

### D-20 Email launch (PRD-CR-01)
- **Decision:** as in 06; ESP [ASSUMPTION] SendGrid (named in ADR-004); content read from `version_effective`; launch pause linked to campaign pause/breaker.

### D-21 Client performance monitoring (Measure SDK)
- **Decision:** Wrap `measure_flutter` behind a `PerformanceMonitor` interface (same dependency-inversion idea as ADR-009). Details in 08.

### D-22 Audit (ADR-008)
- **Decision:** INSERT-only grants, no triggers; `actor_type` (USER, SYSTEM, CIRCUIT_BREAKER, WORKER); no retention drop; compression after 7 days [ASSUMPTION]. Not tamper-proof against a DBA.

## Part B · Assumption ledger
| ID | Assumption | Revisit when |
|---|---|---|
| A-01 | FastAPI/psycopg3/Alembic | hosting decided |
| A-02 | One role per user | someone needs two roles |
| A-03 | Same-channel overlap = conflict | organizers define |
| A-04 | Idempotency retention 7 days (ADR-005) | OQ-07 |
| A-05 | Max attempts: outbox/delivery 8, email recipient 5 | OQ-08 |
| A-06 | Lease 120 s / heartbeat 60 s | usability data |
| A-07 | Offline policy D-13 | product owner objects |
| A-08 | KPI formulas D-15 | OQ-09 |
| A-09 | Audit visibility: reviewers full, marketers own business events | OQ-05 |
| A-10 | Audience = list refs materialised at launch start | frozen audience required |
| A-11 | One in-review version per campaign | product owner objects |
| A-12 | USD-only budgets (threshold) | B-12 |
| A-13 | Breaker: CPA > 4× target for 3 consecutive hours | B-10 |

## Part C · Blockers
| ID | Blocker | Needed before | Workaround |
|---|---|---|---|
| B-01 | Verified sending domain and SendGrid account | Stage 8 | Mailpit + fake provider |
| B-02 | Consent/unsubscribe/legal review | first real send | fictional contacts |
| B-03 | KPI formulas/attribution (OQ-09) | Stage 9 sign-off | A-08 |
| B-04 | Hosting (OQ-13) | Stage 10 | Docker Compose |
| B-05 | Performance numbers (OQ-12) | Stage 10 | baseline with Measure first |
| B-06 | Attachment types (OQ-14) | attachments | not built |
| B-07 | Swap on SCHEDULED/RUNNING | Stage 4 | see 00 |
| B-08 | Editorial patches allowed? | Stage 3 flag-on | flag OFF |
| B-09 | Role list | Stage 6 | data-driven roles |
| B-10 | Breaker thresholds/resume | Stage 9 | A-13 |
| B-11 | DPS parameters, SLA | Stage 6 | config, TBD |
| B-12 | Currency vs threshold | Stage 1 | USD only |
| B-14 | Internal notes after completion | Stage 7 | no access |
| B-15 | Minor-edit budget tolerance | Stage 3 flag-on | 0% |
