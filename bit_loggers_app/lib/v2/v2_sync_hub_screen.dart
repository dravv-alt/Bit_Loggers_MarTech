import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/sync_queue_service.dart';
import '../state/campaign_state_machine.dart';
import 'v2_components.dart';
import 'v2_mappers.dart';
import 'v2_tokens.dart';
import 'v2_utility_chrome.dart';

/// V2 Sync Hub & Delivery Outbox in Perforated Ledger & Facet Instrument style.
class V2SyncHubScreen extends StatefulWidget {
  final ApiService api;
  final int initialSectionIndex;

  const V2SyncHubScreen({
    super.key,
    required this.api,
    this.initialSectionIndex = 0,
  });

  @override
  State<V2SyncHubScreen> createState() => _V2SyncHubScreenState();
}

class _V2SyncHubScreenState extends State<V2SyncHubScreen> {
  late int _activeSection; // 0 = Offline Queue, 1 = Delivery Outbox
  late final SyncQueueService _syncQueue;

  List<OutboxEventItem> _outboxEvents = [];
  OutboxStats _stats = OutboxStats(
    pending: 0,
    processed: 0,
    failed: 0,
    total: 0,
    isEmailServiceFailing: false,
  );
  bool _isEmailFailing = false;
  bool _loadingOutbox = true;
  bool _working = false;

  String _queueFilter = 'all';
  String _outboxFilter = 'all';

  @override
  void initState() {
    super.initState();
    _activeSection = widget.initialSectionIndex.clamp(0, 1);
    _syncQueue = widget.api.syncQueue;
    _syncQueue.addListener(_onQueueChanged);
    _fetchOutbox();
  }

  @override
  void dispose() {
    _syncQueue.removeListener(_onQueueChanged);
    super.dispose();
  }

