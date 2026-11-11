/**
 * ====================================================================
 * CAMPAIGNGRID — DECLARATIVE STATE MACHINE REGISTRY & GUARD ENGINE
 * Single authoritative source of truth across UX, DX, and AX:
 *   1. CAMPAIGN_LIFECYCLE_MACHINE (Draft -> Submitted -> Approved/ChangesRequested/Rejected -> Scheduled -> Completed)
 *   2. EDIT_LEASE_MACHINE (unlocked | held_by_me | held_by_other | expired)
 *   3. OUTBOX_DELIVERY_MACHINE (PENDING -> PROCESSING -> PROCESSED | FAILED)
 *   4. OFFLINE_SYNC_MACHINE (PENDING -> SYNCING -> SYNCED | FAILED)
 *   5. DIAGNOSTIC_OUTCOME_MACHINE (INFO | SUCCESS | WARNING | FAILURE)
 * ====================================================================
 */

export const CAMPAIGN_STAGES = Object.freeze({
  Draft: {
    id: 'Draft',
    label: 'Draft',
    tone: 'neutral',
    terminal: false,
    description: 'Editable working proposal version before formal review.',
  },
  Submitted: {
    id: 'Submitted',
    label: 'Awaiting review',
    tone: 'yellow',
    terminal: false,
    description: 'Locked for compliance/strategist review signoff on the active version.',
  },
  ChangesRequested: {
    id: 'ChangesRequested',
    label: 'Changes requested',
    tone: 'orange',
    terminal: false,
    description: 'Reviewer requested revisions before another submission.',
  },
  Approved: {
    id: 'Approved',
    label: 'Approved',
    tone: 'cyan',
    terminal: false,
    description: 'Approved on the current version and eligible for flight scheduling.',
  },
  Scheduled: {
    id: 'Scheduled',
    label: 'Scheduled',
    tone: 'lime',
    terminal: false,
    description: 'Conflict-free flight window booked on the channel calendar.',
  },
  Rejected: {
    id: 'Rejected',
    label: 'Rejected',
    tone: 'rose',
    terminal: false,
    description: 'Rejected by reviewer; can be revised into a fresh proposal version if revisited.',
  },
  Completed: {
    id: 'Completed',
    label: 'Completed',
    tone: 'neutral',
    terminal: true,
    description: 'Completed historical flight; immutable.',
  },
});

export const CAMPAIGN_TRANSITIONS = Object.freeze({
  CREATE_CAMPAIGN: {
    event: 'CREATE_CAMPAIGN',
    label: 'Create draft',
    from: [],
    to: 'Draft',
    allowedRoles: ['marketer', 'admin'],
    requiresOwnerUnlessAdmin: false,
    forbidsOwner: false,
    description: 'Create campaign shell with immutable version v1 in Draft.',
  },
  REVISE_VERSION: {
    event: 'REVISE_VERSION',
    label: 'Revise version',
    from: ['Draft', 'Submitted', 'ChangesRequested', 'Approved', 'Scheduled', 'Rejected'],
    to: 'Draft',
    allowedRoles: ['marketer', 'admin'],
    requiresOwnerUnlessAdmin: true,
    forbidsOwner: false,
    description: 'Snapshot immutable next version v(N+1) and promote back to Draft.',
  },
  SUBMIT_FOR_REVIEW: {
    event: 'SUBMIT_FOR_REVIEW',
    label: 'Submit for review',
    from: ['Draft', 'ChangesRequested'],
    to: 'Submitted',
    allowedRoles: ['marketer', 'admin'],
    requiresOwnerUnlessAdmin: true,
    forbidsOwner: false,
    description: 'Submit Draft or revised proposal version to reviewer queue.',
  },
  APPROVE_VERSION: {
    event: 'APPROVE_VERSION',
    label: 'Approve',
    from: ['Submitted'],
    to: 'Approved',
    allowedRoles: ['reviewer', 'admin'],
    requiresOwnerUnlessAdmin: false,
    forbidsOwner: true,
    requiresReason: true,
    description: 'Approve current submitted version (requires non-owner reviewer + reason).',
  },
  REQUEST_CHANGES: {
    event: 'REQUEST_CHANGES',
    label: 'Request changes',
    from: ['Submitted'],
    to: 'ChangesRequested',
    allowedRoles: ['reviewer', 'admin'],
    requiresOwnerUnlessAdmin: false,
    forbidsOwner: true,
    requiresReason: true,
    description: 'Return submitted version to author with mandatory rationale.',
  },
  REJECT_VERSION: {
    event: 'REJECT_VERSION',
    label: 'Reject',
    from: ['Submitted'],
    to: 'Rejected',
    allowedRoles: ['reviewer', 'admin'],
    requiresOwnerUnlessAdmin: false,
    forbidsOwner: true,
    requiresReason: true,
    description: 'Reject submitted version with mandatory rationale.',
  },
  SCHEDULE_FLIGHT: {
    event: 'SCHEDULE_FLIGHT',
    label: 'Schedule flight',
    from: ['Approved', 'Scheduled'],
    to: 'Scheduled',
    allowedRoles: ['marketer', 'admin'],
    requiresOwnerUnlessAdmin: true,
    forbidsOwner: false,
    requiresApprovedCurrentVersion: true,
    description: 'Lock an approved current version onto a non-overlapping channel flight window.',
  },
});

