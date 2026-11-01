import crypto from 'node:crypto';
import { DIAGNOSTIC_EVENTS } from './diagnostics.js';

export class OutboxService {
  constructor(db, diagnostics) {
    this.db = db;
    this.diagnostics = diagnostics;
    this.isEmailServiceFailing = false; // toggle for testing failure/recovery
    this.maxAttempts = 3;
  }

  setEmailFailing(failing) {
    this.isEmailServiceFailing = Boolean(failing);
    console.log(`[OUTBOX] Email provider failure simulation: ${this.isEmailServiceFailing ? 'ON' : 'OFF'}`);
  }

  // Poll and process due outbox events
  processPendingEvents() {
    const now = new Date().toISOString();
    const events = this.db.prepare(`
      SELECT * FROM outbox_events
      WHERE status = 'PENDING' AND available_at <= ?
      ORDER BY created_at ASC
      LIMIT 20
    `).all(now);

    const results = [];

    for (const evt of events) {
      let payload;
      try {
        payload = JSON.parse(evt.payload);
      } catch (err) {
        payload = {};
      }

      const { recipients = [], title, message, campaign_id, priority = 'medium', correlation_id } = payload;
      const channels = ['in-app', 'push', 'email'];
      let allChannelsSucceeded = true;
      let failureReason = null;

      for (const recipientId of recipients) {
        for (const channel of channels) {
          const dedupeKey = `${evt.event_id}:${recipientId}:${channel}`;

          // Check if notification already created
          const existing = this.db.prepare(`SELECT notification_id FROM notifications WHERE dedupe_key = ?`).get(dedupeKey);
          if (existing) {
            continue; // Deduplication prevents duplicates
          }

          // Simulate external channel delivery
          if (channel === 'email' && this.isEmailServiceFailing) {
            allChannelsSucceeded = false;
            failureReason = 'EmailProviderGatewayTimeout: SMTP server unreachable';
            continue;
          }

          // Store notification
          const notifId = 'notif-' + crypto.randomUUID().slice(0, 8);
          try {
            this.db.prepare(`
              INSERT INTO notifications 
              (notification_id, recipient_id, campaign_id, event_type, title, message, channel, priority, dedupe_key, is_read, created_at)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)
            `).run(notifId, recipientId, campaign_id || null, evt.event_type, title || evt.event_type, message || '', channel, priority, dedupeKey, new Date().toISOString());
          } catch (err) {
            console.error(`Failed to create notification: ${err.message}`);
          }
        }
      }

      if (allChannelsSucceeded) {
        // Mark event processed
        this.db.prepare(`
          UPDATE outbox_events 
          SET status = 'PROCESSED', last_error = NULL
          WHERE event_id = ?
        `).run(evt.event_id);

        results.push({ event_id: evt.event_id, status: 'PROCESSED' });
      } else {
        // Increment attempts & backoff
        const nextAttempts = evt.attempts + 1;
        const backoffSeconds = Math.pow(2, nextAttempts); // Exponential backoff: 2s, 4s, 8s
        const nextAvailableAt = new Date(Date.now() + backoffSeconds * 1000).toISOString();

        this.diagnostics.log({
          correlationId: correlation_id,
          campaignId: campaign_id,
          eventType: DIAGNOSTIC_EVENTS.NOTIFICATION_RETRY,
          outcome: 'WARNING',
          errorCategory: 'DELIVERY_FAILURE',
          message: `Notification delivery failed for event ${evt.event_id}. Attempt ${nextAttempts}/${this.maxAttempts}. Error: ${failureReason}. Retry scheduled at ${nextAvailableAt}`
        });

        if (nextAttempts >= this.maxAttempts) {
          this.db.prepare(`
            UPDATE outbox_events
            SET status = 'FAILED', attempts = ?, last_error = ?
            WHERE event_id = ?
          `).run(nextAttempts, failureReason, evt.event_id);
          results.push({ event_id: evt.event_id, status: 'FAILED', error: failureReason });
        } else {
          this.db.prepare(`
            UPDATE outbox_events
            SET status = 'PENDING', attempts = ?, last_error = ?, available_at = ?
            WHERE event_id = ?
          `).run(nextAttempts, failureReason, nextAvailableAt, evt.event_id);
          results.push({ event_id: evt.event_id, status: 'RETRY_SCHEDULED', nextAvailableAt, error: failureReason });
        }
      }
    }

    return results;
  }
}

