import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/models.dart';
import 'v3_components.dart';
import 'v3_tokens.dart';

class _PipelineColumnDef {
  final String id;
  final String title;
  final String dotColor;

  const _PipelineColumnDef(this.id, this.title, this.dotColor);
}

class V3PipelineView extends StatefulWidget {
  final List<Campaign> campaigns;
  final User currentUser;
  final V3Palette palette;
  final String initialViewMode;
  final void Function(String campaignId, {String initialTab}) onInspectCampaign;
  final ValueChanged<Campaign> onEditCampaign;
  final ValueChanged<String> onSubmitCampaign;

  const V3PipelineView({
    super.key,
    required this.campaigns,
    required this.currentUser,
    required this.palette,
    this.initialViewMode = 'board',
    required this.onInspectCampaign,
    required this.onEditCampaign,
    required this.onSubmitCampaign,
  });

  @override
  State<V3PipelineView> createState() => _V3PipelineViewState();
}

class _V3PipelineViewState extends State<V3PipelineView> {
  static const _columns = [
    _PipelineColumnDef('Draft', 'Drafts', 'indigo'),
    _PipelineColumnDef('Submitted', 'Awaiting review', 'yellow'),
    _PipelineColumnDef('ChangesRequested', 'Changes requested', 'yellow'),
    _PipelineColumnDef('Approved', 'Approved', 'green'),
    _PipelineColumnDef('Scheduled', 'Scheduled', 'green'),
    _PipelineColumnDef('Rejected', 'Rejected', 'rose'),
  ];

  static const _channels = ['All', 'Social', 'Search', 'Email', 'Display', 'Video', 'Influencer'];
  static const _pageSize = 6;

