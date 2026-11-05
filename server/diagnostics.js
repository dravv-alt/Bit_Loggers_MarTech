import crypto from 'node:crypto';

export const DIAGNOSTIC_EVENTS = {
  CAMPAIGN_SUBMITTED: 'CAMPAIGN_SUBMITTED',
  APPROVAL_REQUESTED: 'APPROVAL_REQUESTED',
  CAMPAIGN_APPROVED: 'CAMPAIGN_APPROVED',
  CHANGES_REQUESTED: 'CHANGES_REQUESTED',
  CAMPAIGN_REJECTED: 'CAMPAIGN_REJECTED',
  VERSION_CREATED: 'VERSION_CREATED',
  VERSION_CONFLICT: 'VERSION_CONFLICT',
  SCHEDULE_BLOCKED: 'SCHEDULE_BLOCKED',
  CAMPAIGN_SCHEDULED: 'CAMPAIGN_SCHEDULED',
  EDIT_LOCK_ACQUIRED: 'EDIT_LOCK_ACQUIRED',
  EDIT_LOCK_EXPIRED: 'EDIT_LOCK_EXPIRED',
  NOTIFICATION_RETRY: 'NOTIFICATION_RETRY',
  AI_REQUEST_FAILED: 'AI_REQUEST_FAILED'
};

export class Diagnostics {
  constructor(db) {
    this.db = db;
  }

  async log({ correlationId, campaignId, versionId, eventType, actorId, outcome = 'INFO', errorCategory = null, message = '', latencyMs = null, details = null }) {
    const logId = 'log-' + crypto.randomUUID().slice(0, 8);
    const recordedAt = new Date().toISOString();
    const corrId = correlationId || ('c-' + crypto.randomUUID().slice(0, 8));

    try {
      await this.db.query(
        `INSERT INTO diagnostic_logs 
         (log_id, recorded_at, correlation_id, campaign_id, version_id, event_type, outcome, actor_id, latency_ms, details)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
        [
          logId,
          recordedAt,
          corrId,
          campaignId || null,
          versionId || null,
          eventType,
          outcome,
          actorId || null,
          latencyMs || null,
          details ? JSON.stringify(details) : null
        ]
      );
    } catch (err) {
      console.error('[DIAGNOSTICS] Failed to write hypertable log:', err.message);
    }

    // Console output for immediate developer visibility
    const symbol = outcome === 'FAILURE' ? '❌' : outcome === 'SUCCESS' ? '✅' : 'ℹ️';
    console.log(`[DIAGNOSTIC] ${symbol} [${eventType}] [Corr: ${corrId}] [Camp: ${campaignId || 'N/A'}] ${message}`);

    return { logId, correlationId: corrId, timestamp: recordedAt };
  }

  async getLogs({ limit = 100, eventType = null, campaignId = null } = {}) {
    let sql = 'SELECT * FROM diagnostic_logs';
    const params = [];
    const conditions = [];

    if (eventType) {
      params.push(eventType);
      conditions.push(`event_type = $${params.length}`);
    }
    if (campaignId) {
      params.push(campaignId);
      conditions.push(`campaign_id = $${params.length}`);
    }

    if (conditions.length > 0) {
      sql += ' WHERE ' + conditions.join(' AND ');
    }

    params.push(limit);
    sql += ` ORDER BY recorded_at DESC LIMIT $${params.length}`;

    const res = await this.db.query(sql, params);
    return res.rows;
  }
}
