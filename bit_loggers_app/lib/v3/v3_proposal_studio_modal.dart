import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'v3_components.dart';
import 'v3_tokens.dart';

class V3ProposalStudioModal extends StatefulWidget {
  final ApiService api;
  final V3Palette palette;
  final Campaign? campaign;
  final VoidCallback onClose;
  final Future<void> Function() onSaved;
  final void Function(String title, String description, String status) onNotify;

  const V3ProposalStudioModal({
    super.key,
    required this.api,
    required this.palette,
    this.campaign,
    required this.onClose,
    required this.onSaved,
    required this.onNotify,
  });

  @override
  State<V3ProposalStudioModal> createState() => _V3ProposalStudioModalState();
}

class _V3ProposalStudioModalState extends State<V3ProposalStudioModal> {
  static const _channels = ['Social', 'Search', 'Email', 'Display', 'Video', 'Influencer'];

  late final TextEditingController _titleCtrl;
  late final TextEditingController _budgetCtrl;
  late final TextEditingController _objectiveCtrl;
  late final TextEditingController _audienceCtrl;
  late final TextEditingController _aiPromptCtrl;
  late final TextEditingController _cvrCtrl;
  late final TextEditingController _ctrCtrl;
  late final TextEditingController _roiCtrl;
  late final TextEditingController _cpaCtrl;
  late final TextEditingController _aovCtrl;

  String _channel = 'Social';
  String _aiSummary = '';
  bool _generatingAi = false;
  bool _saving = false;

  bool get _isEditing => widget.campaign != null;

  @override
  void initState() {
    super.initState();
    final c = widget.campaign;
    final ver = c?.currentVersion;
    _channel = ver?.channel ?? 'Social';
    _aiSummary = ver?.aiSummary ?? '';
    final kpi = ver?.kpiProjected;

    _titleCtrl = TextEditingController(text: c?.title ?? '');
    _budgetCtrl = TextEditingController(
      text: ((ver?.budget ?? 18000)).round().toString(),
    );
    _objectiveCtrl = TextEditingController(text: ver?.objective ?? '');
    _audienceCtrl = TextEditingController(text: ver?.targetAudience ?? '');
    _aiPromptCtrl = TextEditingController();
    _cvrCtrl = TextEditingController(text: (kpi?.conversionRate ?? 4.2).toString());
    _ctrCtrl = TextEditingController(text: (kpi?.ctr ?? 4.8).toString());
    _roiCtrl = TextEditingController(text: (kpi?.roi ?? 4.6).toString());
    _cpaCtrl = TextEditingController(text: (kpi?.cpa ?? 22.0).toString());
    _aovCtrl = TextEditingController(text: (kpi?.aov ?? 135.0).toString());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _budgetCtrl.dispose();
    _objectiveCtrl.dispose();
    _audienceCtrl.dispose();
    _aiPromptCtrl.dispose();
    _cvrCtrl.dispose();
    _ctrCtrl.dispose();
    _roiCtrl.dispose();
    _cpaCtrl.dispose();
    _aovCtrl.dispose();
    super.dispose();
  }

  Future<void> _draftAi() async {
    setState(() => _generatingAi = true);
    try {
      final res = await widget.api.draftWithAI(
        _aiPromptCtrl.text.trim().isNotEmpty
            ? _aiPromptCtrl.text.trim()
            : (_titleCtrl.text.trim().isNotEmpty
                ? _titleCtrl.text.trim()
                : 'Q4 Customer Acquisition Sprint'),
        channel: _channel,
        budget: double.tryParse(_budgetCtrl.text) ?? 18000,
      );
      if (!mounted) return;
      setState(() {
        if (_titleCtrl.text.trim().isEmpty && res['title'] != null) {
          _titleCtrl.text = res['title'].toString();
        }
        if (res['objective'] != null) _objectiveCtrl.text = res['objective'].toString();
        if (res['target_audience'] != null) _audienceCtrl.text = res['target_audience'].toString();
        if (res['channel'] != null) _channel = res['channel'].toString();
        if (res['budget'] != null) _budgetCtrl.text = res['budget'].toString();
        if (res['ai_summary'] != null) _aiSummary = res['ai_summary'].toString();
        if (res['kpi_projected'] is Map) {
          final k = Map<String, dynamic>.from(res['kpi_projected'] as Map);
          if (k['conversionRate'] != null) _cvrCtrl.text = k['conversionRate'].toString();
          if (k['ctr'] != null) _ctrCtrl.text = k['ctr'].toString();
          if (k['roi'] != null) _roiCtrl.text = k['roi'].toString();
          if (k['cpa'] != null) _cpaCtrl.text = k['cpa'].toString();
          if (k['aov'] != null) _aovCtrl.text = k['aov'].toString();
        }
      });
      widget.onNotify(
        'Proposal brief synthesized',
        'Review generated targets and submit when ready.',
        'success',
      );
    } catch (e) {
      widget.onNotify('AI assist failed', e.toString(), 'error');
    } finally {
      if (mounted) setState(() => _generatingAi = false);
    }
  }

