import crypto from 'node:crypto';
import { DIAGNOSTIC_EVENTS } from './diagnostics.js';

export class WorkflowService {
  constructor(db, diagnostics, outbox) {
    this.db = db;
    this.diagnostics = diagnostics;
    this.outbox = outbox;
    this.lockTtlSeconds = 300; // 5 minute edit lease
  }

  // --- Helpers ---
  generateId(prefix = 'id') {
    return `${prefix}-${crypto.randomUUID().slice(0, 8)}`;
  }

  hashPayload(payload) {
    return crypto.createHash('sha256').update(JSON.stringify(payload || {})).digest('hex');
  }

  async getUser(userId) {
    const res = await this.db.query('SELECT user_id as id, name, email, role FROM users WHERE user_id = $1', [userId]);
    return res.rows[0] || null;
  }

  async getUsers() {
    const res = await this.db.query('SELECT user_id as id, name, email, role FROM users ORDER BY name ASC');
    return res.rows;
  }

  async getCampaign(campaignId) {
    const res = await this.db.query('SELECT * FROM campaigns WHERE campaign_id = $1', [campaignId]);
    return res.rows[0] || null;
  }

  async getVersion(versionId) {
    const res = await this.db.query('SELECT * FROM campaign_versions WHERE version_id = $1', [versionId]);
    return res.rows[0] || null;
  }

  async getDecision(versionId) {
    const res = await this.db.query('SELECT * FROM approval_decisions WHERE version_id = $1', [versionId]);
    return res.rows[0] || null;
  }

  // --- Concurrency / Edit Leases (FR-14) ---
  async acquireEditLock(campaignId, user, correlationId) {
    const now = new Date();
    const expiresAt = new Date(now.getTime() + this.lockTtlSeconds * 1000).toISOString();
    const nowIso = now.toISOString();

    const existingRes = await this.db.query(
      `SELECT l.*, u.name as holder_name 
       FROM edit_locks l 
       JOIN users u ON l.user_id = u.user_id 
       WHERE l.campaign_id = $1`,
      [campaignId]
    );
    const existingLock = existingRes.rows[0];

    if (existingLock) {
      if (new Date(existingLock.expires_at) > now && existingLock.user_id !== user.id) {
        return {
          granted: false,
          holder_id: existingLock.user_id,
          holder_name: existingLock.holder_name,
          expires_at: existingLock.expires_at,
          message: `Campaign is currently locked by ${existingLock.holder_name} until ${new Date(existingLock.expires_at).toLocaleTimeString()}`
        };
      }

      if (new Date(existingLock.expires_at) <= now && existingLock.user_id !== user.id) {
        await this.diagnostics.log({
          correlationId,
          campaignId,
          eventType: DIAGNOSTIC_EVENTS.EDIT_LOCK_EXPIRED,
          actorId: existingLock.user_id,
          outcome: 'INFO',
          message: `Edit lock for campaign ${campaignId} expired from ${existingLock.holder_name}`
        });
      }

      await this.db.query(
        `UPDATE edit_locks 
         SET user_id = $1, acquired_at = $2, expires_at = $3
         WHERE campaign_id = $4`,
        [user.id, nowIso, expiresAt, campaignId]
      );
    } else {
      await this.db.query(
        `INSERT INTO edit_locks (campaign_id, user_id, acquired_at, expires_at)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (campaign_id) DO UPDATE 
         SET user_id = EXCLUDED.user_id, acquired_at = EXCLUDED.acquired_at, expires_at = EXCLUDED.expires_at`,
        [campaignId, user.id, nowIso, expiresAt]
      );
    }

    await this.diagnostics.log({
      correlationId,
      campaignId,
      eventType: DIAGNOSTIC_EVENTS.EDIT_LOCK_ACQUIRED,
      actorId: user.id,
      outcome: 'SUCCESS',
      message: `Edit lock acquired by ${user.name} until ${expiresAt}`
    });

    return {
      granted: true,
      holder_id: user.id,
      holder_name: user.name,
      acquired_at: nowIso,
      expires_at: expiresAt
    };
  }

  async releaseEditLock(campaignId, userId) {
    await this.db.query('DELETE FROM edit_locks WHERE campaign_id = $1 AND user_id = $2', [campaignId, userId]);
  }

  // --- Campaign Creation (FR-01, FR-02) ---
  async createCampaign(user, data, correlationId) {
    if (user.role !== 'marketer' && user.role !== 'admin') {
      const err = new Error('Only marketers can create campaigns.');
      err.code = 'FORBIDDEN';
      err.status = 403;
      throw err;
    }

    const campaignId = this.generateId('camp');
    const versionId = this.generateId('ver');
    const versionNo = 1;
    const now = new Date().toISOString();

    const kpiProjected = data.kpi_projected || {
      conversionRate: 3.5,
      ctr: 4.2,
      roi: 3.8,
      cpa: 25.0,
      aov: 95.0
    };

    return await this.db.withTransaction(async (client) => {
      // 1. Insert Campaign
      await client.query(
        `INSERT INTO campaigns (campaign_id, title, owner_id, status, current_version_id, created_at, updated_at)
         VALUES ($1, $2, $3, 'Draft', $4, $5, $5)`,
        [campaignId, data.title, user.id, versionId, now]
      );

      // 2. Insert Initial Version Snapshot (Immutable)
      await client.query(
        `INSERT INTO campaign_versions 
         (version_id, campaign_id, version_no, title, objective, target_audience, channel, budget, kpi_projected, ai_summary, creatives, targeting, financials, compliance, ad_network, flight_phases, tracking, created_by, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19)`,
        [
          versionId,
          campaignId,
          versionNo,
          data.title,
          data.objective || 'Launch campaign',
          data.target_audience || 'Target demographics',
          data.channel || 'Social',
          data.budget || 10000.0,
          JSON.stringify(kpiProjected),
          data.ai_summary || null,
          JSON.stringify(data.creatives || []),
          JSON.stringify(data.targeting || {}),
          JSON.stringify(data.financials || {}),
          JSON.stringify(data.compliance || {}),
          JSON.stringify(data.ad_network || {}),
          JSON.stringify(data.flight_phases || []),
          JSON.stringify(data.tracking || {}),
          user.id,
          now
        ]
      );

      // 3. TimescaleDB Hypertable: Append-only Audit Trail
      const auditEventId = this.generateId('evt');
      await client.query(
        `INSERT INTO audit_events 
         (event_id, created_at, campaign_id, version_id, actor_id, actor_name, event_type, summary, details)
         VALUES ($1, $2, $3, $4, $5, $6, 'CAMPAIGN_CREATED', $7, $8)`,
        [
          auditEventId,
          now,
          campaignId,
          versionId,
          user.id,
          user.name,
          `Campaign "${data.title}" created with initial draft version v1.`,
          JSON.stringify({ budget: data.budget, channel: data.channel })
        ]
      );

      // 4. TimescaleDB Hypertable: Version History Snapshot
      const historyId = this.generateId('hist');
      await client.query(
        `INSERT INTO campaign_version_history 
         (history_id, created_at, campaign_id, version_id, version_no, snapshot, reason, actor_id)
         VALUES ($1, $2, $3, $4, $5, $6, 'Initial proposal draft', $7)`,
        [
          historyId,
          now,
          campaignId,
          versionId,
          versionNo,
          JSON.stringify({ title: data.title, budget: data.budget, channel: data.channel, kpi_projected: kpiProjected }),
          user.id
        ]
      );

      await this.diagnostics.log({
        correlationId,
        campaignId,
        versionId,
        eventType: DIAGNOSTIC_EVENTS.VERSION_CREATED,
        actorId: user.id,
        outcome: 'SUCCESS',
        message: `Campaign "${data.title}" created with initial version v1`
      });

      return {
        campaign_id: campaignId,
        title: data.title,
        owner_id: user.id,
        owner_name: user.name,
        status: 'Draft',
        current_version_id: versionId,
        version_no: versionNo,
        created_at: now,
        updated_at: now
      };
    });
  }

