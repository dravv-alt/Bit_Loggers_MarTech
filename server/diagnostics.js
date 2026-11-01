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

  log({ correlationId, campaignId, versionId, eventType, actorId, outcome = 'INFO', errorCategory = null, message }) {
    const logId = 'log-' + crypto.randomUUID().slice(0, 8);
    const timestamp = new Date().toISOString();
    const corrId = correlationId || ('c-' + crypto.randomUUID().slice(0, 8));

    try {
      const stmt = this.db.prepare(`
        INSERT INTO diagnostic_logs 
        (log_id, correlation_id, campaign_id, version_id, event_type, actor_id, outcome, error_category, message, timestamp)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `);
      stmt.run(
        logId,
        corrId,
        campaignId || null,
        versionId || null,
        eventType,
        actorId || null,
        outcome || 'INFO',
        errorCategory || null,
        message || '',
        timestamp
      );
    } catch (err) {
      console.error('Failed to write diagnostic log:', err.message);
    }

    // Also console log for debugging
    const symbol = outcome === 'FAILURE' ? '❌' : outcome === 'SUCCESS' ? '✅' : 'ℹ️';
    console.log(`[DIAGNOSTIC] ${symbol} [${eventType}] [Corr: ${corrId}] [Camp: ${campaignId || 'N/A'}] ${message}`);

    return { logId, correlationId: corrId, timestamp };
  }

  getLogs({ limit = 100, eventType = null, campaignId = null } = {}) {
    let query = 'SELECT * FROM diagnostic_logs';
    const params = [];
    const conditions = [];

    if (eventType) {
      conditions.push('event_type = ?');
      params.push(eventType);
    }
    if (campaignId) {
      conditions.push('campaign_id = ?');
      params.push(campaignId);
    }

    if (conditions.length > 0) {
      query += ' WHERE ' + conditions.join(' AND ');
    }

    query += ' ORDER BY timestamp DESC LIMIT ?';
    params.push(limit);

    return this.db.prepare(query).all(...params);
  }
}
