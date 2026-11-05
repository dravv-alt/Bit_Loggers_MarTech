# 04 · Task Queue (revised for ADR v2.0)
**Rule:** exactly one task in progress. Take the first `NEXT` row; when done mark `DONE` and promote the next unblocked row. Sizes are planning estimates only (30 min to a few hours); no measured velocity exists (TBD).
Status: `NEXT` · `QUEUED` · `BLOCKED` · `DONE`.

## Stage 1 · Approval core
| ID | Task | Size | Depends on | Status | Done when |
|---|---|---|---|---|---|
| T1-01 | Repo scaffold; `docker-compose.yml` with pinned TimescaleDB image; `.env.example`; README skeleton | 1 h | none | **NEXT** | DB reachable, `timescaledb` extension creatable |
| T1-02 | Backend skeleton, Alembic wired, migration `0001_extensions` (timescaledb, btree_gist, citext); create `migrator` and `app_rw` DB roles | 1.5 h | T1-01 | QUEUED | upgrade works; app role is not an owner |
| T1-03 | Migration `0002_identity_rbac` (data-driven roles/permissions, `UNIQUE (user_id, role_code)`); seed MARKETER, REVIEWER and fictional users | 1.5 h | T1-02 | QUEUED | seeded permissions queryable |
| T1-04 | Migration `0003_campaign_version`: `channel`, `campaign`, `campaign_version` (governance_status, generated `required_tiers`, `UNIQUE` combos for composite FKs, deferred FKs), `version_kpi_targets` | 2 h | T1-03 | QUEUED | circular insert works in one txn |
| T1-05 | Migration `0004_decision`: `approval_decision` (tier, reviewer_role, campaign_owner_id, composite FKs, CHECKs) | 2 h | T1-04 | QUEUED | DB-3 test can be written |
| T1-06 | Migration `0005_schedule`: `campaign_schedule` with declarative guard, tier FKs, GiST exclusion `WHERE ACTIVE` | 2 h | T1-05 | QUEUED | DDL applies cleanly |
| T1-07 | Raw-SQL constraint tests: ADR-003, ADR-003b, ADR-012, DB-3 | 2 h | T1-06 | QUEUED | all pass |
| T1-08 | Migration `0006_audit`: `audit_event` hypertable, `actor_type`; verify FK-from-hypertable behaviour on pinned image; record result in D-01 | 2 h | T1-04 | QUEUED | audit insert works |
| T1-09 | Migration `0007_outbox` (`available_at`, DEAD status, index) + `outbox.write()` helper | 1 h | T1-05 | QUEUED | helper writes inside a given txn |
| T1-10 | Migration `0008_grants`: revoke UPDATE/DELETE, column-level UPDATE on versions, INSERT-only audit; tests DB-1, DB-2 | 1.5 h | T1-07, T1-08, T1-09 | QUEUED | grant tests pass |
| T1-11 | App core: config, async pool + `transaction()`, correlation-ID middleware, `ApiError` + handlers, JSON logging with redaction | 2 h | T1-02 | QUEUED | any error returns code + correlation id |
| T1-12 | Auth: argon2id, `POST /auth/login`, JWT, `current_user`, `GET /me` | 2 h | T1-03, T1-11 | QUEUED | T-01 passes |
| T1-13 | RBAC: `require(permission)`, policy functions (owner, reviewer visibility), route-registry test | 2 h | T1-12 | QUEUED | Registry test passes |
| T1-14 | `POST /campaigns`, `GET` campaign/versions | 2 h | T1-13, T1-04 | QUEUED | create + fetch works |
| T1-15 | `POST /campaigns/{id}/versions` (submit proposal, `expected_version`, in-review guard, audit + outbox) | 2.5 h | T1-14, T1-08, T1-09 | QUEUED | submit tests pass |
| T1-16 | Unified decisions endpoint with ordered validation, governance transitions, active-version promotion | 3 h | T1-15 | QUEUED | T-01…T-06 pass |
| T1-17 | Lifecycle tests: ADR-002 scenario, tier-2 fail-closed | 1.5 h | T1-16 | QUEUED | pass |
| T1-18 | Race test (20 parallel, loop 50×) | 1.5 h | T1-16 | QUEUED | stable |
| T1-19 | Atomicity test (injected failure) | 1 h | T1-16 | QUEUED | no partial rows |
| T1-20 | Stage 1 exit review: README, assumptions re-read, update D-01 with Timescale result | 1 h | T1-17..19 | QUEUED | checklist in 03 ticked |

