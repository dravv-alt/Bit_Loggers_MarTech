import crypto from 'node:crypto';
import { DIAGNOSTIC_EVENTS } from './diagnostics.js';

export class OutboxService {
  constructor(db, diagnostics) {
    this.db = db;
    this.diagnostics = diagnostics;
    this.isEmailServiceFailing = false;
    this.maxAttempts = 3;
  }

  setEmailFailing(failing) {
    this.isEmailServiceFailing = Boolean(failing);
    console.log(`[OUTBOX] Email provider failure simulation: ${this.isEmailServiceFailing ? 'ON' : 'OFF'}`);
  }

  // Poll and process due outbox events asynchronously
  async processPendingEvents() {
    try {
      const dueQuery = `
        SELECT * FROM outbox_events
        WHERE status IN ('PENDING', 'FAILED') AND next_retry_at <= NOW()
        ORDER BY created_at ASC
        LIMIT 20
      `;
      const res = await this.db.query(dueQuery);
      const events = res.rows;
      if (events.length === 0) return [];

      const results = [];

      for (const evt of events) {
        let payload = evt.payload;
        if (typeof payload === 'string') {
          try {
            payload = JSON.parse(payload);
          } catch (_) {
            payload = {};
          }
        }

        const { recipients = [], title, message, campaign_id, correlation_id } = payload;
        const channels = ['in-app', 'push', 'email'];
        let allChannelsSucceeded = true;
        let failureReason = null;

        for (const recipientId of recipients) {
          for (const channel of channels) {
            // Simulate external email gateway outage
            if (channel === 'email' && this.isEmailServiceFailing) {
              allChannelsSucceeded = false;
              failureReason = 'EmailProviderGatewayTimeout: SMTP server unreachable';
              continue;
            }

            // Insert durable in-app notification
            const notifId = 'notif-' + crypto.randomUUID().slice(0, 8);
            try {
              await this.db.query(
                `INSERT INTO notifications 
                 (notification_id, recipient_id, campaign_id, event_type, title, body, is_read, created_at)
                 VALUES ($1, $2, $3, $4, $5, $6, FALSE, NOW())`,
                [
                  notifId,
                  recipientId,
                  campaign_id || null,
                  evt.event_type,
                  title || evt.event_type,
                  message || ''
                ]
              );
            } catch (err) {
              console.error(`[OUTBOX] Failed to insert notification: ${err.message}`);
            }
          }
        }

        if (allChannelsSucceeded) {
          await this.db.query(
            `UPDATE outbox_events 
             SET status = 'PROCESSED', processed_at = NOW(), error_log = NULL
             WHERE event_id = $1`,
            [evt.event_id]
          );
          results.push({ event_id: evt.event_id, status: 'PROCESSED' });
        } else {
          const nextAttempts = (evt.attempts || 0) + 1;
          const backoffSeconds = Math.pow(2, nextAttempts);

          await this.diagnostics.log({
            correlationId: correlation_id,
            campaignId: campaign_id,
            eventType: DIAGNOSTIC_EVENTS.NOTIFICATION_RETRY,
            outcome: 'WARNING',
            errorCategory: 'DELIVERY_FAILURE',
            message: `Notification delivery failed for event ${evt.event_id}. Attempt ${nextAttempts}/${this.maxAttempts}. Error: ${failureReason}. Retry scheduled in ${backoffSeconds}s`
          });

          const newStatus = nextAttempts >= this.maxAttempts ? 'FAILED' : 'PENDING';
          await this.db.query(
            `UPDATE outbox_events
             SET status = $1, attempts = $2, error_log = $3, next_retry_at = NOW() + ($4 || ' seconds')::INTERVAL
             WHERE event_id = $5`,
            [newStatus, nextAttempts, failureReason, backoffSeconds.toString(), evt.event_id]
          );
          results.push({ event_id: evt.event_id, status: newStatus, error: failureReason, attempts: nextAttempts });
        }
      }

      return results;
    } catch (err) {
      console.error('[OUTBOX] Error in processPendingEvents:', err.message);
      return [];
    }
  }
}