export const EDIT_LEASE_MACHINE = Object.freeze({
  ttlSeconds: 300,
  states: ['unlocked', 'held_by_me', 'held_by_other', 'expired'],
  transitions: [
    { event: 'ACQUIRE_LEASE', from: ['unlocked', 'expired', 'held_by_me'], to: 'held_by_me' },
    { event: 'RELEASE_LEASE', from: ['held_by_me'], to: 'unlocked' },
    { event: 'LEASE_TTL_ELAPSED', from: ['held_by_me', 'held_by_other'], to: 'expired' },
  ],
});

export const OUTBOX_DELIVERY_MACHINE = Object.freeze({
  maxAttempts: 3,
  states: ['PENDING', 'PROCESSING', 'PROCESSED', 'FAILED'],
  transitions: [
    { event: 'CLAIM_EVENT', from: ['PENDING', 'FAILED'], to: 'PROCESSING' },
    { event: 'DELIVERY_SUCCEEDED', from: ['PROCESSING'], to: 'PROCESSED' },
    { event: 'DELIVERY_RETRY_SCHEDULED', from: ['PROCESSING'], to: 'PENDING' },
    { event: 'DELIVERY_FAILED_OR_EXHAUSTED', from: ['PROCESSING'], to: 'FAILED' },
  ],
});

export const OFFLINE_SYNC_MACHINE = Object.freeze({
  states: ['PENDING', 'SYNCING', 'SYNCED', 'FAILED'],
  supportedActionTypes: [
    'CREATE_CAMPAIGN',
    'UPDATE_CAMPAIGN',
    'SAVE_DRAFT',
    'SUBMIT_CAMPAIGN',
    'MAKE_DECISION',
    'SCHEDULE_CAMPAIGN',
    'POST_DISCUSSION',
  ],
  transitions: [
    { event: 'ENQUEUE', from: [], to: 'PENDING' },
    { event: 'BEGIN_DRAIN', from: ['PENDING', 'FAILED'], to: 'SYNCING' },
    { event: 'SYNC_ACK', from: ['SYNCING'], to: 'SYNCED' },
    { event: 'SYNC_ERROR', from: ['SYNCING'], to: 'FAILED' },
  ],
});

export const DIAGNOSTIC_OUTCOME_MACHINE = Object.freeze({
  outcomes: {
    INFO: { id: 'INFO', label: 'Info', tone: 'blue' },
    SUCCESS: { id: 'SUCCESS', label: 'Success', tone: 'lime' },
    WARNING: { id: 'WARNING', label: 'Warning', tone: 'yellow' },
    FAILURE: { id: 'FAILURE', label: 'Failure', tone: 'rose' },
  },
});

export function normalizeCampaignStage(rawStatus) {
  const s = String(rawStatus || 'Draft').trim();
  const lower = s.toLowerCase();
  if (lower === 'revised' || lower === 'draft') return 'Draft';
  if (lower === 'submitted' || lower === 'inreview' || lower === 'in review' || lower === 'needs review' || lower === 'awaiting review') {
    return 'Submitted';
  }
  if (lower === 'changesrequested' || lower === 'changes_requested' || lower === 'changes requested' || lower === 'changes') {
    return 'ChangesRequested';
  }
  if (lower === 'approved') return 'Approved';
  if (lower === 'scheduled') return 'Scheduled';
  if (lower === 'rejected') return 'Rejected';
  if (lower === 'completed') return 'Completed';
  return CAMPAIGN_STAGES[s] ? s : 'Draft';
}

export function validEventsFromStage(stage) {
  const normalized = normalizeCampaignStage(stage);
  return Object.values(CAMPAIGN_TRANSITIONS)
    .filter((t) => t.from.includes(normalized))
    .map((t) => ({
      event: t.event,
      target_stage: t.to,
      label: t.label,
      allowed_roles: t.allowedRoles,
    }));
}

export function createWorkflowError({
  status = 409,
  code = 'INVALID_TRANSITION',
  message,
  event = null,
  fromState = null,
  allowedFrom = null,
  allowedTransitions = null,
  extra = {},
}) {
  const err = new Error(message);
  err.status = status;
  err.code = code;
  err.transition = {
    machine: 'campaign_lifecycle',
    event,
    from_state: fromState,
    allowed_from: allowedFrom,
    allowed_transitions: allowedTransitions || (fromState ? validEventsFromStage(fromState) : []),
  };
  Object.assign(err, extra);
  return err;
}

