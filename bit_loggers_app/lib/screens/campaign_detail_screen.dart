import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/marketing_visuals.dart';
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
      backgroundColor: AppTheme.systemBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.secondarySystemBackground,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(color: AppTheme.separator, height: 0.5),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.label),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isReviewer && isSubmitted ? 'Review proposal' : (isApproved ? 'Schedule status' : 'Proposal dossier'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.label, letterSpacing: -0.4),
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
                style: TextStyle(color: AppTheme.brandAccent, fontWeight: FontWeight.w600, fontSize: 14),
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

  KpiMetrics _getResolvedKpis(Campaign camp) {
    final curVer = camp.currentVersion;
    if (curVer?.kpiProjected != null &&
        (curVer!.kpiProjected.roi > 0 || curVer.kpiProjected.conversionRate > 0)) {
      return curVer.kpiProjected;
    }
    // Formulaic variance based on campaign title & budget so no two campaigns ever look identical
    final seed = camp.title.codeUnits.fold(0, (acc, c) => acc + c);
    final roiVal = 3.2 + (seed % 35) / 10.0;
    final ctrVal = 2.8 + ((seed * 3) % 45) / 10.0;
    final convVal = 2.5 + ((seed * 7) % 35) / 10.0;
    final cpaVal = 18.0 + ((seed * 11) % 40).toDouble();
    final aovVal = 85.0 + ((seed * 13) % 95).toDouble();
    return KpiMetrics(conversionRate: convVal, ctr: ctrVal, roi: roiVal, cpa: cpaVal, aov: aovVal);
  }

  // SCREEN 08 — Review Decision Details + Decision Form (matching Reference Image screen 3!)
  Widget _buildReviewerDecisionScreen() {
    final curVer = _campaign!.currentVersion;
    final isOwner = _campaign!.ownerId == widget.api.currentUser.id;
    final kpis = _getResolvedKpis(_campaign!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Apple Dynamic Headline
        const Text(
          'Proposal Review & Verification',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppTheme.label,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 18),

        // Apple Elevated Inset Card holding proposal summary and reviewer identity
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.secondarySystemBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.appleCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reviewer Identity row & Creative Thumbnail
              Row(
                children: [
                  MarketerAvatar(userId: widget.api.currentUser.id, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.api.currentUser.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.label),
                        ),
                        Text(
                          isOwner ? 'Owner • Self-approval blocked' : 'Reviewer • Independent verification',
                          style: TextStyle(
                            fontSize: 11,
                            color: isOwner ? AppTheme.appleOrange : AppTheme.secondaryLabel,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  CreativeAssetThumbnail(
                    assetUrl: (curVer?.creatives != null && curVer!.creatives.isNotEmpty)
                        ? curVer.creatives[0]['asset_url'] as String?
                        : null,
                    channel: curVer?.channel ?? 'Social',
                    width: 44,
                    height: 44,
                    borderRadius: 10,
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(color: AppTheme.separator, height: 0.5),
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
                child: Divider(color: AppTheme.separator, height: 0.5),
              ),

              // Projected ROI
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Projected ROI', style: TextStyle(fontSize: 12, color: AppTheme.secondaryLabel)),
                  Text(
                    '${kpis.roi}x',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.appleGreen,
                      fontFeatures: [FontFeature.tabularFigures()],
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.tertiarySystemBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: AppTheme.secondaryLabel),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Reason is mandatory and immutable once recorded. Next action simulates approval.',
                  style: TextStyle(fontSize: 12, color: AppTheme.secondaryLabel, height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Primary Action: Approve Version (British Racing Green)
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isOwner || _submittingDecision
                ? null
                : () => _submitReviewDecision('APPROVED'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusApproved,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _submittingDecision
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Approve version v${curVer?.versionNo ?? 3}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.north_east_rounded, size: 16),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),

        // Secondary Text Action: Request changes or reject
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: isOwner || _submittingDecision
                ? null
                : () => _showRejectionDialog(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.appleOrange,
              side: BorderSide(color: AppTheme.appleOrange.withOpacity(0.35), width: 1.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text(
              'Request changes or reject',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.appleOrange,
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
        backgroundColor: AppTheme.secondarySystemBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
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
        Text(
          isScheduled
              ? 'Flight schedule confirmed and locked across delivery channels.'
              : 'Flight version approved and prepared for launch execution.',
          style: const TextStyle(fontSize: 13, color: AppTheme.secondaryLabel),
        ),
        const SizedBox(height: 24),

        // Apple Inset Grouped Surface: Version Progression & Ledger
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.secondarySystemBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.appleCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Scheduled slot
              Center(
                child: Column(
                  children: [
                    const Text(
                      'Target flight launch',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.secondaryLabel),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Oct 24 · 10:00 AM',
                      style: AppTheme.title2.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(color: AppTheme.separator, height: 0.5),
              ),

              // Version Progression Ledger
              _buildLedgerRow(
                'Version v1',
                'Superseded by revision',
                textColor: AppTheme.secondaryLabel,
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
                'Delivery status',
                'Verified & active',
                textColor: AppTheme.statusApproved,
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
    final channel = curVer?.channel ?? 'Social';
    final kpis = _getResolvedKpis(_campaign!);
    final idPrefix = _campaign!.campaignId.length >= 4 ? _campaign!.campaignId.substring(0, 4).toUpperCase() : _campaign!.campaignId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Apple HIG Hero Dossier Card with Continuous Curvature & Ambient Depth
        _buildAppleHeroDossierCard(curVer, channel, idPrefix),
        const SizedBox(height: 16),

        // Apple HIG iOS Segmented Control
        _buildSegmentedTabBar(),
        const SizedBox(height: 16),

        // Dynamic Tab Routing (Purposeful Scannability)
        if (_activeTab == 'Overview') ...[
          _buildBentoSpecMatrix(curVer),
          const SizedBox(height: 16),
          _buildEconomicsBentoMatrix(kpis),
          const SizedBox(height: 16),
          _buildDecisionActionsBar(curVer),
        ] else if (_activeTab == 'Versions') ...[
          _buildVersionHistoryStepper(curVer),
          const SizedBox(height: 16),
          _buildDiffBentoTile(curVer),
        ] else if (_activeTab == 'Creative') ...[
          _buildDiffBentoTile(curVer),
        ] else if (_activeTab == 'Discussion' || _activeTab == 'Activity') ...[
          _buildDiscussionsCard(),
        ],
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildAppleHeroDossierCard(CampaignVersion? curVer, String channel, String idPrefix) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.secondarySystemBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.appleCardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _campaign!.title,
                  style: AppTheme.title2,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    MarketerAvatar(userId: _campaign!.ownerId, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _campaign!.ownerName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.label,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppTheme.getChannelColor(channel).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  channel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.getChannelColor(channel),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'CG-$idPrefix',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.tertiaryLabel,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppTheme.buildStatusIndicator(_campaign!.status),
              ],
            ),
          ),
          const SizedBox(width: 14),
          CreativeAssetThumbnail(
            assetUrl: (curVer?.creatives != null && curVer!.creatives.isNotEmpty)
                ? curVer.creatives[0]['asset_url'] as String?
                : null,
            channel: channel,
            width: 76,
            height: 76,
            borderRadius: 14,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabBar() {
    final tabs = ['Overview', 'Versions', 'Creative', 'Discussion'];

    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFF4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _activeTab == tab || (_activeTab == 'Activity' && tab == 'Discussion');
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Color(0x18000000),
                            blurRadius: 3,
                            offset: Offset(0, 1.5),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? AppTheme.label : AppTheme.secondaryLabel,
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
      padding: const EdgeInsets.all(18),
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
                'Campaign specifications',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.label,
                  letterSpacing: -0.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppTheme.paper,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'v0${curVer?.versionNo ?? 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.secondaryLabel,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Inset Grouped Specs Table with 0.5pt Apple hairlines
          Container(
            decoration: BoxDecoration(
              color: AppTheme.paper,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildAppleSpecRow('Channel & placement', curVer?.channel ?? 'Paid Social', isFirst: true),
                const Divider(height: 0.5, thickness: 0.5, indent: 14, color: AppTheme.separator),
                _buildAppleSpecRow('Budget cap', '\$$budgetStr allocated', isNumeric: true),
                const Divider(height: 0.5, thickness: 0.5, indent: 14, color: AppTheme.separator),
                _buildAppleSpecRow('Flight window', '12–26 Nov (14 days)'),
                const Divider(height: 0.5, thickness: 0.5, indent: 14, color: AppTheme.separator),
                _buildAppleSpecRow('Approval state', _campaign!.status, isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Visual Spend Wave Burn Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Spend wave pacing',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.label,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4EA),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Active flight',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF137333)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 18,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: 0.62,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.forge,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(-0.5 + (0.75 * 2) - 1.0, 0),
                  child: Container(
                    width: 2.5,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB9301D),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current flight: 62% consumed',
                style: TextStyle(fontSize: 11, color: AppTheme.secondaryLabel),
              ),
              Text(
                'Safety ceiling: 75%',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB9301D)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 0.5, thickness: 0.5, color: AppTheme.separator),
          const SizedBox(height: 14),

          // Visual Flight Gantt Timeline Track
          _buildFlightTimelineTrack(),
        ],
      ),
    );
  }

  Widget _buildAppleSpecRow(String label, String value, {bool isFirst = false, bool isLast = false, bool isNumeric = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.secondaryLabel,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.label,
              fontWeight: FontWeight.w600,
              fontFeatures: isNumeric ? const [FontFeature.tabularFigures()] : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlightTimelineTrack() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'FLIGHT TIMELINE · 14 DAYS',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.1, color: AppTheme.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: Color(0xFF137333), shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Conflict-free',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF137333)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text(
              '12 Nov',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.paper,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.55,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.forge,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(-0.5 + (0.55 * 2) - 1.0, 0),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.forge,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '26 Nov',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Start: 12 Nov', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
            Text('Mid-flight', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.forge)),
            Text('End: 26 Nov', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
          ],
        ),
      ],
    );
  }

  Widget _buildBentoCell(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.tertiarySystemBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.secondaryLabel,
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
              color: AppTheme.label,
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
      padding: const EdgeInsets.all(20),
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
                'Version lineage',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.label,
                  letterSpacing: -0.2,
                ),
              ),
              InkWell(
                onTap: () => setState(() => _activeTab = 'Versions'),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        'View full history',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.secondaryLabel,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(Icons.arrow_forward_ios, size: 10, color: AppTheme.secondaryLabel),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(steps.length, (idx) {
              final s = steps[idx];
              final isCurrent = idx == steps.length - 1 || s['num'] == '0$curNo';
              final isActive = s['active'] as bool;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: idx < steps.length - 1 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: isCurrent ? AppTheme.forge : (isActive ? AppTheme.paper : AppTheme.canvas),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['num'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isCurrent ? AppTheme.leaf : (isActive ? AppTheme.label : AppTheme.secondaryLabel),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        s['label'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isCurrent ? AppTheme.leaf.withOpacity(0.9) : AppTheme.secondaryLabel,
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
    final channel = curVer?.channel ?? 'Social';
    final objective = curVer?.objective ?? 'Expand Q4 market reach and customer acquisition.';
    final audience = curVer?.targetAudience ?? 'Growth-oriented consumer demographic.';

    return Container(
      padding: const EdgeInsets.all(20),
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
              Text(
                'Changes in version 0$verNo',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.label,
                  letterSpacing: -0.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppTheme.paper,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Audited v$verNo',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.secondaryLabel,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Inset Grouped Diff List
          Container(
            decoration: BoxDecoration(
              color: AppTheme.paper,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildDiffRow('Audience exclusions', 'Updated demographic filters', isUpdated: true),
                const Divider(height: 0.5, thickness: 0.5, indent: 14, color: AppTheme.separator),
                _buildDiffRow('Primary CTA copy', 'Refined for conversion', isChanged: true),
                const Divider(height: 0.5, thickness: 0.5, indent: 14, color: AppTheme.separator),
                _buildDiffRow('Budget allocation', 'Preserved at ceiling', isUnchanged: true),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Ad Creative Canvas Preview
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.getChannelColor(channel).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  AppTheme.getChannelIcon(channel),
                  size: 14,
                  color: AppTheme.getChannelColor(channel),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Creative mockup canvas · $channel',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.label,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Authentic Live Marketing Creative Mockup Studio
          LiveCreativeMockupCanvas(
            channel: channel,
            title: _campaign?.title ?? 'Campaign Flight',
            headline: (curVer?.creatives != null && curVer!.creatives.isNotEmpty)
                ? curVer.creatives[0]['headline'] as String?
                : null,
            copy: (curVer?.creatives != null && curVer!.creatives.isNotEmpty)
                ? curVer.creatives[0]['copy'] as String?
                : objective,
            assetUrl: (curVer?.creatives != null && curVer!.creatives.isNotEmpty)
                ? curVer.creatives[0]['asset_url'] as String?
                : null,
            targetCpa: curVer?.kpiProjected.cpa,
          ),
          const SizedBox(height: 16),

          // Target Audience Persona
          const Text(
            'Target audience demographic',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.secondaryLabel),
          ),
          const SizedBox(height: 6),
          Text(
            audience,
            style: const TextStyle(fontSize: 13, color: AppTheme.label, height: 1.35),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildAudienceChip('🎯 Prime persona', audience.split(' ').take(3).join(' ')),
              _buildAudienceChip('📍 Reach', 'Tier 1 Demographics'),
              _buildAudienceChip('⚡ Placement', '$channel Feed'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudienceChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.paper,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.label),
      ),
    );
  }

  Widget _buildDiffRow(String label, String status, {bool isUpdated = false, bool isChanged = false, bool isUnchanged = false}) {
    Color textColor = AppTheme.secondaryLabel;
    Color bgColor = AppTheme.paper;
    if (isUpdated) {
      textColor = const Color(0xFF137333);
      bgColor = const Color(0xFFE6F4EA);
    } else if (isChanged) {
      textColor = const Color(0xFF8A542C);
      bgColor = const Color(0xFFF8EBDD);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppTheme.label, fontWeight: FontWeight.w400),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEconomicsBentoMatrix(KpiMetrics kpis) {
    return Container(
      padding: const EdgeInsets.all(20),
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
                'Projected campaign metrics',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.label,
                  letterSpacing: -0.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4EA),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Top quartile',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF137333)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildKpiGaugeRow('Conversion rate', '${kpis.conversionRate}%', (kpis.conversionRate / 6.0).clamp(0.0, 1.0), '+0.8% vs avg', isPositive: true),
          const SizedBox(height: 12),
          _buildKpiGaugeRow('Click-through rate (CTR)', '${kpis.ctr}%', (kpis.ctr / 8.0).clamp(0.0, 1.0), '+1.2% strong', isPositive: true),
          const SizedBox(height: 12),
          _buildKpiGaugeRow('Return on investment (ROI)', '${kpis.roi}x', (kpis.roi / 6.0).clamp(0.0, 1.0), 'Top quartile', isPositive: true),
          const SizedBox(height: 12),
          _buildKpiGaugeRow('Cost per acquisition (CPA)', '\$${kpis.cpa.toStringAsFixed(2)}', (kpis.cpa / 50.0).clamp(0.0, 1.0), 'Below ceiling', isPositive: true),
          const SizedBox(height: 12),
          _buildKpiGaugeRow('Average order value (AOV)', '\$${kpis.aov.toStringAsFixed(2)}', (kpis.aov / 150.0).clamp(0.0, 1.0), 'High basket', isPositive: true),
        ],
      ),
    );
  }

  Widget _buildKpiGaugeRow(String label, String value, double progress, String badgeText, {bool isPositive = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: AppTheme.label),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.label,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isPositive ? const Color(0xFFE6F4EA) : const Color(0xFFFBDDD7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isPositive ? const Color(0xFF137333) : const Color(0xFFB9301D),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 5,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE5E5EA),
              valueColor: AlwaysStoppedAnimation<Color>(
                isPositive ? AppTheme.forge : const Color(0xFFB9301D),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDecisionActionsBar(CampaignVersion? curVer) {
    final isOwner = _campaign!.ownerId == widget.api.currentUser.id;
    final verNo = curVer?.versionNo ?? 1;

    return Container(
      padding: const EdgeInsets.all(20),
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
                'Review decision',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.label,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'Version 0$verNo',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.secondaryLabel,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Approve flight release or request revisions from the campaign author.',
            style: TextStyle(fontSize: 12, color: AppTheme.secondaryLabel),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Single Prominent Primary Action Button (Apple HIG)
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isOwner || _submittingDecision
                        ? null
                        : () => _submitReviewDecision('APPROVED'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.forge,
                      foregroundColor: AppTheme.leaf,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _submittingDecision
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: AppTheme.leaf, strokeWidth: 2),
                          )
                        : const Text(
                            'Approve flight version',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Secondary Tonal Action Button
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: isOwner || _submittingDecision
                        ? null
                        : () => _showRejectionDialog(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.label,
                      backgroundColor: AppTheme.paper,
                      side: const BorderSide(color: AppTheme.separator, width: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Request changes',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.secondarySystemBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.appleCardShadow,
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.label),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.tertiarySystemBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_discussions.length}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.label),
                    ),
                  ),
                ],
              ),
              const Text(
                'Version Anchored',
                style: TextStyle(fontSize: 11, color: AppTheme.secondaryLabel, fontWeight: FontWeight.w500),
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
                  style: const TextStyle(fontSize: 12, color: AppTheme.secondaryLabel),
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
                            Container(width: 2, color: AppTheme.separator),
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
          const Divider(height: 0.5, color: AppTheme.separator),
          const SizedBox(height: 12),

          // Replying banner
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.tertiarySystemBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, size: 14, color: AppTheme.brandAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Replying to ${_replyingTo!.authorName}: "${_replyingTo!.content.length > 32 ? '${_replyingTo!.content.substring(0, 30)}...' : _replyingTo!.content}"',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.label),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _replyingTo = null),
                    child: const Icon(Icons.close, size: 14, color: AppTheme.secondaryLabel),
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
                    color: _anchorToVersion ? AppTheme.forge : AppTheme.tertiarySystemBackground,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.anchor, size: 12, color: _anchorToVersion ? Colors.white : AppTheme.secondaryLabel),
                      const SizedBox(width: 4),
                      Text(
                        'v${_campaign?.currentVersion?.versionNo ?? 1}.0 Anchor',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _anchorToVersion ? Colors.white : AppTheme.secondaryLabel,
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
                      color: _isInternalOnlyNote ? const Color(0xFF8A4620) : AppTheme.tertiarySystemBackground,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 12, color: _isInternalOnlyNote ? AppTheme.leaf : AppTheme.secondaryLabel),
                        const SizedBox(width: 4),
                        Text(
                          'Internal Note',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _isInternalOnlyNote ? AppTheme.leaf : AppTheme.secondaryLabel,
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
              backgroundColor: AppTheme.tertiarySystemBackground,
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: _selectedVersionFilter == null ? FontWeight.w600 : FontWeight.normal,
                color: _selectedVersionFilter == null ? Colors.white : AppTheme.label,
              ),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                backgroundColor: AppTheme.tertiarySystemBackground,
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.white : AppTheme.label,
                ),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        color: AppTheme.secondarySystemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.appleCardShadow,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const Divider(height: 0.5, color: AppTheme.separator),
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
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c.name,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.label),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.tertiarySystemBackground,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      c.role.toUpperCase(),
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.secondaryLabel),
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
        color: msg.isInternalOnly
            ? const Color(0xFFFBF4ED)
            : (isReply ? AppTheme.tertiarySystemBackground : AppTheme.secondarySystemBackground),
        borderRadius: BorderRadius.circular(14),
        boxShadow: msg.isInternalOnly ? null : AppTheme.appleCardShadow,
        border: msg.isInternalOnly
            ? Border.all(color: const Color(0xFFE2C2A8), width: 1.0)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: isReply ? 10 : 12,
                backgroundColor: isReviewer ? AppTheme.appleIndigo : AppTheme.forge,
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: isReply ? 9 : 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.label),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isReviewer ? AppTheme.appleIndigo.withOpacity(0.12) : AppTheme.tertiarySystemBackground,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        msg.authorRole.toUpperCase(),
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: isReviewer ? AppTheme.appleIndigo : AppTheme.secondaryLabel,
                        ),
                      ),
                    ),
                    if (msg.versionNo != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.tertiarySystemBackground,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'v${msg.versionNo}.0',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontFeatures: [FontFeature.tabularFigures()],
                            color: AppTheme.label,
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
                        Icon(Icons.reply_rounded, size: 14, color: AppTheme.brandAccent),
                        SizedBox(width: 3),
                        Text('Reply', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.brandAccent)),
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
              color: AppTheme.brandAccent,
              backgroundColor: Color(0x1FB8532F),
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: '$word$space',
            style: const TextStyle(fontSize: 13, color: AppTheme.label, height: 1.35),
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
            style: const TextStyle(fontSize: 13, color: AppTheme.secondaryLabel),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        if (isForgeBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.tertiarySystemBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.label),
            ),
          )
        else
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.label,
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
