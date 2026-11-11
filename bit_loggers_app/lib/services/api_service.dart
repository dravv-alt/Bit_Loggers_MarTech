import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../state/campaign_state_machine.dart';
import 'sync_queue_service.dart';

class ApiService {
  static String _resolveBaseUrl() {
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          return 'http://10.0.2.2:3000';
        }
      } catch (_) {}
    }
    return 'http://localhost:3000';
  }

  static String baseUrl = _resolveBaseUrl();
  final _uuid = const Uuid();
  final SyncQueueService syncQueue = SyncQueueService();

  // Active user header for RBAC
  User currentUser = User(
    id: 'usr-marketer-1',
    name: 'Alice Cooper (Marketer)',
    email: 'alice.marketer@bitloggers.com',
    role: 'marketer',
  );

  bool isConnected = false;

  // Stateful in-memory store used seamlessly when offline or backend unreachable
  List<Campaign>? _offlineCampaigns;
  List<ScheduleEvent>? _offlineCalendar;
  List<AuditEventItem>? _offlineAudit;
  List<AppNotification>? _offlineNotifications;
  final Map<String, List<DiscussionMessage>> _offlineDiscussions = {};
  final Map<String, EditLock> _offlineLocks = {};
  final Map<String, String> _offlineSubmittedIdempotencyHashes = {};

  bool _isBackendUnreachableStatus(int code) => code == 401 || code >= 500;

  WorkflowApiException _parseWorkflowError(http.Response res, String fallbackMessage) {
    try {
      final body = jsonDecode(res.body);
      final errObj = body is Map ? body['error'] : null;
      if (errObj is Map) {
        final tr = errObj['transition'];
        return WorkflowApiException(
          statusCode: res.statusCode,
          code: errObj['code']?.toString() ?? 'WORKFLOW_ERROR',
          message: errObj['message']?.toString() ?? fallbackMessage,
          fromState: tr is Map ? tr['from_state']?.toString() : null,
          allowedTransitions: tr is Map && tr['allowed_transitions'] is List
              ? (tr['allowed_transitions'] as List).map((e) => e.toString()).toList()
              : const [],
        );
      }
    } catch (_) {}
    return WorkflowApiException(
      statusCode: res.statusCode,
      code: 'HTTP_${res.statusCode}',
      message: fallbackMessage,
    );
  }

  List<Campaign> get _mutableOfflineCampaigns {
    _offlineCampaigns ??= _buildInitialOfflineCampaigns();
    return _offlineCampaigns!;
  }

  List<ScheduleEvent> get _mutableOfflineCalendar {
    _offlineCalendar ??= _buildInitialOfflineCalendar();
    return _offlineCalendar!;
  }

  List<AuditEventItem> get _mutableOfflineAudit {
    _offlineAudit ??= _buildInitialOfflineAudit();
    return _offlineAudit!;
  }

  List<AppNotification> get _mutableOfflineNotifications {
    _offlineNotifications ??= _buildInitialOfflineNotifications();
    return _offlineNotifications!;
  }

  void _prependOfflineAudit({
    String? campaignId,
    String? versionId,
    required String eventType,
    String? previousState,
    String? newState,
    required String summary,
    String details = '',
  }) {
    _mutableOfflineAudit.insert(
      0,
      AuditEventItem(
        eventId: 'aud-${DateTime.now().millisecondsSinceEpoch % 100000}',
        campaignId: campaignId,
        versionId: versionId,
        actorId: currentUser.id,
        actorName: currentUser.name.split(' (').first,
        eventType: eventType,
        previousState: previousState,
        newState: newState,
        summary: summary,
        details: details,
        correlationId: 'c-${_uuid.v4().substring(0, 8)}',
        occurredAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, String> _headers({String? idempotencyKey, int? expectedVersion}) {
    final headers = {
      'Content-Type': 'application/json',
      'x-user-id': currentUser.id,
      'x-correlation-id': 'c-${_uuid.v4().substring(0, 8)}',
    };
    if (idempotencyKey != null) {
      headers['idempotency-key'] = idempotencyKey;
    }
    if (expectedVersion != null) {
      headers['x-expected-version'] = expectedVersion.toString();
    }
    return headers;
  }

  // Check health and ping server
  Future<bool> checkConnection() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/users')).timeout(const Duration(seconds: 2));
      isConnected = res.statusCode == 200;
      return isConnected;
    } catch (_) {
      isConnected = false;
      return false;
    }
  }

  // --- Users ---
  Future<List<User>> getUsers() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/users'), headers: _headers()).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['users'] as List).map((u) => User.fromJson(u)).toList();
        return list;
      }
    } catch (_) {}

    // Fallback users
    return [
      User(id: 'usr-marketer-1', name: 'Alice Cooper (Marketer)', email: 'alice.marketer@bitloggers.com', role: 'marketer'),
      User(id: 'usr-reviewer-1', name: 'Marcus Vance (Reviewer)', email: 'marcus.reviewer@bitloggers.com', role: 'reviewer'),
      User(id: 'usr-reviewer-2', name: 'Elena Rostova (Compliance)', email: 'elena.compliance@bitloggers.com', role: 'reviewer'),
      User(id: 'usr-admin-1', name: 'Sarah Jenkins (Admin)', email: 'sarah.admin@bitloggers.com', role: 'admin'),
    ];
  }

  // --- Campaigns List ---
  Future<List<Campaign>> getCampaigns({String? status, String? channel}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/campaigns').replace(queryParameters: {
        if (status != null && status != 'All') 'status': status,
        if (channel != null && channel != 'All') 'channel': channel,
      });
      final res = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['campaigns'] as List).map((c) => Campaign.fromJson(c)).toList();
      }
    } catch (_) {}

    return _mutableOfflineCampaigns.where((c) {
      if (status != null && status != 'All' && c.status != status) return false;
      if (channel != null && channel != 'All' && (c.currentVersion?.channel ?? '') != channel) {
        return false;
      }
      return true;
    }).map((c) {
      final rawLock = _offlineLocks[c.campaignId] ?? c.activeLock;
      final lockInfo = CampaignStateMachine.evaluateLock(rawLock, currentUser.id);
      final validLock = lockInfo.status == LockLeaseStatus.expired ? null : rawLock;
      if (lockInfo.status == LockLeaseStatus.expired) {
        _offlineLocks.remove(c.campaignId);
      }
      return Campaign(
        campaignId: c.campaignId,
        title: c.title,
        ownerId: c.ownerId,
        ownerName: c.ownerName,
        status: c.status,
        currentVersionId: c.currentVersionId,
        currentVersion: c.currentVersion,
        versions: c.versions,
        decisions: c.decisions,
        activeLock: validLock,
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
      );
    }).toList();
  }

  // --- Campaign Details ---
  Future<Campaign> getCampaign(String id) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/campaigns/$id'), headers: _headers()).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        return Campaign.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}

    final list = _mutableOfflineCampaigns;
    final found = list.firstWhere((c) => c.campaignId == id, orElse: () => list.first);
    final rawLock = _offlineLocks[found.campaignId] ?? found.activeLock;
    final lockInfo = CampaignStateMachine.evaluateLock(rawLock, currentUser.id);
    final validLock = lockInfo.status == LockLeaseStatus.expired ? null : rawLock;
    if (lockInfo.status == LockLeaseStatus.expired) {
      _offlineLocks.remove(found.campaignId);
    }
    return Campaign(
      campaignId: found.campaignId,
      title: found.title,
      ownerId: found.ownerId,
      ownerName: found.ownerName,
      status: found.status,
      currentVersionId: found.currentVersionId,
      currentVersion: found.currentVersion,
      versions: found.versions,
      decisions: found.decisions,
      activeLock: validLock,
      createdAt: found.createdAt,
      updatedAt: found.updatedAt,
    );
  }

  // --- Create Campaign ---
  Future<Campaign> createCampaign(Map<String, dynamic> body) async {
    Campaign buildOfflineCampaign(String newId) {
      if (!CampaignStateMachine.canCreateCampaign(currentUser)) {
        throw const WorkflowApiException(
          statusCode: 403,
          code: 'FORBIDDEN',
          message: 'Only marketers or administrators can create campaign proposals.',
        );
      }
      final verId = 'ver-${_uuid.v4().substring(0, 6)}';
      final nowIso = DateTime.now().toIso8601String();
      final v1 = CampaignVersion(
        versionId: verId,
        campaignId: newId,
        versionNo: 1,
        objective: body['objective'] ?? 'Launch campaign',
        targetAudience: body['target_audience'] ?? 'Lookalike',
        channel: body['channel'] ?? 'Social',
        budget: (body['budget'] as num?)?.toDouble() ?? 15000,
        kpiProjected: KpiMetrics.fromJson(body['kpi_projected']),
        aiSummary: body['ai_summary'],
        createdBy: currentUser.id,
        createdAt: nowIso,
      );
      final created = Campaign(
        campaignId: newId,
        title: body['title'] ?? 'Untitled Proposal',
        ownerId: currentUser.id,
        ownerName: currentUser.name.split(' (').first,
        status: CampaignStage.draft.wireValue,
        currentVersionId: verId,
        currentVersion: v1,
        versions: [v1],
        decisions: const [],
        createdAt: nowIso,
        updatedAt: nowIso,
      );
      _mutableOfflineCampaigns.insert(0, created);
      _prependOfflineAudit(
        campaignId: newId,
        versionId: verId,
        eventType: 'CAMPAIGN_CREATED',
        newState: 'Draft',
        summary: 'Created proposal "${created.title}" (v1)',
        details: '${v1.channel} · \$${v1.budget.toStringAsFixed(0)}',
      );
      return created;
    }

    if (syncQueue.isOfflineSimulationEnabled) {
      if (!CampaignStateMachine.canCreateCampaign(currentUser)) {
        throw const WorkflowApiException(
          statusCode: 403,
          code: 'FORBIDDEN',
          message: 'Only marketers or administrators can create campaign proposals.',
        );
      }
      final action = syncQueue.enqueueAction(
        actionType: 'CREATE_CAMPAIGN',
        endpoint: '/api/campaigns',
        method: 'POST',
        payload: body,
      );
      return buildOfflineCampaign('camp-${action.actionId.substring(4)}');
    }

    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/campaigns'),
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 201 || res.statusCode == 200) {
        return Campaign.fromJson(jsonDecode(res.body));
      } else if (!_isBackendUnreachableStatus(res.statusCode)) {
        throw _parseWorkflowError(res, 'Failed to create campaign');
      }
    } catch (e) {
      if (e is WorkflowApiException) rethrow;
    }

    syncQueue.enqueueAction(
      actionType: 'CREATE_CAMPAIGN',
      endpoint: '/api/campaigns',
      method: 'POST',
      payload: body,
    );
    return buildOfflineCampaign('camp-${_uuid.v4().substring(0, 6)}');
  }

  // --- Update Campaign ---
  Future<Campaign> updateCampaign(String id, Map<String, dynamic> body, {int? expectedVersion}) async {
    Campaign applyOfflineUpdate() {
      final idx = _mutableOfflineCampaigns.indexWhere((c) => c.campaignId == id);
      if (idx < 0) {
        throw const WorkflowApiException(
          statusCode: 404,
          code: 'CAMPAIGN_NOT_FOUND',
          message: 'Campaign does not exist.',
        );
      }
      final existing = _mutableOfflineCampaigns[idx];
      final withLock = Campaign(
        campaignId: existing.campaignId,
        title: existing.title,
        ownerId: existing.ownerId,
        ownerName: existing.ownerName,
        status: existing.status,
        currentVersionId: existing.currentVersionId,
        currentVersion: existing.currentVersion,
        versions: existing.versions,
        decisions: existing.decisions,
        activeLock: _offlineLocks[id] ?? existing.activeLock,
        createdAt: existing.createdAt,
        updatedAt: existing.updatedAt,
      );
      final caps = CampaignStateMachine.evaluate(withLock, currentUser);
      if (!caps.canEdit) {
        throw WorkflowApiException(
          statusCode: caps.lockInfo.isHeldByOther ? 409 : 403,
          code: caps.lockInfo.isHeldByOther ? 'EDIT_LOCK_HELD' : 'FORBIDDEN',
          message: caps.editBlockedReason ?? 'Only the campaign owner can edit this proposal.',
          fromState: caps.stage.wireValue,
        );
      }
      final curNo = existing.currentVersion?.versionNo ?? 1;
      if (expectedVersion != null && expectedVersion != curNo) {
        throw WorkflowApiException(
          statusCode: 409,
          code: 'VERSION_CONFLICT',
          message: 'Version conflict: Expected v$expectedVersion, current is v$curNo.',
          fromState: caps.stage.wireValue,
        );
      }
      final nextNo = curNo + 1;
      final nextVerId = 'ver-${id.replaceAll('camp-', '')}-v$nextNo';
      final nowIso = DateTime.now().toIso8601String();
      final nextVer = CampaignVersion(
        versionId: nextVerId,
        campaignId: id,
        versionNo: nextNo,
        objective: body['objective'] ?? existing.currentVersion?.objective ?? '',
        targetAudience: body['target_audience'] ?? existing.currentVersion?.targetAudience ?? 'Lookalike',
        channel: body['channel'] ?? existing.currentVersion?.channel ?? 'Social',
        budget: (body['budget'] as num?)?.toDouble() ?? existing.currentVersion?.budget ?? 15000,
        kpiProjected: body['kpi_projected'] != null
            ? KpiMetrics.fromJson(body['kpi_projected'])
            : (existing.currentVersion?.kpiProjected ?? KpiMetrics.fromJson(null)),
        aiSummary: body['ai_summary'] ?? existing.currentVersion?.aiSummary,
        createdBy: currentUser.id,
        createdAt: nowIso,
      );
      final updated = Campaign(
        campaignId: existing.campaignId,
        title: body['title'] ?? existing.title,
        ownerId: existing.ownerId,
        ownerName: existing.ownerName,
        status: CampaignStage.draft.wireValue,
        currentVersionId: nextVerId,
        currentVersion: nextVer,
        versions: [...existing.versions, nextVer],
        decisions: existing.decisions,
        activeLock: withLock.activeLock,
        createdAt: existing.createdAt,
        updatedAt: nowIso,
      );
      _mutableOfflineCampaigns[idx] = updated;
      _prependOfflineAudit(
        campaignId: id,
        versionId: nextVerId,
        eventType: 'VERSION_CREATED',
        previousState: existing.status,
        newState: 'Draft',
        summary: 'Created immutable v$nextNo for "${updated.title}"',
        details: '${nextVer.channel} · \$${nextVer.budget.toStringAsFixed(0)}',
      );
      return updated;
    }

    if (syncQueue.isOfflineSimulationEnabled) {
      final updated = applyOfflineUpdate();
      syncQueue.enqueueAction(
        actionType: 'UPDATE_CAMPAIGN',
        endpoint: '/api/campaigns/$id',
        method: 'PUT',
        payload: {
          'campaign_id': id,
          'expected_version': expectedVersion,
          ...body,
        },
      );
      return updated;
    }

    try {
      final res = await http
          .put(
            Uri.parse('$baseUrl/api/campaigns/$id'),
            headers: _headers(expectedVersion: expectedVersion),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        return Campaign.fromJson(jsonDecode(res.body));
      } else if (!_isBackendUnreachableStatus(res.statusCode)) {
        throw _parseWorkflowError(res, 'Update failed');
      }
    } catch (e) {
      if (e is WorkflowApiException) rethrow;
    }

    return applyOfflineUpdate();
  }

  // --- Submit Proposal ---
  Future<Map<String, dynamic>> submitCampaign(String id, {String? idempotencyKey}) async {
    final key = idempotencyKey ?? 'submit-$id-v${_mutableOfflineCampaigns.firstWhere((c) => c.campaignId == id, orElse: () => _mutableOfflineCampaigns.first).currentVersion?.versionNo ?? 1}';

    Map<String, dynamic> applyOfflineSubmit({bool queuedOffline = false}) {
      final idx = _mutableOfflineCampaigns.indexWhere((c) => c.campaignId == id);
      if (idx < 0) {
        throw const WorkflowApiException(
          statusCode: 404,
          code: 'CAMPAIGN_NOT_FOUND',
          message: 'Campaign does not exist.',
        );
      }
      final c = _mutableOfflineCampaigns[idx];
      final requestSignature = '$id:${currentUser.id}:${c.currentVersionId}';
      if (_offlineSubmittedIdempotencyHashes.containsKey(key)) {
        if (_offlineSubmittedIdempotencyHashes[key] != requestSignature) {
          throw const WorkflowApiException(
            statusCode: 409,
            code: 'IDEMPOTENCY_KEY_REUSED',
            message: 'Idempotency key reused with different request parameters.',
          );
        }
        return {'success': true, 'status': 'Submitted', 'campaign_id': id, 'idempotent_replay': true};
      }

      final caps = CampaignStateMachine.evaluate(c, currentUser);
      if (!caps.canSubmit) {
        throw WorkflowApiException(
          statusCode: caps.isOwner || caps.isAdmin ? 409 : 403,
          code: caps.isOwner || caps.isAdmin ? 'INVALID_TRANSITION' : 'FORBIDDEN',
          message: caps.submitBlockedReason ?? 'Campaign cannot be submitted in its current stage.',
          fromState: caps.stage.wireValue,
        );
      }

      _offlineSubmittedIdempotencyHashes[key] = requestSignature;
      final prevStatus = c.status;
      _mutableOfflineCampaigns[idx] = Campaign(
        campaignId: c.campaignId,
        title: c.title,
        ownerId: c.ownerId,
        ownerName: c.ownerName,
        status: CampaignStage.submitted.wireValue,
        currentVersionId: c.currentVersionId,
        currentVersion: c.currentVersion,
        versions: c.versions,
        decisions: c.decisions,
        activeLock: _offlineLocks[id] ?? c.activeLock,
        createdAt: c.createdAt,
        updatedAt: DateTime.now().toIso8601String(),
      );
      _prependOfflineAudit(
        campaignId: c.campaignId,
        versionId: c.currentVersionId,
        eventType: 'CAMPAIGN_SUBMITTED',
        previousState: prevStatus,
        newState: 'Submitted',
        summary: 'Submitted "${c.title}" (v${c.currentVersion?.versionNo ?? 1}) for review',
        details: 'Idempotency key ${key.substring(0, key.length > 14 ? 14 : key.length)}',
      );
      return {
        'success': true,
        'status': 'Submitted',
        'campaign_id': id,
        'queued_offline': queuedOffline,
      };
    }

    if (syncQueue.isOfflineSimulationEnabled) {
      final result = applyOfflineSubmit(queuedOffline: true);
      syncQueue.enqueueAction(
        actionType: 'SUBMIT_CAMPAIGN',
        endpoint: '/api/campaigns/$id/submit',
        method: 'POST',
        payload: {'campaign_id': id},
        customIdempotencyKey: key,
      );
      return result;
    }

    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/campaigns/$id/submit'),
            headers: _headers(idempotencyKey: key),
          )
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else if (!_isBackendUnreachableStatus(res.statusCode)) {
        throw _parseWorkflowError(res, 'Submission failed');
      }
    } catch (e) {
      if (e is WorkflowApiException) rethrow;
    }

    return applyOfflineSubmit();
  }

  // --- Review Decisions ---
  Future<Map<String, dynamic>> recordReviewDecision({
    required String campaignId,
    required String versionId,
    required String decisionType,
    required String reason,
    String? policyRef,
  }) async {
    return makeDecision(campaignId, decisionType, versionId, reason, policyReference: policyRef);
  }

  Future<Map<String, dynamic>> makeDecision(String id, String type, String versionId, String reason, {String? policyReference}) async {
    final endpoint = type == 'APPROVED'
        ? '/api/campaigns/$id/approve'
        : type == 'CHANGES_REQUESTED'
            ? '/api/campaigns/$id/request-changes'
            : '/api/campaigns/$id/reject';

    Map<String, dynamic> applyOfflineDecision({bool queuedOffline = false}) {
      if (reason.trim().isEmpty) {
        throw const WorkflowApiException(
          statusCode: 422,
          code: 'REASON_REQUIRED',
          message: 'Reason is required before recording a decision.',
        );
      }
      final idx = _mutableOfflineCampaigns.indexWhere((c) => c.campaignId == id);
      if (idx < 0) {
        throw const WorkflowApiException(
          statusCode: 404,
          code: 'CAMPAIGN_NOT_FOUND',
          message: 'Campaign not found',
        );
      }
      final camp = _mutableOfflineCampaigns[idx];
      if (!camp.versions.any((v) => v.versionId == versionId) && camp.currentVersionId != versionId) {
        throw const WorkflowApiException(
          statusCode: 422,
          code: 'VERSION_MISMATCH',
          message: 'Version does not belong to this campaign.',
        );
      }
      if (camp.decisions.any((d) => d.versionId == versionId)) {
        throw const WorkflowApiException(
          statusCode: 409,
          code: 'NOT_AWAITING_REVIEW',
          message: 'This version has already received a review decision.',
        );
      }
      final caps = CampaignStateMachine.evaluate(camp, currentUser);
      if (!caps.canReview) {
        throw WorkflowApiException(
          statusCode: caps.isOwner || !caps.isReviewerRole ? 403 : 409,
          code: caps.isOwner || !caps.isReviewerRole ? 'FORBIDDEN' : 'INVALID_TRANSITION',
          message: caps.reviewBlockedReason ?? 'Decision cannot be recorded right now.',
          fromState: caps.stage.wireValue,
        );
      }
      final nextStatus = type == 'APPROVED'
          ? CampaignStage.approved.wireValue
          : type == 'CHANGES_REQUESTED'
              ? CampaignStage.changesRequested.wireValue
              : CampaignStage.rejected.wireValue;
      final dec = ApprovalDecision(
        decisionId: 'dec-${DateTime.now().millisecondsSinceEpoch % 100000}',
        campaignId: camp.campaignId,
        versionId: versionId,
        reviewerId: currentUser.id,
        reviewerName: currentUser.name.split(' (').first,
        decisionType: type,
        reason: reason.trim(),
        policyReference: policyReference,
        decidedAt: DateTime.now().toIso8601String(),
      );
      _mutableOfflineCampaigns[idx] = Campaign(
        campaignId: camp.campaignId,
        title: camp.title,
        ownerId: camp.ownerId,
        ownerName: camp.ownerName,
        status: nextStatus,
        currentVersionId: camp.currentVersionId,
        currentVersion: camp.currentVersion,
        versions: camp.versions,
        decisions: [...camp.decisions, dec],
        activeLock: camp.activeLock,
        createdAt: camp.createdAt,
        updatedAt: DateTime.now().toIso8601String(),
      );
      final evtType = type == 'APPROVED'
          ? 'CAMPAIGN_APPROVED'
          : type == 'CHANGES_REQUESTED'
              ? 'CHANGES_REQUESTED'
              : 'CAMPAIGN_REJECTED';
      _prependOfflineAudit(
        campaignId: camp.campaignId,
        versionId: versionId,
        eventType: evtType,
        previousState: camp.status,
        newState: nextStatus,
        summary: 'Recorded $type on "${camp.title}"',
        details: reason.trim(),
      );
      return {
        'success': true,
        'decision_id': dec.decisionId,
        'status': nextStatus,
        'queued_offline': queuedOffline,
      };
    }

    if (syncQueue.isOfflineSimulationEnabled) {
      final result = applyOfflineDecision(queuedOffline: true);
      syncQueue.enqueueAction(
        actionType: 'MAKE_DECISION',
        endpoint: endpoint,
        method: 'POST',
        payload: {
          'campaign_id': id,
          'version_id': versionId,
          'decision': type,
          'reason': reason.trim(),
          if (policyReference != null) 'policy_reference': policyReference,
        },
      );
      return result;
    }

    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: _headers(),
            body: jsonEncode({
              'version_id': versionId,
              'decision': type,
              'reason': reason,
              if (policyReference != null) 'policy_reference': policyReference,
            }),
          )
          .timeout(const Duration(seconds: 2));

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else if (!_isBackendUnreachableStatus(res.statusCode)) {
        throw _parseWorkflowError(res, 'Decision submission failed');
      }
    } catch (e) {
      if (e is WorkflowApiException) rethrow;
    }

    return applyOfflineDecision();
  }

  // --- Scheduling ---
  Future<Map<String, dynamic>> scheduleCampaign(String id, String versionId, String startsAt, String endsAt, String channel) async {
    Map<String, dynamic> applyOfflineSchedule({bool queuedOffline = false}) {
      final idx = _mutableOfflineCampaigns.indexWhere((c) => c.campaignId == id);
      if (idx < 0) {
        throw const WorkflowApiException(
          statusCode: 404,
          code: 'CAMPAIGN_NOT_FOUND',
          message: 'Campaign not found',
        );
      }
      final camp = _mutableOfflineCampaigns[idx];
      final caps = CampaignStateMachine.evaluate(camp, currentUser);
      if (!caps.isOwner && !caps.isAdmin) {
        throw WorkflowApiException(
          statusCode: 403,
          code: 'FORBIDDEN',
          message: caps.scheduleBlockedReason ?? 'Only the campaign owner can schedule this campaign.',
        );
      }
      if (camp.currentVersionId != versionId) {
        throw WorkflowApiException(
          statusCode: 409,
          code: 'SCHEDULE_BLOCKED',
          message: 'Scheduling blocked: Prior version is superseded by v${camp.currentVersion?.versionNo ?? 1}.',
          fromState: caps.stage.wireValue,
        );
      }
      if (!caps.canSchedule) {
        throw WorkflowApiException(
          statusCode: 409,
          code: 'SCHEDULE_BLOCKED',
          message: caps.scheduleBlockedReason ?? 'Scheduling blocked: This exact version has not been approved.',
          fromState: caps.stage.wireValue,
        );
      }
      final start = DateTime.tryParse(startsAt);
      final end = DateTime.tryParse(endsAt);
      if (start == null || end == null || !end.isAfter(start)) {
        throw const WorkflowApiException(
          statusCode: 400,
          code: 'INVALID_DATES',
          message: 'Invalid schedule window: end date must be strictly after start date.',
        );
      }
      final overlap = _mutableOfflineCalendar.where((ev) {
        final evStatus = ev.status.toUpperCase();
        if (evStatus == 'CANCELLED' || evStatus == 'COMPLETED') return false;
        if (ev.channel.toLowerCase() != channel.toLowerCase() || ev.campaignId == id) return false;
        final s = DateTime.tryParse(ev.startsAt);
        final e = DateTime.tryParse(ev.endsAt);
        if (s == null || e == null) return false;
        return s.isBefore(end) && e.isAfter(start);
      }).toList();
      if (overlap.isNotEmpty) {
        throw WorkflowApiException(
          statusCode: 409,
          code: 'SCHEDULING_CONFLICT',
          message: 'Scheduling conflict: $channel slot is held by "${overlap.first.title}".',
          fromState: caps.stage.wireValue,
        );
      }

      _mutableOfflineCampaigns[idx] = Campaign(
        campaignId: camp.campaignId,
        title: camp.title,
        ownerId: camp.ownerId,
        ownerName: camp.ownerName,
        status: CampaignStage.scheduled.wireValue,
        currentVersionId: camp.currentVersionId,
        currentVersion: camp.currentVersion,
        versions: camp.versions,
        decisions: camp.decisions,
        activeLock: camp.activeLock,
        createdAt: camp.createdAt,
        updatedAt: DateTime.now().toIso8601String(),
      );
      _mutableOfflineCalendar.add(
        ScheduleEvent(
          scheduleId: 'sched-${DateTime.now().millisecondsSinceEpoch % 10000}',
          campaignId: camp.campaignId,
          title: camp.title,
          channel: channel,
          versionNo: camp.currentVersion?.versionNo ?? 1,
          budget: camp.currentVersion?.budget ?? 15000,
          startsAt: startsAt,
          endsAt: endsAt,
          status: 'ACTIVE',
        ),
      );
      _prependOfflineAudit(
        campaignId: camp.campaignId,
        versionId: versionId,
        eventType: 'FLIGHT_SCHEDULED',
        previousState: 'Approved',
        newState: 'Scheduled',
        summary: 'Scheduled "${camp.title}" on $channel',
        details: '$startsAt -> $endsAt',
      );
      return {'success': true, 'status': 'Scheduled', 'queued_offline': queuedOffline};
    }

    if (syncQueue.isOfflineSimulationEnabled) {
      final result = applyOfflineSchedule(queuedOffline: true);
      syncQueue.enqueueAction(
        actionType: 'SCHEDULE_CAMPAIGN',
        endpoint: '/api/campaigns/$id/schedule',
        method: 'POST',
        payload: {
          'campaign_id': id,
          'version_id': versionId,
          'channel': channel,
          'starts_at': startsAt,
          'ends_at': endsAt,
        },
      );
      return result;
    }

    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/campaigns/$id/schedule'),
            headers: _headers(),
            body: jsonEncode({
              'version_id': versionId,
              'starts_at': startsAt,
              'ends_at': endsAt,
              'channel': channel,
            }),
          )
          .timeout(const Duration(seconds: 2));

      if (res.statusCode == 201 || res.statusCode == 200) {
        return jsonDecode(res.body);
      } else if (!_isBackendUnreachableStatus(res.statusCode)) {
        throw _parseWorkflowError(res, 'Scheduling failed');
      }
    } catch (e) {
      if (e is WorkflowApiException) rethrow;
    }

    return applyOfflineSchedule();
  }

  // --- Concurrency Edit Lease ---
  Future<Map<String, dynamic>> acquireLock(String id) async {
    if (!syncQueue.isOfflineSimulationEnabled) {
      try {
        final res = await http.post(Uri.parse('$baseUrl/api/campaigns/$id/lock'), headers: _headers()).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          return jsonDecode(res.body);
        } else if (res.statusCode == 409) {
          final err = jsonDecode(res.body)['error'] as Map?;
          return {
            'granted': false,
            'holder_name': err?['holder'] ?? 'Another editor',
            'expires_at': err?['expires_at'],
            'message': err?['message'] ?? 'Campaign is currently locked by another editor.',
          };
        } else if (!_isBackendUnreachableStatus(res.statusCode)) {
          throw _parseWorkflowError(res, 'Failed to acquire edit lease');
        }
      } catch (e) {
        if (e is WorkflowApiException) rethrow;
      }
    }

    final now = DateTime.now();
    final existingLock = _offlineLocks[id];
    final lockInfo = CampaignStateMachine.evaluateLock(existingLock, currentUser.id, now: now);
    if (lockInfo.isHeldByOther) {
      return {
        'granted': false,
        'holder_id': lockInfo.holderId,
        'holder_name': lockInfo.holderName,
        'expires_at': existingLock?.expiresAt,
        'message': 'Campaign is currently locked by ${lockInfo.holderName}.',
      };
    }

    final expires = now.add(const Duration(minutes: 5));
    _offlineLocks[id] = EditLock(
      campaignId: id,
      holderId: currentUser.id,
      holderName: currentUser.name.split(' (').first,
      acquiredAt: now.toIso8601String(),
      expiresAt: expires.toIso8601String(),
    );
    return {
      'granted': true,
      'holder_id': currentUser.id,
      'holder_name': currentUser.name,
      'expires_at': expires.toIso8601String(),
    };
  }

  Future<void> releaseLock(String id) async {
    final existing = _offlineLocks[id];
    if (existing == null || existing.holderId == currentUser.id) {
      _offlineLocks.remove(id);
    }
    if (syncQueue.isOfflineSimulationEnabled) return;
    try {
      await http.delete(Uri.parse('$baseUrl/api/campaigns/$id/lock'), headers: _headers()).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  // --- Discussions ---
  Future<List<Collaborator>> getCollaborators(String id) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/campaigns/$id/collaborators'), headers: _headers()).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['collaborators'] as List).map((c) => Collaborator.fromJson(c)).toList();
      }
    } catch (_) {}
    return [
      Collaborator(userId: 'usr-marketer-1', name: 'Alice Cooper', role: 'marketer', email: 'alice.marketer@bitloggers.com'),
      Collaborator(userId: 'usr-reviewer-1', name: 'Marcus Vance', role: 'reviewer', email: 'marcus.reviewer@bitloggers.com'),
      Collaborator(userId: 'usr-reviewer-2', name: 'Elena Rostova', role: 'reviewer', email: 'elena.compliance@bitloggers.com'),
    ];
  }

  Future<List<DiscussionMessage>> getDiscussions(String id, {String? versionId}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/campaigns/$id/discussions').replace(
        queryParameters: {
          if (versionId != null) 'version_id': versionId,
        },
      );
      final res = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['messages'] as List).map((m) => DiscussionMessage.fromJson(m)).toList();
      }
    } catch (_) {}
    final list = _offlineDiscussions.putIfAbsent(
      id,
      () => [
        DiscussionMessage(
          messageId: 'msg-1',
          authorName: 'Marcus Vance',
          authorRole: 'reviewer',
          content: 'Please ensure high-CPA broad cohorts remain excluded on the revised snapshot.',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
          versionNo: 2,
          mentions: const ['Alice Cooper'],
        ),
        DiscussionMessage(
          messageId: 'msg-2',
          authorName: 'Alice Cooper',
          authorRole: 'marketer',
          content: 'Confirmed @Marcus Vance — suppressed 7 low-intent segments and locked Lookalike audience.',
          createdAt: DateTime.now().subtract(const Duration(minutes: 42)).toIso8601String(),
          versionNo: 3,
          mentions: const ['Marcus Vance'],
        ),
      ],
    );
    final isMarketer = currentUser.role.trim().toLowerCase() == 'marketer';
    return list.where((m) {
      if (isMarketer && m.isInternalOnly) return false;
      if (versionId != null && versionId.isNotEmpty && m.versionId != null && m.versionId != versionId) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<DiscussionMessage> postDiscussion(
    String id,
    String content, {
    String? parentMessageId,
    String? versionId,
    bool isInternalOnly = false,
  }) async {
    final sanitizedInternalOnly =
        currentUser.role.trim().toLowerCase() == 'marketer' ? false : isInternalOnly;

    DiscussionMessage appendOfflineDiscussion() {
      if (content.trim().isEmpty) {
        throw const WorkflowApiException(
          statusCode: 400,
          code: 'BLANK_MESSAGE',
          message: 'Message content cannot be blank.',
        );
      }
      final created = DiscussionMessage(
        messageId: 'msg-${DateTime.now().millisecondsSinceEpoch % 10000}',
        authorName: currentUser.name.split(' (').first,
        authorRole: currentUser.role,
        content: content.trim(),
        createdAt: DateTime.now().toIso8601String(),
        parentMessageId: parentMessageId,
        versionId: versionId,
        isInternalOnly: sanitizedInternalOnly,
      );
      _offlineDiscussions.putIfAbsent(id, () => []).add(created);
      return created;
    }

    if (syncQueue.isOfflineSimulationEnabled) {
      final created = appendOfflineDiscussion();
      syncQueue.enqueueAction(
        actionType: 'POST_DISCUSSION',
        endpoint: '/api/campaigns/$id/discussions',
        method: 'POST',
        payload: {
          'campaign_id': id,
          'content': content.trim(),
          if (parentMessageId != null) 'parent_message_id': parentMessageId,
          if (versionId != null) 'version_id': versionId,
          'is_internal_only': sanitizedInternalOnly,
        },
      );
      return created;
    }

    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/campaigns/$id/discussions'),
            headers: _headers(),
            body: jsonEncode({
              'content': content,
              if (parentMessageId != null) 'parentMessageId': parentMessageId,
              if (versionId != null) 'versionId': versionId,
              'isInternalOnly': sanitizedInternalOnly,
            }),
          )
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 201 || res.statusCode == 200) {
        return DiscussionMessage.fromJson(jsonDecode(res.body));
      } else if (!_isBackendUnreachableStatus(res.statusCode)) {
        throw _parseWorkflowError(res, 'Failed to post message');
      }
    } catch (e) {
      if (e is WorkflowApiException) rethrow;
    }

    return appendOfflineDiscussion();
  }

  /// Logs spend ceiling override/pause telemetry to the activity ledger.
  void recordSpendOverrideAudit({
    required String campaignId,
    required String campaignTitle,
    required String action,
    required String reason,
  }) {
    _prependOfflineAudit(
      campaignId: campaignId,
      eventType: action == 'RESUMED' ? 'DELIVERY_RESUMED' : 'DELIVERY_PAUSED',
      previousState: action == 'RESUMED' ? 'Paused' : 'Running',
      newState: action == 'RESUMED' ? 'Running' : 'Paused',
      summary: action == 'RESUMED'
          ? 'Resumed delivery for "$campaignTitle" with override reason'
          : 'Delivery paused at CPA ceiling for "$campaignTitle"',
      details: reason,
    );
  }

  // --- Notifications ---
  Future<Map<String, dynamic>> getNotifications() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/notifications'), headers: _headers()).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['notifications'] as List).map((n) => AppNotification.fromJson(n)).toList();
        return {'notifications': list, 'unreadCount': data['unreadCount'] ?? 0};
      }
    } catch (_) {}

    return {
      'notifications': _mutableOfflineNotifications,
      'unreadCount': _mutableOfflineNotifications.where((n) => !n.isRead).length,
    };
  }

  List<AppNotification> _buildInitialOfflineNotifications() {
    final now = DateTime.now();
    return <AppNotification>[
      AppNotification(
        notificationId: 'notif-01',
        title: 'Revisions requested on Black Friday Pass',
        message: 'Marcus Vance requested tighter VIP cohort targeting before signoff.',
        channel: 'in-app',
        priority: 'high',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 24)).toIso8601String(),
        campaignId: 'camp-02',
      ),
      AppNotification(
        notificationId: 'notif-02',
        title: 'Enterprise AI Rollout awaiting review',
        message: 'Proposal v1 (\$28,000 Search) queued for compliance signoff.',
        channel: 'in-app',
        priority: 'medium',
        isRead: false,
        createdAt: now.subtract(const Duration(hours: 3)).toIso8601String(),
        campaignId: 'camp-03',
      ),
      AppNotification(
        notificationId: 'notif-03',
        title: 'Summer Solar Flash Sale scheduled',
        message: 'Flight window confirmed across Social lane.',
        channel: 'in-app',
        priority: 'low',
        isRead: true,
        createdAt: now.subtract(const Duration(days: 1)).toIso8601String(),
        campaignId: 'camp-01',
      ),
    ];
  }

  Future<void> markAllNotificationsRead() async {
    _offlineNotifications = _mutableOfflineNotifications
        .map(
          (n) => AppNotification(
            notificationId: n.notificationId,
            title: n.title,
            message: n.message,
            channel: n.channel,
            priority: n.priority,
            isRead: true,
            createdAt: n.createdAt,
            campaignId: n.campaignId,
          ),
        )
        .toList();
    try {
      await http.post(Uri.parse('$baseUrl/api/notifications/read-all'), headers: _headers()).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  Future<void> markNotificationRead(String notificationId) async {
    _offlineNotifications = _mutableOfflineNotifications
        .map(
          (n) => n.notificationId == notificationId
              ? AppNotification(
                  notificationId: n.notificationId,
                  title: n.title,
                  message: n.message,
                  channel: n.channel,
                  priority: n.priority,
                  isRead: true,
                  createdAt: n.createdAt,
                  campaignId: n.campaignId,
                )
              : n,
        )
        .toList();
    try {
      await http
          .post(
            Uri.parse('$baseUrl/api/notifications/$notificationId/read'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  // --- Analytics ---
  Future<Map<String, dynamic>> getAnalytics({
    String? channel,
    String? startDate,
    String? endDate,
    String? interval,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/analytics').replace(queryParameters: {
        if (channel != null && channel != 'All') 'channel': channel,
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        if (interval != null) 'interval': interval,
      });
      final res = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}

    final allBreakdown = [
      {'channel': 'Search', 'count': 1, 'budget': 28000.0, 'roi': 5.5, 'conv': 4.8},
      {'channel': 'Email', 'count': 1, 'budget': 22000.0, 'roi': 5.1, 'conv': 5.6},
      {'channel': 'Social', 'count': 1, 'budget': 18500.0, 'roi': 4.6, 'conv': 4.2},
      {'channel': 'Display', 'count': 1, 'budget': 15000.0, 'roi': 1.8, 'conv': 1.5},
    ];
    final filteredBreakdown = (channel != null && channel != 'All')
        ? allBreakdown.where((b) => b['channel'].toString().toLowerCase() == channel.toLowerCase()).toList()
        : allBreakdown;
    final totalB = filteredBreakdown.fold<double>(0.0, (s, e) => s + (e['budget'] as double));

    final now = DateTime.now();
    final trends = List<Map<String, dynamic>>.generate(14, (idx) {
      final d = now.subtract(Duration(days: 13 - idx));
      final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final wave = (idx % 4 - 1.5) * 0.14;
      final lift = (idx / 13.0) * 0.45;
      return {
        'date': dateStr,
        'projected': {
          'roi': 4.05 + (idx * 0.015),
          'conversionRate': 3.75 + (idx * 0.01),
          'ctr': 4.45 + (idx * 0.01),
          'cpa': 24.8 - (idx * 0.04),
          'aov': 110.0 + (idx * 0.3),
        },
        'actual': {
          'roi': (4.10 + lift + wave).clamp(3.2, 5.4),
          'conversionRate': (3.85 + lift * 0.7 + wave * 0.5).clamp(2.8, 5.5),
          'ctr': (4.55 + lift * 0.8 + wave * 0.4).clamp(3.5, 6.2),
          'cpa': (24.2 - lift * 4.2 - wave * 1.4).clamp(18.0, 27.0),
          'aov': (112.0 + lift * 14.0 + wave * 5.0).clamp(98.0, 134.0),
        },
      };
    });

    return {
      'summary': {
        'totalCampaigns': filteredBreakdown.length,
        'totalBudget': totalB,
        'kpis': {
          'conversionRate': {'name': 'Conversion Rate', 'unit': '%', 'projected': 3.8, 'actual': 4.1},
          'ctr': {'name': 'Click-Through Rate', 'unit': '%', 'projected': 4.5, 'actual': 4.9},
          'roi': {'name': 'Return on Investment', 'unit': 'x', 'projected': 4.1, 'actual': 4.4},
          'cpa': {'name': 'Cost Per Acquisition', 'unit': '\$', 'projected': 24.5, 'actual': 22.0},
          'aov': {'name': 'Average Order Value', 'unit': '\$', 'projected': 110.0, 'actual': 118.0},
        }
      },
      'channelBreakdown': filteredBreakdown,
      'trends': trends,
    };
  }

  // --- Calendar ---
  Future<List<ScheduleEvent>> getCalendar() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/calendar'), headers: _headers()).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['events'] as List).map((e) => ScheduleEvent.fromJson(e)).toList();
      }
    } catch (_) {}

    return List<ScheduleEvent>.from(_mutableOfflineCalendar);
  }

  List<ScheduleEvent> _buildInitialOfflineCalendar() {
    final today = DateTime.now();
    final d0 = DateTime(today.year, today.month, today.day, 9, 0);
    final d1 = d0.add(const Duration(days: 1));
    final d2 = d0.add(const Duration(days: 2));
    final d4 = d0.add(const Duration(days: 4));
    final d5 = d0.add(const Duration(days: 5));
    return [
      ScheduleEvent(
        scheduleId: 'sched-01',
        campaignId: 'camp-01',
        title: 'Summer Solar Flash Sale',
        channel: 'Social',
        versionNo: 3,
        budget: 25000,
        startsAt: d1.toIso8601String(),
        endsAt: d5.toIso8601String(),
        status: 'SCHEDULED',
      ),
      ScheduleEvent(
        scheduleId: 'sched-02',
        campaignId: 'camp-03',
        title: 'Enterprise AI Assistant Rollout',
        channel: 'Search',
        versionNo: 1,
        budget: 28000,
        startsAt: d0.toIso8601String(),
        endsAt: d4.toIso8601String(),
        status: 'SCHEDULED',
      ),
      ScheduleEvent(
        scheduleId: 'sched-03',
        campaignId: 'camp-02',
        title: 'Black Friday Super Savings Pass',
        channel: 'Email',
        versionNo: 2,
        budget: 22000,
        startsAt: d1.toIso8601String(),
        endsAt: d2.toIso8601String(),
        status: 'SCHEDULED',
      ),
    ];
  }

  Future<void> seedCalendar() async {
    try {
      await http.post(Uri.parse('$baseUrl/api/seed/calendar'), headers: _headers()).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  // --- Audit Trail ---
  Future<List<AuditEventItem>> getAudit({String? campaignId, String? eventType, String? search}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/audit').replace(queryParameters: {
        if (campaignId != null && campaignId.isNotEmpty) 'campaign_id': campaignId,
        if (eventType != null && eventType.isNotEmpty && eventType != 'ALL') 'event_type': eventType,
        if (search != null && search.isNotEmpty) 'search': search,
      });
      final res = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['audit'] as List).map((a) => AuditEventItem.fromJson(a)).toList();
      }
    } catch (_) {}

    return _mutableOfflineAudit.where((e) {
      if (campaignId != null && campaignId.isNotEmpty && e.campaignId != campaignId) return false;
      if (eventType != null && eventType.isNotEmpty && eventType != 'ALL' && e.eventType != eventType) return false;
      if (search != null && search.isNotEmpty) {
        final q = search.toLowerCase();
        return e.actorName.toLowerCase().contains(q) ||
            e.eventType.toLowerCase().contains(q) ||
            e.summary.toLowerCase().contains(q) ||
            (e.campaignId?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList();
  }

  List<AuditEventItem> _buildInitialOfflineAudit() {
    final now = DateTime.now();
    return [
      AuditEventItem(
        eventId: 'aud-01',
        campaignId: 'camp-01',
        versionId: 'ver-01-v3',
        actorId: 'usr-marketer-1',
        actorName: 'Alice Cooper',
        eventType: 'CAMPAIGN_SUBMITTED',
        previousState: 'ChangesRequested',
        newState: 'Submitted',
        summary: 'Submitted Summer Solar Flash Sale v3 (Lookalike, \$25,000)',
        details: 'Narrowed to high-intent Lookalike segments and raised budget to \$25,000.',
        correlationId: 'c-91a4f02b',
        occurredAt: now.subtract(const Duration(minutes: 18)).toIso8601String(),
      ),
      AuditEventItem(
        eventId: 'aud-02',
        campaignId: 'camp-01',
        versionId: 'ver-01-v2',
        actorId: 'usr-reviewer-1',
        actorName: 'Marcus Vance',
        eventType: 'CHANGES_REQUESTED',
        previousState: 'Submitted',
        newState: 'ChangesRequested',
        summary: 'Requested tighter audience on Summer Solar Flash Sale v2',
        details: 'Broad reach causes high-CPA waste segments; isolate Lookalike tier first.',
        correlationId: 'c-88c1e410',
        occurredAt: now.subtract(const Duration(hours: 2)).toIso8601String(),
      ),
      AuditEventItem(
        eventId: 'aud-03',
        campaignId: 'camp-01',
        versionId: 'ver-01-v1',
        actorId: 'usr-reviewer-1',
        actorName: 'Marcus Vance',
        eventType: 'CAMPAIGN_APPROVED',
        previousState: 'Submitted',
        newState: 'Approved',
        summary: 'Approved Summer Solar Flash Sale v1 pilot cap (\$20,000)',
        details: 'Approved pilot cap within Q4 threshold.',
        correlationId: 'c-71d29a04',
        occurredAt: now.subtract(const Duration(hours: 5)).toIso8601String(),
      ),
      AuditEventItem(
        eventId: 'aud-04',
        campaignId: 'camp-03',
        versionId: 'ver-03',
        actorId: 'usr-marketer-1',
        actorName: 'Alice Cooper',
        eventType: 'CAMPAIGN_SUBMITTED',
        previousState: 'Draft',
        newState: 'Submitted',
        summary: 'Submitted Enterprise AI Assistant Rollout v1 for signoff',
        details: 'Submitted Search proposal (\$28,000 cap)',
        correlationId: 'c-45f08b12',
        occurredAt: now.subtract(const Duration(days: 1)).toIso8601String(),
      ),
      AuditEventItem(
        eventId: 'aud-05',
        campaignId: 'camp-02',
        versionId: 'ver-02',
        actorId: 'usr-reviewer-1',
        actorName: 'Marcus Vance',
        eventType: 'EDIT_LOCK_CONFLICT',
        previousState: 'ChangesRequested',
        newState: 'ChangesRequested',
        summary: 'Prevented concurrent overwrite while edit lease was active',
        details: 'Guarded version v2 against stale save',
        correlationId: 'c-19b77c3e',
        occurredAt: now.subtract(const Duration(days: 2)).toIso8601String(),
      ),
    ];
  }

  // --- Diagnostics ---
  Future<List<DiagnosticLogItem>> getDiagnostics({String? eventType}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/diagnostics').replace(queryParameters: {
        if (eventType != null && eventType.isNotEmpty) 'event_type': eventType,
      });
      final res = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['logs'] as List).map((l) => DiagnosticLogItem.fromJson(l)).toList();
      }
    } catch (_) {}

    final now = DateTime.now();
    return [
      DiagnosticLogItem(
        logId: 'diag-01',
        correlationId: 'c-91a4f02b',
        eventType: 'SCHEDULE_BOOKED',
        outcome: 'SUCCESS',
        message: 'Flight window verified against overlapping Social lane slots (18ms).',
        timestamp: now.subtract(const Duration(minutes: 14)).toIso8601String(),
      ),
      DiagnosticLogItem(
        logId: 'diag-02',
        correlationId: 'c-88c1e410',
        eventType: 'APPROVAL_COMMITTED',
        outcome: 'SUCCESS',
        message: 'Decision persisted to immutable audit log and outbox queued.',
        timestamp: now.subtract(const Duration(hours: 2)).toIso8601String(),
      ),
      DiagnosticLogItem(
        logId: 'diag-03',
        correlationId: 'c-71d29a04',
        eventType: 'OUTBOX_DISPATCH',
        outcome: 'INFO',
        message: 'Queued stakeholder notification batch for camp-02 revision.',
        timestamp: now.subtract(const Duration(hours: 5)).toIso8601String(),
      ),
      DiagnosticLogItem(
        logId: 'diag-04',
        correlationId: 'c-19b77c3e',
        eventType: 'SCHEDULE_CONFLICT_GUARD',
        outcome: 'FAILURE',
        message: 'Rejected overlapping Social slot submission during conflict check.',
        timestamp: now.subtract(const Duration(days: 1)).toIso8601String(),
      ),
    ];
  }

  // --- AI Drafting ---
  Future<Map<String, dynamic>> draftWithAI(String prompt, {String? channel, double? budget}) async {
    final chosenChannel = channel ?? 'Social';
    final chosenBudget = budget ?? 25000.0;
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/ai/draft'),
            headers: _headers(),
            body: jsonEncode({
              'prompt': prompt,
              'channel': chosenChannel,
              'budget': chosenBudget,
            }),
          )
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else if (!_isBackendUnreachableStatus(res.statusCode)) {
        final err = jsonDecode(res.body);
        throw Exception(err['error']?['message'] ?? 'AI generation failed');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('AI generation failed')) {
        rethrow;
      }
    }

    // Structured local synthesis fallback when backend AI service is offline
    final cleanedPrompt = prompt.trim().isNotEmpty ? prompt.trim() : 'Seasonal high-intent conversion push';
    return {
      'title': cleanedPrompt.length > 36 ? '${cleanedPrompt.substring(0, 34)}…' : cleanedPrompt,
      'objective': 'Drive measurable acquisition for "$cleanedPrompt" across $chosenChannel within CPA guardrails.',
      'target_audience': 'Lookalike high-intent cohort (5/12 top converting segments)',
      'channel': chosenChannel,
      'budget': chosenBudget,
      'kpi_projected': {
        'conversionRate': 3.4,
        'ctr': 2.9,
        'roi': 4.1,
        'cpa': 11.8,
        'aov': 84.0,
      },
      'ai_summary': 'Suppressed broad waste segments and calibrated cap below ceiling.',
    };
  }

  // --- Run All Architecture Tests (LLD Section 14) ---
  Future<Map<String, dynamic>> runTests() async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/api/test/run-all'), headers: _headers()).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    throw Exception('Failed to run test suite on backend server.');
  }

  // --- Offline Sync Queue (FR-13, ADR-005) ---
  Future<Map<String, dynamic>> syncBatch(List<OfflineSyncAction> actions) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/sync/queue'),
        headers: _headers(),
        body: jsonEncode({
          'actions': actions.map((a) => a.toServerAction()).toList(),
        }),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else if (!_isBackendUnreachableStatus(res.statusCode)) {
        throw _parseWorkflowError(res, 'Batch sync failed with status ${res.statusCode}');
      }
    } catch (e) {
      if (e is WorkflowApiException) rethrow;
      if (!syncQueue.isOfflineSimulationEnabled && isConnected) {
        rethrow;
      }
    }

    // Explicit offline / disconnected simulation fallback
    return {
      'processed': actions.length,
      'synced': actions.length,
      'failed': 0,
      'results': actions
          .map((a) => {
                'action_id': a.actionId,
                'idempotency_key': a.idempotencyKey,
                'status': 'SYNCED',
                'is_replay': false,
                'response_code': 200,
                'data': {'mock_synced': true, 'action_type': a.actionType},
              })
          .toList(),
    };
  }

  // --- Transactional Outbox (FR-14, ADR-004) ---
  bool _mockEmailFailing = false;
  late final List<OutboxEventItem> _mockOutboxEvents = [
    OutboxEventItem(
      eventId: 'evt-outbox-mock-1',
      eventType: 'CAMPAIGN_SUBMITTED_EMAIL',
      payload: {'recipient': 'marcus.reviewer@bitloggers.com', 'subject': 'Campaign V3 Needs Review'},
      status: OutboxDeliveryState.processed.wireValue,
      attempts: 1,
      maxAttempts: OutboxDeliveryState.defaultMaxAttempts,
      createdAt: DateTime.now().subtract(const Duration(minutes: 12)).toIso8601String(),
      processedAt: DateTime.now().subtract(const Duration(minutes: 11)).toIso8601String(),
    ),
    OutboxEventItem(
      eventId: 'evt-outbox-mock-2',
      eventType: 'CAMPAIGN_DECISION_EMAIL',
      payload: {'recipient': 'alice.marketer@bitloggers.com', 'subject': 'Decision: APPROVED'},
      status: OutboxDeliveryState.processed.wireValue,
      attempts: 1,
      maxAttempts: OutboxDeliveryState.defaultMaxAttempts,
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
      processedAt: DateTime.now().subtract(const Duration(minutes: 4)).toIso8601String(),
    ),
    OutboxEventItem(
      eventId: 'evt-outbox-mock-3',
      eventType: 'ANALYTICS_DATA_SYNC',
      payload: {'metric': 'roi', 'campaign_id': 'camp-01'},
      status: OutboxDeliveryState.pending.wireValue,
      attempts: 0,
      maxAttempts: OutboxDeliveryState.defaultMaxAttempts,
      createdAt: DateTime.now().subtract(const Duration(minutes: 1)).toIso8601String(),
    ),
  ];

  Future<Map<String, dynamic>> getOutbox() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/outbox'), headers: _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final eventsList = (data['events'] as List? ?? [])
            .map((e) => OutboxEventItem.fromJson(e))
            .toList();
        final stats = OutboxStats.fromJson(data);
        return {
          'events': eventsList,
          'stats': stats,
          'isEmailServiceFailing': data['isEmailServiceFailing'] == true,
        };
      }
    } catch (_) {}

    // Fallback dynamic stateful mock outbox data for offline presentation
    final pendingCount = _mockOutboxEvents.where((e) => e.status == 'PENDING').length;
    final processingCount = _mockOutboxEvents.where((e) => e.status == 'PROCESSING').length;
    final processedCount = _mockOutboxEvents.where((e) => e.status == 'PROCESSED').length;
    final failedCount = _mockOutboxEvents.where((e) => e.status == 'FAILED').length;
    return {
      'events': List<OutboxEventItem>.from(_mockOutboxEvents),
      'stats': OutboxStats(
        pending: pendingCount,
        processing: processingCount,
        processed: processedCount,
        failed: failedCount,
        total: _mockOutboxEvents.length,
        isEmailServiceFailing: _mockEmailFailing,
      ),
      'isEmailServiceFailing': _mockEmailFailing,
    };
  }

  Future<List<dynamic>> processOutbox() async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/api/outbox/process'), headers: _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['processed'] ?? [];
      }
    } catch (_) {}

    // Fallback dynamic mock worker processing respecting maxAttempts & incrementing attempts
    final processedList = <dynamic>[];
    for (int i = 0; i < _mockOutboxEvents.length; i++) {
      final evt = _mockOutboxEvents[i];
      if (evt.status == 'PENDING' || evt.status == 'FAILED') {
        final nextAttempts = evt.attempts + 1;
        if (_mockEmailFailing) {
          _mockOutboxEvents[i] = OutboxEventItem(
            eventId: evt.eventId,
            eventType: evt.eventType,
            payload: evt.payload,
            status: 'FAILED',
            attempts: nextAttempts,
            maxAttempts: evt.maxAttempts,
            createdAt: evt.createdAt,
            errorLog: 'EmailProviderGatewayTimeout: MockSMTP unreachable (504)',
          );
          processedList.add({'event_id': evt.eventId, 'status': 'FAILED'});
        } else {
          _mockOutboxEvents[i] = OutboxEventItem(
            eventId: evt.eventId,
            eventType: evt.eventType,
            payload: evt.payload,
            status: 'PROCESSED',
            attempts: nextAttempts,
            maxAttempts: evt.maxAttempts,
            createdAt: evt.createdAt,
            processedAt: DateTime.now().toIso8601String(),
          );
          processedList.add({'event_id': evt.eventId, 'status': 'PROCESSED'});
        }
      }
    }
    return processedList;
  }

  Future<bool> toggleEmailFailure({bool? failing}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/outbox/toggle-email-failure'),
        headers: _headers(),
        body: jsonEncode({if (failing != null) 'failing': failing}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final state = data['isEmailServiceFailing'] == true;
        _mockEmailFailing = state;
        return state;
      }
    } catch (_) {}
    _mockEmailFailing = failing ?? !_mockEmailFailing;
    return _mockEmailFailing;
  }

  Future<bool> createTestOutboxEvent() async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/outbox/test-event'),
        headers: _headers(),
      );
      if (res.statusCode == 200) return true;
    } catch (_) {}

    // Fallback dynamic mock test event injection
    final id = 'evt-test-${DateTime.now().millisecondsSinceEpoch % 10000}';
    final newEvt = OutboxEventItem(
      eventId: id,
      eventType: 'TEST_NOTIFICATION_EMAIL',
      payload: {
        'recipients': [currentUser.id],
        'title': 'Manual Outbox Test Notification',
        'message': 'Testing transactional outbox notification delivery and retry resilience.',
      },
      status: 'PENDING',
      attempts: 0,
      maxAttempts: 5,
      createdAt: DateTime.now().toIso8601String(),
    );
    _mockOutboxEvents.insert(0, newEvt);
    return true;
  }

  Future<bool> resetOutbox() async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/api/outbox/reset'), headers: _headers());
      if (res.statusCode == 200) return true;
    } catch (_) {}

    _mockEmailFailing = false;
    _mockOutboxEvents.clear();
    _mockOutboxEvents.addAll([
      OutboxEventItem(
        eventId: 'outbox-clean-01',
        eventType: 'CAMPAIGN_APPROVED',
        payload: {
          'recipients': ['marcus.reviewer@bitloggers.com'],
          'title': 'Campaign "Nordic Summer Flash" Approved',
          'message': 'Campaign proposal has been approved and moved to ready state.',
        },
        status: 'PROCESSED',
        attempts: 1,
        maxAttempts: 3,
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
        processedAt: DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
      ),
      OutboxEventItem(
        eventId: 'outbox-clean-02',
        eventType: 'FLIGHT_SCHEDULED',
        payload: {
          'recipients': ['alice.cooper@bitloggers.com'],
          'title': 'Flight Scheduled: Social & Display',
          'message': 'Campaign flight scheduled for Nov 10 - Nov 18 across omnichannel lanes.',
        },
        status: 'PROCESSED',
        attempts: 1,
        maxAttempts: 3,
        createdAt: DateTime.now().subtract(const Duration(minutes: 8)).toIso8601String(),
        processedAt: DateTime.now().subtract(const Duration(minutes: 8)).toIso8601String(),
      ),
      OutboxEventItem(
        eventId: 'outbox-clean-03',
        eventType: 'BUDGET_REALLOCATION_ALERT',
        payload: {
          'recipients': ['finance-lead@bitloggers.com'],
          'title': 'Budget Cap Reallocation Alert',
          'message': 'Notice: Budget cap update pending dispatch confirmation.',
        },
        status: 'PENDING',
        attempts: 0,
        maxAttempts: 3,
        createdAt: DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String(),
      ),
    ]);
    return true;
  }

  // Fallback initial demo campaigns with rich version histories & decisions
  List<Campaign> _buildInitialOfflineCampaigns() {
    final now = DateTime.now();

    final v1Camp01 = CampaignVersion(
      versionId: 'ver-01-v1',
      campaignId: 'camp-01',
      versionNo: 1,
      objective: 'Initial solar pilot cap for Q4 homeowner launch.',
      targetAudience: 'Broad',
      channel: 'Social',
      budget: 20000,
      kpiProjected: KpiMetrics(conversionRate: 2.3, ctr: 1.9, roi: 3.1, cpa: 15.00, aov: 120.00),
      aiSummary: 'Baseline Q4 Social pilot.',
      createdBy: 'usr-marketer-1',
      createdAt: now.subtract(const Duration(days: 4)).toIso8601String(),
    );
    final v2Camp01 = CampaignVersion(
      versionId: 'ver-01-v2',
      campaignId: 'camp-01',
      versionNo: 2,
      objective: 'Hold pilot spend while isolating solar homeowner segments.',
      targetAudience: 'Broad',
      channel: 'Social',
      budget: 20000,
      kpiProjected: KpiMetrics(conversionRate: 2.5, ctr: 2.1, roi: 3.4, cpa: 14.90, aov: 125.00),
      aiSummary: 'Broad reach flagged 3 high-CPA waste segments.',
      createdBy: 'usr-marketer-1',
      createdAt: now.subtract(const Duration(days: 2)).toIso8601String(),
    );
    final v3Camp01 = CampaignVersion(
      versionId: 'ver-01-v3',
      campaignId: 'camp-01',
      versionNo: 3,
      objective: 'Drive consumer adoption for eco-friendly home solar accessories.',
      targetAudience: 'Lookalike',
      channel: 'Social',
      budget: 25000,
      kpiProjected: KpiMetrics(conversionRate: 3.1, ctr: 2.8, roi: 4.6, cpa: 11.40, aov: 145.00),
      aiSummary: 'Suppressed 7 low-intent segments; isolated top 5 Lookalike tiers below \$30k ceiling.',
      createdBy: 'usr-marketer-1',
      createdAt: now.subtract(const Duration(hours: 3)).toIso8601String(),
    );

    final v1Camp02 = CampaignVersion(
      versionId: 'ver-02-v1',
      campaignId: 'camp-02',
      versionNo: 1,
      objective: 'Early VIP member pass teaser.',
      targetAudience: 'Broad',
      channel: 'Display',
      budget: 15000,
      kpiProjected: KpiMetrics(conversionRate: 3.4, ctr: 3.2, roi: 3.8, cpa: 16.40, aov: 110.00),
      createdBy: 'usr-marketer-1',
      createdAt: now.subtract(const Duration(days: 3)).toIso8601String(),
    );
    final v2Camp02 = CampaignVersion(
      versionId: 'ver-02-v2',
      campaignId: 'camp-02',
      versionNo: 2,
      objective: 'Pre-launch exclusive membership pass for holiday buyers.',
      targetAudience: 'Lookalike',
      channel: 'Display',
      budget: 18000,
      kpiProjected: KpiMetrics(conversionRate: 5.6, ctr: 6.2, roi: 5.1, cpa: 14.20, aov: 115.00),
      aiSummary: 'Narrowed VIP cohort sequences with improved economics.',
      createdBy: 'usr-marketer-1',
      createdAt: now.subtract(const Duration(days: 1)).toIso8601String(),
    );

    final v1Camp03 = CampaignVersion(
      versionId: 'ver-03-v1',
      campaignId: 'camp-03',
      versionNo: 1,
      objective: 'Drive enterprise B2B inbound demos for workflow intelligence.',
      targetAudience: 'Broad',
      channel: 'Search',
      budget: 25000,
      kpiProjected: KpiMetrics(conversionRate: 3.9, ctr: 5.1, roi: 4.6, cpa: 28.00, aov: 210.00),
      createdBy: 'usr-marketer-1',
      createdAt: now.subtract(const Duration(days: 2)).toIso8601String(),
    );
    final v2Camp03 = CampaignVersion(
      versionId: 'ver-03-v2',
      campaignId: 'camp-03',
      versionNo: 2,
      objective: 'Scale Search pipeline across VP Marketing & Ops buyers.',
      targetAudience: 'Lookalike',
      channel: 'Search',
      budget: 28000,
      kpiProjected: KpiMetrics(conversionRate: 4.8, ctr: 6.5, roi: 5.5, cpa: 12.50, aov: 240.00),
      aiSummary: 'High-intent search keyword campaign targeting corporate marketing leaders.',
      createdBy: 'usr-marketer-1',
      createdAt: now.subtract(const Duration(days: 1)).toIso8601String(),
    );

    final v1Camp04 = CampaignVersion(
      versionId: 'ver-04-v1',
      campaignId: 'camp-04',
      versionNo: 1,
      objective: 'Incentivize checkout using digital token cashback.',
      targetAudience: 'Broad',
      channel: 'Email',
      budget: 15000,
      kpiProjected: KpiMetrics(conversionRate: 4.1, ctr: 4.5, roi: 4.9, cpa: 13.80, aov: 105.00),
      aiSummary: 'Targeted opt-in loyalty tier.',
      createdBy: 'usr-marketer-1',
      createdAt: now.subtract(const Duration(days: 4)).toIso8601String(),
    );

    return [
      Campaign(
        campaignId: 'camp-01',
        title: 'Summer Solar Flash Sale',
        ownerId: 'usr-marketer-1',
        ownerName: 'Alice Cooper',
        status: 'Submitted',
        currentVersionId: v3Camp01.versionId,
        currentVersion: v3Camp01,
        versions: [v1Camp01, v2Camp01, v3Camp01],
        decisions: [
          ApprovalDecision(
            decisionId: 'dec-01-v1',
            campaignId: 'camp-01',
            versionId: v1Camp01.versionId,
            reviewerId: 'usr-reviewer-1',
            reviewerName: 'Marcus Vance',
            decisionType: 'APPROVED',
            reason: 'Initial pilot cap within Q4 threshold',
            decidedAt: now.subtract(const Duration(days: 3, hours: 18)).toIso8601String(),
          ),
          ApprovalDecision(
            decisionId: 'dec-01-v2',
            campaignId: 'camp-01',
            versionId: v2Camp01.versionId,
            reviewerId: 'usr-reviewer-1',
            reviewerName: 'Marcus Vance',
            decisionType: 'CHANGES_REQUESTED',
            reason: 'Broad reach causes 3 high-CPA waste segments; narrow to Lookalike before scaling.',
            decidedAt: now.subtract(const Duration(days: 1, hours: 20)).toIso8601String(),
          ),
        ],
        createdAt: now.subtract(const Duration(days: 4)).toIso8601String(),
        updatedAt: now.subtract(const Duration(hours: 3)).toIso8601String(),
      ),
      Campaign(
        campaignId: 'camp-02',
        title: 'Black Friday Super Savings Pass',
        ownerId: 'usr-marketer-1',
        ownerName: 'Alice Cooper',
        status: 'Submitted',
        currentVersionId: v2Camp02.versionId,
        currentVersion: v2Camp02,
        versions: [v1Camp02, v2Camp02],
        decisions: [
          ApprovalDecision(
            decisionId: 'dec-02-v1',
            campaignId: 'camp-02',
            versionId: v1Camp02.versionId,
            reviewerId: 'usr-reviewer-1',
            reviewerName: 'Marcus Vance',
            decisionType: 'APPROVED',
            reason: 'Display frequency cap verified',
            decidedAt: now.subtract(const Duration(days: 2)).toIso8601String(),
          ),
        ],
        activeLock: EditLock(
          campaignId: 'camp-02',
          holderId: 'usr-reviewer-2',
          holderName: 'Elena Rostova',
          acquiredAt: now.toIso8601String(),
          expiresAt: now.add(const Duration(minutes: 3, seconds: 22)).toIso8601String(),
        ),
        createdAt: now.subtract(const Duration(days: 3)).toIso8601String(),
        updatedAt: now.subtract(const Duration(hours: 6)).toIso8601String(),
      ),
      Campaign(
        campaignId: 'camp-03',
        title: 'Enterprise AI Assistant Rollout',
        ownerId: 'usr-marketer-1',
        ownerName: 'Alice Cooper',
        status: 'Approved',
        currentVersionId: v2Camp03.versionId,
        currentVersion: v2Camp03,
        versions: [v1Camp03, v2Camp03],
        decisions: [
          ApprovalDecision(
            decisionId: 'dec-03-v2',
            campaignId: 'camp-03',
            versionId: v2Camp03.versionId,
            reviewerId: 'usr-reviewer-1',
            reviewerName: 'Marcus Vance',
            decisionType: 'APPROVED',
            reason: 'Strong Lookalike aperture and CPA guardrail aligned.',
            decidedAt: now.subtract(const Duration(hours: 5)).toIso8601String(),
          ),
        ],
        createdAt: now.subtract(const Duration(days: 2)).toIso8601String(),
        updatedAt: now.subtract(const Duration(hours: 5)).toIso8601String(),
      ),
      Campaign(
        campaignId: 'camp-04',
        title: 'VIP Retention Early Access',
        ownerId: 'usr-marketer-1',
        ownerName: 'Alice Cooper',
        status: 'Scheduled',
        currentVersionId: v1Camp04.versionId,
        currentVersion: v1Camp04,
        versions: [v1Camp04],
        decisions: [
          ApprovalDecision(
            decisionId: 'dec-04-v1',
            campaignId: 'camp-04',
            versionId: v1Camp04.versionId,
            reviewerId: 'usr-reviewer-1',
            reviewerName: 'Marcus Vance',
            decisionType: 'APPROVED',
            reason: 'Compliant VIP opt-in distribution.',
            decidedAt: now.subtract(const Duration(days: 3)).toIso8601String(),
          ),
        ],
        createdAt: now.subtract(const Duration(days: 4)).toIso8601String(),
        updatedAt: now.subtract(const Duration(days: 2)).toIso8601String(),
      ),
    ];
  }
}

