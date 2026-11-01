import { DatabaseSync } from 'node:sqlite';
import path from 'node:path';
import fs from 'node:fs';

const DB_PATH = process.env.DB_PATH || path.resolve(process.cwd(), 'campaigns.db');

export function initDatabase(dbPath) {
  const targetPath = dbPath || DB_PATH;
  const dbDir = path.dirname(targetPath);
  if (!fs.existsSync(dbDir)) {
    fs.mkdirSync(dbDir, { recursive: true });
  }

  const db = new DatabaseSync(targetPath);

  // Enable WAL and Foreign Keys
  db.exec('PRAGMA journal_mode = WAL;');
  db.exec('PRAGMA foreign_keys = ON;');

  // Create tables according to Bit Loggers LLD
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT NOT NULL,
      role TEXT NOT NULL CHECK(role IN ('marketer', 'reviewer', 'admin')),
      avatar TEXT
    );

    CREATE TABLE IF NOT EXISTS campaigns (
      campaign_id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      owner_id TEXT NOT NULL REFERENCES users(id),
      status TEXT NOT NULL CHECK(status IN ('Draft', 'Submitted', 'ChangesRequested', 'Approved', 'Revised', 'Scheduled', 'Rejected', 'Completed')),
      current_version_id TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS campaign_versions (
      version_id TEXT PRIMARY KEY,
      campaign_id TEXT NOT NULL REFERENCES campaigns(campaign_id),
      version_no INTEGER NOT NULL,
      objective TEXT NOT NULL,
      target_audience TEXT NOT NULL,
      channel TEXT NOT NULL,
      budget REAL NOT NULL,
      kpi_projected TEXT NOT NULL,
      kpi_actual TEXT,
      snapshot TEXT NOT NULL,
      ai_summary TEXT,
      created_by TEXT NOT NULL REFERENCES users(id),
      created_at TEXT NOT NULL,
      UNIQUE (campaign_id, version_no)
    );

    CREATE TABLE IF NOT EXISTS approval_decisions (
      decision_id TEXT PRIMARY KEY,
      campaign_id TEXT NOT NULL REFERENCES campaigns(campaign_id),
      version_id TEXT NOT NULL UNIQUE REFERENCES campaign_versions(version_id),
      reviewer_id TEXT NOT NULL REFERENCES users(id),
      decision_type TEXT NOT NULL CHECK(decision_type IN ('APPROVED', 'CHANGES_REQUESTED', 'REJECTED')),
      reason TEXT NOT NULL CHECK(length(trim(reason)) > 0),
      policy_reference TEXT,
      decided_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS decision_amendments (
      amendment_id TEXT PRIMARY KEY,
      decision_id TEXT NOT NULL REFERENCES approval_decisions(decision_id),
      amended_by TEXT NOT NULL REFERENCES users(id),
      amendment_reason TEXT NOT NULL CHECK(length(trim(amendment_reason)) > 0),
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS schedules (
      schedule_id TEXT PRIMARY KEY,
      campaign_id TEXT NOT NULL REFERENCES campaigns(campaign_id),
      version_id TEXT NOT NULL REFERENCES campaign_versions(version_id),
      decision_id TEXT NOT NULL REFERENCES approval_decisions(decision_id),
      starts_at TEXT NOT NULL,
      ends_at TEXT NOT NULL,
      channel TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'SCHEDULED',
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS audit_events (
      event_id TEXT PRIMARY KEY,
      campaign_id TEXT REFERENCES campaigns(campaign_id),
      version_id TEXT,
      actor_id TEXT NOT NULL,
      event_type TEXT NOT NULL,
      previous_state TEXT,
      new_state TEXT,
      details TEXT,
      correlation_id TEXT,
      occurred_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS outbox_events (
      event_id TEXT PRIMARY KEY,
      event_type TEXT NOT NULL,
      payload TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING', 'PROCESSED', 'FAILED')),
      attempts INTEGER NOT NULL DEFAULT 0,
      last_error TEXT,
      available_at TEXT NOT NULL,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS idempotency_keys (
      user_id TEXT NOT NULL,
      operation TEXT NOT NULL,
      idempotency_key TEXT NOT NULL,
      campaign_id TEXT,
      request_hash TEXT NOT NULL,
      stored_response TEXT NOT NULL,
      created_at TEXT NOT NULL,
      PRIMARY KEY (user_id, operation, idempotency_key)
    );

    CREATE TABLE IF NOT EXISTS edit_locks (
      campaign_id TEXT PRIMARY KEY REFERENCES campaigns(campaign_id),
      holder_id TEXT NOT NULL REFERENCES users(id),
      holder_name TEXT NOT NULL,
      acquired_at TEXT NOT NULL,
      expires_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS discussions (
      message_id TEXT PRIMARY KEY,
      campaign_id TEXT NOT NULL REFERENCES campaigns(campaign_id),
      author_id TEXT NOT NULL REFERENCES users(id),
      author_name TEXT NOT NULL,
      author_role TEXT NOT NULL,
      content TEXT NOT NULL,
      mentions TEXT,
      parent_id TEXT,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS notifications (
      notification_id TEXT PRIMARY KEY,
      recipient_id TEXT NOT NULL REFERENCES users(id),
      campaign_id TEXT,
      event_type TEXT NOT NULL,
      title TEXT NOT NULL,
      message TEXT NOT NULL,
      channel TEXT NOT NULL CHECK(channel IN ('in-app', 'push', 'email')),
      priority TEXT NOT NULL DEFAULT 'medium',
      dedupe_key TEXT UNIQUE,
      is_read INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS diagnostic_logs (
      log_id TEXT PRIMARY KEY,
      correlation_id TEXT NOT NULL,
      campaign_id TEXT,
      version_id TEXT,
      event_type TEXT NOT NULL,
      actor_id TEXT,
      outcome TEXT NOT NULL,
      error_category TEXT,
      message TEXT NOT NULL,
      timestamp TEXT NOT NULL
    );

    CREATE INDEX IF NOT EXISTS idx_outbox_due ON outbox_events (status, available_at);
    CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON notifications (recipient_id, is_read);
    CREATE INDEX IF NOT EXISTS idx_audit_campaign ON audit_events (campaign_id, occurred_at);
    CREATE INDEX IF NOT EXISTS idx_schedules_channel_dates ON schedules (channel, starts_at, ends_at);
  `);

  // Seed default demo users if not present
  const userCount = db.prepare('SELECT COUNT(*) as count FROM users').get().count;
  if (userCount === 0) {
    const insertUser = db.prepare(`
      INSERT INTO users (id, name, email, role, avatar)
      VALUES (?, ?, ?, ?, ?)
    `);

    insertUser.run('usr-marketer-1', 'Alice Cooper (Marketer)', 'alice.marketer@bitloggers.com', 'marketer', 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150');
    insertUser.run('usr-reviewer-1', 'Marcus Vance (Reviewer)', 'marcus.reviewer@bitloggers.com', 'reviewer', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150');
    insertUser.run('usr-reviewer-2', 'Elena Rostova (Compliance)', 'elena.compliance@bitloggers.com', 'reviewer', 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=150');
    insertUser.run('usr-admin-1', 'Sarah Jenkins (Platform Admin)', 'sarah.admin@bitloggers.com', 'admin', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150');
  }

  return db;
}