  // --- Campaign Update / Revisions (FR-02, FR-06, FR-14) ---
  async updateCampaign(campaignId, user, data, { expectedVersion, correlationId } = {}) {
    const campaign = await this.getCampaign(campaignId);
    if (!campaign) {
      const err = new Error('Campaign does not exist.');
      err.code = 'CAMPAIGN_NOT_FOUND';
      err.status = 404;
      throw err;
    }

    if (campaign.owner_id !== user.id && user.role !== 'admin') {
      const err = new Error('Only the campaign owner can edit this campaign.');
      err.code = 'FORBIDDEN';
      err.status = 403;
      throw err;
    }

    // Retrieve current version details
    const curVer = await this.getVersion(campaign.current_version_id);
    const currentVersionNo = curVer ? curVer.version_no : 1;

    // Optimistic Concurrency Check (FR-14)
    if (expectedVersion !== undefined && expectedVersion !== null) {
      if (Number(expectedVersion) !== currentVersionNo) {
        await this.diagnostics.log({
          correlationId,
          campaignId,
          versionId: campaign.current_version_id,
          eventType: DIAGNOSTIC_EVENTS.VERSION_CONFLICT,
          actorId: user.id,
          outcome: 'FAILURE',
          errorCategory: 'CONCURRENCY_ERROR',
          message: `Optimistic version conflict: expected version ${expectedVersion}, but current is v${currentVersionNo}`
        });

        const err = new Error(`Version conflict: Proposal was modified by another action. Expected v${expectedVersion}, current is v${currentVersionNo}.`);
        err.code = 'VERSION_CONFLICT';
        err.status = 409;
        throw err;
      }
    }

    const newVersionNo = currentVersionNo + 1;
    const newVersionId = this.generateId('ver');
    const now = new Date().toISOString();

    const title = data.title || curVer?.title || campaign.title;
    const objective = data.objective || curVer?.objective || 'Campaign objective';
    const targetAudience = data.target_audience || curVer?.target_audience || 'Target audience';
    const channel = data.channel || curVer?.channel || 'Social';
    const budget = data.budget !== undefined ? data.budget : (curVer?.budget || 10000.0);
    const kpiProjected = data.kpi_projected || (curVer?.kpi_projected ? (typeof curVer.kpi_projected === 'string' ? JSON.parse(curVer.kpi_projected) : curVer.kpi_projected) : { conversionRate: 3.5, ctr: 4.2, roi: 3.8, cpa: 25.0, aov: 95.0 });
    const aiSummary = data.ai_summary !== undefined ? data.ai_summary : curVer?.ai_summary;

    const curCreatives = data.creatives || curVer?.creatives || [];
    const curTargeting = data.targeting || curVer?.targeting || {};
    const curFinancials = data.financials || curVer?.financials || {};
    const curCompliance = data.compliance || curVer?.compliance || {};
    const curAdNetwork = data.ad_network || curVer?.ad_network || {};
    const curFlightPhases = data.flight_phases || curVer?.flight_phases || [];
    const curTracking = data.tracking || curVer?.tracking || {};

    return await this.db.withTransaction(async (client) => {
      // 1. Insert New Immutable Version Snapshot
      await client.query(
        `INSERT INTO campaign_versions 
         (version_id, campaign_id, version_no, title, objective, target_audience, channel, budget, kpi_projected, ai_summary, creatives, targeting, financials, compliance, ad_network, flight_phases, tracking, created_by, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19)`,
        [
          newVersionId,
          campaignId,
          newVersionNo,
          title,
          objective,
          targetAudience,
          channel,
          budget,
          JSON.stringify(kpiProjected),
          aiSummary,
          JSON.stringify(typeof curCreatives === 'string' ? JSON.parse(curCreatives) : curCreatives),
          JSON.stringify(typeof curTargeting === 'string' ? JSON.parse(curTargeting) : curTargeting),
          JSON.stringify(typeof curFinancials === 'string' ? JSON.parse(curFinancials) : curFinancials),
          JSON.stringify(typeof curCompliance === 'string' ? JSON.parse(curCompliance) : curCompliance),
          JSON.stringify(typeof curAdNetwork === 'string' ? JSON.parse(curAdNetwork) : curAdNetwork),
          JSON.stringify(typeof curFlightPhases === 'string' ? JSON.parse(curFlightPhases) : curFlightPhases),
          JSON.stringify(typeof curTracking === 'string' ? JSON.parse(curTracking) : curTracking),
          user.id,
          now
        ]
      );

      // 2. Update Campaign Pointer and Reset to Draft
      await client.query(
        `UPDATE campaigns 
         SET title = $1, current_version_id = $2, status = 'Draft', updated_at = $3
         WHERE campaign_id = $4`,
        [title, newVersionId, now, campaignId]
      );

      // 3. TimescaleDB Hypertable: Append-only Audit
      const auditEventId = this.generateId('evt');
      await client.query(
        `INSERT INTO audit_events 
         (event_id, created_at, campaign_id, version_id, actor_id, actor_name, event_type, summary, details)
         VALUES ($1, $2, $3, $4, $5, $6, 'VERSION_CREATED', $7, $8)`,
        [
          auditEventId,
          now,
          campaignId,
          newVersionId,
          user.id,
          user.name,
          `Created immutable version v${newVersionNo} for campaign "${title}".`,
          JSON.stringify({ previous_version: currentVersionNo, new_version: newVersionNo, budget, channel })
        ]
      );

      // 4. TimescaleDB Hypertable: Version History
      const histId = this.generateId('hist');
      await client.query(
        `INSERT INTO campaign_version_history 
         (history_id, created_at, campaign_id, version_id, version_no, snapshot, reason, actor_id)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [
          histId,
          now,
          campaignId,
          newVersionId,
          newVersionNo,
          JSON.stringify({ title, budget, channel, objective, kpiProjected }),
          data.reason || `Revised to version v${newVersionNo}`,
          user.id
        ]
      );

      await this.diagnostics.log({
        correlationId,
        campaignId,
        versionId: newVersionId,
        eventType: DIAGNOSTIC_EVENTS.VERSION_CREATED,
        actorId: user.id,
        outcome: 'SUCCESS',
        message: `Created immutable version v${newVersionNo} for campaign "${title}"`
      });

      return {
        campaign_id: campaignId,
        title,
        status: 'Draft',
        current_version_id: newVersionId,
        version_no: newVersionNo,
        updated_at: now
      };
    });
  }

  // --- Campaign Submission (FR-03, FR-16) ---
  async submitCampaign(campaignId, user, { idempotencyKey, correlationId } = {}) {
    const campaign = await this.getCampaign(campaignId);
    if (!campaign) {
      const err = new Error('Campaign does not exist.');
      err.code = 'CAMPAIGN_NOT_FOUND';
      err.status = 404;
      throw err;
    }

    if (campaign.owner_id !== user.id && user.role !== 'admin') {
      const err = new Error('Only the campaign owner can submit this proposal.');
      err.code = 'FORBIDDEN';
      err.status = 403;
      throw err;
    }

    const requestPayload = { campaignId, userId: user.id, versionId: campaign.current_version_id };
    const requestHash = this.hashPayload(requestPayload);

    // Idempotency check (FR-03, FR-16)
    if (idempotencyKey) {
      const existingKeyRes = await this.db.query(
        'SELECT * FROM idempotency_keys WHERE key = $1 AND user_id = $2',
        [idempotencyKey, user.id]
      );
      const existingKey = existingKeyRes.rows[0];

      if (existingKey) {
        if (existingKey.request_hash !== requestHash) {
          const err = new Error('Idempotency key reused with different request parameters.');
          err.code = 'IDEMPOTENCY_KEY_REUSED';
          err.status = 409;
          throw err;
        }
        // Return cached original response
        return typeof existingKey.response_body === 'string'
          ? JSON.parse(existingKey.response_body)
          : existingKey.response_body;
      }
    }

    const curVer = await this.getVersion(campaign.current_version_id);
    const now = new Date().toISOString();

    return await this.db.withTransaction(async (client) => {
      // 1. Update Campaign Status
      await client.query(
        `UPDATE campaigns 
         SET status = 'Submitted', updated_at = $1 
         WHERE campaign_id = $2`,
        [now, campaignId]
      );

      // 2. TimescaleDB Hypertable: Audit Trail
      const auditEventId = this.generateId('evt');
      await client.query(
        `INSERT INTO audit_events 
         (event_id, created_at, campaign_id, version_id, actor_id, actor_name, event_type, summary, details)
         VALUES ($1, $2, $3, $4, $5, $6, 'CAMPAIGN_SUBMITTED', $7, $8)`,
        [
          auditEventId,
          now,
          campaignId,
          campaign.current_version_id,
          user.id,
          user.name,
          `Campaign "${campaign.title}" (v${curVer?.version_no || 1}) submitted for review.`,
          JSON.stringify({ version_id: campaign.current_version_id, version_no: curVer?.version_no || 1 })
        ]
      );

      // 3. Queue Notification in Transactional Outbox
      const outboxId = this.generateId('outbox');
      const outboxPayload = {
        recipients: ['usr-reviewer-1', 'usr-reviewer-2'],
        campaign_id: campaignId,
        version_id: campaign.current_version_id,
        title: 'Campaign Submitted For Review',
        message: `${user.name} submitted "${campaign.title}" (v${curVer?.version_no || 1}) for formal review.`,
        correlation_id: correlationId
      };

      await client.query(
        `INSERT INTO outbox_events 
         (event_id, event_type, payload, status, created_at)
         VALUES ($1, 'APPROVAL_REQUESTED', $2, 'PENDING', $3)`,
        [outboxId, JSON.stringify(outboxPayload), now]
      );

      const responseData = {
        campaign_id: campaignId,
        status: 'Submitted',
        version_id: campaign.current_version_id,
        version_no: curVer?.version_no || 1,
        submitted_at: now
      };

      // 4. Save Idempotency Key
      if (idempotencyKey) {
        await client.query(
          `INSERT INTO idempotency_keys 
           (key, user_id, endpoint, request_hash, response_code, response_body, created_at)
           VALUES ($1, $2, $3, $4, 200, $5, $6)`,
          [idempotencyKey, user.id, '/api/campaigns/submit', requestHash, JSON.stringify(responseData), now]
        );
      }

      await this.diagnostics.log({
        correlationId,
        campaignId,
        versionId: campaign.current_version_id,
        eventType: DIAGNOSTIC_EVENTS.CAMPAIGN_SUBMITTED,
        actorId: user.id,
        outcome: 'SUCCESS',
        message: `Campaign "${campaign.title}" (v${curVer?.version_no || 1}) submitted for review`
      });

      return responseData;
    });
  }

  // --- Review Decisions (FR-01, FR-04, FR-05, FR-06) ---
  // Atomic commit: Decision + State Change + TimescaleDB Audit + Outbox Notification
  async makeDecision(campaignId, reviewer, { versionId, decision, reason, policyRef, correlationId } = {}) {
    if (reviewer.role !== 'reviewer' && reviewer.role !== 'admin') {
      const err = new Error('Only reviewers can record approval decisions.');
      err.code = 'FORBIDDEN';
      err.status = 403;
      throw err;
    }

    const campaign = await this.getCampaign(campaignId);
    if (!campaign) {
      const err = new Error('Campaign does not exist.');
      err.code = 'CAMPAIGN_NOT_FOUND';
      err.status = 404;
      throw err;
    }

    // Separation of Duties / Self-Approval Invariant (FR-01, Section 2.1)
    if (campaign.owner_id === reviewer.id) {
      await this.diagnostics.log({
        correlationId,
        campaignId,
        versionId,
        eventType: 'SELF_APPROVAL_VIOLATION',
        actorId: reviewer.id,
        outcome: 'FAILURE',
        errorCategory: 'AUTHORIZATION_ERROR',
        message: `Self-approval blocked: Reviewer ${reviewer.name} cannot approve own campaign ${campaignId}`
      });

      const err = new Error('Self-approval violation: You cannot approve or review a campaign you created.');
      err.code = 'FORBIDDEN';
      err.status = 403;
      throw err;
    }

    // Mandatory Non-Empty Reason Invariant (FR-05)
    if (!reason || reason.trim().length === 0) {
      const err = new Error('A non-empty mandatory justification reason is required for every review decision.');
      err.code = 'REASON_REQUIRED';
      err.status = 422;
      throw err;
    }

    // Verify version exists and belongs to this campaign
    const targetVersion = await this.getVersion(versionId);
    if (!targetVersion || targetVersion.campaign_id !== campaignId) {
      const err = new Error('Version does not belong to this campaign.');
      err.code = 'VERSION_MISMATCH';
      err.status = 422;
      throw err;
    }

    // Check if decision already recorded on this exact version (FR-05: Exactly one decision per version)
    const existingDecision = await this.getDecision(versionId);
    if (existingDecision) {
      const err = new Error(`Version v${targetVersion.version_no} has already been decided (${existingDecision.decision_type}).`);
      err.code = 'NOT_AWAITING_REVIEW';
      err.status = 409;
      throw err;
    }

    const decisionId = this.generateId('dec');
    const now = new Date().toISOString();

    let newCampaignStatus;
    let eventType;
    if (decision === 'APPROVED') {
      newCampaignStatus = 'Approved';
      eventType = DIAGNOSTIC_EVENTS.CAMPAIGN_APPROVED;
    } else if (decision === 'CHANGES_REQUESTED') {
      newCampaignStatus = 'ChangesRequested';
      eventType = DIAGNOSTIC_EVENTS.CHANGES_REQUESTED;
    } else if (decision === 'REJECTED') {
      newCampaignStatus = 'Rejected';
      eventType = DIAGNOSTIC_EVENTS.CAMPAIGN_REJECTED;
    } else {
      const err = new Error(`Invalid decision outcome: ${decision}`);
      err.code = 'INVALID_DECISION';
      err.status = 400;
      throw err;
    }

    // Single Atomic Transaction (PRD Invariant 9)
    return await this.db.withTransaction(async (client) => {
      // 1. Record Immutable Review Decision
      await client.query(
        `INSERT INTO approval_decisions 
         (decision_id, campaign_id, version_id, reviewer_id, decision_type, reason, policy_ref, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [decisionId, campaignId, versionId, reviewer.id, decision, reason.trim(), policyRef || null, now]
      );

      // 2. Update Campaign State
      await client.query(
        `UPDATE campaigns 
         SET status = $1, updated_at = $2 
         WHERE campaign_id = $3`,
        [newCampaignStatus, now, campaignId]
      );

      // 3. TimescaleDB Hypertable: Append-only Audit Trail
      const auditEventId = this.generateId('evt');
      await client.query(
        `INSERT INTO audit_events 
         (event_id, created_at, campaign_id, version_id, actor_id, actor_name, event_type, summary, details)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
        [
          auditEventId,
          now,
          campaignId,
          versionId,
          reviewer.id,
          reviewer.name,
          eventType,
          `Reviewer recorded ${decision} on v${targetVersion.version_no}: ${reason.trim()}`,
          JSON.stringify({ decision_id: decisionId, decision_type: decision, reason: reason.trim(), policy_ref: policyRef })
        ]
      );

      // 4. TimescaleDB Hypertable: Version History Snapshot
      const historyId = this.generateId('hist');
      await client.query(
        `INSERT INTO campaign_version_history 
         (history_id, created_at, campaign_id, version_id, version_no, snapshot, reason, actor_id)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [
          historyId,
          now,
          campaignId,
          versionId,
          targetVersion.version_no,
          JSON.stringify({
            title: targetVersion.title,
            budget: targetVersion.budget,
            channel: targetVersion.channel,
            decision: { decision_id: decisionId, decision_type: decision, reviewer: reviewer.name, reason: reason.trim() }
          }),
          `Decision ${decision}: ${reason.trim()}`,
          reviewer.id
        ]
      );

      // 5. Transactional Outbox Event (Survives Provider Outages)
      const outboxId = this.generateId('outbox');
      const outboxPayload = {
        recipients: [campaign.owner_id],
        campaign_id: campaignId,
        version_id: versionId,
        title: `Proposal ${decision === 'APPROVED' ? 'Approved' : decision === 'CHANGES_REQUESTED' ? 'Changes Requested' : 'Rejected'}`,
        message: `${reviewer.name} marked v${targetVersion.version_no} as ${decision}. Reason: "${reason.trim()}"`,
        correlation_id: correlationId
      };

      await client.query(
        `INSERT INTO outbox_events 
         (event_id, event_type, payload, status, created_at)
         VALUES ($1, $2, $3, 'PENDING', $4)`,
        [outboxId, eventType, JSON.stringify(outboxPayload), now]
      );

      await this.diagnostics.log({
        correlationId,
        campaignId,
        versionId,
        eventType,
        actorId: reviewer.id,
        outcome: 'SUCCESS',
        message: `Reviewer recorded ${decision} on v${targetVersion.version_no}: ${reason.trim()}`
      });

      return {
        decision_id: decisionId,
        campaign_id: campaignId,
        version_id: versionId,
        version_no: targetVersion.version_no,
        decision_type: decision,
        reason: reason.trim(),
        reviewer_id: reviewer.id,
        reviewer_name: reviewer.name,
        created_at: now
      };
    });
  }

  // --- Campaign Scheduling (FR-07, FR-08) ---
  // Atomic validation: Current Approved Version + Conflict Detection inside transaction
  async scheduleCampaign(campaignId, user, { versionId, channel, startsAt, endsAt, correlationId } = {}) {
    const campaign = await this.getCampaign(campaignId);
    if (!campaign) {
      const err = new Error('Campaign does not exist.');
      err.code = 'CAMPAIGN_NOT_FOUND';
      err.status = 404;
      throw err;
    }

    if (campaign.owner_id !== user.id && user.role !== 'admin') {
      const err = new Error('Only the campaign owner can schedule this campaign.');
      err.code = 'FORBIDDEN';
      err.status = 403;
      throw err;
    }

    const start = new Date(startsAt);
    const end = new Date(endsAt);
    if (isNaN(start.getTime()) || isNaN(end.getTime()) || end <= start) {
      const err = new Error('Invalid schedule window: end date must be strictly after start date.');
      err.code = 'INVALID_DATES';
      err.status = 400;
      throw err;
    }

    return await this.db.withTransaction(async (client) => {
      // 1. Lock campaign row and verify current version
      const lockRes = await client.query('SELECT * FROM campaigns WHERE campaign_id = $1 FOR UPDATE', [campaignId]);
      const lockedCampaign = lockRes.rows[0];

      if (lockedCampaign.current_version_id !== versionId) {
        await this.diagnostics.log({
          correlationId,
          campaignId,
          versionId,
          eventType: DIAGNOSTIC_EVENTS.SCHEDULE_BLOCKED,
          actorId: user.id,
          outcome: 'FAILURE',
          errorCategory: 'OUTDATED_VERSION',
          message: `Scheduling blocked: Version ${versionId} is superseded. Current active version is ${lockedCampaign.current_version_id}.`
        });

        const err = new Error(`Scheduling blocked: Version v${versionId} is no longer current. A superseded version cannot be scheduled.`);
        err.code = 'SCHEDULE_BLOCKED';
        err.status = 409;
        throw err;
      }

      // 2. Authoritative Approval Verification inside Transaction (FR-07 Invariant)
      const decisionRes = await client.query(
        'SELECT * FROM approval_decisions WHERE version_id = $1',
        [versionId]
      );
      const decision = decisionRes.rows[0];

      const verRes = await client.query('SELECT * FROM campaign_versions WHERE version_id = $1', [versionId]);
      const ver = verRes.rows[0];

      if (!decision || decision.decision_type !== 'APPROVED') {
        await this.diagnostics.log({
          correlationId,
          campaignId,
          versionId,
          eventType: DIAGNOSTIC_EVENTS.SCHEDULE_BLOCKED,
          actorId: user.id,
          outcome: 'FAILURE',
          errorCategory: 'UNAPPROVED_VERSION',
          message: `Scheduling blocked: Version v${ver?.version_no || '?'} has not been approved.`
        });

        const err = new Error(`Scheduling blocked: Version v${ver?.version_no || '?'} has not received an APPROVED decision.`);
        err.code = 'SCHEDULE_BLOCKED';
        err.status = 409;
        throw err;
      }

      // 3. Calendar Conflict Detection (FR-08)
      const conflictRes = await client.query(
        `SELECT s.*, c.title 
         FROM schedules s 
         JOIN campaigns c ON s.campaign_id = c.campaign_id 
         WHERE s.channel = $1 
           AND s.status = 'ACTIVE' 
           AND s.campaign_id != $2
           AND s.starts_at < $3 
           AND s.ends_at > $4`,
        [channel, campaignId, end.toISOString(), start.toISOString()]
      );

      if (conflictRes.rows.length > 0) {
        const conflict = conflictRes.rows[0];
        const err = new Error(`Scheduling conflict: Channel "${channel}" is already booked by "${conflict.title}" during this flight window.`);
        err.code = 'SCHEDULING_CONFLICT';
        err.status = 409;
        throw err;
      }

      const scheduleId = this.generateId('sched');
      const now = new Date().toISOString();

      // 4. Insert Schedule Record
      await client.query(
        `INSERT INTO schedules 
         (schedule_id, campaign_id, version_id, decision_id, channel, starts_at, ends_at, status, created_by, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, 'ACTIVE', $8, $9)`,
        [scheduleId, campaignId, versionId, decision.decision_id, channel, start.toISOString(), end.toISOString(), user.id, now]
      );

      // 5. Update Campaign State
      await client.query(
        `UPDATE campaigns 
         SET status = 'Scheduled', updated_at = $1 
         WHERE campaign_id = $2`,
        [now, campaignId]
      );

      // 6. TimescaleDB Hypertable: Audit Trail
      const auditEventId = this.generateId('evt');
      await client.query(
        `INSERT INTO audit_events 
         (event_id, created_at, campaign_id, version_id, actor_id, actor_name, event_type, summary, details)
         VALUES ($1, $2, $3, $4, $5, $6, 'CAMPAIGN_SCHEDULED', $7, $8)`,
        [
          auditEventId,
          now,
          campaignId,
          versionId,
          user.id,
          user.name,
          `Campaign "${campaign.title}" (v${ver?.version_no}) scheduled for ${channel} flight.`,
          JSON.stringify({ schedule_id: scheduleId, channel, starts_at: startsAt, ends_at: endsAt })
        ]
      );

      // 7. Transactional Outbox
      const outboxId = this.generateId('outbox');
      await client.query(
        `INSERT INTO outbox_events 
         (event_id, event_type, payload, status, created_at)
         VALUES ($1, 'CAMPAIGN_SCHEDULED', $2, 'PENDING', $3)`,
        [
          outboxId,
          JSON.stringify({
            recipients: [campaign.owner_id, decision.reviewer_id],
            campaign_id: campaignId,
            version_id: versionId,
            title: 'Campaign Flight Scheduled',
            message: `"${campaign.title}" is officially scheduled on ${channel} from ${start.toLocaleDateString()} to ${end.toLocaleDateString()}.`
          }),
          now
        ]
      );

      await this.diagnostics.log({
        correlationId,
        campaignId,
        versionId,
        eventType: DIAGNOSTIC_EVENTS.CAMPAIGN_SCHEDULED,
        actorId: user.id,
        outcome: 'SUCCESS',
        message: `Campaign "${campaign.title}" (v${ver?.version_no}) scheduled successfully on ${channel}`
      });

      return {
        schedule_id: scheduleId,
        campaign_id: campaignId,
        version_id: versionId,
        version_no: ver?.version_no,
        channel,
        starts_at: start.toISOString(),
        ends_at: end.toISOString(),
        status: 'ACTIVE',
        created_at: now
      };
    });
  }

  parseJsonField(val, fallback) {
    if (!val) return fallback;
    if (typeof val === 'string') {
      try { return JSON.parse(val); } catch (_) { return fallback; }
    }
    return val;
  }

  // --- Campaign Details & Queries ---
  async getCampaignDetails(campaignId) {
    const campaignRes = await this.db.query(
      `SELECT c.*, u.name as owner_name, u.email as owner_email
       FROM campaigns c 
       JOIN users u ON c.owner_id = u.user_id 
       WHERE c.campaign_id = $1`,
      [campaignId]
    );
    const campaign = campaignRes.rows[0];
    if (!campaign) return null;

    const curVerRes = await this.db.query(
      'SELECT * FROM campaign_versions WHERE version_id = $1',
      [campaign.current_version_id]
    );
    const curVer = curVerRes.rows[0] || null;

    const versionsRes = await this.db.query(
      `SELECT v.*, d.decision_type, d.reason as decision_reason, d.created_at as decided_at, u.name as reviewer_name
       FROM campaign_versions v
       LEFT JOIN approval_decisions d ON v.version_id = d.version_id
       LEFT JOIN users u ON d.reviewer_id = u.user_id
       WHERE v.campaign_id = $1
       ORDER BY v.version_no ASC`,
      [campaignId]
    );

    const scheduleRes = await this.db.query(
      'SELECT * FROM schedules WHERE campaign_id = $1 AND status = \'ACTIVE\' ORDER BY created_at DESC LIMIT 1',
      [campaignId]
    );

    return {
      ...campaign,
      currentVersion: curVer ? {
        ...curVer,
        kpi_projected: this.parseJsonField(curVer.kpi_projected, {}),
        kpi_actual: this.parseJsonField(curVer.kpi_actual, null),
        creatives: this.parseJsonField(curVer.creatives, []),
        targeting: this.parseJsonField(curVer.targeting, {}),
        financials: this.parseJsonField(curVer.financials, {}),
        compliance: this.parseJsonField(curVer.compliance, {}),
        ad_network: this.parseJsonField(curVer.ad_network, {}),
        flight_phases: this.parseJsonField(curVer.flight_phases, []),
        tracking: this.parseJsonField(curVer.tracking, {})
      } : null,
      versions: versionsRes.rows.map(v => ({
        ...v,
        kpi_projected: this.parseJsonField(v.kpi_projected, {}),
        kpi_actual: this.parseJsonField(v.kpi_actual, null),
        creatives: this.parseJsonField(v.creatives, []),
        targeting: this.parseJsonField(v.targeting, {}),
        financials: this.parseJsonField(v.financials, {}),
        compliance: this.parseJsonField(v.compliance, {}),
        ad_network: this.parseJsonField(v.ad_network, {}),
        flight_phases: this.parseJsonField(v.flight_phases, []),
        tracking: this.parseJsonField(v.tracking, {})
      })),
      schedule: scheduleRes.rows[0] || null
    };
  }

  async listCampaigns({ status, channel, owner_id } = {}) {
    let sql = `
      SELECT c.*, u.name as owner_name, v.version_no, v.channel, v.budget, v.objective, v.target_audience, v.kpi_projected,
             v.financials, v.compliance, v.ad_network, v.creatives, v.flight_phases
      FROM campaigns c
      JOIN users u ON c.owner_id = u.user_id
      LEFT JOIN campaign_versions v ON c.current_version_id = v.version_id
    `;
    const params = [];
    const conditions = [];

    if (status && status !== 'All') {
      params.push(status);
      conditions.push(`c.status = $${params.length}`);
    }
    if (channel && channel !== 'All') {
      params.push(channel);
      conditions.push(`v.channel = $${params.length}`);
    }
    if (owner_id) {
      params.push(owner_id);
      conditions.push(`c.owner_id = $${params.length}`);
    }

    if (conditions.length > 0) {
      sql += ' WHERE ' + conditions.join(' AND ');
    }

    sql += ' ORDER BY c.updated_at DESC';

    const res = await this.db.query(sql, params);
    return res.rows.map(row => ({
      campaign_id: row.campaign_id,
      title: row.title,
      owner_id: row.owner_id,
      owner_name: row.owner_name,
      status: row.status,
      current_version_id: row.current_version_id,
      created_at: row.created_at,
      updated_at: row.updated_at,
      currentVersion: row.current_version_id ? {
        version_id: row.current_version_id,
        version_no: row.version_no,
        title: row.title,
        channel: row.channel,
        budget: Number(row.budget),
        objective: row.objective,
        target_audience: row.target_audience,
        kpi_projected: this.parseJsonField(row.kpi_projected, {}),
        financials: this.parseJsonField(row.financials, {}),
        compliance: this.parseJsonField(row.compliance, {}),
        ad_network: this.parseJsonField(row.ad_network, {}),
        creatives: this.parseJsonField(row.creatives, []),
        flight_phases: this.parseJsonField(row.flight_phases, [])
      } : null
    }));
  }

  // --- Calendar & Schedules (FR-07, FR-08) ---
  async getCalendarEvents() {
    const res = await this.db.query(
      `SELECT s.*, c.title, c.status as campaign_status, u.name as owner_name, v.version_no, v.budget
       FROM schedules s
       JOIN campaigns c ON s.campaign_id = c.campaign_id
       JOIN users u ON c.owner_id = u.user_id
       JOIN campaign_versions v ON s.version_id = v.version_id
       WHERE s.status = 'ACTIVE'
       ORDER BY s.starts_at ASC`
    );
    return res.rows;
  }

  // --- TimescaleDB Hypertable Queries (FR-15) ---
  async getAuditTrail(campaignId) {
    const res = await this.db.query(
      `SELECT * FROM audit_events 
       WHERE campaign_id = $1 
       ORDER BY created_at DESC`,
      [campaignId]
    );
    return res.rows;
  }

  // --- TimescaleDB Hypertable Version History (FR-06) ---
  async getVersionHistory(campaignId) {
    const res = await this.db.query(
      `SELECT h.*, d.decision_type, d.reason as decision_reason, u.name as reviewer_name
       FROM campaign_version_history h
       LEFT JOIN approval_decisions d ON h.version_id = d.version_id
       LEFT JOIN users u ON d.reviewer_id = u.user_id
       WHERE h.campaign_id = $1
       ORDER BY h.created_at ASC`,
      [campaignId]
    );
    return res.rows;
  }

  // --- Collaboration: Discussions & Mentions (FR-12) ---
  async getCollaborators(campaignId) {
    const res = await this.db.query(
      `SELECT user_id, name, role, email FROM users ORDER BY name ASC`
    );
    return res.rows;
  }

  async getDiscussions(campaignId, { versionId, user } = {}) {
    let sql = `
      SELECT d.*, u.name as author_name, u.role as author_role, u.email as author_email,
             v.version_no as anchored_version_no
      FROM discussions d 
      JOIN users u ON d.user_id = u.user_id 
      LEFT JOIN campaign_versions v ON d.version_id = v.version_id
      WHERE d.campaign_id = $1
    `;
    const params = [campaignId];

    if (versionId) {
      params.push(versionId);
      sql += ` AND d.version_id = $${params.length}`;
    }

    // Privacy rule (ADR-008 / F-15):
    // Marketers cannot see is_internal_only notes created by reviewers
    if (user && user.role === 'marketer') {
      sql += ` AND d.is_internal_only = FALSE`;
    }

    sql += ` ORDER BY d.created_at ASC`;

    const res = await this.db.query(sql, params);
    return res.rows.map(r => ({
      ...r,
      mentions: typeof r.mentions === 'string' ? JSON.parse(r.mentions) : (r.mentions || [])
    }));
  }

  async postDiscussionMessage(campaignId, user, { content, parentMessageId, versionId, isInternalOnly = false }) {
    if (!content || content.trim().length === 0) {
      throw new Error('Message content cannot be blank.');
    }
    const messageId = this.generateId('msg');
    const now = new Date().toISOString();

    // 1. Verify parent message if replying
    if (parentMessageId) {
      const parentCheck = await this.db.query(
        `SELECT message_id, is_internal_only FROM discussions WHERE message_id = $1 AND campaign_id = $2`,
        [parentMessageId, campaignId]
      );
      if (parentCheck.rowCount === 0) {
        const err = new Error('Parent discussion thread does not exist.');
        err.status = 404;
        throw err;
      }
      if (parentCheck.rows[0].is_internal_only) {
        isInternalOnly = true;
      }
    }

    // 2. Verify version anchor if provided
    let versionNo = null;
    if (versionId) {
      const vRes = await this.db.query(
        `SELECT version_id, version_no FROM campaign_versions WHERE version_id = $1 AND campaign_id = $2`,
        [versionId, campaignId]
      );
      if (vRes.rowCount > 0) {
        versionNo = vRes.rows[0].version_no;
      }
    }

    // 3. Marketers cannot create internal-only notes
    if (isInternalOnly && user.role === 'marketer') {
      isInternalOnly = false;
    }

    // 4. Extract @mentions
    const allUsersRes = await this.db.query(`SELECT user_id, name, role FROM users`);
    const allUsers = allUsersRes.rows;
    const mentionedUserIds = [];

    const lowerContent = content.toLowerCase();
    for (const u of allUsers) {
      const firstName = u.name.split(' ')[0].toLowerCase();
      const fullName = u.name.toLowerCase();
      if (
        lowerContent.includes(`@${fullName}`) ||
        lowerContent.includes(`@${firstName}`) ||
        lowerContent.includes(`@${u.user_id.toLowerCase()}`) ||
        (u.role === 'reviewer' && lowerContent.includes('@reviewer')) ||
        (u.role === 'marketer' && lowerContent.includes('@marketer'))
      ) {
        if (!mentionedUserIds.includes(u.user_id) && u.user_id !== user.id) {
          mentionedUserIds.push(u.user_id);
        }
      }
    }

    // 5. Insert into discussions
    await this.db.query(
      `INSERT INTO discussions (
        message_id, campaign_id, user_id, content, parent_message_id,
        version_id, version_no, mentions, is_internal_only, created_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
      [
        messageId,
        campaignId,
        user.id,
        content.trim(),
        parentMessageId || null,
        versionId || null,
        versionNo,
        JSON.stringify(mentionedUserIds),
        isInternalOnly,
        now
      ]
    );

    // 6. Dispatch notifications to mentioned users
    for (const recipientId of mentionedUserIds) {
      const notifId = this.generateId('notif');
      const snippet = content.length > 70 ? `${content.substring(0, 67)}...` : content;
      await this.db.query(
        `INSERT INTO notifications (notification_id, recipient_id, campaign_id, event_type, title, body, is_read, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [
          notifId,
          recipientId,
          campaignId,
          'MENTION',
          `${user.name} mentioned you in a discussion`,
          snippet,
          false,
          now
        ]
      );
    }

    return {
      message_id: messageId,
      campaign_id: campaignId,
      parent_message_id: parentMessageId || null,
      version_id: versionId || null,
      version_no: versionNo,
      author_id: user.id,
      author_name: user.name,
      author_role: user.role,
      content: content.trim(),
      mentions: mentionedUserIds,
      is_internal_only: isInternalOnly,
      created_at: now
    };
  }

  // --- Analytics & 5 KPIs with TimescaleDB time_bucket (FR-09) ---
  async getAnalytics({ channel, startDate, endDate, bucketInterval = '1 day' } = {}) {
    const now = new Date();
    const end = endDate ? new Date(endDate) : now;
    const start = startDate ? new Date(startDate) : new Date(now.getTime() - 30 * 86400000);

    const channelFilter = (channel && channel !== 'All') ? channel : null;

    // 1. Channel breakdown & totals
    let sql = `
      SELECT v.channel, COUNT(c.campaign_id) as total_campaigns, SUM(v.budget) as total_budget,
             AVG((v.kpi_projected->>'conversionRate')::numeric) as avg_conv_rate,
             AVG((v.kpi_projected->>'ctr')::numeric) as avg_ctr,
             AVG((v.kpi_projected->>'roi')::numeric) as avg_roi,
             AVG((v.kpi_projected->>'cpa')::numeric) as avg_cpa,
             AVG((v.kpi_projected->>'aov')::numeric) as avg_aov
      FROM campaigns c
      JOIN campaign_versions v ON c.current_version_id = v.version_id
    `;
    const params = [];
    if (channelFilter) {
      params.push(channelFilter);
      sql += ' WHERE v.channel = $1';
    }
    sql += ' GROUP BY v.channel';

    const res = await this.db.query(sql, params);

    // 2. Summary query
    const overallRes = await this.db.query(`
      SELECT COUNT(c.campaign_id) as count, COALESCE(SUM(v.budget), 0) as total_budget,
             COALESCE(AVG((v.kpi_projected->>'conversionRate')::numeric), 3.8) as avg_conv,
             COALESCE(AVG((v.kpi_projected->>'ctr')::numeric), 4.5) as avg_ctr,
             COALESCE(AVG((v.kpi_projected->>'roi')::numeric), 4.1) as avg_roi,
             COALESCE(AVG((v.kpi_projected->>'cpa')::numeric), 24.5) as avg_cpa,
             COALESCE(AVG((v.kpi_projected->>'aov')::numeric), 110.0) as avg_aov
      FROM campaigns c
      JOIN campaign_versions v ON c.current_version_id = v.version_id
      ${channelFilter ? 'WHERE v.channel = $1' : ''}
    `, channelFilter ? [channelFilter] : []);

    const summary = overallRes.rows[0];

    // Query actual volume and formulaic rates from kpi_metric_snapshots
    const actualSnapshotsRes = await this.db.query(`
      SELECT 
        COALESCE(SUM(impressions), 0)::numeric as total_impressions,
        COALESCE(SUM(clicks), 0)::numeric as total_clicks,
        COALESCE(SUM(spend), 0)::numeric as total_spend,
        COALESCE(SUM(conversions), 0)::numeric as total_conversions,
        COALESCE(SUM(revenue), 0)::numeric as total_revenue,
        CASE WHEN SUM(impressions) > 0 THEN ROUND((SUM(clicks)::numeric / SUM(impressions)::numeric) * 100, 2) ELSE 5.2 END as actual_ctr,
        CASE WHEN SUM(clicks) > 0 THEN ROUND((SUM(conversions)::numeric / SUM(clicks)::numeric) * 100, 2) ELSE 4.8 END as actual_conv,
        CASE WHEN SUM(conversions) > 0 THEN ROUND((SUM(spend)::numeric / SUM(conversions)::numeric), 2) ELSE 21.0 END as actual_cpa,
        CASE WHEN SUM(spend) > 0 THEN ROUND((SUM(revenue)::numeric / SUM(spend)::numeric), 2) ELSE 5.0 END as actual_roi,
        CASE WHEN SUM(conversions) > 0 THEN ROUND((SUM(revenue)::numeric / SUM(conversions)::numeric), 2) ELSE 140.0 END as actual_aov
      FROM kpi_metric_snapshots
      WHERE recorded_at >= $1 AND recorded_at <= $2
      ${channelFilter ? 'AND channel = $3' : ''}
    `, channelFilter ? [start.toISOString(), end.toISOString(), channelFilter] : [start.toISOString(), end.toISOString()]);

    const actuals = actualSnapshotsRes.rows[0];

    // 3. TimescaleDB continuous time-series aggregation query (time_bucket)
    let timeBucketSql = `
      SELECT
        time_bucket($1::interval, recorded_at) AS bucket,
        is_actual,
        ROUND(AVG(conversion_rate)::numeric, 2) AS avg_conversion_rate,
        ROUND(AVG(ctr)::numeric, 2) AS avg_ctr,
        ROUND(AVG(roi)::numeric, 2) AS avg_roi,
        ROUND(AVG(cpa)::numeric, 2) AS avg_cpa,
        ROUND(AVG(aov)::numeric, 2) AS avg_aov
      FROM kpi_metric_snapshots
      WHERE recorded_at >= $2 AND recorded_at <= $3
    `;
    const bucketParams = [bucketInterval, start.toISOString(), end.toISOString()];
    if (channelFilter) {
      bucketParams.push(channelFilter);
      timeBucketSql += ' AND channel = $4';
    }
    timeBucketSql += `
      GROUP BY bucket, is_actual
      ORDER BY bucket ASC, is_actual ASC
    `;

    let timeBucketRows = [];
    try {
      const bucketRes = await this.db.query(timeBucketSql, bucketParams);
      timeBucketRows = bucketRes.rows;
    } catch (_) {
      // Hypertable query fallback
    }

    // Map time buckets into coherent trend points
    const trendMap = new Map();
    for (const r of timeBucketRows) {
      const bucketKey = new Date(r.bucket).toISOString().substring(0, 10);
      if (!trendMap.has(bucketKey)) {
        trendMap.set(bucketKey, {
          date: bucketKey,
          projected: { conversionRate: 0, ctr: 0, roi: 0, cpa: 0, aov: 0 },
          actual: { conversionRate: 0, ctr: 0, roi: 0, cpa: 0, aov: 0 }
        });
      }
      const entry = trendMap.get(bucketKey);
      const metrics = {
        conversionRate: Number(r.avg_conversion_rate),
        ctr: Number(r.avg_ctr),
        roi: Number(r.avg_roi),
        cpa: Number(r.avg_cpa),
        aov: Number(r.avg_aov)
      };
      if (r.is_actual) {
        entry.actual = metrics;
      } else {
        entry.projected = metrics;
      }
    }

    const trends = Array.from(trendMap.values());

    return {
      dateRange: {
        startDate: start.toISOString().substring(0, 10),
        endDate: end.toISOString().substring(0, 10),
        interval: bucketInterval
      },
      summary: {
        totalCampaigns: Number(summary.count),
        totalBudget: Number(summary.total_budget),
        kpis: {
          conversionRate: { name: 'Conversion Rate', unit: '%', projected: Number(Number(summary.avg_conv).toFixed(2)), actual: Number(actuals.actual_conv) },
          ctr: { name: 'Click-Through Rate', unit: '%', projected: Number(Number(summary.avg_ctr).toFixed(2)), actual: Number(actuals.actual_ctr) },
          roi: { name: 'Return on Investment', unit: 'x', projected: Number(Number(summary.avg_roi).toFixed(2)), actual: Number(actuals.actual_roi) },
          cpa: { name: 'Cost Per Acquisition', unit: '$', projected: Number(Number(summary.avg_cpa).toFixed(2)), actual: Number(actuals.actual_cpa) },
          aov: { name: 'Average Order Value', unit: '$', projected: Number(Number(summary.avg_aov).toFixed(2)), actual: Number(actuals.actual_aov) }
        }
      },
      aggregates: {
        impressions: Number(actuals.total_impressions),
        clicks: Number(actuals.total_clicks),
        spend: Number(actuals.total_spend),
        conversions: Number(actuals.total_conversions),
        revenue: Number(actuals.total_revenue),
        ctr: Number(actuals.actual_ctr),
        conversionRate: Number(actuals.actual_conv),
        cpa: Number(actuals.actual_cpa),
        roi: Number(actuals.actual_roi),
        aov: Number(actuals.actual_aov)
      },
      channelBreakdown: res.rows.map(r => ({
        channel: r.channel,
        campaigns: Number(r.total_campaigns),
        budget: Number(r.total_budget)
      })),
      trends
    };
  }

  // --- Offline Mobile Sync Queue Processor (FR-13, FR-14, ADR-005) ---
  async processSyncQueue(user, actions = [], { correlationId } = {}) {
    const corr = correlationId || this.generateId('corr');
    const results = [];

    for (const action of actions) {
      const { action_id, idempotency_key, action_type, payload = {} } = action;
      try {
        let responseData = null;

        // 1. Check idempotency store for existing result
        if (idempotency_key) {
          const cached = await this.db.query(
            'SELECT response_code, response_body FROM idempotency_keys WHERE key = $1 AND user_id = $2',
            [idempotency_key, user.id]
          );
          if (cached.rows.length > 0) {
            results.push({
              action_id,
              idempotency_key,
              status: 'SYNCED',
              is_replay: true,
              response_code: cached.rows[0].response_code,
              data: cached.rows[0].response_body
            });
            continue;
          }
        }

        // 2. Dispatch action
        switch (action_type) {
          case 'CREATE_CAMPAIGN': {
            responseData = await this.createCampaign(user, payload, corr);
            break;
          }
          case 'UPDATE_CAMPAIGN':
          case 'SAVE_DRAFT': {
            const { campaign_id, expected_version, ...updateData } = payload;
            responseData = await this.updateCampaign(campaign_id, user, updateData, {
              expectedVersion: expected_version,
              correlationId: corr
            });
            break;
          }
          case 'SUBMIT_CAMPAIGN': {
            const { campaign_id } = payload;
            responseData = await this.submitCampaign(campaign_id, user, {
              idempotencyKey: idempotency_key,
              correlationId: corr
            });
            break;
          }
          case 'MAKE_DECISION': {
            const { campaign_id, version_id, decision, reason, policy_reference } = payload;
            responseData = await this.makeDecision(campaign_id, user, {
              versionId: version_id,
              decision,
              reason,
              policyRef: policy_reference,
              correlationId: corr
            });
            break;
          }
          case 'SCHEDULE_CAMPAIGN': {
            const { campaign_id, version_id, channel, starts_at, ends_at } = payload;
            responseData = await this.scheduleCampaign(campaign_id, user, {
              versionId: version_id,
              channel,
              startsAt: starts_at,
              endsAt: ends_at,
              correlationId: corr
            });
            break;
          }
          case 'POST_DISCUSSION': {
            const { campaign_id, content, parent_message_id, version_id, is_internal_only } = payload;
            responseData = await this.postDiscussionMessage(campaign_id, user, {
              content,
              parentMessageId: parent_message_id,
              versionId: version_id,
              isInternalOnly: is_internal_only
            });
            break;
          }
          default:
            throw new Error(`Unsupported sync action_type: ${action_type}`);
        }

        // 3. Cache response in idempotency store
        if (idempotency_key && responseData) {
          try {
            await this.db.query(
              `INSERT INTO idempotency_keys (key, user_id, endpoint, request_hash, response_code, response_body, created_at)
               VALUES ($1, $2, $3, $4, 200, $5, NOW())
               ON CONFLICT (key) DO NOTHING`,
              [
                idempotency_key,
                user.id,
                `/api/sync/${action_type.toLowerCase()}`,
                crypto.createHash('sha256').update(JSON.stringify(payload)).digest('hex'),
                JSON.stringify(responseData)
              ]
            );
          } catch (_) {}
        }

        results.push({
          action_id,
          idempotency_key,
          status: 'SYNCED',
          is_replay: false,
          response_code: 200,
          data: responseData
        });
      } catch (err) {
        results.push({
          action_id,
          idempotency_key,
          status: 'FAILED',
          response_code: err.status || err.statusCode || 400,
          error: {
            code: err.code || 'SYNC_ACTION_FAILED',
            message: err.message
          }
        });
      }
    }

    return {
      correlation_id: corr,
      processed: results.length,
      synced: results.filter(r => r.status === 'SYNCED').length,
      failed: results.filter(r => r.status === 'FAILED').length,
      results
    };
  }
}
