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

class DiscussionMessage {
  final String messageId;
  final String authorName;
  final String authorRole;
  final String content;
  final String createdAt;

  DiscussionMessage({
    required this.messageId,
    required this.authorName,
    required this.authorRole,
    required this.content,
    required this.createdAt,
  });

  factory DiscussionMessage.fromJson(Map<String, dynamic> json) {
    return DiscussionMessage(
      messageId: json['message_id'] ?? '',
      authorName: json['author_name'] ?? '',
      authorRole: json['author_role'] ?? '',
      content: json['content'] ?? '',
      createdAt: json['created_at'] ?? '',
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
  final String actorName;
  final String eventType;
  final String? previousState;
  final String? newState;
  final String details;
  final String occurredAt;

  AuditEventItem({
    required this.eventId,
    this.campaignId,
    required this.actorName,
    required this.eventType,
    this.previousState,
    this.newState,
    required this.details,
    required this.occurredAt,
  });

  factory AuditEventItem.fromJson(Map<String, dynamic> json) {
    return AuditEventItem(
      eventId: json['event_id'] ?? '',
      campaignId: json['campaign_id'],
      actorName: json['actor_name'] ?? json['actor_id'] ?? 'System',
      eventType: json['event_type'] ?? '',
      previousState: json['previous_state'],
      newState: json['new_state'],
      details: json['details'] ?? '',
      occurredAt: json['occurred_at'] ?? '',
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
      message: json['message'] ?? '',
      timestamp: json['timestamp'] ?? '',
    );
  }
}

