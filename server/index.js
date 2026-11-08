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
import { generateEnterpriseSyntheticData } from './synthetic-data.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export async function createApp() {
  const app = express();
  app.use(cors());
  app.use(express.json());

  // Initialize modular services with PostgreSQL + TimescaleDB
  const db = await initDatabase();
  await seedKpiSnapshots(db);
  const diagnostics = new Diagnostics(db);
  const outbox = new OutboxService(db, diagnostics);
  const workflow = new WorkflowService(db, diagnostics, outbox);
  const ai = new AIService(diagnostics);

  // Correlation ID & Context Middleware
  app.use(async (req, res, next) => {
    const correlationId = req.headers['x-correlation-id'] || 'c-' + crypto.randomUUID().slice(0, 8);
    req.correlationId = correlationId;
    res.setHeader('X-Correlation-ID', correlationId);

    // Identify user from header or default to Marketer
    const userId = req.headers['x-user-id'] || 'usr-marketer-1';
    req.user = (await workflow.getUser(userId)) || (await workflow.getUser('usr-marketer-1'));

    next();
  });

  // --- Auth / Users ---
  app.get('/api/users', async (req, res) => {
    const users = await workflow.getUsers();
    res.json({ users, currentUser: req.user });
  });

  app.get('/api/users/me', (req, res) => {
    res.json({ user: req.user });
  });

  // --- Campaigns List & Details ---
  app.get('/api/campaigns', async (req, res) => {
    const { status, channel, owner_id } = req.query;
    const campaigns = await workflow.listCampaigns({ status, channel, owner_id });
    res.json({ campaigns });
  });

  app.get('/api/campaigns/:id', async (req, res) => {
    const campaign = await workflow.getCampaignDetails(req.params.id);
    if (!campaign) {
      return res.status(404).json({
        error: { code: 'CAMPAIGN_NOT_FOUND', message: 'Campaign does not exist.', correlation_id: req.correlationId }
      });
    }
    res.json(campaign);
  });

  app.post('/api/campaigns', async (req, res) => {
    try {
      const campaign = await workflow.createCampaign(req.user, req.body, req.correlationId);
      res.status(201).json(campaign);
    } catch (err) {
      res.status(err.status || 500).json({
        error: { code: err.code || 'INTERNAL_ERROR', message: err.message, correlation_id: req.correlationId }
      });
    }
  });

  app.put('/api/campaigns/:id', async (req, res) => {
    const expectedVersion = req.headers['x-expected-version'] || req.body.expected_version;
    try {
      const campaign = await workflow.updateCampaign(req.params.id, req.user, req.body, {
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

  // --- Concurrency / Edit Lock (LLD Section 9, FR-14) ---
  app.post('/api/campaigns/:id/lock', async (req, res) => {
    const result = await workflow.acquireEditLock(req.params.id, req.user, req.correlationId);
    if (!result.granted) {
      return res.status(409).json({
        error: { code: 'EDIT_LOCK_HELD', message: result.message, holder: result.holder_name, expires_at: result.expires_at, correlation_id: req.correlationId }
      });
    }
    res.json(result);
  });

  app.delete('/api/campaigns/:id/lock', async (req, res) => {
    await workflow.releaseEditLock(req.params.id, req.user.id);
    res.json({ success: true });
  });

  // --- Campaign Submission (LLD Section 8, FR-03, T-08) ---
  const handleSubmit = async (req, res) => {
    const idempotencyKey = req.headers['idempotency-key'] || req.headers['x-idempotency-key'] || req.body.idempotency_key;
    try {
      const result = await workflow.submitCampaign(req.params.id, req.user, {
        idempotencyKey,
        correlationId: req.correlationId
      });
      res.json(result);
    } catch (err) {
      res.status(err.status || 500).json({
        error: { code: err.code || 'SUBMIT_FAILED', message: err.message, correlation_id: req.correlationId }
      });
    }
  };

  app.post('/api/campaigns/:id/submit', handleSubmit);
  app.post('/campaigns/:id/submit', handleSubmit);

  // --- Reviewer Decisions (LLD Section 2, 3, 6, FR-05) ---
  const handleDecision = (decisionType) => async (req, res) => {
    const { version_id, reason, policy_reference } = req.body;
    try {
      const result = await workflow.makeDecision(req.params.id, req.user, {
        versionId: version_id,
        decision: decisionType,
        reason,
        policyRef: policy_reference,
        correlationId: req.correlationId
      });
      res.json(result);
    } catch (err) {
      res.status(err.status || 500).json({
        error: { code: err.code || 'DECISION_FAILED', message: err.message, correlation_id: req.correlationId }
      });
    }
  };

  app.post('/api/campaigns/:id/approve', handleDecision('APPROVED'));
  app.post('/campaigns/:id/approve', handleDecision('APPROVED'));

  app.post('/api/campaigns/:id/request-changes', handleDecision('CHANGES_REQUESTED'));
  app.post('/campaigns/:id/request-changes', handleDecision('CHANGES_REQUESTED'));

  app.post('/api/campaigns/:id/reject', handleDecision('REJECTED'));
  app.post('/campaigns/:id/reject', handleDecision('REJECTED'));

  // --- Scheduling (LLD Section 7, FR-07) ---
  const handleSchedule = async (req, res) => {
    const { version_id, starts_at, ends_at, channel } = req.body;
    try {
      const result = await workflow.scheduleCampaign(req.params.id, req.user, {
        versionId: version_id,
        startsAt: starts_at,
        endsAt: ends_at,
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
  const handleDecisionsGet = async (req, res) => {
    const decisionsRes = await db.query(
      `SELECT d.*, u.name as reviewer_name 
       FROM approval_decisions d
       JOIN users u ON d.reviewer_id = u.user_id
       WHERE d.campaign_id = $1
       ORDER BY d.created_at DESC`,
      [req.params.id]
    );
    res.json({ decisions: decisionsRes.rows });
  };

  app.get('/api/campaigns/:id/decisions', handleDecisionsGet);
  app.get('/campaigns/:id/decisions', handleDecisionsGet);

  const handleVersionsGet = async (req, res) => {
    const versionsRes = await db.query(
      `SELECT * FROM campaign_versions 
       WHERE campaign_id = $1 
       ORDER BY version_no ASC`,
      [req.params.id]
    );
    res.json({
      versions: versionsRes.rows.map(v => ({
        ...v,
        kpi_projected: typeof v.kpi_projected === 'string' ? JSON.parse(v.kpi_projected) : v.kpi_projected,
        kpi_actual: v.kpi_actual && typeof v.kpi_actual === 'string' ? JSON.parse(v.kpi_actual) : v.kpi_actual
      }))
    });
  };

  app.get('/api/campaigns/:id/versions', handleVersionsGet);
  app.get('/campaigns/:id/versions', handleVersionsGet);

  // --- Collaboration / Discussions (Pillar 4, FR-12) ---
  app.get('/api/campaigns/:id/collaborators', async (req, res) => {
    try {
      const collaborators = await workflow.getCollaborators(req.params.id);
      res.json({ collaborators });
    } catch (err) {
      res.status(500).json({ error: { message: err.message } });
    }
  });

  app.get('/api/campaigns/:id/discussions', async (req, res) => {
    const { version_id } = req.query;
    const messages = await workflow.getDiscussions(req.params.id, {
      versionId: version_id,
      user: req.user
    });
    res.json({ messages });
  });

  app.post('/api/campaigns/:id/discussions', async (req, res) => {
    try {
      const msg = await workflow.postDiscussionMessage(req.params.id, req.user, req.body);
      res.status(201).json(msg);
    } catch (err) {
      res.status(400).json({ error: { message: err.message } });
    }
  });

  // --- Notifications (Pillar 4, FR-13) ---
  app.get('/api/notifications', async (req, res) => {
    const notifsRes = await db.query(
      `SELECT * FROM notifications 
       WHERE recipient_id = $1 
       ORDER BY created_at DESC 
       LIMIT 50`,
      [req.user.id]
    );

    const countRes = await db.query(
      `SELECT COUNT(*) as count FROM notifications
       WHERE recipient_id = $1 AND is_read = FALSE`,
      [req.user.id]
    );

    res.json({
      notifications: notifsRes.rows,
      unreadCount: Number(countRes.rows[0].count)
    });
  });

  app.post('/api/notifications/:id/read', async (req, res) => {
    await db.query(
      'UPDATE notifications SET is_read = TRUE WHERE notification_id = $1 AND recipient_id = $2',
      [req.params.id, req.user.id]
    );
    res.json({ success: true });
  });

  app.post('/api/notifications/read-all', async (req, res) => {
    await db.query('UPDATE notifications SET is_read = TRUE WHERE recipient_id = $1', [req.user.id]);
    res.json({ success: true });
  });

  // --- Outbox Management & Testing (FR-14, ADR-004, T-12) ---
  app.get('/api/outbox', async (req, res) => {
    const eventsRes = await db.query('SELECT * FROM outbox_events ORDER BY created_at DESC LIMIT 50');
    const statsRes = await db.query(`
      SELECT 
        COUNT(*) FILTER (WHERE status = 'PENDING') AS pending,
        COUNT(*) FILTER (WHERE status = 'PROCESSED') AS processed,
        COUNT(*) FILTER (WHERE status = 'FAILED') AS failed
      FROM outbox_events
    `);
    res.json({
      events: eventsRes.rows,
      stats: {
        pending: Number(statsRes.rows[0]?.pending || 0),
        processed: Number(statsRes.rows[0]?.processed || 0),
        failed: Number(statsRes.rows[0]?.failed || 0),
      },
      isEmailServiceFailing: outbox.isEmailServiceFailing
    });
  });

  app.post('/api/outbox/process', async (req, res) => {
    const results = await outbox.processPendingEvents();
    res.json({ processed: results });
  });

  app.post('/api/outbox/toggle-email-failure', (req, res) => {
    const failing = req.body.failing !== undefined ? req.body.failing : !outbox.isEmailServiceFailing;
    outbox.setEmailFailing(failing);
    res.json({ isEmailServiceFailing: outbox.isEmailServiceFailing });
  });

  // --- Offline Mobile Sync Queue Endpoint (FR-13, FR-14, ADR-005) ---
  app.post('/api/sync/queue', async (req, res) => {
    const { actions = [] } = req.body;
    const response = await workflow.processSyncQueue(req.user, actions, {
      correlationId: req.correlationId
    });
    res.json(response);
  });

  // --- AI Assistance (Pillar 4, FR-10, FR-11, T-13) ---
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

  // --- Analytics & KPIs with TimescaleDB time_bucket (Pillar 2, FR-09) ---
  app.get('/api/analytics', async (req, res) => {
    const data = await workflow.getAnalytics({
      channel: req.query.channel,
      startDate: req.query.start_date,
      endDate: req.query.end_date,
      bucketInterval: req.query.interval || '1 day'
    });
    res.json(data);
  });

  // --- Calendar & Schedules (Pillar 3, FR-08) ---
  app.get('/api/calendar', async (req, res) => {
    const events = await workflow.getCalendarEvents();
    res.json({ events });
  });

  // --- TimescaleDB Audit Trail & Diagnostics (Pillar 3 & 5, FR-15) ---
  app.get('/api/audit', async (req, res) => {
    let sql = 'SELECT * FROM audit_events';
    const conditions = [];
    const params = [];

    if (req.query.campaign_id) {
      params.push(req.query.campaign_id);
      conditions.push(`campaign_id = $${params.length}`);
    }
    if (req.query.event_type && req.query.event_type.toUpperCase() !== 'ALL') {
      params.push(req.query.event_type.toUpperCase());
      conditions.push(`event_type = $${params.length}`);
    }
    if (req.query.search) {
      params.push(`%${req.query.search}%`);
      conditions.push(`(summary ILIKE $${params.length} OR actor_name ILIKE $${params.length} OR details::text ILIKE $${params.length} OR event_id ILIKE $${params.length})`);
    }

    if (conditions.length > 0) {
      sql += ' WHERE ' + conditions.join(' AND ');
    }
    sql += ' ORDER BY created_at DESC LIMIT 150';

    const auditRes = await db.query(sql, params);
    res.json({ audit: auditRes.rows });
  });

  app.get('/api/diagnostics', async (req, res) => {
    const logs = await diagnostics.getLogs({
      eventType: req.query.event_type,
      campaignId: req.query.campaign_id
    });
    res.json({ logs });
  });

  // --- Funnel & Hourly Telemetry Endpoints ---
  app.get('/api/analytics/funnel', async (req, res) => {
    try {
      const channel = req.query.channel;
      const params = [];
      let whereClause = '';
      if (channel && channel !== 'All') {
        params.push(channel);
        whereClause = `WHERE channel = $1`;
      }
      const result = await db.query(`
        SELECT 
          COALESCE(SUM(impressions), 0) as total_impressions,
          COALESCE(SUM(clicks), 0) as total_clicks,
          COALESCE(SUM(spend), 0) as total_spend,
          COALESCE(SUM(conversions), 0) as total_conversions,
          COALESCE(SUM(revenue), 0) as total_revenue,
          CASE WHEN SUM(impressions) > 0 THEN ROUND((SUM(clicks)::numeric / SUM(impressions)::numeric) * 100, 2) ELSE 0 END as overall_ctr,
          CASE WHEN SUM(clicks) > 0 THEN ROUND((SUM(conversions)::numeric / SUM(clicks)::numeric) * 100, 2) ELSE 0 END as overall_cvr,
          CASE WHEN SUM(conversions) > 0 THEN ROUND((SUM(spend)::numeric / SUM(conversions)::numeric), 2) ELSE 0 END as overall_cpa,
          CASE WHEN SUM(spend) > 0 THEN ROUND(((SUM(revenue) - SUM(spend))::numeric / SUM(spend)::numeric), 2) ELSE 0 END as overall_roi
        FROM kpi_metric_snapshots
        ${whereClause}
      `, params);
      res.json({ funnel: result.rows[0] });
    } catch (err) {
      res.status(500).json({ error: { message: err.message } });
    }
  });

  app.get('/api/analytics/hourly', async (req, res) => {
    try {
      const result = await db.query(`
        SELECT 
          recorded_at,
          channel,
          impressions,
          clicks,
          spend,
          conversions,
          revenue,
          conversion_rate,
          ctr,
          cpa,
          roi
        FROM kpi_metric_snapshots
        WHERE snapshot_id LIKE 'synth-hourly-%'
        ORDER BY recorded_at ASC
      `);
      res.json({ hourly: result.rows });
    } catch (err) {
      res.status(500).json({ error: { message: err.message } });
    }
  });

  // --- Seed Enterprise Synthetic Data ---
  app.post('/api/seed', async (req, res) => {
    try {
      const result = await generateEnterpriseSyntheticData(workflow, db, { force: true });
      res.json({ 
        success: true, 
        message: 'Enterprise MarTech synthetic data successfully generated and seeded in PostgreSQL + TimescaleDB.',
        result
      });
    } catch (err) {
      console.error('[SEED] Error generating enterprise synthetic data:', err);
      res.status(500).json({ error: { message: err.message } });
    }
  });

  app.post('/api/seed/calendar', async (req, res) => {
    await seedCalendarFlights(workflow, db, { force: true });
    res.json({ success: true, message: 'Sample calendar flights seeded successfully.' });
  });

  // --- Run Automated Architecture Tests via API ---
  app.post('/api/test/run-all', async (req, res) => {
    try {
      const { runAllTests } = await import('../tests/run-all-tests.js');
      const testReport = await runAllTests();
      res.json(testReport);
    } catch (err) {
      res.status(500).json({ error: { message: err.message } });
    }
  });

  // Serve static files: React Landing Page at dist/
  const reactDist = path.resolve(__dirname, '../dist');
  const downloadsDir = path.resolve(__dirname, '../downloads');
  if (fs.existsSync(downloadsDir)) {
    app.use('/downloads', express.static(downloadsDir));
  }
  app.use(express.static(reactDist));

  // Catch-all SPA route for landing page
  app.get('*', (req, res, next) => {
    if (req.path.startsWith('/api') || req.path.startsWith('/campaigns')) {
      return next();
    }
    const indexPath = path.join(reactDist, 'index.html');
    res.sendFile(indexPath, (err) => {
      if (err) next();
    });
  });

  return { app, db, diagnostics, outbox, workflow, ai };
}

export async function seedDemoCampaigns(workflow, db) {
  const countRes = await db.query('SELECT COUNT(*) as count FROM campaigns');
  if (parseInt(countRes.rows[0].count, 10) > 0) return;

  console.log('[DATABASE] Seeding initial enterprise campaigns into PostgreSQL + TimescaleDB...');
  await generateEnterpriseSyntheticData(workflow, db, { force: false });
  console.log('✅ [DATABASE] Seeding complete.');
}

export async function seedKpiSnapshots(db) {
  try {
    const countRes = await db.query('SELECT COUNT(*) as count FROM kpi_metric_snapshots');
    if (parseInt(countRes.rows[0].count, 10) > 0) return;

    console.log('[DATABASE] Seeding TimescaleDB hypertable kpi_metric_snapshots (30 days telemetry)...');
    const channels = ['Social', 'Search', 'Email', 'Display'];
    const baseMetrics = {
      Social: { conv: 4.2, ctr: 4.8, roi: 4.6, cpa: 21.5, aov: 145.0 },
      Search: { conv: 4.8, ctr: 6.5, roi: 5.5, cpa: 42.0, aov: 240.0 },
      Email: { conv: 3.5, ctr: 4.1, roi: 3.8, cpa: 28.0, aov: 95.0 },
      Display: { conv: 1.8, ctr: 1.6, roi: 2.1, cpa: 48.0, aov: 75.0 }
    };

    const now = Date.now();
    for (let dayOffset = 30; dayOffset >= 0; dayOffset--) {
      const timestamp = new Date(now - dayOffset * 86400000).toISOString();
      for (const ch of channels) {
        const base = baseMetrics[ch];
        const jitter = (Math.sin(dayOffset * 0.7 + ch.length) * 0.15);

        // Projected snapshot
        await db.query(
          `INSERT INTO kpi_metric_snapshots (snapshot_id, recorded_at, campaign_id, channel, conversion_rate, ctr, roi, cpa, aov, is_actual)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
           ON CONFLICT DO NOTHING`,
          [
            `snap-proj-${ch}-${dayOffset}`,
            timestamp,
            `camp-${ch.toLowerCase()}`,
            ch,
            Math.max(0.5, (base.conv * (1 + jitter * 0.5)).toFixed(2)),
            Math.max(0.5, (base.ctr * (1 + jitter * 0.5)).toFixed(2)),
            Math.max(0.5, (base.roi * (1 + jitter * 0.4)).toFixed(2)),
            Math.max(1.0, (base.cpa * (1 - jitter * 0.3)).toFixed(2)),
            Math.max(10.0, (base.aov * (1 + jitter * 0.3)).toFixed(2)),
            false
          ]
        );

        // Actual telemetry snapshot
        const actualJitter = (Math.cos(dayOffset * 0.5 + ch.length * 2) * 0.22);
        await db.query(
          `INSERT INTO kpi_metric_snapshots (snapshot_id, recorded_at, campaign_id, channel, conversion_rate, ctr, roi, cpa, aov, is_actual)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
           ON CONFLICT DO NOTHING`,
          [
            `snap-act-${ch}-${dayOffset}`,
            timestamp,
            `camp-${ch.toLowerCase()}`,
            ch,
            Math.max(0.5, (base.conv * (1 + actualJitter)).toFixed(2)),
            Math.max(0.5, (base.ctr * (1 + actualJitter * 0.9)).toFixed(2)),
            Math.max(0.5, (base.roi * (1 + actualJitter * 1.1)).toFixed(2)),
            Math.max(1.0, (base.cpa * (1 - actualJitter * 0.8)).toFixed(2)),
            Math.max(10.0, (base.aov * (1 + actualJitter * 0.7)).toFixed(2)),
            true
          ]
        );
      }
    }
    console.log('✅ [DATABASE] 30-day KPI hypertable snapshots seeded.');
  } catch (err) {
    console.warn('[DATABASE] Could not seed kpi_metric_snapshots:', err.message);
  }
}

export async function seedCalendarFlights(workflow, db, { force = false } = {}) {
  try {
    const countRes = await db.query('SELECT COUNT(*) as count FROM schedules');
    const existingCount = parseInt(countRes.rows[0].count, 10);
    if (!force && existingCount >= 3) {
      console.log(`[CALENDAR] Found ${existingCount} existing scheduled flights in PostgreSQL.`);
      return;
    }

    console.log('[CALENDAR] Seeding sample multi-channel flight schedules across current calendar window...');
    const marketer = await workflow.getUser('usr-marketer-1');
    const reviewer = await workflow.getUser('usr-reviewer-1');

    const now = Date.now();
    const dayMs = 86400000;

    // Check if we already have approved or enterprise campaigns in the database
    const existingCamps = await db.query(
      `SELECT c.campaign_id, c.title, c.status, c.current_version_id, v.channel, v.budget
       FROM campaigns c
       JOIN campaign_versions v ON c.current_version_id = v.version_id
       ORDER BY c.created_at ASC`
    );

    if (existingCamps.rows.length >= 3) {
      // Clear out old schedules if forcing
      if (force) {
        await db.query('DELETE FROM schedules');
      }

      // Schedule real existing campaigns across the current calendar timeframe (including today)
      const flightPlans = [
        { titleMatch: 'Cyber Week', channel: 'Social', startOffset: -2, endOffset: 12 },
        { titleMatch: 'VIP Loyalty', channel: 'Email', startOffset: -1, endOffset: 3 },
        { titleMatch: 'Summer Solar', channel: 'Search', startOffset: 4, endOffset: 11 },
        { titleMatch: 'Weekend Flash', channel: 'Display', startOffset: 1, endOffset: 5 }
      ];

      for (const fp of flightPlans) {
        const found = existingCamps.rows.find(c => c.title.toLowerCase().includes(fp.titleMatch.toLowerCase()));
        if (found) {
          const startsAt = new Date(now + fp.startOffset * dayMs);
          const endsAt = new Date(now + fp.endOffset * dayMs);

          // Ensure campaign has an approved decision before scheduling
          const decCheck = await db.query(
            "SELECT * FROM approval_decisions WHERE version_id = $1 AND decision_type = 'APPROVED'",
            [found.current_version_id]
          );
          if (decCheck.rows.length === 0) {
            await workflow.makeDecision(found.campaign_id, reviewer, {
              versionId: found.current_version_id,
              decision: 'APPROVED',
              reason: 'Pre-flight executive calendar approval.'
            });
          }

          // Check if schedule already exists for this campaign
          const schedCheck = await db.query('SELECT * FROM schedules WHERE campaign_id = $1', [found.campaign_id]);
          if (schedCheck.rows.length === 0) {
            await workflow.scheduleCampaign(found.campaign_id, marketer, {
              versionId: found.current_version_id,
              channel: fp.channel,
              startsAt: startsAt.toISOString(),
              endsAt: endsAt.toISOString()
            });
          }
        }
      }

      console.log(`✅ [CALENDAR] Aligned calendar schedules with existing home page enterprise campaigns.`);
      return;
    }

    const sampleFlights = [
      {
        title: 'Q4 Festive Creator Blitz',
        objective: 'Partner with top lifestyle creators for seasonal gift guide features.',
        target_audience: 'Urban digital consumers aged 22-38 with high social commerce affinity.',
        channel: 'Social',
        budget: 28000,
        startOffsetDays: -2,
        endOffsetDays: 5,
        decisionReason: 'Verified influencer tier pricing and high-intent creator roster for Q4.'
      },
      {
        title: 'High-Intent Holiday Search Surge',
        objective: 'Capture high-intent holiday shoppers searching for luxury home goods.',
        target_audience: 'Active searchers with purchase intent for home electronics and decor.',
        channel: 'Search',
        budget: 36000,
        startOffsetDays: -1,
        endOffsetDays: 7,
        decisionReason: 'Search keyword bid ceiling verified under $4.20 with expected 5.2x ROI.'
      },
      {
        title: 'VIP Loyalty Early-Bird Pass',
        objective: 'Exclusive 48-hour early shopping pass for gold tier loyalty members.',
        target_audience: 'Top 10% repeat buyers with lifetime spend exceeding $250.',
        channel: 'Email',
        budget: 16500,
        startOffsetDays: 0,
        endOffsetDays: 4,
        decisionReason: 'Segmented VIP cohort with historical 6.8% conversion rate.'
      },
      {
        title: 'Omnichannel Cart Recovery Network',
        objective: 'Re-engage checkout abandonment users across programmatic display inventory.',
        target_audience: 'Users who added items to checkout within the last 72 hours.',
        channel: 'Display',
        budget: 14000,
        startOffsetDays: 2,
        endOffsetDays: 10,
        decisionReason: 'Retargeting frequency capped at 3 impressions per user per 24 hours.'
      },
      {
        title: 'YouTube Prime Holiday Anthem',
        objective: 'Build brand equity and prime unboxing demand through 15s non-skippable CTV ads.',
        target_audience: 'Connected TV households with interest in technology and lifestyle.',
        channel: 'Video',
        budget: 44000,
        startOffsetDays: 3,
        endOffsetDays: 14,
        decisionReason: 'CTV inventory guaranteed through direct programmatic private marketplace.'
      },
      {
        title: 'Weekend Flash Countdown Deals',
        objective: 'Urgency-driven weekend social promotion for limited-quantity doorbusters.',
        target_audience: 'Mobile shoppers looking for limited-time flash discount codes.',
        channel: 'Social',
        budget: 19000,
        startOffsetDays: 6,
        endOffsetDays: 10,
        decisionReason: 'Approved as secondary flash flight with tight 4-day flight duration.'
      }
    ];

    for (let i = 0; i < sampleFlights.length; i++) {
      const item = sampleFlights[i];
      const camp = await workflow.createCampaign(marketer, {
        title: item.title,
        objective: item.objective,
        target_audience: item.target_audience,
        channel: item.channel,
        budget: item.budget,
        kpi_projected: { conversionRate: 4.5, ctr: 5.2, roi: 4.8, cpa: 22.0, aov: 130.0 }
      });

      await workflow.submitCampaign(camp.campaign_id, marketer, {
        idempotencyKey: `seed-sched-${camp.campaign_id}-${i}`
      });

      await workflow.makeDecision(camp.campaign_id, reviewer, {
        versionId: camp.current_version_id,
        decision: 'APPROVED',
        reason: item.decisionReason
      });

      const startsAt = new Date(now + item.startOffsetDays * dayMs);
      const endsAt = new Date(now + item.endOffsetDays * dayMs);

      await workflow.scheduleCampaign(camp.campaign_id, marketer, {
        versionId: camp.current_version_id,
        channel: item.channel,
        startsAt: startsAt.toISOString(),
        endsAt: endsAt.toISOString()
      });
    }

    console.log(`✅ [CALENDAR] Successfully seeded ${sampleFlights.length} sample flight schedules into PostgreSQL!`);
  } catch (err) {
    console.error('[CALENDAR] Error seeding sample flights:', err.message);
  }
}
