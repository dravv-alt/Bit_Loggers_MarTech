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

class _CampaignDetailScreenState extends State<CampaignDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Campaign? _campaign;
  bool _loading = true;
  List<DiscussionMessage> _discussions = [];

  // Review Form
  String _decisionType = 'APPROVED';
  final _reasonController = TextEditingController();
  final _policyController = TextEditingController();
  bool _submittingDecision = false;

  // Schedule Form
  final DateTime _startDate = DateTime.now();
  final DateTime _endDate = DateTime.now().add(const Duration(days: 14));
  String _scheduleChannel = 'Social';
  bool _submittingSchedule = false;

  // Discussion Form
  final _commentController = TextEditingController();
  bool _postingComment = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final c = await widget.api.getCampaign(widget.campaignId);
      final d = await widget.api.getDiscussions(widget.campaignId);
      setState(() {
        _campaign = c;
        _discussions = d;
        _scheduleChannel = c.currentVersion?.channel ?? 'Social';
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showSnack(e.toString(), isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade900 : Colors.teal.shade900,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitDecision() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      _showSnack('Validation Error: A justification reason is mandatory (LLD Section 3).', isError: true);
      return;
    }

    setState(() => _submittingDecision = true);
    try {
      await widget.api.makeDecision(
        widget.campaignId,
        _decisionType,
        _campaign!.currentVersionId,
        reason,
        policyReference: _policyController.text.trim().isEmpty ? null : _policyController.text.trim(),
      );
      _showSnack('Decision recorded: $_decisionType', isError: false);
      _reasonController.clear();
      _fetch();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      setState(() => _submittingDecision = false);
    }
  }

  Future<void> _submitSchedule() async {
    setState(() => _submittingSchedule = true);
    try {
      await widget.api.scheduleCampaign(
        widget.campaignId,
        _campaign!.currentVersionId,
        _startDate.toIso8601String(),
        _endDate.toIso8601String(),
        _scheduleChannel,
      );
      _showSnack('Campaign successfully scheduled on $_scheduleChannel!', isError: false);
      _fetch();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      setState(() => _submittingSchedule = false);
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _postingComment = true);
    try {
      await widget.api.postDiscussion(widget.campaignId, text);
      _commentController.clear();
      final d = await widget.api.getDiscussions(widget.campaignId);
      setState(() => _discussions = d);
      _showSnack('Comment posted', isError: false);
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      setState(() => _postingComment = false);
    }
  }

  Future<void> _toggleLock() async {
    try {
      if (_campaign?.activeLock?.holderId == widget.api.currentUser.id) {
        await widget.api.releaseLock(widget.campaignId);
        _showSnack('Edit lease released');
      } else {
        await widget.api.acquireLock(widget.campaignId);
        _showSnack('5-minute edit lease acquired');
      }
      _fetch();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _campaign == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final curVer = _campaign!.currentVersion;
    final kpi = curVer?.kpiProjected ?? KpiMetrics(conversionRate: 3.5, ctr: 4.2, roi: 3.8, cpa: 25, aov: 95);
    final isReviewer = widget.api.currentUser.role == 'reviewer';
    final isOwner = widget.api.currentUser.id == _campaign!.ownerId;
    final statusColor = AppTheme.getStatusColor(_campaign!.status);

    return Scaffold(
      appBar: AppBar(
        title: Text(_campaign!.title),
        actions: [
          if (isOwner && (_campaign!.status == 'Draft' || _campaign!.status == 'ChangesRequested' || _campaign!.status == 'Revised'))
            IconButton(
              icon: const Icon(Icons.edit, color: AppTheme.primary),
              tooltip: 'Revise Proposal',
              onPressed: () async {
                final updated = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CampaignWizardScreen(api: widget.api, existingCampaign: _campaign),
                  ),
                );
                if (updated == true) _fetch();
              },
            ),
          IconButton(
            icon: Icon(
              _campaign?.activeLock?.holderId == widget.api.currentUser.id ? Icons.lock_open : Icons.lock_outline,
              color: _campaign?.activeLock != null ? Colors.amber : Colors.grey,
            ),
            tooltip: 'Edit Lease',
            onPressed: _toggleLock,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Versions & Diff'),
            Tab(text: 'Governance Decision'),
            Tab(text: 'Discussions'),
            Tab(text: 'Schedule Flight'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: OVERVIEW
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Status ribbon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      _campaign!.status.toUpperCase(),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: statusColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                    ),
                    child: Text(
                      'Version v${curVer?.versionNo ?? 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.primary),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'by ${_campaign!.ownerName}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // AI Strategy Summary
              if (curVer?.aiSummary != null && curVer!.aiSummary!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C2A3D),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: AppTheme.primary, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'GEMINI ARGON AI PROPOSAL SUMMARY',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        curVer.aiSummary!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFFE2E8F0), fontStyle: FontStyle.italic, height: 1.4),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Budget & Channel
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('ALLOCATED BUDGET', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            '\$${(curVer?.budget ?? 0).toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('PRIMARY CHANNEL', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            curVer?.channel ?? 'Social',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Strategic Objective
              const Text('STRATEGIC OBJECTIVE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(curVer?.objective ?? '', style: const TextStyle(fontSize: 13, height: 1.4)),
              ),
              const SizedBox(height: 16),

              // Target Audience Persona
              const Text('TARGET AUDIENCE PERSONA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(curVer?.targetAudience ?? '', style: const TextStyle(fontSize: 13, height: 1.4)),
              ),
              const SizedBox(height: 20),

              // 5 Mandatory Projected KPIs
              const Text('5 MANDATORY PROJECTED MARTECH KPIS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _kpiBox('Conversion', '${kpi.conversionRate}%', AppTheme.primary),
                  const SizedBox(width: 8),
                  _kpiBox('CTR', '${kpi.ctr}%', const Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  _kpiBox('ROI', '${kpi.roi}x', const Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  _kpiBox('CPA', '\$${kpi.cpa.toInt()}', const Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  _kpiBox('AOV', '\$${kpi.aov.toInt()}', const Color(0xFFA855F7)),
                ],
              ),
            ],
          ),

          // TAB 2: VERSIONS & IMMUTABLE DIFF VIEWER
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _campaign!.versions.length,
            itemBuilder: (context, index) {
              final v = _campaign!.versions[index];
              final isCurrent = v.versionId == _campaign!.currentVersionId;
              final dec = _campaign!.decisions.where((d) => d.versionId == v.versionId).firstOrNull;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: isCurrent ? AppTheme.primary : AppTheme.cardBorder, width: isCurrent ? 1.5 : 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Version v${v.versionNo}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent ? AppTheme.primary : Colors.white,
                                ),
                              ),
                              if (isCurrent) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('ACTIVE', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                ),
                              ]
                            ],
                          ),
                          Text(v.createdAt.substring(0, 10), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Channel: ${v.channel} • Budget: \$${v.budget.toInt()}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(v.targetAudience, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      if (dec != null) ...[
                        const Divider(height: 16),
                        Row(
                          children: [
                            Text(dec.decisionType, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.getStatusColor(dec.decisionType))),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('by ${dec.reviewerName}: "${dec.reason}"', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),

          // TAB 3: GOVERNANCE DECISION (Reviewer / Self-approval prevented)
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!isReviewer)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade900.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: const Text(
                    'Note: Only Reviewers can record approval decisions. Marketers are prohibited from approving their own campaigns (QA-03 RBAC). Switch to Marcus Vance in the top menu to review.',
                    style: TextStyle(fontSize: 12, color: Colors.amberAccent),
                  ),
                )
              else if (_campaign!.status != 'Submitted')
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Campaign is in ${_campaign!.status} status and is not awaiting review.',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                )
              else ...[
                const Text('SELECT DECISION OUTCOME *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _decisionChoice('APPROVED', 'Approve', Colors.green),
                    const SizedBox(width: 8),
                    _decisionChoice('CHANGES_REQUESTED', 'Request Changes', Colors.orange),
                    const SizedBox(width: 8),
                    _decisionChoice('REJECTED', 'Reject', Colors.red),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('MANDATORY REASON * (Cannot be empty)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 6),
                TextField(
                  controller: _reasonController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Enter detailed justification for your decision...',
                  ),
                ),
                const SizedBox(height: 14),
                const Text('POLICY REFERENCE (Optional)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 6),
                TextField(
                  controller: _policyController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Q4 Growth Governance Standard §3.1',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submittingDecision ? null : _submitDecision,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _decisionType == 'APPROVED'
                        ? const Color(0xFF10B981)
                        : _decisionType == 'CHANGES_REQUESTED'
                            ? const Color(0xFFF97316)
                            : const Color(0xFFEF4444),
                  ),
                  child: _submittingDecision
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('Confirm $_decisionType Decision'),
                ),
              ],
            ],
          ),

          // TAB 4: DISCUSSIONS
          Column(
            children: [
              Expanded(
                child: _discussions.isEmpty
                    ? const Center(child: Text('No comments yet. Start the conversation below.', style: TextStyle(color: Colors.grey, fontSize: 12)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _discussions.length,
                        itemBuilder: (context, i) {
                          final msg = _discussions[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.card,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${msg.authorName} (${msg.authorRole})',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.primary),
                                    ),
                                    Text(msg.createdAt.substring(11, 16), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(msg.content, style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                color: AppTheme.surface,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: 'Write a comment or mention @marketer...',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: _postingComment ? const CircularProgressIndicator() : const Icon(Icons.send, color: AppTheme.primary),
                      onPressed: _postingComment ? null : _postComment,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // TAB 5: SCHEDULE FLIGHT (Marketers only)
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_campaign!.status != 'Approved')
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red),
                  ),
                  child: const Text(
                    'Scheduling Blocked: Only approved versions can be scheduled. This proposal must first receive an APPROVED decision (QA-01).',
                    style: TextStyle(fontSize: 12, color: Colors.redAccent),
                  ),
                )
              else ...[
                const Text('CHANNEL CONFIRMATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _scheduleChannel,
                  items: ['Social', 'Email', 'Search', 'Display', 'Influencer', 'Video']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _scheduleChannel = val);
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _submittingSchedule ? null : _submitSchedule,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  child: _submittingSchedule
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Confirm Flight Schedule'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpiBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _decisionChoice(String type, String title, MaterialColor color) {
    final selected = _decisionType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _decisionType = type),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.2) : AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? color : AppTheme.cardBorder, width: selected ? 1.5 : 1),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: selected ? color : Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

