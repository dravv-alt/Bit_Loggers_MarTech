import type { Campaign, ScheduleEvent, WorkspaceUser } from './types';

export type CampaignStage =
  | 'Draft'
  | 'Submitted'
  | 'ChangesRequested'
  | 'Approved'
  | 'Scheduled'
  | 'Rejected'
  | 'Completed';

export type LockLeaseStatus = 'unlocked' | 'held_by_me' | 'held_by_other' | 'expired';

export type OutboxDeliveryStatus = 'PENDING' | 'PROCESSING' | 'PROCESSED' | 'FAILED';

export type DiagnosticOutcome = 'INFO' | 'SUCCESS' | 'WARNING' | 'FAILURE';

export interface LockLeaseInfo {
  status: LockLeaseStatus;
  holderId: string | null;
  holderName: string | null;
  expiresAt: string | null;
  remainingSeconds: number;
}

export interface WorkflowActionPrompt {
  actionId: 'review' | 'schedule' | 'submit' | 'inspect' | 'revise';
  label: string;
  targetTab: 'overview' | 'review' | 'schedule';
}

export interface CampaignCapabilities {
  stage: CampaignStage;
  stageLabel: string;
  isOwner: boolean;
  isAdmin: boolean;
  isReviewerRole: boolean;
  canEdit: boolean;
  editBlockedReason: string | null;
  canSubmit: boolean;
  submitBlockedReason: string | null;
  canReview: boolean;
  reviewBlockedReason: string | null;
  canSchedule: boolean;
  scheduleBlockedReason: string | null;
  lockInfo: LockLeaseInfo;
  validNextStages: CampaignStage[];
  nextAction: WorkflowActionPrompt | null;
}

export const STAGE_LABELS: Record<CampaignStage, string> = {
  Draft: 'Draft',
  Submitted: 'Awaiting review',
  ChangesRequested: 'Changes requested',
  Approved: 'Approved',
  Scheduled: 'Scheduled',
  Rejected: 'Rejected',
  Completed: 'Completed',
};

export const ALLOWED_NEXT_STAGES: Record<CampaignStage, CampaignStage[]> = {
  Draft: ['Submitted', 'Draft'],
  Submitted: ['Approved', 'ChangesRequested', 'Rejected', 'Draft'],
  ChangesRequested: ['Submitted', 'Draft'],
  Approved: ['Scheduled', 'Draft'],
  Scheduled: ['Scheduled', 'Completed', 'Draft'],
  Rejected: ['Draft'],
  Completed: [],
};

export const OUTBOX_MAX_ATTEMPTS = 3;

export function normalizeCampaignStage(rawStatus?: string | null): CampaignStage {
  const s = (rawStatus || 'Draft').trim().toLowerCase();
  switch (s) {
    case 'draft':
    case 'revised':
      return 'Draft';
    case 'submitted':
    case 'inreview':
    case 'in review':
    case 'needs review':
    case 'awaiting review':
      return 'Submitted';
    case 'changesrequested':
    case 'changes_requested':
    case 'changes requested':
    case 'changes':
      return 'ChangesRequested';
    case 'approved':
      return 'Approved';
    case 'scheduled':
      return 'Scheduled';
    case 'rejected':
      return 'Rejected';
    case 'completed':
      return 'Completed';
    default:
      return 'Draft';
  }
}

export function normalizeDiagnosticOutcome(raw?: string | null): DiagnosticOutcome {
  const s = (raw || 'INFO').trim().toUpperCase();
  if (s === 'SUCCESS' || s === 'PASSED' || s === 'OK') return 'SUCCESS';
  if (s === 'WARNING' || s === 'WARN' || s === 'ATTEMPT' || s === 'RETRY') return 'WARNING';
  if (s === 'FAILURE' || s === 'FAILED' || s === 'ERROR') return 'FAILURE';
  return 'INFO';
}

export function diagnosticDotColor(
  outcome?: string | null,
): 'green' | 'yellow' | 'rose' | 'indigo' {
  switch (normalizeDiagnosticOutcome(outcome)) {
    case 'SUCCESS':
      return 'green';
    case 'WARNING':
      return 'yellow';
    case 'FAILURE':
      return 'rose';
    default:
      return 'indigo';
  }
}

export function evaluateLockState(
  lock: Campaign['active_lock'],
  currentUserId: string,
  nowMs = Date.now(),
): LockLeaseInfo {
  if (!lock || !lock.expires_at) {
    return {
      status: 'unlocked',
      holderId: null,
      holderName: null,
      expiresAt: null,
      remainingSeconds: 0,
    };
  }
  const expiresMs = Date.parse(lock.expires_at);
  if (Number.isNaN(expiresMs) || expiresMs <= nowMs) {
    return {
      status: 'expired',
      holderId: lock.holder_id || null,
      holderName: lock.holder_name || null,
      expiresAt: lock.expires_at,
      remainingSeconds: 0,
    };
  }
  const remainingSeconds = Math.max(0, Math.ceil((expiresMs - nowMs) / 1000));
  return {
    status: lock.holder_id === currentUserId ? 'held_by_me' : 'held_by_other',
    holderId: lock.holder_id,
    holderName: lock.holder_name || 'Another editor',
    expiresAt: lock.expires_at,
    remainingSeconds,
  };
}