## Later stages (epics; split into 30 min – few hour tasks when the stage starts)
| ID | Epic | Stage | Status | Notes |
|---|---|---|---|---|
| E2-01 | Flutter scaffold, tokens, generated client | S2 | BLOCKED by S1 | |
| E2-02 | Login, secure storage, role shells | S2 | BLOCKED | |
| E2-03 | Campaign list/detail, submit proposal UI | S2 | BLOCKED | |
| E2-04 | Review queue + decision sheet | S2 | BLOCKED | |
| E2-05 | `PerformanceMonitor` interface + Measure adapter + no-op adapter | S2 | BLOCKED | see 08 |
| E2-06 | Baseline traces: cold launch, login, queue load, decision submit | S2 | BLOCKED | numbers TBD |
| E3-01 | `campaign_draft`, `If-Match` autosave endpoint | S3 | BLOCKED | |
| E3-02 | `edit_lock` with sessions, heartbeat, distinct errors | S3 | BLOCKED | |
| E3-03 | Semantic diff classifier + submit-from-draft | S3 | BLOCKED | flag OFF; B-08, B-15 |
| E3-04 | `version_patch` + `version_effective` view | S3 | BLOCKED | flag OFF |
| E3-05 | Flutter editor: local-first autosave, lease banner, conflict diff | S3 | BLOCKED | |
| E4-01 | Schedule/cancel endpoints + swap rule | S4 | BLOCKED | B-07 |
| E4-02 | Calendar API + UI | S4 | BLOCKED | |
| E4-03 | Cancel/pause/resume + RUNNING/COMPLETED worker | S4 | BLOCKED | |
| E4-04 | `diagnostic_event` hypertable + post-rollback logging | S4 | BLOCKED | |
| E5-01 | Idempotency wrapper (with exemptions) | S5 | BLOCKED | |
| E5-02 | Outbox dispatcher, DLQ, notification tables | S5 | BLOCKED | |
| E5-03 | FCM push + workflow email + retries | S5 | BLOCKED | |
| E5-04 | Drift cache, change feed, pending actions, recovery | S5 | BLOCKED | |
| E6-01 | Roles FINANCE_EXECUTIVE, SENIOR_REVIEWER, MANAGER (migration) | S6 | BLOCKED | B-09 |
| E6-02 | Tier-2 decisions, PENDING_TIER_2 flow, schedule guard end-to-end | S6 | BLOCKED | |
| E6-03 | `review_work_queue`, DPS worker, tracks, claim-next | S6 | BLOCKED | B-11 |
| E6-04 | Queue UI with score breakdown | S6 | BLOCKED | |
| E7-01 | Threads/messages/mentions + internal-only policy | S7 | BLOCKED | |
| E7-02 | Per-channel leak tests | S7 | BLOCKED | |
| E8-01 | Contacts, lists, suppression, import | S8 | BLOCKED | B-01, B-02 |
| E8-02 | Launch scheduler + materialisation | S8 | BLOCKED | |
| E8-03 | Batch sender (SendGrid adapter), retries, breaker linkage | S8 | BLOCKED | |
| E8-04 | Webhooks, tracking, unsubscribe | S8 | BLOCKED | |
| E8-05 | Launch UI | S8 | BLOCKED | |
| E9-01 | Telemetry hypertable, rollups, KPI view, dashboard cache | S9 | BLOCKED | B-03 |
| E9-02 | Analytics API + charts | S9 | BLOCKED | |
| E9-03 | Breaker worker + runtime controls | S9 | BLOCKED | B-10 |
| E9-04 | AI summary job, fallback card, proposal assist | S9 | BLOCKED | |
| E10-01 | Measure-driven profiling and optimisation (before/after) | S10 | BLOCKED | 08 |
| E10-02 | Load tests incl. 200 concurrent dashboards during approvals | S10 | BLOCKED | |
| E10-03 | Security suite, metrics, alerts | S10 | BLOCKED | |
| E10-04 | CI/CD, store builds, backup/restore drill | S10 | BLOCKED | B-04 |
