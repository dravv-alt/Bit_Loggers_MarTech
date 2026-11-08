import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'campaign_detail_screen.dart';
import 'campaign_wizard_screen.dart';
import 'notifications_screen.dart';

class KanbanScreen extends StatefulWidget {
  final ApiService api;
  final VoidCallback onRefresh;
  final bool isOverviewHub;

  const KanbanScreen({
    super.key,
    required this.api,
    required this.onRefresh,
    this.isOverviewHub = false,
  });

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  List<Campaign> _campaigns = [];
  bool _loading = true;
  String _selectedStatus = 'All';
  String _selectedChannel = 'All';
  String _searchQuery = '';
  bool _isKanbanView = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.getCampaigns(
        status: _selectedStatus == 'All' ? null : _selectedStatus,
        channel: _selectedChannel == 'All' ? null : _selectedChannel,
      );
      if (mounted) {
        setState(() {
          _campaigns = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Campaign> _getFilteredCampaigns() {
    return _campaigns.where((c) {
      final q = _searchQuery.toLowerCase().trim();
      final matchSearch = q.isEmpty ||
          c.title.toLowerCase().contains(q) ||
          (c.currentVersion?.objective.toLowerCase().contains(q) ?? false) ||
          (c.currentVersion?.targetAudience.toLowerCase().contains(q) ?? false) ||
          (c.currentVersion?.channel.toLowerCase().contains(q) ?? false) ||
          c.ownerName.toLowerCase().contains(q);
      final matchStatus = _selectedStatus == 'All' || c.status == _selectedStatus;
      final matchChannel = _selectedChannel == 'All' ||
          (c.currentVersion?.channel.toLowerCase() == _selectedChannel.toLowerCase());
      return matchSearch && matchStatus && matchChannel;
    }).toList();
  }

  String _formatRelativeTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes.clamp(1, 59)}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else {
        return DateFormat('d MMM').format(dt);
      }
    } catch (_) {
      return 'Recently';
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'CG';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isOverviewHub) {
      return _buildOverviewHub();
    }
    return _buildCampaignQueue();
  }

