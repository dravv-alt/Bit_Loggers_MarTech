import 'dart:convert';

class User {
  final String id;
  final String name;
  final String email;
  final String role; // 'marketer', 'reviewer', 'admin'
  final String? avatar;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatar,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'marketer',
      avatar: json['avatar'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
    'avatar': avatar,
  };
}

class KpiMetrics {
  final double conversionRate;
  final double ctr;
  final double roi;
  final double cpa;
  final double aov;

  KpiMetrics({
    required this.conversionRate,
    required this.ctr,
    required this.roi,
    required this.cpa,
    required this.aov,
  });

  factory KpiMetrics.fromJson(dynamic json) {
    if (json == null) {
      return KpiMetrics(conversionRate: 3.5, ctr: 4.2, roi: 3.8, cpa: 25.0, aov: 95.0);
    }
    final map = json is String ? jsonDecode(json) : json as Map<String, dynamic>;
    return KpiMetrics(
      conversionRate: (map['conversionRate'] as num?)?.toDouble() ?? 3.5,
      ctr: (map['ctr'] as num?)?.toDouble() ?? 4.2,
      roi: (map['roi'] as num?)?.toDouble() ?? 3.8,
      cpa: (map['cpa'] as num?)?.toDouble() ?? 25.0,
      aov: (map['aov'] as num?)?.toDouble() ?? 95.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'conversionRate': conversionRate,
    'ctr': ctr,
    'roi': roi,
    'cpa': cpa,
    'aov': aov,
  };
}

class CampaignVersion {
  final String versionId;
  final String campaignId;
  final int versionNo;
  final String objective;
  final String targetAudience;
  final String channel;
  final double budget;
  final KpiMetrics kpiProjected;
  final KpiMetrics? kpiActual;
  final String? aiSummary;
  final String createdBy;
  final String createdAt;

  CampaignVersion({
    required this.versionId,
    required this.campaignId,
    required this.versionNo,
    required this.objective,
    required this.targetAudience,
    required this.channel,
    required this.budget,
    required this.kpiProjected,
    this.kpiActual,
    this.aiSummary,
    required this.createdBy,
    required this.createdAt,
  });

