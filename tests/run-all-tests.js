import path from 'node:path';
import fs from 'node:fs';
import { createApp } from '../server/index.js';
import { DIAGNOSTIC_EVENTS } from '../server/diagnostics.js';

export async function runAllTests() {
  const results = [];
  const testDbPath = path.resolve(process.cwd(), 'test-campaigns.db');
  if (fs.existsSync(testDbPath)) {
    fs.unlinkSync(testDbPath);
  }

  // Create isolated server instance for tests
  const { app, db, diagnostics, outbox, workflow, ai } = createApp(testDbPath);
  const marketer = workflow.getUser('usr-marketer-1');
  const reviewer1 = workflow.getUser('usr-reviewer-1');
  const reviewer2 = workflow.getUser('usr-reviewer-2');

  function record(id, name, qa, passed, details) {
    results.push({ id, name, qa, passed, details });
    const status = passed ? '✅ PASS' : '❌ FAIL';
    console.log(`[${status}] ${id}: ${name} -> ${details}`);
  }

  console.log('\n========================================');
  console.log('   RUNNING BIT LOGGERS LLD TEST SUITE   ');
  console.log('========================================\n');

  // --- T-01: Approve V1. Edit budget to create V2. Schedule V2. Expected: 409 SCHEDULE_BLOCKED ---
  try {
    const c1 = workflow.createCampaign(marketer, { title: 'T-01 Campaign', budget: 10000, channel: 'Social' });
    workflow.submitCampaign(c1.campaign_id, marketer);
    workflow.makeDecision(c1.campaign_id, reviewer1, {
      version_id: c1.current_version_id,
      decision: 'APPROVED',
      reason: 'Valid proposal for test T-01'
    });
    // Now edit budget to create v2
    const c1_v2 = workflow.updateCampaign(c1.campaign_id, marketer, { budget: 20000 });
    let blocked = false;
    let errCode = '';
    try {
      workflow.scheduleCampaign(c1.campaign_id, marketer, {
        version_id: c1_v2.current_version_id,
        channel: 'Social'
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

  // --- T-02: Approve without a reason, or with whitespace only. Expected: 422 REASON_REQUIRED ---
  try {
    const c2 = workflow.createCampaign(marketer, { title: 'T-02 Campaign', budget: 5000 });
    workflow.submitCampaign(c2.campaign_id, marketer);
    let caught = false;
    let code = '';
    try {
      workflow.makeDecision(c2.campaign_id, reviewer1, {
        version_id: c2.current_version_id,
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
    const c3 = workflow.createCampaign(marketer, { title: 'T-03 Campaign', budget: 8000 });
    workflow.submitCampaign(c3.campaign_id, marketer);
    let caught = false;
    let code = '';
    try {
      workflow.makeDecision(c3.campaign_id, reviewer1, {
        version_id: c3.current_version_id,
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
    const c4 = workflow.createCampaign(marketer, { title: 'T-04 Campaign', budget: 12000 });
    workflow.submitCampaign(c4.campaign_id, marketer);
    let caught = false;
    let code = '';
    try {
      workflow.makeDecision(c4.campaign_id, reviewer1, {
        version_id: c4.current_version_id,
        decision: 'REJECTED',
        reason: null // null
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

  // --- T-05: Approve V3 using V1's version_id on a different campaign. Expected: 422 VERSION_MISMATCH ---
  try {
    const campA = workflow.createCampaign(marketer, { title: 'Camp A', budget: 5000 });
    const campB = workflow.createCampaign(marketer, { title: 'Camp B', budget: 6000 });
    workflow.submitCampaign(campB.campaign_id, marketer);
    let caught = false;
    let code = '';
    try {
      // Attempt to approve campB using campA's version_id
      workflow.makeDecision(campB.campaign_id, reviewer1, {
        version_id: campA.current_version_id,
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

  // --- T-06: Marketer calls approve; marketer approves own campaign. Expected: 403 FORBIDDEN ---
  try {
    const c6 = workflow.createCampaign(marketer, { title: 'T-06 Self-Approval Attempt', budget: 9000 });
    workflow.submitCampaign(c6.campaign_id, marketer);
    let caught = false;
    let code = '';
    try {
      // Marketer attempts to approve
      workflow.makeDecision(c6.campaign_id, marketer, {
        version_id: c6.current_version_id,
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

  // --- T-07: Reviewer approves; verify audit. Expected: Decision, actor and timestamp recorded ---
  try {
    const c7 = workflow.createCampaign(marketer, { title: 'T-07 Audit Campaign', budget: 15000 });
    workflow.submitCampaign(c7.campaign_id, marketer);
    const decision = workflow.makeDecision(c7.campaign_id, reviewer1, {
      version_id: c7.current_version_id,
      decision: 'APPROVED',
      reason: 'Valid justification for audit trail test'
    });
    const auditLogs = workflow.getAuditTrail(c7.campaign_id);
    const approvedEvent = auditLogs.find(a => a.event_type === 'CAMPAIGN_APPROVED');
    const passed = Boolean(decision.decision_id && approvedEvent && approvedEvent.actor_id === reviewer1.id && approvedEvent.occurred_at);
    record('T-07', 'Reviewer approves; verify audit trail', 'QA-03', passed, `Audit event recorded: ${approvedEvent?.event_type} by ${approvedEvent?.actor_name}`);
  } catch (err) {
    record('T-07', 'Reviewer approves; verify audit trail', 'QA-03', false, `Error: ${err.message}`);
  }

  // --- T-08: Repeat submission with same idempotency key after a lost response. Expected: One submission; original response returned ---
  try {
    const c8 = workflow.createCampaign(marketer, { title: 'T-08 Idempotency Campaign', budget: 11000 });
    const idemKey = 'idempotency-key-' + Date.now();
    const res1 = workflow.submitCampaign(c8.campaign_id, marketer, { idempotencyKey: idemKey, payload: { note: 'first try' } });
    const res2 = workflow.submitCampaign(c8.campaign_id, marketer, { idempotencyKey: idemKey, payload: { note: 'first try' } });
    
    // Check how many submissions were actually recorded
    const auditSubmissions = db.prepare(`SELECT COUNT(*) as count FROM audit_events WHERE campaign_id = ? AND event_type = 'CAMPAIGN_SUBMITTED'`).get(c8.campaign_id).count;
    const passed = (res1.version_id === res2.version_id) && (auditSubmissions === 1);
    record('T-08', 'Repeat submission with same idempotency key', 'QA-02', passed, `Single submission recorded; replayed original response.`);
  } catch (err) {
    record('T-08', 'Repeat submission with same idempotency key', 'QA-02', false, `Error: ${err.message}`);
  }

  // --- T-09: Two reviewers approve the same version concurrently. Expected: One commit succeeds; other gets 409 NOT_AWAITING_REVIEW ---
  try {
    const c9 = workflow.createCampaign(marketer, { title: 'T-09 Concurrency Campaign', budget: 14000 });
    workflow.submitCampaign(c9.campaign_id, marketer);
    // First reviewer approves
    const dec1 = workflow.makeDecision(c9.campaign_id, reviewer1, {
      version_id: c9.current_version_id,
      decision: 'APPROVED',
      reason: 'First reviewer approval'
    });
    // Second reviewer attempts concurrent approval
    let caught = false;
    let code = '';
    try {
      workflow.makeDecision(c9.campaign_id, reviewer2, {
        version_id: c9.current_version_id,
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
    const c10 = workflow.createCampaign(marketer, { title: 'T-10 Edit Lock Campaign', budget: 7000 });
    const lock1 = workflow.acquireEditLock(c10.campaign_id, marketer);
    const user2 = workflow.getUser('usr-reviewer-1');
    const lock2 = workflow.acquireEditLock(c10.campaign_id, user2);
    const passed = lock1.granted === true && lock2.granted === false && lock2.holder_name === marketer.name;
    record('T-10', 'Two users request the edit lease', 'QA-01', passed, `Second denied; current editor shown: ${lock2.holder_name}`);
  } catch (err) {
    record('T-10', 'Two users request the edit lease', 'QA-01', false, `Error: ${err.message}`);
  }

  // --- T-11: Save with a stale expected_version. Expected: 409 VERSION_CONFLICT; no overwrite ---
  try {
    const c11 = workflow.createCampaign(marketer, { title: 'T-11 Version Check', budget: 10000 });
    // Advance version to v2
    workflow.updateCampaign(c11.campaign_id, marketer, { budget: 15000 });
    let caught = false;
    let code = '';
    try {
      // Stale screen still thinks it is version 1
      workflow.updateCampaign(c11.campaign_id, marketer, { budget: 18000 }, { expectedVersion: 1 });
    } catch (e) {
      caught = true;
      code = e.code;
    }
    const passed = caught && code === 'VERSION_CONFLICT';
    record('T-11', 'Save with a stale expected_version', 'QA-01', passed, `Result: ${code} (Expected 409 VERSION_CONFLICT)`);
  } catch (err) {
    record('T-11', 'Save with a stale expected_version', 'QA-01', false, `Error: ${err.message}`);
  }

  // --- T-12: Email provider down during approval. Expected: Approval succeeds; event retried from outbox ---
  try {
    const c12 = workflow.createCampaign(marketer, { title: 'T-12 Outbox Resilience', budget: 25000 });
    workflow.submitCampaign(c12.campaign_id, marketer);
    // Simulate email outage
    outbox.setEmailFailing(true);
    // Make approval
    const dec12 = workflow.makeDecision(c12.campaign_id, reviewer1, {
      version_id: c12.current_version_id,
      decision: 'APPROVED',
      reason: 'Testing approval commit during external email outage'
    });
    // Check campaign state is committed as Approved
    const updatedCamp = workflow.getCampaign(c12.campaign_id);
    const approvalCommitted = updatedCamp.status === 'Approved' && Boolean(dec12.decision_id);
    
    // Check outbox has retry scheduled
    const outboxEvt = db.prepare(`SELECT * FROM outbox_events WHERE payload LIKE ? AND event_type = 'CAMPAIGN_APPROVED'`).get(`%${c12.campaign_id}%`);
    const retryScheduled = Boolean(outboxEvt && (outboxEvt.attempts > 0 || outboxEvt.last_error !== null || outboxEvt.status === 'PENDING'));

    // Restore email service
    outbox.setEmailFailing(false);
    outbox.processPendingEvents();
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
    } catch (e) {
      aiFailed = true;
    }
    // Manual workflow continues without AI
    const manualCamp = workflow.createCampaign(marketer, {
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

  // --- T-14: Restart the application. Expected: Campaigns, versions and decisions remain ---
  try {
    // 1. Create and approve a campaign on first connection
    const c14 = workflow.createCampaign(marketer, { title: 'T-14 Durability Test', budget: 30000 });
    workflow.submitCampaign(c14.campaign_id, marketer);
    workflow.makeDecision(c14.campaign_id, reviewer1, {
      version_id: c14.current_version_id,
      decision: 'APPROVED',
      reason: 'Durability validation approval'
    });
    const c14_id = c14.campaign_id;
    const c14_ver = c14.current_version_id;

    // 2. Simulate application restart by creating brand new App/DB instance pointing to the same SQLite file
    const restartedApp = createApp(testDbPath);
    const recoveredCamp = restartedApp.workflow.getCampaign(c14_id);
    const recoveredVer = restartedApp.workflow.getVersion(c14_ver);
    const recoveredDec = restartedApp.workflow.getDecision(c14_ver);

    const passed = Boolean(recoveredCamp && recoveredCamp.status === 'Approved' && recoveredVer && recoveredDec && recoveredDec.decision_type === 'APPROVED');
    record('T-14', 'Restart application (Persistence test)', 'QA-02', passed, `All campaigns, versions, and decision records persisted across restart.`);
  } catch (err) {
    record('T-14', 'Restart application (Persistence test)', 'QA-02', false, `Error: ${err.message}`);
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

// If executed directly from command line
if (process.argv[1]?.endsWith('run-all-tests.js')) {
  runAllTests().then(res => {
    process.exit(res.allPassed ? 0 : 1);
  }).catch(err => {
    console.error('Test execution failed:', err);
    process.exit(1);
  });
}
