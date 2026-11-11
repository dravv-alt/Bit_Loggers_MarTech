import '../models/models.dart';

/// Typed API / workflow state exception so UI & ApiService distinguish real
/// 403/409/422 invariant rejections from unreachable-server fallbacks.
class WorkflowApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;
  final String? fromState;
  final List<String> allowedTransitions;

  const WorkflowApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.fromState,
    this.allowedTransitions = const [],
  });

  @override
  String toString() => message;
}

/// Explicit lifecycle stages matching PostgreSQL CHECK constraint in `server/schema.sql`.
enum CampaignStage {
  draft('Draft', 'Draft', 'neutral', 'brand'),
  submitted('Submitted', 'Awaiting review', 'yellow', 'review'),
  changesRequested('ChangesRequested', 'Changes requested', 'orange', 'changes'),
  approved('Approved', 'Approved', 'cyan', 'approved'),
  scheduled('Scheduled', 'Scheduled', 'lime', 'scheduled'),
  rejected('Rejected', 'Rejected', 'rose', 'blocked'),
  completed('Completed', 'Completed', 'neutral', 'blocked');

  final String wireValue;
  final String label;
  final String v3Tone;
  final String v2Key;

  const CampaignStage(this.wireValue, this.label, this.v3Tone, this.v2Key);

  bool get canSubmit => this == draft || this == changesRequested;
  bool get canRevise => this != completed;
  bool get isAwaitingReview => this == submitted;
  bool get canSchedule => this == approved || this == scheduled;

  List<CampaignStage> get allowedNextStages {
    switch (this) {
      case CampaignStage.draft:
        return const [CampaignStage.submitted, CampaignStage.draft];
      case CampaignStage.submitted:
        return const [
          CampaignStage.approved,
          CampaignStage.changesRequested,
          CampaignStage.rejected,
          CampaignStage.draft,
        ];
      case CampaignStage.changesRequested:
        return const [CampaignStage.submitted, CampaignStage.draft];
      case CampaignStage.approved:
        return const [CampaignStage.scheduled, CampaignStage.draft];
      case CampaignStage.scheduled:
        return const [CampaignStage.scheduled, CampaignStage.completed, CampaignStage.draft];
      case CampaignStage.rejected:
        return const [CampaignStage.draft];
      case CampaignStage.completed:
        return const [];
    }
  }

  static CampaignStage fromRaw(String? raw) {
    final s = (raw ?? 'Draft').trim().toLowerCase();
    switch (s) {
      case 'draft':
      case 'revised':
      case 'brand':
        return CampaignStage.draft;
      case 'submitted':
      case 'inreview':
      case 'in review':
      case 'in_review':
      case 'needs review':
      case 'awaiting review':
      case 'review':
        return CampaignStage.submitted;
      case 'changesrequested':
      case 'changes_requested':
      case 'changes requested':
      case 'changes':
        return CampaignStage.changesRequested;
      case 'approved':
        return CampaignStage.approved;
      case 'scheduled':
        return CampaignStage.scheduled;
      case 'rejected':
      case 'blocked':
      case 'conflict':
      case 'failed':
        return CampaignStage.rejected;
      case 'completed':
        return CampaignStage.completed;
      default:
        return CampaignStage.draft;
    }
  }
}

enum LockLeaseStatus { unlocked, heldByMe, heldByOther, expired }

class LockLeaseInfo {
  final LockLeaseStatus status;
  final String? holderId;
  final String? holderName;
  final DateTime? expiresAt;
  final int remainingSeconds;

  const LockLeaseInfo({
    required this.status,
    this.holderId,
    this.holderName,
    this.expiresAt,
    this.remainingSeconds = 0,
  });

  bool get isHeldByOther => status == LockLeaseStatus.heldByOther;
  bool get isHeldByMe => status == LockLeaseStatus.heldByMe;
}

class WorkflowActionPrompt {
  final String actionId; // 'submit' | 'review' | 'schedule' | 'inspect' | 'revise'
  final String label;
  final String targetTab; // 'overview' | 'review' | 'schedule'

  const WorkflowActionPrompt({
    required this.actionId,
    required this.label,
    required this.targetTab,
  });
}

class CampaignCapabilities {
  final CampaignStage stage;
  final bool isOwner;
  final bool isAdmin;
  final bool isReviewerRole;
  final bool canEdit;
  final String? editBlockedReason;
  final bool canSubmit;
  final String? submitBlockedReason;
  final bool canReview;
  final String? reviewBlockedReason;
  final bool canSchedule;
  final String? scheduleBlockedReason;
  final LockLeaseInfo lockInfo;
  final WorkflowActionPrompt? nextAction;

