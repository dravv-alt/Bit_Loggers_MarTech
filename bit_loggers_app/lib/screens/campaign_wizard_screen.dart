import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

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

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: AppTheme.leaf)),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Gemini Argon AI Assistant Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.leaf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderSage, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
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
                  child: const Row(
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
                const Text(
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
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.leaf))
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
          const Text(
            'CAMPAIGN TITLE *',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          TextField(controller: _titleController, decoration: const InputDecoration(hintText: 'e.g. Summer Solar Flash Sale')),
          const SizedBox(height: 16),

          // Channel & Budget
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
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
                          .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary))))
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
                    const Text(
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
          const SizedBox(height: 16),

          // Objective
          const Text(
            'STRATEGIC OBJECTIVE *',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          TextField(controller: _objectiveController, maxLines: 3, decoration: const InputDecoration(hintText: 'State marketing target...')),
          const SizedBox(height: 16),

          // Target Audience
          const Text(
            'TARGET AUDIENCE PERSONA *',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          TextField(controller: _audienceController, maxLines: 2, decoration: const InputDecoration(hintText: 'Target segment, persona...')),
          const SizedBox(height: 20),

          // 5 Projected KPIs (Pillar 2)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.leaf,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderSage),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '5 MANDATORY PROJECTED MARTECH KPIS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),
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
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting ? null : () => _save(false),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppTheme.leaf,
                    foregroundColor: AppTheme.forge,
                    elevation: 0,
                    side: const BorderSide(color: AppTheme.borderSage, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Save Draft',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.forge,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting ? null : () => _save(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.forge,
                    foregroundColor: AppTheme.leaf,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: AppTheme.leaf, strokeWidth: 2),
                        )
                      : Text(
                          isEditing ? 'Submit Revision' : 'Submit for Review',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.leaf,
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

  Widget _kpiInput(String label, double val, Function(double) onChanged) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppTheme.paper.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderSage, width: 0.5),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 4),
            TextFormField(
              initialValue: val.toString(),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              decoration: const InputDecoration(
                isDense: true,
                filled: true,
                fillColor: AppTheme.leaf,
                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                border: OutlineInputBorder(borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.forge, width: 1)),
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
}

