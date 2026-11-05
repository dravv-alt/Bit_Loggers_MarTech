# 02 · Staged Roadmap (revised for ADR v2.0)
Work one stage at a time. A stage is done only when its exit criteria pass as automated tests. Durations are TBD (no velocity data yet).

| Stage | Goal | ADRs |
|---|---|---|
| S1 | Approval core: dual lifecycle, declarative guards, unified decisions endpoint | 002, 003, 007 (tier 1), 008, 010 |
| S2 | Flutter foundation + Measure baseline | 009 (interfaces), 010 |
| S3 | Draft sandbox, leases, autosave, semantic diff, version promotion | 006, 013 |
| S4 | Scheduling, calendar, operational lifecycle (cancel/pause/resume) | 003, 012, 014 (manual part) |
| S5 | Reliability: idempotency, outbox + DLQ, notifications, offline queue | 004, 005 |
| S6 | Governance extensions: Tier 2, extra roles, review queue (DPS) | 007, 015 |
| S7 | Collaboration: threads, internal notes | 008 |
| S8 | Email campaign launch | PRD-CR-01 |
| S9 | Analytics, runtime breaker, AI summaries | 009, 011, 014 |
| S10 | Hardening, Measure-driven optimisation, release | all |

## S1 · Approval core (backend only)
- **Scope:** TimescaleDB compose; identity + data-driven RBAC (MARKETER, REVIEWER); `campaign` with `operational_status` + `active_version_id`; `campaign_version` with `governance_status` and generated `required_tiers`; `version_kpi_targets`; `approval_decision` with tier column and composite FKs; `campaign_schedule` DDL with the declarative guard and GiST constraint (tested with raw SQL, no endpoint yet); `audit_event` hypertable; `outbox_event`; endpoints: login, create campaign, submit proposal as a new version, unified decisions.
- **Exit criteria:**
  1. ADR-010 ordered-validation tests T-01…T-06 pass (defined in 03).
  2. ADR-002 check: V1 approved → active; V2 rejected; V1 still approved, active and untouched.
  3. ADR-003 check: raw SQL schedule insert against a CHANGES_REQUESTED decision fails with an FK violation; a schedule for a tier-2 version without a tier-2 decision fails.
  4. ADR-012 check: overlapping same-channel ACTIVE schedules rejected; cancelled ones do not block.
  5. App-role UPDATE/DELETE on append-only tables and on version content columns fails.
  6. 20 parallel decisions on one version → exactly one success.
  7. Failure injected after the decision insert leaves no partial rows.
- **Out of scope:** Flutter, sandbox, lease, idempotency, workers, tier-2 role, queue ranking, notifications.

## S2 · Flutter foundation + Measure baseline
- **Scope:** scaffold, tokens, generated client, login, secure storage, role shells, campaign list/detail, submit proposal, review queue (plain order), decision sheet with mandatory reason, error-code mapping; `PerformanceMonitor` interface with Measure adapter and no-op adapter; cold-launch and key-journey baselines captured.
- **Exit:** marketer submits, reviewer approves on an emulator against the real backend; baselines recorded in the Measure dashboard (numbers TBD).

## S3 · Sandbox, lease, autosave, semantic diff
- **Scope:** `campaign_draft`, `edit_lock` (user + session), heartbeat, `LEASE_EXPIRED` / `LEASE_HELD` / `VERSION_CONFLICT`, local-first autosave, submit-from-draft classifier (major only; minor path behind flag), `version_patch` + `version_effective` view (flag OFF by default), baseline-stability tests.
- **Exit:** ADR-006 and ADR-013 verification scenarios pass; with flag OFF every submit creates a version; with flag ON a typo patch creates `PATCH_APPLIED` audit and no new version, while budget +4.9% crossing the $50,000 line is classified major.

## S4 · Scheduling and operational lifecycle
- **Scope:** schedule/cancel endpoints, calendar API + UI, `SCHEDULE_BLOCKED` vs `SCHEDULING_CONFLICT`, version swap rule (B-07 default), cancel/pause/resume, `SCHEDULED → RUNNING → COMPLETED` worker transitions, `diagnostic_event` hypertable.
- **Exit:** AC-09…AC-12 equivalents; concurrent overlapping schedule test; blocked attempts produce diagnostics after rollback.

## S5 · Reliability and offline
- **Scope:** idempotency wrapper (exemptions per D-10), outbox dispatcher, DLQ, notifications (in-app, FCM, workflow email), retry/backoff, Drift cache, change feed, pending-action queue, restart recovery.
- **Exit:** replayed request returns stored response with `Idempotent-Replay: true`; email outage leaves approval committed and delivery retried; kill-during-submit recovers; DEAD events visible to ops.

## S6 · Tiers, roles, review queue
- **Scope:** FINANCE_EXECUTIVE, SENIOR_REVIEWER, MANAGER roles; Tier-2 decisions; `PENDING_TIER_2_APPROVAL`; schedule requires both decisions; `review_work_queue`, DPS recompute worker, escalation + SLA tracks, claim-next, expedite override, score breakdown UI.
- **Exit:** $75,000 flow from ADR-007 passes; corrected ADR-015 scenarios pass (see 05 §10); starvation test shows SLA track promotes an old low-score item.
- **Blockers:** B-09, B-11.

## S7 · Collaboration
- **Scope:** threads with `context_anchor`, messages, mentions, `is_internal_only`, notification filtering, sync-feed filtering.
- **Exit:** a leak test per channel (API, sync, push, email) proves internal notes never reach a marketer.

## S8 · Email launch
- **Scope:** per 06 (contacts, suppression, launcher, SendGrid adapter behind interface, webhooks, tracking, retries, controls, progress UI), plus campaign pause/breaker linkage.
- **Blockers:** B-01, B-02.

## S9 · Analytics, breaker, AI
- **Scope:** `campaign_telemetry`, continuous aggregate, KPI view, dashboard cache, filters, charts; breaker worker; `ai_proposal_summary` job + fallback card; proposal assist.
- **Exit:** breaker scenario pauses within the expected window; Gemini timeout leaves review fully usable; KPI values match hand-computed fixtures. Blockers: B-03, B-10.

## S10 · Hardening and release
- **Scope:** Measure-driven profiling per 08 and 07 §9, load tests (200 concurrent dashboard queries during approvals, outbox lag, launcher throughput), security suite, metrics/alerts, read replica / Redis only if measurements justify, CI/CD, store builds, backup/restore drill.
- **Exit:** PRD Definition of Done plus ADR v2.0 invariants checklist. Blockers: B-04, B-05.
