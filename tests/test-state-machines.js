import assert from 'node:assert/strict';
import {
  CAMPAIGN_STAGES,
  CAMPAIGN_TRANSITIONS,
  assertCampaignTransition,
  evaluateCampaignCapabilities,
  evaluateLockState,
  getStateMachineCatalog,
  normalizeCampaignStage,
} from '../server/state-machines.js';

const marketer = { id: 'usr-marketer-1', name: 'Alice Cooper', role: 'marketer' };
const otherMarketer = { id: 'usr-marketer-2', name: 'Bob Jones', role: 'marketer' };
const reviewer = { id: 'usr-reviewer-1', name: 'Marcus Vance', role: 'reviewer' };
const adminOwner = { id: 'usr-admin-1', name: 'Maya Lin', role: 'admin' };

const results = [];
function check(name, fn) {
  try {
    fn();
    results.push({ name, passed: true });
    console.log(`[PASS] ${name}`);
  } catch (err) {
    results.push({ name, passed: false, error: err.message });
    console.error(`[FAIL] ${name}: ${err.message}`);
  }
}

check('Catalog exposes all 6 explicit machines cleanly', () => {
  const catalog = getStateMachineCatalog({ outboxFailing: false, aiFailing: false });
  assert.equal(Object.keys(catalog.machines).length, 6);
  assert.ok(catalog.machines.campaign_lifecycle.states.Approved);
  assert.equal(catalog.machines.outbox_delivery.maxAttempts, 3);
});

check('Legacy alias normalization maps Revised -> Draft and InReview -> Submitted', () => {
  assert.equal(normalizeCampaignStage('Revised'), 'Draft');
  assert.equal(normalizeCampaignStage('InReview'), 'Submitted');
  assert.equal(normalizeCampaignStage('Changes Requested'), 'ChangesRequested');
  assert.equal(normalizeCampaignStage('unknown'), 'Draft');
});

check('Lifecycle blocks invalid transitions (Approved -> Submit, Draft -> Approve)', () => {
  const campApproved = { campaign_id: 'c1', owner_id: marketer.id, status: 'Approved' };
  assert.throws(
    () => assertCampaignTransition('Approved', 'SUBMIT_FOR_REVIEW', marketer, campApproved),
    (e) => e.code === 'INVALID_TRANSITION' && e.status === 409 && e.transition?.from_state === 'Approved',
  );

  const campDraft = { campaign_id: 'c1', owner_id: marketer.id, status: 'Draft' };
  assert.throws(
    () => assertCampaignTransition('Draft', 'APPROVE_VERSION', reviewer, campDraft),
    (e) => e.code === 'INVALID_TRANSITION' && e.status === 409 && e.transition?.allowed_from.includes('Submitted'),
  );
});

check('Separation of duties blocks self-approval even for admin owner', () => {
  const adminCamp = { campaign_id: 'c2', owner_id: adminOwner.id, status: 'Submitted' };
  assert.throws(
    () => assertCampaignTransition('Submitted', 'APPROVE_VERSION', adminOwner, adminCamp),
    (e) => e.code === 'FORBIDDEN' && e.status === 403,
  );
  const caps = evaluateCampaignCapabilities(adminCamp, adminOwner);
  assert.equal(caps.can_review, false);
  assert.ok(caps.review_blocked_reason.toLowerCase().includes('separation of duties'));
});

check('Non-owner marketer cannot review or edit submitted campaign', () => {
  const camp = { campaign_id: 'c3', owner_id: marketer.id, status: 'Submitted' };
  const caps = evaluateCampaignCapabilities(camp, otherMarketer);
  assert.equal(caps.can_review, false);
  assert.equal(caps.can_edit, false);
  assert.equal(caps.can_schedule, false);
});

check('Edit lease expires cleanly when expires_at <= now', () => {
  const past = new Date(Date.now() - 5000).toISOString();
  const future = new Date(Date.now() + 120000).toISOString();
  const expiredState = evaluateLockState({ user_id: reviewer.id, holder_name: reviewer.name, expires_at: past }, marketer.id);
  assert.equal(expiredState.status, 'expired');
  assert.equal(expiredState.remaining_seconds, 0);

  const activeForeign = evaluateLockState({ user_id: reviewer.id, holder_name: reviewer.name, expires_at: future }, marketer.id);
  assert.equal(activeForeign.status, 'held_by_other');
  assert.ok(activeForeign.remaining_seconds > 100);

  const capsLocked = evaluateCampaignCapabilities(
    { campaign_id: 'c4', owner_id: marketer.id, status: 'Draft' },
    marketer,
    { activeLock: { user_id: reviewer.id, holder_name: reviewer.name, expires_at: future } },
  );
  assert.equal(capsLocked.can_edit, false);
  assert.equal(capsLocked.can_submit, false);
});

check('Schedule capability requires Approved/Scheduled and owner/admin', () => {
  const camp = { campaign_id: 'c5', owner_id: marketer.id, status: 'Approved' };
  const dec = { version_id: 'v1', decision_type: 'APPROVED' };
  const marketerCaps = evaluateCampaignCapabilities(camp, marketer, { currentVersionDecision: dec });
  const reviewerCaps = evaluateCampaignCapabilities(camp, reviewer, { currentVersionDecision: dec });
  assert.equal(marketerCaps.can_schedule, true);
  assert.equal(reviewerCaps.can_schedule, false);
});

check('Completed campaigns are terminal for revisions', () => {
  const camp = { campaign_id: 'c6', owner_id: marketer.id, status: 'Completed' };
  assert.throws(
    () => assertCampaignTransition('Completed', 'REVISE_VERSION', marketer, camp),
    (e) => e.code === 'INVALID_TRANSITION' && CAMPAIGN_STAGES.Completed.terminal === true,
  );
  assert.ok(CAMPAIGN_TRANSITIONS.REVISE_VERSION.from.includes('Approved'));
});

const failed = results.filter((r) => !r.passed).length;
console.log(`\nState Machine Tests: ${results.length - failed}/${results.length} passed.`);
process.exit(failed > 0 ? 1 : 0);

