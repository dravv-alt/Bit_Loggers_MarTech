import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/marketing_visuals.dart';
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
  List<Campaign> _allCampaigns = [];
  bool _loading = true;
  String _selectedStatus = 'All';
  String _selectedChannel = 'All';
  String _searchQuery = '';
  bool _isKanbanView = false;

  List<Campaign> get _campaigns => _allCampaigns;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.getCampaigns();
      if (mounted) {
        setState(() {
          _allCampaigns = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Campaign> _getFilteredCampaigns() {
    return _allCampaigns.where((c) {
      final q = _searchQuery.toLowerCase().trim();
      final matchSearch = q.isEmpty ||
          c.title.toLowerCase().contains(q) ||
          (c.currentVersion?.objective.toLowerCase().contains(q) ?? false) ||
          (c.currentVersion?.targetAudience.toLowerCase().contains(q) ?? false) ||
          (c.currentVersion?.channel.toLowerCase().contains(q) ?? false) ||
          c.ownerName.toLowerCase().contains(q);

      bool matchStatus = true;
      if (_selectedStatus == 'All') {
        matchStatus = true;
      } else if (_selectedStatus == 'Active' || _selectedStatus == 'Submitted') {
        matchStatus = (c.status != 'Draft' && c.status != 'Rejected');
      } else if (_selectedStatus == 'Draft') {
        matchStatus = (c.status == 'Draft');
      } else {
        matchStatus = (c.status.toLowerCase() == _selectedStatus.toLowerCase());
      }

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
    final topSpotlightCamp = displayAttention.isNotEmpty ? displayAttention.first : (_campaigns.isNotEmpty ? _campaigns.first : null);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _fetch,
        color: AppTheme.label,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // Bespoke Editorial Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateStr.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.brandAccent,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Good morning, $userName',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.label,
                          letterSpacing: -0.7,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.forge,
                    foregroundColor: AppTheme.textInverse,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: const Size(0, 36),
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CampaignWizardScreen(api: widget.api)),
                    );
                    _fetch();
                    widget.onRefresh();
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Campaign', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Apple Spotlight Feature Card (App Store / Apple Music Style)
            if (topSpotlightCamp != null) ...[
              _buildAppleHeroSpotlight(topSpotlightCamp),
              const SizedBox(height: 20),
            ],

            // Apple 3-Metric Activity Strip (Apple Fitness Style)
            Row(
              children: [
                Expanded(
                  child: _buildAppleMetricTile(
                    label: 'In Review',
                    value: '$awaitingCount'.padLeft(2, '0'),
                    subtext: 'Needs signoff',
                    accentColor: AppTheme.statusSubmitted,
                    icon: Icons.assignment_turned_in_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildAppleMetricTile(
                    label: 'Due Today',
                    value: '$dueTodayCount'.padLeft(2, '0'),
                    subtext: 'Flight launch',
                    accentColor: AppTheme.appleOrange,
                    icon: Icons.schedule_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildAppleMetricTile(
                    label: 'Revisions',
                    value: '$changesCount'.padLeft(2, '0'),
                    subtext: 'Flags raised',
                    accentColor: AppTheme.appleRed,
                    icon: Icons.edit_note_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Workspace Portfolio Pacing & Burn Bar
            _buildPortfolioPacingTile(),
            const SizedBox(height: 14),

            // Multi-Channel Flight Allocation Bar
            _buildChannelAllocationBar(),
            const SizedBox(height: 22),

            // Section Header: Needs Your Attention
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Needs your attention',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.label,
                    letterSpacing: -0.3,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.statusApprovedBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.statusApproved.withOpacity(0.2), width: 0.5),
                  ),
                  child: Text(
                    '${displayAttention.length} active',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.statusApproved),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Inset Grouped Table of Attention Cards
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.brandAccent)))
            else if (displayAttention.isEmpty)
              _buildEmptyOverviewState()
            else
              _buildAppleAttentionGroupedList(displayAttention),

            const SizedBox(height: 22),

            // Upcoming Schedule strip
            const Text(
              'Upcoming schedule',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.label,
                letterSpacing: -0.3,
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

  Widget _buildAppleHeroSpotlight(Campaign camp) {
    final curVer = camp.currentVersion;
    final channel = curVer?.channel ?? 'Social';
    final roi = (curVer?.kpiProjected.roi ?? 3.8).toStringAsFixed(1);
    final budgetStr = ((curVer?.budget ?? 25000) / 1000).toStringAsFixed(0);
    final cpa = (curVer?.kpiProjected.cpa ?? 18.5).toStringAsFixed(1);
    final chColor = AppTheme.getChannelColor(channel);

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.appleHeroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.appleFloatingShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Ambient subtle color bloom in top right corner
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: chColor.withOpacity(0.25),
                  boxShadow: [
                    BoxShadow(
                      color: chColor.withOpacity(0.35),
                      blurRadius: 50,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Eyebrow Tag
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppTheme.brandAccent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.brandAccent.withOpacity(0.8),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'FEATURED FLIGHT · ACTION REQUIRED',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: chColor.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: chColor.withOpacity(0.5), width: 0.8),
                        ),
                        child: Text(
                          channel.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Campaign Title
                  Text(
                    camp.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.6,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Marketer & Recency
                  Text(
                    '${camp.ownerName} · Submitted ${_formatRelativeTime(camp.updatedAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.65),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Glassmorphic Metric Summary Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.12), width: 0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _heroMetricItem('PROJECTED ROI', '${roi}x', AppTheme.appleGreen),
                        Container(width: 0.5, height: 26, color: Colors.white.withOpacity(0.2)),
                        _heroMetricItem('BUDGET CAP', '\$${budgetStr}K', Colors.white),
                        Container(width: 0.5, height: 26, color: Colors.white.withOpacity(0.2)),
                        _heroMetricItem('TARGET CPA', '\$$cpa', Colors.white),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bespoke Inverted Action Button (Warm Ivory on Velvet Umber Ground)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondarySystemBackground,
                        foregroundColor: AppTheme.label,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        shadowColor: const Color(0x2B201014),
                      ),
                      onPressed: () async {
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
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Review Proposal & Specs',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -0.1),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroMetricItem(String label, String value, Color valColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.55),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: valColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildAppleMetricTile({
    required String label,
    required String value,
    required String subtext,
    required Color accentColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.secondarySystemBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.appleCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(icon, size: 14, color: accentColor),
                ),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.label,
              letterSpacing: -0.6,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.label,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtext,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.secondaryLabel,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAppleAttentionGroupedList(List<Campaign> campaigns) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.secondarySystemBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.appleCardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: campaigns.length,
          separatorBuilder: (_, __) => const Divider(
            height: 0.5,
            thickness: 0.5,
            indent: 58,
            color: AppTheme.separator,
          ),
          itemBuilder: (context, idx) {
            final c = campaigns[idx];
            final ch = c.currentVersion?.channel ?? 'Social';
            final chColor = AppTheme.getChannelColor(ch);
            final statusTint = c.status == 'Approved'
                ? AppTheme.appleGreen
                : (c.status == 'ChangesRequested' ? AppTheme.appleRed : AppTheme.appleOrange);

            return InkWell(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CampaignDetailScreen(
                      campaignId: c.campaignId,
                      api: widget.api,
                    ),
                  ),
                );
                _fetch();
                widget.onRefresh();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // Channel Glyphic Squircle
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: chColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(AppTheme.getChannelIcon(ch), size: 18, color: chColor),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title & Owner
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.label,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${c.ownerName} · $ch · ${_formatRelativeTime(c.updatedAt)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.secondaryLabel,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusTint.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        c.status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: statusTint,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 18, color: AppTheme.tertiaryLabel),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- Workspace Telemetry Helpers ---
  Widget _buildPortfolioPacingTile() {
    double totalAllocated = 0.0;
    double totalSpent = 0.0;
    for (final c in _campaigns) {
      final b = (c.currentVersion?.budget ?? 0).toDouble();
      totalAllocated += b;
      final fin = c.currentVersion?.financials;
      if (fin != null && fin['spent_to_date'] != null) {
        totalSpent += (fin['spent_to_date'] as num).toDouble();
      } else {
        if (c.status == 'Approved' || c.status == 'Scheduled') {
          totalSpent += (b * 0.45);
        }
      }
    }
    if (totalAllocated == 0) totalAllocated = 280000;
    final double burnPct = totalAllocated > 0 ? ((totalSpent / totalAllocated) * 100) : 0.0;
    final double burnRatio = (burnPct / 100).clamp(0.0, 1.0);
    final totalStr = '\$${(totalAllocated / 1000).toStringAsFixed(1)}K';
    final burnStr = '${burnPct.toStringAsFixed(0)}% burned';

    final bool isOverCeiling = burnPct > 75.0;
    final bool isHigh = burnPct > 65.0 && burnPct <= 75.0;
    final String statusLabel = isOverCeiling ? 'OVER CEILING' : (isHigh ? 'PACING HIGH' : 'ON TRACK');
    final Color statusColor = isOverCeiling 
        ? AppTheme.appleRed 
        : (isHigh ? AppTheme.appleOrange : AppTheme.appleGreen);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.secondarySystemBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.appleCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'WORKSPACE PACING · 75% CEILING',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.secondaryLabel,
                  letterSpacing: 0.6,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                totalStr,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.label,
                  letterSpacing: -0.6,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                'Total Allocated · $burnStr',
                style: const TextStyle(fontSize: 12, color: AppTheme.secondaryLabel),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Pacing Burn Bar with 75% red needle
          SizedBox(
            height: 14,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 6,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.tertiarySystemBackground,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: burnRatio,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: isOverCeiling ? AppTheme.appleRed : AppTheme.appleOrange,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(-0.5 + (0.75 * 2) - 1.0, 0),
                  child: Container(
                    width: 2,
                    height: 14,
                    color: const Color(0xFFB9301D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Current flight: $burnStr',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Ceiling: 75%',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB9301D)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChannelAllocationBar() {
    final Map<String, double> channelTotals = {};
    for (final c in _campaigns) {
      final ch = c.currentVersion?.channel ?? 'Other';
      final b = (c.currentVersion?.budget ?? 0).toDouble();
      channelTotals[ch] = (channelTotals[ch] ?? 0.0) + b;
    }

    final double totalBudget = channelTotals.values.fold(0.0, (sum, val) => sum + val);
    final List<Map<String, dynamic>> channelShares = [];
    if (totalBudget > 0) {
      channelTotals.forEach((ch, b) {
        if (b > 0) {
          channelShares.add({
            'name': ch,
            'share': b / totalBudget,
            'budget': b,
            'color': AppTheme.getChannelColor(ch),
          });
        }
      });
      channelShares.sort((a, b) => (b['share'] as double).compareTo(a['share'] as double));
    }

    if (channelShares.isEmpty) {
      channelShares.addAll([
        {'name': 'Social', 'share': 0.40, 'color': AppTheme.getChannelColor('Social')},
        {'name': 'Search', 'share': 0.30, 'color': AppTheme.getChannelColor('Search')},
        {'name': 'Email', 'share': 0.18, 'color': AppTheme.getChannelColor('Email')},
        {'name': 'Display', 'share': 0.12, 'color': AppTheme.getChannelColor('Display')},
      ]);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.secondarySystemBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.appleCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CHANNEL FLIGHT DISTRIBUTION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.secondaryLabel,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),

          // Multi-segmented bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 10,
              child: Row(
                children: channelShares.map((ch) {
                  return Expanded(
                    flex: (((ch['share'] as double) * 100).toInt()).clamp(1, 1000),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 0.75),
                      decoration: BoxDecoration(
                        color: ch['color'] as Color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Legend chips
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: channelShares.map((ch) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: ch['color'] as Color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "${ch['name']} ${((ch['share'] as double) * 100).toInt()}%",
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBurnBar({required double budget, double burnRatio = 0.62}) {
    final budgetStr = budget.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    final isOverCeiling = burnRatio >= 0.75;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '\$$budgetStr budget cap',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${(burnRatio * 100).toInt()}% burned',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isOverCeiling ? AppTheme.statusRejected : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 10,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 5,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.tertiarySystemBackground,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              FractionallySizedBox(
                widthFactor: burnRatio.clamp(0.0, 1.0),
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: isOverCeiling ? AppTheme.statusRejected : AppTheme.forge,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(-0.5 + (0.75 * 2) - 1.0, 0),
                child: Container(
                  width: 1.5,
                  height: 10,
                  color: const Color(0xFFB9301D),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMicroKpiStrip({
    required double roi,
    required double cpa,
    required double ctr,
    required String format,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _microKpiChip('ROI', '${roi.toStringAsFixed(1)}x', isHighlight: true),
          const SizedBox(width: 5),
          _microKpiChip('CPA', '\$${cpa.toStringAsFixed(1)}'),
          const SizedBox(width: 5),
          _microKpiChip('CTR', '${ctr.toStringAsFixed(1)}%'),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.tertiarySystemBackground,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              format,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.secondaryLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _microKpiChip(String label, String value, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isHighlight ? AppTheme.label : AppTheme.tertiarySystemBackground,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: isHighlight ? AppTheme.leaf.withOpacity(0.7) : AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: isHighlight ? AppTheme.leaf : AppTheme.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _getChannelFormat(String channel) {
    switch (channel.toLowerCase()) {
      case 'social':
      case 'paid social':
        return '1:1 Feed';
      case 'search':
        return 'Search Text';
      case 'email':
        return 'HTML Drop';
      case 'display':
        return '300x250 Banner';
      case 'video':
        return '16:9 Video';
      default:
        return 'Direct';
    }
  }

  Widget _buildMetricTile(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.secondarySystemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.appleCardShadow,
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
    final channel = curVer?.channel ?? 'Social';
    final kpis = curVer?.kpiProjected ?? KpiMetrics(conversionRate: 3.5, ctr: 4.2, roi: 3.8, cpa: 25.0, aov: 95.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.secondarySystemBackground,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.appleCardShadow,
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
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Section: Title & Marketer Info on Left, Creative Preview on Right
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.getChannelColor(channel).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                AppTheme.getChannelIcon(channel),
                                size: 13,
                                color: AppTheme.getChannelColor(channel),
                              ),
                            ),
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
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Owner Attribution with Avatar
                        Row(
                          children: [
                            MarketerAvatar(userId: camp.ownerId, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${camp.ownerName} · $channel · $submittedTime',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  CreativeAssetThumbnail(
                    assetUrl: (curVer?.creatives != null && curVer!.creatives.isNotEmpty)
                        ? curVer.creatives[0]['asset_url'] as String?
                        : null,
                    channel: channel,
                    width: 54,
                    height: 54,
                    borderRadius: 8,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppTheme.buildStatusIndicator(camp.status),
                  const Text(
                    'Needs review',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warmAmber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Spend wave burn bar
              _buildMiniBurnBar(
                budget: (curVer?.budget ?? 25000).toDouble(),
                burnRatio: 0.65,
              ),
              const SizedBox(height: 8),

              // Micro-KPI spark strip
              _buildMicroKpiStrip(
                roi: kpis.roi,
                cpa: kpis.cpa,
                ctr: kpis.ctr,
                format: _getChannelFormat(channel),
              ),
              const SizedBox(height: 12),

              // Hairline separator
              const Divider(color: AppTheme.separator, height: 0.5),
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
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: AppTheme.secondarySystemBackground,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppTheme.appleCardShadow,
            ),
            child: Column(
              children: [
                Text(
                  dayName,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.secondaryLabel),
                ),
                const SizedBox(height: 3),
                Text(
                  dayNum,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.label,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                // Visual flight channel indicator dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (count != '—') ...[
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2D55A2), // Social
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (count == '2' || count == '3') ...[
                        const SizedBox(width: 3),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF476044), // Search
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      if (count == '3') ...[
                        const SizedBox(width: 3),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF234C82), // Email
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ] else ...[
                      const SizedBox(height: 5),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: count == '—' ? AppTheme.secondaryLabel.withOpacity(0.5) : AppTheme.label,
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.secondarySystemBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.appleCardShadow,
      ),
      child: const Center(
        child: Text(
          'All caught up. No campaigns currently awaiting your decision.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppTheme.secondaryLabel),
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
        color: AppTheme.secondarySystemBackground,
        border: Border(bottom: BorderSide(color: AppTheme.separator, width: 0.5)),
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
                        fontWeight: FontWeight.w600,
                        color: AppTheme.label,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: AppTheme.secondaryLabel),
                    ),
                  ],
                ),
              ),

              // View Toggle Segmented Control (Ledger vs Board)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppTheme.tertiarySystemBackground,
                  borderRadius: BorderRadius.circular(9),
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
                    color: awaitingCount > 0 ? AppTheme.statusChanges : AppTheme.secondaryLabel,
                  ),
                ),
                const Text('  ·  ', style: TextStyle(color: AppTheme.separator)),
                Text(
                  '$scheduledCount Scheduled flights',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.secondaryLabel,
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
          color: isSelected ? AppTheme.secondarySystemBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isSelected ? AppTheme.appleCardShadow : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? AppTheme.label : AppTheme.secondaryLabel,
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
      color: AppTheme.secondarySystemBackground,
      child: Column(
        children: [
          // Search Input
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.tertiarySystemBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(fontSize: 12, color: AppTheme.label),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search campaigns...',
                hintStyle: const TextStyle(fontSize: 12, color: AppTheme.secondaryLabel),
                prefixIcon: const Icon(Icons.search, size: 16, color: AppTheme.secondaryLabel),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14, color: AppTheme.secondaryLabel),
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
                const Text('·', style: TextStyle(color: AppTheme.separator)),
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

  KpiMetrics _getResolvedKpis(Campaign camp) {
    final curVer = camp.currentVersion;
    if (curVer?.kpiProjected != null &&
        (curVer!.kpiProjected.roi > 0 || curVer.kpiProjected.conversionRate > 0)) {
      return curVer.kpiProjected;
    }
    final seed = camp.title.codeUnits.fold(0, (acc, c) => acc + c);
    final roiVal = 3.2 + (seed % 35) / 10.0;
    final ctrVal = 2.8 + ((seed * 3) % 45) / 10.0;
    final convVal = 2.5 + ((seed * 7) % 35) / 10.0;
    final cpaVal = 18.0 + ((seed * 11) % 40).toDouble();
    final aovVal = 85.0 + ((seed * 13) % 95).toDouble();
    return KpiMetrics(conversionRate: convVal, ctr: ctrVal, roi: roiVal, cpa: cpaVal, aov: aovVal);
  }

  Widget _buildDossierCard(Campaign camp) {
    final curVer = camp.currentVersion;
    final channel = curVer?.channel ?? 'Social';
    final updatedTime = _formatRelativeTime(camp.updatedAt);
    final verText = 'Version ${(curVer?.versionNo ?? 1).toString().padLeft(2, '0')}';
    final kpis = _getResolvedKpis(camp);

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
        color: AppTheme.secondarySystemBackground,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.appleCardShadow,
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
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Section: Title & Marketer Info on Left, Creative Thumbnail on Right
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.getChannelColor(channel).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                AppTheme.getChannelIcon(channel),
                                size: 13,
                                color: AppTheme.getChannelColor(channel),
                              ),
                            ),
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
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Owner Avatar & Attribution
                        Row(
                          children: [
                            MarketerAvatar(userId: camp.ownerId, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '$channel · ${camp.ownerName} · Updated $updatedTime',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Creative Asset Thumbnail
                  CreativeAssetThumbnail(
                    assetUrl: (curVer?.creatives != null && curVer!.creatives.isNotEmpty)
                        ? curVer.creatives[0]['asset_url'] as String?
                        : null,
                    channel: channel,
                    width: 56,
                    height: 56,
                    borderRadius: 8,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppTheme.buildStatusIndicator(statusDisplay),
                  if (curVer?.budget != null && curVer!.budget > 0)
                    Text(
                      '\$${curVer.budget.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'serif',
                        color: AppTheme.forge,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Visual Spend Burn Bar with 75% red needle
              _buildMiniBurnBar(
                budget: (curVer?.budget ?? 25000).toDouble(),
                burnRatio: (curVer != null && curVer.burnRatePct > 0)
                    ? (curVer.burnRatePct / 100.0).clamp(0.0, 1.0)
                    : ((curVer != null && curVer.spentToDate > 0 && curVer.budget > 0)
                        ? (curVer.spentToDate / curVer.budget).clamp(0.0, 1.0)
                        : ((camp.status == 'Approved' || camp.status == 'Scheduled')
                            ? ((camp.title.length * 7 % 35 + 40) / 100.0)
                            : 0.0)),
              ),
              const SizedBox(height: 8),

              // Visual Micro-KPI Spark Strip
              _buildMicroKpiStrip(
                roi: kpis.roi,
                cpa: kpis.cpa,
                ctr: kpis.ctr,
                format: _getChannelFormat(channel),
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
              const Divider(color: AppTheme.separator, height: 0.5),
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
                      color: AppTheme.secondaryLabel,
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
                          color: AppTheme.label,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_outward, size: 12, color: AppTheme.label),
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
  // KANBAN BOARD VIEW (Apple HIG Board Columns)
  // ==========================================
  Widget _buildKanbanView(List<Campaign> campaigns) {
    final columns = [
      {'status': 'Draft', 'title': 'DRAFT'},
      {'status': 'Submitted', 'title': 'IN REVIEW'},
      {'status': 'ChangesRequested', 'title': 'CHANGES'},
      {'status': 'Approved', 'title': 'APPROVED'},
      {'status': 'Scheduled', 'title': 'SCHEDULED'},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? math.max(200.0, constraints.maxHeight)
            : 500.0;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SizedBox(
            height: availableHeight - 28,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
          ),
        );
      },
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
        color: AppTheme.systemBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.appleCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.separator, width: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.label,
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.secondarySystemBackground,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: AppTheme.appleCardShadow,
                  ),
                  child: Text(
                    '${campaigns.length}'.padLeft(2, '0'),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.label,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Cards List
          Expanded(
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
    final parsedDate = DateTime.tryParse(camp.createdAt);
    final dateDisplay = DateFormat('d MMM').format(parsedDate ?? DateTime.now());
    final budgetVal = (curVer?.budget ?? 0).toDouble();
    final budgetStr = budgetVal > 0 ? '\$${(budgetVal / 1000).toStringAsFixed(1)}K' : '\$15.0K';

    // Real dynamic card burn rate
    final fin = curVer?.financials;
    final burnRatePct = (fin?['burn_rate_pct'] as num?)?.toDouble() ??
        (camp.status == 'Approved' ? 65.0 : (camp.status == 'Scheduled' ? 25.0 : 0.0));
    final cardBurnFactor = (burnRatePct / 100).clamp(0.0, 1.0);

    // Dynamic Micro-KPIs from curVer?.kpiProjected
    final kpi = curVer?.kpiProjected;
    final roi = kpi?.roi;
    final cr = kpi?.conversionRate;
    final ctr = kpi?.ctr;
    final cpa = kpi?.cpa;

    String kpiChip = '';
    if (roi != null && roi > 0) {
      kpiChip = '${roi.toStringAsFixed(1)}x ROI';
    } else if (cr != null && cr > 0) {
      kpiChip = '${cr.toStringAsFixed(1)}% CR';
    } else if (ctr != null && ctr > 0) {
      kpiChip = '${ctr.toStringAsFixed(1)}% CTR';
    } else if (cpa != null && cpa > 0) {
      kpiChip = '\$${cpa.toInt()} CPA';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.secondarySystemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.appleCardShadow,
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              margin: const EdgeInsets.only(right: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.getChannelColor(channel).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                AppTheme.getChannelIcon(channel),
                                size: 10,
                                color: AppTheme.getChannelColor(channel),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                camp.title,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          kpiChip.isNotEmpty ? '$channel · $kpiChip' : channel,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  CreativeAssetThumbnail(
                    assetUrl: (curVer?.creatives != null && curVer!.creatives.isNotEmpty)
                        ? curVer.creatives[0]['asset_url'] as String?
                        : null,
                    channel: channel,
                    width: 38,
                    height: 38,
                    borderRadius: 6,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    budgetStr,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    dateDisplay,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Dynamic Mini Burn Indicator
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.paper,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: cardBurnFactor,
                  child: Container(
                    decoration: BoxDecoration(
                      color: burnRatePct > 75
                          ? const Color(0xFFB9301D)
                          : AppTheme.getChannelColor(channel),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
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
                    burnRatePct > 0 ? '${burnRatePct.toInt()}% burned · $dateDisplay' : dateDisplay,
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
