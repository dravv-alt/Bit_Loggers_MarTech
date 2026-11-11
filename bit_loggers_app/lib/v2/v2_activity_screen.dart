import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'v2_components.dart';
import 'v2_diagnostics_screen.dart';
import 'v2_mappers.dart';
import 'v2_sync_hub_screen.dart';
import 'v2_tokens.dart';
import 'v2_verification_screen.dart';

/// Screen 15: Append-Only Activity Ledger, Delivery Retry Cells & Operational Utilities.
class V2ActivityScreen extends StatefulWidget {
  final ApiService api;
  final List<AuditEventItem> auditEvents;
  final VoidCallback onRefreshRequested;

  const V2ActivityScreen({
    super.key,
    required this.api,
    required this.auditEvents,
    required this.onRefreshRequested,
  });

  @override
  State<V2ActivityScreen> createState() => _V2ActivityScreenState();
}

class _V2ActivityScreenState extends State<V2ActivityScreen> {
  String _filter = 'All';
  List<OutboxEventItem> _outbox = [];
  bool _loadingOutbox = false;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _loadOutbox();
  }

  Future<void> _loadOutbox() async {
    setState(() => _loadingOutbox = true);
    try {
      final data = await widget.api.getOutbox();
      if (mounted) {
        setState(() {
          _outbox = (data['events'] as List<OutboxEventItem>?) ?? [];
          _loadingOutbox = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOutbox = false);
    }
  }

  String _categoryForEvent(AuditEventItem e) {
    final t = e.eventType.toUpperCase();
    if (t.contains('SCHEDULE')) return 'Schedule';
    if (t.contains('LOCK') || t.contains('DELIVERY') || t.contains('OUTBOX')) return 'System';
    return 'Decisions';
  }

  String _statusForEvent(AuditEventItem e) {
    final t = e.eventType.toUpperCase();
    if (t.contains('APPROVED') || t.contains('SCHEDULED') || t.contains('RESUMED')) {
      return 'approved';
    }
    if (t.contains('REJECTED') || t.contains('PAUSED') || t.contains('CONFLICT')) {
      return 'blocked';
    }
    if (t.contains('CHANGES')) return 'changes';
    return 'review';
  }

  String _prettyState(String raw) {
    if (raw == 'ChangesRequested') return 'Changes requested';
    return raw;
  }

  String _transitionLabel(AuditEventItem e) {
    if (e.previousState != null && e.newState != null) {
      return '${_prettyState(e.previousState!)} → ${_prettyState(e.newState!)}';
    }
    final words = e.eventType.toLowerCase().split('_');
    if (words.isEmpty) return 'Event';
    return '${words.first[0].toUpperCase()}${words.first.substring(1)} ${words.skip(1).join(' ')}'.trim();
  }

  String _friendlyOutboxTitle(OutboxEventItem item) {
    final pTitle = item.payload['title']?.toString().trim();
    if (pTitle != null && pTitle.isNotEmpty) return pTitle;
    switch (item.eventType.toUpperCase()) {
      case 'CAMPAIGN_SUBMITTED_EMAIL':
        return 'Review request notice';
      case 'CAMPAIGN_DECISION_EMAIL':
        return 'Decision notice';
      case 'ANALYTICS_DATA_SYNC':
        return 'Performance rollup sync';
      default:
        final words = item.eventType.toLowerCase().replaceAll('_', ' ').trim();
        return words.isEmpty ? 'Delivery notice' : '${words[0].toUpperCase()}${words.substring(1)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'All'
        ? widget.auditEvents
        : widget.auditEvents.where((e) => _categoryForEvent(e) == _filter).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      children: [
        Text('Activity', style: V2Tokens.t1()),
        const SizedBox(height: 10),

        // Category Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Decisions', 'Schedule', 'System'].map((tab) {
              final isSelected = _filter == tab;
              return GestureDetector(
                onTap: () => setState(() => _filter = tab),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: isSelected ? V2Tokens.surfaceCard : V2Tokens.surfaceRecessed,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isSelected ? V2Tokens.inkPrussian : V2Tokens.hairline,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 7, 12, 9),
                        child: Text(
                          tab,
                          style: V2Tokens.t4(
                            color: isSelected ? V2Tokens.textPrimary : V2Tokens.textSecondary,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          bottom: 0,
                          left: 10,
                          right: 10,
                          child: Container(height: 2.5, color: V2Tokens.cadmiumYellow),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Append-Only Audit Timeline Card
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: V2Tokens.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: V2Tokens.hairline, width: 1),
          ),
          child: filtered.isEmpty
              ? Text(
                  'No events recorded in this category.',
                  style: V2Tokens.t3(color: V2Tokens.textSecondary),
                )
              : Column(
                  children: List.generate(filtered.length, (idx) {
                    final ev = filtered[idx];
                    final isLast = idx == filtered.length - 1;
                    final st = _statusForEvent(ev);
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              children: [
                                V2FacetCell(status: st, size: 12),
                                if (!isLast)
                                  Expanded(
                                    child: Container(
                                      width: 1.5,
                                      margin: const EdgeInsets.only(top: 4),
                                      color: V2Tokens.hairline,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(ev.actorName, style: V2Tokens.t3(fontWeight: FontWeight.w600)),
                                      Text(
                                        V2Mappers.formatShortTimestamp(ev.occurredAt),
                                        style: V2Tokens.t4(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    ev.summary,
                                    style: V2Tokens.t3(color: V2Tokens.textSecondary),
                                  ),
                                  const SizedBox(height: 5),
                                  V2StatusBadge(
                                    status: st,
                                    customLabel: _transitionLabel(ev),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
        ),
        const SizedBox(height: 16),

        // Delivery Outbox & Notifications Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Notifications & delivery', style: V2Tokens.t2()),
            InkWell(
              onTap: _processing
                  ? null
                  : () async {
                      setState(() => _processing = true);
                      await widget.api.processOutbox();
                      await _loadOutbox();
                      widget.onRefreshRequested();
                      if (mounted) setState(() => _processing = false);
                    },
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: V2Tokens.surfaceCard,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: V2Tokens.hairline, width: 1),
                ),
                child: Text(
                  _processing ? 'Dispatching…' : 'Dispatch pending',
                  style: V2Tokens.t4(color: V2Tokens.inkPrussian),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Container(
          decoration: BoxDecoration(
            color: V2Tokens.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: V2Tokens.hairline, width: 1),
          ),
          child: _loadingOutbox && _outbox.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: V2Tokens.inkPrussian),
                  ),
                )
              : Column(
                  children: List.generate(_outbox.length, (idx) {
                    final item = _outbox[idx];
                    final isProc = item.status.toUpperCase() == 'PROCESSED';
                    final isFail = item.status.toUpperCase() == 'FAILED';
                    final statusKey = isProc
                        ? 'approved'
                        : isFail
                            ? 'blocked'
                            : 'changes';
                    final chipLabel = isProc
                        ? 'Processed'
                        : isFail
                            ? 'Retrying ${item.attempts} of ${item.maxAttempts}'
                            : 'Queued';
                    final recipient = item.payload['recipient'] ??
                        (item.payload['recipients'] is List
                            ? (item.payload['recipients'] as List).join(', ')
                            : 'Stakeholders');
                    final titleText = _friendlyOutboxTitle(item);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: idx < _outbox.length - 1
                            ? const Border(bottom: BorderSide(color: V2Tokens.hairline, width: 1))
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '$titleText · $recipient',
                                  overflow: TextOverflow.ellipsis,
                                  style: V2Tokens.t3(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
                              V2StatusBadge(status: statusKey, customLabel: chipLabel),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  isFail
                                      ? (item.errorLog ?? 'Retry backoff active')
                                      : isProc
                                          ? 'Committed & dispatched'
                                          : 'Awaiting worker dispatch',
                                  overflow: TextOverflow.ellipsis,
                                  style: V2Tokens.t3(color: V2Tokens.textSecondary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 5 Delivery Attempt Cells
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(5, (cIdx) {
                                  Color cellColor = V2Tokens.surfaceRecessed;
                                  if (isProc && cIdx == 0) {
                                    cellColor = V2Tokens.approvedSolid;
                                  } else if (isFail && cIdx < item.attempts) {
                                    cellColor = cIdx == item.attempts - 1
                                        ? V2Tokens.cadmiumYellow
                                        : V2Tokens.blockedSolid;
                                  }
                                  return Container(
                                    width: 8,
                                    height: 8,
                                    margin: EdgeInsets.only(right: cIdx == 4 ? 0 : 3),
                                    decoration: BoxDecoration(
                                      color: cellColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ),
        ),
        const SizedBox(height: 12),

        // Quick Workspace Console Utilities (Sync Queue, Diagnostics, System Verification)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: V2Tokens.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: V2Tokens.hairline, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _utilityBtn(
                context,
                icon: Icons.cloud_sync_outlined,
                label: 'Sync Hub',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => V2SyncHubScreen(api: widget.api)),
                ).then((_) => _loadOutbox()),
              ),
              _utilityBtn(
                context,
                icon: Icons.terminal_rounded,
                label: 'Diagnostics',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => V2DiagnosticsScreen(api: widget.api)),
                ),
              ),
              _utilityBtn(
                context,
                icon: Icons.shield_outlined,
                label: 'System Checks',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => V2VerificationScreen(api: widget.api)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'The audit trail is append-only.',
          style: V2Tokens.t3(color: V2Tokens.textSecondary),
        ),
      ],
    );
  }

  Widget _utilityBtn(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: V2Tokens.surfaceRecessed,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: V2Tokens.hairline, width: 0.8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: V2Tokens.inkPrussian),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: V2Tokens.t4(color: V2Tokens.inkPrussian),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