  const CampaignCapabilities({
    required this.stage,
    required this.isOwner,
    required this.isAdmin,
    required this.isReviewerRole,
    required this.canEdit,
    this.editBlockedReason,
    required this.canSubmit,
    this.submitBlockedReason,
    required this.canReview,
    this.reviewBlockedReason,
    required this.canSchedule,
    this.scheduleBlockedReason,
    required this.lockInfo,
    this.nextAction,
  });

  /// Serializable contract for automated agents / QA inspection (AX).
  Map<String, dynamic> toAgentJson() => {
        'stage': stage.wireValue,
        'stage_label': stage.label,
        'is_owner': isOwner,
        'can_edit': canEdit,
        'edit_blocked_reason': editBlockedReason,
        'can_submit': canSubmit,
        'submit_blocked_reason': submitBlockedReason,
        'can_review': canReview,
        'review_blocked_reason': reviewBlockedReason,
        'can_schedule': canSchedule,
        'schedule_blocked_reason': scheduleBlockedReason,
        'lock_state': {
          'status': lockInfo.status.name,
          'holder_id': lockInfo.holderId,
          'holder_name': lockInfo.holderName,
          'remaining_seconds': lockInfo.remainingSeconds,
        },
        'valid_next_stages': stage.allowedNextStages.map((s) => s.wireValue).toList(),
        'next_action': nextAction == null
            ? null
            : {
                'action_id': nextAction!.actionId,
                'label': nextAction!.label,
                'target_tab': nextAction!.targetTab,
              },
      };
}

enum SyncActionState {
  pending('PENDING', 'Pending'),
  syncing('SYNCING', 'Syncing'),
  synced('SYNCED', 'Synced'),
  failed('FAILED', 'Failed');

  final String wireValue;
  final String label;
  const SyncActionState(this.wireValue, this.label);

  bool get isRetryable => this == SyncActionState.pending || this == SyncActionState.failed;

  static SyncActionState fromRaw(String? raw) {
    switch ((raw ?? 'PENDING').trim().toUpperCase()) {
      case 'SYNCING':
        return SyncActionState.syncing;
      case 'SYNCED':
        return SyncActionState.synced;
      case 'FAILED':
        return SyncActionState.failed;
      default:
        return SyncActionState.pending;
    }
  }
}

enum OutboxDeliveryState {
  pending('PENDING', 'Pending', 'yellow'),
  processing('PROCESSING', 'Processing', 'blue'),
  processed('PROCESSED', 'Processed', 'lime'),
  failed('FAILED', 'Failed', 'rose');

  static const int defaultMaxAttempts = 3;

  final String wireValue;
  final String label;
  final String tone;
  const OutboxDeliveryState(this.wireValue, this.label, this.tone);

  static OutboxDeliveryState fromRaw(String? raw) {
    switch ((raw ?? 'PENDING').trim().toUpperCase()) {
      case 'PROCESSING':
        return OutboxDeliveryState.processing;
      case 'PROCESSED':
        return OutboxDeliveryState.processed;
      case 'FAILED':
        return OutboxDeliveryState.failed;
      default:
        return OutboxDeliveryState.pending;
    }
  }
}

enum DiagnosticOutcome {
  info('INFO', 'Info', 'neutral', 'blue'),
  success('SUCCESS', 'Success', 'lime', 'green'),
  warning('WARNING', 'Warning', 'yellow', 'yellow'),
  failure('FAILURE', 'Failure', 'rose', 'rose');

  final String wireValue;
  final String label;
  final String v3Tone;
  final String dotColorKey;
  const DiagnosticOutcome(this.wireValue, this.label, this.v3Tone, this.dotColorKey);

  static DiagnosticOutcome fromRaw(String? raw) {
    final s = (raw ?? 'INFO').trim().toUpperCase();
    if (s == 'SUCCESS' || s == 'PASSED' || s == 'OK') return DiagnosticOutcome.success;
    if (s == 'WARNING' || s == 'WARN' || s == 'ATTEMPT' || s == 'RETRY') {
      return DiagnosticOutcome.warning;
    }
    if (s == 'FAILURE' || s == 'FAILED' || s == 'ERROR') return DiagnosticOutcome.failure;
    return DiagnosticOutcome.info;
  }
}

class CampaignStateMachine {
  static bool canCreateCampaign(User user) {
    final r = user.role.trim().toLowerCase();
    return r == 'marketer' || r == 'admin';
  }

  static LockLeaseInfo evaluateLock(EditLock? lock, String currentUserId, {DateTime? now}) {
    if (lock == null) {
      return const LockLeaseInfo(status: LockLeaseStatus.unlocked);
    }
    final ts = now ?? DateTime.now();
    final expires = DateTime.tryParse(lock.expiresAt)?.toLocal();
    if (expires == null || !expires.isAfter(ts)) {
      return LockLeaseInfo(
        status: LockLeaseStatus.expired,
        holderId: lock.holderId,
        holderName: lock.holderName,
        expiresAt: expires,
        remainingSeconds: 0,
      );
    }
    final remaining = expires.difference(ts).inSeconds;
    return LockLeaseInfo(
      status: lock.holderId == currentUserId
          ? LockLeaseStatus.heldByMe
          : LockLeaseStatus.heldByOther,
      holderId: lock.holderId,
      holderName: lock.holderName,
      expiresAt: expires,
      remainingSeconds: remaining < 0 ? 0 : remaining,
    );
  }

