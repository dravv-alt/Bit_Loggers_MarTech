import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/sync_queue_service.dart';
import '../theme/app_theme.dart';

/// FR-13: Mobile Offline Sync Queue (ADR-005 Client-Supplied Idempotency)
/// FR-14: Transactional Outbox Background Worker (ADR-004 SKIP LOCKED)
class SyncHubScreen extends StatefulWidget {
  final ApiService api;
  final int initialTabIndex;

  const SyncHubScreen({
    super.key,
    required this.api,
    this.initialTabIndex = 0,
  });

  @override
  State<SyncHubScreen> createState() => _SyncHubScreenState();
}

class _SyncHubScreenState extends State<SyncHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late SyncQueueService _syncQueue;

  // Outbox state
  List<OutboxEventItem> _outboxEvents = [];
  OutboxStats _outboxStats = OutboxStats(
    pending: 0,
    processed: 0,
    failed: 0,
    total: 0,
    isEmailServiceFailing: false,
  );
  bool _isEmailFailing = false;
  bool _loadingOutbox = false;
  bool _processingWorker = false;

  // Filters
  String _queueFilter = 'ALL'; // 'ALL', 'PENDING', 'SYNCED', 'FAILED'
  String _outboxFilter = 'ALL'; // 'ALL', 'PENDING', 'PROCESSED', 'FAILED'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _syncQueue = widget.api.syncQueue;
    _syncQueue.addListener(_onQueueChanged);
    _fetchOutbox();
  }

  @override
  void dispose() {
    _syncQueue.removeListener(_onQueueChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onQueueChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _fetchOutbox() async {
    setState(() => _loadingOutbox = true);
    try {
      final res = await widget.api.getOutbox();
      if (mounted) {
        setState(() {
          _outboxEvents = (res['events'] as List<OutboxEventItem>?) ?? [];
          _outboxStats = res['stats'] as OutboxStats;
          _isEmailFailing = res['isEmailServiceFailing'] == true;
          _loadingOutbox = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOutbox = false);
    }
  }

  Future<void> _drainSyncQueue() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final summary = await _syncQueue.drainQueue(widget.api);
    if (!mounted) return;

    final processed = summary['processed'] ?? 0;
    final synced = summary['synced'] ?? 0;
    final failed = summary['failed'] ?? 0;

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          'Sync finished: $synced synced, $failed failed ($processed total).',
          style: const TextStyle(color: AppTheme.textInverse),
        ),
        backgroundColor: failed > 0 ? AppTheme.statusRejected : AppTheme.forge,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Refresh outbox to catch newly created events from synced campaigns
    _fetchOutbox();
  }

  Future<void> _triggerOutboxWorker() async {
    setState(() => _processingWorker = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final processed = await widget.api.processOutbox();
      if (mounted) {
        await _fetchOutbox();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              _isEmailFailing
                  ? 'Worker ran with outage injected: ${_outboxStats.failed} event(s) recorded as FAILED (EmailProviderGatewayTimeout).'
                  : 'Worker ran: ${processed.length} event(s) dispatched successfully to recipients.',
              style: const TextStyle(color: AppTheme.textInverse),
            ),
            backgroundColor: _isEmailFailing ? AppTheme.statusRejected : AppTheme.forge,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Outbox worker run failed: $e'),
            backgroundColor: AppTheme.statusRejected,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingWorker = false);
    }
  }

  Future<void> _toggleEmailFailure(bool value) async {
    final updated = await widget.api.toggleEmailFailure(failing: value);
    if (mounted) {
      setState(() => _isEmailFailing = updated);
      await _fetchOutbox();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated
                ? 'Email Provider Outage injected (worker will encounter retry backoff)'
                : 'Email Provider restored to healthy state (worker ready to dispatch)',
            style: const TextStyle(color: AppTheme.textInverse),
          ),
          backgroundColor: updated ? AppTheme.statusRejected : AppTheme.forge,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _queueTestOutboxEvent() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final ok = await widget.api.createTestOutboxEvent();
    if (!mounted) return;
    if (ok) {
      await _fetchOutbox();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEmailFailing
                ? 'Queued test notification (Pending: ${_outboxStats.pending}). With outage injected, worker will record failure.'
                : 'Queued test notification (Pending: ${_outboxStats.pending}). Outbox worker will dispatch successfully.',
            style: const TextStyle(color: AppTheme.textInverse),
          ),
          backgroundColor: _isEmailFailing ? AppTheme.statusChanges : AppTheme.forge,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to queue test notification.'),
          backgroundColor: AppTheme.statusRejected,
        ),
      );
    }
  }

  Future<void> _resetOutboxToCleanSlate() async {
    setState(() => _loadingOutbox = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await widget.api.resetOutbox();
      await _fetchOutbox();
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Outbox ledger reset to clean slate (3 curated enterprise events).'),
          backgroundColor: AppTheme.forge,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to reset outbox: $e'),
            backgroundColor: AppTheme.statusRejected,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingOutbox = false);
    }
  }

  void _simulateOfflineWrite() {
    final now = DateTime.now();
    final sampleTitle = 'Festive Flash Deal #${now.second}';
    final action = _syncQueue.enqueueAction(
      actionType: 'CREATE_CAMPAIGN',
      endpoint: '/api/campaigns',
      method: 'POST',
      payload: {
        'title': sampleTitle,
        'objective': 'Offline drafted promotion for mobile seasonal sale.',
        'target_audience': 'Mobile VIP customers',
        'channel': 'Social',
        'budget': 14500,
        'kpi_projected': {
          'conversionRate': 4.5,
          'ctr': 5.2,
          'roi': 4.8,
          'cpa': 18.00,
          'aov': 120.00,
        },
      },
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Enqueued offline action "${action.actionType}" with Idempotency Key: ${action.idempotencyKey.substring(0, 16)}...',
          style: const TextStyle(color: AppTheme.textInverse),
        ),
        backgroundColor: AppTheme.forge,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showPayloadModal(OfflineSyncAction action) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ActionDetailModal(action: action),
    );
  }

  void _showOutboxEventModal(OutboxEventItem evt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OutboxDetailModal(event: evt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _syncQueue.pendingCount;

    return Scaffold(
      backgroundColor: AppTheme.paper,
      appBar: AppBar(
        backgroundColor: AppTheme.paper,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sync & Outbox Hub',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              'FR-13 Mobile Queue · FR-14 Transactional Outbox',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary.withOpacity(0.9),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20, color: AppTheme.textPrimary),
            tooltip: 'Refresh Hub',
            onPressed: () {
              _fetchOutbox();
              setState(() {});
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.forge,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.forge,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_sync_outlined, size: 15),
                  const SizedBox(width: 4),
                  const Text('Queue'),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.statusChanges,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.leaf,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.outbox_outlined, size: 15),
                  const SizedBox(width: 4),
                  const Text('Outbox'),
                  if (_outboxStats.pending > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.forge,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_outboxStats.pending}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.leaf,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMobileQueueTab(),
          _buildTransactionalOutboxTab(),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: MOBILE OFFLINE SYNC QUEUE (FR-13, ADR-005)
  // =========================================================================
  Widget _buildMobileQueueTab() {
    final queue = _syncQueue.queue;
    final filtered = queue.where((a) {
      if (_queueFilter == 'ALL') return true;
      return a.status.toUpperCase() == _queueFilter;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      color: AppTheme.forge,
      backgroundColor: AppTheme.leaf,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Offline Simulation Switch Card
          _buildOfflineToggleBanner(),
          const SizedBox(height: 14),

          // Queue Metrics Strip
          _buildQueueMetricsStrip(),
          const SizedBox(height: 14),

          // Action Buttons: Drain & Sync, Add Sample Offline Write
          _buildQueueActionButtons(),
          const SizedBox(height: 16),

          // Filter Row
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Queued Actions (${filtered.length})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildQueueFilterPills(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action List
          if (filtered.isEmpty)
            _buildEmptyQueueState()
          else
            ...filtered.map((action) => _buildActionCard(action)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOfflineToggleBanner() {
    final isSimulating = _syncQueue.isOfflineSimulationEnabled;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSimulating ? const Color(0xFFFFF7ED) : AppTheme.leaf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSimulating ? const Color(0xFFF97316) : AppTheme.borderSage,
          width: isSimulating ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSimulating ? const Color(0xFFFFEDD5) : AppTheme.paper,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSimulating ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                  size: 20,
                  color: isSimulating ? const Color(0xFFC2410C) : AppTheme.forge,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSimulating ? 'Offline Simulation Active' : 'Network Connectivity Online',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSimulating ? const Color(0xFF9A3412) : AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      isSimulating
                          ? 'Campaign writes are queued locally with idempotency keys'
                          : 'Mutations post directly to server API',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isSimulating,
                activeColor: const Color(0xFFC2410C),
                onChanged: (val) {
                  _syncQueue.setOfflineSimulation(val);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.paper.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.fingerprint, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'ADR-005: Every offline action generates a client UUID idempotency key to prevent replay duplication upon network restoration.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary.withOpacity(0.95),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueMetricsStrip() {
    return Row(
      children: [
        _buildMetricMiniCard('Pending', '${_syncQueue.pendingCount}', AppTheme.statusChanges),
        const SizedBox(width: 8),
        _buildMetricMiniCard('Syncing', '${_syncQueue.syncingCount}', const Color(0xFF2563EB)),
        const SizedBox(width: 8),
        _buildMetricMiniCard('Synced', '${_syncQueue.syncedCount}', AppTheme.verdictLimeDark),
        const SizedBox(width: 8),
        _buildMetricMiniCard('Failed', '${_syncQueue.failedCount}', AppTheme.statusRejected),
      ],
    );
  }

  Widget _buildMetricMiniCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.leaf,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderSage, width: 1),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueActionButtons() {
    final isDraining = _syncQueue.isDraining;
    final hasPending = _syncQueue.hasPending;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: ElevatedButton.icon(
            onPressed: isDraining || !hasPending ? null : _drainSyncQueue,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.forge,
              foregroundColor: AppTheme.leaf,
              disabledBackgroundColor: AppTheme.forge.withOpacity(0.4),
              disabledForegroundColor: AppTheme.leaf.withOpacity(0.6),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon: isDraining
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.leaf),
                  )
                : const Icon(Icons.sync, size: 18),
            label: Text(
              isDraining ? 'Syncing Queue...' : 'Drain & Sync Now',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: OutlinedButton.icon(
            onPressed: _simulateOfflineWrite,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimary,
              backgroundColor: AppTheme.leaf,
              side: const BorderSide(color: AppTheme.borderSage, width: 1),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add_circle_outline, size: 16),
            label: const Text(
              'Add Mock',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (_syncQueue.syncedCount > 0) ...[
          const SizedBox(width: 6),
          IconButton(
            onPressed: _syncQueue.clearSynced,
            tooltip: 'Clear Synced Items',
            icon: const Icon(Icons.cleaning_services_outlined, size: 18, color: AppTheme.textSecondary),
          ),
        ],
      ],
    );
  }

  Widget _buildQueueFilterPills() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSage, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['ALL', 'PENDING', 'SYNCED', 'FAILED'].map((f) {
          final active = _queueFilter == f;
          return InkWell(
            onTap: () => setState(() => _queueFilter = f),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: active ? AppTheme.forge : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                f,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: active ? AppTheme.leaf : AppTheme.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyQueueState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSage, width: 1),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 40, color: AppTheme.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 12),
          const Text(
            'Offline Sync Queue is Empty',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'When offline mode is active, any campaign edits, creations, or submissions are safely held in local storage and replayed here with client idempotency UUIDs.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withOpacity(0.85), height: 1.4),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _simulateOfflineWrite,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.forge,
              foregroundColor: AppTheme.leaf,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Simulate Offline Campaign Write', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(OfflineSyncAction action) {
    Color statusColor;
    IconData statusIcon;
    switch (action.status.toUpperCase()) {
      case 'SYNCED':
        statusColor = AppTheme.verdictLimeDark;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'SYNCING':
        statusColor = const Color(0xFF2563EB);
        statusIcon = Icons.sync;
        break;
      case 'FAILED':
        statusColor = AppTheme.statusRejected;
        statusIcon = Icons.error_outline;
        break;
      default:
        statusColor = AppTheme.statusChanges;
        statusIcon = Icons.hourglass_top;
    }

    final createdAtFormatted = DateFormat('HH:mm:ss · dd MMM').format(
      DateTime.tryParse(action.createdAt) ?? DateTime.now(),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSage, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showPayloadModal(action),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Method & Action Type + Status Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.forge,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        action.method,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.leaf,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        action.actionType,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            action.status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Endpoint row
                Text(
                  action.endpoint,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: AppTheme.textSecondary.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 8),

                // Idempotency Key Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.paper.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.borderSage, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.vpn_key_outlined, size: 11, color: AppTheme.textSecondary),
                      const SizedBox(width: 5),
                      Text(
                        'Idempotency Key: ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary.withOpacity(0.9),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          action.idempotencyKey,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: AppTheme.forge,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (action.isReplay) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'REPLAY',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6D28D9),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Payload snippet
                if (action.payload.isNotEmpty)
                  Text(
                    'Payload: ${jsonEncode(action.payload)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary.withOpacity(0.8),
                    ),
                  ),

                // Error Box if failed
                if (action.error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.statusRejected.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.statusRejected.withOpacity(0.3), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.statusRejected),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            action.error!,
                            style: const TextStyle(fontSize: 11, color: AppTheme.statusRejected),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 8),
                // Footer: Timestamp and inspection trigger
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        action.retryCount > 0
                            ? '$createdAtFormatted · Retried: ${action.retryCount}x'
                            : createdAtFormatted,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary.withOpacity(0.7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Inspect Payload →',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.forge.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 2: TRANSACTIONAL OUTBOX (FR-14, ADR-004)
  // =========================================================================
  Widget _buildTransactionalOutboxTab() {
    final filtered = _outboxEvents.where((e) {
      if (_outboxFilter == 'ALL') return true;
      return e.status.toUpperCase() == _outboxFilter;
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchOutbox,
      color: AppTheme.forge,
      backgroundColor: AppTheme.leaf,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Outbox Worker Heartbeat & Control Banner
          _buildOutboxControlBanner(),
          const SizedBox(height: 14),

          // Outbox Metrics Strip
          _buildOutboxMetricsStrip(),
          const SizedBox(height: 14),

          // Worker Trigger Button
          _buildOutboxActionButtons(),
          const SizedBox(height: 16),

          // Filter Row
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Outbox Ledger (${filtered.length})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildOutboxFilterPills(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Events Feed
          if (_loadingOutbox)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppTheme.forge),
              ),
            )
          else if (filtered.isEmpty)
            _buildEmptyOutboxState()
          else
            ...filtered.map((evt) => _buildOutboxEventCard(evt)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOutboxControlBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSage, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppTheme.verdictLimeDark,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Transactional Outbox Worker (4s Poll Loop)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.forge.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'SKIP LOCKED',
                  style: TextStyle(
                    fontSize: 9,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: AppTheme.forge,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Email Service Failure Injection Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _isEmailFailing ? const Color(0xFFFEF2F2) : AppTheme.paper.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isEmailFailing ? const Color(0xFFF87171) : AppTheme.borderSage,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isEmailFailing ? Icons.warning_rounded : Icons.mark_email_read_outlined,
                  size: 18,
                  color: _isEmailFailing ? AppTheme.statusRejected : AppTheme.forge,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inject Email Service Outage',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _isEmailFailing ? AppTheme.statusRejected : AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        _isEmailFailing
                            ? 'Simulating SMTP timeout (retries with exp backoff up to 5 attempts)'
                            : 'All outbox events dispatch successfully to mock SMTP',
                        style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _isEmailFailing,
                  activeColor: AppTheme.statusRejected,
                  onChanged: _toggleEmailFailure,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutboxMetricsStrip() {
    return Row(
      children: [
        _buildMetricMiniCard('Pending', '${_outboxStats.pending}', AppTheme.statusChanges),
        const SizedBox(width: 8),
        _buildMetricMiniCard('Processed', '${_outboxStats.processed}', AppTheme.verdictLimeDark),
        const SizedBox(width: 8),
        _buildMetricMiniCard('Failed', '${_outboxStats.failed}', AppTheme.statusRejected),
        const SizedBox(width: 8),
        _buildMetricMiniCard('Total Events', '${_outboxStats.total}', AppTheme.forge),
      ],
    );
  }

  Widget _buildOutboxActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _processingWorker ? null : _triggerOutboxWorker,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.forge,
              foregroundColor: AppTheme.leaf,
              disabledBackgroundColor: AppTheme.forge.withOpacity(0.4),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon: _processingWorker
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.leaf),
                  )
                : const Icon(Icons.bolt, size: 18),
            label: Text(
              _processingWorker ? 'Worker Running...' : 'Force Run Outbox Worker Now',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: OutlinedButton.icon(
                onPressed: _queueTestOutboxEvent,
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppTheme.leaf,
                  foregroundColor: AppTheme.forge,
                  side: const BorderSide(color: AppTheme.borderSage),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.mark_email_unread_outlined, size: 16, color: AppTheme.forge),
                label: const Text(
                  'Queue Test Notification Event',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.forge),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: _resetOutboxToCleanSlate,
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppTheme.leaf,
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.borderSage),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.restart_alt, size: 15, color: AppTheme.textSecondary),
                label: const Text(
                  'Clean Slate',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOutboxFilterPills() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSage, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['ALL', 'PENDING', 'PROCESSED', 'FAILED'].map((f) {
          final active = _outboxFilter == f;
          return InkWell(
            onTap: () => setState(() => _outboxFilter = f),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: active ? AppTheme.forge : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                f,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: active ? AppTheme.leaf : AppTheme.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyOutboxState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSage, width: 1),
      ),
      child: Column(
        children: [
          Icon(Icons.outbox, size: 40, color: AppTheme.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 12),
          const Text(
            'No Outbox Events Recorded',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Campaign decisions, submissions, and status changes write events inside the same atomic ACID transaction to guarantee zero duplicate emails or notifications.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withOpacity(0.85), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildOutboxEventCard(OutboxEventItem evt) {
    Color statusColor;
    IconData statusIcon;
    switch (evt.status.toUpperCase()) {
      case 'PROCESSED':
        statusColor = AppTheme.verdictLimeDark;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'PROCESSING':
        statusColor = const Color(0xFF2563EB);
        statusIcon = Icons.sync;
        break;
      case 'FAILED':
        statusColor = AppTheme.statusRejected;
        statusIcon = Icons.error_outline;
        break;
      default:
        statusColor = AppTheme.statusChanges;
        statusIcon = Icons.schedule;
    }

    final createdAtFormatted = DateFormat('HH:mm:ss · dd MMM').format(
      DateTime.tryParse(evt.createdAt) ?? DateTime.now(),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSage, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showOutboxEventModal(evt),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        evt.eventType,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            evt.status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Event ID: ${evt.eventId}',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: AppTheme.textSecondary.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 6),

                // Humanized Outbox Email Preview
                if (evt.payload.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.paper,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderSage),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.mail_outline, size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            evt.payload['subject'] as String? ??
                                (evt.payload['campaign_title'] != null
                                    ? 'Flight Notification · ${evt.payload['campaign_title']}'
                                    : 'Enterprise Dispatch · ${evt.eventType.replaceAll('_', ' ')}'),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (evt.payload['recipient'] != null) ...[
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 80),
                            child: Text(
                              evt.payload['recipient'] as String,
                              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                if (evt.errorLog != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.statusRejected.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.statusRejected.withOpacity(0.3), width: 1),
                    ),
                    child: Text(
                      'Error: ${evt.errorLog}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppTheme.statusRejected),
                    ),
                  ),
                ],

                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$createdAtFormatted · Attempts: ${evt.attempts}/${evt.maxAttempts}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: evt.attempts > 1 ? FontWeight.w600 : FontWeight.normal,
                          color: evt.attempts > 1 ? AppTheme.statusRejected : AppTheme.textSecondary.withOpacity(0.7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Details →',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.forge.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DETAIL MODAL: ACTION INSPECTION (FR-13)
// ---------------------------------------------------------------------------
class _ActionDetailModal extends StatelessWidget {
  final OfflineSyncAction action;

  const _ActionDetailModal({required this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderSage,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.actionType,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Offline Client Action Inspection',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withOpacity(0.8)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderSage),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildInfoRow('Action ID', action.actionId, monospace: true),
                _buildInfoRow('Idempotency Key', action.idempotencyKey, monospace: true),
                _buildInfoRow('Endpoint', '${action.method} ${action.endpoint}', monospace: true),
                _buildInfoRow('Status', action.status),
                _buildInfoRow('Replay Cached?', action.isReplay ? 'YES (Cache Hit)' : 'NO'),
                _buildInfoRow('Retry Attempts', '${action.retryCount}'),
                _buildInfoRow('Created At', action.createdAt),
                const SizedBox(height: 14),

                const Text(
                  'Payload (JSON)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.paper,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderSage, width: 1),
                  ),
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(action.payload),
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textPrimary),
                  ),
                ),

                if (action.serverResponse != null) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Server Response',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.verdictLimeDark),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.paper,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderSage, width: 1),
                    ),
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ').convert(action.serverResponse),
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textPrimary),
                    ),
                  ),
                ],

                if (action.error != null) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Error Message',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.statusRejected),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.statusRejected.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.statusRejected.withOpacity(0.3), width: 1),
                    ),
                    child: SelectableText(
                      action.error!,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.statusRejected),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool monospace = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: monospace ? 'monospace' : null,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DETAIL MODAL: OUTBOX EVENT INSPECTION (FR-14)
// ---------------------------------------------------------------------------
class _OutboxDetailModal extends StatelessWidget {
  final OutboxEventItem event;

  const _OutboxDetailModal({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderSage,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.eventType,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'PostgreSQL Transactional Outbox Event',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withOpacity(0.8)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderSage),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildInfoRow('Event ID', event.eventId, monospace: true),
                _buildInfoRow('Status', event.status),
                _buildInfoRow('Attempts', '${event.attempts} / ${event.maxAttempts}'),
                _buildInfoRow('Created At', event.createdAt),
                if (event.processedAt != null)
                  _buildInfoRow('Processed At', event.processedAt!),
                if (event.nextRetryAt != null)
                  _buildInfoRow('Next Retry At', event.nextRetryAt!),
                const SizedBox(height: 14),

                const Text(
                  'Dispatched Message Preview',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.leaf,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderSage),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.mark_email_read_outlined, size: 16, color: AppTheme.brandAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              event.payload['subject'] as String? ?? 'Enterprise Notification: ${event.eventType}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'To: ${event.payload['recipient'] ?? 'marketer@bitloggers.internal'} · From: dispatch@bitloggers.internal',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Security: TLS 1.3 · HMAC-SHA256 Signed Outbox Payload',
                        style: TextStyle(fontSize: 10, color: AppTheme.moss, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                const Text(
                  'Payload (JSON)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.paper,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderSage, width: 1),
                  ),
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(event.payload),
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textPrimary),
                  ),
                ),

                if (event.errorLog != null) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Error Log',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.statusRejected),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.statusRejected.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.statusRejected.withOpacity(0.3), width: 1),
                    ),
                    child: SelectableText(
                      event.errorLog!,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.statusRejected),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool monospace = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: monospace ? 'monospace' : null,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
