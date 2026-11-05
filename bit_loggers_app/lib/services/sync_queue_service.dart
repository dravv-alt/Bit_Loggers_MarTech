import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'api_service.dart';

/// SyncQueueService manages the client-side offline action queue (FR-13, ADR-005).
/// When offline simulation is active (or connection fails), write operations
/// are persisted with unique client-supplied idempotency keys.
/// When connectivity is restored, the queue is drained via batch dispatch to `/api/sync/queue`.
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

  int get pendingCount => _queue.where((a) => a.status == 'PENDING').length;
  int get syncingCount => _queue.where((a) => a.status == 'SYNCING').length;
  int get syncedCount => _queue.where((a) => a.status == 'SYNCED').length;
  int get failedCount => _queue.where((a) => a.status == 'FAILED').length;
  int get totalCount => _queue.length;
  bool get hasPending => pendingCount > 0;

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
        final match = pending.firstWhere(
          (a) => a.actionId == actId || a.idempotencyKey == idemKey,
          orElse: () => pending.first,
        );

        match.status = res['status'] ?? 'SYNCED';
        match.isReplay = res['is_replay'] == true;
        if (res['data'] != null && res['data'] is Map) {
          match.serverResponse = Map<String, dynamic>.from(res['data']);
        }
        if (res['error'] != null) {
          match.error = res['error'] is Map
              ? res['error']['message'] ?? res['error'].toString()
              : res['error'].toString();
        } else {
          match.error = null;
        }
      }

      for (final action in pending) {
        if (action.status == 'SYNCING') {
          action.status = 'SYNCED';
        }
      }

      _isDraining = false;
      notifyListeners();
      return response;
    } catch (e) {
      for (final action in pending) {
        action.status = 'FAILED';
        action.error = e.toString();
      }
      _isDraining = false;
      notifyListeners();
      return {
        'processed': pending.length,
        'synced': 0,
        'failed': pending.length,
        'error': e.toString(),
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