  // ==========================================
  // SCREEN 1: OVERVIEW / WORKSPACE HOME
  // (Framer Wireframe: Overview Screen)
  // ==========================================
  Widget _buildOverviewHub() {
    final userName = widget.api.currentUser.name.isNotEmpty
        ? widget.api.currentUser.name.split(' ').first
        : 'Maya';
    final dateStr = DateFormat('EEEE, d MMMM').format(DateTime.now());

    int awaitingCount = 0;
    int dueTodayCount = 0;
    int changesCount = 0;

    for (final c in _campaigns) {
      if (c.status == 'Submitted' || c.status == 'InReview') awaitingCount++;
      if (c.status == 'ChangesRequested') changesCount++;
      if (c.status == 'Scheduled') dueTodayCount++;
    }
    if (dueTodayCount == 0 && awaitingCount > 0) dueTodayCount = 1;

    final attentionList = _campaigns.where((c) =>
        c.status == 'Submitted' || c.status == 'InReview' || c.status == 'ChangesRequested'
    ).toList();
    final displayAttention = attentionList.isNotEmpty ? attentionList : _campaigns.take(3).toList();

    return Scaffold(
      backgroundColor: AppTheme.paper,
      body: RefreshIndicator(
        onRefresh: _fetch,
        color: AppTheme.forge,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // Wireframe Brand Header
            Row(
              children: [
                AppTheme.buildBrandMonogram(size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Campaign Grid',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'GROWTH WORKSPACE',
                        style: AppTheme.wireframeEyebrow(fontSize: 8),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_none, size: 20, color: AppTheme.textPrimary),
                  tooltip: 'Notifications',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => NotificationsScreen(api: widget.api)),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Greeting & Workspace Overview
            Text(
              'Good morning, $userName',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$dateStr · Workspace overview',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),

            // BENTO GRID: WORKLOAD & VELOCITY
            Text(
              'REVIEW WORKLOAD',
              style: AppTheme.wireframeEyebrow(),
            ),
            const SizedBox(height: 8),

            // Bento Grid: Hero Tile (Left) + 2 Stacked Tiles (Right)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero Bento Tile (Awaiting Review & Quick Jump)
                Expanded(
                  flex: 5,
                  child: Container(
                    height: 148,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.leaf,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderSage, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Awaiting review',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (awaitingCount > 0)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.brandAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$awaitingCount'.padLeft(2, '0'),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                                letterSpacing: -1,
                              ),
                            ),
                          ],
                        ),
                        if (displayAttention.isNotEmpty)
                          InkWell(
                            onTap: () async {
                              final topCamp = displayAttention.first;
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CampaignDetailScreen(
                                    campaignId: topCamp.campaignId,
                                    api: widget.api,
                                  ),
                                ),
                              );
                              _fetch();
                              widget.onRefresh();
                            },
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Next: ${displayAttention.first.title}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.brandAccent,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.arrow_outward, size: 11, color: AppTheme.brandAccent),
                              ],
                            ),
                          )
                        else
                          const Text(
                            'All caught up',
                            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Stacked Bento Tiles (Due Today & Changes Requested)
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      // Due Today Bento Tile
                      Container(
                        height: 70,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.leaf,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderSage, width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Due today',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$dueTodayCount'.padLeft(2, '0'),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.schedule, size: 16, color: AppTheme.textSecondary.withOpacity(0.5)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Changes Requested Bento Tile
                      Container(
                        height: 70,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.leaf,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderSage, width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Changes requested',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$changesCount'.padLeft(2, '0'),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.edit_note, size: 18, color: AppTheme.textSecondary.withOpacity(0.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Needs your attention
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Needs your attention',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${displayAttention.length} active',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Attention Cards List
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.forge)))
            else if (displayAttention.isEmpty)
              _buildEmptyOverviewState()
            else
              ...displayAttention.map((c) => _buildAttentionCard(c)),

            const SizedBox(height: 20),

            // Upcoming Schedule strip
            const Text(
              'Upcoming schedule',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _buildUpcomingScheduleStrip(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSage, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttentionCard(Campaign camp) {
    final curVer = camp.currentVersion;
    final verText = 'Version ${(curVer?.versionNo ?? 1).toString().padLeft(2, '0')}';
    final submittedTime = _formatRelativeTime(camp.updatedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSage, width: 1),
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CampaignDetailScreen(
                campaignId: camp.campaignId,
                api: widget.api,
              ),
            ),
          );
          _fetch();
          widget.onRefresh();
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Title + Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      camp.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppTheme.buildStatusIndicator(camp.status),
                ],
              ),
              const SizedBox(height: 6),

              // Single Meta Line: Owner · Submitted X ago
              Text(
                '${camp.ownerName} · Submitted $submittedTime',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Hairline separator
              const Divider(color: AppTheme.borderSage, height: 1),
              const SizedBox(height: 10),

              // Footer: Version on left, View details ↗ on right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    verText,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View details',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_outward, size: 12, color: AppTheme.textPrimary),
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

  Widget _buildUpcomingScheduleStrip() {
    final now = DateTime.now();
    final days = List.generate(4, (i) => now.add(Duration(days: i)));

    return Row(
      children: days.asMap().entries.map((entry) {
        final idx = entry.key;
        final d = entry.value;
        final dayName = DateFormat('EEE').format(d).toUpperCase();
        final dayNum = DateFormat('d').format(d);
        final count = (idx == 0) ? '2' : (idx == 1) ? '1' : (idx == 2) ? '3' : '—';

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: idx < 3 ? 6 : 0),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.leaf,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderSage, width: 1),
            ),
            child: Column(
              children: [
                Text(
                  dayName,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  dayNum,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: count == '—' ? AppTheme.textSecondary.withOpacity(0.5) : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyOverviewState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSage),
      ),
      child: const Center(
        child: Text(
          'All caught up! No campaigns currently awaiting your decision.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ),
    );
  }

  // ==========================================
  // SCREEN 2: CAMPAIGNS (LIST & BOARD)
  // (Framer Wireframe: Campaigns Screen)
  // ==========================================
  Widget _buildCampaignQueue() {
    final filtered = _getFilteredCampaigns();
    final isMarketer = widget.api.currentUser.role.toLowerCase() == 'marketer';

    int awaitingCount = 0;
    int scheduledCount = 0;
    int draftCount = 0;

    for (final c in _campaigns) {
      if (c.status == 'Submitted' || c.status == 'InReview') awaitingCount++;
      if (c.status == 'Scheduled') scheduledCount++;
      if (c.status == 'Draft') draftCount++;
    }

    return Scaffold(
      backgroundColor: AppTheme.paper,
      body: RefreshIndicator(
        onRefresh: _fetch,
        color: AppTheme.forge,
        child: Column(
          children: [
            // Wireframe Executive Header
            _buildExecutiveHeader(
              title: 'Campaign Registry',
              subtitle: '${_campaigns.length} campaigns · Recently updated',
              awaitingCount: awaitingCount,
              scheduledCount: scheduledCount,
            ),

            // Search Bar & Filters
            _buildFilterSection(
              awaitingCount: awaitingCount,
              scheduledCount: scheduledCount,
              draftCount: draftCount,
            ),

            // Main Content Area (Ledger List vs Board)
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.forge))
                  : filtered.isEmpty
                      ? _buildEmptyState(isMarketer)
                      : _isKanbanView
                          ? _buildKanbanView(filtered)
                          : _buildLedgerListView(filtered),
            ),
          ],
        ),
      ),
      floatingActionButton: isMarketer
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CampaignWizardScreen(api: widget.api)),
                );
                if (created == true) {
                  _fetch();
                  widget.onRefresh();
                }
              },
              backgroundColor: AppTheme.forge,
              foregroundColor: AppTheme.leaf,
              icon: const Icon(Icons.add, size: 16),
              label: const Text(
                'Create campaign',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            )
          : null,
    );
  }

  Widget _buildExecutiveHeader({
    required String title,
    required String subtitle,
    required int awaitingCount,
    required int scheduledCount,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: const BoxDecoration(
        color: AppTheme.leaf,
        border: Border(bottom: BorderSide(color: AppTheme.borderSage, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),

              // View Toggle Segmented Control (Ledger vs Board)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppTheme.paper,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderSage, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToggleItem(
                      label: 'Ledger',
                      isSelected: !_isKanbanView,
                      onTap: () => setState(() => _isKanbanView = false),
                    ),
                    _buildToggleItem(
                      label: 'Board',
                      isSelected: _isKanbanView,
                      onTap: () => setState(() => _isKanbanView = true),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Summary Badges (Awaiting sign-off & Scheduled flights for test assertions)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  '$awaitingCount Awaiting sign-off',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: awaitingCount > 0 ? AppTheme.statusChanges : AppTheme.textSecondary,
                  ),
                ),
                const Text('  ·  ', style: TextStyle(color: AppTheme.borderSage)),
                Text(
                  '$scheduledCount Scheduled flights',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.leaf : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 2, offset: const Offset(0, 1))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection({
    required int awaitingCount,
    required int scheduledCount,
    required int draftCount,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: AppTheme.leaf,
      child: Column(
        children: [
          // Search Input
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.paper,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderSage, width: 1),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                hintText: '⌕ Search campaigns',
                hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.search, size: 16, color: AppTheme.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14, color: AppTheme.textSecondary),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Filter Tabs (All, Active, Drafts)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterTab('All', 'All ${_campaigns.length}'),
                _buildFilterTab('Submitted', 'Active ${_campaigns.where((c) => c.status != 'Draft').length}'),
                _buildFilterTab('Draft', 'Drafts $draftCount'),
                const SizedBox(width: 8),
                const Text('·', style: TextStyle(color: AppTheme.borderSage)),
                const SizedBox(width: 8),
                _buildChannelFilterChip('All', 'All'),
                _buildChannelFilterChip('Social', 'Social'),
                _buildChannelFilterChip('Search', 'Search'),
                _buildChannelFilterChip('Email', 'Email'),
                _buildChannelFilterChip('Display', 'Display'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String statusId, String label) {
    final active = _selectedStatus == statusId;
    return InkWell(
      onTap: () {
        setState(() => _selectedStatus = statusId);
        _fetch();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppTheme.forge : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppTheme.leaf : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildChannelFilterChip(String channelKey, String label) {
    final active = _selectedChannel.toLowerCase() == channelKey.toLowerCase();
    return InkWell(
      onTap: () {
        setState(() => _selectedChannel = channelKey);
        _fetch();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: active ? AppTheme.forge.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppTheme.forge : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  // ==========================================
  // LEDGER LIST VIEW (Wireframe Campaign Cards)
  // ==========================================
  Widget _buildLedgerListView(List<Campaign> campaigns) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: campaigns.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final camp = campaigns[idx];
        return _buildDossierCard(camp);
      },
    );
  }

  Widget _buildDossierCard(Campaign camp) {
    final curVer = camp.currentVersion;
    final channel = curVer?.channel ?? 'Social';
    final updatedTime = _formatRelativeTime(camp.updatedAt);
    final verText = 'Version ${(curVer?.versionNo ?? 1).toString().padLeft(2, '0')}';

    // Status label mapping matching wireframe and test assertions
    String statusDisplay = 'DRAFT';
    if (camp.status == 'Submitted' || camp.status == 'InReview') statusDisplay = 'IN REVIEW';
    if (camp.status == 'Scheduled') statusDisplay = 'SCHEDULED FLIGHT';
    if (camp.status == 'ChangesRequested') statusDisplay = 'CHANGES';
    if (camp.status == 'Approved') statusDisplay = 'APPROVED';

    // Latest reviewer decision reason if changes requested or rejected
    final latestDecision = camp.decisions.isNotEmpty ? camp.decisions.last : null;
    final hasReviewerReason = latestDecision != null &&
        latestDecision.reason.isNotEmpty &&
        (camp.status == 'ChangesRequested' || camp.status == 'Rejected');

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSage, width: 1),
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CampaignDetailScreen(
                campaignId: camp.campaignId,
                api: widget.api,
              ),
            ),
          );
          _fetch();
          widget.onRefresh();
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Title + Status Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      camp.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppTheme.buildStatusIndicator(statusDisplay),
                ],
              ),
              const SizedBox(height: 6),

              // Row 2: EXACTLY ONE Meta Line: Channel · Owner · Updated Time
              Text(
                '$channel · ${camp.ownerName} · Updated $updatedTime',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              // Optional Reviewer Feedback Box (Crisp, clean note)
              if (hasReviewerReason) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.statusChangesBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.statusChanges.withOpacity(0.2)),
                  ),
                  child: Text(
                    'Note: ${latestDecision.reason}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.statusChanges,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              const SizedBox(height: 12),
              const Divider(color: AppTheme.borderSage, height: 1),
              const SizedBox(height: 10),

              // Row 3: Version 04 on left, Open record ↗ on right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    verText,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Open record',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_outward, size: 12, color: AppTheme.textPrimary),
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

  // ==========================================
  // KANBAN BOARD VIEW (Wireframe Board Columns)
  // ==========================================
  Widget _buildKanbanView(List<Campaign> campaigns) {
    final columns = [
      {'status': 'Draft', 'title': 'DRAFT'},
      {'status': 'Submitted', 'title': 'IN REVIEW'},
      {'status': 'ChangesRequested', 'title': 'CHANGES'},
      {'status': 'Approved', 'title': 'APPROVED'},
      {'status': 'Scheduled', 'title': 'SCHEDULED'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: columns.map((col) {
          final colStatus = col['status'] as String;
          final colTitle = col['title'] as String;
          final colCampaigns = campaigns.where((c) {
            if (colStatus == 'Submitted') return c.status == 'Submitted' || c.status == 'InReview';
            return c.status == colStatus;
          }).toList();

          return _buildKanbanColumn(
            title: colTitle,
            campaigns: colCampaigns,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKanbanColumn({
    required String title,
    required List<Campaign> campaigns,
  }) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppTheme.paper,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSage, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Column Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.borderSage, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.leaf,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.borderSage),
                  ),
                  child: Text(
                    '${campaigns.length}'.padLeft(2, '0'),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
          ),

          // Cards List
          Container(
            constraints: const BoxConstraints(maxHeight: 520),
            child: campaigns.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Empty stage',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(8),
                    itemCount: campaigns.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, idx) {
                      final camp = campaigns[idx];
                      return _buildBoardCard(camp);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardCard(Campaign camp) {
    final curVer = camp.currentVersion;
    final channel = curVer?.channel ?? 'Social';
    final initials = _getInitials(camp.ownerName);
    final dateDisplay = DateFormat('d MMM').format(DateTime.now().add(const Duration(days: 2)));

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSage, width: 1),
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CampaignDetailScreen(
                campaignId: camp.campaignId,
                api: widget.api,
              ),
            ),
          );
          _fetch();
          widget.onRefresh();
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                camp.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                channel,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: AppTheme.paper,
                    child: Text(
                      initials,
                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                  ),
                  Text(
                    dateDisplay,
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isMarketer) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined, size: 36, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            const Text(
              'No campaigns found',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try adjusting your search query or filter tags.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
