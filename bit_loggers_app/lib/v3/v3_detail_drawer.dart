import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../state/campaign_state_machine.dart';
import 'v3_components.dart';
import 'v3_tokens.dart';

class V3DetailDrawer extends StatefulWidget {
  final ApiService api;
  final V3Palette palette;
  final String campaignId;
  final String initialTab;
  final VoidCallback onClose;
  final ValueChanged<Campaign> onEditCampaign;
  final Future<void> Function() onMutated;
  final void Function(String title, String description, String status) onNotify;

  const V3DetailDrawer({
    super.key,
    required this.api,
    required this.palette,
    required this.campaignId,
    required this.initialTab,
    required this.onClose,
    required this.onEditCampaign,
    required this.onMutated,
    required this.onNotify,
  });

  @override
  State<V3DetailDrawer> createState() => _V3DetailDrawerState();
}

class _V3DetailDrawerState extends State<V3DetailDrawer> {
  Campaign? _campaign;
  List<DiscussionMessage> _discussions = [];
  late String _activeTab;
  bool _loading = true;

  // Review state
  String _decisionType = 'APPROVED';
  final TextEditingController _reasonCtrl = TextEditingController();
  final TextEditingController _policyCtrl = TextEditingController();
  bool _submittingDecision = false;
  String? _reviewError;

  // Schedule state
  String _schedChannel = 'Social';
  late DateTime _startDate;
  late DateTime _endDate;
  bool _submittingSchedule = false;

  // Comment state
  final TextEditingController _commentCtrl = TextEditingController();
  bool _sendingComment = false;
  bool _togglingLock = false;

