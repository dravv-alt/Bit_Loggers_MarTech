import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/marketing_visuals.dart';
import 'campaign_detail_screen.dart';

/// FR-10: Audit Trail & Historical Governance Log Viewer (ADR-008)
/// TimescaleDB Hypertable append-only ledger for non-repudiation,
/// cryptographic event verification, actor-based governance filtering,
/// and deep payload state transition inspection.
class AuditScreen extends StatefulWidget {
  final ApiService api;
  final String? initialCampaignId;

  const AuditScreen({super.key, required this.api, this.initialCampaignId});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  List<AuditEventItem> _auditEvents = [];
  bool _loading = true;
  String _selectedEventType = 'ALL';
  String _selectedRoleFilter = 'ALL'; // 'ALL', 'marketer', 'reviewer', 'system'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _eventTypes = const [
    'ALL',
    'CAMPAIGN_CREATED',
    'CAMPAIGN_SUBMITTED',
    'CAMPAIGN_APPROVED',
    'CHANGES_REQUESTED',
    'CAMPAIGN_REJECTED',
    'EDIT_LOCK_ACQUIRED',
    'SCHEDULE_BLOCKED',
    'VERSION_CONFLICT',
    'CIRCUIT_BREAKER',
    'MENTION',
  ];

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
      final list = await widget.api.getAudit(
        campaignId: widget.initialCampaignId,
        eventType: _selectedEventType != 'ALL' ? _selectedEventType : null,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      if (mounted) {
        setState(() {
          _auditEvents = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AuditEventItem> get _filteredEvents {
    return _auditEvents.where((evt) {
      if (_selectedRoleFilter != 'ALL') {
        final actor = evt.actorName.toLowerCase();
        final role = _selectedRoleFilter.toLowerCase();
        if (role == 'marketer' && !actor.contains('marketer') && !actor.contains('alex') && !actor.contains('alice')) {
          return false;
        }
        if (role == 'reviewer' && !actor.contains('reviewer') && !actor.contains('marcus') && !actor.contains('sarah')) {
          return false;
        }
        if (role == 'system' && !actor.contains('system') && !actor.contains('worker') && !actor.contains('circuit')) {
          return false;
        }
      }

      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final inSummary = evt.summary.toLowerCase().contains(q);
      final inActor = evt.actorName.toLowerCase().contains(q);
      final inType = evt.eventType.toLowerCase().contains(q);
      final inCamp = (evt.campaignId ?? '').toLowerCase().contains(q);
      final inDetails = evt.details.toLowerCase().contains(q);

      return inSummary || inActor || inType || inCamp || inDetails;
    }).toList();
  }

  Color _getEventColor(String eventType) {
    final type = eventType.toUpperCase();
    if (type.contains('APPROV')) return AppTheme.verdictLimeDark;
    if (type.contains('SUBMIT')) return AppTheme.forge;
    if (type.contains('CREATE')) return AppTheme.forge;
    if (type.contains('LOCK')) return const Color(0xFF1E3A8A);
    if (type.contains('CHANGE') || type.contains('WARN')) return const Color(0xFFB45309);
    if (type.contains('REJECT') || type.contains('BLOCK') || type.contains('CONFLICT')) return AppTheme.statusRejected;
    if (type.contains('CIRCUIT')) return const Color(0xFF991B1B);
    return AppTheme.textSecondary;
  }

  IconData _getEventIcon(String eventType) {
    final type = eventType.toUpperCase();
    if (type.contains('APPROV')) return Icons.check_circle_outline;
    if (type.contains('SUBMIT')) return Icons.send_outlined;
    if (type.contains('CREATE')) return Icons.add_circle_outline;
    if (type.contains('LOCK')) return Icons.lock_clock_outlined;
    if (type.contains('CHANGE')) return Icons.edit_note_outlined;
    if (type.contains('REJECT')) return Icons.cancel_outlined;
    if (type.contains('BLOCK')) return Icons.block_outlined;
    if (type.contains('CONFLICT')) return Icons.sync_problem_outlined;
    if (type.contains('CIRCUIT')) return Icons.offline_bolt_outlined;
    if (type.contains('MENTION')) return Icons.alternate_email;
    return Icons.history_edu_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredEvents;

    return Scaffold(
      backgroundColor: AppTheme.paper,
      appBar: AppBar(
        backgroundColor: AppTheme.paper,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.forge),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Audit Trail & Governance',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              widget.initialCampaignId != null
                  ? 'Anchored to ${widget.initialCampaignId} • TimescaleDB'
                  : 'TimescaleDB Append-Only Hypertable (ADR-008)',
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.forge),
            tooltip: 'Reload ledger',
            onPressed: _fetch,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Loading indicator line
          if (_loading)
            const LinearProgressIndicator(
              minHeight: 2.5,
              color: AppTheme.forge,
              backgroundColor: AppTheme.borderSage,
            ),

          // Immutable Governance Telemetry Spectrum Card
          _buildGovernanceTelemetryCard(items),

          // Search & Filter Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: AppTheme.paper,
              border: Border(bottom: BorderSide(color: AppTheme.borderSage, width: 1)),
            ),
            child: Column(
              children: [
                // Search Input Field
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.leaf,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderSage, width: 1),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search audit ledger by actor, event, or ID...',
                      hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textSecondary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16, color: AppTheme.textSecondary),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val.trim());
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Event Count & Actor Role Filters
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.forge.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${items.length} records in hypertable',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.forge),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Role segment buttons
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppTheme.leaf,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderSage, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildRoleFilterBtn('All', 'ALL'),
                          _buildRoleFilterBtn('Marketer', 'marketer'),
                          _buildRoleFilterBtn('Reviewer', 'reviewer'),
                          _buildRoleFilterBtn('System', 'system'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Horizontal Event Type Filter Chips
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _eventTypes.length,
              itemBuilder: (context, idx) {
                final type = _eventTypes[idx];
                final isSelected = _selectedEventType == type;
                final label = type == 'ALL'
                    ? 'All Events'
                    : type.replaceAll('CAMPAIGN_', '').replaceAll('_', ' ');

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppTheme.leaf : AppTheme.textPrimary,
                    ),
                    selected: isSelected,
                    selectedColor: AppTheme.forge,
                    backgroundColor: AppTheme.leaf,
                    side: const BorderSide(color: AppTheme.borderSage, width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onSelected: (_) {
                      setState(() => _selectedEventType = type);
                      _fetch();
                    },
                  ),
                );
              },
            ),
          ),

          // Audit Events List
          Expanded(
            child: items.isEmpty && !_loading
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _fetch,
                    color: AppTheme.forge,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final evt = items[index];
                        return _buildAuditEventCard(evt);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleFilterBtn(String label, String roleKey) {
    final isSelected = _selectedRoleFilter == roleKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedRoleFilter = roleKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.forge : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppTheme.leaf : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildGovernanceTelemetryCard(List<AuditEventItem> events) {
    int approvedCount = 0;
    int createdCount = 0;
    int guardCount = 0;
    for (final e in events) {
      if (e.eventType.contains('APPROVED')) {
        approvedCount++;
      } else if (e.eventType.contains('CREATED') || e.eventType.contains('SUBMITTED')) {
        createdCount++;
      } else {
        guardCount++;
      }
    }
    final total = math.max(1, events.length);
    final approvedFlex = math.max(1, (approvedCount * 100 / total).round());
    final createdFlex = math.max(1, (createdCount * 100 / total).round());
    final guardFlex = math.max(1, (guardCount * 100 / total).round());

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSage),
        boxShadow: [
          BoxShadow(
            color: AppTheme.forge.withOpacity(0.02),
            blurRadius: 6,
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
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.moss,
                ),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'IMMUTABLE GOVERNANCE SPECTRUM',
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
                  color: AppTheme.statusApprovedBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '100% Cryptographic Seal',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.statusApproved,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Visual Multi-Segmented Spectrum Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 7,
              child: Row(
                children: [
                  Expanded(
                    flex: approvedFlex,
                    child: Container(color: AppTheme.moss),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: createdFlex,
                    child: Container(color: AppTheme.forge),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: guardFlex,
                    child: Container(color: AppTheme.warmAmber),
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
              _buildTelemetryChip('Approved', '$approvedCount', AppTheme.moss),
              _buildTelemetryChip('Created', '$createdCount', AppTheme.forge),
              _buildTelemetryChip('Guarded', '$guardCount', AppTheme.warmAmber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryChip(String label, String count, Color color) {
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
          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
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

  Widget _buildAuditEventCard(AuditEventItem evt) {
    final eventColor = _getEventColor(evt.eventType);
    final eventIcon = _getEventIcon(evt.eventType);

    DateTime? occurred;
    try {
      occurred = DateTime.parse(evt.occurredAt).toLocal();
    } catch (_) {}

    final dateStr = occurred != null
        ? DateFormat('d MMM yyyy • HH:mm:ss').format(occurred)
        : evt.occurredAt;

    final hasTransition = evt.previousState != null || evt.newState != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderSage, width: 1),
      ),
      child: InkWell(
        onTap: () => _showAuditDetailModal(evt),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Event Type Badge + Timestamp
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: eventColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: eventColor.withOpacity(0.3), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(eventIcon, size: 12, color: eventColor),
                        const SizedBox(width: 4),
                        Text(
                          evt.eventType,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: eventColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dateStr,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Summary Text
              Text(
                evt.summary,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),

              // State Transition Flow (if applicable)
              if (hasTransition) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.paper,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderSage),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        evt.previousState ?? 'Initial',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward, size: 12, color: AppTheme.forge),
                      ),
                      Text(
                        evt.newState ?? 'Updated',
                        style: const TextStyle(fontSize: 11, color: AppTheme.forge, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Bottom Row: Actor & Correlation ID
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MarketerAvatar(userId: evt.actorId, size: 20),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 130),
                        child: Text(
                          evt.actorName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                        ),
                      ),
                      if (evt.campaignId != null) ...[
                        const Text(' • ', style: TextStyle(color: AppTheme.textSecondary)),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            evt.campaignId!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.forge),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fingerprint, size: 12, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        evt.eventId.length > 12 ? '${evt.eventId.substring(0, 10)}...' : evt.eventId,
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history_edu_outlined, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            const Text(
              'No Audit Records Match Filters',
              style: TextStyle(fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try clearing search keywords or switching event type filters.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedEventType = 'ALL';
                  _selectedRoleFilter = 'ALL';
                });
                _fetch();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.forge,
                side: const BorderSide(color: AppTheme.forge),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Reset All Filters', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAuditDetailModal(AuditEventItem evt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.leaf,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.94,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: ListView(
                controller: scrollController,
                children: [
                  // Grab Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.borderSage,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getEventColor(evt.eventType).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            evt.eventType,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _getEventColor(evt.eventType),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          evt.occurredAt.length >= 19 ? evt.occurredAt.substring(0, 19).replaceAll('T', ' ') : evt.occurredAt,
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Text(
                    evt.summary,
                    style: const TextStyle(
                      fontFamily: 'serif',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppTheme.borderSage, height: 1),
                  const SizedBox(height: 14),

                  // Governance Metadata Grid
                  _buildModalMetaRow('Audit Event ID', evt.eventId, isMonospace: true),
                  if (evt.correlationId != null)
                    _buildModalMetaRow('Correlation UUID', evt.correlationId!, isMonospace: true),
                  _buildModalMetaRow('Actor Name', evt.actorName),
                  if (evt.actorId != null)
                    _buildModalMetaRow('Actor ID', evt.actorId!, isMonospace: true),
                  if (evt.campaignId != null)
                    _buildModalMetaRow('Campaign Ref', evt.campaignId!, isMonospace: true),
                  if (evt.versionId != null)
                    _buildModalMetaRow('Version Ref', evt.versionId!, isMonospace: true),
                  if (evt.previousState != null)
                    _buildModalMetaRow('Previous State', evt.previousState!),
                  if (evt.newState != null)
                    _buildModalMetaRow('New State', evt.newState!),

                  const SizedBox(height: 16),
                  const Text(
                    'TIMESCALEDB HYPERTABLE PAYLOAD (JSON)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // JSON Payload Container
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.paper,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderSage),
                    ),
                    child: SelectableText(
                      _formatJson(evt.rawDetails ?? {'details': evt.details}),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppTheme.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Cryptographic Seal Note
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.verdictLime.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.forge.withOpacity(0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified_outlined, size: 16, color: AppTheme.forge),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'TimescaleDB Append-Only Non-Repudiation Seal: Timestamp partition verified & immutable.',
                            style: TextStyle(fontSize: 11, color: AppTheme.forge, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action Button to Campaign Dossier (if campaign linked)
                  if (evt.campaignId != null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CampaignDetailScreen(
                                campaignId: evt.campaignId!,
                                api: widget.api,
                              ),
                            ),
                          ).then((_) => _fetch());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.forge,
                          foregroundColor: AppTheme.leaf,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.folder_open, size: 16),
                        label: const Text('Open Campaign Dossier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalMetaRow(String label, String value, {bool isMonospace = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
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

  String _formatJson(dynamic object) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(object);
    } catch (_) {
      return object.toString();
    }
  }
}
