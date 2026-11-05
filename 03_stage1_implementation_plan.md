# 03 · Stage 1 Implementation Plan: Approval Core (ADR v2.0)
**Milestone:** A backend where a marketer creates a campaign and submits proposals as immutable versions, and a reviewer records exactly one decision per version and tier through one unified endpoint, atomically with an audit row and an outbox row. The dual lifecycle, declarative schedule guard and calendar exclusion constraint are proven by tests. RBAC is enforced for MARKETER and REVIEWER.
**Deliberately excluded:** Flutter, sandbox/draft, lease, idempotency, workers, Tier-2 role and endpoints, review-queue ranking, notifications, AI, analytics, email launch. Full DDL and API are in `05`.

## 1. Repo layout
```
repo/
  docker-compose.yml           # timescaledb only (pinned image tag, TBD)
  backend/
    pyproject.toml
    alembic/versions/          # 0001_extensions 0002_identity_rbac 0003_campaign_version 0004_decision
                               # 0005_schedule 0006_audit_hypertable 0007_outbox 0008_grants
    app/
      main.py config.py db.py errors.py middleware.py security.py rbac.py
      modules/{campaigns,review,audit,outbox}/{routes,service,sql}.py
    tests/
      conftest.py              # testcontainers timescaledb, migrate as migrator, run app as app_rw
      test_constraints.py  test_rbac.py  test_submit_version.py
      test_decisions_ordered.py  test_lifecycles.py  test_concurrency.py  test_atomicity.py
```
**Important:** migrations run as `migrator` (table owner). The API connects as `app_rw`, which must not own tables, otherwise grants and column-level grants do nothing.

## 2. Schema built in Stage 1 (see 05 for DDL)
- Extensions: `timescaledb`, `btree_gist`, `citext`.
- Identity/RBAC (data-driven roles): `app_user`, `role`, `permission`, `role_permission`, `user_role`; seed MARKETER, REVIEWER; fictional users.
- `channel` lookup; `campaign` (`operational_status`, `active_version_id`, deferred FK); `campaign_version` (`governance_status`, generated `required_tiers`, `content_hash`); `version_kpi_targets`.
- `approval_decision` with `approval_tier`, `reviewer_role`, `campaign_owner_id`, composite FKs, `UNIQUE (version_id, approval_tier)`.
- `campaign_schedule` (DDL and constraints only, no endpoints).
- `audit_event` hypertable; `outbox_event` (`available_at`, statuses incl. DEAD).
- Grants: `app_rw` has no UPDATE/DELETE on append-only tables; version UPDATE limited to `(governance_status, submitted_at)`.
- **No triggers** (ADR-003).

## 3. Endpoints built in Stage 1
| Method | Path | Permission | Notes |
|---|---|---|---|
| POST | `/auth/login` | public | access token only (refresh in S2) |
| GET | `/me` | authenticated | id, role, permissions |
| POST | `/campaigns` | `campaign:create` | creates campaign (DRAFT, no version yet) |
| POST | `/campaigns/{id}/versions` | `campaign:submit_own` | body: full proposal + `expected_version`; creates version N+1 as SUBMITTED. **Temporary route**: replaced by draft submit in S3 |
| GET | `/campaigns/{id}`, `/campaigns/{id}/versions`, `/campaigns/{id}/versions/{vid}`, `/campaigns/{id}/versions/{vid}/decisions` | read permissions | visibility policy |
| GET | `/review/queue` | `review:queue` | plain order (`submitted_at`); ranking arrives in S6 |
| POST | `/campaigns/{id}/versions/{vid}/decisions` | `review:decide` | `{type, reason, policy_reference?}` |

Every response has `X-Correlation-Id`. Errors: `{code, message, correlation_id}`. The `Idempotency-Key` header is accepted and ignored until S5 (known gap, documented).

## 4. Governance transitions implemented in Stage 1
| Current governance status | Decision | Tier | Resulting governance status |
|---|---|---|---|
| SUBMITTED | APPROVED, `required_tiers=1` | 1 | APPROVED |
| SUBMITTED | APPROVED, `required_tiers=2` | 1 | PENDING_TIER_2_APPROVAL (no tier-2 endpoint yet; fails closed) |
| SUBMITTED / PENDING_TIER_2 | CHANGES_REQUESTED | 1 / 2 | CHANGES_REQUESTED |
| SUBMITTED / PENDING_TIER_2 | REJECTED | 1 / 2 | REJECTED |
When a version becomes APPROVED: set `campaign.active_version_id` if its `version_no` is higher than the current active one; `operational_status` DRAFT → PUBLISHED if first. Rejection and change requests never touch `active_version_id` (ADR-002).
Tier is derived from the status (SUBMITTED → 1, PENDING_TIER_2 → 2). In Stage 1 a tier-2 attempt returns `403 FORBIDDEN` because no role holds tier-2 rights.

