import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'v2_components.dart';
import 'v2_mappers.dart';
import 'v2_tokens.dart';
import 'v2_utility_chrome.dart';

/// V2 Diagnostic Telemetry & Correlation Tracer in Perforated Ledger style.
class V2DiagnosticsScreen extends StatefulWidget {
  final ApiService api;

  const V2DiagnosticsScreen({super.key, required this.api});

  @override
  State<V2DiagnosticsScreen> createState() => _V2DiagnosticsScreenState();
}

class _V2DiagnosticsScreenState extends State<V2DiagnosticsScreen> {
  List<DiagnosticLogItem> _logs = [];
  bool _loading = true;
  String _selectedOutcome = 'ALL';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.getDiagnostics();
      if (!mounted) return;
      setState(() {
        _logs = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<DiagnosticLogItem> get _filtered {
    return _logs.where((log) {
      final out = log.outcome.toUpperCase();
      if (_selectedOutcome == 'SUCCESS' && out != 'SUCCESS') return false;
      if (_selectedOutcome == 'FAILURE' && out != 'FAILURE' && out != 'ERROR') return false;
      if (_selectedOutcome == 'INFO' && (out == 'SUCCESS' || out == 'FAILURE' || out == 'ERROR')) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return log.correlationId.toLowerCase().contains(q) ||
          log.eventType.toLowerCase().contains(q) ||
          log.message.toLowerCase().contains(q);
    }).toList();
  }

  String _statusKey(String outcome) {
    switch (outcome.toUpperCase()) {
      case 'SUCCESS':
        return 'approved';
      case 'FAILURE':
      case 'ERROR':
        return 'blocked';
      case 'ATTEMPT':
      case 'WARN':
      case 'WARNING':
        return 'changes';
      default:
        return 'review';
    }
  }

  String _prettyEventTitle(String raw) {
    final clean = raw.trim().replaceAll('_', ' ').toLowerCase();
    if (clean.isEmpty) return 'Telemetry check';
    return '${clean[0].toUpperCase()}${clean.substring(1)}';
  }

  void _copyCorrelationId(String id) {
    Clipboard.setData(ClipboardData(text: id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Trace ID copied: $id', style: V2Tokens.t3(color: V2Tokens.labelOnInk)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: V2Tokens.inkPrussian,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final successCount = _logs.where((l) => l.outcome.toUpperCase() == 'SUCCESS').length;
    final failCount = _logs.where((l) {
      final o = l.outcome.toUpperCase();
      return o == 'FAILURE' || o == 'ERROR';
    }).length;
    final otherCount = _logs.length - successCount - failCount;
    final items = _filtered;

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
                    icon: Icons.refresh_rounded,
                    label: _loading ? 'Refreshing…' : 'Refresh',
                    onTap: _loading ? null : _fetch,
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: V2Tokens.inkPrussian,
                    backgroundColor: V2Tokens.surfaceCard,
                    onRefresh: _fetch,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      children: [
                        Row(
                          children: [
                            V2FacetCell(
                              status: failCount > 0 ? 'blocked' : 'approved',
                              size: 12,
                              selected: failCount > 0,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pipeline health & correlation tracing',
                              style: V2Tokens.t3(color: V2Tokens.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Diagnostics', style: V2Tokens.t1()),
                        const SizedBox(height: 12),

                        // Perforated Telemetry Meter Card
                        Container(
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
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${_logs.length}', style: V2Tokens.t1(mono: true)),
                                        const SizedBox(height: 2),
                                        Text(
                                          'traced operational events',
                                          style: V2Tokens.t3(color: V2Tokens.textSecondary),
                                        ),
                                      ],
                                    ),
                                    V2StatusBadge(
                                      status: failCount > 0 ? 'blocked' : 'approved',
                                      customLabel: failCount > 0
                                          ? '$failCount failure(s)'
                                          : 'All checks healthy',
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
                                      okCount: successCount,
                                      warnCount: otherCount,
                                      errorCount: failCount,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '$successCount verified · $otherCount informational · $failCount failures',
                                      style: V2Tokens.t4(color: V2Tokens.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Search Input
                        Container(
                          decoration: BoxDecoration(
                            color: V2Tokens.surfaceCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: V2Tokens.hairline, width: 1),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: TextField(
                            controller: _searchCtrl,
                            style: V2Tokens.t3(),
                            onChanged: (v) => setState(() => _searchQuery = v.trim()),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              border: InputBorder.none,
                              icon: const Icon(
                                Icons.search_rounded,
                                size: 18,
                                color: V2Tokens.textSecondary,
                              ),
                              hintText: 'Filter by trace ID, event, or message…',
                              hintStyle: V2Tokens.t3(color: V2Tokens.textSecondary),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                        color: V2Tokens.textSecondary,
                                      ),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Filter Chips
                        V2FilterChipStrip(
                          chips: [
                            (id: 'ALL', label: 'All ${_logs.length}'),
                            (id: 'SUCCESS', label: 'Success $successCount'),
                            (id: 'FAILURE', label: 'Failures $failCount'),
                            (id: 'INFO', label: 'Attempt / Info $otherCount'),
                          ],
                          selectedId: _selectedOutcome,
                          onSelect: (id) => setState(() => _selectedOutcome = id),
                        ),
                        const SizedBox(height: 12),

                        // Grouped Inset Diagnostic Ledger
                        Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: V2Tokens.surfaceCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: V2Tokens.hairline, width: 1),
                          ),
                          child: _loading && _logs.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: V2Tokens.inkPrussian,
                                    ),
                                  ),
                                )
                              : items.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        children: [
                                          const V2FacetCell(status: 'approved', size: 16),
                                          const SizedBox(height: 10),
                                          Text('No matching trace entries', style: V2Tokens.t2()),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Adjust your search filter or refresh diagnostics telemetry.',
                                            textAlign: TextAlign.center,
                                            style: V2Tokens.t3(color: V2Tokens.textSecondary),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Column(
                                      children: List.generate(items.length, (idx) {
                                        final log = items[idx];
                                        final isLast = idx == items.length - 1;
                                        final stKey = _statusKey(log.outcome);
                                        final isFailure = stKey == 'blocked';

                                        return Container(
                                          decoration: BoxDecoration(
                                            color: isFailure
                                                ? V2Tokens.changedRowTint
                                                : Colors.transparent,
                                            border: isLast
                                                ? null
                                                : const Border(
                                                    bottom: BorderSide(
                                                      color: V2Tokens.hairline,
                                                      width: 1,
                                                    ),
                                                  ),
                                          ),
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(top: 3),
                                                child: V2FacetCell(
                                                  status: stKey,
                                                  size: 13,
                                                  selected: isFailure,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Flexible(
                                                          child: V2StatusBadge(
                                                            status: stKey,
                                                            customLabel: log.outcome.isEmpty
                                                                ? 'Info'
                                                                : '${log.outcome[0].toUpperCase()}${log.outcome.substring(1).toLowerCase()}',
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          V2Mappers.formatShortTimestamp(
                                                              log.timestamp),
                                                          style: V2Tokens.t4(
                                                              color: V2Tokens.textSecondary),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      _prettyEventTitle(log.eventType),
                                                      style: V2Tokens.t2(),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      log.message,
                                                      style: V2Tokens.t3(
                                                          color: V2Tokens.textSecondary),
                                                    ),
                                                    if (log.correlationId.isNotEmpty) ...[
                                                      const SizedBox(height: 10),
                                                      InkWell(
                                                        onTap: () =>
                                                            _copyCorrelationId(log.correlationId),
                                                        borderRadius: BorderRadius.circular(8),
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(
                                                              horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: V2Tokens.surfaceRecessed,
                                                            borderRadius: BorderRadius.circular(8),
                                                            border: Border.all(
                                                              color: V2Tokens.hairline,
                                                              width: 0.8,
                                                            ),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              const Icon(
                                                                Icons.copy_rounded,
                                                                size: 12,
                                                                color: V2Tokens.inkPrussian,
                                                              ),
                                                              const SizedBox(width: 5),
                                                              Text(
                                                                'Trace ${log.correlationId}',
                                                                style: V2Tokens.t4(
                                                                    color: V2Tokens.inkPrussian),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ),
                        ),
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
}