export function assertCampaignTransition(currentStatus, eventName, user, campaign = null) {
  const spec = CAMPAIGN_TRANSITIONS[eventName];
  if (!spec) {
    throw createWorkflowError({
      status: 400,
      code: 'UNKNOWN_TRANSITION',
      message: `Unknown workflow transition event: ${eventName}`,
      event: eventName,
    });
  }

  const normalized = currentStatus ? normalizeCampaignStage(currentStatus) : null;
  const role = String(user?.role || '').toLowerCase();

  if (!spec.allowedRoles.includes(role)) {
    throw createWorkflowError({
      status: 403,
      code: 'FORBIDDEN',
      message: `Action ${spec.label} requires role ${spec.allowedRoles.join(' or ')}.`,
      event: eventName,
      fromState: normalized,
      allowedFrom: spec.from,
    });
  }

  if (campaign && spec.requiresOwnerUnlessAdmin) {
    if (campaign.owner_id !== user.id && role !== 'admin') {
      throw createWorkflowError({
        status: 403,
        code: 'FORBIDDEN',
        message: 'Only the campaign owner or an administrator can perform this action.',
        event: eventName,
        fromState: normalized,
        allowedFrom: spec.from,
      });
    }
  }

  if (campaign && spec.forbidsOwner && campaign.owner_id === user.id) {
    throw createWorkflowError({
      status: 403,
      code: 'FORBIDDEN',
      message: 'Self-approval violation: You cannot review or approve your own campaign.',
      event: eventName,
      fromState: normalized,
      allowedFrom: spec.from,
    });
  }

  if (normalized && spec.from.length > 0 && !spec.from.includes(normalized)) {
    const validHere = validEventsFromStage(normalized).map((v) => v.event);
    throw createWorkflowError({
      status: 409,
      code: 'INVALID_TRANSITION',
      message: `Cannot ${spec.label.toLowerCase()} while campaign is in "${normalized}" stage. Allowed from: ${spec.from.join(', ')}.`,
      event: eventName,
      fromState: normalized,
      allowedFrom: spec.from,
      allowedTransitions: validHere,
    });
  }

  return spec.to;
}

export function evaluateLockState(lock, currentUserId, now = new Date()) {
  if (!lock || !lock.expires_at) {
    return {
      status: 'unlocked',
      holder_id: null,
      holder_name: null,
      expires_at: null,
      remaining_seconds: 0,
    };
  }
  const expiresMs = Date.parse(lock.expires_at);
  const nowMs = now.getTime();
  if (Number.isNaN(expiresMs) || expiresMs <= nowMs) {
    return {
      status: 'expired',
      holder_id: lock.user_id || lock.holder_id || null,
      holder_name: lock.holder_name || null,
      expires_at: lock.expires_at,
      remaining_seconds: 0,
    };
  }
  const holderId = lock.user_id || lock.holder_id;
  const remainingSeconds = Math.max(0, Math.ceil((expiresMs - nowMs) / 1000));
  return {
    status: holderId === currentUserId ? 'held_by_me' : 'held_by_other',
    holder_id: holderId,
    holder_name: lock.holder_name || 'Another editor',
    expires_at: lock.expires_at,
    remaining_seconds: remainingSeconds,
  };
}

