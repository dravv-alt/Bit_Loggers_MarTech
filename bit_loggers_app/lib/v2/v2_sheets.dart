import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../state/campaign_state_machine.dart';
import 'v2_components.dart';
import 'v2_mappers.dart';
import 'v2_tokens.dart';
import 'v2_weight_scale.dart';

/// Screens 04 & 05: Role-gated Decision Sheet / Owner Lock inside V2SheetScaffold.
class V2DecisionSheet extends StatefulWidget {
  final ApiService api;
  final Campaign campaign;
  final CampaignVersion targetVersion;

  const V2DecisionSheet({
    super.key,
    required this.api,
    required this.campaign,
    required this.targetVersion,
  });

  @override
  State<V2DecisionSheet> createState() => _V2DecisionSheetState();
}

class _V2DecisionSheetState extends State<V2DecisionSheet> {
  String _outcome = 'Approve';
  late final TextEditingController _reasonCtrl;
  late List<String> _pinnedClauses;
  String? _reasonError;
  bool _shakeOn = false;
  bool _submitting = false;

  // Hold-to-approve state
  double _holdProgress = 0.28;
  bool _isHolding = false;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    final budgetStr = V2Tokens.formatCurrency(widget.targetVersion.budget);
    final audShort = widget.targetVersion.targetAudience.length > 18
        ? widget.targetVersion.targetAudience.substring(0, 18)
        : widget.targetVersion.targetAudience;
    _pinnedClauses = ['Budget $budgetStr', 'Audience $audShort'];
    _reasonCtrl = TextEditingController(
      text: '${audShort.trim()} aperture aligns with guardrails and $budgetStr cap sits safely below ceiling.',
    );
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _reasonCtrl.dispose();
    super.dispose();
  }

  CampaignCapabilities get _decisionCaps =>
      CampaignStateMachine.evaluate(widget.campaign, widget.api.currentUser);

  bool get _isOwnerLocked => !_decisionCaps.canReview;

  void _triggerErrorShake(String msg) {
    HapticFeedback.heavyImpact();
    setState(() {
      _reasonError = msg;
      _shakeOn = true;
    });
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _shakeOn = false);
    });
  }

  void _startHold() {
    if (_submitting) return;
    if (_reasonCtrl.text.trim().isEmpty) {
      _triggerErrorShake('Reason is required before recording a decision.');
      return;
    }
    setState(() {
      _reasonError = null;
      _isHolding = true;
      _holdProgress = 0.28;
    });
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 28), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final next = _holdProgress + 0.06;
      if (next >= 1.0) {
        t.cancel();
        setState(() {
          _holdProgress = 1.0;
          _isHolding = false;
        });
        HapticFeedback.mediumImpact();
        _commitDecision('APPROVED');
      } else {
        setState(() => _holdProgress = next);
      }
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    if (mounted) {
      setState(() {
        _isHolding = false;
        _holdProgress = 0.28;
      });
    }
  }

  Future<void> _commitDecision(String apiDecisionType) async {
    final trimmed = _reasonCtrl.text.trim();
    if (trimmed.isEmpty) {
      _triggerErrorShake('Reason is required before recording a decision.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.api.recordReviewDecision(
        campaignId: widget.campaign.campaignId,
        versionId: widget.targetVersion.versionId,
        decisionType: apiDecisionType,
        reason: trimmed,
        policyRef: _pinnedClauses.isNotEmpty ? _pinnedClauses.join('; ') : null,
      );
      if (mounted) {
        Navigator.pop(context, apiDecisionType);
      }
    } catch (e) {
      if (mounted) {
        _triggerErrorShake(e.toString().replaceAll('Exception: ', ''));
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final verTag = V2Tokens.formatVersionTag(widget.targetVersion.versionNo);
    final statusKey = V2Tokens.normalizeStatusKey(widget.campaign.status);

    if (_isOwnerLocked) {
      return V2SheetScaffold(
        parentTitle: widget.campaign.title,
        parentSub: 'Owner: ${V2Tokens.cleanPersonName(widget.campaign.ownerName)} · $verTag',
        parentStatus: statusKey,
        onClose: () => Navigator.pop(context),
        rightAction: Text(_decisionCaps.isOwner ? 'Owner lock' : 'Review lock', style: V2Tokens.t4()),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Review $verTag', style: V2Tokens.t1()),
            const SizedBox(height: 2),
            Text(
              '${widget.campaign.title} · Viewer: ${V2Tokens.cleanPersonName(widget.api.currentUser.name)} (${_decisionCaps.isOwner ? 'Owner' : widget.api.currentUser.role})',
              style: V2Tokens.t3(color: V2Tokens.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: V2Tokens.surfaceRecessed,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: V2Tokens.hairline, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 22, color: V2Tokens.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _decisionCaps.reviewBlockedReason ??
                          'You own this campaign, so you cannot decide on it.',
                      style: V2Tokens.t2(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Opacity(
              opacity: 0.5,
              child: IgnorePointer(
                child: TextField(
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Reason field disabled for campaign owners…',
                    hintStyle: V2Tokens.t3(color: V2Tokens.textSecondary),
                    filled: true,
                    fillColor: V2Tokens.surfaceRecessed,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: V2Tokens.hairline, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: V2Tokens.surfaceRecessed,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: V2Tokens.hairline, width: 1),
              ),
              child: Text('Owner view', style: V2Tokens.t2(color: V2Tokens.textSecondary)),
            ),
          ],
        ),
      );
    }

    final budgetClause = 'Budget ${V2Tokens.formatCurrency(widget.targetVersion.budget)}';
    final audLabel = 'Audience ${widget.targetVersion.targetAudience.length > 18 ? widget.targetVersion.targetAudience.substring(0, 18) : widget.targetVersion.targetAudience}';
    final availableClauses = [budgetClause, audLabel];

    return V2SheetScaffold(
      parentTitle: widget.campaign.title,
      parentSub: 'Owner: ${V2Tokens.cleanPersonName(widget.campaign.ownerName)} · $verTag',
      parentStatus: statusKey,
      onClose: () => Navigator.pop(context),
      rightAction: Text('Review $verTag', style: V2Tokens.t4()),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Review $verTag', style: V2Tokens.t1()),
                const SizedBox(height: 2),
                Text(
                  '${widget.campaign.title} · Budget ${V2Tokens.formatCurrency(widget.targetVersion.budget)}',
                  style: V2Tokens.t3(color: V2Tokens.textSecondary),
                ),
                const SizedBox(height: 14),

                // 3-way Outcome Switcher
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: V2Tokens.surfaceRecessed,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: V2Tokens.hairline, width: 1),
                  ),
                  child: Row(
                    children: ['Approve', 'Request changes', 'Reject'].map((opt) {
                      final selected = _outcome == opt;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _outcome = opt),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 40),
                            alignment: Alignment.center,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: selected ? V2Tokens.surfaceCard : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                              border: selected
                                  ? Border.all(color: V2Tokens.inkPrussian, width: 1.5)
                                  : null,
                            ),
                            child: Text(
                              opt,
                              textAlign: TextAlign.center,
                              style: V2Tokens.t3(
                                color: selected ? V2Tokens.textPrimary : V2Tokens.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),

                // Mandatory Reason Field
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Reason (mandatory)', style: V2Tokens.t4()),
                    Text('${_reasonCtrl.text.trim().length} chars', style: V2Tokens.t4()),
                  ],
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  transform: Matrix4.translationValues(_shakeOn ? 8 : 0, 0, 0),
                  child: TextField(
                    controller: _reasonCtrl,
                    maxLines: 3,
                    onChanged: (_) {
                      if (_reasonError != null) {
                        setState(() => _reasonError = null);
                      } else {
                        setState(() {});
                      }
                    },
                    style: V2Tokens.t3(),
                    decoration: InputDecoration(
                      hintText: 'Explain why the budget, audience and KPIs are acceptable',
                      hintStyle: V2Tokens.t3(color: V2Tokens.textSecondary),
                      filled: true,
                      fillColor: V2Tokens.surfaceCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _reasonError != null ? V2Tokens.blockedSolid : V2Tokens.hairline,
                          width: _reasonError != null ? 1.5 : 1.0,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _reasonError != null ? V2Tokens.blockedSolid : V2Tokens.hairline,
                          width: _reasonError != null ? 1.5 : 1.0,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _reasonError != null ? V2Tokens.blockedSolid : V2Tokens.inkPrussian,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_reasonError != null) ...[
                  const SizedBox(height: 6),
                  Text(_reasonError!, style: V2Tokens.t4(color: V2Tokens.blockedSolid)),
                ],
                const SizedBox(height: 14),

                // Pinned parameter clauses
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: V2Tokens.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: V2Tokens.hairline, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pinned parameter clauses', style: V2Tokens.t4()),
                      const SizedBox(height: 8),
                      ...availableClauses.map((clause) {
                        final pinned = _pinnedClauses.contains(clause);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (pinned) {
                                _pinnedClauses.remove(clause);
                              } else {
                                _pinnedClauses.add(clause);
                              }
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                            decoration: BoxDecoration(
                              color: pinned ? V2Tokens.changedRowTint : V2Tokens.surfaceRecessed,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: pinned ? V2Tokens.inkPrussian : V2Tokens.hairline,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    clause,
                                    overflow: TextOverflow.ellipsis,
                                    style: V2Tokens.t3(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (pinned) ...[
                                      const Icon(
                                        Icons.check_rounded,
                                        size: 13,
                                        color: V2Tokens.approvedSolid,
                                      ),
                                      const SizedBox(width: 3),
                                    ],
                                    Text(
                                      pinned ? 'Pinned' : 'Tap to pin',
                                      style: V2Tokens.t4(
                                        color: pinned
                                            ? V2Tokens.approvedSolid
                                            : V2Tokens.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sticky CTA footer inside Decision Sheet
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: const BoxDecoration(
              color: V2Tokens.surfaceCard,
              border: Border(top: BorderSide(color: V2Tokens.hairline, width: 1)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_outcome == 'Approve')
                    GestureDetector(
                      onTapDown: (_) => _startHold(),
                      onTapUp: (_) => _cancelHold(),
                      onTapCancel: _cancelHold,
                      onLongPressStart: (_) => _startHold(),
                      onLongPressEnd: (_) => _cancelHold(),
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: V2Tokens.inkPrussian,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            FractionallySizedBox(
                              widthFactor: _holdProgress.clamp(0.0, 1.0),
                              child: Container(
                                height: double.infinity,
                                color: V2Tokens.cadmiumYellow.withOpacity(0.35),
                              ),
                            ),
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.touch_app_rounded, size: 17, color: V2Tokens.labelOnInk),
                                  const SizedBox(width: 8),
                                  Text(
                                    _submitting
                                        ? 'Recording approval…'
                                        : _isHolding
                                            ? 'Holding to commit…'
                                            : 'Hold to approve $verTag',
                                    style: V2Tokens.t2(color: V2Tokens.labelOnInk),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _submitting
                            ? null
                            : () => _commitDecision(
                                  _outcome == 'Reject' ? 'REJECTED' : 'CHANGES_REQUESTED',
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _outcome == 'Reject' ? V2Tokens.blockedSolid : V2Tokens.changesSolid,
                          foregroundColor: V2Tokens.labelOnInk,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        ),
                        child: Text(
                          _outcome == 'Reject' ? 'Reject Version' : 'Request Changes',
                          style: V2Tokens.t2(color: V2Tokens.labelOnInk),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Hold for a moment to confirm. This decision cannot be edited, only amended.',
                    style: V2Tokens.t3(color: V2Tokens.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Screens 06 & 07: Proposal Studio (Author or Revise) with Tactile Ruler, AI Brief, and Idempotency Offline Banner.
class V2ProposalStudioSheet extends StatefulWidget {
  final ApiService api;
  final Campaign? existingCampaign;
  final CampaignVersion? baseVersion;
  final int initialLeaseSeconds;

  const V2ProposalStudioSheet({
    super.key,
    required this.api,
    this.existingCampaign,
    this.baseVersion,
    this.initialLeaseSeconds = 202,
  });

  @override
  State<V2ProposalStudioSheet> createState() => _V2ProposalStudioSheetState();
}

class _V2ProposalStudioSheetState extends State<V2ProposalStudioSheet> {
  late double _budget;
  late String _audience;
  late String _channel;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _objectiveCtrl;
  late final TextEditingController _aiPromptCtrl;

  bool _simulatingOffline = false;
  bool _submitting = false;
  bool _draftingAi = false;
  bool _showAiBar = false;
  int _leaseSeconds = 202;
  Timer? _leaseTimer;
  late final String _idempotencyKey;

  @override
  void initState() {
    super.initState();
    final ver = widget.baseVersion ?? widget.existingCampaign?.currentVersion;
    _budget = (ver?.budget ?? 25000).clamp(10000, 35000);
    _audience = ver?.targetAudience.isNotEmpty == true ? ver!.targetAudience : 'Lookalike';
    _channel = ver?.channel.isNotEmpty == true ? ver!.channel : 'Social';
    _titleCtrl = TextEditingController(
      text: widget.existingCampaign?.title ?? 'Q4 Seasonal Conversion Blitz',
    );
    _objectiveCtrl = TextEditingController(
      text: ver?.objective.isNotEmpty == true ? ver!.objective : 'Festive Conversion',
    );
    _aiPromptCtrl = TextEditingController();
    _simulatingOffline = widget.api.syncQueue.isOfflineSimulationEnabled;
    _leaseSeconds = widget.existingCampaign?.activeLock != null
        ? CampaignStateMachine.evaluateLock(
            widget.existingCampaign!.activeLock,
            widget.api.currentUser.id,
          ).remainingSeconds
        : widget.initialLeaseSeconds;
    _idempotencyKey = 'K-${DateTime.now().millisecondsSinceEpoch % 10000}';

    if (widget.existingCampaign != null) {
      widget.api
          .acquireLock(widget.existingCampaign!.campaignId)
          .then((res) {
            if (!mounted) return;
            final expStr = res['expires_at'] as String?;
            final expDt = expStr != null ? DateTime.tryParse(expStr)?.toLocal() : null;
            if (expDt != null) {
              final secs = expDt.difference(DateTime.now()).inSeconds;
              setState(() => _leaseSeconds = secs < 0 ? 0 : secs);
            }
          })
          .catchError((_) {});
    }
    _leaseTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _leaseSeconds = _leaseSeconds > 0 ? _leaseSeconds - 1 : 0);
      }
    });
  }

  @override
  void dispose() {
    _leaseTimer?.cancel();
    if (widget.existingCampaign != null) {
      widget.api.releaseLock(widget.existingCampaign!.campaignId);
    }
    _titleCtrl.dispose();
    _objectiveCtrl.dispose();
    _aiPromptCtrl.dispose();
    super.dispose();
  }

  bool get _isLookalike =>
      _audience.toLowerCase().contains('lookalike') ||
      _audience.toLowerCase().contains('vip') ||
      _audience.toLowerCase().contains('loyalty');

  String get _projectedCpa {
    final base = _isLookalike ? 11.4 : 15.8;
    return (base * (_budget / 25000)).toStringAsFixed(2);
  }

  String get _projectedCtr => _isLookalike ? '2.8%' : '1.9%';
  String get _projectedConv => _isLookalike ? '3.1%' : '2.1%';

  Future<void> _runAiDraft() async {
    setState(() => _draftingAi = true);
    try {
      final res = await widget.api.draftWithAI(
        _aiPromptCtrl.text.trim(),
        channel: _channel,
        budget: _budget,
      );
      if (mounted) {
        setState(() {
          if (widget.existingCampaign == null && res['title'] != null) {
            _titleCtrl.text = res['title'].toString();
          }
          if (res['objective'] != null) {
            _objectiveCtrl.text = res['objective'].toString();
          }
          if (res['target_audience'] != null) {
            _audience = res['target_audience'].toString().contains('Broad') ? 'Broad' : 'Lookalike';
          }
          _showAiBar = false;
          _draftingAi = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _draftingAi = false);
    }
  }

  Future<void> _submitProposal({bool simulateConflict = false}) async {
    if (_submitting) return;
    if (simulateConflict && widget.existingCampaign != null) {
      final merged = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => V2ConflictSheet(
            campaign: widget.existingCampaign!,
            localBudget: _budget,
            localAudience: _audience,
            localChannel: _channel,
          ),
        ),
      );
      if (merged == null || !mounted) return;
      _budget = (merged['budget'] as double?) ?? _budget;
      _audience = (merged['audience'] as String?) ?? _audience;
      _channel = (merged['channel'] as String?) ?? _channel;
    }

    setState(() => _submitting = true);
    try {
      final prevOffline = widget.api.syncQueue.isOfflineSimulationEnabled;
      if (_simulatingOffline) {
        widget.api.syncQueue.setOfflineSimulation(true);
      }

      final payload = {
        'title': _titleCtrl.text.trim().isEmpty ? 'Campaign Proposal' : _titleCtrl.text.trim(),
        'objective': _objectiveCtrl.text.trim().isEmpty ? 'Festive Conversion' : _objectiveCtrl.text.trim(),
        'target_audience': _audience,
        'channel': _channel,
        'budget': _budget,
        'kpi_projected': {
          'conversionRate': _isLookalike ? 3.1 : 2.1,
          'ctr': _isLookalike ? 2.8 : 1.9,
          'roi': _isLookalike ? 4.4 : 3.2,
          'cpa': double.tryParse(_projectedCpa) ?? 11.40,
          'aov': 125.0,
        },
      };

      Campaign saved;
      if (widget.existingCampaign != null) {
        saved = await widget.api.updateCampaign(
          widget.existingCampaign!.campaignId,
          payload,
          expectedVersion: widget.existingCampaign!.currentVersion?.versionNo,
        );
      } else {
        saved = await widget.api.createCampaign(payload);
      }

      await widget.api.submitCampaign(saved.campaignId, idempotencyKey: _idempotencyKey);
      if (!prevOffline && _simulatingOffline) {
        // Leave queue enabled only if user intentionally toggled offline mode in SyncHub;
        // reset temporary Studio toggle cleanly if needed, keeping queued action visible in SyncHub.
        widget.api.syncQueue.setOfflineSimulation(false);
      }

      if (mounted) {
        Navigator.pop(context, saved);
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('409') || msg.toLowerCase().contains('conflict')) {
        setState(() => _submitting = false);
        await _submitProposal(simulateConflict: true);
        return;
      }
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.replaceAll('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existingCampaign;
    final nextVerNo = (existing?.currentVersion?.versionNo ?? 0) + 1;
    final verLabel = existing != null ? 'V$nextVerNo.0' : 'V1.0';
    final parentTitle = existing?.title ?? 'New Campaign Proposal';

    return V2SheetScaffold(
      parentTitle: parentTitle,
      parentSub: existing != null
          ? 'Revising ${V2Tokens.formatVersionTag(existing.currentVersion?.versionNo ?? 1)} · Lease active'
          : 'Authoring V1.0 · Draft workspace',
      parentStatus: existing != null ? existing.status : 'brand',
      onClose: () => Navigator.pop(context),
      rightAction: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: V2Tokens.approvedChipBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: V2Tokens.hairline, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const V2FacetCell(status: 'approved', size: 9),
            const SizedBox(width: 5),
            Text(
              'Editing, lease ${V2Tokens.formatLease(_leaseSeconds)}',
              style: V2Tokens.t4(color: V2Tokens.approvedSolid),
            ),
          ],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        existing != null ? 'Draft $verLabel' : 'New Proposal',
                        overflow: TextOverflow.ellipsis,
                        style: V2Tokens.t1(),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => setState(() => _showAiBar = !_showAiBar),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: _showAiBar ? V2Tokens.inkPrussian : V2Tokens.surfaceRecessed,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: V2Tokens.hairline, width: 1),
                            ),
                            child: Text(
                              'AI assist',
                              style: V2Tokens.t4(
                                color: _showAiBar ? V2Tokens.labelOnInk : V2Tokens.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _simulatingOffline = !_simulatingOffline),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: _simulatingOffline
                                  ? V2Tokens.changedRowTint
                                  : V2Tokens.surfaceRecessed,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _simulatingOffline ? V2Tokens.inkPrussian : V2Tokens.hairline,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _simulatingOffline ? 'Back online' : 'Test offline',
                              style: V2Tokens.t4(color: V2Tokens.textPrimary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_showAiBar) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: V2Tokens.changedRowTint,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: V2Tokens.inkPrussian, width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI brief synthesis', style: V2Tokens.t4(color: V2Tokens.inkPrussian)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _aiPromptCtrl,
                                style: V2Tokens.t3(),
                                decoration: InputDecoration(
                                  hintText: 'e.g. Festive solar promo for eco homeowners',
                                  hintStyle: V2Tokens.t3(color: V2Tokens.textSecondary),
                                  isDense: true,
                                  filled: true,
                                  fillColor: V2Tokens.surfaceCard,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: V2Tokens.hairline),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _draftingAi ? null : _runAiDraft,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: V2Tokens.inkPrussian,
                                foregroundColor: V2Tokens.labelOnInk,
                                elevation: 0,
                                minimumSize: const Size(76, 40),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(
                                _draftingAi ? '…' : 'Draft',
                                style: V2Tokens.t4(color: V2Tokens.labelOnInk),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Screen 07: Offline Queue + Idempotency Banner
                if (_simulatingOffline) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: V2Tokens.changedRowTint,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: V2Tokens.inkPrussian, width: 1.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.wifi_off_rounded, size: 17, color: V2Tokens.inkPrussian),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No connection. We will retry this exact submission when you are back online.',
                                style: V2Tokens.t3(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Idempotency key #$_idempotencyKey locked',
                                style: V2Tokens.t4(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Title Field when creating or renaming
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: V2Tokens.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: V2Tokens.hairline, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Proposal title', style: V2Tokens.t4()),
                      TextField(
                        controller: _titleCtrl,
                        style: V2Tokens.t2(),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                          border: InputBorder.none,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Hero Budget Card with Mechanical Rolling Weight Scale
                Container(
                  decoration: BoxDecoration(
                    color: V2Tokens.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: V2Tokens.hairline, width: 1),
                  ),
                  child: V2BudgetWeightScale(
                    budget: _budget,
                    minBudget: math.min(15000.0, (_budget / 1000.0).floor() * 1000.0),
                    maxBudget: 35000.0,
                    ceilingBudget: 30000.0,
                    onBudgetChanged: (val) => setState(() => _budget = val),
                  ),
                ),
                const SizedBox(height: 12),

                // Grouped Inset Form: Objective, Audience, Channel
                Container(
                  decoration: BoxDecoration(
                    color: V2Tokens.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: V2Tokens.hairline, width: 1),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('Objective', style: V2Tokens.t3(color: V2Tokens.textSecondary)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _objectiveCtrl,
                                textAlign: TextAlign.end,
                                maxLines: 2,
                                minLines: 1,
                                style: V2Tokens.t3(fontWeight: FontWeight.w600),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, thickness: 1, color: V2Tokens.hairline),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Audience', style: V2Tokens.t3(color: V2Tokens.textSecondary)),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: ['Lookalike', 'Broad'].map((aud) {
                                final active = aud == 'Lookalike' ? _isLookalike : !_isLookalike;
                                return GestureDetector(
                                  onTap: () => setState(() => _audience = aud),
                                  child: Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: active
                                          ? V2Tokens.inkPrussian
                                          : V2Tokens.surfaceRecessed,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      aud,
                                      style: V2Tokens.t4(
                                        color: active ? V2Tokens.labelOnInk : V2Tokens.textSecondary,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, thickness: 1, color: V2Tokens.hairline),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Channel', style: V2Tokens.t3(color: V2Tokens.textSecondary)),
                            Wrap(
                              spacing: 4,
                              children: ['Social', 'Search', 'Display', 'Email'].map((ch) {
                                final active = _channel == ch;
                                return GestureDetector(
                                  onTap: () => setState(() => _channel = ch),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: active
                                          ? V2Tokens.inkPrussian
                                          : V2Tokens.surfaceRecessed,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      ch,
                                      style: V2Tokens.t4(
                                        color: active ? V2Tokens.labelOnInk : V2Tokens.textSecondary,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 3-Column Live Projections in Mono
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: V2Tokens.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: V2Tokens.hairline, width: 1),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CPA', style: V2Tokens.t4()),
                            const SizedBox(height: 2),
                            Text('\$$_projectedCpa', style: V2Tokens.t2(mono: true)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CTR', style: V2Tokens.t4()),
                            const SizedBox(height: 2),
                            Text(_projectedCtr, style: V2Tokens.t2(mono: true)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Conversion', style: V2Tokens.t4()),
                            const SizedBox(height: 2),
                            Text(_projectedConv, style: V2Tokens.t2(mono: true)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sticky Submit Action Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: const BoxDecoration(
              color: V2Tokens.surfaceCard,
              border: Border(top: BorderSide(color: V2Tokens.hairline, width: 1)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : () => _submitProposal(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _submitting ? V2Tokens.surfaceRecessed : V2Tokens.inkPrussian,
                        foregroundColor:
                            _submitting ? V2Tokens.textPrimary : V2Tokens.labelOnInk,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                      icon: _submitting
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: V2Tokens.inkPrussian,
                              ),
                            )
                          : const SizedBox.shrink(),
                      label: Text(
                        _submitting
                            ? 'Securing $verLabel…'
                            : (_simulatingOffline ? 'Queue $verLabel offline' : 'Submit $verLabel'),
                        style: V2Tokens.t2(
                          color: _submitting ? V2Tokens.textPrimary : V2Tokens.labelOnInk,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _simulatingOffline
                            ? 'Safe to retry. Queued with key #$_idempotencyKey.'
                            : 'Draft saved locally',
                        style: V2Tokens.t3(color: V2Tokens.textSecondary),
                      ),
                      if (existing != null)
                        InkWell(
                          onTap: () => _submitProposal(simulateConflict: true),
                          child: Text(
                            'Test version conflict →',
                            style: V2Tokens.t4(color: V2Tokens.inkPrussian),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen 08: Stale-Save Version Conflict Resolver Sheet.
class V2ConflictSheet extends StatefulWidget {
  final Campaign campaign;
  final double localBudget;
  final String localAudience;
  final String localChannel;

  const V2ConflictSheet({
    super.key,
    required this.campaign,
    required this.localBudget,
    required this.localAudience,
    required this.localChannel,
  });

  @override
  State<V2ConflictSheet> createState() => _V2ConflictSheetState();
}

class _V2ConflictSheetState extends State<V2ConflictSheet> {
  String _budgetChoice = 'mine';
  String _audienceChoice = 'theirs';
  String _channelChoice = 'mine';

  @override
  Widget build(BuildContext context) {
    final nextVer = (widget.campaign.currentVersion?.versionNo ?? 1) + 1;
    final serverTag = 'V$nextVer.0';
    final serverBudget = widget.localBudget == 28000 ? 30000.0 : 28000.0;
    const serverAudience = 'Lookalike';
    final serverChannel = widget.campaign.currentVersion?.channel ?? 'Social';

    final rows = [
      (
        key: 'budget',
        label: 'Budget',
        choice: _budgetChoice,
        mineLabel: 'Mine: ${V2Tokens.formatCurrency(widget.localBudget)}',
        theirsLabel: '$serverTag: ${V2Tokens.formatCurrency(serverBudget)}',
        onPick: (String v) => setState(() => _budgetChoice = v),
      ),
      (
        key: 'audience',
        label: 'Audience',
        choice: _audienceChoice,
        mineLabel: 'Mine: ${widget.localAudience}',
        theirsLabel: '$serverTag: Retargeting',
        onPick: (String v) => setState(() => _audienceChoice = v),
      ),
      (
        key: 'channel',
        label: 'Channel',
        choice: _channelChoice,
        mineLabel: 'Mine: ${widget.localChannel}',
        theirsLabel: '$serverTag: $serverChannel',
        onPick: (String v) => setState(() => _channelChoice = v),
      ),
    ];

    return V2SheetScaffold(
      parentTitle: widget.campaign.title,
      parentSub: '409 Version conflict · Concurrent save detected',
      parentStatus: 'changes',
      onClose: () => Navigator.pop(context),
      rightAction: Text('Conflict merge', style: V2Tokens.t4(color: V2Tokens.changesSolid)),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('A newer version exists', style: V2Tokens.t1()),
                const SizedBox(height: 4),
                Text(
                  'A collaborator saved $serverTag while you were editing. Choose per field to merge.',
                  style: V2Tokens.t3(color: V2Tokens.textSecondary),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: V2Tokens.surfaceCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: V2Tokens.inkPrussian, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your edits', style: V2Tokens.t4(color: V2Tokens.inkPrussian)),
                            const SizedBox(height: 3),
                            Text('Local draft', style: V2Tokens.t3(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              '${V2Tokens.formatCurrency(widget.localBudget)} · ${widget.localChannel}',
                              overflow: TextOverflow.ellipsis,
                              style: V2Tokens.t4(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: V2Tokens.surfaceCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: V2Tokens.hairline, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Server HEAD', style: V2Tokens.t4(color: V2Tokens.changesSolid)),
                            const SizedBox(height: 3),
                            Text(serverTag, style: V2Tokens.t3(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              '${V2Tokens.formatCurrency(serverBudget)} · Retargeting',
                              overflow: TextOverflow.ellipsis,
                              style: V2Tokens.t4(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: V2Tokens.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: V2Tokens.hairline, width: 1),
                  ),
                  child: Column(
                    children: rows.map((row) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(row.label, style: V2Tokens.t3(fontWeight: FontWeight.w600)),
                                Text(
                                  row.choice == 'mine' ? 'Keeping yours' : 'Taking $serverTag',
                                  style: V2Tokens.t4(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: V2Tokens.surfaceRecessed,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: V2Tokens.hairline, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => row.onPick('mine'),
                                      child: Container(
                                        constraints: const BoxConstraints(minHeight: 38),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: row.choice == 'mine'
                                              ? V2Tokens.surfaceCard
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                          border: row.choice == 'mine'
                                              ? Border.all(color: V2Tokens.inkPrussian, width: 1.5)
                                              : null,
                                        ),
                                        child: Text(
                                          row.mineLabel,
                                          overflow: TextOverflow.ellipsis,
                                          style: V2Tokens.t4(
                                            color: row.choice == 'mine'
                                                ? V2Tokens.textPrimary
                                                : V2Tokens.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => row.onPick('theirs'),
                                      child: Container(
                                        constraints: const BoxConstraints(minHeight: 38),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: row.choice == 'theirs'
                                              ? V2Tokens.surfaceCard
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                          border: row.choice == 'theirs'
                                              ? Border.all(color: V2Tokens.inkPrussian, width: 1.5)
                                              : null,
                                        ),
                                        child: Text(
                                          row.theirsLabel,
                                          overflow: TextOverflow.ellipsis,
                                          style: V2Tokens.t4(
                                            color: row.choice == 'theirs'
                                                ? V2Tokens.textPrimary
                                                : V2Tokens.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: const BoxDecoration(
              color: V2Tokens.surfaceCard,
              border: Border(top: BorderSide(color: V2Tokens.hairline, width: 1)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, {
                          'budget': _budgetChoice == 'mine' ? widget.localBudget : serverBudget,
                          'audience':
                              _audienceChoice == 'mine' ? widget.localAudience : serverAudience,
                          'channel': _channelChoice == 'mine' ? widget.localChannel : serverChannel,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: V2Tokens.inkPrussian,
                        foregroundColor: V2Tokens.labelOnInk,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                      child: Text(
                        'Merge and continue',
                        style: V2Tokens.t2(color: V2Tokens.labelOnInk),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Discard my edits',
                      style: V2Tokens.t3(
                        color: V2Tokens.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Screens 10 & 11: Pre-Flight Schedule Invariant Gate Sheet (Pass or Blocked).
class V2PreFlightSheet extends StatefulWidget {
  final ApiService api;
  final Campaign campaign;
  final CampaignVersion targetVersion;
  final List<ScheduleEvent> existingEvents;
  final bool forceUnapprovedDemo;
  final DateTime? preferredStart;
  final DateTime? preferredEnd;

  const V2PreFlightSheet({
    super.key,
    required this.api,
    required this.campaign,
    required this.targetVersion,
    required this.existingEvents,
    this.forceUnapprovedDemo = false,
    this.preferredStart,
    this.preferredEnd,
  });

  @override
  State<V2PreFlightSheet> createState() => _V2PreFlightSheetState();
}

class _V2PreFlightSheetState extends State<V2PreFlightSheet> {
  late bool _simulateOldGate;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _simulateOldGate = widget.forceUnapprovedDemo;
  }

  DateTime get _startDate =>
      widget.preferredStart ?? DateTime.now().add(const Duration(days: 1));
  DateTime get _endDate => widget.preferredEnd ?? _startDate.add(const Duration(days: 4));

  @override
  Widget build(BuildContext context) {
    final versions = V2Mappers.sortedVersions(widget.campaign);
    final testVer = (_simulateOldGate && versions.length > 1)
        ? versions[versions.length - 2]
        : widget.targetVersion;
    final verTag = V2Tokens.formatVersionTag(testVer.versionNo);
    final isCurrent = testVer.versionId == widget.campaign.currentVersionId;
    final hasApprovedDecision = widget.campaign.decisions.any(
          (d) => d.versionId == testVer.versionId && d.decisionType == 'APPROVED',
        ) ||
        (isCurrent &&
            (V2Tokens.normalizeStatusKey(widget.campaign.status) == 'approved' ||
                V2Tokens.normalizeStatusKey(widget.campaign.status) == 'scheduled'));

    final isApproved = !_simulateOldGate && hasApprovedDecision;
    final collision = widget.existingEvents.any((ev) {
      if (ev.channel.toLowerCase() != testVer.channel.toLowerCase() ||
          ev.campaignId == widget.campaign.campaignId) {
        return false;
      }
      final s = DateTime.tryParse(ev.startsAt);
      final e = DateTime.tryParse(ev.endsAt);
      if (s == null || e == null) return false;
      return s.isBefore(_endDate) && e.isAfter(_startDate);
    });

    final gate2Failed = !isApproved;
    final gate3Failed = !gate2Failed && !isCurrent;
    final gate4Failed = !gate2Failed && !gate3Failed && collision;
    final isBlocked = gate2Failed || gate3Failed || gate4Failed;

    final gates = [
      (
        title: 'Version belongs to this campaign',
        sub: '${widget.campaign.title} · $verTag',
        state: 'pass',
      ),
      (
        title: gate2Failed
            ? '$verTag has not been approved. Prior approvals never carry over.'
            : 'This exact version is approved',
        sub: gate2Failed
            ? 'Scheduling blocked until $verTag approval'
            : 'Reviewed and signed off cleanly',
        state: gate2Failed ? 'fail' : 'pass',
      ),
      (
        title: 'This is the current version',
        sub: gate2Failed
            ? 'Not checked'
            : (isCurrent ? '$verTag is current active head' : 'Superseded by V${widget.campaign.currentVersion?.versionNo ?? testVer.versionNo}.0'),
        state: gate2Failed ? 'muted' : (gate3Failed ? 'fail' : 'pass'),
      ),
      (
        title: 'No slot collisions on ${testVer.channel}',
        sub: gate2Failed || gate3Failed
            ? 'Not checked'
            : (gate4Failed ? 'Another campaign occupies this window' : 'Selected window clear'),
        state: (gate2Failed || gate3Failed)
            ? 'muted'
            : (gate4Failed ? 'fail' : 'pass'),
      ),
    ];

    return V2SheetScaffold(
      parentTitle: widget.campaign.title,
      parentSub: '${testVer.channel} · ${V2Mappers.flightWindowLabel(widget.campaign, widget.existingEvents)}',
      parentStatus: isBlocked ? 'blocked' : 'approved',
      onClose: () => Navigator.pop(context),
      rightAction: InkWell(
        onTap: () => setState(() => _simulateOldGate = !_simulateOldGate),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: V2Tokens.surfaceRecessed,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: V2Tokens.hairline, width: 1),
          ),
          child: Text(
            _simulateOldGate ? 'View current pass' : 'Test unapproved gate',
            style: V2Tokens.t4(color: V2Tokens.textPrimary),
          ),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Pre-flight check for $verTag', style: V2Tokens.t4()),
                const SizedBox(height: 4),
                Text(
                  gate2Failed
                      ? 'Gate 2 blocked'
                      : gate3Failed
                          ? 'Gate 3 blocked'
                          : gate4Failed
                              ? 'Slot collision blocked'
                              : 'All 4 checks passed',
                  style: V2Tokens.t1(
                    color: isBlocked ? V2Tokens.blockedSolid : V2Tokens.approvedSolid,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: V2Tokens.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: V2Tokens.hairline, width: 1),
                  ),
                  child: Column(
                    children: List.generate(gates.length, (idx) {
                      final g = gates[idx];
                      final isFail = g.state == 'fail';
                      final isPass = g.state == 'pass';
                      final isMuted = g.state == 'muted';
                      return Opacity(
                        opacity: isMuted ? 0.45 : 1.0,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isFail ? V2Tokens.blockedChipBg : Colors.transparent,
                            border: idx < gates.length - 1
                                ? const Border(bottom: BorderSide(color: V2Tokens.hairline, width: 1))
                                : null,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: isPass
                                    ? const Icon(Icons.check_rounded, size: 16, color: V2Tokens.approvedSolid)
                                    : isFail
                                        ? const Icon(Icons.error_outline_rounded,
                                            size: 16, color: V2Tokens.blockedSolid)
                                        : const V2FacetCell(status: 'brand', size: 12),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      g.title,
                                      style: V2Tokens.t3(
                                        fontWeight: FontWeight.w600,
                                        color: isFail ? V2Tokens.blockedSolid : V2Tokens.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      g.sub,
                                      style: V2Tokens.t4(
                                        color: isFail
                                            ? V2Tokens.blockedSolid
                                            : V2Tokens.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: const BoxDecoration(
              color: V2Tokens.surfaceCard,
              border: Border(top: BorderSide(color: V2Tokens.hairline, width: 1)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isBlocked || _submitting
                          ? null
                          : () async {
                              final nav = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() => _submitting = true);
                              try {
                                await widget.api.scheduleCampaign(
                                  widget.campaign.campaignId,
                                  testVer.versionId,
                                  _startDate.toIso8601String(),
                                  _endDate.toIso8601String(),
                                  testVer.channel,
                                );
                                if (mounted) nav.pop('SCHEDULED');
                              } catch (e) {
                                if (mounted) {
                                  setState(() => _submitting = false);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(e.toString().replaceAll('Exception: ', '')),
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isBlocked ? V2Tokens.surfaceRecessed : V2Tokens.inkPrussian,
                        disabledBackgroundColor: V2Tokens.surfaceRecessed,
                        foregroundColor:
                            isBlocked ? V2Tokens.textSecondary : V2Tokens.labelOnInk,
                        disabledForegroundColor: V2Tokens.textSecondary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                      child: Text(
                        _submitting
                            ? 'Booking flight…'
                            : (isBlocked ? 'Schedule blocked' : 'Schedule $verTag'),
                        style: V2Tokens.t2(
                          color: isBlocked ? V2Tokens.textSecondary : V2Tokens.labelOnInk,
                        ),
                      ),
                    ),
                  ),
                  if (isBlocked) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, 'OPEN_REVIEW'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: V2Tokens.surfaceCard,
                          foregroundColor: V2Tokens.inkPrussian,
                          side: const BorderSide(color: V2Tokens.inkPrussian, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        ),
                        child: Text(
                          'Review $verTag to unlock gate',
                          style: V2Tokens.t3(
                            color: V2Tokens.inkPrussian,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