  factory CampaignVersion.fromJson(Map<String, dynamic> json) {
    return CampaignVersion(
      versionId: json['version_id'] ?? '',
      campaignId: json['campaign_id'] ?? '',
      versionNo: json['version_no'] ?? 1,
      objective: json['objective'] ?? '',
      targetAudience: json['target_audience'] ?? '',
      channel: json['channel'] ?? 'Social',
      budget: (json['budget'] as num?)?.toDouble() ?? 10000.0,
      kpiProjected: KpiMetrics.fromJson(json['kpi_projected']),
      kpiActual: json['kpi_actual'] != null ? KpiMetrics.fromJson(json['kpi_actual']) : null,
      aiSummary: json['ai_summary'],
      createdBy: json['created_by'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class ApprovalDecision {
  final String decisionId;
  final String campaignId;
  final String versionId;
  final String reviewerId;
  final String reviewerName;
  final String decisionType; // 'APPROVED', 'CHANGES_REQUESTED', 'REJECTED'
  final String reason;
  final String? policyReference;
  final String decidedAt;

  ApprovalDecision({
    required this.decisionId,
    required this.campaignId,
    required this.versionId,
    required this.reviewerId,
    required this.reviewerName,
    required this.decisionType,
    required this.reason,
    this.policyReference,
    required this.decidedAt,
  });

  factory ApprovalDecision.fromJson(Map<String, dynamic> json) {
    return ApprovalDecision(
      decisionId: json['decision_id'] ?? '',
      campaignId: json['campaign_id'] ?? '',
      versionId: json['version_id'] ?? '',
      reviewerId: json['reviewer_id'] ?? '',
      reviewerName: json['reviewer_name'] ?? 'Reviewer',
      decisionType: json['decision_type'] ?? json['decision'] ?? 'APPROVED',
      reason: json['reason'] ?? '',
      policyReference: json['policy_reference'],
      decidedAt: json['decided_at'] ?? '',
    );
  }
}

class EditLock {
  final String campaignId;
  final String holderId;
  final String holderName;
  final String acquiredAt;
  final String expiresAt;

  EditLock({
    required this.campaignId,
    required this.holderId,
    required this.holderName,
    required this.acquiredAt,
    required this.expiresAt,
  });

  factory EditLock.fromJson(Map<String, dynamic> json) {
    return EditLock(
      campaignId: json['campaign_id'] ?? '',
      holderId: json['holder_id'] ?? '',
      holderName: json['holder_name'] ?? 'Editor',
      acquiredAt: json['acquired_at'] ?? '',
      expiresAt: json['expires_at'] ?? '',
    );
  }
}

class Campaign {
  final String campaignId;
  final String title;
  final String ownerId;
  final String ownerName;
  final String status; // 'Draft', 'Submitted', 'ChangesRequested', 'Approved', 'Revised', 'Scheduled', 'Rejected'
  final String currentVersionId;
  final CampaignVersion? currentVersion;
  final List<CampaignVersion> versions;
  final List<ApprovalDecision> decisions;
  final EditLock? activeLock;
  final String createdAt;
  final String updatedAt;

  Campaign({
    required this.campaignId,
    required this.title,
    required this.ownerId,
    required this.ownerName,
    required this.status,
    required this.currentVersionId,
    this.currentVersion,
    this.versions = const [],
    this.decisions = const [],
    this.activeLock,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    CampaignVersion? currentVer;
    if (json['current_version'] != null) {
      currentVer = CampaignVersion.fromJson(json['current_version']);
    } else if (json['version_no'] != null) {
      currentVer = CampaignVersion(
        versionId: json['current_version_id'] ?? '',
        campaignId: json['campaign_id'] ?? '',
        versionNo: json['version_no'] ?? 1,
        objective: json['objective'] ?? '',
        targetAudience: json['target_audience'] ?? '',
        channel: json['channel'] ?? 'Social',
        budget: (json['budget'] as num?)?.toDouble() ?? 10000.0,
        kpiProjected: KpiMetrics.fromJson(json['kpi_projected']),
        kpiActual: json['kpi_actual'] != null ? KpiMetrics.fromJson(json['kpi_actual']) : null,
        aiSummary: json['ai_summary'],
        createdBy: json['owner_id'] ?? '',
        createdAt: json['created_at'] ?? '',
      );
    }

    final versList = (json['versions'] as List?)
            ?.map((v) => CampaignVersion.fromJson(v))
            .toList() ??
        [];
    final decsList = (json['decisions'] as List?)
            ?.map((d) => ApprovalDecision.fromJson(d))
            .toList() ??
        [];

    EditLock? lock;
    if (json['active_lock'] != null) {
      lock = EditLock.fromJson(json['active_lock']);
    }

    return Campaign(
      campaignId: json['campaign_id'] ?? '',
      title: json['title'] ?? '',
      ownerId: json['owner_id'] ?? '',
      ownerName: json['owner_name'] ?? 'Marketer',
      status: json['status'] ?? 'Draft',
      currentVersionId: json['current_version_id'] ?? '',
      currentVersion: currentVer,
      versions: versList,
      decisions: decsList,
      activeLock: lock,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }
}

class AppNotification {
  final String notificationId;
  final String title;
  final String message;
  final String channel; // 'in-app', 'push', 'email'
  final String priority;
  final bool isRead;
  final String createdAt;
  final String? campaignId;

  AppNotification({
    required this.notificationId,
    required this.title,
    required this.message,
    required this.channel,
    required this.priority,
    required this.isRead,
    required this.createdAt,
    this.campaignId,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      notificationId: json['notification_id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      channel: json['channel'] ?? 'in-app',
      priority: json['priority'] ?? 'medium',
      isRead: (json['is_read'] == 1 || json['is_read'] == true),
      createdAt: json['created_at'] ?? '',
      campaignId: json['campaign_id'],
    );
  }
}

class Collaborator {
  final String userId;
  final String name;
  final String role;
  final String email;

  Collaborator({
    required this.userId,
    required this.name,
    required this.role,
    required this.email,
  });

  factory Collaborator.fromJson(Map<String, dynamic> json) {
    return Collaborator(
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      email: json['email'] ?? '',
    );
  }
}

class DiscussionMessage {
  final String messageId;
  final String authorName;
  final String authorRole;
  final String content;
  final String createdAt;
  final String? parentMessageId;
  final String? versionId;
  final int? versionNo;
  final bool isInternalOnly;
  final List<String> mentions;

  DiscussionMessage({
    required this.messageId,
    required this.authorName,
    required this.authorRole,
    required this.content,
    required this.createdAt,
    this.parentMessageId,
    this.versionId,
    this.versionNo,
    this.isInternalOnly = false,
    this.mentions = const [],
  });

  factory DiscussionMessage.fromJson(Map<String, dynamic> json) {
    List<String> parsedMentions = [];
    if (json['mentions'] is List) {
      parsedMentions = (json['mentions'] as List).map((e) => e.toString()).toList();
    }
    return DiscussionMessage(
      messageId: json['message_id'] ?? '',
      authorName: json['author_name'] ?? '',
      authorRole: json['author_role'] ?? '',
      content: json['content'] ?? '',
      createdAt: json['created_at'] ?? '',
      parentMessageId: json['parent_message_id'],
      versionId: json['version_id'],
      versionNo: json['version_no'] != null
          ? (json['version_no'] as num).toInt()
          : (json['anchored_version_no'] != null ? (json['anchored_version_no'] as num).toInt() : null),
      isInternalOnly: json['is_internal_only'] == true || json['is_internal_only'] == 1,
      mentions: parsedMentions,
    );
  }
}

class ScheduleEvent {
  final String scheduleId;
  final String campaignId;
  final String title;
  final String channel;
  final int versionNo;
  final double budget;
  final String startsAt;
  final String endsAt;
  final String status;

  ScheduleEvent({
    required this.scheduleId,
    required this.campaignId,
    required this.title,
    required this.channel,
    required this.versionNo,
    required this.budget,
    required this.startsAt,
    required this.endsAt,
    required this.status,
  });

  factory ScheduleEvent.fromJson(Map<String, dynamic> json) {
    return ScheduleEvent(
      scheduleId: json['schedule_id'] ?? '',
      campaignId: json['campaign_id'] ?? '',
      title: json['title'] ?? '',
      channel: json['channel'] ?? 'Social',
      versionNo: json['version_no'] ?? 1,
      budget: (json['budget'] as num?)?.toDouble() ?? 0.0,
      startsAt: json['starts_at'] ?? '',
      endsAt: json['ends_at'] ?? '',
      status: json['status'] ?? 'SCHEDULED',
    );
  }
}

class AuditEventItem {
  final String eventId;
  final String? campaignId;
  final String? versionId;
  final String? actorId;
  final String actorName;
  final String eventType;
  final String? previousState;
  final String? newState;
  final String summary;
  final String details;
  final Map<String, dynamic>? rawDetails;
  final String? correlationId;
  final String occurredAt;

  AuditEventItem({
    required this.eventId,
    this.campaignId,
    this.versionId,
    this.actorId,
    required this.actorName,
    required this.eventType,
    this.previousState,
    this.newState,
    required this.summary,
    required this.details,
    this.rawDetails,
    this.correlationId,
    required this.occurredAt,
  });

  factory AuditEventItem.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parsedDetails;
    if (json['details'] is Map) {
      parsedDetails = Map<String, dynamic>.from(json['details']);
    } else if (json['details'] is String) {
      try {
        parsedDetails = Map<String, dynamic>.from(jsonDecode(json['details']));
      } catch (_) {}
    }

    final summaryText = json['summary']?.toString() ?? '';
    final detailsStr = json['details'] is Map
        ? jsonEncode(json['details'])
        : (json['details']?.toString() ?? summaryText);

    return AuditEventItem(
      eventId: json['event_id'] ?? '',
      campaignId: json['campaign_id'],
      versionId: json['version_id'] ?? parsedDetails?['version_id'],
      actorId: json['actor_id'] ?? parsedDetails?['actor_id'],
      actorName: json['actor_name'] ?? json['actor_id'] ?? 'System',
      eventType: json['event_type'] ?? '',
      previousState: json['previous_state'] ?? parsedDetails?['previous_state'],
      newState: json['new_state'] ?? parsedDetails?['new_state'] ?? parsedDetails?['decision'],
      summary: summaryText.isNotEmpty ? summaryText : detailsStr,
      details: detailsStr,
      rawDetails: parsedDetails,
      correlationId: json['correlation_id'] ?? parsedDetails?['correlation_id'] ?? parsedDetails?['correlationId'],
      occurredAt: json['created_at'] ?? json['occurred_at'] ?? '',
    );
  }
}

class DiagnosticLogItem {
  final String logId;
  final String correlationId;
  final String eventType;
  final String outcome;
  final String message;
  final String timestamp;

  DiagnosticLogItem({
    required this.logId,
    required this.correlationId,
    required this.eventType,
    required this.outcome,
    required this.message,
    required this.timestamp,
  });

  factory DiagnosticLogItem.fromJson(Map<String, dynamic> json) {
    return DiagnosticLogItem(
      logId: json['log_id'] ?? '',
      correlationId: json['correlation_id'] ?? '',
      eventType: json['event_type'] ?? '',
      outcome: json['outcome'] ?? 'INFO',
      message: json['message'] ?? (json['details'] is Map ? jsonEncode(json['details']) : (json['details']?.toString() ?? '')),
      timestamp: json['recorded_at'] ?? json['timestamp'] ?? '',
    );
  }
}

// --- Mobile Offline Write Sync Queue (FR-13, ADR-005) ---
class OfflineSyncAction {
  final String actionId;
  final String idempotencyKey;
  final String actionType; // 'CREATE_CAMPAIGN', 'UPDATE_CAMPAIGN', 'SAVE_DRAFT', 'SUBMIT_CAMPAIGN', 'MAKE_DECISION', 'SCHEDULE_CAMPAIGN', 'POST_DISCUSSION'
  final String endpoint;
  final String method;
  final Map<String, dynamic> payload;
  final String createdAt;
  String status; // 'PENDING', 'SYNCING', 'SYNCED', 'FAILED'
  String? error;
  int retryCount;
  bool isReplay;
  Map<String, dynamic>? serverResponse;

  OfflineSyncAction({
    required this.actionId,
    required this.idempotencyKey,
    required this.actionType,
    required this.endpoint,
    this.method = 'POST',
    required this.payload,
    required this.createdAt,
    this.status = 'PENDING',
    this.error,
    this.retryCount = 0,
    this.isReplay = false,
    this.serverResponse,
  });

  Map<String, dynamic> toServerAction() => {
    'action_id': actionId,
    'idempotency_key': idempotencyKey,
    'action_type': actionType,
    'endpoint': endpoint,
    'method': method,
    'payload': payload,
    'created_at': createdAt,
  };

  factory OfflineSyncAction.fromJson(Map<String, dynamic> json) {
    return OfflineSyncAction(
      actionId: json['action_id'] ?? json['actionId'] ?? '',
      idempotencyKey: json['idempotency_key'] ?? json['idempotencyKey'] ?? '',
      actionType: json['action_type'] ?? json['actionType'] ?? '',
      endpoint: json['endpoint'] ?? '',
      method: json['method'] ?? 'POST',
      payload: json['payload'] is Map ? Map<String, dynamic>.from(json['payload']) : {},
      createdAt: json['created_at'] ?? json['createdAt'] ?? '',
      status: json['status'] ?? 'PENDING',
      error: json['error'] is Map ? json['error']['message'] ?? jsonEncode(json['error']) : json['error']?.toString(),
      retryCount: json['retry_count'] ?? json['retryCount'] ?? 0,
      isReplay: json['is_replay'] ?? json['isReplay'] ?? false,
      serverResponse: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'])
          : (json['server_response'] is Map ? Map<String, dynamic>.from(json['server_response']) : null),
    );
  }

  Map<String, dynamic> toJson() => {
    'action_id': actionId,
    'idempotency_key': idempotencyKey,
    'action_type': actionType,
    'endpoint': endpoint,
    'method': method,
    'payload': payload,
    'created_at': createdAt,
    'status': status,
    'error': error,
    'retry_count': retryCount,
    'is_replay': isReplay,
    'server_response': serverResponse,
  };
}

// --- Transactional Outbox Event Item (FR-14, ADR-004) ---
class OutboxEventItem {
  final String eventId;
  final String eventType;
  final Map<String, dynamic> payload;
  final String status; // 'PENDING', 'PROCESSING', 'PROCESSED', 'FAILED'
  final int attempts;
  final int maxAttempts;
  final String? nextRetryAt;
  final String? errorLog;
  final String createdAt;
  final String? processedAt;

  OutboxEventItem({
    required this.eventId,
    required this.eventType,
    required this.payload,
    required this.status,
    required this.attempts,
    required this.maxAttempts,
    this.nextRetryAt,
    this.errorLog,
    required this.createdAt,
    this.processedAt,
  });

  factory OutboxEventItem.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> parsedPayload = {};
    if (json['payload'] is Map) {
      parsedPayload = Map<String, dynamic>.from(json['payload']);
    } else if (json['payload'] is String) {
      try {
        parsedPayload = Map<String, dynamic>.from(jsonDecode(json['payload']));
      } catch (_) {}
    }
    return OutboxEventItem(
      eventId: json['event_id'] ?? json['eventId'] ?? '',
      eventType: json['event_type'] ?? json['eventType'] ?? '',
      payload: parsedPayload,
      status: json['status'] ?? 'PENDING',
      attempts: json['attempts'] ?? 0,
      maxAttempts: json['max_attempts'] ?? json['maxAttempts'] ?? 5,
      nextRetryAt: json['next_retry_at'] ?? json['nextRetryAt'],
      errorLog: json['error_log'] ?? json['errorLog'],
      createdAt: json['created_at'] ?? json['createdAt'] ?? '',
      processedAt: json['processed_at'] ?? json['processedAt'],
    );
  }

  Map<String, dynamic> toJson() => {
    'event_id': eventId,
    'event_type': eventType,
    'payload': payload,
    'status': status,
    'attempts': attempts,
    'max_attempts': maxAttempts,
    'next_retry_at': nextRetryAt,
    'error_log': errorLog,
    'created_at': createdAt,
    'processed_at': processedAt,
  };
}

class OutboxStats {
  final int pending;
  final int processed;
  final int failed;
  final int total;
  final bool isEmailServiceFailing;

  OutboxStats({
    required this.pending,
    required this.processed,
    required this.failed,
    required this.total,
    required this.isEmailServiceFailing,
  });

  factory OutboxStats.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] is Map ? json['stats'] : json;
    final p = (stats['pending'] as num?)?.toInt() ?? 0;
    final pr = (stats['processed'] as num?)?.toInt() ?? 0;
    final f = (stats['failed'] as num?)?.toInt() ?? 0;
    return OutboxStats(
      pending: p,
      processed: pr,
      failed: f,
      total: p + pr + f,
      isEmailServiceFailing: json['isEmailServiceFailing'] == true,
    );
  }
}


