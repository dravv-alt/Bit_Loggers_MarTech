import express from 'express';
import cors from 'cors';
import crypto from 'node:crypto';
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import { initDatabase } from './db.js';
import { Diagnostics, DIAGNOSTIC_EVENTS } from './diagnostics.js';
import { OutboxService } from './outbox.js';
import { WorkflowService } from './workflow.js';
import { AIService } from './ai.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export function createApp(dbPath = null) {
  const app = express();
  app.use(cors());
  app.use(express.json());

  // Initialize modular services
  const db = initDatabase(dbPath);
  const diagnostics = new Diagnostics(db);
  const outbox = new OutboxService(db, diagnostics);
  const workflow = new WorkflowService(db, diagnostics, outbox);
  const ai = new AIService(diagnostics);

  // Correlation ID & Context Middleware
  app.use((req, res, next) => {
    const correlationId = req.headers['x-correlation-id'] || 'c-' + crypto.randomUUID().slice(0, 8);
    req.correlationId = correlationId;
    res.setHeader('X-Correlation-ID', correlationId);

    // Identify user from header or default to Marketer
    const userId = req.headers['x-user-id'] || 'usr-marketer-1';
    req.user = workflow.getUser(userId) || workflow.getUser('usr-marketer-1');

    next();
  });

  // --- Auth / Users ---
  app.get('/api/users', (req, res) => {
    const users = db.prepare('SELECT * FROM users').all();
    res.json({ users, currentUser: req.user });
  });

  app.get('/api/users/me', (req, res) => {
    res.json({ user: req.user });
  });

  // --- Campaigns List & Details ---
  app.get('/api/campaigns', (req, res) => {
    const { status, channel, owner_id } = req.query;
    const campaigns = workflow.listCampaigns({ status, channel, owner_id });
    res.json({ campaigns });
  });

  app.get('/api/campaigns/:id', (req, res) => {
    const campaign = workflow.getCampaignDetails(req.params.id);
    if (!campaign) {
      return res.status(404).json({
        error: { code: 'CAMPAIGN_NOT_FOUND', message: 'Campaign does not exist.', correlation_id: req.correlationId }
      });
    }
    res.json(campaign);
  });

  app.post('/api/campaigns', (req, res) => {
    try {
      const campaign = workflow.createCampaign(req.user, req.body, req.correlationId);
      res.status(201).json(campaign);
    } catch (err) {
      res.status(err.status || 500).json({
        error: { code: err.code || 'INTERNAL_ERROR', message: err.message, correlation_id: req.correlationId }
      });
    }
  });

  app.put('/api/campaigns/:id', (req, res) => {
    const expectedVersion = req.headers['x-expected-version'] || req.body.expected_version;
    try {
      const campaign = workflow.updateCampaign(req.params.id, req.user, req.body, {
        expectedVersion,
        correlationId: req.correlationId
      });
      res.json(campaign);
    } catch (err) {
      res.status(err.status || 500).json({
        error: { code: err.code || 'INTERNAL_ERROR', message: err.message, correlation_id: req.correlationId }
      });
    }
  });

  // --- Concurrency / Edit Lock (LLD Section 9) ---
  app.post('/api/campaigns/:id/lock', (req, res) => {
    const result = workflow.acquireEditLock(req.params.id, req.user, req.correlationId);
    if (!result.granted) {
      return res.status(409).json({
        error: { code: 'EDIT_LOCK_HELD', message: result.message, holder: result.holder_name, expires_at: result.expires_at, correlation_id: req.correlationId }
      });
    }
    res.json(result);
  });

  app.delete('/api/campaigns/:id/lock', (req, res) => {
    const released = workflow.releaseEditLock(req.params.id, req.user.id);
    res.json({ success: released });
  });

  // --- Campaign Submission (LLD Section 8, T-08) ---
  app.post('/api/campaigns/:id/submit', (req, res) => {
    const idempotencyKey = req.headers['idempotency-key'] || req.headers['x-idempotency-key'] || req.body.idempotency_key;
    try {
      const result = workflow.submitCampaign(req.params.id, req.user, {
        idempotencyKey,
        correlationId: req.correlationId,
        payload: req.body
      });
      res.json(result);
    } catch (err) {
      res.status(err.status || 500).json({
        error: { code: err.code || 'SUBMIT_FAILED', message: err.message, correlation_id: req.correlationId }
      });
    }
  });

  // Also support direct path without /api prefix as per LLD Table 11
  app.post('/campaigns/:id/submit', (req, res) => {
    const idempotencyKey = req.headers['idempotency-key'] || req.headers['x-idempotency-key'] || req.body.idempotency_key;
    try {
      const result = workflow.submitCampaign(req.params.id, req.user, {
        idempotencyKey,
        correlationId: req.correlationId,
        payload: req.body
      });
      res.json(result);
    } catch (err) {
      res.status(err.status || 500).json({
        error: { code: err.code || 'SUBMIT_FAILED', message: err.message, correlation_id: req.correlationId }
      });
    }
  });

  // --- Reviewer Decisions (LLD Section 2, 3, 6 & 11) ---
  const handleDecision = (decisionType) => (req, res) => {
    const { version_id, reason, policy_reference } = req.body;
    try {
      const result = workflow.makeDecision(req.params.id, req.user, {
        version_id,
        decision: decisionType,
        reason,
        policy_reference,
        correlationId: req.correlationId
      });
      res.json(result);
    } catch (err) {
      res.status(err.status || 500).json({
        error: { code: err.code || 'DECISION_FAILED', message: err.message, correlation_id: req.correlationId }
      });
    }
  };

  // Both /api/campaigns/:id/... and /campaigns/:id/... routes
  app.post('/api/campaigns/:id/approve', handleDecision('APPROVED'));
  app.post('/campaigns/:id/approve', handleDecision('APPROVED'));

  app.post('/api/campaigns/:id/request-changes', handleDecision('CHANGES_REQUESTED'));
  app.post('/campaigns/:id/request-changes', handleDecision('CHANGES_REQUESTED'));

  app.post('/api/campaigns/:id/reject', handleDecision('REJECTED'));
  app.post('/campaigns/:id/reject', handleDecision('REJECTED'));

  // --- Scheduling (LLD Section 7 & 11) ---
  const handleSchedule = (req, res) => {
    const { version_id, starts_at, ends_at, channel } = req.body;
    try {
      const result = workflow.scheduleCampaign(req.params.id, req.user, {
        version_id,
        starts_at,
        ends_at,
        channel,
        correlationId: req.correlationId
      });
      res.status(201).json(result);
    } catch (err) {
      res.status(err.status || 500).json({
        error: { code: err.code || 'SCHEDULE_FAILED', message: err.message, correlation_id: req.correlationId }
      });
    }
  };

  app.post('/api/campaigns/:id/schedule', handleSchedule);
  app.post('/campaigns/:id/schedule', handleSchedule);

  // --- Decision & Version History ---
  const handleDecisionsGet = (req, res) => {
    const decisions = db.prepare(`
      SELECT d.*, u.name as reviewer_name 
      FROM approval_decisions d
      JOIN users u ON d.reviewer_id = u.id
      WHERE d.campaign_id = ?
      ORDER BY d.decided_at DESC
    `).all(req.params.id);
    res.json({ decisions });
  };

  app.get('/api/campaigns/:id/decisions', handleDecisionsGet);
  app.get('/campaigns/:id/decisions', handleDecisionsGet);

  const handleVersionsGet = (req, res) => {
    const versions = db.prepare(`
      SELECT * FROM campaign_versions 
      WHERE campaign_id = ? 
      ORDER BY version_no ASC
    `).all(req.params.id);
    res.json({
      versions: versions.map(v => ({
        ...v,
        kpi_projected: JSON.parse(v.kpi_projected || '{}'),
        kpi_actual: v.kpi_actual ? JSON.parse(v.kpi_actual) : null
      }))
    });
  };

  app.get('/api/campaigns/:id/versions', handleVersionsGet);
  app.get('/campaigns/:id/versions', handleVersionsGet);

  // --- Collaboration / Discussions (Pillar 4) ---
  app.get('/api/campaigns/:id/discussions', (req, res) => {
    const messages = workflow.getDiscussions(req.params.id);
    res.json({ messages });
  });

  app.post('/api/campaigns/:id/discussions', (req, res) => {
    try {
      const msg = workflow.postDiscussionMessage(req.params.id, req.user, req.body);
      res.status(201).json(msg);
    } catch (err) {
      res.status(400).json({ error: { message: err.message } });
    }
  });

  // --- Notifications (Pillar 4) ---
  app.get('/api/notifications', (req, res) => {
    const notifications = db.prepare(`
      SELECT * FROM notifications 
      WHERE recipient_id = ? 
      ORDER BY created_at DESC 
      LIMIT 50
    `).all(req.user.id);

    const unreadCount = db.prepare(`
      SELECT COUNT(*) as count FROM notifications
      WHERE recipient_id = ? AND is_read = 0
    `).get(req.user.id).count;

    res.json({ notifications, unreadCount });
  });

  app.post('/api/notifications/:id/read', (req, res) => {
    db.prepare('UPDATE notifications SET is_read = 1 WHERE notification_id = ? AND recipient_id = ?').run(req.params.id, req.user.id);
    res.json({ success: true });
  });

  app.post('/api/notifications/read-all', (req, res) => {
    db.prepare('UPDATE notifications SET is_read = 1 WHERE recipient_id = ?').run(req.user.id);
    res.json({ success: true });
  });

  // --- Outbox Management & Testing (T-12) ---
  app.get('/api/outbox', (req, res) => {
    const events = db.prepare('SELECT * FROM outbox_events ORDER BY created_at DESC LIMIT 50').all();
    res.json({
      events,
      isEmailServiceFailing: outbox.isEmailServiceFailing
    });
  });

  app.post('/api/outbox/process', (req, res) => {
    const results = outbox.processPendingEvents();
    res.json({ processed: results });
  });

  app.post('/api/outbox/toggle-email-failure', (req, res) => {
    const failing = req.body.failing !== undefined ? req.body.failing : !outbox.isEmailServiceFailing;
    outbox.setEmailFailing(failing);
    res.json({ isEmailServiceFailing: outbox.isEmailServiceFailing });
  });

  // --- AI Assistance (Pillar 4, T-13) ---
  app.post('/api/ai/draft', async (req, res) => {
    try {
      const draft = await ai.draftProposal({
        ...req.body,
        correlationId: req.correlationId
      });
      res.json(draft);
    } catch (err) {
      res.status(503).json({
        error: { code: 'AI_UNAVAILABLE', message: err.message, correlation_id: req.correlationId }
      });
    }
  });

  app.post('/api/ai/summarize', async (req, res) => {
    try {
      const summary = await ai.summarizeProposal({
        ...req.body,
        correlationId: req.correlationId
      });
      res.json({ summary });
    } catch (err) {
      res.status(503).json({
        error: { code: 'AI_UNAVAILABLE', message: err.message, correlation_id: req.correlationId }
      });
    }
  });

  app.post('/api/ai/toggle-failure', (req, res) => {
    const failing = req.body.failing !== undefined ? req.body.failing : !ai.isGeminiFailing;
    ai.setGeminiFailing(failing);
    res.json({ isGeminiFailing: ai.isGeminiFailing });
  });

  // --- Analytics & KPIs (Pillar 2) ---
  app.get('/api/analytics', (req, res) => {
    const data = workflow.getAnalytics({ channel: req.query.channel });
    res.json(data);
  });

  // --- Calendar & Schedules (Pillar 3) ---
  app.get('/api/calendar', (req, res) => {
    const events = workflow.getCalendarEvents();
    res.json({ events });
  });

  // --- Audit Trail & Diagnostics (Pillar 3 & 5) ---
  app.get('/api/audit', (req, res) => {
    const audit = workflow.getAuditTrail(req.query.campaign_id);
    res.json({ audit });
  });

  app.get('/api/diagnostics', (req, res) => {
    const logs = diagnostics.getLogs({
      eventType: req.query.event_type,
      campaignId: req.query.campaign_id
    });
    res.json({ logs });
  });

  // --- Seed Demo Data ---
  app.post('/api/seed', (req, res) => {
    seedDemoCampaigns(workflow, db);
    res.json({ success: true, message: 'Demo campaigns and historical metrics seeded.' });
  });

  // --- Run Automated LLD Tests via API ---
  app.post('/api/test/run-all', async (req, res) => {
    try {
      const { runAllTests } = await import('../tests/run-all-tests.js');
      const testReport = await runAllTests();
      res.json(testReport);
    } catch (err) {
      res.status(500).json({ error: { message: err.message } });
    }
  });

  // Serve static files in production (Flutter web build prioritized)
  const flutterDist = path.resolve(__dirname, '../bit_loggers_app/build/web');
  const reactDist = path.resolve(__dirname, '../dist');
  const clientDist = fs.existsSync(path.join(flutterDist, 'index.html')) ? flutterDist : reactDist;
  app.use(express.static(clientDist));

  // Catch-all SPA route
  app.get('*', (req, res, next) => {
    if (req.path.startsWith('/api') || req.path.startsWith('/campaigns')) {
      return next();
    }
    const indexPath = path.join(clientDist, 'index.html');
    res.sendFile(indexPath, (err) => {
      if (err) next();
    });
  });

  return { app, db, diagnostics, outbox, workflow, ai };
}