  String _searchQuery = '';
  String _channelFilter = 'All';
  String _stageFilter = 'All';
  late String _viewMode; // 'board' | 'table'
  String _sortBy = 'updated'; // 'title' | 'budget' | 'roi' | 'updated'
  bool _sortAsc = false;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.initialViewMode == 'table' ? 'table' : 'board';
  }

  List<Campaign> get _filtered {
    final q = _searchQuery.trim().toLowerCase();
    final matched = widget.campaigns.where((c) {
      final matchesQ = q.isEmpty ||
          c.title.toLowerCase().contains(q) ||
          (c.currentVersion?.objective ?? '').toLowerCase().contains(q) ||
          c.ownerName.toLowerCase().contains(q) ||
          c.ownerId.toLowerCase().contains(q);
      final ch = c.currentVersion?.channel ?? 'Social';
      final matchesCh =
          _channelFilter == 'All' || ch.toLowerCase() == _channelFilter.toLowerCase();
      final matchesStage = _stageFilter == 'All' ||
          (_stageFilter == 'Draft'
              ? (c.status == 'Draft' || c.status == 'Revised')
              : c.status == _stageFilter);
      return matchesQ && matchesCh && matchesStage;
    }).toList();

    matched.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'title':
          cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case 'budget':
          cmp = (a.currentVersion?.budget ?? 0).compareTo(b.currentVersion?.budget ?? 0);
          break;
        case 'roi':
          cmp = (a.currentVersion?.kpiProjected.roi ?? 0)
              .compareTo(b.currentVersion?.kpiProjected.roi ?? 0);
          break;
        default:
          cmp = a.updatedAt.compareTo(b.updatedAt);
          break;
      }
      return _sortAsc ? cmp : -cmp;
    });
    return matched;
  }

  void _toggleSort(String col) {
    setState(() {
      if (_sortBy == col) {
        _sortAsc = !_sortAsc;
      } else {
        _sortBy = col;
        _sortAsc = col == 'title';
      }
      _page = 1;
    });
  }

  String _ownerLabel(String ownerId) {
    if (ownerId.contains('reviewer')) return 'Marcus Vance';
    if (ownerId.contains('admin')) return 'Maya Lin';
    return 'Alice Cooper';
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final list = _filtered;

    final totalBudget = widget.campaigns.fold<double>(
      0,
      (s, c) => s + (c.currentVersion?.budget ?? 0.0),
    );
    final reviewCount = widget.campaigns.where((c) => c.status == 'Submitted').length;
    final approvedOrLive =
        widget.campaigns.where((c) => c.status == 'Approved' || c.status == 'Scheduled').length;
    final rois = widget.campaigns
        .map((c) => c.currentVersion?.kpiProjected.roi ?? 0.0)
        .where((r) => r > 0)
        .toList();
    final avgRoi = rois.isEmpty ? 4.6 : rois.reduce((a, b) => a + b) / rois.length;

    final stats = [
      V3StatItem(
        icon: Icons.monetization_on_rounded,
        label: 'Committed pipeline',
        value: V3Tokens.formatMoney(totalBudget),
        delta: '+12.4%',
        deltaTone: 'lime',
        tileTone: 'blue',
        caption: '${widget.campaigns.length} active proposals',
        hint: 'Sum of current-version campaign budgets across all pipeline stages.',
      ),
      V3StatItem(
        icon: Icons.schedule_rounded,
        label: 'Awaiting review',
        value: '$reviewCount',
        delta: reviewCount > 0 ? 'Needs signoff' : 'Clear',
        deltaTone: reviewCount > 0 ? 'neutral' : 'lime',
        tileTone: 'orange',
        caption: '24h review SLA',
        hint: 'Proposals locked to a submitted version waiting for reviewer signoff.',
      ),
      V3StatItem(
        icon: Icons.check_circle_outline_rounded,
        label: 'Approved & live',
        value: '$approvedOrLive',
        delta: '${((approvedOrLive / math.max(1, widget.campaigns.length)) * 100).round()}% ready',
        deltaTone: 'lime',
        tileTone: 'emerald',
        caption: 'Flight ready',
        hint: 'Approved briefs ready for calendar scheduling or already live.',
      ),
      V3StatItem(
        icon: Icons.auto_awesome_rounded,
        label: 'Blended ROI target',
        value: '${avgRoi.toStringAsFixed(1)}x',
        delta: '+0.4x',
        deltaTone: 'lime',
        tileTone: 'purple',
        caption: 'Projected return',
        hint: 'Weighted projected return across current proposal versions.',
      ),
    ];

    final totalPages = math.max(1, (list.length / _pageSize).ceil());
    final safePage = _page.clamp(1, totalPages);
    final pagedRows = list.skip((safePage - 1) * _pageSize).take(_pageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        V3StatCardGrid(stats: stats, palette: p, footerVariant: true),
        const SizedBox(height: 16),

        // Toolbar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.bgSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.borderDefault, width: 1),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 780;
              final filters = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: wide ? 240 : math.min(constraints.maxWidth, 340),
                    height: 36,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: p.bgTertiary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: p.borderDefault),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, size: 16, color: p.iconSecondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              style: V3Tokens.bodyMedium(p),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: 'Search briefs, owners, objectives…',
                                hintStyle: V3Tokens.bodyRegular(p, color: p.textTertiary),
                              ),
                              onChanged: (v) => setState(() {
                                _searchQuery = v;
                                _page = 1;
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildFilterMenu<String>(
                    p: p,
                    value: _channelFilter,
                    display: _channelFilter == 'All' ? 'All channels' : _channelFilter,
                    items: _channels
                        .map((c) => (id: c, label: c == 'All' ? 'All channels' : c))
                        .toList(),
                    onSelected: (v) => setState(() {
                      _channelFilter = v;
                      _page = 1;
                    }),
                  ),
                  _buildFilterMenu<String>(
                    p: p,
                    value: _stageFilter,
                    display: _stageFilter == 'All'
                        ? 'All stages'
                        : _columns.firstWhere((c) => c.id == _stageFilter).title,
                    items: [
                      (id: 'All', label: 'All stages'),
                      ..._columns.map((c) => (id: c.id, label: c.title)),
                    ],
                    onSelected: (v) => setState(() {
                      _stageFilter = v;
                      _page = 1;
                    }),
                  ),
                ],
              );

              final rightControls = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (wide) ...[
                    Text(
                      '${list.length} matching',
                      style: V3Tokens.bodyMedium(p, color: p.textSecondary),
                    ),
                    const SizedBox(width: 12),
                  ],
                  V3SegmentedControl<String>(
                    palette: p,
                    selected: _viewMode,
                    options: const [
                      V3SegmentedOption(
                        id: 'board',
                        label: 'Board',
                        icon: Icons.view_kanban_outlined,
                      ),
                      V3SegmentedOption(
                        id: 'table',
                        label: 'Table',
                        icon: Icons.table_rows_outlined,
                      ),
                    ],
                    onSelect: (m) => setState(() => _viewMode = m),
                  ),
                ],
              );

              if (wide) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Expanded(child: filters), rightControls],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [filters, const SizedBox(height: 10), rightControls],
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Board vs Table
        if (_viewMode == 'board')
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final cols = w >= 900 ? 3 : (w >= 600 ? 2 : 1);
              const gap = 14.0;
              final colW = (w - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: _columns.map((col) {
                  final items = list
                      .where((c) => col.id == 'Draft'
                          ? (c.status == 'Draft' || c.status == 'Revised')
                          : c.status == col.id)
                      .toList();
                  return SizedBox(
                    width: colW,
                    child: _buildKanbanColumn(p, col, items),
                  );
                }).toList(),
              );
            },
          )
        else
          _buildTable(p, pagedRows, list.length, safePage, totalPages),
      ],
    );
  }

  Widget _buildFilterMenu<T>({
    required V3Palette p,
    required T value,
    required String display,
    required List<({T id, String label})> items,
    required ValueChanged<T> onSelected,
  }) {
    return PopupMenuButton<T>(
      color: p.bgPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.borderDefault),
      ),
      onSelected: onSelected,
      itemBuilder: (_) => items
          .map(
            (it) => PopupMenuItem<T>(
              value: it.id,
              child: Text(
                it.label,
                style: V3Tokens.bodyMedium(
                  p,
                  color: it.id == value ? p.accentText : p.textPrimary,
                ),
              ),
            ),
          )
          .toList(),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: p.bgPrimary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.borderDefault),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(display, style: V3Tokens.bodyMedium(p)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: p.iconSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildKanbanColumn(V3Palette p, _PipelineColumnDef col, List<Campaign> items) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.bgSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.borderDefault, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 2, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    V3StatusDot(colorKey: col.dotColor, palette: p),
                    const SizedBox(width: 8),
                    Text(col.title, style: V3Tokens.bodyMedium(p)),
                  ],
                ),
                V3Badge(label: '${items.length}', palette: p),
              ],
            ),
          ),
          if (items.isEmpty)
            V3DashedBox(
              palette: p,
              minHeight: 118,
              padding: const EdgeInsets.all(14),
              borderRadius: 14,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.grid_view_outlined, size: 20, color: p.iconTertiary),
                  const SizedBox(height: 6),
                  Text(
                    'No proposals in ${col.title.toLowerCase()}',
                    textAlign: TextAlign.center,
                    style: V3Tokens.bodyMedium(p, color: p.textTertiary),
                  ),
                ],
              ),
            )
          else
            ...items.map((camp) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildCampaignCard(p, camp),
                )),
        ],
      ),
    );
  }

  Widget _buildCampaignCard(V3Palette p, Campaign camp) {
    final ver = camp.currentVersion;
    final roi = ver?.kpiProjected.roi ?? 4.2;
    final cpa = ver?.kpiProjected.cpa ?? 22.0;
    final canEdit = widget.currentUser.id == camp.ownerId || widget.currentUser.role == 'admin';
    final lockedByOther =
        camp.activeLock != null && camp.activeLock!.holderId != widget.currentUser.id;

    final ownerDisplay = V3Tokens.cleanPersonName(
      camp.ownerName.isNotEmpty ? camp.ownerName : _ownerLabel(camp.ownerId),
    );

    return V3HoverCard(
      palette: p,
      onTap: () => widget.onInspectCampaign(camp.campaignId),
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      builder: (hovered) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  V3Chip(
                    label: ver?.channel ?? 'Social',
                    tone: V3Tokens.channelChipTone(ver?.channel ?? 'Social'),
                    palette: p,
                  ),
                  const SizedBox(width: 6),
                  V3Badge(label: 'v${ver?.versionNo ?? 1}', palette: p),
                ],
              ),
              if (lockedByOther)
                V3Chip(
                  label: 'Editing',
                  tone: 'orange',
                  palette: p,
                  leadingIcon: Icons.lock_outline_rounded,
                )
              else
                Text(
                  V3Tokens.formatRelativeTime(camp.updatedAt),
                  style: V3Tokens.caption(p, color: p.textTertiary),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            camp.title,
            style: V3Tokens.headline(p).copyWith(
              color: hovered ? p.accentText : p.textPrimary,
            ),
          ),
            const SizedBox(height: 4),
            Text(
              ver?.objective.isNotEmpty == true ? ver!.objective : 'No objective recorded yet.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: V3Tokens.bodyRegular(p),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: p.bgSecondary,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  Expanded(child: _kpiCol(p, 'Budget', V3Tokens.formatMoney(ver?.budget ?? 0.0))),
                  Expanded(child: _kpiCol(p, 'Est. ROI', '${roi.toStringAsFixed(1)}x')),
                  Expanded(child: _kpiCol(p, 'CPA cap', '\$${cpa.toStringAsFixed(0)}')),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: p.separator, width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(ownerDisplay, style: V3Tokens.caption(p)),
                  Wrap(
                    spacing: 6,
                    children: [
                      if ((camp.status == 'Draft' || camp.status == 'ChangesRequested') &&
                          canEdit) ...[
                        V3Button(
                          label: 'Edit',
                          icon: Icons.edit_outlined,
                          small: true,
                          palette: p,
                          onTap: () => widget.onEditCampaign(camp),
                        ),
                        V3Button(
                          label: 'Submit',
                          icon: Icons.send_outlined,
                          small: true,
                          variant: V3ButtonVariant.primary,
                          palette: p,
                          onTap: () => widget.onSubmitCampaign(camp.campaignId),
                        ),
                      ] else if (camp.status == 'Submitted' &&
                          widget.currentUser.role != 'marketer')
                        V3Button(
                          label: 'Review',
                          icon: Icons.check_circle_outline_rounded,
                          small: true,
                          variant: V3ButtonVariant.primary,
                          palette: p,
                          onTap: () => widget.onInspectCampaign(camp.campaignId, initialTab: 'review'),
                        )
                      else if (camp.status == 'Approved' && canEdit)
                        V3Button(
                          label: 'Schedule',
                          icon: Icons.calendar_today_outlined,
                          small: true,
                          variant: V3ButtonVariant.primary,
                          palette: p,
                          onTap: () =>
                              widget.onInspectCampaign(camp.campaignId, initialTab: 'schedule'),
                        )
                      else if (camp.status == 'Scheduled')
                        V3Button(
                          label: 'Flight live',
                          icon: Icons.event_available_outlined,
                          small: true,
                          palette: p,
                          onTap: () => widget.onInspectCampaign(camp.campaignId),
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

  Widget _kpiCol(V3Palette p, String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: V3Tokens.caption(p, color: p.textTertiary)),
        const SizedBox(height: 2),
        Text(val, style: V3Tokens.bodyMedium(p)),
      ],
    );
  }

  Widget _buildTable(
    V3Palette p,
    List<Campaign> rows,
    int totalItems,
    int currentPage,
    int totalPages,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.bgPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: math.max(constraints.maxWidth, 880)),
                child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.4),
                  1: FixedColumnWidth(100),
                  2: FixedColumnWidth(148),
                  3: FixedColumnWidth(80),
                  4: FixedColumnWidth(105),
                  5: FixedColumnWidth(78),
                  6: FixedColumnWidth(86),
                  7: FixedColumnWidth(104),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      color: p.bgSecondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    children: [
                      _sortHeader(p, 'Campaign', sortKey: 'title'),
                      _sortHeader(p, 'Channel'),
                      _sortHeader(p, 'Stage'),
                      _sortHeader(p, 'Version'),
                      _sortHeader(p, 'Budget', sortKey: 'budget'),
                      _sortHeader(p, 'ROI', sortKey: 'roi'),
                      _sortHeader(p, 'Updated', sortKey: 'updated'),
                      _sortHeader(p, 'Action'),
                    ],
                  ),
                  ...rows.map((camp) {
                    return TableRow(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: p.separator, width: 1)),
                      ),
                      children: [
                        InkWell(
                          onTap: () => widget.onInspectCampaign(camp.campaignId),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: p.bgSecondary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.campaign_rounded, size: 16, color: p.iconSecondary),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(camp.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: V3Tokens.bodyMedium(p)),
                                      Text(
                                        V3Tokens.cleanPersonName(
                                          camp.ownerName.isNotEmpty
                                              ? camp.ownerName
                                              : _ownerLabel(camp.ownerId),
                                        ),
                                        style: V3Tokens.caption(p),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: V3Chip(
                              label: camp.currentVersion?.channel ?? 'Social',
                              tone: V3Tokens.channelChipTone(camp.currentVersion?.channel ?? 'Social'),
                              palette: p,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: V3Chip(
                              label: V3Tokens.statusLabel(camp.status),
                              tone: V3Tokens.statusChipTone(camp.status),
                              palette: p,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: V3Badge(
                              label: 'v${camp.currentVersion?.versionNo ?? 1}',
                              palette: p,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            V3Tokens.formatMoney(camp.currentVersion?.budget ?? 0.0),
                            style: V3Tokens.bodyMedium(p),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '${(camp.currentVersion?.kpiProjected.roi ?? 4.2).toStringAsFixed(1)}x',
                            style: V3Tokens.bodyMedium(p),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            V3Tokens.formatRelativeTime(camp.updatedAt),
                            style: V3Tokens.caption(p),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: V3Button(
                            label: 'Inspect',
                            icon: Icons.visibility_outlined,
                            small: true,
                            palette: p,
                            onTap: () => widget.onInspectCampaign(camp.campaignId),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${rows.length} of $totalItems proposals',
                style: V3Tokens.caption(p),
              ),
              Row(
                children: [
                  V3Button(
                    label: 'Prev',
                    small: true,
                    palette: p,
                    onTap: currentPage > 1 ? () => setState(() => _page = currentPage - 1) : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('$currentPage / $totalPages', style: V3Tokens.caption(p)),
                  ),
                  V3Button(
                    label: 'Next',
                    small: true,
                    palette: p,
                    onTap: currentPage < totalPages
                        ? () => setState(() => _page = currentPage + 1)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sortHeader(V3Palette p, String label, {String? sortKey}) {
    final active = sortKey != null && _sortBy == sortKey;
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: V3Tokens.caption(p, color: active ? p.textPrimary : p.textSecondary),
          ),
          if (sortKey != null) ...[
            const SizedBox(width: 3),
            Icon(
              active
                  ? (_sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                  : Icons.unfold_more_rounded,
              size: 13,
              color: active ? p.accentText : p.textTertiary,
            ),
          ],
        ],
      ),
    );
    if (sortKey == null) return child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _toggleSort(sortKey),
        child: child,
      ),
    );
  }
}