  void _onQueueChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _fetchOutbox() async {
    setState(() => _loadingOutbox = true);
    try {
      final res = await widget.api.getOutbox();
      if (!mounted) return;
      setState(() {
        _outboxEvents = (res['events'] as List<OutboxEventItem>?) ?? [];
        _stats = res['stats'] as OutboxStats;
        _isEmailFailing = res['isEmailServiceFailing'] == true;
        _loadingOutbox = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingOutbox = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: V2Tokens.t3(color: V2Tokens.labelOnInk)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: V2Tokens.inkPrussian,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _drainQueue() async {
    setState(() => _working = true);
    try {
      final summary = await _syncQueue.drainQueue(widget.api);
      final synced = summary['synced'] ?? 0;
      final failed = summary['failed'] ?? 0;
      await _fetchOutbox();
      _showSnack('Sync finished: $synced synced, $failed failed.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _dispatchOutbox() async {
    setState(() => _working = true);
    try {
      final processed = await widget.api.processOutbox();
      await _fetchOutbox();
      _showSnack(
        _isEmailFailing
            ? 'Email outage active: ${_stats.failed} delivery attempt(s) queued for backoff retry.'
            : 'Worker ran cleanly: ${processed.length} delivery event(s) dispatched.',
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _toggleEmailOutage() async {
    final updated = await widget.api.toggleEmailFailure(failing: !_isEmailFailing);
    if (!mounted) return;
    setState(() => _isEmailFailing = updated);
    await _fetchOutbox();
    _showSnack(
      updated
          ? 'Email delivery failure simulation turned on.'
          : 'Email delivery restored to healthy state.',
    );
  }

  Future<void> _queueTestNotice() async {
    final ok = await widget.api.createTestOutboxEvent();
    if (!mounted) return;
    if (ok) {
      await _fetchOutbox();
      _showSnack('Test delivery notice added to pending queue.');
    } else {
      _showSnack('Could not queue test delivery notice.');
    }
  }

  Future<void> _resetOutbox() async {
    setState(() => _loadingOutbox = true);
    await widget.api.resetOutbox();
    await _fetchOutbox();
    _showSnack('Outbox ledger restored to baseline.');
  }

  String _friendlyActionLabel(String raw) {
    switch (raw.toUpperCase()) {
      case 'CREATE_CAMPAIGN':
        return 'Create campaign proposal';
      case 'UPDATE_CAMPAIGN':
      case 'SAVE_DRAFT':
        return 'Save new version draft';
      case 'SUBMIT_CAMPAIGN':
        return 'Submit proposal for review';
      case 'MAKE_DECISION':
        return 'Record review decision';
      case 'SCHEDULE_CAMPAIGN':
        return 'Lock flight window';
      case 'POST_DISCUSSION':
        return 'Post discussion note';
      default:
        final words = raw.toLowerCase().replaceAll('_', ' ').trim();
        return words.isEmpty ? 'Queued mutation' : '${words[0].toUpperCase()}${words.substring(1)}';
    }
  }

  String _friendlyOutboxLabel(OutboxEventItem item) {
    final pTitle = item.payload['title']?.toString().trim();
    if (pTitle != null && pTitle.isNotEmpty) return pTitle;
    switch (item.eventType.toUpperCase()) {
      case 'CAMPAIGN_SUBMITTED_EMAIL':
        return 'Review request email';
      case 'CAMPAIGN_DECISION_EMAIL':
        return 'Decision dispatch notice';
      case 'CAMPAIGN_APPROVED':
        return 'Approval signoff confirmation';
      case 'FLIGHT_SCHEDULED':
        return 'Channel flight confirmation';
      default:
        final words = item.eventType.toLowerCase().replaceAll('_', ' ').trim();
        return words.isEmpty ? 'Outbox notice' : '${words[0].toUpperCase()}${words.substring(1)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final allQueue = _syncQueue.queue;
    final pendingAttention = _syncQueue.retryableCount + _stats.pending + _stats.failed;

    return Scaffold(
      backgroundColor: V2Tokens.bgPlaster,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(
              children: [
                V2SubScreenAppBar(
                  backLabel: 'Back',
                  trailing: V2ActionPill(
                    icon: Icons.add_alert_outlined,
                    label: 'Test notice',
                    onTap: _queueTestNotice,
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: V2Tokens.inkPrussian,
                    backgroundColor: V2Tokens.surfaceCard,
                    onRefresh: _fetchOutbox,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      children: [
                        // Context Eyebrow + Title
                        Row(
                          children: [
                            V2FacetCell(
                              status: pendingAttention > 0 ? 'changes' : 'approved',
                              size: 12,
                              selected: pendingAttention > 0,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _syncQueue.isOfflineSimulationEnabled
                                  ? 'Offline simulation active · $_statsPendingText()'
                                  : _isEmailFailing
                                      ? 'SMTP failure simulation active'
                                      : 'Idempotent sync & reliable dispatch',
                              style: V2Tokens.t3(color: V2Tokens.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Sync Hub & Outbox', style: V2Tokens.t1()),
                        const SizedBox(height: 12),

                        // Section Switcher Pills
                        V2FilterChipStrip(
                          chips: [
                            (id: 'queue', label: 'Offline queue (${allQueue.length})'),
                            (id: 'outbox', label: 'Delivery outbox (${_outboxEvents.length})'),
                          ],
                          selectedId: _activeSection == 0 ? 'queue' : 'outbox',
                          onSelect: (id) =>
                              setState(() => _activeSection = id == 'queue' ? 0 : 1),
                        ),
                        const SizedBox(height: 12),

                        // Perforated Summary Card
                        _activeSection == 0
                            ? _buildQueueSummaryCard(allQueue)
                            : _buildOutboxSummaryCard(),
                        const SizedBox(height: 12),

                        // Ledger Filter Strip + Grouped Table
                        if (_activeSection == 0)
                          ..._buildQueueLedger(allQueue)
                        else
                          ..._buildOutboxLedger(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statsPendingText() => '${_syncQueue.retryableCount} awaiting sync';

  Widget _buildQueueSummaryCard(List<OfflineSyncAction> allQueue) {
    final pending = _syncQueue.retryableCount;
    final synced = _syncQueue.syncedCount;
    final failed = _syncQueue.failedCount;
    final offline = _syncQueue.isOfflineSimulationEnabled;

    return Container(
      decoration: BoxDecoration(
        color: V2Tokens.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: V2Tokens.hairline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$pending', style: V2Tokens.t1(mono: true)),
                      const SizedBox(height: 2),
                      Text(
                        pending == 1
                            ? 'offline action waiting to sync'
                            : 'offline actions waiting to sync',
                        style: V2Tokens.t3(color: V2Tokens.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _working || pending == 0 ? null : _drainQueue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: V2Tokens.inkPrussian,
                    disabledBackgroundColor: V2Tokens.surfaceRecessed,
                    foregroundColor: V2Tokens.labelOnInk,
                    disabledForegroundColor: V2Tokens.textSecondary,
                    elevation: 0,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  child: Text(
                    _working ? 'Syncing…' : 'Sync now',
                    style: V2Tokens.t3(
                      color: pending == 0 ? V2Tokens.textSecondary : V2Tokens.labelOnInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const V2TicketPerforation(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                V2SegmentMeter(
                  okCount: synced,
                  warnCount: pending,
                  errorCount: failed,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$synced synced · $pending pending · $failed failed',
                          style: V2Tokens.t4(color: V2Tokens.textSecondary),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        V2ActionPill(
                          icon: offline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                          label: offline ? 'Offline mode on' : 'Simulate offline',
                          active: offline,
                          onTap: () => _syncQueue.setOfflineSimulation(!offline),
                        ),
                        if (synced > 0) ...[
                          const SizedBox(width: 6),
                          V2ActionPill(
                            icon: Icons.cleaning_services_outlined,
                            label: 'Clear synced',
                            onTap: _syncQueue.clearSynced,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutboxSummaryCard() {
    final attention = _stats.pending + _stats.failed;
    return Container(
      decoration: BoxDecoration(
        color: V2Tokens.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: V2Tokens.hairline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$attention', style: V2Tokens.t1(mono: true)),
                      const SizedBox(height: 2),
                      Text(
                        _stats.failed > 0
                            ? '${_stats.failed} retrying · ${_stats.pending} pending'
                            : 'queued delivery dispatches',
                        style: V2Tokens.t3(color: V2Tokens.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _working ? null : _dispatchOutbox,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: V2Tokens.inkPrussian,
                    foregroundColor: V2Tokens.labelOnInk,
                    elevation: 0,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  child: Text(
                    _working ? 'Running…' : 'Run worker',
                    style: V2Tokens.t3(
                      color: V2Tokens.labelOnInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const V2TicketPerforation(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                V2SegmentMeter(
                  okCount: _stats.processed,
                  warnCount: _stats.pending,
                  errorCount: _stats.failed,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${_stats.processed} processed · ${_stats.pending} pending · ${_stats.failed} failed',
                      style: V2Tokens.t4(color: V2Tokens.textSecondary),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        V2ActionPill(
                          icon: _isEmailFailing
                              ? Icons.mail_lock_outlined
                              : Icons.mark_email_read_outlined,
                          label: _isEmailFailing ? 'Email outage on' : 'Simulate outage',
                          active: _isEmailFailing,
                          onTap: _toggleEmailOutage,
                        ),
                        const SizedBox(width: 6),
                        V2ActionPill(
                          icon: Icons.restart_alt_rounded,
                          label: 'Reset',
                          onTap: _resetOutbox,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildQueueLedger(List<OfflineSyncAction> allQueue) {
    final filtered = _queueFilter == 'all'
        ? allQueue
        : allQueue.where((a) => a.status.toLowerCase() == _queueFilter).toList();

    return [
      V2FilterChipStrip(
        chips: [
          (id: 'all', label: 'All ${allQueue.length}'),
          (id: 'pending', label: 'Pending ${_syncQueue.pendingCount}'),
          (id: 'synced', label: 'Synced ${_syncQueue.syncedCount}'),
          (id: 'failed', label: 'Failed ${_syncQueue.failedCount}'),
        ],
        selectedId: _queueFilter,
        onSelect: (id) => setState(() => _queueFilter = id),
      ),
      const SizedBox(height: 10),
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: V2Tokens.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: V2Tokens.hairline, width: 1),
        ),
        child: filtered.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const V2FacetCell(status: 'approved', size: 16),
                    const SizedBox(height: 10),
                    Text('Offline queue empty', style: V2Tokens.t2()),
                    const SizedBox(height: 4),
                    Text(
                      'Drafts, approvals, and schedules created offline appear here with idempotency keys.',
                      textAlign: TextAlign.center,
                      style: V2Tokens.t3(color: V2Tokens.textSecondary),
                    ),
                  ],
                ),
              )
            : Column(
                children: List.generate(filtered.length, (idx) {
                  final item = filtered[idx];
                  final isLast = idx == filtered.length - 1;
                  final syncState = SyncActionState.fromRaw(item.status);
                  final statusKey = syncState == SyncActionState.synced
                      ? 'approved'
                      : syncState == SyncActionState.failed
                          ? 'blocked'
                          : 'changes';
                  final isHighlighted = syncState.isRetryable || syncState == SyncActionState.syncing;
                  return Container(
                    decoration: BoxDecoration(
                      color: isHighlighted ? V2Tokens.changedRowTint : Colors.transparent,
                      border: isLast
                          ? null
                          : const Border(bottom: BorderSide(color: V2Tokens.hairline, width: 1)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: V2FacetCell(
                            status: statusKey,
                            size: 13,
                            selected: isHighlighted,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: V2StatusBadge(
                                      status: statusKey,
                                      customLabel: item.isReplay
                                          ? 'Replayed cleanly'
                                          : syncState == SyncActionState.synced
                                              ? 'Synced'
                                              : syncState == SyncActionState.failed
                                                  ? 'Needs retry'
                                                  : syncState == SyncActionState.syncing
                                                      ? 'Syncing…'
                                                      : 'Pending sync',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    V2Mappers.formatShortTimestamp(item.createdAt),
                                    style: V2Tokens.t4(color: V2Tokens.textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(_friendlyActionLabel(item.actionType), style: V2Tokens.t2()),
                              const SizedBox(height: 4),
                              Text(
                                item.error ?? '${item.method} ${item.endpoint}',
                                style: V2Tokens.t3(
                                  color: syncState == SyncActionState.failed
                                      ? V2Tokens.blockedSolid
                                      : V2Tokens.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Key: ${item.idempotencyKey} · Retries: ${item.retryCount}',
                                      overflow: TextOverflow.ellipsis,
                                      style: V2Tokens.t4(color: V2Tokens.textSecondary),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _syncQueue.removeAction(item.actionId),
                                    child: Text(
                                      'Remove',
                                      style: V2Tokens.t4(color: V2Tokens.inkPrussian),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
      ),
    ];
  }

  List<Widget> _buildOutboxLedger() {
    final filtered = _outboxFilter == 'all'
        ? _outboxEvents
        : _outboxEvents.where((e) => e.status.toLowerCase() == _outboxFilter).toList();

    return [
      V2FilterChipStrip(
        chips: [
          (id: 'all', label: 'All ${_outboxEvents.length}'),
          (id: 'processed', label: 'Processed ${_stats.processed}'),
          (id: 'pending', label: 'Pending ${_stats.pending}'),
          (id: 'failed', label: 'Failed ${_stats.failed}'),
        ],
        selectedId: _outboxFilter,
        onSelect: (id) => setState(() => _outboxFilter = id),
      ),
      const SizedBox(height: 10),
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: V2Tokens.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: V2Tokens.hairline, width: 1),
        ),
        child: _loadingOutbox && _outboxEvents.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2, color: V2Tokens.inkPrussian),
                ),
              )
            : filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const V2FacetCell(status: 'approved', size: 16),
                        const SizedBox(height: 10),
                        Text('No matching outbox events', style: V2Tokens.t2()),
                        const SizedBox(height: 4),
                        Text(
                          'Every review or schedule transition records an immutable outbox entry.',
                          textAlign: TextAlign.center,
                          style: V2Tokens.t3(color: V2Tokens.textSecondary),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: List.generate(filtered.length, (idx) {
                      final evt = filtered[idx];
                      final isLast = idx == filtered.length - 1;
                      final delivery = OutboxDeliveryState.fromRaw(evt.status);
                      final isProc = delivery == OutboxDeliveryState.processed;
                      final isFail = delivery == OutboxDeliveryState.failed;
                      final statusKey = isProc
                          ? 'approved'
                          : isFail
                              ? 'blocked'
                              : 'changes';
                      final badgeText = isProc
                          ? 'Processed'
                          : delivery == OutboxDeliveryState.processing
                              ? 'Delivering…'
                              : isFail
                                  ? (evt.attempts >= evt.maxAttempts
                                      ? 'Max retries (${evt.attempts}/${evt.maxAttempts})'
                                      : 'Retry ${evt.attempts} of ${evt.maxAttempts}')
                                  : 'Pending dispatch';

                      return Container(
                        decoration: BoxDecoration(
                          color: !isProc ? V2Tokens.changedRowTint : Colors.transparent,
                          border: isLast
                              ? null
                              : const Border(bottom: BorderSide(color: V2Tokens.hairline, width: 1)),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: V2FacetCell(
                                status: statusKey,
                                size: 13,
                                selected: !isProc,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: V2StatusBadge(
                                          status: statusKey,
                                          customLabel: badgeText,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        V2Mappers.formatShortTimestamp(evt.createdAt),
                                        style: V2Tokens.t4(color: V2Tokens.textSecondary),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(_friendlyOutboxLabel(evt), style: V2Tokens.t2()),
                                  const SizedBox(height: 4),
                                  Text(
                                    isFail
                                        ? (evt.errorLog ?? 'Retry backoff scheduled')
                                        : isProc
                                            ? 'Committed atomically & delivered to recipients'
                                            : 'Awaiting background worker dispatch',
                                    style: V2Tokens.t3(
                                      color: isFail ? V2Tokens.blockedSolid : V2Tokens.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Event ${evt.eventId}',
                                        style: V2Tokens.t4(color: V2Tokens.textSecondary),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: List.generate(5, (cIdx) {
                                          Color c = V2Tokens.surfaceRecessed;
                                          if (isProc && cIdx == 0) {
                                            c = V2Tokens.approvedSolid;
                                          } else if (isFail && cIdx < evt.attempts) {
                                            c = cIdx == evt.attempts - 1
                                                ? V2Tokens.cadmiumYellow
                                                : V2Tokens.blockedSolid;
                                          }
                                          return Container(
                                            width: 8,
                                            height: 8,
                                            margin: EdgeInsets.only(right: cIdx == 4 ? 0 : 3),
                                            decoration: BoxDecoration(
                                              color: c,
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
      ),
    ];
  }
}

