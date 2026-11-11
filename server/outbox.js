import crypto from 'node:crypto';
import { DIAGNOSTIC_EVENTS } from './diagnostics.js';
import { OUTBOX_DELIVERY_MACHINE } from './state-machines.js';

export class EmailService {
  constructor({ isFailing = false, providerName = 'MockSMTP' } = {}) {
    this.isFailing = isFailing;
    this.providerName = providerName;
  }

  setFailing(failing) {
    this.isFailing = Boolean(failing);
    console.log(`[EMAIL SERVICE] Provider ${this.providerName} failure simulation: ${this.isFailing ? 'ON' : 'OFF'}`);
  }

  async send({ to, subject, body, metadata = {} } = {}) {
    if (this.isFailing) {
      const err = new Error(`EmailProviderGatewayTimeout: ${this.providerName} unreachable`);
      err.code = 'EMAIL_GATEWAY_TIMEOUT';
      throw err;
    }
    return {
      messageId: `msg-${crypto.randomUUID().slice(0, 8)}`,
      provider: this.providerName,
      deliveredAt: new Date().toISOString()
    };
  }
}

export class OutboxService {
  constructor(db, diagnostics, emailService = null) {
    this.db = db;
    this.diagnostics = diagnostics;
    this.emailService = emailService || new EmailService();
    this.maxAttempts = OUTBOX_DELIVERY_MACHINE.maxAttempts;
  }

  get isEmailServiceFailing() {
    return this.emailService.isFailing;
  }

  set isEmailServiceFailing(val) {
    this.emailService.setFailing(val);
  }

  setEmailService(emailService) {
    this.emailService = emailService;
  }

  setEmailFailing(failing) {
    this.emailService.setFailing(failing);
  }

  // Poll and process due outbox events cleanly through PENDING/FAILED -> PROCESSING -> PROCESSED|FAILED
  async processPendingEvents(options = {}) {
    try {
      const force = options.force === true;
      const dueQuery = force
        ? `
          SELECT * FROM outbox_events
          WHERE status IN ('PENDING', 'FAILED')
          ORDER BY created_at DESC
          LIMIT 20
        `
        : `
          SELECT * FROM outbox_events
          WHERE (status = 'PENDING' OR (status = 'FAILED' AND attempts < max_attempts))
            AND next_retry_at <= NOW()
          ORDER BY created_at DESC
          LIMIT 20
        `;
      const res = await this.db.query(dueQuery);
      const events = res.rows;
      if (events.length === 0) return [];

      const results = [];

      for (const evt of events) {
        await this.db.query(
          `UPDATE outbox_events SET status = 'PROCESSING' WHERE event_id = $1`,
          [evt.event_id]
        );

        let payload = evt.payload;
        if (typeof payload === 'string') {
          try {
            payload = JSON.parse(payload);
          } catch (_) {
            payload = {};
          }
        }

        const { recipients = [], title, message, campaign_id, correlation_id } = payload;
        let allChannelsSucceeded = true;
        let failureReason = null;
        const notifTitle = title || evt.event_type;
        const notifBody = message || '';

        for (const recipientId of recipients) {
          // 1. Dispatch external email channel cleanly
          try {
            await this.emailService.send({
              to: recipientId,
              subject: notifTitle,
              body: notifBody,
              metadata: { campaign_id, correlation_id }
            });
          } catch (emailErr) {
            allChannelsSucceeded = false;
            failureReason = emailErr.message || 'EmailProviderGatewayTimeout: SMTP server unreachable';
          }

          // 2. Insert durable in-app notification once per recipient/event without duplicating across retries
          try {
            const existing = await this.db.query(
              `SELECT 1 FROM notifications
               WHERE recipient_id = $1
                 AND event_type = $2
                 AND title = $3
                 AND (($4::varchar IS NULL AND campaign_id IS NULL) OR campaign_id = $4)
               LIMIT 1`,
              [recipientId, evt.event_type, notifTitle, campaign_id || null]
            );
            if (existing.rows.length === 0) {
              const notifId = 'notif-' + crypto.randomUUID().slice(0, 8);
              await this.db.query(
                `INSERT INTO notifications 
                 (notification_id, recipient_id, campaign_id, event_type, title, body, is_read, created_at)
                 VALUES ($1, $2, $3, $4, $5, $6, FALSE, NOW())`,
                [
                  notifId,
                  recipientId,
                  campaign_id || null,
                  evt.event_type,
                  notifTitle,
                  notifBody
                ]
              );
            }
          } catch (err) {
            console.error(`[OUTBOX] Failed to insert notification: ${err.message}`);
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
          const cap = evt.max_attempts || this.maxAttempts;
          const backoffSeconds = Math.pow(2, nextAttempts);

          await this.diagnostics.log({
            correlationId: correlation_id,
            campaignId: campaign_id,
            eventType: DIAGNOSTIC_EVENTS.NOTIFICATION_RETRY,
            outcome: 'WARNING',
            errorCategory: 'DELIVERY_FAILURE',
            message: `Notification delivery failed for event ${evt.event_id}. Attempt ${nextAttempts}/${cap}. Error: ${failureReason}. Retry scheduled in ${backoffSeconds}s`
          });

          const newStatus = (this.isEmailServiceFailing || nextAttempts >= cap) ? 'FAILED' : 'PENDING';
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
