-- ====================================================================
-- CAMPAIGNGRID / BIT LOGGERS — POSTGRESQL + TIMESCALEDB CORE SCHEMA
-- PRD Pillars:
--   1. Relational Entities (Users, Campaigns, Versions, Decisions, Outbox)
--   2. TimescaleDB Hypertables (Audit Events, Version History, Diagnostic Logs, KPIs)
-- ====================================================================

CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

-- --------------------------------------------------------------------
-- 1. USERS & RBAC (FR-01)
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  user_id VARCHAR(64) PRIMARY KEY,
  name VARCHAR(128) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  role VARCHAR(32) NOT NULL CHECK (role IN ('marketer', 'reviewer', 'admin')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- --------------------------------------------------------------------
-- 2. CAMPAIGNS (FR-02)
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS campaigns (
  campaign_id VARCHAR(64) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  owner_id VARCHAR(64) NOT NULL REFERENCES users(user_id),
  status VARCHAR(32) NOT NULL CHECK (status IN ('Draft', 'Submitted', 'Approved', 'ChangesRequested', 'Rejected', 'Scheduled', 'Completed')),
  current_version_id VARCHAR(64),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- --------------------------------------------------------------------
-- 3. CAMPAIGN VERSIONS (FR-02, FR-06)
-- Immutable snapshots. Each revision creates a new version number.
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS campaign_versions (
  version_id VARCHAR(64) PRIMARY KEY,
  campaign_id VARCHAR(64) NOT NULL REFERENCES campaigns(campaign_id) ON DELETE CASCADE,
  version_no INT NOT NULL,
  title VARCHAR(255) NOT NULL,
  objective TEXT NOT NULL,
  target_audience TEXT NOT NULL,
  channel VARCHAR(64) NOT NULL,
  budget NUMERIC(14, 2) NOT NULL,
  kpi_projected JSONB NOT NULL,
  kpi_actual JSONB,
  ai_summary TEXT,
  creatives JSONB DEFAULT '[]'::jsonb,
  targeting JSONB DEFAULT '{}'::jsonb,
  financials JSONB DEFAULT '{}'::jsonb,
  compliance JSONB DEFAULT '{}'::jsonb,
  ad_network JSONB DEFAULT '{}'::jsonb,
  flight_phases JSONB DEFAULT '[]'::jsonb,
  tracking JSONB DEFAULT '{}'::jsonb,
  created_by VARCHAR(64) NOT NULL REFERENCES users(user_id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_campaign_version_no UNIQUE (campaign_id, version_no)
);

-- Foreign key back from campaigns.current_version_id
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_campaigns_current_version'
  ) THEN
    ALTER TABLE campaigns 
      ADD CONSTRAINT fk_campaigns_current_version 
      FOREIGN KEY (current_version_id) 
      REFERENCES campaign_versions(version_id) 
      DEFERRABLE INITIALLY DEFERRED;
  END IF;
END $$;

-- --------------------------------------------------------------------
-- 4. APPROVAL DECISIONS (FR-05)
-- Exactly one decision per version. Mandatory explanation reason.
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS approval_decisions (
  decision_id VARCHAR(64) PRIMARY KEY,
  campaign_id VARCHAR(64) NOT NULL REFERENCES campaigns(campaign_id) ON DELETE CASCADE,
  version_id VARCHAR(64) NOT NULL REFERENCES campaign_versions(version_id) ON DELETE CASCADE,
  reviewer_id VARCHAR(64) NOT NULL REFERENCES users(user_id),
  decision_type VARCHAR(32) NOT NULL CHECK (decision_type IN ('APPROVED', 'CHANGES_REQUESTED', 'REJECTED')),
  reason TEXT NOT NULL CHECK (length(trim(reason)) > 0),
  policy_ref VARCHAR(128),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_decision_per_version UNIQUE (version_id)
);

-- --------------------------------------------------------------------
-- 5. FLIGHT SCHEDULES (FR-07, FR-08)
-- Validates only currently approved versions within transaction.
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS schedules (
  schedule_id VARCHAR(64) PRIMARY KEY,
  campaign_id VARCHAR(64) NOT NULL REFERENCES campaigns(campaign_id) ON DELETE CASCADE,
  version_id VARCHAR(64) NOT NULL REFERENCES campaign_versions(version_id) ON DELETE CASCADE,
  decision_id VARCHAR(64) NOT NULL REFERENCES approval_decisions(decision_id),
  channel VARCHAR(64) NOT NULL,
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ NOT NULL,
  status VARCHAR(32) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'CANCELLED', 'COMPLETED')),
  created_by VARCHAR(64) NOT NULL REFERENCES users(user_id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_flight_dates CHECK (ends_at > starts_at)
);

-- --------------------------------------------------------------------
-- 6. EDIT LEASES & CONCURRENCY (FR-14)
-- Exclusive edit lease with expiration.
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS edit_locks (
  campaign_id VARCHAR(64) PRIMARY KEY REFERENCES campaigns(campaign_id) ON DELETE CASCADE,
  user_id VARCHAR(64) NOT NULL REFERENCES users(user_id),
  acquired_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL
);

-- --------------------------------------------------------------------
-- 7. IDEMPOTENCY STORE (FR-03, FR-16)
-- Exact payload match verification & response replay.
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS idempotency_keys (
  key VARCHAR(128) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL REFERENCES users(user_id),
  endpoint VARCHAR(128) NOT NULL,
  request_hash VARCHAR(64) NOT NULL,
  response_code INT NOT NULL,
  response_body JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- --------------------------------------------------------------------
-- 8. TRANSACTIONAL OUTBOX (FR-13, FR-16)
-- Guaranteed delivery & worker retries.
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS outbox_events (
  event_id VARCHAR(64) PRIMARY KEY,
  event_type VARCHAR(64) NOT NULL,
  payload JSONB NOT NULL,
  status VARCHAR(32) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PROCESSING', 'PROCESSED', 'FAILED')),
  attempts INT NOT NULL DEFAULT 0,
  max_attempts INT NOT NULL DEFAULT 3,
  next_retry_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  error_log TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMPTZ
);

-- --------------------------------------------------------------------
-- 9. COLLABORATION: DISCUSSIONS (FR-12)
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS discussions (
  message_id VARCHAR(64) PRIMARY KEY,
  campaign_id VARCHAR(64) NOT NULL REFERENCES campaigns(campaign_id) ON DELETE CASCADE,
  user_id VARCHAR(64) NOT NULL REFERENCES users(user_id),
  content TEXT NOT NULL,
  parent_message_id VARCHAR(64) REFERENCES discussions(message_id) ON DELETE CASCADE,
  version_id VARCHAR(64) REFERENCES campaign_versions(version_id) ON DELETE SET NULL,
  version_no INT,
  mentions JSONB DEFAULT '[]'::jsonb,
  is_internal_only BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE discussions ADD COLUMN IF NOT EXISTS parent_message_id VARCHAR(64) REFERENCES discussions(message_id) ON DELETE CASCADE;
ALTER TABLE discussions ADD COLUMN IF NOT EXISTS version_id VARCHAR(64) REFERENCES campaign_versions(version_id) ON DELETE SET NULL;
ALTER TABLE discussions ADD COLUMN IF NOT EXISTS version_no INT;
ALTER TABLE discussions ADD COLUMN IF NOT EXISTS mentions JSONB DEFAULT '[]'::jsonb;
ALTER TABLE discussions ADD COLUMN IF NOT EXISTS is_internal_only BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_discussions_campaign_id ON discussions(campaign_id);
CREATE INDEX IF NOT EXISTS idx_discussions_parent_id ON discussions(parent_message_id);
CREATE INDEX IF NOT EXISTS idx_discussions_version_id ON discussions(version_id);

-- --------------------------------------------------------------------
-- 10. NOTIFICATIONS (FR-13)
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications (
  notification_id VARCHAR(64) PRIMARY KEY,
  recipient_id VARCHAR(64) NOT NULL REFERENCES users(user_id),
  campaign_id VARCHAR(64) REFERENCES campaigns(campaign_id) ON DELETE CASCADE,
  event_type VARCHAR(64) NOT NULL,
  title VARCHAR(255) NOT NULL,
  body TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ====================================================================
-- TIMESCALEDB HYPERTABLES (Append-only governance, audit, & analytics)
-- ====================================================================

-- --------------------------------------------------------------------
-- 11. AUDIT EVENTS (FR-15) — HYPERTABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_events (
  event_id VARCHAR(64) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  campaign_id VARCHAR(64),
  version_id VARCHAR(64),
  actor_id VARCHAR(64),
  actor_name VARCHAR(128),
  event_type VARCHAR(64) NOT NULL,
  summary TEXT NOT NULL,
  details JSONB,
  PRIMARY KEY (event_id, created_at)
);

SELECT create_hypertable('audit_events', 'created_at', if_not_exists => TRUE);

-- --------------------------------------------------------------------
-- 12. CAMPAIGN VERSION HISTORY (FR-06) — HYPERTABLE
-- Time-series snapshots of every state change & version progression.
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS campaign_version_history (
  history_id VARCHAR(64) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  campaign_id VARCHAR(64) NOT NULL,
  version_id VARCHAR(64) NOT NULL,
  version_no INT NOT NULL,
  snapshot JSONB NOT NULL,
  reason TEXT,
  actor_id VARCHAR(64),
  PRIMARY KEY (history_id, created_at)
);

SELECT create_hypertable('campaign_version_history', 'created_at', if_not_exists => TRUE);

-- --------------------------------------------------------------------
-- 13. DIAGNOSTIC LOGS (FR-16, Section 6.7) — HYPERTABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS diagnostic_logs (
  log_id VARCHAR(64) NOT NULL,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  correlation_id VARCHAR(64) NOT NULL,
  campaign_id VARCHAR(64),
  version_id VARCHAR(64),
  event_type VARCHAR(64) NOT NULL,
  outcome VARCHAR(32) NOT NULL,
  actor_id VARCHAR(64),
  latency_ms INT,
  details JSONB,
  PRIMARY KEY (log_id, recorded_at)
);

SELECT create_hypertable('diagnostic_logs', 'recorded_at', if_not_exists => TRUE);

-- --------------------------------------------------------------------
-- 14. KPI METRIC SNAPSHOTS (FR-09) — HYPERTABLE
-- Standardized 5 KPIs (Conversion Rate, CTR, ROI, CPA, AOV)
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS kpi_metric_snapshots (
  snapshot_id VARCHAR(64) NOT NULL,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  campaign_id VARCHAR(64) NOT NULL,
  channel VARCHAR(64) NOT NULL,
  conversion_rate NUMERIC(6, 2) NOT NULL,
  ctr NUMERIC(6, 2) NOT NULL,
  roi NUMERIC(6, 2) NOT NULL,
  cpa NUMERIC(10, 2) NOT NULL,
  aov NUMERIC(10, 2) NOT NULL,
  is_actual BOOLEAN NOT NULL DEFAULT FALSE,
  impressions INT DEFAULT 0,
  clicks INT DEFAULT 0,
  spend NUMERIC(12, 2) DEFAULT 0,
  conversions INT DEFAULT 0,
  revenue NUMERIC(12, 2) DEFAULT 0,
  PRIMARY KEY (snapshot_id, recorded_at)
);

SELECT create_hypertable('kpi_metric_snapshots', 'recorded_at', if_not_exists => TRUE);

-- Indexes for lightning fast lookups
CREATE INDEX IF NOT EXISTS idx_campaigns_owner ON campaigns(owner_id);
CREATE INDEX IF NOT EXISTS idx_campaigns_status ON campaigns(status);
CREATE INDEX IF NOT EXISTS idx_versions_campaign ON campaign_versions(campaign_id);
CREATE INDEX IF NOT EXISTS idx_schedules_channel_dates ON schedules(channel, starts_at, ends_at);
CREATE INDEX IF NOT EXISTS idx_outbox_pending ON outbox_events(status, next_retry_at) WHERE status IN ('PENDING', 'FAILED');
CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON notifications(recipient_id, is_read);

