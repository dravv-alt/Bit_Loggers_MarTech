import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'campaign_detail_screen.dart';
import 'campaign_wizard_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    if (widget.isOverviewHub) {
      return _buildOverviewHub();
    }
    return _buildCampaignQueue();
  }

  // SCREEN 02: Marketer Home Dashboard matching the reference image!
  Widget _buildOverviewHub() {
    final isMarketer = widget.api.currentUser.role == 'marketer';
    final primaryCamp = _campaigns.isNotEmpty ? _campaigns.first : null;
    final primaryVer = primaryCamp?.currentVersion;
    final budgetFormatted = (primaryVer?.budget ?? 45000).toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );

    return Scaffold(
      backgroundColor: AppTheme.paper,
      body: RefreshIndicator(
        onRefresh: _fetch,
        color: AppTheme.forge,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Headline in high-contrast Editorial Serif
            const Text(
              'Make room\nfor reach.',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                height: 1.15,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 20),

            // PRIMARY FORGE CARD (#1B3029 deep forest green surface)
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppTheme.forge,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.borderSage.withOpacity(0.25), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text(
                          'Allocated budget',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textInverseMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.leaf.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Version v${primaryVer?.versionNo ?? 3}',
                          style: const TextStyle(
                            color: AppTheme.leaf,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Large Balance in Tabular Figures
                  Text(
                    '\$$budgetFormatted.00',
                    style: const TextStyle(
                      fontFamily: 'serif',
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.leaf,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Row: Submit V3 (Lime) + Lock status + Revise
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Verdict Lime Action Button (consequential)
                      InkWell(
                        onTap: () async {
                          if (primaryCamp != null) {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CampaignDetailScreen(
                                  campaignId: primaryCamp.campaignId,
                                  api: widget.api,
                                ),
                              ),
                            );
                            _fetch();
                            widget.onRefresh();
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: AppTheme.verdictLime,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isMarketer ? Icons.north_east : Icons.fact_check,
                                size: 14,
                                color: AppTheme.forge,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isMarketer
                                    ? 'Submit v${primaryVer?.versionNo ?? 3}'
                                    : 'Review v${primaryVer?.versionNo ?? 3}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.forge,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Lock Status
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppTheme.leaf.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline, size: 12, color: AppTheme.textInverseMuted),
                            SizedBox(width: 4),
                            Text(
                              'Lock: 04:12',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textInverseMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Revise text button
                      if (isMarketer)
                        TextButton(
                          onPressed: () {
                            if (primaryCamp != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CampaignWizardScreen(
                                    api: widget.api,
                                    existingCampaign: primaryCamp,
                                  ),
                                ),
                              ).then((_) => _fetch());
                            }
                          },
                          child: const Text(
                            '+ Revise',
                            style: TextStyle(
                              color: AppTheme.leaf,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // SECONDARY LEAF CARD (#FBFAF6 near-white surface with hairline sage border)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.leaf,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderSage, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your next chapter',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.paper,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderSage, width: 1),
                        ),
                        child: const Text(
                          'Goal',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.forge),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    primaryCamp?.title ?? 'Summer Sale Launch',
                    style: const TextStyle(
                      fontFamily: 'serif',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '3.4x Projected ROI • 4.8% CTR',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      value: 0.72,
                      minHeight: 4,
                      backgroundColor: AppTheme.paper,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.forge),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // RECENT ACTIVITY SECTION
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'Recent activity',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _selectedStatus = 'All');
                  },
                  child: const Text(
                    'See all',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Activity Item 1: Version V2
            _buildActivityRow(
              icon: Icons.description_outlined,
              title: 'Version v2',
              subtitle: 'Changes requested by reviewer',
              badge: 'Audience',
              badgeColor: AppTheme.statusChanges,
            ),
            const SizedBox(height: 8),

            // Activity Item 2: Version V1
            _buildActivityRow(
              icon: Icons.add_circle_outline,
              title: 'Version v1',
              subtitle: 'Approved (Superseded)',
              trailing: '+\$38,000',
              badgeColor: AppTheme.textSecondary,
            ),
            const SizedBox(height: 40),
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
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'New proposal',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            )
          : null,
    );
  }

  Widget _buildActivityRow({
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    String? trailing,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSage, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.paper,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: AppTheme.forge),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          if (badge != null)
            Text(
              badge,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: badgeColor,
              ),
            ),
          if (trailing != null)
            Text(
              trailing,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
        ],
      ),
    );
  }

  // SCREEN 03: Full Campaigns Registry & Interactive Flight Board
  Widget _buildCampaignQueue() {
    final filtered = _getFilteredCampaigns();
    final isMarketer = widget.api.currentUser.role == 'marketer';
    final isReviewer = widget.api.currentUser.role == 'reviewer';

    // Compute executive summary metrics
    double totalBudget = 0;
    int awaitingReviewCount = 0;
    int scheduledCount = 0;
    int changesCount = 0;
    int approvedCount = 0;
    int draftCount = 0;

    for (final c in _campaigns) {
      final b = c.currentVersion?.budget ?? 0;
      totalBudget += b;
      switch (c.status) {
        case 'Submitted':
          awaitingReviewCount++;
          break;
        case 'Scheduled':
          scheduledCount++;
          break;
        case 'ChangesRequested':
          changesCount++;
          break;
        case 'Approved':
          approvedCount++;
          break;
        case 'Draft':
          draftCount++;
          break;
      }
    }

    final formattedTotalBudget = totalBudget.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );

    return Scaffold(
      backgroundColor: AppTheme.paper,
      body: RefreshIndicator(
        onRefresh: _fetch,
        color: AppTheme.forge,
        child: Column(
          children: [
            // Archival Registry Header Strip with View Switcher & Executive Metrics
            _buildExecutiveHeader(
              title: isReviewer ? 'Review Queue' : 'Campaign Registry',
              subtitle: '${_campaigns.length} campaigns listed • \$$formattedTotalBudget total',
              awaitingCount: awaitingReviewCount,
              scheduledCount: scheduledCount,
            ),

            // Search and Filter Bar
            _buildFilterSection(
              awaitingCount: awaitingReviewCount,
              changesCount: changesCount,
              approvedCount: approvedCount,
              scheduledCount: scheduledCount,
              draftCount: draftCount,
            ),

            // Main Content Area: Ledger List vs Kanban Board
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.forge,
                      ),
                    )
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
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'New proposal',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      decoration: const BoxDecoration(
        color: AppTheme.paper,
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
                        fontFamily: 'serif',
                        fontSize: 22,
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

              // View Toggle Pill (Ledger vs Board)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppTheme.leaf,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSage, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildViewToggleBtn(
                      label: 'Ledger',
                      icon: Icons.view_agenda_outlined,
                      isSelected: !_isKanbanView,
                      onTap: () => setState(() => _isKanbanView = false),
                    ),
                    _buildViewToggleBtn(
                      label: 'Board',
                      icon: Icons.view_column_outlined,
                      isSelected: _isKanbanView,
                      onTap: () => setState(() => _isKanbanView = true),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Executive Summary Badges Row (Horizontally scrollable for all viewport widths)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMiniMetricBadge(
                  label: 'Awaiting sign-off',
                  count: awaitingCount,
                  color: awaitingCount > 0 ? AppTheme.statusChanges : AppTheme.textSecondary,
                  highlight: awaitingCount > 0,
                ),
                const SizedBox(width: 8),
                _buildMiniMetricBadge(
                  label: 'Scheduled flights',
                  count: scheduledCount,
                  color: AppTheme.forge,
                  highlight: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggleBtn({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.forge : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? AppTheme.leaf : AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.leaf : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMetricBadge({
    required String label,
    required int count,
    required Color color,
    required bool highlight,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: highlight ? color.withOpacity(0.12) : AppTheme.leaf,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight ? color.withOpacity(0.4) : AppTheme.borderSage,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection({
    required int awaitingCount,
    required int changesCount,
    required int approvedCount,
    required int scheduledCount,
    required int draftCount,
  }) {
    return Container(
      color: AppTheme.paper,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input Field
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.leaf,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderSage, width: 1),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search campaigns, objectives, audiences, channels…',
                hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.search, size: 16, color: AppTheme.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: AppTheme.textSecondary),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Status Tabs Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTabPill('All', 'All (${_campaigns.length})'),
                _buildTabPill('Submitted', 'In review ($awaitingCount)'),
                _buildTabPill('ChangesRequested', 'Changes ($changesCount)'),
                _buildTabPill('Approved', 'Approved ($approvedCount)'),
                _buildTabPill('Scheduled', 'Scheduled ($scheduledCount)'),
                _buildTabPill('Draft', 'Drafts ($draftCount)'),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Channel Filter Pills Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChannelFilterChip('All', 'All Channels'),
                _buildChannelFilterChip('Social', 'Social'),
                _buildChannelFilterChip('Search', 'Search'),
                _buildChannelFilterChip('Email', 'Email'),
                _buildChannelFilterChip('Display', 'Display'),
                _buildChannelFilterChip('Influencer', 'Influencer'),
                _buildChannelFilterChip('Video', 'Video'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabPill(String id, String label) {
    final active = _selectedStatus == id;
    return InkWell(
      onTap: () {
        setState(() => _selectedStatus = id);
        _fetch();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppTheme.forge : AppTheme.leaf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? AppTheme.forge : AppTheme.borderSage,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: active ? AppTheme.leaf : AppTheme.textPrimary,
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? AppTheme.forge.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppTheme.forge : AppTheme.borderSage.withOpacity(0.6),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: active ? AppTheme.forge : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  // LEDGER LIST VIEW (Architectural Dossier Cards)
  Widget _buildLedgerListView(List<Campaign> campaigns) {
    return RefreshIndicator(
      onRefresh: _fetch,
      color: AppTheme.forge,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        itemCount: campaigns.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, idx) {
          final camp = campaigns[idx];
          return _buildDossierCard(camp);
        },
      ),
    );
  }

  Widget _buildDossierCard(Campaign camp) {
    final curVer = camp.currentVersion;
    final channel = curVer?.channel ?? 'Social';
    final channelMeta = _getChannelMeta(channel);
    final statusMeta = _getStatusMeta(camp.status);
    final budgetFormatted = (curVer?.budget ?? 0).toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );

    // Latest reviewer decision reason if changes requested or rejected
    final latestDecision = camp.decisions.isNotEmpty ? camp.decisions.last : null;
    final hasReviewerReason = latestDecision != null &&
        latestDecision.reason.isNotEmpty &&
        (camp.status == 'ChangesRequested' || camp.status == 'Rejected');

    final isMarketer = widget.api.currentUser.role == 'marketer';
    final isReviewer = widget.api.currentUser.role == 'reviewer';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(20),
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
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Taxonomy: Channel Pill + Version Chip + Active Lock + Governance Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Channel Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: channelMeta['bg'] as Color,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: (channelMeta['color'] as Color).withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(channelMeta['icon'] as IconData, size: 11, color: channelMeta['color'] as Color),
                              const SizedBox(width: 4),
                              Text(
                                channel.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: channelMeta['color'] as Color,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Version Chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.paper,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.borderSage),
                          ),
                          child: Text(
                            'v${curVer?.versionNo ?? 1}.0',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.forge,
                            ),
                          ),
                        ),

                        // Lock Pill if held
                        if (camp.activeLock != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.statusChanges.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lock, size: 9, color: AppTheme.statusChanges),
                                const SizedBox(width: 3),
                                Text(
                                  'Locked: ${camp.activeLock!.holderName}',
                                  style: const TextStyle(fontSize: 9, color: AppTheme.statusChanges, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusMeta['bgColor'] as Color,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusMeta['borderColor'] as Color, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusMeta['icon'] as IconData, size: 10, color: statusMeta['textColor'] as Color),
                        const SizedBox(width: 4),
                        Text(
                          statusMeta['label'] as String,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: statusMeta['textColor'] as Color,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title in High-Contrast Editorial Serif
              Text(
                camp.title,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),

              // Objective excerpt
              if (curVer?.objective.isNotEmpty ?? false)
                Text(
                  curVer!.objective,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 12),

              // Target Audience Cohort Chip
              if (curVer?.targetAudience.isNotEmpty ?? false)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.paper,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderSage.withOpacity(0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.group_outlined, size: 12, color: AppTheme.forge),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          curVer!.targetAudience,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              // Economics Matrix (Budget + ROI + CPA Cap + CTR)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.paper,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderSage.withOpacity(0.7)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('ALLOCATED BUDGET', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          '\$$budgetFormatted.00',
                          style: const TextStyle(
                            fontFamily: 'serif',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.forge,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildKpiPill('ROI', '${curVer?.kpiProjected.roi.toStringAsFixed(1) ?? "3.8"}x'),
                        const SizedBox(width: 8),
                        _buildKpiPill('CPA CAP', '\$${curVer?.kpiProjected.cpa.toStringAsFixed(2) ?? "22.50"}'),
                        const SizedBox(width: 8),
                        _buildKpiPill('CTR', '${curVer?.kpiProjected.ctr.toStringAsFixed(1) ?? "4.5"}%'),
                      ],
                    ),
                  ],
                ),
              ),

              // Reviewer Written Justification Callout
              if (hasReviewerReason) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.statusChanges.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.statusChanges.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.rate_review_outlined, size: 14, color: AppTheme.statusChanges),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reviewer Note (${latestDecision.reviewerName}):',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.statusChanges),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              latestDecision.reason,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Action Footer
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Owner: ${camp.ownerName}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),

                  // Quick Action Button
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isMarketer && (camp.status == 'ChangesRequested' || camp.status == 'Draft'))
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CampaignWizardScreen(
                                    api: widget.api,
                                    existingCampaign: camp,
                                  ),
                                ),
                              ).then((_) => _fetch());
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.forge,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '+ Revise',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.leaf),
                              ),
                            ),
                          ),
                        ),
                      if (isReviewer && camp.status == 'Submitted')
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.verdictLime,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Review Now',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.forge),
                            ),
                          ),
                        ),
                      Text(
                        'Open dossier →',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.forge.withOpacity(0.9),
                        ),
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

  Widget _buildKpiPill(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  // KANBAN BOARD VIEW (Horizontal Columns per Governance Stage)
  Widget _buildKanbanView(List<Campaign> campaigns) {
    final columns = [
      {'status': 'Draft', 'title': 'DRAFT', 'color': AppTheme.textSecondary},
      {'status': 'Submitted', 'title': 'IN REVIEW', 'color': AppTheme.statusChanges},
      {'status': 'ChangesRequested', 'title': 'CHANGES', 'color': AppTheme.statusChanges},
      {'status': 'Approved', 'title': 'APPROVED', 'color': AppTheme.forge},
      {'status': 'Scheduled', 'title': 'SCHEDULED', 'color': const Color(0xFF1E3A8A)},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: columns.map((col) {
          final colStatus = col['status'] as String;
          final colTitle = col['title'] as String;
          final colColor = col['color'] as Color;
          final colCampaigns = campaigns.where((c) => c.status == colStatus).toList();

          return _buildKanbanColumn(
            title: colTitle,
            color: colColor,
            campaigns: colCampaigns,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKanbanColumn({
    required String title,
    required Color color,
    required List<Campaign> campaigns,
  }) {
    return Container(
      width: 275,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: AppTheme.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderSage, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Column Header Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.borderSage, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.leaf,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderSage),
                  ),
                  child: Text(
                    '${campaigns.length}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.forge),
                  ),
                ),
              ],
            ),
          ),

          // Column Cards List
          Container(
            constraints: const BoxConstraints(maxHeight: 520),
            child: campaigns.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No campaigns in $title',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(10),
                    itemCount: campaigns.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final camp = campaigns[idx];
                      return _buildCompactKanbanCard(camp);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactKanbanCard(Campaign camp) {
    final curVer = camp.currentVersion;
    final channel = curVer?.channel ?? 'Social';
    final channelMeta = _getChannelMeta(channel);
    final budgetFormatted = (curVer?.budget ?? 0).toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(14),
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
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Channel and Version
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: channelMeta['bg'] as Color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(channelMeta['icon'] as IconData, size: 10, color: channelMeta['color'] as Color),
                        const SizedBox(width: 3),
                        Text(
                          channel.toUpperCase(),
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: channelMeta['color'] as Color),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'v${curVer?.versionNo ?? 1}.0',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                camp.title,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Audience
              if (curVer?.targetAudience.isNotEmpty ?? false)
                Text(
                  '@ ${curVer!.targetAudience}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 10),

              // Budget and CTA
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\$$budgetFormatted',
                    style: const TextStyle(
                      fontFamily: 'serif',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.forge,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 10, color: AppTheme.textSecondary),
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
            const Icon(Icons.folder_open_outlined, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            const Text(
              'No Dossiers Found',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'No campaigns match the current criteria or stage filter.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            if (isMarketer) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CampaignWizardScreen(api: widget.api)),
                  ).then((_) => _fetch());
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create first proposal'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.forge,
                  foregroundColor: AppTheme.leaf,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getChannelMeta(String channel) {
    switch (channel.toLowerCase()) {
      case 'social':
        return {
          'icon': Icons.tag_rounded,
          'color': const Color(0xFFBE185D),
          'bg': const Color(0xFFFDF2F8),
        };
      case 'search':
        return {
          'icon': Icons.search_rounded,
          'color': AppTheme.forge,
          'bg': AppTheme.paper,
        };
      case 'email':
        return {
          'icon': Icons.mail_outline_rounded,
          'color': const Color(0xFF0369A1),
          'bg': const Color(0xFFF0F9FF),
        };
      case 'display':
        return {
          'icon': Icons.view_carousel_outlined,
          'color': const Color(0xFF6B21A8),
          'bg': const Color(0xFFFAF5FF),
        };
      case 'influencer':
        return {
          'icon': Icons.stars_outlined,
          'color': const Color(0xFFB45309),
          'bg': const Color(0xFFFFFBEB),
        };
      case 'video':
        return {
          'icon': Icons.play_circle_outline_rounded,
          'color': const Color(0xFFC2410C),
          'bg': const Color(0xFFFFF7ED),
        };
      default:
        return {
          'icon': Icons.campaign_outlined,
          'color': AppTheme.forge,
          'bg': AppTheme.paper,
        };
    }
  }

  Map<String, dynamic> _getStatusMeta(String status) {
    switch (status) {
      case 'Approved':
        return {
          'label': 'APPROVED & LOCKED',
          'bgColor': AppTheme.forge,
          'textColor': AppTheme.leaf,
          'borderColor': AppTheme.verdictLime,
          'icon': Icons.lock_outline_rounded,
        };
      case 'Scheduled':
        return {
          'label': 'SCHEDULED FLIGHT',
          'bgColor': AppTheme.forge.withOpacity(0.08),
          'textColor': AppTheme.forge,
          'borderColor': AppTheme.borderSage,
          'icon': Icons.calendar_month_outlined,
        };
      case 'Submitted':
        return {
          'label': 'IN REVIEW',
          'bgColor': AppTheme.statusChanges.withOpacity(0.12),
          'textColor': AppTheme.statusChanges,
          'borderColor': AppTheme.statusChanges.withOpacity(0.4),
          'icon': Icons.schedule_rounded,
        };
      case 'ChangesRequested':
        return {
          'label': 'CHANGES REQUIRED',
          'bgColor': AppTheme.statusChanges.withOpacity(0.14),
          'textColor': AppTheme.statusChanges,
          'borderColor': AppTheme.statusChanges,
          'icon': Icons.edit_note_rounded,
        };
      case 'Rejected':
        return {
          'label': 'REJECTED',
          'bgColor': AppTheme.statusRejected.withOpacity(0.12),
          'textColor': AppTheme.statusRejected,
          'borderColor': AppTheme.statusRejected,
          'icon': Icons.cancel_outlined,
        };
      case 'Draft':
      default:
        return {
          'label': 'DRAFT PROPOSAL',
          'bgColor': AppTheme.paper,
          'textColor': AppTheme.textSecondary,
          'borderColor': AppTheme.borderSage,
          'icon': Icons.edit_outlined,
        };
    }
  }
}