## 5. Decision transaction (ADR-010 order)
```python
async def decide(conn, user, campaign_id, version_id, body, corr):
    # 401: dependency. 403 (role): route dependency require("review:decide").
    async with conn.transaction():
        c = await one(conn, "SELECT id, owner_id, operational_status, active_version_id "
                            "FROM campaign WHERE id=%s FOR UPDATE", campaign_id)   # serialise writers
        if c is None:                         raise ApiError(404, "CAMPAIGN_NOT_FOUND")
        if not policy.can_review(user, c):    raise ApiError(404, "CAMPAIGN_NOT_FOUND")   # not visible
        if c.owner_id == user.id:             raise ApiError(403, "FORBIDDEN")           # self-approval
        v = await one(conn, "SELECT id, campaign_id, version_no, governance_status, required_tiers "
                            "FROM campaign_version WHERE id=%s", version_id)
        if v is None or v.campaign_id != campaign_id:
                                              raise ApiError(422, "VERSION_MISMATCH")
        tier = {"SUBMITTED": 1, "PENDING_TIER_2_APPROVAL": 2}.get(v.governance_status)
        if tier is None:                      raise ApiError(409, "NOT_AWAITING_REVIEW")
        if not role_allows_tier(user.role, tier):
                                              raise ApiError(403, "FORBIDDEN")
        if not body.reason or not body.reason.strip():
                                              raise ApiError(422, "REASON_REQUIRED")
        try:
            did = await insert_decision(conn, ..., tier=tier, reviewer_role=user.role,
                                        campaign_owner_id=c.owner_id)    # UNIQUE (version_id, tier) is the arbiter
        except UniqueViolation:               raise ApiError(409, "NOT_AWAITING_REVIEW")
        new_status = next_status(body.type, tier, v.required_tiers)
        n = await conn.execute("UPDATE campaign_version SET governance_status=%s "
                               "WHERE id=%s AND governance_status=%s",
                               (new_status, version_id, v.governance_status))
        assert n == 1                                            # conditional transition
        if new_status == "APPROVED":
            await promote_active_version(conn, c, v)
        await audit.write(conn, ..., event=f"DECISION_{body.type}", prev=v.governance_status, new=new_status, corr=corr)
        await outbox.write(conn, ..., event=f"DECISION_{body.type}", corr=corr)
    return did
```
Notes:
- The 404 for reviewers who cannot see a campaign hides existence. A campaign is visible to reviewers once it has any submitted version.
- A request with both a wrong state and an empty reason returns 409 (state check precedes reason check, per ADR-010).
- "No writes happen on failure" is what the transaction guarantees; reads still occur (see F-14).
- Diagnostic events for rejected attempts are written after rollback on a separate autocommit connection (to stdout in S1; hypertable in S4).

## 6. Submit-proposal transaction
```sql
-- one txn; campaign row FOR UPDATE; caller must be owner
-- guard: no version currently in SUBMITTED or PENDING_TIER_2_APPROVAL  (409 CAMPAIGN_IN_REVIEW) [A-11]
-- guard: operational_status not CANCELLED/COMPLETED
-- guard: expected_version == (SELECT coalesce(max(version_no),0) FROM campaign_version WHERE campaign_id=$1)  else 409 VERSION_CONFLICT
INSERT INTO campaign_version (id, campaign_id, version_no, created_by, ..., governance_status, submitted_at)
VALUES ($new, $cid, $expected+1, $user, ..., 'SUBMITTED', now());
INSERT INTO version_kpi_targets (...);
-- audit VERSION_CREATED + VERSION_SUBMITTED, outbox VERSION_SUBMITTED (same txn)
```
Budget > $50,000 sets `required_tiers=2` automatically (generated column).

## 7. Tests
| ID | Test | Proves |
|---|---|---|
| T-01 | no/invalid token → 401 UNAUTHENTICATED | auth |
| T-02 | marketer calls decisions → 403; reviewer who owns the campaign (seeded directly) → 403; no rows written | RBAC + self-approval |
| T-03 | unknown campaign id → 404 CAMPAIGN_NOT_FOUND | ordering |
| T-04 | version from another campaign → 422 VERSION_MISMATCH | composite FK + check |
| T-05 | version already decided → 409 NOT_AWAITING_REVIEW; wrong state + empty reason also → 409 | ordering |
| T-06 | empty / whitespace reason → 422 REASON_REQUIRED, no decision row | reason rule + CHECK |
| ADR-002 | V1 approved → active; V2 submitted then REJECTED; V1 still APPROVED and active, V2 REJECTED | dual lifecycle |
| ADR-003 | raw SQL schedule insert pointing at a CHANGES_REQUESTED decision → FK violation | declarative guard |
| ADR-003b | schedule for `required_tiers=2` without tier-2 decision → CHECK violation | tier guard |
| ADR-012 | overlapping ACTIVE same-channel windows → exclusion violation; CANCELLED does not block; different channel allowed | calendar |
| DB-1 | as `app_rw`: UPDATE content column on `campaign_version` fails; UPDATE `governance_status` works; DELETE fails | column-level grants |
| DB-2 | as `app_rw`: UPDATE/DELETE on `approval_decision`, `audit_event` fails | append-only |
| DB-3 | raw decision with `reviewer_id = campaign_owner_id` → CHECK violation; reviewer without role → FK violation | declarative separation of duties |
| Race | 20 parallel decisions by different reviewers → 1 success, 19 × 409 | row lock + unique |
| Atomic | injected failure after decision insert → no decision, no status change, no outbox, no audit | one transaction |
| Registry | every route has a declared permission | RBAC completeness |

## 8. Stage 1 exit checklist
- [ ] `docker compose up`; `alembic upgrade head` from empty.
- [ ] `pytest` green; race test passes 50 consecutive runs.
- [ ] Timescale FK behaviour verified on the pinned image and written back into D-01.
- [ ] README: run, test, role/grant model, known gaps (no idempotency, no sandbox).
- [ ] Assumptions A-02, A-11, A-12 re-read.
