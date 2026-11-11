import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../state/campaign_state_machine.dart';
import '../widgets/marketing_visuals.dart';
import 'v2_components.dart';
import 'v2_mappers.dart';
import 'v2_sheets.dart';
import 'v2_tokens.dart';

/// Screen 02: Campaign Detail Ledger with synchronized Version Thread, Perforated Economics & Role Gates.
class V2CampaignDetailScreen extends StatefulWidget {
  final ApiService api;
  final String campaignId;
  final List<ScheduleEvent> calendarEvents;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onDataMutated;

  const V2CampaignDetailScreen({
    super.key,
    required this.api,
    required this.campaignId,
    required this.calendarEvents,
    this.onOpenCalendar,
    this.onDataMutated,
  });

  @override
  State<V2CampaignDetailScreen> createState() => _V2CampaignDetailScreenState();
}

class _V2CampaignDetailScreenState extends State<V2CampaignDetailScreen> {
  Campaign? _campaign;
  bool _loading = true;
  int _selectedVersionIdx = 0;
  String? _activeClauseFilter;
  String? _commitBanner;

  // Integrated team discussions & creative preview drawer state
  List<DiscussionMessage> _discussions = [];
  bool _showDiscussionPanel = false;
  bool _showCreativePreview = false;
  final TextEditingController _msgCtrl = TextEditingController();
  bool _postingMsg = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool preserveVersion = false}) async {
    try {
      final camp = await widget.api.getCampaign(widget.campaignId);
      final msgs = await widget.api.getDiscussions(widget.campaignId);
      if (!mounted) return;
      final versions = V2Mappers.sortedVersions(camp);
      setState(() {
        _campaign = camp;
        _discussions = msgs;
        _loading = false;
        if (!preserveVersion || _selectedVersionIdx >= versions.length) {
          _selectedVersionIdx = (versions.length - 1).clamp(0, versions.length);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showBanner(String text) {
    setState(() => _commitBanner = text);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _commitBanner == text) {
        setState(() => _commitBanner = null);
      }
    });
  }

  Future<void> _openStudio(Campaign camp, CampaignVersion ver) async {
    final result = await Navigator.push<Campaign>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => V2ProposalStudioSheet(
          api: widget.api,
          existingCampaign: camp,
          baseVersion: ver,
        ),
      ),
    );
    if (result != null) {
      widget.onDataMutated?.call();
      await _load();
      _showBanner(
        'Submitted ${V2Tokens.formatVersionTag(result.currentVersion?.versionNo ?? 1)} (${V2Tokens.formatCurrency(result.currentVersion?.budget ?? 0)} · ${result.currentVersion?.targetAudience ?? ''}).',
      );
    }
  }

  Future<void> _openDecision(Campaign camp, CampaignVersion ver) async {
    final outcome = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => V2DecisionSheet(
          api: widget.api,
          campaign: camp,
          targetVersion: ver,
        ),
      ),
    );
    if (outcome != null) {
      widget.onDataMutated?.call();
      await _load(preserveVersion: true);
      final word = outcome == 'APPROVED'
          ? 'Approved'
          : outcome == 'CHANGES_REQUESTED'
              ? 'Changes'
              : 'Rejected';
      final tag = V2Tokens.formatVersionTag(ver.versionNo);
      _showBanner(
        outcome == 'APPROVED'
            ? '$word stamp locked on $tag. Ready to schedule.'
            : '$word recorded on $tag.',
      );
    }
  }

  Future<void> _openPreFlight(Campaign camp, CampaignVersion ver, {bool forceOldDemo = false}) async {
    final res = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => V2PreFlightSheet(
          api: widget.api,
          campaign: camp,
          targetVersion: ver,
          existingEvents: widget.calendarEvents,
          forceUnapprovedDemo: forceOldDemo,
        ),
      ),
    );
    if (res == 'SCHEDULED') {
      widget.onDataMutated?.call();
      await _load(preserveVersion: true);
      _showBanner('Scheduled ${V2Tokens.formatVersionTag(ver.versionNo)} on ${ver.channel}.');
      if (widget.onOpenCalendar != null && mounted) {
        Navigator.pop(context, 'OPEN_CALENDAR');
        widget.onOpenCalendar!();
      }
    } else if (res == 'OPEN_REVIEW') {
      await _openDecision(camp, ver);
    }
  }

  Future<void> _sendMessage(CampaignVersion ver) async {
    final txt = _msgCtrl.text.trim();
    if (txt.isEmpty || _postingMsg) return;
    setState(() => _postingMsg = true);
    try {
      await widget.api.postDiscussion(widget.campaignId, txt, versionId: ver.versionId);
      _msgCtrl.clear();
      await _load(preserveVersion: true);
    } finally {
      if (mounted) setState(() => _postingMsg = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _campaign == null) {
      return const Scaffold(
        backgroundColor: V2Tokens.bgPlaster,
        body: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: V2Tokens.inkPrussian),
        ),
      );
    }

    final camp = _campaign!;
    final versions = V2Mappers.sortedVersions(camp);
    final safeIdx = _selectedVersionIdx.clamp(0, versions.length - 1);
    final activeVer = versions[safeIdx];
    final prevBudget = V2Mappers.previousBudgetFor(camp, activeVer);
    final stamps = V2Mappers.buildStampLedger(camp);
    final activeTag = V2Tokens.formatVersionTag(activeVer.versionNo);
    final headVerNo = camp.currentVersion?.versionNo ?? versions.last.versionNo;
    final headTag = V2Tokens.formatVersionTag(headVerNo);
    final isCurrentHead = activeVer.versionId == camp.currentVersionId || safeIdx == versions.length - 1;

    final campStatusKey = V2Tokens.normalizeStatusKey(camp.status);
    final stampStatusKey = stamps.isNotEmpty && safeIdx < stamps.length
        ? stamps[safeIdx].status
        : campStatusKey;
    final isApproved = stampStatusKey == 'approved';
    final isScheduled = stampStatusKey == 'scheduled' || (isCurrentHead && campStatusKey == 'scheduled');
    final isChanges = stampStatusKey == 'changes' || (isCurrentHead && campStatusKey == 'changes');

    final curUser = widget.api.currentUser;
    final caps = CampaignStateMachine.evaluate(camp, curUser);
    final isOwner = caps.isOwner;
    final canEdit = caps.canEdit;

    return Scaffold(
      backgroundColor: V2Tokens.bgPlaster,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(
              children: [
                // Clean Top Navigation Chrome (Single contextual Edit trigger)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: V2Tokens.hairline, width: 1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 38),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.chevron_left_rounded, size: 19, color: V2Tokens.textPrimary),
                              const SizedBox(width: 2),
                              Text('Pipeline', style: V2Tokens.t3(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      if (canEdit)
                        InkWell(
                          onTap: () => _openStudio(camp, activeVer),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 36),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: V2Tokens.surfaceCard,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: V2Tokens.hairline, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit_outlined, size: 13, color: V2Tokens.textPrimary),
                                const SizedBox(width: 6),
                                Text('Edit $headTag', style: V2Tokens.t4(color: V2Tokens.textPrimary)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Scrollable Body
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    children: [
                      if (_commitBanner != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: V2Tokens.approvedChipBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: V2Tokens.hairline, width: 1),
                          ),
                          child: Row(
                            children: [
                              const V2FacetCell(status: 'approved', size: 12),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _commitBanner!,
                                  style: V2Tokens.t3(
                                    color: V2Tokens.approvedSolid,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Title & Status Header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(camp.title, style: V2Tokens.t1()),
                                const SizedBox(height: 3),
                                Text(
                                  'Owner: ${V2Tokens.cleanPersonName(camp.ownerName)} · Reviewing $activeTag',
                                  style: V2Tokens.t3(color: V2Tokens.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          V2StatusBadge(status: stampStatusKey),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Synchronized Vertical Version Thread
                      V2VerticalVersionThread(
                        stamps: stamps,
                        selectedStampIdx: safeIdx,
                        onSelectStamp: (idx) {
                          setState(() => _selectedVersionIdx = idx);
                        },
                        activeClauseFilter: _activeClauseFilter,
                        onHighlightClause: (field) {
                          setState(() => _activeClauseFilter = field);
                        },
                        onOpenDiff: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => V2DiffScreen(
                                campaign: camp,
                                initialVersionNo: activeVer.versionNo,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // Perforated Financial & Audience Ledger Card
                      Container(
                        decoration: BoxDecoration(
                          color: V2Tokens.surfaceCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: V2Tokens.hairline, width: 1),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                              decoration: BoxDecoration(
                                color: _activeClauseFilter == 'Budget'
                                    ? V2Tokens.changedRowTint
                                    : Colors.transparent,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Budget ($activeTag)',
                                        style: V2Tokens.t3(color: V2Tokens.textSecondary),
                                      ),
                                      Text(
                                        V2Tokens.formatCurrency(activeVer.budget),
                                        style: V2Tokens.t2(mono: true),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  V2CellMeter(
                                    amount: activeVer.budget,
                                    prevAmount: prevBudget,
                                    maxAmount: 40000,
                                    ceilingRatio: 0.75,
                                    totalCells: 24,
                                    cellHeight: 9,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Ceiling tick: \$30,000', style: V2Tokens.t4()),
                                      InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => V2SpendScreen(
                                                api: widget.api,
                                                campaign: camp,
                                                version: activeVer,
                                                onAuditLogged: () => widget.onDataMutated?.call(),
                                                onReviseRequested: () => _openStudio(camp, activeVer),
                                              ),
                                            ),
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 2),
                                          child: Text(
                                            'Live spend meter →',
                                            style: V2Tokens.t4(color: V2Tokens.inkPrussian),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const V2TicketPerforation(notchBg: V2Tokens.bgPlaster),

                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                              child: Column(
                                children: [
                                  V2AudienceSegmentBar(
                                    mode: activeVer.targetAudience,
                                    highlighted: _activeClauseFilter == 'Audience',
                                    onInspectDiff: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => V2DiffScreen(
                                            campaign: camp,
                                            initialVersionNo: activeVer.versionNo,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                                    decoration: const BoxDecoration(
                                      border: Border(top: BorderSide(color: V2Tokens.hairline, width: 1)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Channel', style: V2Tokens.t3(color: V2Tokens.textSecondary)),
                                        Text(activeVer.channel, style: V2Tokens.t4(color: V2Tokens.textPrimary)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.only(top: 8),
                                    decoration: const BoxDecoration(
                                      border: Border(top: BorderSide(color: V2Tokens.hairline, width: 1)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Target CPA', style: V2Tokens.t3(color: V2Tokens.textSecondary)),
                                        Text(
                                          '\$${activeVer.kpiProjected.cpa.toStringAsFixed(2)}',
                                          style: V2Tokens.t4(color: V2Tokens.textPrimary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Collapsible Team Discussion & Creative Preview utility rows (preserves full features)
                      Container(
                        decoration: BoxDecoration(
                          color: V2Tokens.surfaceCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: V2Tokens.hairline, width: 1),
                        ),
                        child: Column(
                          children: [
                            InkWell(
                              onTap: () => setState(() => _showCreativePreview = !_showCreativePreview),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Creative mockup (${activeVer.channel})',
                                        style: V2Tokens.t3(fontWeight: FontWeight.w600)),
                                    Icon(
                                      _showCreativePreview
                                          ? Icons.expand_less_rounded
                                          : Icons.expand_more_rounded,
                                      size: 18,
                                      color: V2Tokens.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_showCreativePreview)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                child: LiveCreativeMockupCanvas(
                                  channel: activeVer.channel,
                                  title: camp.title,
                                  copy: activeVer.objective,
                                  targetCpa: activeVer.kpiProjected.cpa,
                                ),
                              ),
                            const Divider(height: 1, thickness: 1, color: V2Tokens.hairline),
                            InkWell(
                              onTap: () => setState(() => _showDiscussionPanel = !_showDiscussionPanel),
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Team thread (${_discussions.length})',
                                        style: V2Tokens.t3(fontWeight: FontWeight.w600)),
                                    Icon(
                                      _showDiscussionPanel
                                          ? Icons.expand_less_rounded
                                          : Icons.expand_more_rounded,
                                      size: 18,
                                      color: V2Tokens.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_showDiscussionPanel)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ..._discussions.map((m) => Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: V2Tokens.bgPlaster,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: V2Tokens.hairline, width: 1),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    '${m.authorName} · ${m.authorRole}',
                                                    style: V2Tokens.t4(color: V2Tokens.textPrimary),
                                                  ),
                                                  Text(
                                                    V2Mappers.formatShortTimestamp(m.createdAt),
                                                    style: V2Tokens.t4(),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(m.content, style: V2Tokens.t3()),
                                            ],
                                          ),
                                        )),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _msgCtrl,
                                            style: V2Tokens.t3(),
                                            decoration: InputDecoration(
                                              hintText: 'Add a note for this version…',
                                              hintStyle: V2Tokens.t3(color: V2Tokens.textSecondary),
                                              isDense: true,
                                              filled: true,
                                              fillColor: V2Tokens.bgPlaster,
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(10),
                                                borderSide: const BorderSide(color: V2Tokens.hairline),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: _postingMsg ? null : () => _sendMessage(activeVer),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: V2Tokens.inkPrussian,
                                            foregroundColor: V2Tokens.labelOnInk,
                                            minimumSize: const Size(64, 40),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: Text(
                                            _postingMsg ? '…' : 'Post',
                                            style: V2Tokens.t4(color: V2Tokens.labelOnInk),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Text(
                        !isCurrentHead
                            ? 'Historical snapshot ($activeTag). Prior approvals never authorize $headTag.'
                            : 'Only the approved, current version can be scheduled.',
                        style: V2Tokens.t3(color: V2Tokens.textSecondary),
                      ),
                    ],
                  ),
                ),

                // Sticky Role- & Status-Gated Primary Footer
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  decoration: const BoxDecoration(
                    color: V2Tokens.surfaceCard,
                    border: Border(top: BorderSide(color: V2Tokens.hairline, width: 1)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: _buildPrimaryAction(
                      camp: camp,
                      activeVer: activeVer,
                      activeTag: activeTag,
                      headTag: headTag,
                      headIdx: versions.length - 1,
                      isCurrentHead: isCurrentHead,
                      isScheduled: isScheduled,
                      isApproved: isApproved,
                      isChanges: isChanges,
                      isOwner: isOwner,
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

  Widget _buildPrimaryAction({
    required Campaign camp,
    required CampaignVersion activeVer,
    required String activeTag,
    required String headTag,
    required int headIdx,
    required bool isCurrentHead,
    required bool isScheduled,
    required bool isApproved,
    required bool isChanges,
    required bool isOwner,
  }) {
    final caps = CampaignStateMachine.evaluate(camp, widget.api.currentUser);

    if (isScheduled) {
      return SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context, 'OPEN_CALENDAR');
            widget.onOpenCalendar?.call();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: V2Tokens.approvedSolid,
            foregroundColor: V2Tokens.labelOnInk,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          child: Text(
            'Scheduled on ${activeVer.channel} · View Calendar',
            style: V2Tokens.t2(color: V2Tokens.labelOnInk),
          ),
        ),
      );
    }

    if (isApproved && isCurrentHead) {
      return SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton(
          onPressed: caps.canSchedule ? () => _openPreFlight(camp, activeVer) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: V2Tokens.inkPrussian,
            disabledBackgroundColor: V2Tokens.surfaceRecessed,
            foregroundColor: V2Tokens.labelOnInk,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          child: Text(
            caps.canSchedule ? 'Schedule $activeTag' : 'Approved · Owner schedules launch',
            style: V2Tokens.t2(
              color: caps.canSchedule ? V2Tokens.labelOnInk : V2Tokens.textSecondary,
            ),
          ),
        ),
      );
    }

    if (!isCurrentHead) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: () => setState(() => _selectedVersionIdx = headIdx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: V2Tokens.inkPrussian,
                  foregroundColor: V2Tokens.labelOnInk,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: Text(
                  'Return to $headTag (Current)',
                  overflow: TextOverflow.ellipsis,
                  style: V2Tokens.t3(color: V2Tokens.labelOnInk, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 46,
            child: OutlinedButton(
              onPressed: () => _openPreFlight(camp, activeVer, forceOldDemo: true),
              style: OutlinedButton.styleFrom(
                backgroundColor: V2Tokens.surfaceRecessed,
                foregroundColor: V2Tokens.blockedSolid,
                side: const BorderSide(color: V2Tokens.hairline, width: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: Text(
                'Test $activeTag gate',
                style: V2Tokens.t4(color: V2Tokens.blockedSolid),
              ),
            ),
          ),
        ],
      );
    }

    if (isChanges ||
        caps.stage == CampaignStage.draft ||
        caps.stage == CampaignStage.rejected) {
      return SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton(
          onPressed: caps.canEdit ? () => _openStudio(camp, activeVer) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: V2Tokens.inkPrussian,
            disabledBackgroundColor: V2Tokens.surfaceRecessed,
            foregroundColor: V2Tokens.labelOnInk,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          child: Text(
            caps.canEdit ? 'Edit in Proposal Studio' : (caps.editBlockedReason ?? 'Read-only brief'),
            overflow: TextOverflow.ellipsis,
            style: V2Tokens.t2(
              color: caps.canEdit ? V2Tokens.labelOnInk : V2Tokens.textSecondary,
            ),
          ),
        ),
      );
    }

    if (caps.stage == CampaignStage.completed) {
      return SizedBox(
        width: double.infinity,
        height: 46,
        child: OutlinedButton(
          onPressed: () {
            Navigator.pop(context, 'OPEN_CALENDAR');
            widget.onOpenCalendar?.call();
          },
          style: OutlinedButton.styleFrom(
            backgroundColor: V2Tokens.surfaceRecessed,
            side: const BorderSide(color: V2Tokens.hairline, width: 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          child: Text('Completed Flight · Archived', style: V2Tokens.t2(color: V2Tokens.textSecondary)),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton.icon(
        onPressed: () => _openDecision(camp, activeVer),
        style: ElevatedButton.styleFrom(
          backgroundColor: V2Tokens.inkPrussian,
          foregroundColor: V2Tokens.labelOnInk,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        icon: !caps.canReview
            ? const Icon(Icons.lock_outline_rounded, size: 15, color: V2Tokens.cadmiumYellow)
            : const SizedBox.shrink(),
        label: Text(
          caps.canReview
              ? 'Review $activeTag'
              : (caps.isOwner ? 'Inspect $activeTag (Owner Lock)' : 'Inspect $activeTag (Locked)'),
          style: V2Tokens.t2(color: V2Tokens.labelOnInk),
        ),
      ),
    );
  }
}

/// Screen 03: Version Diff Inspector comparing snapshots side-by-side.
class V2DiffScreen extends StatefulWidget {
  final Campaign campaign;
  final int initialVersionNo;

  const V2DiffScreen({
    super.key,
    required this.campaign,
    required this.initialVersionNo,
  });

  @override
  State<V2DiffScreen> createState() => _V2DiffScreenState();
}

class _V2DiffScreenState extends State<V2DiffScreen> {
  late int _selectedVerNo;

  @override
  void initState() {
    super.initState();
    _selectedVerNo = widget.initialVersionNo;
  }

  @override
  Widget build(BuildContext context) {
    final versions = V2Mappers.sortedVersions(widget.campaign);
    final idx = versions.indexWhere((v) => v.versionNo == _selectedVerNo);
    final safeIdx = idx >= 0 ? idx : versions.length - 1;
    final curVer = versions[safeIdx];
    final prevVer = safeIdx > 0 ? versions[safeIdx - 1] : curVer;
    final curTag = V2Tokens.formatVersionTag(curVer.versionNo);
    final prevTag = V2Tokens.formatVersionTag(prevVer.versionNo);

    final budgetDelta = curVer.budget - prevVer.budget;
    final budgetPct = prevVer.budget > 0 ? ((budgetDelta / prevVer.budget) * 100).round() : 0;
    final budgetChanged = budgetDelta.abs() >= 1;
    final audienceChanged = curVer.targetAudience != prevVer.targetAudience;
    final channelChanged = curVer.channel != prevVer.channel;

    return Scaffold(
      backgroundColor: V2Tokens.bgPlaster,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: V2Tokens.hairline, width: 1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 36),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.chevron_left_rounded, size: 19, color: V2Tokens.textPrimary),
                              const SizedBox(width: 2),
                              Text(
                                widget.campaign.title,
                                style: V2Tokens.t3(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        safeIdx > 0 ? '$prevTag to $curTag' : 'Baseline $curTag',
                        style: V2Tokens.t4(),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    children: [
                      Text('Changes in $curTag', style: V2Tokens.t1()),
                      const SizedBox(height: 14),

                      // Version Picker Segment
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: V2Tokens.surfaceRecessed,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: V2Tokens.hairline, width: 1),
                        ),
                        child: Row(
                          children: versions.map((v) {
                            final selected = v.versionNo == curVer.versionNo;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedVerNo = v.versionNo),
                                child: Container(
                                  constraints: const BoxConstraints(minHeight: 38),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: selected ? V2Tokens.surfaceCard : Colors.transparent,
                                    borderRadius: BorderRadius.circular(9),
                                    border: selected
                                        ? Border.all(color: V2Tokens.inkPrussian, width: 1.5)
                                        : null,
                                  ),
                                  child: Text(
                                    V2Tokens.formatVersionTag(v.versionNo),
                                    style: V2Tokens.t4(
                                      color: selected
                                          ? V2Tokens.textPrimary
                                          : V2Tokens.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Perforated Budget Diff Ticket
                      Container(
                        decoration: BoxDecoration(
                          color: budgetChanged ? V2Tokens.changedRowTint : V2Tokens.surfaceCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: V2Tokens.hairline, width: 1),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Budget', style: V2Tokens.t2()),
                                      V2StatusBadge(
                                        status: budgetChanged ? 'changes' : 'approved',
                                        customLabel: budgetChanged ? 'Changed' : 'Unchanged',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 10,
                                    children: [
                                      if (budgetChanged) ...[
                                        Text(
                                          V2Tokens.formatCurrency(prevVer.budget),
                                          style: V2Tokens.t2(
                                            mono: true,
                                            color: V2Tokens.textSecondary,
                                          ).copyWith(decoration: TextDecoration.lineThrough),
                                        ),
                                        const Icon(Icons.arrow_forward_rounded,
                                            size: 14, color: V2Tokens.textSecondary),
                                      ],
                                      Text(
                                        V2Tokens.formatCurrency(curVer.budget),
                                        style: V2Tokens.t1(mono: true),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  V2CellMeter(
                                    amount: curVer.budget,
                                    prevAmount: prevVer.budget,
                                    maxAmount: 40000,
                                    ceilingRatio: 0.75,
                                    totalCells: 24,
                                    cellHeight: 10,
                                  ),
                                ],
                              ),
                            ),
                            const V2TicketPerforation(notchBg: V2Tokens.bgPlaster),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Previous: ${V2Tokens.formatCurrency(prevVer.budget)}',
                                    style: V2Tokens.t4(),
                                  ),
                                  Text(
                                    budgetChanged
                                        ? '${budgetDelta > 0 ? '+' : ''}${V2Tokens.formatCurrency(budgetDelta)} (${budgetDelta > 0 ? '+' : ''}$budgetPct%)'
                                        : 'No delta vs $prevTag',
                                    style: V2Tokens.t4(
                                      color: budgetChanged
                                          ? V2Tokens.changesSolid
                                          : V2Tokens.approvedSolid,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Parameters Diff Card
                      Container(
                        decoration: BoxDecoration(
                          color: V2Tokens.surfaceCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: V2Tokens.hairline, width: 1),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: audienceChanged
                                    ? V2Tokens.changedRowTint
                                    : Colors.transparent,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                border: const Border(
                                  bottom: BorderSide(color: V2Tokens.hairline, width: 1),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Audience', style: V2Tokens.t2()),
                                      V2StatusBadge(
                                        status: audienceChanged ? 'changes' : 'approved',
                                        customLabel: audienceChanged ? 'Changed' : 'Unchanged',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    children: [
                                      if (audienceChanged) ...[
                                        Text(
                                          prevVer.targetAudience,
                                          style: V2Tokens.t3(
                                            color: V2Tokens.textSecondary,
                                            decoration: TextDecoration.lineThrough,
                                          ),
                                        ),
                                        const Icon(Icons.arrow_forward_rounded,
                                            size: 13, color: V2Tokens.textSecondary),
                                      ],
                                      Text(
                                        curVer.targetAudience,
                                        style: V2Tokens.t3(fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: channelChanged ? V2Tokens.changedRowTint : Colors.transparent,
                                border: const Border(
                                  bottom: BorderSide(color: V2Tokens.hairline, width: 1),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Channel', style: V2Tokens.t3(color: V2Tokens.textSecondary)),
                                  Text(
                                    channelChanged
                                        ? '${prevVer.channel} → ${curVer.channel}'
                                        : '${curVer.channel}, unchanged',
                                    style: V2Tokens.t4(),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Projected CPA',
                                      style: V2Tokens.t3(color: V2Tokens.textSecondary)),
                                  Text(
                                    '\$${curVer.kpiProjected.cpa.toStringAsFixed(2)}',
                                    style: V2Tokens.t4(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Prior approvals do not apply to $curTag.',
                        style: V2Tokens.t3(color: V2Tokens.textSecondary),
                      ),
                    ],
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

/// Screens 12 & 13: Live Spend Meter & Automated Ceiling Pause with Mandatory Override Reason.
class V2SpendScreen extends StatefulWidget {
  final ApiService api;
  final Campaign campaign;
  final CampaignVersion version;
  final VoidCallback? onAuditLogged;
  final VoidCallback? onReviseRequested;

  const V2SpendScreen({
    super.key,
    required this.api,
    required this.campaign,
    required this.version,
    this.onAuditLogged,
    this.onReviseRequested,
  });

  @override
  State<V2SpendScreen> createState() => _V2SpendScreenState();
}

class _V2SpendScreenState extends State<V2SpendScreen> {
  bool _isPaused = false;
  bool _isResumeReasonOpen = false;
  final TextEditingController _resumeCtrl = TextEditingController(
    text: 'Paused retargeting ad set (\$38.50 CPA); reallocated cap to Lookalike (\$10.80 CPA).',
  );
  String? _resumeError;
  String? _commitBanner;

  @override
  void dispose() {
    _resumeCtrl.dispose();
    super.dispose();
  }

  void _confirmResume() {
    final trimmed = _resumeCtrl.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _resumeError = 'Written override reason is mandatory.');
      return;
    }
    widget.api.recordSpendOverrideAudit(
      campaignId: widget.campaign.campaignId,
      campaignTitle: widget.campaign.title,
      action: 'RESUMED',
      reason: trimmed,
    );
    widget.onAuditLogged?.call();
    setState(() {
      _resumeError = null;
      _isResumeReasonOpen = false;
      _isPaused = false;
      _commitBanner = 'Delivery resumed with audit reason logged.';
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _commitBanner = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final spendTotal = widget.version.budget * 2;
    final spentAmount = _isPaused ? (spendTotal * 0.75) : (spendTotal * 0.57);
    const ceilingIndex = 30;
    final filledSquares = _isPaused ? 30 : 23;

    final channelRows = [
      (
        name: 'Social · Lookalike',
        cpa: _isPaused ? '\$24.10' : '\$10.80',
        ratio: _isPaused ? 9 : 6,
        high: _isPaused,
      ),
      (
        name: 'Search · Brand Intent',
        cpa: '\$11.40',
        ratio: 5,
        high: false,
      ),
      (
        name: 'Display · Retargeting',
        cpa: _isPaused ? '\$38.50' : '\$12.20',
        ratio: _isPaused ? 10 : 4,
        high: _isPaused,
      ),
    ];

    return Scaffold(
      backgroundColor: V2Tokens.bgPlaster,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: V2Tokens.hairline, width: 1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 36),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.chevron_left_rounded,
                                  size: 19, color: V2Tokens.textPrimary),
                              const SizedBox(width: 2),
                              Text(
                                widget.campaign.title,
                                style: V2Tokens.t3(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      V2StatusBadge(
                        status: _isPaused ? 'blocked' : 'approved',
                        customLabel: _isPaused ? 'Paused at ceiling' : 'Running',
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    children: [
                      if (_commitBanner != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: V2Tokens.approvedChipBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: V2Tokens.hairline, width: 1),
                          ),
                          child: Row(
                            children: [
                              const V2FacetCell(status: 'approved', size: 12),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _commitBanner!,
                                  style: V2Tokens.t3(
                                    color: V2Tokens.approvedSolid,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (_isPaused) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: V2Tokens.blockedChipBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: V2Tokens.blockedSolid, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.pause_circle_outline_rounded,
                                  size: 18, color: V2Tokens.blockedSolid),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Delivery paused automatically at the \$15.00 ceiling',
                                  style: V2Tokens.t3(
                                    color: V2Tokens.blockedSolid,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Hero 40-Cell 2x20 Spend Matrix
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: V2Tokens.surfaceCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: V2Tokens.hairline, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  'CPA ${_isPaused ? '\$15.20' : '\$11.40'}',
                                  style: V2Tokens.t1(
                                    mono: true,
                                    color: _isPaused
                                        ? V2Tokens.blockedSolid
                                        : V2Tokens.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Ceiling \$15.00',
                                  style: V2Tokens.t4(color: V2Tokens.blockedSolid),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Spent ${V2Tokens.formatCurrency(spentAmount)} of ${V2Tokens.formatCurrency(spendTotal)}',
                              style: V2Tokens.t3(color: V2Tokens.textSecondary),
                            ),
                            const SizedBox(height: 12),

                            ...[0, 20].map((rowStart) {
                              final rowWidgets = <Widget>[];
                              for (int col = 0; col < 20; col++) {
                                final cellIdx = rowStart + col;
                                final isFilled = cellIdx < filledSquares;
                                final isLeading = isFilled && cellIdx >= filledSquares - 3;
                                final isCeilingTick = cellIdx == ceilingIndex;
                                if (isCeilingTick) {
                                  rowWidgets.add(
                                    Container(
                                      width: 3,
                                      height: 18,
                                      margin: const EdgeInsets.only(right: 3),
                                      decoration: BoxDecoration(
                                        color: V2Tokens.blockedSolid,
                                        borderRadius: BorderRadius.circular(1),
                                      ),
                                    ),
                                  );
                                }
                                rowWidgets.add(
                                  Expanded(
                                    child: Container(
                                      height: 12,
                                      margin: EdgeInsets.only(right: col == 19 ? 0 : 3),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(2),
                                        color: !isFilled
                                            ? V2Tokens.surfaceRecessed
                                            : (_isPaused && isLeading)
                                                ? V2Tokens.blockedSolid
                                                : isLeading
                                                    ? V2Tokens.cadmiumYellow
                                                    : V2Tokens.inkPrussian,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return Padding(
                                padding: EdgeInsets.only(bottom: rowStart == 0 ? 6 : 0),
                                child: Row(children: rowWidgets),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Channel CPA Breakdown
                      Container(
                        decoration: BoxDecoration(
                          color: V2Tokens.surfaceCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: V2Tokens.hairline, width: 1),
                        ),
                        child: Column(
                          children: List.generate(channelRows.length, (idx) {
                            final ch = channelRows[idx];
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                border: idx < channelRows.length - 1
                                    ? const Border(
                                        bottom: BorderSide(color: V2Tokens.hairline, width: 1),
                                      )
                                    : null,
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(ch.name, style: V2Tokens.t3(fontWeight: FontWeight.w600)),
                                      Text(
                                        'CPA ${ch.cpa}',
                                        style: V2Tokens.t4(
                                          color: ch.high
                                              ? V2Tokens.blockedSolid
                                              : V2Tokens.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: List.generate(12, (i) {
                                      final active = i < ch.ratio;
                                      return Expanded(
                                        child: Container(
                                          height: 6,
                                          margin: EdgeInsets.only(right: i == 11 ? 0 : 3),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(1.5),
                                            color: active
                                                ? (ch.high
                                                    ? V2Tokens.blockedSolid
                                                    : V2Tokens.inkPrussian)
                                                : V2Tokens.surfaceRecessed,
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),

                      if (_isPaused && _isResumeReasonOpen) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: V2Tokens.changedRowTint,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: V2Tokens.inkPrussian, width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Override reason (logged to Activity) *',
                                    style: V2Tokens.t4(color: V2Tokens.inkPrussian),
                                  ),
                                  Text(
                                    '${_resumeCtrl.text.trim().length} chars',
                                    style: V2Tokens.t4(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _resumeCtrl,
                                maxLines: 2,
                                onChanged: (_) => setState(() => _resumeError = null),
                                style: V2Tokens.t3(),
                                decoration: InputDecoration(
                                  hintText: 'Explain what corrective action was taken before resuming…',
                                  hintStyle: V2Tokens.t3(color: V2Tokens.textSecondary),
                                  filled: true,
                                  fillColor: V2Tokens.surfaceCard,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: _resumeError != null
                                          ? V2Tokens.blockedSolid
                                          : V2Tokens.hairline,
                                    ),
                                  ),
                                ),
                              ),
                              if (_resumeError != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  _resumeError!,
                                  style: V2Tokens.t4(color: V2Tokens.blockedSolid),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Footer Buttons
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  decoration: const BoxDecoration(
                    color: V2Tokens.surfaceCard,
                    border: Border(top: BorderSide(color: V2Tokens.hairline, width: 1)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: _isPaused
                        ? Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (!_isResumeReasonOpen) {
                                      setState(() => _isResumeReasonOpen = true);
                                    } else {
                                      _confirmResume();
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: V2Tokens.inkPrussian,
                                    foregroundColor: V2Tokens.labelOnInk,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  child: Text(
                                    _isResumeReasonOpen
                                        ? 'Confirm & resume delivery'
                                        : 'Resume delivery (reason required)',
                                    style: V2Tokens.t2(color: V2Tokens.labelOnInk),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                height: 42,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    widget.onReviseRequested?.call();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: V2Tokens.surfaceCard,
                                    foregroundColor: V2Tokens.textPrimary,
                                    side: const BorderSide(color: V2Tokens.inkPrussian, width: 1.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  child: Text(
                                    'Raise ceiling, needs review',
                                    style: V2Tokens.t3(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () {
                                widget.api.recordSpendOverrideAudit(
                                  campaignId: widget.campaign.campaignId,
                                  campaignTitle: widget.campaign.title,
                                  action: 'PAUSED',
                                  reason: 'Simulated CPA ceiling guardrail breach (\$15.20 > \$15.00).',
                                );
                                widget.onAuditLogged?.call();
                                setState(() => _isPaused = true);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: V2Tokens.inkPrussian,
                                foregroundColor: V2Tokens.labelOnInk,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: Text(
                                'Pause delivery',
                                style: V2Tokens.t2(color: V2Tokens.labelOnInk),
                              ),
                            ),
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