export function evaluateCampaignCapabilities(
  campaign,
  user,
  { activeLock = null, currentVersionDecision = null, now = new Date() } = {},
) {
  const stage = normalizeCampaignStage(campaign?.status);
  const stageMeta = CAMPAIGN_STAGES[stage] || CAMPAIGN_STAGES.Draft;
  const role = String(user?.role || '').toLowerCase();
  const isOwner = Boolean(campaign && user && campaign.owner_id === user.id);
  const isAdmin = role === 'admin';
  const isReviewer = role === 'reviewer';

  const lockState = evaluateLockState(activeLock || campaign?.active_lock, user?.id, now);
  const lockedByOther = lockState.status === 'held_by_other';

  // Edit / Revise
  let canEdit = false;
  let editBlockedReason = null;
  if (stage === 'Completed') {
    editBlockedReason = 'Completed campaigns are archived and read-only.';
  } else if (!isOwner && !isAdmin) {
    editBlockedReason = 'Only the campaign owner or an administrator can revise this brief.';
  } else if (lockedByOther) {
    editBlockedReason = `Active edit lease held by ${lockState.holder_name || 'another editor'}.`;
  } else {
    canEdit = CAMPAIGN_TRANSITIONS.REVISE_VERSION.from.includes(stage);
  }

  // Submit for Review
  let canSubmit = false;
  let submitBlockedReason = null;
  if (!isOwner && !isAdmin) {
    submitBlockedReason = 'Only the campaign owner can submit this proposal for review.';
  } else if (lockedByOther) {
    submitBlockedReason = `Cannot submit while edit lease is held by ${lockState.holder_name}.`;
  } else if (!CAMPAIGN_TRANSITIONS.SUBMIT_FOR_REVIEW.from.includes(stage)) {
    submitBlockedReason =
      stage === 'Submitted'
        ? 'Already submitted and awaiting reviewer signoff.'
        : `Submit is available from Draft or Changes requested (currently ${stageMeta.label}).`;
  } else {
    canSubmit = true;
  }

  // Review Decision
  let canReview = false;
  let reviewBlockedReason = null;
  const alreadyDecided = Boolean(currentVersionDecision);
  if (isOwner) {
    reviewBlockedReason = 'Separation of duties active: owners cannot review their own campaigns.';
  } else if (!isReviewer && !isAdmin) {
    reviewBlockedReason = 'Switch to a reviewer account to record signoff decisions.';
  } else if (alreadyDecided) {
    reviewBlockedReason = `Current version already received a ${currentVersionDecision.decision_type} decision.`;
  } else if (stage !== 'Submitted') {
    reviewBlockedReason = `Proposals must be in Awaiting review before signoff (currently ${stageMeta.label}).`;
  } else {
    canReview = true;
  }

  // Schedule Flight
  let canSchedule = false;
  let scheduleBlockedReason = null;
  const hasApprovedDecision = Boolean(
    currentVersionDecision && currentVersionDecision.decision_type === 'APPROVED',
  );
  if (!isOwner && !isAdmin) {
    scheduleBlockedReason = 'Only the campaign owner or an administrator can book flight windows.';
  } else if (stage !== 'Approved' && stage !== 'Scheduled') {
    scheduleBlockedReason = 'Only approved versions can lock a slot on the production channel calendar.';
  } else if (currentVersionDecision && !hasApprovedDecision) {
    scheduleBlockedReason = 'Active version approval is required before scheduling.';
  } else {
    canSchedule = true;
  }

  let nextRecommendedAction = null;
  if (canReview) {
    nextRecommendedAction = { action: 'review', label: 'Review version', target_tab: 'review' };
  } else if (canSchedule && stage === 'Approved') {
    nextRecommendedAction = { action: 'schedule', label: 'Schedule flight', target_tab: 'schedule' };
  } else if (canSubmit) {
    nextRecommendedAction = { action: 'submit', label: 'Submit for review', target_tab: 'overview' };
  } else if (stage === 'Scheduled') {
    nextRecommendedAction = { action: 'inspect', label: 'Flight live', target_tab: 'overview' };
  }

  return {
    stage,
    stage_label: stageMeta.label,
    is_owner: isOwner,
    can_edit: canEdit,
    edit_blocked_reason: editBlockedReason,
    can_submit: canSubmit,
    submit_blocked_reason: submitBlockedReason,
    can_review: canReview,
    review_blocked_reason: reviewBlockedReason,
    can_schedule: canSchedule,
    schedule_blocked_reason: scheduleBlockedReason,
    lock_state: lockState,
    valid_transitions: validEventsFromStage(stage),
    next_recommended_action: nextRecommendedAction,
  };
}

export function getStateMachineCatalog({ outboxFailing = false, aiFailing = false } = {}) {
  return {
    version: '1.0.0',
    machines: {
      campaign_lifecycle: {
        initial: 'Draft',
        states: CAMPAIGN_STAGES,
        transitions: CAMPAIGN_TRANSITIONS,
        invariants: [
          'Owners cannot review or approve their own campaigns (enforced even for admin).',
          'At most one approval decision may be recorded per immutable version_id.',
          'Decisions require campaign status Submitted and non-empty justification reason.',
          'Flight scheduling requires campaign.current_version_id to hold an APPROVED decision and non-overlapping ACTIVE channel window.',
          'Revisions snapshot a new version_no + 1, transition campaign back to Draft, and fail with 409 VERSION_CONFLICT if expected_version is stale or 409 EDIT_LOCK_HELD if locked by another user.',
        ],
      },
      edit_lease: EDIT_LEASE_MACHINE,
      outbox_delivery: {
        ...OUTBOX_DELIVERY_MACHINE,
        runtime_simulation: { smtp_outage: Boolean(outboxFailing) },
      },
      offline_sync: OFFLINE_SYNC_MACHINE,
      diagnostic_outcomes: DIAGNOSTIC_OUTCOME_MACHINE,
      ai_assistant: {
        states: ['READY', 'DEGRADED'],
        current_state: aiFailing ? 'DEGRADED' : 'READY',
        fallback_behavior: 'Manual campaign authoring continues uninterrupted with 503 AI_UNAVAILABLE.',
      },
    },
  };
}
