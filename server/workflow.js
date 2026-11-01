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

  getUser(userId) {
    return this.db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
  }

  getCampaign(campaignId) {
    return this.db.prepare('SELECT * FROM campaigns WHERE campaign_id = ?').get(campaignId);
  }

  getVersion(versionId) {
    return this.db.prepare('SELECT * FROM campaign_versions WHERE version_id = ?').get(versionId);
  }

  getDecision(versionId) {
    return this.db.prepare('SELECT * FROM approval_decisions WHERE version_id = ?').get(versionId);
  }

  // --- Concurrency / Edit Leases ---
  acquireEditLock(campaignId, user, correlationId) {
    const now = new Date();
    const expiresAt = new Date(now.getTime() + this.lockTtlSeconds * 1000).toISOString();
    const nowIso = now.toISOString();

    const existingLock = this.db.prepare('SELECT * FROM edit_locks WHERE campaign_id = ?').get(campaignId);

    if (existingLock) {
      if (existingLock.expires_at > nowIso && existingLock.holder_id !== user.id) {
        // Active lock held by someone else
        return {
          granted: false,
          holder_id: existingLock.holder_id,
          holder_name: existingLock.holder_name,
          expires_at: existingLock.expires_at,
          message: `Campaign is currently locked by ${existingLock.holder_name} until ${new Date(existingLock.expires_at).toLocaleTimeString()}`
        };
      }

      if (existingLock.expires_at <= nowIso && existingLock.holder_id !== user.id) {
        // Stale lock expired
        this.diagnostics.log({
          correlationId,
          campaignId,
          eventType: DIAGNOSTIC_EVENTS.EDIT_LOCK_EXPIRED,
          actorId: existingLock.holder_id,
          outcome: 'INFO',
          message: `Edit lock for campaign ${campaignId} expired from ${existingLock.holder_name}`
        });
      }

      // Renew or takeover expired lock
      this.db.prepare(`
        UPDATE edit_locks 
        SET holder_id = ?, holder_name = ?, acquired_at = ?, expires_at = ?
        WHERE campaign_id = ?
      `).run(user.id, user.name, nowIso, expiresAt, campaignId);
    } else {
      this.db.prepare(`
        INSERT INTO edit_locks (campaign_id, holder_id, holder_name, acquired_at, expires_at)
        VALUES (?, ?, ?, ?, ?)
      `).run(campaignId, user.id, user.name, nowIso, expiresAt);
    }

    this.diagnostics.log({
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

  releaseEditLock(campaignId, userId) {
    const lock = this.db.prepare('SELECT * FROM edit_locks WHERE campaign_id = ?').get(campaignId);
    if (lock && (lock.holder_id === userId || lock.expires_at <= new Date().toISOString())) {
      this.db.prepare('DELETE FROM edit_locks WHERE campaign_id = ?').run(campaignId);
      return true;
    }
    return false;
  }

  // --- Campaign Creation ---
  createCampaign(user, data, correlationId = null) {
    if (!user || user.role !== 'marketer') {
      const err = new Error('Only marketers can create campaigns.');
      err.code = 'FORBIDDEN';
      err.status = 403;
      throw err;
    }

    const campaignId = this.generateId('camp');
    const versionId = this.generateId('ver-v1');
    const now = new Date().toISOString();
    const corrId = correlationId || null;

    const title = data.title?.trim() || 'Untitled Campaign';
    const objective = data.objective?.trim() || 'Accelerate conversion and pipeline growth';
    const targetAudience = data.target_audience?.trim() || 'Target Marketing Segment';
    const channel = data.channel || 'Social';
    const budget = Number(data.budget) || 10000;
    const kpiProjected = JSON.stringify(data.kpi_projected || {
      conversionRate: 3.5,
      ctr: 4.2,
      roi: 3.8,
      cpa: 25.0,
      aov: 95.0
    });
    const aiSummary = data.ai_summary || null;

    const snapshot = JSON.stringify({
      version_no: 1,
      title,
      objective,
      target_audience: targetAudience,
      channel,
      budget,
      kpi_projected: JSON.parse(kpiProjected),
      ai_summary: aiSummary
    });

    // Execute in transaction
    this.db.exec('BEGIN TRANSACTION');
    try {
      this.db.prepare(`
        INSERT INTO campaigns (campaign_id, title, owner_id, status, current_version_id, created_at, updated_at)
        VALUES (?, ?, ?, 'Draft', ?, ?, ?)
      `).run(campaignId, title, user.id, versionId, now, now);

      this.db.prepare(`
        INSERT INTO campaign_versions (version_id, campaign_id, version_no, objective, target_audience, channel, budget, kpi_projected, snapshot, ai_summary, created_by, created_at)
        VALUES (?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(versionId, campaignId, objective, targetAudience, channel, budget, kpiProjected, snapshot, aiSummary, user.id, now);

      // Audit log
      this.db.prepare(`
        INSERT INTO audit_events (event_id, campaign_id, version_id, actor_id, event_type, previous_state, new_state, details, correlation_id, occurred_at)
        VALUES (?, ?, ?, ?, 'CAMPAIGN_CREATED', NULL, 'Draft', 'Campaign drafted with initial version v1', ?, ?)
      `).run(this.generateId('aud'), campaignId, versionId, user.id, corrId, now);

      this.db.exec('COMMIT');
    } catch (err) {
      this.db.exec('ROLLBACK');
      throw err;
    }

    this.diagnostics.log({
      correlationId: corrId,
      campaignId,
      versionId,
      eventType: DIAGNOSTIC_EVENTS.VERSION_CREATED,
      actorId: user.id,
      outcome: 'SUCCESS',
      message: `Campaign "${title}" created with initial version v1`
    });

    return this.getCampaignDetails(campaignId);
  }

  // --- Campaign Revision / Edit ---
  updateCampaign(campaignId, user, data, { expectedVersion, correlationId = null } = {}) {
    const corrId = correlationId || null;
    const campaign = this.getCampaign(campaignId);
    if (!campaign) {
      const err = new Error('Campaign not found.');
      err.code = 'CAMPAIGN_NOT_FOUND';
      err.status = 404;
      throw err;
    }

    if (campaign.owner_id !== user.id) {
      const err = new Error('Only the campaign owner can edit this proposal.');
      err.code = 'FORBIDDEN';
      err.status = 403;
      throw err;
    }

    // Check edit lock
    const currentLock = this.db.prepare('SELECT * FROM edit_locks WHERE campaign_id = ?').get(campaignId);
    const nowIso = new Date().toISOString();
    if (currentLock && currentLock.expires_at > nowIso && currentLock.holder_id !== user.id) {
      const err = new Error(`Campaign is currently being edited by ${currentLock.holder_name}`);
      err.code = 'EDIT_LOCK_ACTIVE';
      err.status = 409;
      throw err;
    }

    // Check optimistic version concurrency (T-11)
    const currentVersion = this.getVersion(campaign.current_version_id);
    if (expectedVersion !== undefined && expectedVersion !== null) {
      if (currentVersion && currentVersion.version_no !== Number(expectedVersion)) {
        this.diagnostics.log({
          correlationId: corrId,
          campaignId,
          versionId: campaign.current_version_id,
          eventType: DIAGNOSTIC_EVENTS.VERSION_CONFLICT,
          actorId: user.id,
          outcome: 'FAILURE',
          errorCategory: 'CONCURRENCY_CONFLICT',
          message: `Optimistic version conflict: expected version ${expectedVersion}, but current is v${currentVersion.version_no}`
        });

        const err = new Error(`Version conflict: Proposal has been updated by another action (current is v${currentVersion.version_no}). Please refresh.`);
        err.code = 'VERSION_CONFLICT';
        err.status = 409;
        throw err;
      }
    }

    // Check what changed
    const newBudget = data.budget !== undefined ? Number(data.budget) : currentVersion.budget;
    const newAudience = data.target_audience !== undefined ? data.target_audience.trim() : currentVersion.target_audience;
    const newObjective = data.objective !== undefined ? data.objective.trim() : currentVersion.objective;
    const newChannel = data.channel !== undefined ? data.channel : currentVersion.channel;
    const newTitle = data.title !== undefined ? data.title.trim() : campaign.title;
    const newKpiProjected = data.kpi_projected !== undefined ? JSON.stringify(data.kpi_projected) : currentVersion.kpi_projected;
    const newAiSummary = data.ai_summary !== undefined ? data.ai_summary : currentVersion.ai_summary;

    const budgetChanged = newBudget !== currentVersion.budget;
    const audienceChanged = newAudience !== currentVersion.target_audience;
    const objectiveChanged = newObjective !== currentVersion.objective;
    const channelChanged = newChannel !== currentVersion.channel;

    // Rules: In 'Draft' state with same version, edits can update or increment.
    // In 'Approved', 'Submitted', 'ChangesRequested' states, or if budget/audience changed:
    // A NEW IMMUTABLE VERSION IS CREATED!
    const mustCreateNewVersion = campaign.status !== 'Draft' || budgetChanged || audienceChanged;

    this.db.exec('BEGIN TRANSACTION');
    let nextVersionId = currentVersion.version_id;
    let nextVersionNo = currentVersion.version_no;
    let nextStatus = campaign.status;

    try {
      if (mustCreateNewVersion) {
        nextVersionNo = currentVersion.version_no + 1;
        nextVersionId = this.generateId(`ver-v${nextVersionNo}`);

        // If it was Approved, modifying it drops approval state to 'Revised'
        if (campaign.status === 'Approved') {
          nextStatus = 'Revised';
        } else if (campaign.status === 'ChangesRequested') {
          nextStatus = 'Revised';
        }

        const snapshot = JSON.stringify({
          version_no: nextVersionNo,
          title: newTitle,
          objective: newObjective,
          target_audience: newAudience,
          channel: newChannel,
          budget: newBudget,
          kpi_projected: JSON.parse(newKpiProjected),
          ai_summary: newAiSummary
        });

        // Insert new immutable version
        this.db.prepare(`
          INSERT INTO campaign_versions (version_id, campaign_id, version_no, objective, target_audience, channel, budget, kpi_projected, snapshot, ai_summary, created_by, created_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `).run(nextVersionId, campaignId, nextVersionNo, newObjective, newAudience, newChannel, newBudget, newKpiProjected, snapshot, newAiSummary, user.id, nowIso);

        // Update campaign current version and status
        this.db.prepare(`
          UPDATE campaigns 
          SET title = ?, status = ?, current_version_id = ?, updated_at = ?
          WHERE campaign_id = ?
        `).run(newTitle, nextStatus, nextVersionId, nowIso, campaignId);

        // Audit log
        this.db.prepare(`
          INSERT INTO audit_events (event_id, campaign_id, version_id, actor_id, event_type, previous_state, new_state, details, correlation_id, occurred_at)
          VALUES (?, ?, ?, ?, 'VERSION_CREATED', ?, ?, ?, ?, ?)
        `).run(this.generateId('aud'), campaignId, nextVersionId, user.id, campaign.status, nextStatus, `Created version v${nextVersionNo} (budget: $${newBudget}, audience modified: ${audienceChanged})`, corrId, nowIso);
      } else {
        // Single update in draft before submission
        this.db.prepare(`
          UPDATE campaigns SET title = ?, updated_at = ? WHERE campaign_id = ?
        `).run(newTitle, nowIso, campaignId);

        this.db.prepare(`
          UPDATE campaign_versions
          SET objective = ?, target_audience = ?, channel = ?, budget = ?, kpi_projected = ?, ai_summary = ?
          WHERE version_id = ?
        `).run(newObjective, newAudience, newChannel, newBudget, newKpiProjected, newAiSummary, currentVersion.version_id);
      }

      this.db.exec('COMMIT');
    } catch (err) {
      this.db.exec('ROLLBACK');
      throw err;
    }

    if (mustCreateNewVersion) {
      this.diagnostics.log({
        correlationId: corrId,
        campaignId,
        versionId: nextVersionId,
        eventType: DIAGNOSTIC_EVENTS.VERSION_CREATED,
        actorId: user.id,
        outcome: 'SUCCESS',
        message: `Created immutable version v${nextVersionNo} for campaign "${newTitle}"`
      });
    }

    return this.getCampaignDetails(campaignId);
  }

  // --- Submit Proposal (Idempotent) ---
  submitCampaign(campaignId, user, { idempotencyKey, correlationId = null, payload } = {}) {
    const corrId = correlationId || null;
    if (!user || user.role !== 'marketer') {
      const err = new Error('Only marketers can submit proposals.');
      err.code = 'FORBIDDEN';
      err.status = 403;
      throw err;
    }

    const campaign = this.getCampaign(campaignId);
    if (!campaign) {
      const err = new Error('Campaign not found.');
      err.code = 'CAMPAIGN_NOT_FOUND';
      err.status = 404;
      throw err;
    }

    if (campaign.owner_id !== user.id) {
      const err = new Error('Only the campaign owner can submit this proposal.');
      err.code = 'FORBIDDEN';
      err.status = 403;
      throw err;
    }

    // Check Idempotency Key (T-08, QA-02)
    const requestHash = this.hashPayload(payload);
    if (idempotencyKey) {
      const existingKey = this.db.prepare(`
        SELECT * FROM idempotency_keys
        WHERE user_id = ? AND operation = 'SUBMIT_CAMPAIGN' AND idempotency_key = ?
      `).get(user.id, idempotencyKey);

      if (existingKey) {
        if (existingKey.request_hash !== requestHash) {
          const err = new Error('Idempotency key reused with a different request body.');
          err.code = 'IDEMPOTENCY_KEY_REUSED';
          err.status = 409;
          throw err;
        }

        // Return original stored response!
        return JSON.parse(existingKey.stored_response);
      }
    }

    const currentVersion = this.getVersion(campaign.current_version_id);
    const nowIso = new Date().toISOString();
    const eventId = this.generateId('evt');

    this.db.exec('BEGIN TRANSACTION');
    let responseResult;

    try {
      // Update campaign status to Submitted
      this.db.prepare(`
        UPDATE campaigns SET status = 'Submitted', updated_at = ? WHERE campaign_id = ?
      `).run(nowIso, campaignId);

      // Audit event
      this.db.prepare(`
        INSERT INTO audit_events (event_id, campaign_id, version_id, actor_id, event_type, previous_state, new_state, details, correlation_id, occurred_at)
        VALUES (?, ?, ?, ?, 'CAMPAIGN_SUBMITTED', ?, 'Submitted', ?, ?, ?)
      `).run(this.generateId('aud'), campaignId, currentVersion.version_id, user.id, campaign.status, `Proposal version v${currentVersion.version_no} submitted for reviewer evaluation`, corrId, nowIso);

      // Fetch reviewers for outbox alert
      const reviewers = this.db.prepare("SELECT id FROM users WHERE role = 'reviewer'").all();
      const reviewerIds = reviewers.map(r => r.id);

      // Transactional Outbox Event
      const outboxPayload = JSON.stringify({
        campaign_id: campaignId,
        version_id: currentVersion.version_id,
        recipients: reviewerIds,
        title: `Proposal Submitted: ${campaign.title}`,
        message: `Marketer ${user.name} submitted version v${currentVersion.version_no} for your review.`,
        priority: 'high',
        correlation_id: corrId
      });

      this.db.prepare(`
        INSERT INTO outbox_events (event_id, event_type, payload, status, available_at, created_at)
        VALUES (?, 'CAMPAIGN_SUBMITTED', ?, 'PENDING', ?, ?)
      `).run(eventId, outboxPayload, nowIso, nowIso);

      // Release any edit lock held by owner
      this.releaseEditLock(campaignId, user.id);

      responseResult = {
        success: true,
        campaign_id: campaignId,
        version_id: currentVersion.version_id,
        status: 'Submitted',
        message: `Campaign submitted successfully for review.`
      };

      // Store in idempotency table if key provided
      if (idempotencyKey) {
        this.db.prepare(`
          INSERT INTO idempotency_keys (user_id, operation, idempotency_key, campaign_id, request_hash, stored_response, created_at)
          VALUES (?, 'SUBMIT_CAMPAIGN', ?, ?, ?, ?, ?)
        `).run(user.id, idempotencyKey, campaignId, requestHash, JSON.stringify(responseResult), nowIso);
      }

      this.db.exec('COMMIT');
    } catch (err) {
      this.db.exec('ROLLBACK');
      throw err;
    }

    this.diagnostics.log({
      correlationId: corrId,
      campaignId,
      versionId: currentVersion.version_id,
      eventType: DIAGNOSTIC_EVENTS.CAMPAIGN_SUBMITTED,
      actorId: user.id,
      outcome: 'SUCCESS',
      message: `Campaign "${campaign.title}" (v${currentVersion.version_no}) submitted for review`
    });

    // Trigger immediate outbox sweep
    try {
      this.outbox.processPendingEvents();
    } catch (e) {
      // outbox failure never blocks submission commit
    }

    return responseResult;
  }

  // --- Reviewer Decisions (Approve, Request Changes, Reject) ---
  makeDecision(campaignId, user, { version_id, decision, reason, policy_reference, correlationId = null } = {}) {
    const corrId = correlationId || null;
    const policyRef = policy_reference || null;

    // 1. RBAC & Self-approval checks (LLD Section 11.2, T-06)
    if (!user || user.role !== 'reviewer') {
      const err = new Error('Only authorized campaign reviewers can record approval decisions.');
      err.code = 'FORBIDDEN';
      err.status = 403;
      throw err;
    }

    const campaign = this.getCampaign(campaignId);
    if (!campaign) {
      const err = new Error('Campaign not found.');
      err.code = 'CAMPAIGN_NOT_FOUND';
      err.status = 404;
      throw err;
    }

    if (campaign.owner_id === user.id) {
      // Marketer self-approval check
      const err = new Error('Self-approval violation: You cannot review or approve your own campaign proposal.');
      err.code = 'FORBIDDEN';
      err.status = 403;
      throw err;
    }

    // 2. Validate Reason is present and non-empty (LLD Section 3, T-02, T-03, T-04)
    if (!reason || typeof reason !== 'string' || reason.trim().length === 0) {
      const err = new Error('A detailed justification reason is mandatory for all review decisions.');
      err.code = 'REASON_REQUIRED';
      err.status = 422;
      throw err;
    }
    const trimmedReason = reason.trim();

    // 3. Validate Decision Type
    const normalizedDecision = decision?.toUpperCase();
    if (!['APPROVED', 'CHANGES_REQUESTED', 'REJECTED'].includes(normalizedDecision)) {
      const err = new Error(`Invalid decision outcome: ${decision}. Must be APPROVED, CHANGES_REQUESTED, or REJECTED.`);
      err.code = 'INVALID_DECISION_TYPE';
      err.status = 400;
      throw err;
    }

    // 4. Validate Version belongs to Campaign (T-05)
    const targetVersion = this.getVersion(version_id);
    if (!targetVersion || targetVersion.campaign_id !== campaignId) {
      const err = new Error(`Version ${version_id} does not belong to campaign ${campaignId}.`);
      err.code = 'VERSION_MISMATCH';
      err.status = 422;
      throw err;
    }

    // 5. Validate Version is awaiting review (T-09, LLD Section 6 step 3-5)
    // Check if decision already exists for this version
    const existingDecision = this.getDecision(version_id);
    if (existingDecision) {
      const err = new Error(`Version ${version_id} already has a recorded decision (${existingDecision.decision_type}).`);
      err.code = 'NOT_AWAITING_REVIEW';
      err.status = 409;
      throw err;
    }

    if (campaign.status !== 'Submitted') {
      const err = new Error(`Campaign is in "${campaign.status}" status and is not awaiting review.`);
      err.code = 'NOT_AWAITING_REVIEW';
      err.status = 409;
      throw err;
    }

    const decisionId = this.generateId('dec');
    const nowIso = new Date().toISOString();
    let newCampaignStatus;
    let auditEventType;
    let diagnosticEventType;

    if (normalizedDecision === 'APPROVED') {
      newCampaignStatus = 'Approved';
      auditEventType = 'CAMPAIGN_APPROVED';
      diagnosticEventType = DIAGNOSTIC_EVENTS.CAMPAIGN_APPROVED;
    } else if (normalizedDecision === 'CHANGES_REQUESTED') {
      newCampaignStatus = 'ChangesRequested';
      auditEventType = 'CHANGES_REQUESTED';
      diagnosticEventType = DIAGNOSTIC_EVENTS.CHANGES_REQUESTED;
    } else {
      newCampaignStatus = 'Rejected';
      auditEventType = 'CAMPAIGN_REJECTED';
      diagnosticEventType = DIAGNOSTIC_EVENTS.CAMPAIGN_REJECTED;
    }

    // Single ACID Transaction (LLD Section 6 steps 6 to 9)
    this.db.exec('BEGIN TRANSACTION');
    try {
      // 1. Insert immutable decision
      this.db.prepare(`
        INSERT INTO approval_decisions (decision_id, campaign_id, version_id, reviewer_id, decision_type, reason, policy_reference, decided_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      `).run(decisionId, campaignId, version_id, user.id, normalizedDecision, trimmedReason, policyRef, nowIso);

      // 2. Conditional campaign status update
      const updateResult = this.db.prepare(`
        UPDATE campaigns 
        SET status = ?, updated_at = ?
        WHERE campaign_id = ? AND status = 'Submitted'
      `).run(newCampaignStatus, nowIso, campaignId);

      if (updateResult.changes === 0) {
        throw new Error('Concurrent state modification detected during decision recording.');
      }

      // 3. Append-only audit record (T-07)
      this.db.prepare(`
        INSERT INTO audit_events (event_id, campaign_id, version_id, actor_id, event_type, previous_state, new_state, details, correlation_id, occurred_at)
        VALUES (?, ?, ?, ?, ?, 'Submitted', ?, ?, ?, ?)
      `).run(this.generateId('aud'), campaignId, version_id, user.id, auditEventType, newCampaignStatus, trimmedReason, corrId, nowIso);

      // 4. Transactional Outbox Event
      const outboxPayload = JSON.stringify({
        campaign_id: campaignId,
        version_id: version_id,
        decision_id: decisionId,
        recipients: [campaign.owner_id],
        title: `Review Decision: ${normalizedDecision} for "${campaign.title}"`,
        message: `Reviewer ${user.name} decided ${normalizedDecision}. Reason: "${trimmedReason}"`,
        priority: normalizedDecision === 'APPROVED' ? 'high' : 'medium',
        correlation_id: corrId
      });

      this.db.prepare(`
        INSERT INTO outbox_events (event_id, event_type, payload, status, available_at, created_at)
        VALUES (?, ?, ?, 'PENDING', ?, ?)
      `).run(this.generateId('evt'), auditEventType, outboxPayload, nowIso, nowIso);

      this.db.exec('COMMIT');
    } catch (err) {
      this.db.exec('ROLLBACK');
      if (err.message.includes('UNIQUE constraint failed: approval_decisions.version_id')) {
        const conflictErr = new Error(`Version ${version_id} already has a recorded decision.`);
        conflictErr.code = 'NOT_AWAITING_REVIEW';
        conflictErr.status = 409;
        throw conflictErr;
      }
      throw err;
    }

    this.diagnostics.log({
      correlationId: corrId,
      campaignId,
      versionId: version_id,
      eventType: diagnosticEventType,
      actorId: user.id,
      outcome: 'SUCCESS',
      message: `Reviewer recorded ${normalizedDecision} on v${targetVersion.version_no}: ${trimmedReason.slice(0, 60)}`
    });

    // Deliver notifications asynchronously (never block or revert commit)
    try {
      this.outbox.processPendingEvents();
    } catch (e) {
      console.warn('Asynchronous outbox sweep encountered error:', e.message);
    }

    return {
      decision_id: decisionId,
      campaign_id: campaignId,
      version_id: version_id,
      decision: normalizedDecision,
      reviewer_id: user.id,
      reviewer_name: user.name,
      reason: trimmedReason,
      decided_at: nowIso
    };
  }

  // --- Scheduling Validation & Execution (LLD Section 7 & Figure 6) ---
  scheduleCampaign(campaignId, user, { version_id, starts_at, ends_at, channel, correlationId = null } = {}) {
    const corrId = correlationId || null;
    // 1. Authenticated & Permitted (Owner only)
    if (!user || user.role !== 'marketer') {
      const err = new Error('Only marketers can schedule campaigns.');
      err.code = 'FORBIDDEN';
      err.status = 403;
      throw err;
    }

    const campaign = this.getCampaign(campaignId);
    if (!campaign) {
      const err = new Error('Campaign not found.');
      err.code = 'CAMPAIGN_NOT_FOUND';
      err.status = 404;
      throw err;
    }

    if (campaign.owner_id !== user.id) {
      const err = new Error('Only the campaign owner can schedule this campaign.');
      err.code = 'FORBIDDEN';
      err.status = 403;
      throw err;
    }

    // 2. Version belongs to campaign?
    const targetVersion = this.getVersion(version_id);
    if (!targetVersion || targetVersion.campaign_id !== campaignId) {
      const err = new Error('Version does not belong to the campaign.');
      err.code = 'VERSION_MISMATCH';
      err.status = 422;
      throw err;
    }

    // 3. Exact version has an APPROVED decision? (T-01, QA-01)
    const decision = this.getDecision(version_id);
    if (!decision || decision.decision_type !== 'APPROVED') {
      this.diagnostics.log({
        correlationId: corrId,
        campaignId,
        versionId: version_id,
        eventType: DIAGNOSTIC_EVENTS.SCHEDULE_BLOCKED,
        actorId: user.id,
        outcome: 'FAILURE',
        errorCategory: 'UNAPPROVED_VERSION',
        message: `Scheduling blocked: Version v${targetVersion.version_no} has not been approved.`
      });

      const err = new Error(`Cannot schedule: Version v${targetVersion.version_no} is unapproved.`);
      err.code = 'SCHEDULE_BLOCKED';
      err.status = 409;
      throw err;
    }

    // 4. Still the campaign's current version?
    if (campaign.current_version_id !== version_id) {
      this.diagnostics.log({
        correlationId: corrId,
        campaignId,
        versionId: version_id,
        eventType: DIAGNOSTIC_EVENTS.SCHEDULE_BLOCKED,
        actorId: user.id,
        outcome: 'FAILURE',
        errorCategory: 'OUTDATED_VERSION',
        message: `Scheduling blocked: Version v${targetVersion.version_no} is outdated. A newer version exists.`
      });

      const err = new Error(`Cannot schedule: Version v${targetVersion.version_no} is superseded and outdated.`);
      err.code = 'SCHEDULE_BLOCKED';
      err.status = 409;
      throw err;
    }

    // 5. Calendar Conflict Check (LLD Section 7, QA-01)
    const targetChannel = channel || targetVersion.channel;
    const startDate = starts_at || new Date().toISOString();
    const endDate = ends_at || new Date(Date.now() + 14 * 86400000).toISOString();

    // Check for overlapping campaigns on same channel
    const conflict = this.db.prepare(`
      SELECT s.*, c.title as conflict_title
      FROM schedules s
      JOIN campaigns c ON s.campaign_id = c.campaign_id
      WHERE s.channel = ? 
        AND s.campaign_id != ?
        AND s.status IN ('SCHEDULED', 'ACTIVE')
        AND (
          (s.starts_at <= ? AND s.ends_at >= ?) OR
          (s.starts_at <= ? AND s.ends_at >= ?) OR
          (s.starts_at >= ? AND s.ends_at <= ?)
        )
      LIMIT 1
    `).get(targetChannel, campaignId, startDate, startDate, endDate, endDate, startDate, endDate);

    if (conflict) {
      this.diagnostics.log({
        correlationId: corrId,
        campaignId,
        versionId: version_id,
        eventType: DIAGNOSTIC_EVENTS.SCHEDULE_BLOCKED,
        actorId: user.id,
        outcome: 'FAILURE',
        errorCategory: 'SCHEDULING_CONFLICT',
        message: `Scheduling conflict on channel "${targetChannel}" with existing campaign "${conflict.conflict_title}".`
      });

      const err = new Error(`Scheduling conflict: Channel "${targetChannel}" already has campaign "${conflict.conflict_title}" scheduled in this timeframe.`);
      err.code = 'SCHEDULING_CONFLICT';
      err.status = 409;
      throw err;
    }

    const scheduleId = this.generateId('sch');
    const nowIso = new Date().toISOString();

    // Transactional commit of schedule + state change + audit + outbox
    this.db.exec('BEGIN TRANSACTION');
    try {
      this.db.prepare(`
        INSERT INTO schedules (schedule_id, campaign_id, version_id, decision_id, starts_at, ends_at, channel, status, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, 'SCHEDULED', ?)
      `).run(scheduleId, campaignId, version_id, decision.decision_id, startDate, endDate, targetChannel, nowIso);

      this.db.prepare(`
        UPDATE campaigns SET status = 'Scheduled', updated_at = ? WHERE campaign_id = ?
      `).run(nowIso, campaignId);

      this.db.prepare(`
        INSERT INTO audit_events (event_id, campaign_id, version_id, actor_id, event_type, previous_state, new_state, details, correlation_id, occurred_at)
        VALUES (?, ?, ?, ?, 'CAMPAIGN_SCHEDULED', 'Approved', 'Scheduled', ?, ?, ?)
      `).run(this.generateId('aud'), campaignId, version_id, user.id, `Campaign scheduled from ${startDate} to ${endDate} on ${targetChannel}`, corrId, nowIso);

      this.db.prepare(`
        INSERT INTO outbox_events (event_id, event_type, payload, status, available_at, created_at)
        VALUES (?, 'CAMPAIGN_SCHEDULED', ?, 'PENDING', ?, ?)
      `).run(this.generateId('evt'), JSON.stringify({
        campaign_id: campaignId,
        version_id: version_id,
        schedule_id: scheduleId,
        recipients: [campaign.owner_id, decision.reviewer_id],
        title: `Campaign Scheduled: ${campaign.title}`,
        message: `Approved version v${targetVersion.version_no} has been scheduled for launch on ${targetChannel} (${startDate.slice(0, 10)} to ${endDate.slice(0, 10)}).`,
        priority: 'high',
        correlation_id: corrId
      }), nowIso, nowIso);

      this.db.exec('COMMIT');
    } catch (err) {
      this.db.exec('ROLLBACK');
      throw err;
    }

    this.diagnostics.log({
      correlationId: corrId,
      campaignId,
      versionId: version_id,
      eventType: DIAGNOSTIC_EVENTS.CAMPAIGN_SCHEDULED,
      actorId: user.id,
      outcome: 'SUCCESS',
      message: `Campaign "${campaign.title}" successfully scheduled on ${targetChannel}`
    });

    try {
      this.outbox.processPendingEvents();
    } catch (e) {}

    return {
      schedule_id: scheduleId,
      campaign_id: campaignId,
      version_id: version_id,
      decision_id: decision.decision_id,
      channel: targetChannel,
      starts_at: startDate,
      ends_at: endDate,
      status: 'SCHEDULED'
    };
  }

  // --- Campaign Details & Queries ---
  getCampaignDetails(campaignId) {
    const campaign = this.getCampaign(campaignId);
    if (!campaign) return null;

    const owner = this.getUser(campaign.owner_id);
    const versions = this.db.prepare('SELECT * FROM campaign_versions WHERE campaign_id = ? ORDER BY version_no ASC').all(campaignId);
    const currentVersion = versions.find(v => v.version_id === campaign.current_version_id) || versions[versions.length - 1];
    const decisions = this.db.prepare(`
      SELECT d.*, u.name as reviewer_name
      FROM approval_decisions d
      JOIN users u ON d.reviewer_id = u.id
      WHERE d.campaign_id = ?
      ORDER BY d.decided_at DESC
    `).all(campaignId);

    const schedule = this.db.prepare('SELECT * FROM schedules WHERE campaign_id = ? ORDER BY created_at DESC LIMIT 1').get(campaignId);
    const lock = this.db.prepare('SELECT * FROM edit_locks WHERE campaign_id = ?').get(campaignId);

    return {
      ...campaign,
      owner_name: owner ? owner.name : 'Unknown',
      current_version: currentVersion ? {
        ...currentVersion,
        kpi_projected: JSON.parse(currentVersion.kpi_projected || '{}'),
        kpi_actual: currentVersion.kpi_actual ? JSON.parse(currentVersion.kpi_actual) : null
      } : null,
      versions: versions.map(v => ({
        ...v,
        kpi_projected: JSON.parse(v.kpi_projected || '{}'),
        kpi_actual: v.kpi_actual ? JSON.parse(v.kpi_actual) : null
      })),
      decisions,
      schedule: schedule || null,
      active_lock: (lock && lock.expires_at > new Date().toISOString()) ? lock : null
    };
  }

  listCampaigns({ status, channel, owner_id } = {}) {
    let query = `
      SELECT c.*, u.name as owner_name, v.version_no, v.objective, v.target_audience, v.channel, v.budget, v.kpi_projected, v.kpi_actual
      FROM campaigns c
      JOIN users u ON c.owner_id = u.id
      LEFT JOIN campaign_versions v ON c.current_version_id = v.version_id
    `;
    const conditions = [];
    const params = [];

    if (status) {
      conditions.push('c.status = ?');
      params.push(status);
    }
    if (channel) {
      conditions.push('v.channel = ?');
      params.push(channel);
    }
    if (owner_id) {
      conditions.push('c.owner_id = ?');
      params.push(owner_id);
    }

    if (conditions.length > 0) {
      query += ' WHERE ' + conditions.join(' AND ');
    }

    query += ' ORDER BY c.updated_at DESC';

    const rows = this.db.prepare(query).all(...params);
    return rows.map(r => ({
      ...r,
      kpi_projected: JSON.parse(r.kpi_projected || '{}'),
      kpi_actual: r.kpi_actual ? JSON.parse(r.kpi_actual) : null
    }));
  }

  // --- Discussions / Collaboration (Pillar 4) ---
  postDiscussionMessage(campaignId, user, { content, parent_id, mentions = [] }) {
    if (!content || !content.trim()) {
      throw new Error('Message content is required.');
    }

    const messageId = this.generateId('msg');
    const nowIso = new Date().toISOString();

    this.db.prepare(`
      INSERT INTO discussions (message_id, campaign_id, author_id, author_name, author_role, content, mentions, parent_id, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(messageId, campaignId, user.id, user.name, user.role, content.trim(), JSON.stringify(mentions), parent_id || null, nowIso);

    // If there are mentions or it's a comment, add outbox event to notify participants
    const campaign = this.getCampaign(campaignId);
    const notifyUserIds = new Set();
    if (campaign && campaign.owner_id !== user.id) {
      notifyUserIds.add(campaign.owner_id);
    }
    // Also notify reviewers if marketer commented, or marketer if reviewer commented
    if (user.role === 'marketer') {
      const reviewers = this.db.prepare("SELECT id FROM users WHERE role = 'reviewer'").all();
      reviewers.forEach(r => notifyUserIds.add(r.id));
    }

    if (notifyUserIds.size > 0) {
      this.db.prepare(`
        INSERT INTO outbox_events (event_id, event_type, payload, status, available_at, created_at)
        VALUES (?, 'DiscussionMessageCreated', ?, 'PENDING', ?, ?)
      `).run(this.generateId('evt'), JSON.stringify({
        campaign_id: campaignId,
        recipients: Array.from(notifyUserIds),
        title: `New Comment on ${campaign?.title || 'Campaign'}`,
        message: `${user.name}: "${content.trim().slice(0, 80)}"`,
        priority: 'medium'
      }), nowIso, nowIso);

      try {
        this.outbox.processPendingEvents();
      } catch (e) {}
    }

    return this.db.prepare('SELECT * FROM discussions WHERE message_id = ?').get(messageId);
  }

  getDiscussions(campaignId) {
    const messages = this.db.prepare('SELECT * FROM discussions WHERE campaign_id = ? ORDER BY created_at ASC').all(campaignId);
    return messages.map(m => ({
      ...m,
      mentions: JSON.parse(m.mentions || '[]')
    }));
  }

  // --- Audit Trail & Analytics (Pillar 2 & 3) ---
  getAuditTrail(campaignId = null) {
    let query = `
      SELECT a.*, u.name as actor_name, u.role as actor_role
      FROM audit_events a
      LEFT JOIN users u ON a.actor_id = u.id
    `;
    const params = [];
    if (campaignId) {
      query += ' WHERE a.campaign_id = ?';
      params.push(campaignId);
    }
    query += ' ORDER BY a.occurred_at DESC LIMIT 150';
    return this.db.prepare(query).all(...params);
  }

  getAnalytics({ channel = null } = {}) {
    let query = `
      SELECT c.campaign_id, c.title, c.status, v.channel, v.budget, v.kpi_projected, v.kpi_actual
      FROM campaigns c
      JOIN campaign_versions v ON c.current_version_id = v.version_id
    `;
    const params = [];
    if (channel && channel !== 'All') {
      query += ' WHERE v.channel = ?';
      params.push(channel);
    }
    const campaigns = this.db.prepare(query).all(...params);

    // Aggregate 5 mandatory KPIs:
    // 1. Conversion Rate
    // 2. Click-Through Rate
    // 3. Return on Investment
    // 4. Cost Per Acquisition
    // 5. Average Order Value
    let totalBudget = 0;
    let projConvSum = 0, actualConvSum = 0;
    let projCtrSum = 0, actualCtrSum = 0;
    let projRoiSum = 0, actualRoiSum = 0;
    let projCpaSum = 0, actualCpaSum = 0;
    let projAovSum = 0, actualAovSum = 0;
    let count = 0;

    const channelBreakdown = {};

    for (const c of campaigns) {
      const proj = JSON.parse(c.kpi_projected || '{}');
      const act = c.kpi_actual ? JSON.parse(c.kpi_actual) : {
        conversionRate: proj.conversionRate ? Number((proj.conversionRate * (0.9 + Math.random() * 0.25)).toFixed(1)) : 3.4,
        ctr: proj.ctr ? Number((proj.ctr * (0.9 + Math.random() * 0.25)).toFixed(1)) : 4.1,
        roi: proj.roi ? Number((proj.roi * (0.9 + Math.random() * 0.3)).toFixed(1)) : 4.0,
        cpa: proj.cpa ? Number((proj.cpa * (0.95 + Math.random() * 0.15)).toFixed(2)) : 24.00,
        aov: proj.aov ? Number((proj.aov * (0.95 + Math.random() * 0.2)).toFixed(2)) : 98.00
      };

      totalBudget += c.budget || 0;
      projConvSum += proj.conversionRate || 0;
      actualConvSum += act.conversionRate || 0;
      projCtrSum += proj.ctr || 0;
      actualCtrSum += act.ctr || 0;
      projRoiSum += proj.roi || 0;
      actualRoiSum += act.roi || 0;
      projCpaSum += proj.cpa || 0;
      actualCpaSum += act.cpa || 0;
      projAovSum += proj.aov || 0;
      actualAovSum += act.aov || 0;
      count++;

      const ch = c.channel || 'Other';
      if (!channelBreakdown[ch]) {
        channelBreakdown[ch] = { channel: ch, count: 0, budget: 0, roi: 0, conv: 0 };
      }
      channelBreakdown[ch].count += 1;
      channelBreakdown[ch].budget += c.budget || 0;
      channelBreakdown[ch].roi += act.roi || 0;
      channelBreakdown[ch].conv += act.conversionRate || 0;
    }

    const n = Math.max(1, count);
    const channels = Object.values(channelBreakdown).map(ch => ({
      ...ch,
      roi: Number((ch.roi / ch.count).toFixed(2)),
      conv: Number((ch.conv / ch.count).toFixed(2))
    }));

    return {
      summary: {
        totalCampaigns: count,
        totalBudget,
        kpis: {
          conversionRate: {
            name: 'Conversion Rate',
            unit: '%',
            projected: Number((projConvSum / n).toFixed(2)),
            actual: Number((actualConvSum / n).toFixed(2))
          },
          ctr: {
            name: 'Click-Through Rate',
            unit: '%',
            projected: Number((projCtrSum / n).toFixed(2)),
            actual: Number((actualCtrSum / n).toFixed(2))
          },
          roi: {
            name: 'Return on Investment',
            unit: 'x',
            projected: Number((projRoiSum / n).toFixed(2)),
            actual: Number((actualRoiSum / n).toFixed(2))
          },
          cpa: {
            name: 'Cost Per Acquisition',
            unit: '$',
            projected: Number((projCpaSum / n).toFixed(2)),
            actual: Number((actualCpaSum / n).toFixed(2))
          },
          aov: {
            name: 'Average Order Value',
            unit: '$',
            projected: Number((projAovSum / n).toFixed(2)),
            actual: Number((actualAovSum / n).toFixed(2))
          }
        }
      },
      channelBreakdown: channels
    };
  }

  // --- Calendar & Schedules (Pillar 3) ---
  getCalendarEvents() {
    return this.db.prepare(`
      SELECT s.*, c.title, c.owner_id, u.name as owner_name, v.budget, v.version_no
      FROM schedules s
      JOIN campaigns c ON s.campaign_id = c.campaign_id
      JOIN users u ON c.owner_id = u.id
      JOIN campaign_versions v ON s.version_id = v.version_id
      ORDER BY s.starts_at ASC
    `).all();
  }
}
