import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../state/campaign_state_machine.dart';
import 'api_service.dart';

/// SyncQueueService manages the client-side offline action queue (FR-13, ADR-005).
/// Uses explicit SyncActionState lifecycle (PENDING -> SYNCING -> SYNCED | FAILED).
class SyncQueueService extends ChangeNotifier {
  static final SyncQueueService _instance = SyncQueueService._internal();
  factory SyncQueueService() => _instance;
  SyncQueueService._internal();

  bool _isOfflineSimulationEnabled = false;
  bool get isOfflineSimulationEnabled => _isOfflineSimulationEnabled;

  final List<OfflineSyncAction> _queue = [];
  List<OfflineSyncAction> get queue => List.unmodifiable(_queue);

  bool _isDraining = false;
  bool get isDraining => _isDraining;

  int get pendingCount =>
      _queue.where((a) => SyncActionState.fromRaw(a.status) == SyncActionState.pending).length;
  int get syncingCount =>
      _queue.where((a) => SyncActionState.fromRaw(a.status) == SyncActionState.syncing).length;
  int get syncedCount =>
      _queue.where((a) => SyncActionState.fromRaw(a.status) == SyncActionState.synced).length;
  int get failedCount =>
      _queue.where((a) => SyncActionState.fromRaw(a.status) == SyncActionState.failed).length;
  int get retryableCount => pendingCount + failedCount;
  int get totalCount => _queue.length;
  bool get hasPending => pendingCount > 0;
  bool get hasRetryable => retryableCount > 0;

  void setOfflineSimulation(bool enabled) {
    if (_isOfflineSimulationEnabled != enabled) {
      _isOfflineSimulationEnabled = enabled;
      notifyListeners();
    }
  }

  OfflineSyncAction enqueueAction({
    required String actionType,
    required String endpoint,
    String method = 'POST',
    required Map<String, dynamic> payload,
    String? customIdempotencyKey,
  }) {
    final now = DateTime.now();
    final randomSuffix = Random().nextInt(999999).toString().padLeft(6, '0');
    final actionId = 'act_${now.millisecondsSinceEpoch}_$randomSuffix';
    final idempotencyKey = customIdempotencyKey ?? 'idem_off_${now.millisecondsSinceEpoch}_$randomSuffix';

    final action = OfflineSyncAction(
      actionId: actionId,
      idempotencyKey: idempotencyKey,
      actionType: actionType,
      endpoint: endpoint,
      method: method,
      payload: payload,
      createdAt: now.toIso8601String(),
      status: 'PENDING',
    );

    _queue.insert(0, action); // newest first
    notifyListeners();
    return action;
  }

  Future<Map<String, dynamic>> drainQueue(ApiService api) async {
    final pending = _queue.where((a) => a.status == 'PENDING' || a.status == 'FAILED').toList();
    if (pending.isEmpty) {
      return {'processed': 0, 'synced': 0, 'failed': 0, 'results': []};
    }

    _isDraining = true;
    for (final action in pending) {
      action.status = 'SYNCING';
      action.retryCount++;
    }
    notifyListeners();

    try {
      final response = await api.syncBatch(pending);
      final results = (response['results'] as List?) ?? [];

      for (final res in results) {
        final actId = res['action_id'];
        final idemKey = res['idempotency_key'];
        OfflineSyncAction? match;
        for (final candidate in pending) {
          if (candidate.actionId == actId || candidate.idempotencyKey == idemKey) {
            match = candidate;
            break;
          }
        }
        if (match == null) continue;

        final resolvedState = SyncActionState.fromRaw(res['status']?.toString() ?? 'SYNCED');
        match.status = resolvedState.wireValue;
        match.isReplay = res['is_replay'] == true;
        if (res['data'] != null && res['data'] is Map) {
          match.serverResponse = Map<String, dynamic>.from(res['data']);
        }
        if (res['error'] != null) {
          match.error = res['error'] is Map
              ? res['error']['message']?.toString() ?? res['error'].toString()
              : res['error'].toString();
        } else {
          match.error = null;
        }
      }

      // Any action left in SYNCING without an explicit acknowledgement must be marked FAILED so it stays retryable.
      for (final action in pending) {
        if (SyncActionState.fromRaw(action.status) == SyncActionState.syncing) {
          action.status = SyncActionState.failed.wireValue;
          action.error ??= 'Server did not acknowledge queued action.';
        }
      }

      _isDraining = false;
      notifyListeners();
      return response;
    } catch (e) {
      final errMsg = e.toString();
      for (final action in pending) {
        action.status = SyncActionState.failed.wireValue;
        action.error = errMsg;
      }
      _isDraining = false;
      notifyListeners();
      return {
        'processed': pending.length,
        'synced': 0,
        'failed': pending.length,
        'error': errMsg,
      };
    }
  }

  void clearSynced() {
    _queue.removeWhere((a) => a.status == 'SYNCED');
    notifyListeners();
  }

  void clearAll() {
    _queue.clear();
    notifyListeners();
  }

  void removeAction(String actionId) {
    _queue.removeWhere((a) => a.actionId == actionId);
    notifyListeners();
  }
}

