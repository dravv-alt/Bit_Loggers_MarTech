import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/marketing_visuals.dart';

class CampaignWizardScreen extends StatefulWidget {
  final ApiService api;
  final Campaign? existingCampaign;

  const CampaignWizardScreen({super.key, required this.api, this.existingCampaign});

  @override
  State<CampaignWizardScreen> createState() => _CampaignWizardScreenState();
}

class _CampaignWizardScreenState extends State<CampaignWizardScreen> {
  final _titleController = TextEditingController();
  final _objectiveController = TextEditingController();
  final _audienceController = TextEditingController();
  final _budgetController = TextEditingController(text: '12500');
  final _aiPromptController = TextEditingController();

  String _channel = 'Social';
  double _conversionRate = 3.5;
  double _ctr = 4.2;
  double _roi = 3.8;
  double _cpa = 25.0;
  double _aov = 95.0;
  String? _aiSummary;

  bool _isGeneratingAi = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onFieldChanged);
    _objectiveController.addListener(_onFieldChanged);
    _audienceController.addListener(_onFieldChanged);
    _budgetController.addListener(_onFieldChanged);
    if (widget.existingCampaign != null) {
      final c = widget.existingCampaign!;
      final v = c.currentVersion;
      _titleController.text = c.title;
      _channel = v?.channel ?? 'Social';
      _budgetController.text = (v?.budget ?? 12500).toInt().toString();
      _objectiveController.text = v?.objective ?? '';
      _audienceController.text = v?.targetAudience ?? '';
      if (v?.kpiProjected != null) {
        _conversionRate = v!.kpiProjected.conversionRate;
        _ctr = v.kpiProjected.ctr;
        _roi = v.kpiProjected.roi;
        _cpa = v.kpiProjected.cpa;
        _aov = v.kpiProjected.aov;
      }
      _aiSummary = v?.aiSummary;
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onFieldChanged);
    _objectiveController.removeListener(_onFieldChanged);
    _audienceController.removeListener(_onFieldChanged);
    _budgetController.removeListener(_onFieldChanged);
    _titleController.dispose();
    _objectiveController.dispose();
    _audienceController.dispose();
    _budgetController.dispose();
    _aiPromptController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: AppTheme.leaf)),
        backgroundColor: isError ? AppTheme.statusRejected : AppTheme.forge,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _generateAi() async {
    final prompt = _aiPromptController.text.trim().isNotEmpty
        ? _aiPromptController.text.trim()
        : _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : 'Summer Solar Flash Sale';

    setState(() => _isGeneratingAi = true);
    try {
      final res = await widget.api.draftWithAI(
        prompt,
        channel: _channel,
        budget: double.tryParse(_budgetController.text) ?? 12500,
      );

      setState(() {
        if (res['title'] != null) _titleController.text = res['title'];
        if (res['objective'] != null) _objectiveController.text = res['objective'];
        if (res['target_audience'] != null) _audienceController.text = res['target_audience'];
        if (res['channel'] != null) _channel = res['channel'];
        if (res['budget'] != null) _budgetController.text = (res['budget'] as num).toInt().toString();

        if (res['kpi_projected'] != null) {
          final kp = res['kpi_projected'];
          _conversionRate = (kp['conversionRate'] as num?)?.toDouble() ?? 3.5;
          _ctr = (kp['ctr'] as num?)?.toDouble() ?? 4.2;
          _roi = (kp['roi'] as num?)?.toDouble() ?? 3.8;
          _cpa = (kp['cpa'] as num?)?.toDouble() ?? 25.0;
          _aov = (kp['aov'] as num?)?.toDouble() ?? 95.0;
        }
        _aiSummary = res['ai_summary'];
      });

      _showSnack('Gemini Argon proposal drafted! Review and verify parameters below.');
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      setState(() => _isGeneratingAi = false);
    }
  }

  Future<void> _save(bool submitDirectly) async {
    final title = _titleController.text.trim();
    final objective = _objectiveController.text.trim();
    final audience = _audienceController.text.trim();
    final budget = double.tryParse(_budgetController.text) ?? 10000;

    if (title.isEmpty || objective.isEmpty || audience.isEmpty) {
      _showSnack('Please complete Title, Objective, and Target Audience.', isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      final payload = {
        'title': title,
        'channel': _channel,
        'budget': budget,
        'objective': objective,
        'target_audience': audience,
        'kpi_projected': {
          'conversionRate': _conversionRate,
          'ctr': _ctr,
          'roi': _roi,
          'cpa': _cpa,
          'aov': _aov,
        },
        'ai_summary': _aiSummary,
      };

      Campaign saved;
      if (widget.existingCampaign != null) {
        saved = await widget.api.updateCampaign(
          widget.existingCampaign!.campaignId,
          payload,
          expectedVersion: widget.existingCampaign!.currentVersion?.versionNo,
        );
        _showSnack('Proposal revised: Version v${saved.currentVersion?.versionNo}');
      } else {
        saved = await widget.api.createCampaign(payload);
        _showSnack('Proposal created as Draft (v1)');
      }

      if (submitDirectly) {
        await widget.api.submitCampaign(saved.campaignId);
        _showSnack('Submitted for review with Idempotency Key protection.');
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingCampaign != null;

    return Scaffold(
      backgroundColor: AppTheme.paper,
      appBar: AppBar(
        title: Text(isEditing ? 'Revise Proposal' : 'Author Campaign Proposal'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Gemini Argon AI Assistant Card
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.verdictLime.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.verdictLimeDark, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: AppTheme.forge, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'GEMINI ARGON AI STRATEGIST',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.forge,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter a campaign theme or goal. Gemini will structure your objective, target persona, and forecast 5 KPIs.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _aiPromptController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Q4 Black Friday VIP Early Access Blitz...',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isGeneratingAi ? null : _generateAi,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.forge,
                        foregroundColor: AppTheme.leaf,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      icon: _isGeneratingAi
                          ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.leaf))
                          : const Icon(Icons.bolt, size: 16),
                      label: const Text('Draft AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'CAMPAIGN TITLE *',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          TextField(controller: _titleController, decoration: const InputDecoration(hintText: 'e.g. Summer Solar Flash Sale')),
          const SizedBox(height: 16),

          // Visual Channel Selector
          Text(
            'SELECT CHANNEL DESTINATION',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          _buildVisualChannelSelector(),
          const SizedBox(height: 14),

          // Channel & Budget
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CHANNEL',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _channel,
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
                      dropdownColor: AppTheme.leaf,
                      items: ['Social', 'Email', 'Search', 'Display', 'Influencer', 'Video']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(fontSize: 12, color: AppTheme.textPrimary))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _channel = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BUDGET (USD \$) *',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _budgetController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '10000', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Vitruvian Budget Controls & Spend Pacing Dial
          _buildVitruvianBudgetControls(),
          const SizedBox(height: 16),

          // Objective
          Text(
            'STRATEGIC OBJECTIVE *',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          TextField(controller: _objectiveController, maxLines: 3, decoration: const InputDecoration(hintText: 'State marketing target...')),
          const SizedBox(height: 16),

          // Target Audience
          Text(
            'TARGET AUDIENCE PERSONA *',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          TextField(controller: _audienceController, maxLines: 2, decoration: const InputDecoration(hintText: 'Target segment, persona...')),
          const SizedBox(height: 16),

          // Live Ad Mockup Preview
          _buildLiveAdMockupPreview(),
          const SizedBox(height: 20),

          // Projected Performance Benchmarks
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.secondarySystemBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.appleCardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Projected performance benchmarks',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.label,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Estimated conversion, engagement, and returns',
                  style: TextStyle(fontSize: 12, color: AppTheme.secondaryLabel),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _kpiInput('Conv (%)', _conversionRate, (v) => setState(() => _conversionRate = v)),
                    const SizedBox(width: 8),
                    _kpiInput('CTR (%)', _ctr, (v) => setState(() => _ctr = v)),
                    const SizedBox(width: 8),
                    _kpiInput('ROI (x)', _roi, (v) => setState(() => _roi = v)),
                    const SizedBox(width: 8),
                    _kpiInput('CPA (\$)', _cpa, (v) => setState(() => _cpa = v)),
                    const SizedBox(width: 8),
                    _kpiInput('AOV (\$)', _aov, (v) => setState(() => _aov = v)),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 0.5, color: AppTheme.separator),
                const SizedBox(height: 10),
                _buildKpiSummaryBenchmark(),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    ),
    bottomNavigationBar: Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.secondarySystemBackground,
        border: Border(top: BorderSide(color: AppTheme.separator, width: 0.5)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _submitting ? null : () => _save(false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.tertiarySystemBackground,
                  foregroundColor: AppTheme.label,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Save Draft',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.label,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _submitting ? null : () => _save(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.label,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _submitting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: AppTheme.leaf, strokeWidth: 2),
                      )
                    : Text(
                        isEditing ? 'Submit Revision' : 'Submit for Review',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.leaf,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _kpiInput(String label, double val, Function(double) onChanged) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppTheme.tertiarySystemBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.secondaryLabel),
            ),
            const SizedBox(height: 4),
            TextFormField(
              initialValue: val.toString(),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.label,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: AppTheme.secondarySystemBackground,
                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                border: OutlineInputBorder(borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.label, width: 1)),
              ),
              onChanged: (text) {
                final d = double.tryParse(text);
                if (d != null) onChanged(d);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualChannelSelector() {
    final channels = [
      {'id': 'Social', 'label': 'Social Feed', 'icon': Icons.share_rounded, 'tag': 'Reach · Virality'},
      {'id': 'Search', 'label': 'Search SEM', 'icon': Icons.search_rounded, 'tag': 'Intent · Direct'},
      {'id': 'Email', 'label': 'Email CRM', 'icon': Icons.mail_outline_rounded, 'tag': 'Retention · LTV'},
      {'id': 'Display', 'label': 'Display Ads', 'icon': Icons.web_rounded, 'tag': 'Awareness · Scale'},
      {'id': 'Video', 'label': 'Video Pre-Roll', 'icon': Icons.play_circle_outline_rounded, 'tag': 'Engagement'},
      {'id': 'Influencer', 'label': 'Creator Hub', 'icon': Icons.star_outline_rounded, 'tag': 'Affinity'},
    ];

    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: channels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final ch = channels[index];
          final isSelected = _channel == ch['id'];
          return GestureDetector(
            onTap: () {
              setState(() {
                _channel = ch['id'] as String;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 125,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.label : AppTheme.secondarySystemBackground,
                borderRadius: BorderRadius.circular(14),
                boxShadow: isSelected ? AppTheme.appleFloatingShadow : AppTheme.appleCardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(
                        ch['icon'] as IconData,
                        size: 16,
                        color: isSelected ? AppTheme.leaf : AppTheme.forge,
                      ),
                      const Spacer(),
                      if (isSelected)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.warmAmber,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ch['label'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.leaf : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ch['tag'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? AppTheme.leaf.withOpacity(0.7) : AppTheme.textSecondary,
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

  Widget _buildVitruvianBudgetControls() {
    final presets = [5000.0, 10000.0, 25000.0, 50000.0, 100000.0];
    final currentBudget = double.tryParse(_budgetController.text) ?? 10000.0;
    final dailyRate = currentBudget / 14.0;
    final burnPercent = (currentBudget / 100000.0).clamp(0.05, 1.0);

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Pacing & daily run-rate',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.label,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.moss.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '\$${dailyRate.toStringAsFixed(0)}/day (14d flight)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.moss,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Presets row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: presets.map((p) {
                final isCur = (currentBudget - p).abs() < 1.0;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      _budgetController.text = p.toStringAsFixed(0);
                      _onFieldChanged();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCur ? AppTheme.label : AppTheme.tertiarySystemBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        p >= 1000 ? '\$${(p / 1000).toStringAsFixed(0)}k' : '\$$p',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isCur ? Colors.white : AppTheme.label,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Live Burn Bar with 75% red needle
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppTheme.bone,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (burnPercent * 0.72).clamp(0.04, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.moss, AppTheme.warmAmber],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: -2,
                bottom: -2,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final needleLeft = constraints.maxWidth * 0.75;
                    return Stack(
                      children: [
                        Positioned(
                          left: needleLeft,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 2,
                            color: AppTheme.crimsonNeedle,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Allocated: \$${currentBudget.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 10, color: AppTheme.crimsonNeedle),
                  SizedBox(width: 3),
                  Text(
                    '75% Ceiling Warning Needle',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.crimsonNeedle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveAdMockupPreview() {
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : 'Summer Solar Flash Sale';
    final objective = _objectiveController.text.trim().isNotEmpty
        ? _objectiveController.text.trim()
        : 'Direct acquisition of high-efficiency rooftop residential solar units.';
    final audience = _audienceController.text.trim().isNotEmpty
        ? _audienceController.text.trim()
        : 'Suburban homeowners, Eco-conscious tier';
    final currentBudget = double.tryParse(_budgetController.text) ?? 10000.0;

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.forge,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _channel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.leaf,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AD CREATIVE CANVAS · LIVE FLIGHT PREVIEW',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.moss.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fiber_manual_record, size: 7, color: AppTheme.moss),
                    SizedBox(width: 3),
                    Text(
                      'Live Mockup',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.moss,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Live Multi-Channel Ad Studio Mockup
          LiveCreativeMockupCanvas(
            channel: _channel,
            title: title,
            headline: title,
            copy: objective.isNotEmpty ? objective : 'Targeted programmatic reach: $audience',
            targetCpa: _cpa,
          ),
          const SizedBox(height: 12),
          // Audience Persona & Budget Cap Chip
          Row(
            children: [
              Icon(Icons.people_alt_outlined, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Audience: $audience · Cap: \$${currentBudget.toInt()}',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryBenchmark() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'BENCHMARK TELEMETRY & PROJECTED HEALTH',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.moss.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '5/5 Monitored',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.moss,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildKpiSparkChip('Conv', '${_conversionRate.toStringAsFixed(1)}%', 'vs 2.4% avg', _conversionRate >= 2.4),
            _buildKpiSparkChip('CTR', '${_ctr.toStringAsFixed(1)}%', 'vs 3.2% avg', _ctr >= 3.2),
            _buildKpiSparkChip('ROI', '${_roi.toStringAsFixed(1)}x', 'vs 3.0x avg', _roi >= 3.0),
            _buildKpiSparkChip('CPA', '\$${_cpa.toStringAsFixed(0)}', 'vs \$35 target', _cpa <= 35.0),
            _buildKpiSparkChip('AOV', '\$${_aov.toStringAsFixed(0)}', 'vs \$85 target', _aov >= 85.0),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiSparkChip(String label, String value, String benchmark, bool isPositive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.tertiarySystemBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.secondaryLabel,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.label,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 9,
            color: isPositive ? AppTheme.moss : AppTheme.warmAmber,
          ),
          const SizedBox(width: 2),
          Text(
            benchmark,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w500,
              color: isPositive ? AppTheme.moss : AppTheme.warmAmber,
            ),
          ),
        ],
      ),
    );
  }
}

