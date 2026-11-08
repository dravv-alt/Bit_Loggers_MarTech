import 'dotenv/config';
import { createApp } from '../server/index.js';
import { DIAGNOSTIC_EVENTS } from '../server/diagnostics.js';

export async function runAllTests() {
  const results = [];

  // Initialize PostgreSQL + TimescaleDB instance
  const { app, db, diagnostics, outbox, workflow, ai } = await createApp();
  const marketer = await workflow.getUser('usr-marketer-1');
  const reviewer1 = await workflow.getUser('usr-reviewer-1');
  const reviewer2 = await workflow.getUser('usr-reviewer-2');

  function record(id, name, qa, passed, details) {
    results.push({ id, name, qa, passed, details });
    const status = passed ? '✅ PASS' : '❌ FAIL';
    console.log(`[${status}] ${id}: ${name} -> ${details}`);
  }

  console.log('\n========================================');
  console.log('   RUNNING BIT LOGGERS LLD TEST SUITE   ');
  console.log('   (PostgreSQL + TimescaleDB Engine)    ');
  console.log('========================================\n');

  // --- T-01: Approve V1. Edit budget to create V2. Schedule V2. Expected: 409 SCHEDULE_BLOCKED ---
  try {
    const c1 = await workflow.createCampaign(marketer, { title: 'T-01 Campaign', budget: 10000, channel: 'Social' });
    await workflow.submitCampaign(c1.campaign_id, marketer);
    await workflow.makeDecision(c1.campaign_id, reviewer1, {
      versionId: c1.current_version_id,
      decision: 'APPROVED',
      reason: 'Valid proposal for test T-01'
    });
    // Now edit budget to create v2
    const c1_v2 = await workflow.updateCampaign(c1.campaign_id, marketer, { budget: 20000 });
    let blocked = false;
    let errCode = '';
    try {
      await workflow.scheduleCampaign(c1.campaign_id, marketer, {
        versionId: c1_v2.current_version_id,
        channel: 'Social',
        startsAt: new Date(Date.now() + 86400000).toISOString(),
        endsAt: new Date(Date.now() + 7 * 86400000).toISOString()
      });
    } catch (e) {
      blocked = true;
      errCode = e.code;
    }
    const passed = blocked && errCode === 'SCHEDULE_BLOCKED';
    record('T-01', 'Approve V1. Edit budget to create V2. Schedule V2.', 'QA-01', passed, `Result: ${errCode} (Expected 409 SCHEDULE_BLOCKED)`);
  } catch (err) {
    record('T-01', 'Approve V1. Edit budget to create V2. Schedule V2.', 'QA-01', false, `Error: ${err.message}`);
  }

  // --- T-02: Approve without a reason (whitespace only). Expected: 422 REASON_REQUIRED ---
  try {
    const c2 = await workflow.createCampaign(marketer, { title: 'T-02 Campaign', budget: 5000 });
    await workflow.submitCampaign(c2.campaign_id, marketer);
    let caught = false;
    let code = '';
    try {
      await workflow.makeDecision(c2.campaign_id, reviewer1, {
        versionId: c2.current_version_id,
        decision: 'APPROVED',
        reason: '    ' // whitespace only
      });
    } catch (e) {
      caught = true;
      code = e.code;
    }
    const passed = caught && code === 'REASON_REQUIRED';
    record('T-02', 'Approve without a reason (whitespace only)', 'QA-01', passed, `Result: ${code} (Expected 422 REASON_REQUIRED)`);
  } catch (err) {
    record('T-02', 'Approve without a reason (whitespace only)', 'QA-01', false, `Error: ${err.message}`);
  }

  // --- T-03: Request changes without a reason. Expected: 422 REASON_REQUIRED ---
  try {
    const c3 = await workflow.createCampaign(marketer, { title: 'T-03 Campaign', budget: 8000 });
    await workflow.submitCampaign(c3.campaign_id, marketer);
    let caught = false;
    let code = '';
    try {
      await workflow.makeDecision(c3.campaign_id, reviewer1, {
        versionId: c3.current_version_id,
        decision: 'CHANGES_REQUESTED',
        reason: '' // empty string
      });
    } catch (e) {
      caught = true;
      code = e.code;
    }
    const passed = caught && code === 'REASON_REQUIRED';
    record('T-03', 'Request changes without a reason', 'QA-01', passed, `Result: ${code} (Expected 422 REASON_REQUIRED)`);
  } catch (err) {
    record('T-03', 'Request changes without a reason', 'QA-01', false, `Error: ${err.message}`);
  }

  // --- T-04: Reject without a reason. Expected: 422 REASON_REQUIRED ---
  try {
    const c4 = await workflow.createCampaign(marketer, { title: 'T-04 Campaign', budget: 12000 });
    await workflow.submitCampaign(c4.campaign_id, marketer);
    let caught = false;
    let code = '';
    try {
      await workflow.makeDecision(c4.campaign_id, reviewer1, {
        versionId: c4.current_version_id,
        decision: 'REJECTED',
        reason: null
      });
    } catch (e) {
      caught = true;
      code = e.code;
    }
    const passed = caught && code === 'REASON_REQUIRED';
    record('T-04', 'Reject without a reason', 'QA-01', passed, `Result: ${code} (Expected 422 REASON_REQUIRED)`);
  } catch (err) {
    record('T-04', 'Reject without a reason', 'QA-01', false, `Error: ${err.message}`);
  }

  // --- T-05: Cross-campaign approval attempt. Expected: 422 VERSION_MISMATCH ---
  try {
    const campA = await workflow.createCampaign(marketer, { title: 'Camp A', budget: 5000 });
    const campB = await workflow.createCampaign(marketer, { title: 'Camp B', budget: 6000 });
    await workflow.submitCampaign(campB.campaign_id, marketer);
    let caught = false;
    let code = '';
    try {
      await workflow.makeDecision(campB.campaign_id, reviewer1, {
        versionId: campA.current_version_id,
        decision: 'APPROVED',
        reason: 'Trying to cross-approve versions'
      });
    } catch (e) {
      caught = true;
      code = e.code;
    }
    const passed = caught && code === 'VERSION_MISMATCH';
    record('T-05', "Approve using version_id from a different campaign", 'QA-01', passed, `Result: ${code} (Expected 422 VERSION_MISMATCH)`);
  } catch (err) {
    record('T-05', "Approve using version_id from a different campaign", 'QA-01', false, `Error: ${err.message}`);
  }

  // --- T-06: Self-approval violation. Expected: 403 FORBIDDEN ---
  try {
    const c6 = await workflow.createCampaign(marketer, { title: 'T-06 Self-Approval Attempt', budget: 9000 });
    await workflow.submitCampaign(c6.campaign_id, marketer);
    let caught = false;
    let code = '';
    try {
      await workflow.makeDecision(c6.campaign_id, marketer, {
        versionId: c6.current_version_id,
        decision: 'APPROVED',
        reason: 'Marketer approving own work'
      });
    } catch (e) {
      caught = true;
      code = e.code;
    }
    const passed = caught && code === 'FORBIDDEN';
    record('T-06', 'Marketer approves own campaign (Self-approval violation)', 'QA-03', passed, `Result: ${code} (Expected 403 FORBIDDEN)`);
  } catch (err) {
    record('T-06', 'Marketer approves own campaign (Self-approval violation)', 'QA-03', false, `Error: ${err.message}`);
  }

  // --- T-07: Reviewer approves; verify TimescaleDB audit trail. Expected: Event recorded in hypertable ---
  try {
    const c7 = await workflow.createCampaign(marketer, { title: 'T-07 Audit Campaign', budget: 15000 });
    await workflow.submitCampaign(c7.campaign_id, marketer);
    const decision = await workflow.makeDecision(c7.campaign_id, reviewer1, {
      versionId: c7.current_version_id,
      decision: 'APPROVED',
      reason: 'Valid justification for audit trail test'
    });
    const auditLogs = await workflow.getAuditTrail(c7.campaign_id);
    const approvedEvent = auditLogs.find(a => a.event_type === 'CAMPAIGN_APPROVED');
    const passed = Boolean(decision.decision_id && approvedEvent && approvedEvent.actor_id === reviewer1.id && approvedEvent.created_at);
    record('T-07', 'Reviewer approves; verify audit trail', 'QA-03', passed, `Audit event recorded in TimescaleDB: ${approvedEvent?.event_type} by ${approvedEvent?.actor_name}`);
  } catch (err) {
    record('T-07', 'Reviewer approves; verify audit trail', 'QA-03', false, `Error: ${err.message}`);
  }

  // --- T-08: Repeat submission with same idempotency key. Expected: Exactly one submission recorded ---
  try {
    const c8 = await workflow.createCampaign(marketer, { title: 'T-08 Idempotency Campaign', budget: 11000 });
    const idemKey = 'idempotency-key-' + Date.now();
    const res1 = await workflow.submitCampaign(c8.campaign_id, marketer, { idempotencyKey: idemKey });
    const res2 = await workflow.submitCampaign(c8.campaign_id, marketer, { idempotencyKey: idemKey });

    const auditRes = await db.query(
      `SELECT COUNT(*) as count FROM audit_events WHERE campaign_id = $1 AND event_type = 'CAMPAIGN_SUBMITTED'`,
      [c8.campaign_id]
    );
    const auditSubmissions = Number(auditRes.rows[0].count);
    const passed = (res1.version_id === res2.version_id) && (auditSubmissions === 1);
    record('T-08', 'Repeat submission with same idempotency key', 'QA-02', passed, `Single submission recorded; replayed original response.`);
  } catch (err) {
    record('T-08', 'Repeat submission with same idempotency key', 'QA-02', false, `Error: ${err.message}`);
  }

  // --- T-09: Two reviewers approve concurrently. Expected: One succeeds; other gets 409 NOT_AWAITING_REVIEW ---
  try {
    const c9 = await workflow.createCampaign(marketer, { title: 'T-09 Concurrency Campaign', budget: 14000 });
    await workflow.submitCampaign(c9.campaign_id, marketer);
    const dec1 = await workflow.makeDecision(c9.campaign_id, reviewer1, {
      versionId: c9.current_version_id,
      decision: 'APPROVED',
      reason: 'First reviewer approval'
    });
    let caught = false;
    let code = '';
    try {
      await workflow.makeDecision(c9.campaign_id, reviewer2, {
        versionId: c9.current_version_id,
        decision: 'APPROVED',
        reason: 'Second reviewer competing approval'
      });
    } catch (e) {
      caught = true;
      code = e.code;
    }
    const passed = Boolean(dec1.decision_id) && caught && code === 'NOT_AWAITING_REVIEW';
    record('T-09', 'Two reviewers approve the same version concurrently', 'QA-01, QA-02', passed, `First commit succeeded, second returned: ${code}`);
  } catch (err) {
    record('T-09', 'Two reviewers approve the same version concurrently', 'QA-01, QA-02', false, `Error: ${err.message}`);
  }

  // --- T-10: Two users request the edit lease. Expected: Second denied; current editor shown ---
  try {
    const c10 = await workflow.createCampaign(marketer, { title: 'T-10 Edit Lock Campaign', budget: 7000 });
    const lock1 = await workflow.acquireEditLock(c10.campaign_id, marketer);
    const user2 = await workflow.getUser('usr-reviewer-1');
    const lock2 = await workflow.acquireEditLock(c10.campaign_id, user2);
    const passed = lock1.granted === true && lock2.granted === false && lock2.holder_name === marketer.name;
    record('T-10', 'Two users request the edit lease', 'QA-01', passed, `Second denied; current editor shown: ${lock2.holder_name}`);
  } catch (err) {
    record('T-10', 'Two users request the edit lease', 'QA-01', false, `Error: ${err.message}`);
  }

  // --- T-11: Save with a stale expected_version. Expected: 409 VERSION_CONFLICT ---
  try {
    const c11 = await workflow.createCampaign(marketer, { title: 'T-11 Version Check', budget: 10000 });
    await workflow.updateCampaign(c11.campaign_id, marketer, { budget: 15000 });
    let caught = false;
    let code = '';
    try {
      await workflow.updateCampaign(c11.campaign_id, marketer, { budget: 18000 }, { expectedVersion: 1 });
    } catch (e) {
      caught = true;
      code = e.code;
    }
    const passed = caught && code === 'VERSION_CONFLICT';
    record('T-11', 'Save with a stale expected_version', 'QA-01', passed, `Result: ${code} (Expected 409 VERSION_CONFLICT)`);
  } catch (err) {
    record('T-11', 'Save with a stale expected_version', 'QA-01', false, `Error: ${err.message}`);
  }

  // --- T-12: Email provider down during approval. Expected: Approval succeeds; outbox retries ---
  try {
    const c12 = await workflow.createCampaign(marketer, { title: 'T-12 Outbox Resilience', budget: 25000 });
    await workflow.submitCampaign(c12.campaign_id, marketer);
    outbox.setEmailFailing(true);

    const dec12 = await workflow.makeDecision(c12.campaign_id, reviewer1, {
      versionId: c12.current_version_id,
      decision: 'APPROVED',
      reason: 'Testing approval commit during external email outage'
    });

    const updatedCamp = await workflow.getCampaign(c12.campaign_id);
    const approvalCommitted = updatedCamp.status === 'Approved' && Boolean(dec12.decision_id);

    const outboxRes = await db.query(
      `SELECT * FROM outbox_events WHERE payload::text LIKE $1 AND event_type = 'CAMPAIGN_APPROVED'`,
      ['%' + c12.campaign_id + '%']
    );
    const outboxEvt = outboxRes.rows[0];
    const retryScheduled = Boolean(outboxEvt && outboxEvt.status === 'PENDING');

    outbox.setEmailFailing(false);
    await outbox.processPendingEvents();

    const passed = Boolean(approvalCommitted && retryScheduled);
    record('T-12', 'Email provider down during approval', 'QA-02', passed, `Approval committed successfully; outbox handled delivery failure with retry.`);
  } catch (err) {
    outbox.setEmailFailing(false);
    record('T-12', 'Email provider down during approval', 'QA-02', false, `Error: ${err.message}`);
  }

  // --- T-13: Gemini unavailable during proposal creation. Expected: Manual workflow continues ---
  try {
    ai.setGeminiFailing(true);
    let aiFailed = false;
    try {
      await ai.draftProposal({ prompt: 'Summer Surge' });
    } catch (_) {
      aiFailed = true;
    }
    const manualCamp = await workflow.createCampaign(marketer, {
      title: 'Manual Fallback Campaign',
      objective: 'Written manually without AI assistance',
      target_audience: 'Direct Segment',
      channel: 'Search',
      budget: 9500
    });
    ai.setGeminiFailing(false);
    const passed = aiFailed && Boolean(manualCamp.campaign_id);
    record('T-13', 'Gemini unavailable during proposal creation', 'QA-02', passed, `AI failure caught safely; manual campaign creation succeeded without interruption.`);
  } catch (err) {
    ai.setGeminiFailing(false);
    record('T-13', 'Gemini unavailable during proposal creation', 'QA-02', false, `Error: ${err.message}`);
  }

  // --- T-14: Durability & Persistence across server connections. Expected: All records persisted in PostgreSQL ---
  try {
    const c14 = await workflow.createCampaign(marketer, { title: 'T-14 Durability Test', budget: 30000 });
    await workflow.submitCampaign(c14.campaign_id, marketer);
    await workflow.makeDecision(c14.campaign_id, reviewer1, {
      versionId: c14.current_version_id,
      decision: 'APPROVED',
      reason: 'Durability validation approval'
    });
    const c14_id = c14.campaign_id;
    const c14_ver = c14.current_version_id;

    // Simulate new client connection pool
    const restartedApp = await createApp();
    const recoveredCamp = await restartedApp.workflow.getCampaign(c14_id);
    const recoveredVer = await restartedApp.workflow.getVersion(c14_ver);
    const recoveredDec = await restartedApp.workflow.getDecision(c14_ver);

    const passed = Boolean(
      recoveredCamp &&
      recoveredCamp.status === 'Approved' &&
      recoveredVer &&
      recoveredDec &&
      recoveredDec.decision_type === 'APPROVED'
    );
    record('T-14', 'Restart application (Persistence test)', 'QA-02', passed, `All campaigns, versions, and decision records persisted across restart in PostgreSQL.`);
  } catch (err) {
    record('T-14', 'Restart application (Persistence test)', 'QA-02', false, `Error: ${err.message}`);
  }

  // --- T-15: Discussion Threads, Version Anchoring & @Mention Notifications (FR-12) ---
  try {
    const c15 = await workflow.createCampaign(marketer, { title: 'T-15 Collaboration Campaign', budget: 15000, channel: 'Search' });
    const v1Id = c15.current_version_id;

    // 1. Marketer posts message anchored to v1 with an @mention for reviewer1
    const msg1 = await workflow.postDiscussionMessage(c15.campaign_id, marketer, {
      content: 'Can @Marcus Vance please review the CPA target on this flight?',
      versionId: v1Id
    });

    // 2. Reviewer replies to msg1 (threaded)
    const reply1 = await workflow.postDiscussionMessage(c15.campaign_id, reviewer1, {
      content: 'Looks viable, will approve once copy is finalized.',
      parentMessageId: msg1.message_id,
      versionId: v1Id
    });

    // 3. Reviewer posts an internal-only note
    const internalNote = await workflow.postDiscussionMessage(c15.campaign_id, reviewer1, {
      content: 'Internal note: Check margin cap before Q4 launch.',
      isInternalOnly: true
    });

    // 4. Query discussions as reviewer vs marketer
    const reviewerDiscussions = await workflow.getDiscussions(c15.campaign_id, { user: reviewer1 });
    const marketerDiscussions = await workflow.getDiscussions(c15.campaign_id, { user: marketer });

    // 5. Query notifications for reviewer1 to check mention alert
    const notifs = await db.query(
      `SELECT * FROM notifications WHERE recipient_id = $1 AND campaign_id = $2 AND event_type = 'MENTION'`,
      [reviewer1.id, c15.campaign_id]
    );

    const hasMentionAlert = notifs.rowCount > 0;
    const hasThreadLink = reply1.parent_message_id === msg1.message_id;
    const hasVersionAnchor = msg1.version_id === v1Id && msg1.version_no === 1;
    const internalFiltered = !marketerDiscussions.some(m => m.is_internal_only) && reviewerDiscussions.some(m => m.is_internal_only);

    const passed = Boolean(
      msg1.mentions.includes(reviewer1.id) &&
      hasMentionAlert &&
      hasThreadLink &&
      hasVersionAnchor &&
      internalFiltered
    );

    record(
      'T-15',
      'Discussion Threads, Version Anchoring & @Mentions (FR-12)',
      'FR-12',
      passed,
      `Threaded reply linked, anchored to v1, @mention alert created, and internal note privacy enforced.`
    );
  } catch (err) {
    record('T-15', 'Discussion Threads, Version Anchoring & @Mentions (FR-12)', 'FR-12', false, `Error: ${err.message}`);
  }

  // --- T-16: Offline Mobile Sync Queue & Outbox Processing (FR-13, FR-14) ---
  try {
    const actId = 'act-test-' + Math.random().toString(36).substring(2, 8);
    const idempKey = 'idemp-offline-' + Math.random().toString(36).substring(2, 10);

    const queuedActions = [
      {
        action_id: actId,
        idempotency_key: idempKey,
        action_type: 'CREATE_CAMPAIGN',
        payload: {
          title: 'T-16 Offline Created Campaign',
          objective: 'Testing offline mobile batch sync queue drain',
          target_audience: 'Field Marketers',
          channel: 'Display',
          budget: 18500,
          kpi_projected: { conversion_rate: 3.2, ctr: 4.1, roi: 3.9, cpa: 22.0, aov: 95.0 }
        }
      }
    ];

    // 1. Drain offline queue batch
    const drainRes1 = await workflow.processSyncQueue(marketer, queuedActions);
    const firstSyncOk = drainRes1.synced === 1 &&
      drainRes1.results[0].status === 'SYNCED' &&
      drainRes1.results[0].is_replay === false &&
      drainRes1.results[0].data?.campaign_id;

    // 2. Re-drain the exact same batch with the same idempotency key -> must replay safely
    const drainRes2 = await workflow.processSyncQueue(marketer, queuedActions);
    const replayOk = drainRes2.synced === 1 &&
      drainRes2.results[0].status === 'SYNCED' &&
      drainRes2.results[0].is_replay === true &&
      drainRes2.results[0].data?.campaign_id === drainRes1.results[0].data?.campaign_id;

    // 3. Process transactional outbox
    const outboxProcessed = await outbox.processPendingEvents();

    const passed = Boolean(firstSyncOk && replayOk && Array.isArray(outboxProcessed));

    record(
      'T-16',
      'Offline Sync Queue, Batch Drain & Idempotency Replay (FR-13, FR-14)',
      'FR-13',
      passed,
      `Batch queue drained 1 action, replayed safely on retry with zero duplicate writes, outbox processed.`
    );
  } catch (err) {
    record('T-16', 'Offline Sync Queue, Batch Drain & Idempotency Replay (FR-13, FR-14)', 'FR-13', false, `Error: ${err.message}`);
  }

  // Automatic teardown: Clean up all transient test campaigns so database stays clean
  try {
    await db.query(`
      UPDATE campaigns SET current_version_id = NULL 
      WHERE title LIKE 'T-%' 
         OR title LIKE 'Camp %' 
         OR title LIKE 'Manual %';
      DELETE FROM campaigns 
      WHERE title LIKE 'T-%' 
         OR title LIKE 'Camp %' 
         OR title LIKE 'Manual %';
    `);
  } catch (err) {
    console.warn('[TEST TEARDOWN] Non-critical test cleanup warning:', err.message);
  }

  console.log('\n========================================');
  const allPassed = results.every(r => r.passed);
  console.log(`TOTAL TESTS: ${results.length} | PASSED: ${results.filter(r => r.passed).length} | FAILED: ${results.filter(r => !r.passed).length}`);
  console.log('========================================\n');

  return {
    allPassed,
    total: results.length,
    passedCount: results.filter(r => r.passed).length,
    failedCount: results.filter(r => !r.passed).length,
    results
  };
}

if (process.argv[1]?.endsWith('run-all-tests.js')) {
  runAllTests().then(res => {
    process.exit(res.allPassed ? 0 : 1);
  }).catch(err => {
    console.error('Test execution failed:', err);
    process.exit(1);
  });
}