  Future<void> _commit({required bool submit}) async {
    if (_titleCtrl.text.trim().isEmpty ||
        _objectiveCtrl.text.trim().isEmpty ||
        _audienceCtrl.text.trim().isEmpty) {
      widget.onNotify(
        'Missing required fields',
        'Title, objective, and target audience must all be filled out.',
        'error',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final budgetVal = (double.tryParse(_budgetCtrl.text) ?? 18000).clamp(500.0, 500000.0);
      final payload = {
        'title': _titleCtrl.text.trim(),
        'channel': _channel,
        'budget': budgetVal,
        'objective': _objectiveCtrl.text.trim(),
        'target_audience': _audienceCtrl.text.trim(),
        'kpi_projected': {
          'conversionRate': double.tryParse(_cvrCtrl.text) ?? 4.2,
          'ctr': double.tryParse(_ctrCtrl.text) ?? 4.8,
          'roi': double.tryParse(_roiCtrl.text) ?? 4.6,
          'cpa': double.tryParse(_cpaCtrl.text) ?? 22.0,
          'aov': double.tryParse(_aovCtrl.text) ?? 135.0,
        },
        if (_aiSummary.isNotEmpty) 'ai_summary': _aiSummary,
      };

      final saved = _isEditing
          ? await widget.api.updateCampaign(
              widget.campaign!.campaignId,
              payload,
              expectedVersion: widget.campaign!.currentVersion?.versionNo,
            )
          : await widget.api.createCampaign(payload);

      if (submit) {
        await widget.api.submitCampaign(saved.campaignId);
      }

      widget.onNotify(
        submit ? 'Submitted for reviewer signoff' : 'Draft version saved',
        '${saved.title} · version v${saved.currentVersion?.versionNo ?? 1}',
        'success',
      );
      await widget.onSaved();
      widget.onClose();
    } catch (e) {
      widget.onNotify('Could not save brief', e.toString(), 'error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final verTag = _isEditing
        ? 'Creates v${(widget.campaign!.currentVersion?.versionNo ?? 1) + 1}'
        : 'Creates v1';

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 660,
          margin: const EdgeInsets.all(16),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          decoration: BoxDecoration(
            color: p.bgPrimary,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: p.borderDefault),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 42,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 14, 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: p.separator)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _isEditing
                                ? 'Revise ${widget.campaign!.title}'
                                : 'New campaign proposal',
                            style: V3Tokens.title2(p),
                          ),
                          V3Badge(label: verTag, palette: p),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onClose,
                      icon: Icon(Icons.close_rounded, color: p.iconSecondary),
                    ),
                  ],
                ),
              ),

              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // AI Brief Assistant
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
                            Row(
                              children: [
                                Icon(Icons.auto_awesome_outlined, size: 16, color: p.accentText),
                                const SizedBox(width: 6),
                                Text('AI brief assistant', style: V3Tokens.bodyMedium(p)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _aiPromptCtrl,
                                    style: V3Tokens.bodyMedium(p),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      filled: true,
                                      fillColor: p.bgPrimary,
                                      hintText: 'Describe launch goal, offer, or audience segment…',
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
                                ),
                                const SizedBox(width: 8),
                                V3Button(
                                  label: _generatingAi ? 'Generating…' : 'Draft brief',
                                  icon: Icons.auto_awesome_outlined,
                                  palette: p,
                                  onTap: _generatingAi ? null : _draftAi,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      _labeledField(p, 'Campaign title *', _titleCtrl, 'e.g. Q4 Enterprise Launch'),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Primary channel', style: V3Tokens.caption(p)),
                                const SizedBox(height: 6),
                                PopupMenuButton<String>(
                                  color: p.bgPrimary,
                                  onSelected: (ch) => setState(() => _channel = ch),
                                  itemBuilder: (_) => _channels
                                      .map((ch) => PopupMenuItem(
                                          value: ch, child: Text(ch, style: V3Tokens.bodyMedium(p))))
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
                                        Text(_channel, style: V3Tokens.bodyMedium(p)),
                                        Icon(Icons.keyboard_arrow_down_rounded,
                                            color: p.iconSecondary),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _labeledField(
                              p,
                              'Total budget (USD) *',
                              _budgetCtrl,
                              '18000',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _labeledField(
                        p,
                        'Campaign objective *',
                        _objectiveCtrl,
                        'State measurable conversion goals, offer positioning, and guardrails…',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      _labeledField(
                        p,
                        'Target audience segment *',
                        _audienceCtrl,
                        'Specify buyer cohort, exclusions, and regional constraints…',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: p.bgSecondary,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: p.borderDefault),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Projected KPI targets', style: V3Tokens.bodyMedium(p)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _smallKpiField(p, 'CVR (%)', _cvrCtrl),
                                _smallKpiField(p, 'CTR (%)', _ctrCtrl),
                                _smallKpiField(p, 'ROI (x)', _roiCtrl),
                                _smallKpiField(p, 'CPA (\$)', _cpaCtrl),
                                _smallKpiField(p, 'AOV (\$)', _aovCtrl),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: p.separator)),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    V3Button(
                      label: 'Cancel',
                      variant: V3ButtonVariant.ghost,
                      palette: p,
                      onTap: _saving ? null : widget.onClose,
                    ),
                    V3Button(
                      label: 'Save draft',
                      icon: Icons.save_outlined,
                      palette: p,
                      onTap: _saving ? null : () => _commit(submit: false),
                    ),
                    V3Button(
                      label: _saving ? 'Submitting…' : 'Save & submit for review',
                      icon: Icons.send_outlined,
                      variant: V3ButtonVariant.primary,
                      palette: p,
                      onTap: _saving ? null : () => _commit(submit: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _labeledField(
    V3Palette p,
    String label,
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: V3Tokens.caption(p)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: V3Tokens.bodyMedium(p),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: p.bgPrimary,
            hintText: hint,
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
      ],
    );
  }

  Widget _smallKpiField(V3Palette p, String label, TextEditingController ctrl) {
    return SizedBox(
      width: 106,
      child: _labeledField(p, label, ctrl, '0', keyboardType: TextInputType.number),
    );
  }
}