export function canCreateCampaign(user: WorkspaceUser): boolean {
  const r = user.role.trim().toLowerCase();
  return r === 'marketer' || r === 'admin';
}

export function evaluateCampaignCapabilities(
  campaign: Campaign,
  currentUser: WorkspaceUser,
  nowMs = Date.now(),
): CampaignCapabilities {
  const stage = normalizeCampaignStage(campaign.status);
  const role = currentUser.role.trim().toLowerCase();
  const isOwner = campaign.owner_id === currentUser.id;
  const isAdmin = role === 'admin';
  const isReviewerRole = role === 'reviewer' || isAdmin;
  const lockInfo = evaluateLockState(campaign.active_lock, currentUser.id, nowMs);
  const lockedByOther = lockInfo.status === 'held_by_other';

  let canEdit = false;
  let editBlockedReason: string | null = null;
  if (stage === 'Completed') {
    editBlockedReason = 'Completed campaigns are archived and read-only.';
  } else if (!isOwner && !isAdmin) {
    editBlockedReason = 'Only the campaign owner or an administrator can revise this brief.';
  } else if (lockedByOther) {
    editBlockedReason = `Active edit lease held by ${lockInfo.holderName || 'another editor'}.`;
  } else {
    canEdit = true;
  }

  let canSubmit = false;
  let submitBlockedReason: string | null = null;
  if (!isOwner && !isAdmin) {
    submitBlockedReason = 'Only the campaign owner can submit this brief for review.';
  } else if (lockedByOther) {
    submitBlockedReason = `Edit lease held by ${lockInfo.holderName || 'another editor'}.`;
  } else if (stage !== 'Draft' && stage !== 'ChangesRequested') {
    submitBlockedReason =
      stage === 'Submitted'
        ? 'Already submitted and awaiting reviewer signoff.'
        : 'Only Draft or Changes requested proposals can be submitted.';
  } else {
    canSubmit = true;
  }

  const curDecision = (campaign.decisions || []).find(
    (d) => d.version_id === campaign.current_version_id,
  );
  let canReview = false;
  let reviewBlockedReason: string | null = null;
  if (isOwner) {
    reviewBlockedReason =
      'Owner self-approval lock active: Switch to a reviewer account to record a signoff.';
  } else if (!isReviewerRole) {
    reviewBlockedReason = 'Reviewer privileges required to record signoff decisions.';
  } else if (curDecision) {
    reviewBlockedReason = `Active version already received a ${curDecision.decision} decision.`;
  } else if (stage !== 'Submitted') {
    reviewBlockedReason = 'Proposal must be Awaiting review before signoff can be recorded.';
  } else {
    canReview = true;
  }

  let canSchedule = false;
  let scheduleBlockedReason: string | null = null;
  if (!isOwner && !isAdmin) {
    scheduleBlockedReason = 'Only the campaign owner or an administrator can book flight windows.';
  } else if (stage !== 'Approved' && stage !== 'Scheduled') {
    scheduleBlockedReason =
      'Only approved versions can lock a slot on the production channel calendar.';
  } else if (curDecision && curDecision.decision !== 'APPROVED') {
    scheduleBlockedReason = 'Current version does not have an APPROVED review decision.';
  } else {
    canSchedule = true;
  }

  let nextAction: WorkflowActionPrompt | null = null;
  if (canReview) {
    nextAction = { actionId: 'review', label: 'Review', targetTab: 'review' };
  } else if (canSchedule && stage === 'Approved') {
    nextAction = { actionId: 'schedule', label: 'Schedule', targetTab: 'schedule' };
  } else if (canSubmit) {
    nextAction = { actionId: 'submit', label: 'Submit', targetTab: 'overview' };
  } else if (stage === 'Scheduled') {
    nextAction = { actionId: 'inspect', label: 'Flight live', targetTab: 'overview' };
  }

  return {
    stage,
    stageLabel: STAGE_LABELS[stage],
    isOwner,
    isAdmin,
    isReviewerRole,
    canEdit,
    editBlockedReason,
    canSubmit,
    submitBlockedReason,
    canReview,
    reviewBlockedReason,
    canSchedule,
    scheduleBlockedReason,
    lockInfo,
    validNextStages: ALLOWED_NEXT_STAGES[stage],
    nextAction,
  };
}

export function isScheduleActive(evt: ScheduleEvent): boolean {
  const s = (evt.status || 'ACTIVE').trim().toUpperCase();
  return s === 'ACTIVE' || s === 'SCHEDULED';
}

