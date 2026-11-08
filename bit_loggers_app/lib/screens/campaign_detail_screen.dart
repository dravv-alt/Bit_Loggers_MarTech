import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'campaign_wizard_screen.dart';

class CampaignDetailScreen extends StatefulWidget {
  final String campaignId;
  final ApiService api;

  const CampaignDetailScreen({super.key, required this.campaignId, required this.api});

  @override
  State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen> {
  Campaign? _campaign;
  bool _loading = true;
  List<DiscussionMessage> _discussions = [];
  List<Collaborator> _collaborators = [];
  DiscussionMessage? _replyingTo;
  String? _selectedVersionFilter;
  bool _anchorToVersion = true;
  bool _isInternalOnlyNote = false;
  bool _showMentionSuggestions = false;
  String _mentionQuery = '';
  bool _submittingComment = false;

  String _activeTab = 'Overview';
  final _reasonController = TextEditingController(text: 'Aligns with Q4 audience and budget policy');
  final _policyController = TextEditingController(text: 'MARTECH-POL-2026-Q4');
  bool _submittingDecision = false;

  // Schedule Flight Form (SCREEN 10)
  final DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  final DateTime _endDate = DateTime.now().add(const Duration(days: 15));
  String _scheduleChannel = 'Social';
  bool _submittingSchedule = false;

  // Discussion Form
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_onCommentChanged);
    _fetch();
  }

  @override
  void dispose() {
    _commentController.removeListener(_onCommentChanged);
    _commentController.dispose();
    _reasonController.dispose();
    _policyController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final c = await widget.api.getCampaign(widget.campaignId);
      final d = await widget.api.getDiscussions(widget.campaignId, versionId: _selectedVersionFilter);
      final collabs = await widget.api.getCollaborators(widget.campaignId);
      if (mounted) {
        setState(() {
          _campaign = c;
          _discussions = d;
          _collaborators = collabs;
          _scheduleChannel = c.currentVersion?.channel ?? 'Social';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnack(e.toString(), isError: true);
      }
    }
  }

  void _onCommentChanged() {
    final text = _commentController.text;
    final selection = _commentController.selection;
    if (!selection.isValid || selection.baseOffset < 0) {
      if (_showMentionSuggestions) setState(() => _showMentionSuggestions = false);
      return;
    }
    final cursor = selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursor);
    final lastAt = textBeforeCursor.lastIndexOf('@');
    if (lastAt != -1) {
      final query = textBeforeCursor.substring(lastAt + 1);
      if (!query.contains(' ') && query.length < 20) {
        setState(() {
          _showMentionSuggestions = true;
          _mentionQuery = query.toLowerCase();
        });
        return;
      }
    }
    if (_showMentionSuggestions) {
      setState(() => _showMentionSuggestions = false);
    }
  }

  void _insertMention(Collaborator c) {
    final text = _commentController.text;
    final selection = _commentController.selection;
    final cursor = selection.isValid ? selection.baseOffset : text.length;
    final textBeforeCursor = text.substring(0, cursor);
    final lastAt = textBeforeCursor.lastIndexOf('@');
    if (lastAt != -1) {
      final prefix = text.substring(0, lastAt);
      final suffix = text.substring(cursor);
      final replacement = '@${c.name} ';
      _commentController.value = TextEditingValue(
        text: '$prefix$replacement$suffix',
        selection: TextSelection.collapsed(offset: prefix.length + replacement.length),
      );
    }
    setState(() => _showMentionSuggestions = false);
  }

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _submittingComment = true);
    try {
      final versionId = _anchorToVersion && _campaign?.currentVersion != null
          ? _campaign!.currentVersion!.versionId
          : null;

      await widget.api.postDiscussion(
        widget.campaignId,
        content,
        parentMessageId: _replyingTo?.messageId,
        versionId: versionId,
        isInternalOnly: _isInternalOnlyNote,
      );

      _commentController.clear();
      setState(() {
        _replyingTo = null;
        _isInternalOnlyNote = false;
        _showMentionSuggestions = false;
        _submittingComment = false;
      });

      // Refresh discussions
      final d = await widget.api.getDiscussions(widget.campaignId, versionId: _selectedVersionFilter);
      if (mounted) setState(() => _discussions = d);
    } catch (e) {
      if (mounted) {
        setState(() => _submittingComment = false);
        _showSnack(e.toString(), isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: AppTheme.leaf)),
        backgroundColor: isError ? AppTheme.statusRejected : AppTheme.forge,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitReviewDecision(String type) async {
    if (_campaign == null || _campaign!.currentVersion == null) return;
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      _showSnack('Mandatory decision reason cannot be blank', isError: true);
      return;
    }

    setState(() => _submittingDecision = true);
    try {
      await widget.api.recordReviewDecision(
        campaignId: _campaign!.campaignId,
        versionId: _campaign!.currentVersion!.versionId,
        decisionType: type,
        reason: reason,
        policyRef: _policyController.text.trim().isNotEmpty ? _policyController.text.trim() : null,
      );
      _showSnack('Decision recorded: $type on v${_campaign!.currentVersion!.versionNo}');
      await _fetch();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _submittingDecision = false);
    }
  }

  Future<void> _confirmSchedule() async {
    if (_campaign == null || _campaign!.currentVersion == null) return;
    setState(() => _submittingSchedule = true);
    try {
      await widget.api.scheduleCampaign(
        _campaign!.campaignId,
        _campaign!.currentVersion!.versionId,
        _startDate.toIso8601String(),
        _endDate.toIso8601String(),
        _scheduleChannel,
      );
      _showSnack('Flight scheduled successfully for v${_campaign!.currentVersion!.versionNo}');
      await _fetch();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _submittingSchedule = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _campaign == null) {
      return const Scaffold(
        backgroundColor: AppTheme.paper,
        body: Center(
          child: Text('Loading dossier…', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ),
      );
    }

    final curVer = _campaign!.currentVersion;
    final isMarketer = widget.api.currentUser.role == 'marketer';
    final isReviewer = widget.api.currentUser.role == 'reviewer';
    final isApproved = _campaign!.status == 'Approved';
    final isSubmitted = _campaign!.status == 'Submitted';

    return Scaffold(
      backgroundColor: AppTheme.paper,
      appBar: AppBar(
        backgroundColor: AppTheme.paper,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isReviewer && isSubmitted ? 'Review proposal' : (isApproved ? 'Schedule status' : 'Proposal dossier'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        actions: [
          if (isMarketer && curVer != null)
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CampaignWizardScreen(
                      api: widget.api,
                      existingCampaign: _campaign,
                    ),
                  ),
                ).then((_) => _fetch());
              },
              child: const Text(
                '+ Revise',
                style: TextStyle(color: AppTheme.forge, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // If Reviewer and Status == Submitted: show SCREEN 08 "One last look."
          if (isReviewer && isSubmitted) ...[
            _buildReviewerDecisionScreen(),
          ]
          // If Status == Approved or Scheduled: show SCREEN 10 Schedule status / Version Guard
          else if (isApproved || _campaign!.status == 'Scheduled') ...[
            _buildScheduleStatusScreen(),
          ]
          // Default Dossier View
          else ...[
            _buildStandardDossierView(),
          ],
        ],
      ),
    );
  }

  // SCREEN 08 — Review Decision Details + Decision Form (matching Reference Image screen 3!)
  Widget _buildReviewerDecisionScreen() {
    final curVer = _campaign!.currentVersion;
    final isOwner = _campaign!.ownerId == widget.api.currentUser.id;
    final kpis = curVer?.kpiProjected ?? KpiMetrics(conversionRate: 3.5, ctr: 4.2, roi: 3.4, cpa: 14.2, aov: 88.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Editorial Serif Headline
        const Text(
          'One last look.',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 18),

        // Wireframe Bento Card holding proposal summary and reviewer identity
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.leaf,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderSage, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reviewer Identity row (Sarah Jenkins · Marketer • Self-approval blocked)
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.paper,
                    child: Text(
                      widget.api.currentUser.name.split(' ').map((n) => n[0]).take(2).join(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.forge),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.api.currentUser.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                        ),
                        Text(
                          isOwner ? 'Owner • Self-approval blocked' : 'Reviewer • Independent verification',
                          style: TextStyle(
                            fontSize: 11,
                            color: isOwner ? AppTheme.statusChanges : AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(color: AppTheme.borderSage, height: 1),
              ),

              // Two-column tabular list
              _buildTwoColRow('Exact version', 'Version v${curVer?.versionNo ?? 3}', isForgeBadge: true),
              const SizedBox(height: 10),
              _buildTwoColRow(
                'Proposed budget',
                '\$${(curVer?.budget ?? 45000).toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}.00',
              ),
              const SizedBox(height: 10),
              _buildTwoColRow(
                'Target KPI (CPA / AOV)',
                '\$${kpis.cpa.toStringAsFixed(2)} / \$${kpis.aov.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 10),
              _buildTwoColRow(
                'Mandatory reason',
                '"${_reasonController.text.trim()}"',
                italicValue: true,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(color: AppTheme.borderSage, height: 1),
              ),

              // Projected ROI
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Projected ROI', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  Text(
                    '${kpis.roi}x',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Immutability Notice
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.paper,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderSage, width: 0.8),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 14, color: AppTheme.textSecondary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Reason is mandatory and immutable once recorded. Next action simulates approval.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Primary Action: Approve Version V3 ↗ (Forge #20211F)
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: isOwner || _submittingDecision
                ? null
                : () => _submitReviewDecision('APPROVED'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.forge,
              foregroundColor: AppTheme.leaf,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _submittingDecision
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: AppTheme.leaf, strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Approve version v${curVer?.versionNo ?? 3}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.north_east, size: 15),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),

        // Secondary Text Action: Request changes or reject
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            onPressed: isOwner || _submittingDecision
                ? null
                : () => _showRejectionDialog(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimary,
              side: const BorderSide(color: AppTheme.borderSage, width: 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Request changes or reject',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  void _showRejectionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.leaf,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.borderSage),
        ),
        title: const Text(
          'Review action',
          style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter mandatory written justification reason:',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Specify required adjustments or policy reason…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitReviewDecision('CHANGES_REQUESTED');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusChanges,
              foregroundColor: AppTheme.leaf,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Text('Request changes', style: TextStyle(color: AppTheme.leaf, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitReviewDecision('REJECTED');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusRejected,
              foregroundColor: AppTheme.leaf,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Text('Reject', style: TextStyle(color: AppTheme.leaf, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // SCREEN 10 — Version Guard & Schedule Status (matching Reference Image screen 4!)
  Widget _buildScheduleStatusScreen() {
    final curVer = _campaign!.currentVersion;
    final isScheduled = _campaign!.status == 'Scheduled';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 10),
        // Lime circle with checkmark
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppTheme.verdictLime,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.check, size: 32, color: AppTheme.forge),
          ),
        ),
        const SizedBox(height: 18),

        // Serif Headline
        Text(
          isScheduled ? 'Scheduled, version v${curVer?.versionNo ?? 3}.' : 'Approved, version v${curVer?.versionNo ?? 3}.',
          style: const TextStyle(
            fontFamily: 'serif',
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Decision committed in 1 transaction. Outbox queued.',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 24),

        // Wireframe Bento Card: Version Guard & Ledger
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.leaf,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderSage, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Scheduled slot
              const Center(
                child: Column(
                  children: [
                    Text(
                      'SCHEDULED SLOT',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.12),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Oct 24, 10:00',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(color: AppTheme.borderSage, height: 1),
              ),

              // Version Progression Ledger
              _buildLedgerRow(
                'Version v1',
                'Superseded (409 Blocked)',
                textColor: AppTheme.statusRejected,
                badgeBg: AppTheme.paper,
              ),
              const SizedBox(height: 10),
              _buildLedgerRow(
                'Version v2',
                'Changes requested',
                textColor: AppTheme.statusChanges,
              ),
              const SizedBox(height: 10),
              _buildLedgerRow(
                'Version v${curVer?.versionNo ?? 3}',
                'Approved & Current',
                textColor: AppTheme.forge,
                isBold: true,
              ),
              const SizedBox(height: 10),
              _buildLedgerRow(
                'Outbox status',
                'Email Retry #2 (Approval Safe)',
                textColor: AppTheme.textSecondary,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Status', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isScheduled ? const Color(0xFFE5EDF7) : const Color(0xFFE6F4EA),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isScheduled ? 'Scheduled' : 'Approved',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isScheduled ? const Color(0xFF234C82) : const Color(0xFF137333),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Marketer Schedule CTA if approved but not yet scheduled
        if (!isScheduled && widget.api.currentUser.role == 'marketer') ...[
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _submittingSchedule ? null : _confirmSchedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.forge,
                foregroundColor: AppTheme.leaf,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _submittingSchedule
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: AppTheme.leaf, strokeWidth: 2),
                    )
                  : const Text('Confirm flight launch', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildStandardDossierView() {
    final curVer = _campaign!.currentVersion;
    final kpis = curVer?.kpiProjected ?? KpiMetrics(conversionRate: 3.5, ctr: 4.2, roi: 3.4, cpa: 14.2, aov: 88.5);
    final idPrefix = _campaign!.campaignId.length >= 4 ? _campaign!.campaignId.substring(0, 4).toUpperCase() : _campaign!.campaignId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Row with Status Indicator
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _campaign!.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            AppTheme.buildStatusIndicator(_campaign!.status),
          ],
        ),
        const SizedBox(height: 6),
        // Unified scannable metadata line
        Text(
          'CG-$idPrefix · Owner: ${_campaign!.ownerName} • Current Status: ${_campaign!.status}',
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 16),

        // Wireframe Segmented Tabs (Overview | Versions | Discussion | Activity)
        _buildSegmentedTabBar(),
        const SizedBox(height: 16),

        // Bento 1: Campaign Details Spec Matrix
        _buildBentoSpecMatrix(curVer),
        const SizedBox(height: 14),

        // Bento 2: Version Lineage Stepper
        _buildVersionHistoryStepper(curVer),
        const SizedBox(height: 14),

        // Bento 3: Changes Diff & Creative Strategy
        _buildDiffBentoTile(curVer),
        const SizedBox(height: 14),

        // Bento 4: 5 Projected Campaign KPIs Economics Matrix
        _buildEconomicsBentoMatrix(kpis),
        const SizedBox(height: 16),

        // Bento 5: Decision Actions Bar
        _buildDecisionActionsBar(curVer),
        const SizedBox(height: 20),

        // Discussions (FR-12 Collaboration & Version Anchoring)
        _buildDiscussionsCard(),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildSegmentedTabBar() {
    final tabs = ['Overview', 'Versions', 'Discussion', 'Activity'];

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSage, width: 0.8),
      ),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _activeTab == tab;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = tab),
              borderRadius: BorderRadius.circular(7),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.leaf : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: isSelected ? Border.all(color: AppTheme.borderSage, width: 0.8) : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBentoSpecMatrix(CampaignVersion? curVer) {
    final budgetStr = (curVer?.budget ?? 45000).toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSage, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CAMPAIGN DETAILS',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildBentoCell('Channel', curVer?.channel ?? 'Paid social'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBentoCell('Budget cap', '\$$budgetStr · configured'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildBentoCell('Flight', '12–26 Nov'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBentoCell('Current version', '0${curVer?.versionNo ?? 1} · ${_campaign!.status}'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBentoCell(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSage, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionHistoryStepper(CampaignVersion? curVer) {
    final curNo = curVer?.versionNo ?? 1;

    final steps = [
      {'num': '01', 'label': 'Created', 'active': true},
      {'num': '02', 'label': 'Review', 'active': curNo >= 2},
      {'num': '03', 'label': 'Edited', 'active': curNo >= 3},
      {'num': '04', 'label': 'Current', 'active': curNo >= 4},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSage, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Version history',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              InkWell(
                onTap: () => setState(() => _activeTab = 'Versions'),
                child: const Row(
                  children: [
                    Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.north_east, size: 11, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(steps.length, (idx) {
              final s = steps[idx];
              final isCurrent = idx == steps.length - 1 || s['num'] == '0$curNo';
              final isActive = s['active'] as bool;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: idx < steps.length - 1 ? 6 : 0),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCurrent ? AppTheme.forge : (isActive ? AppTheme.paper : AppTheme.canvas),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCurrent ? AppTheme.forge : AppTheme.borderSage,
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['num'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: isCurrent ? AppTheme.leaf : (isActive ? AppTheme.textPrimary : AppTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s['label'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isCurrent ? AppTheme.leaf.withOpacity(0.9) : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffBentoTile(CampaignVersion? curVer) {
    final verNo = curVer?.versionNo ?? 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSage, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Changes in version 0$verNo',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildDiffRow('Audience exclusions', 'Updated', isUpdated: true),
          const SizedBox(height: 8),
          _buildDiffRow('Primary CTA', 'Changed', isChanged: true),
          const SizedBox(height: 8),
          _buildDiffRow('Budget cap', 'Unchanged', isUnchanged: true),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppTheme.borderSage),
          const SizedBox(height: 12),
          const Text(
            'Strategic objective',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            curVer?.objective ?? '',
            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.4),
          ),
          const SizedBox(height: 12),
          const Text(
            'Target audience persona',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            curVer?.targetAudience ?? '',
            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffRow(String label, String status, {bool isUpdated = false, bool isChanged = false, bool isUnchanged = false}) {
    Color textColor = AppTheme.textSecondary;
    Color bgColor = AppTheme.paper;
    if (isUpdated) {
      textColor = const Color(0xFF137333);
      bgColor = const Color(0xFFE6F4EA);
    } else if (isChanged) {
      textColor = const Color(0xFF8A542C);
      bgColor = const Color(0xFFF8EBDD);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppTheme.borderSage, width: 0.5),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEconomicsBentoMatrix(KpiMetrics kpis) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSage, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '5 Projected campaign KPIs',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildTwoColRow('Conversion Rate', '${kpis.conversionRate}%'),
          const SizedBox(height: 8),
          _buildTwoColRow('Click-Through Rate (CTR)', '${kpis.ctr}%'),
          const SizedBox(height: 8),
          _buildTwoColRow('Return on Investment (ROI)', '${kpis.roi}x'),
          const SizedBox(height: 8),
          _buildTwoColRow('Cost Per Acquisition (CPA)', '\$${kpis.cpa.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _buildTwoColRow('Average Order Value (AOV)', '\$${kpis.aov.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _buildDecisionActionsBar(CampaignVersion? curVer) {
    final isOwner = _campaign!.ownerId == widget.api.currentUser.id;
    final verNo = curVer?.versionNo ?? 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSage, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REVIEW DECISION  ·  VERSION 0$verNo',
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: isOwner || _submittingDecision
                        ? null
                        : () => _submitReviewDecision('APPROVED'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.forge,
                      foregroundColor: AppTheme.leaf,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _submittingDecision
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: AppTheme.leaf, strokeWidth: 2),
                          )
                        : const Text(
                            'Approve',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton(
                    onPressed: isOwner || _submittingDecision
                        ? null
                        : () => _showRejectionDialog(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      side: const BorderSide(color: AppTheme.borderSage, width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Request changes',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiscussionsCard() {
    final topLevel = _discussions
        .where((d) => d.parentMessageId == null || !_discussions.any((p) => p.messageId == d.parentMessageId))
        .toList();
    final isReviewer = widget.api.currentUser.role.toLowerCase().contains('reviewer');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSage, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  const Text(
                    'Discussions & Threads',
                    style: TextStyle(fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.paper,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderSage),
                    ),
                    child: Text(
                      '${_discussions.length}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.forge),
                    ),
                  ),
                ],
              ),
              const Text(
                'FR-12 Anchored',
                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Version Filter Bar
          _buildVersionFilterBar(),
          const SizedBox(height: 14),

          // Message list
          if (_discussions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  _selectedVersionFilter != null
                      ? 'No discussion anchored to this version yet.'
                      : 'No discussion entries yet. Marketers and Reviewers can collaborate here.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
            )
          else
            ...topLevel.map((topMsg) {
              final replies = _discussions.where((d) => d.parentMessageId == topMsg.messageId).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDiscussionItem(topMsg, isReply: false),
                  if (replies.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 14, bottom: 8),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(width: 2, color: AppTheme.borderSage),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                children: replies.map((r) => _buildDiscussionItem(r, isReply: true)).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            }),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.borderSage),
          const SizedBox(height: 12),

          // Replying banner
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.paper,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderSage),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, size: 14, color: AppTheme.forge),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Replying to ${_replyingTo!.authorName}: "${_replyingTo!.content.length > 32 ? '${_replyingTo!.content.substring(0, 30)}...' : _replyingTo!.content}"',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _replyingTo = null),
                    child: const Icon(Icons.close, size: 14, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),

          // Mention suggestions autocomplete overlay
          _buildMentionSuggestions(),

          // Composer Toolbar: Anchor to version & Internal note
          Row(
            children: [
              InkWell(
                onTap: () => setState(() => _anchorToVersion = !_anchorToVersion),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _anchorToVersion ? AppTheme.forge : AppTheme.paper,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.borderSage),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.anchor, size: 12, color: _anchorToVersion ? AppTheme.verdictLime : AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'v${_campaign?.currentVersion?.versionNo ?? 1}.0 Anchor',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _anchorToVersion ? AppTheme.leaf : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isReviewer) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => setState(() => _isInternalOnlyNote = !_isInternalOnlyNote),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isInternalOnlyNote ? const Color(0xFF8A4620) : AppTheme.paper,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _isInternalOnlyNote ? const Color(0xFF8A4620) : AppTheme.borderSage),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 12, color: _isInternalOnlyNote ? AppTheme.leaf : AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Internal Note',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _isInternalOnlyNote ? AppTheme.leaf : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const Spacer(),
              const Text(
                'Type @ to mention',
                style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Input field and send button
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: _isInternalOnlyNote
                        ? 'Write internal reviewer note (hidden from marketer)…'
                        : (_replyingTo != null ? 'Write reply to ${_replyingTo!.authorName}…' : 'Add note, feedback, or @mention…'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    prefixIcon: IconButton(
                      icon: const Icon(Icons.alternate_email, size: 16, color: AppTheme.textSecondary),
                      onPressed: () {
                        final text = _commentController.text;
                        _commentController.text = '$text@';
                        _commentController.selection = TextSelection.collapsed(offset: _commentController.text.length);
                        _onCommentChanged();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                width: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.forge,
                    foregroundColor: AppTheme.leaf,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _submittingComment ? null : _postComment,
                  child: _submittingComment
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppTheme.leaf, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVersionFilterBar() {
    final versions = _campaign?.versions ?? [];
    if (versions.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: const Text('All Versions'),
              selected: _selectedVersionFilter == null,
              selectedColor: AppTheme.forge,
              backgroundColor: AppTheme.paper,
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: _selectedVersionFilter == null ? FontWeight.bold : FontWeight.normal,
                color: _selectedVersionFilter == null ? AppTheme.leaf : AppTheme.textPrimary,
              ),
              side: BorderSide(
                color: _selectedVersionFilter == null ? AppTheme.forge : AppTheme.borderSage,
              ),
              visualDensity: VisualDensity.compact,
              onSelected: (val) {
                if (val) {
                  setState(() => _selectedVersionFilter = null);
                  _fetch();
                }
              },
            ),
          ),
          ...versions.map((v) {
            final isSelected = _selectedVersionFilter == v.versionId;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text('v${v.versionNo}.0 (${v.channel})'),
                selected: isSelected,
                selectedColor: AppTheme.forge,
                backgroundColor: AppTheme.paper,
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.leaf : AppTheme.textPrimary,
                ),
                side: BorderSide(
                  color: isSelected ? AppTheme.forge : AppTheme.borderSage,
                ),
                visualDensity: VisualDensity.compact,
                onSelected: (val) {
                  setState(() => _selectedVersionFilter = val ? v.versionId : null);
                  _fetch();
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMentionSuggestions() {
    if (!_showMentionSuggestions) return const SizedBox.shrink();

    final filtered = _collaborators.where((c) {
      final nameMatches = c.name.toLowerCase().contains(_mentionQuery);
      final roleMatches = c.role.toLowerCase().contains(_mentionQuery);
      return nameMatches || roleMatches;
    }).toList();

    if (filtered.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      constraints: const BoxConstraints(maxHeight: 140),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.forge, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderSage),
        itemBuilder: (context, idx) {
          final c = filtered[idx];
          return InkWell(
            onTap: () => _insertMention(c),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppTheme.forge,
                    child: Text(
                      c.name.isNotEmpty ? c.name[0] : '?',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.leaf),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c.name,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.paper,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.borderSage),
                    ),
                    child: Text(
                      c.role.toUpperCase(),
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDiscussionItem(DiscussionMessage msg, {bool isReply = false}) {
    final initials = msg.authorName.isNotEmpty
        ? msg.authorName.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join()
        : '?';
    final isReviewer = msg.authorRole.toLowerCase().contains('reviewer');

    return Container(
      margin: EdgeInsets.only(bottom: isReply ? 8 : 10),
      padding: EdgeInsets.all(isReply ? 10 : 12),
      decoration: BoxDecoration(
        color: msg.isInternalOnly ? const Color(0xFFFBF4ED) : (isReply ? AppTheme.paper.withOpacity(0.5) : AppTheme.paper),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: msg.isInternalOnly ? const Color(0xFFE2C2A8) : AppTheme.borderSage,
          width: msg.isInternalOnly ? 1.2 : 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: isReply ? 10 : 12,
                backgroundColor: isReviewer ? const Color(0xFF3B5249) : AppTheme.forge,
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: isReply ? 9 : 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.leaf,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      msg.authorName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isReviewer ? AppTheme.forge : AppTheme.leaf,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.borderSage, width: 0.5),
                      ),
                      child: Text(
                        msg.authorRole.toUpperCase(),
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: isReviewer ? AppTheme.verdictLime : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    if (msg.versionNo != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.leaf,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.borderSage, width: 0.8),
                        ),
                        child: Text(
                          'v${msg.versionNo}.0',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    if (msg.isInternalOnly)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2C2A8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock, size: 9, color: Color(0xFF7A3E1D)),
                            SizedBox(width: 2),
                            Text(
                              'INTERNAL NOTE',
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF7A3E1D)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (!isReply)
                InkWell(
                  onTap: () {
                    setState(() {
                      _replyingTo = msg;
                      if (msg.versionId != null) {
                        _anchorToVersion = true;
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.reply_rounded, size: 14, color: AppTheme.textSecondary),
                        SizedBox(width: 3),
                        Text('Reply', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          _buildRichContent(msg.content),
        ],
      ),
    );
  }

  Widget _buildRichContent(String text) {
    final words = text.split(' ');
    final spans = <TextSpan>[];

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final isLast = i == words.length - 1;
      final space = isLast ? '' : ' ';

      if (word.startsWith('@') && word.length > 1) {
        spans.add(
          TextSpan(
            text: '$word$space',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.forge,
              backgroundColor: Color(0x33D7F46A),
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: '$word$space',
            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.35),
          ),
        );
      }
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildTwoColRow(String label, String value, {bool isForgeBadge = false, bool italicValue = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        if (isForgeBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.paper,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderSage, width: 1),
            ),
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.forge),
            ),
          )
        else
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              fontStyle: italicValue ? FontStyle.italic : FontStyle.normal,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }

  Widget _buildLedgerRow(String label, String value, {Color? textColor, Color? badgeBg, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        Container(
          padding: badgeBg != null ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2) : EdgeInsets.zero,
          decoration: badgeBg != null
              ? BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6))
              : null,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: textColor ?? AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
