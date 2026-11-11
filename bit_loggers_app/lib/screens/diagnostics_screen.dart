import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Diagnostic Engine Log Viewer
/// Cryptographic correlation ID tracing, transaction telemetry,
/// failure simulation logs, and outbox delivery tracking.
class DiagnosticsScreen extends StatefulWidget {
  final ApiService api;

  const DiagnosticsScreen({super.key, required this.api});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  List<DiagnosticLogItem> _logs = [];
  bool _loading = true;
  String _selectedOutcome = 'ALL'; // 'ALL', 'SUCCESS', 'FAILURE', 'INFO'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.getDiagnostics();
      if (mounted) {
        setState(() {
          _logs = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<DiagnosticLogItem> get _filteredLogs {
    return _logs.where((l) {
      if (_selectedOutcome != 'ALL' && l.outcome.toUpperCase() != _selectedOutcome) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return l.correlationId.toLowerCase().contains(q) ||
          l.eventType.toLowerCase().contains(q) ||
          l.message.toLowerCase().contains(q);
    }).toList();
  }

  Color _getOutcomeColor(String outcome) {
    switch (outcome.toUpperCase()) {
      case 'SUCCESS':
        return AppTheme.statusApproved;
      case 'FAILURE':
      case 'ERROR':
        return AppTheme.statusRejected;
      case 'ATTEMPT':
      case 'WARN':
        return AppTheme.statusChanges;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _getOutcomeIcon(String outcome) {
    switch (outcome.toUpperCase()) {
      case 'SUCCESS':
        return Icons.check_circle_outline;
      case 'FAILURE':
      case 'ERROR':
        return Icons.error_outline;
      case 'ATTEMPT':
        return Icons.replay_outlined;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredLogs;

    return Scaffold(
      backgroundColor: AppTheme.paper,
      appBar: AppBar(
        backgroundColor: AppTheme.paper,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Diagnostic Telemetry',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              'Pipeline health & request tracing',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.textPrimary),
            tooltip: 'Refresh telemetry',
            onPressed: _fetch,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
          if (_loading)
            LinearProgressIndicator(
              minHeight: 2.5,
              color: AppTheme.label,
              backgroundColor: AppTheme.tertiarySystemBackground,
            ),

          // Visual Health & Pipeline Telemetry Spectrum
          _buildDiagnosticsTelemetryCard(items),

          // Search & Filter Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: AppTheme.systemBackground,
              border: Border(bottom: BorderSide(color: AppTheme.separator, width: 0.5)),
            ),
            child: Column(
              children: [
                // Search Input Field
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.secondarySystemBackground,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppTheme.appleCardShadow,
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(fontSize: 13, color: AppTheme.label),
                    decoration: InputDecoration(
                      hintText: 'Search by correlation UUID, event, or error...',
                      hintStyle: TextStyle(fontSize: 12, color: AppTheme.secondaryLabel),
                      prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.secondaryLabel),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, size: 16, color: AppTheme.secondaryLabel),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  ),
                ),
                const SizedBox(height: 10),

                // Outcome Chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.tertiarySystemBackground,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${items.length} telemetry entries',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.label,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Outcome toggle buttons
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppTheme.tertiarySystemBackground,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildOutcomeFilterBtn('All', 'ALL'),
                          _buildOutcomeFilterBtn('Success', 'SUCCESS'),
                          _buildOutcomeFilterBtn('Failure', 'FAILURE'),
                          _buildOutcomeFilterBtn('Info', 'INFO'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Diagnostic Log Cards List
          Expanded(
            child: items.isEmpty && !_loading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.terminal_outlined, size: 48, color: AppTheme.textSecondary),
                        SizedBox(height: 12),
                        Text(
                          'No Diagnostics Found',
                          style: TextStyle(fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'No telemetry entries match the current search or outcome filter.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetch,
                    color: AppTheme.accent,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: items.length,
                      itemBuilder: (context, idx) {
                        final log = items[idx];
                        return _buildLogCard(log);
                      },
                    ),
                  ),
          ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutcomeFilterBtn(String label, String outcomeKey) {
    final isSelected = _selectedOutcome == outcomeKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedOutcome = outcomeKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppTheme.onAccent : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosticsTelemetryCard(List<DiagnosticLogItem> logs) {
    int successCount = 0;
    int failureCount = 0;
    int infoCount = 0;
    for (final l in logs) {
      final o = l.outcome.toUpperCase();
      if (o == 'SUCCESS') {
        successCount++;
      } else if (o == 'FAILURE' || o == 'ERROR') {
        failureCount++;
      } else {
        infoCount++;
      }
    }
    final total = math.max(1, logs.length);
    final successFlex = math.max(1, (successCount * 100 / total).round());
    final failureFlex = math.max(1, (failureCount * 100 / total).round());
    final infoFlex = math.max(1, (infoCount * 100 / total).round());
    final healthRate = ((successCount / total) * 100).clamp(0, 100);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.secondarySystemBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.appleCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: failureCount > 0 ? AppTheme.warmAmber : AppTheme.moss,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'SYSTEM HEALTH & PIPELINE TELEMETRY',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: failureCount > 0 ? AppTheme.statusChangesBg : AppTheme.statusApprovedBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${healthRate.toStringAsFixed(0)}% Reliability',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: failureCount > 0 ? AppTheme.statusChanges : AppTheme.statusApproved,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Visual Spectrum Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 7,
              child: Row(
                children: [
                  Expanded(
                    flex: successFlex,
                    child: Container(color: AppTheme.moss),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: failureFlex,
                    child: Container(color: AppTheme.crimsonNeedle),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: infoFlex,
                    child: Container(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Legend chips
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              _buildDiagChip('Success', '$successCount', AppTheme.statusApproved),
              _buildDiagChip('Failure', '$failureCount', AppTheme.statusRejected),
              _buildDiagChip('Info', '$infoCount', AppTheme.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiagChip(String label, String count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
        ),
        Text(
          count,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildLogCard(DiagnosticLogItem log) {
    final outcomeColor = _getOutcomeColor(log.outcome);
    final outcomeIcon = _getOutcomeIcon(log.outcome);

    DateTime? recorded;
    try {
      recorded = DateTime.parse(log.timestamp).toLocal();
    } catch (_) {}

    final timeStr = recorded != null
        ? DateFormat('HH:mm:ss • d MMM').format(recorded)
        : log.timestamp;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.secondarySystemBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.appleCardShadow,
      ),
      child: InkWell(
        onTap: () => _showLogDetail(log),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Outcome + Event Type + Time
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(outcomeIcon, size: 14, color: outcomeColor),
                      const SizedBox(width: 6),
                      Text(
                        log.eventType,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: outcomeColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      timeStr,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Log Message
              Text(
                log.message,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textPrimary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),

              // Bottom Row: Correlation ID
              Row(
                children: [
                  Icon(Icons.fingerprint, size: 12, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      log.correlationId,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: outcomeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      log.outcome,
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: outcomeColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogDetail(DiagnosticLogItem log) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.leaf,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.quaternaryLabel,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    log.eventType,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.label, letterSpacing: -0.4),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getOutcomeColor(log.outcome).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      log.outcome,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: _getOutcomeColor(log.outcome)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: AppTheme.separator, height: 0.5),
              const SizedBox(height: 12),
              _buildDetailRow('Log ID', log.logId, isMonospace: true),
              _buildDetailRow('Correlation UUID', log.correlationId, isMonospace: true),
              _buildDetailRow('Timestamp', log.timestamp),
              const SizedBox(height: 14),
              Text('Diagnostic message', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.secondaryLabel)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.tertiarySystemBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  log.message,
                  style: TextStyle(fontSize: 12, color: AppTheme.label, height: 1.4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isMonospace = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: isMonospace ? 'monospace' : null,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