export function seedDemoCampaigns(workflow, db) {
  const marketer = workflow.getUser('usr-marketer-1');
  const reviewer = workflow.getUser('usr-reviewer-1');
  const complianceReviewer = workflow.getUser('usr-reviewer-2');

  const count = db.prepare('SELECT COUNT(*) as count FROM campaigns').get().count;
  if (count > 0) return;

  console.log('Seeding initial demo campaigns...');

  // 1. Summer Surge 2026 (Scheduled)
  const c1 = workflow.createCampaign(marketer, {
    title: 'Summer Solar Flash Sale',
    objective: 'Drive summer consumer adoption for eco-friendly home solar accessories.',
    target_audience: 'Homeowners aged 30-55 with interest in sustainability and renewable energy.',
    channel: 'Social',
    budget: 18500,
    kpi_projected: { conversionRate: 4.2, ctr: 4.8, roi: 4.6, cpa: 21.50, aov: 145.00 },
    ai_summary: 'Targeted Instagram & TikTok Reels campaign with high expected summer conversion.'
  });
  workflow.submitCampaign(c1.campaign_id, marketer, { idempotencyKey: 'seed-key-1' });
  workflow.makeDecision(c1.campaign_id, reviewer, {
    version_id: c1.current_version_id,
    decision: 'APPROVED',
    reason: 'Audience alignment is solid, budget is within Q2 limits, and projected ROI of 4.6x is well backed.'
  });
  const now = new Date();
  const nextWeek = new Date(now.getTime() + 7 * 86400000);
  workflow.scheduleCampaign(c1.campaign_id, marketer, {
    version_id: c1.current_version_id,
    starts_at: now.toISOString(),
    ends_at: nextWeek.toISOString(),
    channel: 'Social'
  });

  // 2. Black Friday Alpha (Changes Requested -> Revised)
  const c2 = workflow.createCampaign(marketer, {
    title: 'Black Friday Super Savings Pass',
    objective: 'Pre-launch exclusive membership pass for holiday buyers.',
    target_audience: 'Broad international consumer audience.',
    channel: 'Email',
    budget: 35000,
    kpi_projected: { conversionRate: 3.1, ctr: 3.5, roi: 3.2, cpa: 34.00, aov: 85.00 },
    ai_summary: 'Broad newsletter blitz across entire subscriber list.'
  });
  workflow.submitCampaign(c2.campaign_id, marketer, { idempotencyKey: 'seed-key-2' });
  workflow.makeDecision(c2.campaign_id, reviewer, {
    version_id: c2.current_version_id,
    decision: 'CHANGES_REQUESTED',
    reason: 'The proposed audience is too broad for the selected marketing channel. Narrow the audience to VIP segments and justify the $35,000 budget.'
  });
  // Marketer revises
  workflow.updateCampaign(c2.campaign_id, marketer, {
    target_audience: 'VIP tier past buyers with >$100 lifetime spend and loyalty engagement.',
    budget: 22000,
    kpi_projected: { conversionRate: 5.6, ctr: 6.2, roi: 5.1, cpa: 17.50, aov: 115.00 }
  });

  // 3. AI Copilot Launch (Submitted - Awaiting Review)
  const c3 = workflow.createCampaign(marketer, {
    title: 'Enterprise AI Assistant Rollout',
    objective: 'Drive enterprise B2B inbound demos for workflow intelligence.',
    target_audience: 'VP Marketing, CMOs, and Marketing Ops directors at Mid-Market tech companies.',
    channel: 'Search',
    budget: 28000,
    kpi_projected: { conversionRate: 4.8, ctr: 6.5, roi: 5.5, cpa: 42.00, aov: 240.00 },
    ai_summary: 'High-intent search keyword campaign targeting corporate marketing leaders.'
  });
  workflow.submitCampaign(c3.campaign_id, marketer, { idempotencyKey: 'seed-key-3' });

  // 4. Crypto Rewards Pilot (Rejected)
  const c4 = workflow.createCampaign(marketer, {
    title: 'Crypto Cashback Loyalty Boost',
    objective: 'Incentivize checkout using digital token cashback.',
    target_audience: 'Retail shoppers looking for speculative rewards.',
    channel: 'Display',
    budget: 15000,
    kpi_projected: { conversionRate: 1.5, ctr: 1.2, roi: 1.8, cpa: 55.00, aov: 60.00 },
    ai_summary: 'Display ad network blitz with crypto rebate hooks.'
  });
  workflow.submitCampaign(c4.campaign_id, marketer, { idempotencyKey: 'seed-key-4' });
  workflow.makeDecision(c4.campaign_id, complianceReviewer, {
    version_id: c4.current_version_id,
    decision: 'REJECTED',
    reason: 'Rejected because crypto cashback incentive violates organizational advertising standards and carries regulatory ambiguity in primary target regions.'
  });

  // Add discussions to campaigns
  workflow.postDiscussionMessage(c2.campaign_id, reviewer, {
    content: 'Please make sure to link the revised VIP cohort breakdown in your next submission.'
  });
  workflow.postDiscussionMessage(c2.campaign_id, marketer, {
    content: 'Updated! Cohort narrowed to top 15% spenders with trimmed budget of $22,000.'
  });

  console.log('Seeding complete.');
}