  static const _channels = ['Social', 'Search', 'Email', 'Display', 'Video', 'Influencer'];

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _startDate = DateTime.now();
    _endDate = _startDate.add(const Duration(days: 10));
    _load();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _policyCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.api.getCampaign(widget.campaignId),
        widget.api.getDiscussions(widget.campaignId),
      ]);
      if (!mounted) return;
      final camp = results[0] as Campaign;
      setState(() {
        _campaign = camp;
        _discussions = results[1] as List<DiscussionMessage>;
        _schedChannel = camp.currentVersion?.channel ?? 'Social';
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleLock() async {
    final c = _campaign;
    if (c == null || _togglingLock) return;
    setState(() => _togglingLock = true);
    try {
      final lockState = CampaignStateMachine.evaluateLock(
        c.activeLock,
        widget.api.currentUser.id,
      );
      if (lockState.isHeldByMe) {
        await widget.api.releaseLock(c.campaignId);
        widget.onNotify(
          'Edit lease released',
          'Other authors can now revise this brief.',
          'information',
        );
      } else {
        final res = await widget.api.acquireLock(c.campaignId);
        if (res['granted'] == false) {
          widget.onNotify(
            'Edit lease unavailable',
            res['holder_name'] != null
                ? 'Held by ${res['holder_name']}.'
                : 'Held by another editor.',
            'error',
          );
          return;
        }
        widget.onNotify(
          '5-minute edit lease acquired',
          'Your draft edits are protected from concurrent overwrites.',
          'success',
        );
      }
      await _load();
      await widget.onMutated();
    } catch (e) {
      widget.onNotify('Lease action failed', e.toString(), 'error');
    } finally {
      if (mounted) setState(() => _togglingLock = false);
    }
  }

  Future<void> _submitForReview() async {
    final c = _campaign;
    if (c == null) return;
    try {
      await widget.api.submitCampaign(c.campaignId);
      widget.onNotify(
        'Submitted for review',
        '${c.title} moved to reviewer queue.',
        'success',
      );
      await _load();
      await widget.onMutated();
    } catch (e) {
      widget.onNotify('Submission failed', e.toString(), 'error');
    }
  }

  Future<void> _recordDecision() async {
    final c = _campaign;
    final ver = c?.currentVersion;
    if (c == null || ver == null) return;
    if (_reasonCtrl.text.trim().isEmpty) {
      setState(() {
        _reviewError = 'Provide compliance or optimization rationale before saving.';
      });
      widget.onNotify(
        'Rationale required',
        'Provide compliance or optimization feedback before saving a decision.',
        'error',
      );
      return;
    }
    setState(() {
      _reviewError = null;
      _submittingDecision = true;
    });
    try {
      await widget.api.makeDecision(
        c.campaignId,
        _decisionType,
        ver.versionId,
        _reasonCtrl.text.trim(),
        policyReference: _policyCtrl.text.trim().isEmpty ? null : _policyCtrl.text.trim(),
      );
      _reasonCtrl.clear();
      _policyCtrl.clear();
      widget.onNotify(
        'Review decision recorded',
        'Recorded ${_decisionType.replaceAll('_', ' ')} on v${ver.versionNo}.',
        'success',
      );
      await _load();
      await widget.onMutated();
      if (mounted) setState(() => _activeTab = 'overview');
    } catch (e) {
      widget.onNotify('Decision blocked', e.toString(), 'error');
    } finally {
      if (mounted) setState(() => _submittingDecision = false);
    }
  }

  Future<void> _confirmSchedule() async {
    final c = _campaign;
    final ver = c?.currentVersion;
    if (c == null || ver == null) return;
    setState(() => _submittingSchedule = true);
    try {
      await widget.api.scheduleCampaign(
        c.campaignId,
        ver.versionId,
        _startDate.toIso8601String(),
        _endDate.toIso8601String(),
        _schedChannel,
      );
      widget.onNotify(
        'Flight scheduled cleanly',
        '${c.title} locked on $_schedChannel.',
        'success',
      );
      await _load();
      await widget.onMutated();
      if (mounted) setState(() => _activeTab = 'overview');
    } catch (e) {
      widget.onNotify('Schedule blocked', e.toString(), 'error');
    } finally {
      if (mounted) setState(() => _submittingSchedule = false);
    }
  }

  Future<void> _postComment() async {
    final c = _campaign;
    final txt = _commentCtrl.text.trim();
    if (c == null || txt.isEmpty) return;
    setState(() => _sendingComment = true);
    try {
      await widget.api.postDiscussion(c.campaignId, txt);
      _commentCtrl.clear();
      await _load();
      await widget.onMutated();
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final camp = _campaign;
    final versions = <CampaignVersion>[...(camp?.versions ?? const <CampaignVersion>[])]
      ..sort((a, b) => a.versionNo.compareTo(b.versionNo));
    final curVer = camp?.currentVersion ?? (versions.isNotEmpty ? versions.last : null);
    final prevVer = versions.length > 1 ? versions[versions.length - 2] : null;
    final caps = camp != null
        ? CampaignStateMachine.evaluate(camp, widget.api.currentUser)
        : null;
    final canEdit = caps?.canEdit ?? false;
    final canApprove = caps?.canReview ?? false;
    final isLockedByMe = caps?.lockInfo.isHeldByMe ?? false;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: math.min(720.0, MediaQuery.of(context).size.width),
          height: double.infinity,
          decoration: BoxDecoration(
            color: p.bgPrimary,
            border: Border(left: BorderSide(color: p.borderDefault, width: 1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 36,
                offset: const Offset(-6, 0),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Top Bar
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: p.separator)),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 520;
                      final titleBlock = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (camp != null)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                V3Chip(
                                  label: V3Tokens.statusLabel(camp.status),
                                  tone: V3Tokens.statusChipTone(camp.status),
                                  palette: p,
                                ),
                                V3Chip(
                                  label: curVer?.channel ?? 'Social',
                                  tone: V3Tokens.channelChipTone(curVer?.channel ?? 'Social'),
                                  palette: p,
                                ),
                                V3Badge(label: 'v${curVer?.versionNo ?? 1}', palette: p),
                              ],
                            ),
                          const SizedBox(height: 8),
                          Text(
                            _loading && camp == null ? 'Loading brief…' : (camp?.title ?? ''),
                            style: V3Tokens.title1(p, semiBold: true).copyWith(fontSize: 21),
                          ),
                          if (camp != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Owner ${V3Tokens.cleanPersonName(camp.ownerName)} • Updated ${V3Tokens.formatRelativeTime(camp.updatedAt)}',
                              style: V3Tokens.caption(p),
                            ),
                          ],
                        ],
                      );

                      final actionButtons = [
                        if (camp != null && canEdit) ...[
                          V3Button(
                            label: _togglingLock
                                ? 'Updating…'
                                : (isLockedByMe ? 'Release lock' : 'Lease edit'),
                            icon: isLockedByMe
                                ? Icons.lock_open_rounded
                                : Icons.lock_outline_rounded,
                            small: true,
                            palette: p,
                            onTap: _togglingLock ? null : _toggleLock,
                          ),
                          V3Button(
                            label: 'Revise',
                            icon: Icons.edit_outlined,
                            small: true,
                            palette: p,
                            onTap: () {
                              widget.onClose();
                              widget.onEditCampaign(camp);
                            },
                          ),
                        ],
                      ];

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: titleBlock),
                                IconButton(
                                  onPressed: widget.onClose,
                                  icon: Icon(Icons.close_rounded, color: p.iconSecondary),
                                ),
                              ],
                            ),
                            if (actionButtons.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: actionButtons,
                              ),
                            ],
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: titleBlock),
                          const SizedBox(width: 12),
                          Wrap(
                            spacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ...actionButtons,
                              IconButton(
                                onPressed: widget.onClose,
                                icon: Icon(Icons.close_rounded, color: p.iconSecondary),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),

                if (camp != null) ...[
                  // Tabs
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: p.separator)),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _drawerTab(p, 'overview', 'Overview', Icons.verified_user_outlined),
                          _drawerTab(p, 'versions', 'Versions', Icons.history_rounded,
                              count: versions.length),
                          _drawerTab(p, 'review', 'Review gate', Icons.done_all_rounded,
                              count: camp.decisions.length),
                          _drawerTab(p, 'schedule', 'Flight window', Icons.calendar_today_outlined),
                          _drawerTab(p, 'discussions', 'Discussion', Icons.chat_bubble_outline_rounded,
                              count: _discussions.length),
                        ],
                      ),
                    ),
                  ),

                  // Body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _buildTabBody(
                        p: p,
                        camp: camp,
                        versions: versions,
                        curVer: curVer,
                        prevVer: prevVer,
                        canEdit: canEdit,
                        canApprove: canApprove,
                      ),
                    ),
                  ),
                ] else
                  const Expanded(child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _drawerTab(V3Palette p, String id, String label, IconData icon, {int? count}) {
    final active = _activeTab == id;
    return InkWell(
      onTap: () => setState(() => _activeTab = id),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 10, 14, 10),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: active ? p.accent500 : Colors.transparent, width: 2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? p.accentText : p.iconSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? p.accentText : p.textSecondary,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              V3Badge(label: '$count', palette: p),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabBody({
    required V3Palette p,
    required Campaign camp,
    required List<CampaignVersion> versions,
    required CampaignVersion? curVer,
    required CampaignVersion? prevVer,
    required bool canEdit,
    required bool canApprove,
  }) {
    if (_activeTab == 'versions') {
      return Column(
        children: versions.map((v) {
          final dec = camp.decisions.where((d) => d.versionId == v.versionId).toList();
          final isHead = v.versionId == camp.currentVersionId;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.bgSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.borderDefault),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        V3Badge(label: 'Version ${v.versionNo}', palette: p, primary: isHead),
                        V3Chip(
                          label: v.channel,
                          tone: V3Tokens.channelChipTone(v.channel),
                          palette: p,
                        ),
                        Text(V3Tokens.formatMoney(v.budget), style: V3Tokens.bodyMedium(p)),
                      ],
                    ),
                    Text(V3Tokens.formatRelativeTime(v.createdAt), style: V3Tokens.caption(p)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(v.objective, style: V3Tokens.bodyMedium(p)),
                const SizedBox(height: 3),
                Text('Audience: ${v.targetAudience}', style: V3Tokens.bodyRegular(p)),
                if (dec.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: p.bgInner,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: p.separator),
                    ),
                    child: Row(
                      children: [
                        V3Chip(
                          label: dec.first.decisionType.replaceAll('_', ' '),
                          tone: dec.first.decisionType == 'APPROVED'
                              ? 'lime'
                              : dec.first.decisionType == 'CHANGES_REQUESTED'
                                  ? 'orange'
                                  : 'rose',
                          palette: p,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${V3Tokens.cleanPersonName(dec.first.reviewerName)}: ${dec.first.reason}',
                            style: V3Tokens.bodyRegular(p),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      );
    }

    if (_activeTab == 'review') {
      final caps = CampaignStateMachine.evaluate(camp, widget.api.currentUser);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!caps.canReview)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.chipColors('blue').bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                caps.reviewBlockedReason ??
                    'Owner self-approval lock active: Switch to a reviewer account to record a signoff.',
                style: V3Tokens.bodyMedium(p, color: p.chipColors('blue').fg),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.bgSecondary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.borderDefault),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Decision on v${curVer?.versionNo ?? 1}', style: V3Tokens.bodyMedium(p)),
                const SizedBox(height: 10),
                V3SegmentedControl<String>(
                  palette: p,
                  selected: _decisionType,
                  options: const [
                    V3SegmentedOption(id: 'APPROVED', label: 'Approve'),
                    V3SegmentedOption(id: 'CHANGES_REQUESTED', label: 'Request changes'),
                    V3SegmentedOption(id: 'REJECTED', label: 'Reject'),
                  ],
                  onSelect: (v) => setState(() {
                    _decisionType = v;
                    _reviewError = null;
                  }),
                ),
                const SizedBox(height: 14),
                Text('Decision rationale *', style: V3Tokens.caption(p)),
                const SizedBox(height: 6),
                TextField(
                  controller: _reasonCtrl,
                  maxLines: 3,
                  onChanged: (_) {
                    if (_reviewError != null) setState(() => _reviewError = null);
                  },
                  style: V3Tokens.bodyMedium(p),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: p.bgPrimary,
                    hintText: 'Explain compliance check, CPA alignment, or requested revisions…',
                    hintStyle: V3Tokens.bodyRegular(p, color: p.textTertiary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: _reviewError != null ? p.chipColors('rose').fg : p.borderDefault,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: _reviewError != null ? p.chipColors('rose').fg : p.borderDefault,
                      ),
                    ),
                  ),
                ),
                if (_reviewError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _reviewError!,
                    style: V3Tokens.caption(p, color: p.chipColors('rose').fg),
                  ),
                ],
                const SizedBox(height: 12),
                Text('Policy reference (optional)', style: V3Tokens.caption(p)),
                const SizedBox(height: 6),
                TextField(
                  controller: _policyCtrl,
                  style: V3Tokens.bodyMedium(p),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: p.bgPrimary,
                    hintText: 'e.g. POL-CPA-2026',
                    hintStyle: V3Tokens.bodyRegular(p, color: p.textTertiary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: p.borderDefault),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: p.borderDefault),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: V3Button(
                    label: _submittingDecision
                        ? 'Recording…'
                        : 'Record ${_decisionType == 'APPROVED' ? 'approval' : _decisionType == 'CHANGES_REQUESTED' ? 'change request' : 'rejection'}',
                    icon: _decisionType == 'REJECTED'
                        ? Icons.error_outline_rounded
                        : Icons.done_all_rounded,
                    variant: _decisionType == 'REJECTED'
                        ? V3ButtonVariant.danger
                        : V3ButtonVariant.primary,
                    palette: p,
                    onTap: (!canApprove || _submittingDecision) ? null : _recordDecision,
                  ),
                ),
              ],
            ),
          ),
          if (camp.decisions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Decision history', style: V3Tokens.caption(p)),
            const SizedBox(height: 8),
            ...camp.decisions.reversed.map(
              (d) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.bgSecondary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.borderDefault),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        V3Chip(
                          label: d.decisionType.replaceAll('_', ' '),
                          tone: d.decisionType == 'APPROVED'
                              ? 'lime'
                              : d.decisionType == 'CHANGES_REQUESTED'
                                  ? 'orange'
                                  : 'rose',
                          palette: p,
                        ),
                        Text(
                          V3Tokens.formatRelativeTime(d.decidedAt),
                          style: V3Tokens.caption(p),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(d.reason, style: V3Tokens.bodyMedium(p)),
                    const SizedBox(height: 3),
                    Text(
                      '${V3Tokens.cleanPersonName(d.reviewerName)}${d.policyReference != null && d.policyReference!.isNotEmpty ? ' • ${d.policyReference}' : ''}',
                      style: V3Tokens.caption(p),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
    }

    if (_activeTab == 'schedule') {
      final caps = CampaignStateMachine.evaluate(camp, widget.api.currentUser);
      final ready = caps.canSchedule;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!ready)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.chipColors('rose').bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                caps.scheduleBlockedReason ??
                    'Approval required before scheduling: Only approved versions can lock a slot on the production channel calendar.',
                style: V3Tokens.bodyMedium(p, color: p.chipColors('rose').fg),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.bgSecondary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.borderDefault),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Channel lane', style: V3Tokens.caption(p)),
                const SizedBox(height: 6),
                PopupMenuButton<String>(
                  color: p.bgPrimary,
                  onSelected: (ch) => setState(() => _schedChannel = ch),
                  itemBuilder: (_) => _channels
                      .map((ch) => PopupMenuItem(value: ch, child: Text(ch, style: V3Tokens.bodyMedium(p))))
                      .toList(),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: p.bgPrimary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: p.borderDefault),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_schedChannel, style: V3Tokens.bodyMedium(p)),
                        Icon(Icons.keyboard_arrow_down_rounded, color: p.iconSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _dateTile(p, 'Start date', _isoDate(_startDate), () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => _startDate = picked);
                      }),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dateTile(p, 'End date', _isoDate(_endDate), () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _endDate,
                          firstDate: _startDate,
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => _endDate = picked);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: V3Button(
                    label: _submittingSchedule ? 'Checking collisions…' : 'Confirm flight window',
                    icon: Icons.calendar_today_outlined,
                    variant: V3ButtonVariant.primary,
                    palette: p,
                    onTap: (!ready || _submittingSchedule) ? null : _confirmSchedule,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_activeTab == 'discussions') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_discussions.isEmpty)
            V3DashedBox(
              palette: p,
              borderRadius: 14,
              padding: const EdgeInsets.all(20),
              child: Text(
                'No comments yet. Mention @Marcus Vance or @Alice Cooper to notify them cleanly.',
                textAlign: TextAlign.center,
                style: V3Tokens.bodyRegular(p),
              ),
            )
          else
            ..._discussions.map((msg) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.bgSecondary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.borderDefault),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: p.accentBgSoft,
                        child: Text(
                          msg.authorName.isNotEmpty ? msg.authorName[0].toUpperCase() : 'A',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.accentText),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(V3Tokens.cleanPersonName(msg.authorName),
                                    style: V3Tokens.bodyMedium(p)),
                                Text(V3Tokens.formatRelativeTime(msg.createdAt),
                                    style: V3Tokens.caption(p)),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(msg.content, style: V3Tokens.bodyRegular(p)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.bgSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.borderDefault),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _commentCtrl,
                  maxLines: 2,
                  style: V3Tokens.bodyMedium(p),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Add review note or @mention a teammate…',
                    hintStyle: V3Tokens.bodyRegular(p, color: p.textTertiary),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: V3Button(
                    label: _sendingComment ? 'Sending…' : 'Post note',
                    icon: Icons.send_outlined,
                    small: true,
                    variant: V3ButtonVariant.primary,
                    palette: p,
                    onTap: _sendingComment ? null : _postComment,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Overview Tab
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (prevVer != null && curVer != null)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: p.bgSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.borderDefault),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.alt_route_rounded, size: 16, color: p.accentText),
                    const SizedBox(width: 6),
                    Text(
                      'Budget change from v${prevVer.versionNo} → v${curVer.versionNo}:',
                      style: V3Tokens.bodyMedium(p),
                    ),
                  ],
                ),
                V3Chip(
                  label: '${V3Tokens.formatMoney(prevVer.budget)} → ${V3Tokens.formatMoney(curVer.budget)}',
                  tone: curVer.budget >= prevVer.budget ? 'yellow' : 'lime',
                  palette: p,
                ),
              ],
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 560 ? 5 : 2;
            const gap = 10.0;
            final itemW = (constraints.maxWidth - gap * (cols - 1)) / cols;
            final budgetW = cols == 2 ? constraints.maxWidth : itemW;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                _metricTile(p, 'Budget', V3Tokens.formatMoney(curVer?.budget ?? 0.0),
                    width: budgetW),
                _metricTile(
                  p,
                  'Est. CVR',
                  '${(curVer?.kpiProjected.conversionRate ?? 4.2).toStringAsFixed(1)}%',
                  width: itemW,
                ),
                _metricTile(
                  p,
                  'Est. CTR',
                  '${(curVer?.kpiProjected.ctr ?? 4.8).toStringAsFixed(1)}%',
                  width: itemW,
                ),
                _metricTile(
                  p,
                  'Est. ROI',
                  '${(curVer?.kpiProjected.roi ?? 4.6).toStringAsFixed(1)}x',
                  width: itemW,
                ),
                _metricTile(
                  p,
                  'CPA ceiling',
                  '\$${(curVer?.kpiProjected.cpa ?? 22).toStringAsFixed(0)}',
                  width: itemW,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.bgSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.borderDefault),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Campaign objective', style: V3Tokens.caption(p, color: p.textTertiary)),
              const SizedBox(height: 4),
              Text(curVer?.objective ?? '', style: V3Tokens.bodyMedium(p)),
              Divider(height: 22, color: p.separator),
              Text('Target audience', style: V3Tokens.caption(p, color: p.textTertiary)),
              const SizedBox(height: 4),
              Text(curVer?.targetAudience ?? '', style: V3Tokens.bodyMedium(p)),
              if (curVer?.aiSummary != null && curVer!.aiSummary!.isNotEmpty) ...[
                Divider(height: 22, color: p.separator),
                Text('Governance note', style: V3Tokens.caption(p, color: p.textTertiary)),
                const SizedBox(height: 4),
                Text(curVer.aiSummary!, style: V3Tokens.bodyRegular(p)),
              ],
            ],
          ),
        ),
        if (CampaignStateMachine.evaluate(camp, widget.api.currentUser).canSubmit) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: V3Button(
              label: 'Submit v${curVer?.versionNo ?? 1} for review',
              icon: Icons.send_outlined,
              variant: V3ButtonVariant.primary,
              palette: p,
              onTap: _submitForReview,
            ),
          ),
        ],
      ],
    );
  }

  Widget _metricTile(V3Palette p, String label, String val, {double width = 118}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.bgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: V3Tokens.caption(p, color: p.textTertiary)),
          const SizedBox(height: 4),
          Text(val, style: V3Tokens.title2(p)),
        ],
      ),
    );
  }

  Widget _dateTile(V3Palette p, String label, String value, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: V3Tokens.caption(p)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: p.bgPrimary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.borderDefault),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value, style: V3Tokens.bodyMedium(p)),
                Icon(Icons.calendar_today_outlined, size: 15, color: p.iconSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