  static CampaignCapabilities evaluate(Campaign camp, User user, {DateTime? now}) {
    final stage = CampaignStage.fromRaw(camp.status);
    final role = user.role.trim().toLowerCase();
    final isOwner = camp.ownerId == user.id;
    final isAdmin = role == 'admin';
    final isReviewerRole = role == 'reviewer' || isAdmin;
    final lockInfo = evaluateLock(camp.activeLock, user.id, now: now);

    // Edit / Revise guard
    bool canEdit = false;
    String? editBlocked;
    if (stage == CampaignStage.completed) {
      editBlocked = 'Completed campaigns are archived and read-only.';
    } else if (!isOwner && !isAdmin) {
      editBlocked = 'Only the campaign owner or an administrator can revise this brief.';
    } else if (lockInfo.isHeldByOther) {
      editBlocked = 'Active edit lease held by ${lockInfo.holderName ?? 'another editor'}.';
    } else {
      canEdit = true;
    }

    // Submit guard
    bool canSubmit = false;
    String? submitBlocked;
    if (!isOwner && !isAdmin) {
      submitBlocked = 'Only the campaign owner can submit this brief for review.';
    } else if (lockInfo.isHeldByOther) {
      submitBlocked = 'Edit lease is held by ${lockInfo.holderName ?? 'another editor'}.';
    } else if (!stage.canSubmit) {
      submitBlocked = stage == CampaignStage.submitted
          ? 'Already submitted and awaiting reviewer signoff.'
          : 'Only Draft or Changes requested proposals can be submitted.';
    } else {
      canSubmit = true;
    }

    // Review guard: separation of duties strictly forbids owner even if admin
    final curVersionDecided = camp.decisions.any((d) => d.versionId == camp.currentVersionId);
    bool canReview = false;
    String? reviewBlocked;
    if (isOwner) {
      reviewBlocked =
          'Owner self-approval lock active: Switch to a reviewer account to record a signoff.';
    } else if (!isReviewerRole) {
      reviewBlocked = 'Reviewer privileges required to record signoff decisions.';
    } else if (curVersionDecided) {
      reviewBlocked = 'The active version already has a recorded review decision.';
    } else if (stage != CampaignStage.submitted) {
      reviewBlocked = 'Proposal must be Awaiting review before a decision can be recorded.';
    } else {
      canReview = true;
    }

    // Schedule guard
    final nonApprovedCurDecision = camp.decisions.any(
      (d) => d.versionId == camp.currentVersionId && d.decisionType != 'APPROVED',
    );
    bool canSchedule = false;
    String? scheduleBlocked;
    if (!isOwner && !isAdmin) {
      scheduleBlocked = 'Only the campaign owner or an administrator can book flight windows.';
    } else if (!stage.canSchedule) {
      scheduleBlocked = 'Only approved versions can lock a slot on the production channel calendar.';
    } else if (nonApprovedCurDecision) {
      scheduleBlocked = 'Current version does not have an approved signoff decision.';
    } else {
      canSchedule = true;
    }

    WorkflowActionPrompt? nextAction;
    if (canReview) {
      nextAction = const WorkflowActionPrompt(
        actionId: 'review',
        label: 'Review',
        targetTab: 'review',
      );
    } else if (canSchedule && stage == CampaignStage.approved) {
      nextAction = const WorkflowActionPrompt(
        actionId: 'schedule',
        label: 'Schedule',
        targetTab: 'schedule',
      );
    } else if (canSubmit) {
      nextAction = const WorkflowActionPrompt(
        actionId: 'submit',
        label: 'Submit',
        targetTab: 'overview',
      );
    } else if (stage == CampaignStage.scheduled) {
      nextAction = const WorkflowActionPrompt(
        actionId: 'inspect',
        label: 'Flight live',
        targetTab: 'overview',
      );
    }

    return CampaignCapabilities(
      stage: stage,
      isOwner: isOwner,
      isAdmin: isAdmin,
      isReviewerRole: isReviewerRole,
      canEdit: canEdit,
      editBlockedReason: editBlocked,
      canSubmit: canSubmit,
      submitBlockedReason: submitBlocked,
      canReview: canReview,
      reviewBlockedReason: reviewBlocked,
      canSchedule: canSchedule,
      scheduleBlockedReason: scheduleBlocked,
      lockInfo: lockInfo,
      nextAction: nextAction,
    );
  }
}

