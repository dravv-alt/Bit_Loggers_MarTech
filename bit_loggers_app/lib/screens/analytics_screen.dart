import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class _MetricInfo {
  final String key;
  final String title;
  final String shortTitle;
  final String unit;
  final bool isPrefix;
  final bool isLowerBetter;
  final Color accentColor;

  const _MetricInfo({
    required this.key,
    required this.title,
    required this.shortTitle,
    required this.unit,
    required this.isPrefix,
    required this.isLowerBetter,
    required this.accentColor,
  });

  String formatValue(num value) {
    final formatted = value.toStringAsFixed(value is int || value == value.roundToDouble() ? 1 : 2);
    return isPrefix ? '$unit$formatted' : '$formatted$unit';
  }
}

class AnalyticsScreen extends StatefulWidget {
  final ApiService api;

  const AnalyticsScreen({super.key, required this.api});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _errorMessage;

  String _selectedChannel = 'All';
  String _datePreset = '30D'; // '7D', '30D', '90D', 'Custom'
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  String _selectedMetric = 'roi';
  int? _hoveredIndex;

  static const Map<String, _MetricInfo> _metrics = {
    'roi': _MetricInfo(
      key: 'roi',
      title: 'Return on Investment',
      shortTitle: 'ROI',
      unit: 'x',
      isPrefix: false,
      isLowerBetter: false,
      accentColor: AppTheme.forge,
    ),
    'conversionRate': _MetricInfo(
      key: 'conversionRate',
      title: 'Conversion Rate',
      shortTitle: 'Conv Rate',
      unit: '%',
      isPrefix: false,
      isLowerBetter: false,
      accentColor: Color(0xFF2C5E43),
    ),
    'ctr': _MetricInfo(
      key: 'ctr',
      title: 'Click-Through Rate',
      shortTitle: 'CTR',
      unit: '%',
      isPrefix: false,
      isLowerBetter: false,
      accentColor: Color(0xFF3B5249),
    ),
    'cpa': _MetricInfo(
      key: 'cpa',
      title: 'Cost Per Acquisition',
      shortTitle: 'CPA',
      unit: '\$',
      isPrefix: true,
      isLowerBetter: true,
      accentColor: Color(0xFF8A5A36),
    ),
    'aov': _MetricInfo(
      key: 'aov',
      title: 'Average Order Value',
      shortTitle: 'AOV',
      unit: '\$',
      isPrefix: true,
      isLowerBetter: false,
      accentColor: Color(0xFF4A5E54),
    ),
  };

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final startIso = DateFormat('yyyy-MM-dd').format(_startDate);
      final endIso = DateFormat('yyyy-MM-dd').format(_endDate);

      final res = await widget.api.getAnalytics(
        channel: _selectedChannel == 'All' ? null : _selectedChannel,
        startDate: startIso,
        endDate: endIso,
        interval: '1 day',
      );

      if (mounted) {
        setState(() {
          _data = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _applyDatePreset(String preset) {
    final now = DateTime.now();
    DateTime start;
    if (preset == '7D') {
      start = now.subtract(const Duration(days: 7));
    } else if (preset == '30D') {
      start = now.subtract(const Duration(days: 30));
    } else if (preset == '90D') {
      start = now.subtract(const Duration(days: 90));
    } else {
      return;
    }

    setState(() {
      _datePreset = preset;
      _startDate = start;
      _endDate = now;
      _hoveredIndex = null;
    });
    _fetch();
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.forge,
              onPrimary: AppTheme.leaf,
              surface: AppTheme.leaf,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _datePreset = 'Custom';
        _startDate = picked.start;
        _endDate = picked.end;
        _hoveredIndex = null;
      });
      _fetch();
    }
  }

  List<Map<String, dynamic>> _getTrendsList() {
    if (_data == null || _data!['trends'] == null) return [];
    final raw = _data!['trends'] as List;
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final kpis = _data?['summary']?['kpis'] as Map<String, dynamic>? ?? {};
    final breakdown = (_data?['channelBreakdown'] as List?) ?? [];
    final totalBudget = (_data?['summary']?['totalBudget'] as num?)?.toDouble() ?? 0.0;
    final totalCampaigns = (_data?['summary']?['totalCampaigns'] as num?)?.toInt() ?? 0;
    final trends = _getTrendsList();
    final activeMetricInfo = _metrics[_selectedMetric] ?? _metrics['roi']!;

    return Scaffold(
      backgroundColor: AppTheme.paper,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Intelligence & Analytics',
              style: AppTheme.serifHeadline(fontSize: 18, color: AppTheme.textPrimary),
            ),
            const Text(
              'TimescaleDB Continuous Aggregations (FR-09)',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textPrimary),
            tooltip: 'Refresh Telemetry',
            onPressed: _fetch,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.forge))
          : _errorMessage != null
              ? _buildErrorView()
              : RefreshIndicator(
                  color: AppTheme.forge,
                  onRefresh: _fetch,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      // Filter Controls (Date Presets + Custom Range + Channels)
                      _buildFilterSection(),
                      const SizedBox(height: 16),

                      // Historical Trend Lines Chart (TimescaleDB time_bucket)
                      _buildTrendChartCard(trends, activeMetricInfo),
                      const SizedBox(height: 16),

                      // 5 Mandatory KPI Cards Grid
                      _buildKpiSection(kpis),
                      const SizedBox(height: 20),

                      // Channel Economics & Portfolio Breakdown
                      _buildChannelEconomicsCard(breakdown, totalBudget, totalCampaigns),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 48, color: AppTheme.statusRejected),
            const SizedBox(height: 12),
            Text(
              'Telemetry Feed Error',
              style: AppTheme.serifHeadline(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Failed to load telemetry snapshots.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.forge,
                foregroundColor: AppTheme.leaf,
              ),
              onPressed: _fetch,
              child: const Text('Retry Connection'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final dateRangeStr = '${dateFormat.format(_startDate)} – ${dateFormat.format(_endDate)}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSage),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Date Range Presets & Custom Picker Trigger
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  dateRangeStr,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: _pickCustomDateRange,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _datePreset == 'Custom' ? AppTheme.forge : AppTheme.paper,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.borderSage),
                  ),
                  child: Text(
                    'Custom',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _datePreset == 'Custom' ? AppTheme.leaf : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Presets pills: 7D, 30D, 90D
          Row(
            children: [
              _presetChip('Last 7 Days', '7D'),
              const SizedBox(width: 8),
              _presetChip('Last 30 Days', '30D'),
              const SizedBox(width: 8),
              _presetChip('Quarter to Date', '90D'),
            ],
          ),
          const Divider(height: 20, color: AppTheme.borderSage),

          // Row 2: Channel filter pills
          Row(
            children: [
              const Text(
                'CHANNEL:',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Social', 'Search', 'Email', 'Display', 'Video', 'Influencer'].map((ch) {
                      final isSelected = _selectedChannel == ch;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(ch),
                          selected: isSelected,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppTheme.leaf : AppTheme.textPrimary,
                          ),
                          selectedColor: AppTheme.forge,
                          backgroundColor: AppTheme.paper,
                          side: BorderSide(
                            color: isSelected ? AppTheme.forge : AppTheme.borderSage,
                            width: 1,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _selectedChannel = ch);
                              _fetch();
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _presetChip(String label, String presetCode) {
    final isSelected = _datePreset == presetCode;
    return Expanded(
      child: InkWell(
        onTap: () => _applyDatePreset(presetCode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.forge : AppTheme.paper,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppTheme.forge : AppTheme.borderSage),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppTheme.leaf : AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HISTORICAL TREND LINES & TIMESCALEDB TIME_BUCKET VISUALIZER
  // ---------------------------------------------------------------------------
  Widget _buildTrendChartCard(List<Map<String, dynamic>> trends, _MetricInfo activeMetric) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSage),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title + TimescaleDB Badge
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                'Historical Performance Flights',
                style: AppTheme.serifHeadline(fontSize: 15),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.paper,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderSage),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    const Text(
                      'hypertable time_bucket',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Metric Switcher Tabs (ROI, Conv Rate, CTR, CPA, AOV)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _metrics.values.map((metric) {
                final isSelected = _selectedMetric == metric.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedMetric = metric.key;
                        _hoveredIndex = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.forge : AppTheme.paper,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppTheme.forge : AppTheme.borderSage,
                        ),
                      ),
                      child: Text(
                        metric.shortTitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppTheme.verdictLime : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Legend & Scrubber Banner
          _buildChartLegend(trends, activeMetric),
          const SizedBox(height: 12),

          // The Custom Painted Interactive Line Graph
          trends.isEmpty
              ? Container(
                  height: 180,
                  alignment: Alignment.center,
                  child: const Text('No time-series snapshots recorded for this range.', style: TextStyle(color: AppTheme.textSecondary)),
                )
              : SizedBox(
                  height: 190,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onPanStart: (details) => _updateHoverIndex(details.localPosition.dx, constraints.maxWidth, trends.length),
                        onPanUpdate: (details) => _updateHoverIndex(details.localPosition.dx, constraints.maxWidth, trends.length),
                        onPanEnd: (_) => setState(() => _hoveredIndex = null),
                        onTapDown: (details) => _updateHoverIndex(details.localPosition.dx, constraints.maxWidth, trends.length),
                        onTapCancel: () => setState(() => _hoveredIndex = null),
                        child: CustomPaint(
                          size: Size(constraints.maxWidth, 190),
                          painter: _HistoricalTrendPainter(
                            trends: trends,
                            metricKey: activeMetric.key,
                            accentColor: activeMetric.accentColor,
                            hoveredIndex: _hoveredIndex,
                          ),
                        ),
                      );
                    },
                  ),
                ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.borderSage),
          const SizedBox(height: 10),

          // Statistical Summary Chips (Min, Max, Avg)
          _buildTrendStats(trends, activeMetric),
        ],
      ),
    );
  }

  void _updateHoverIndex(double localX, double totalWidth, int count) {
    if (count <= 1 || totalWidth <= 0) return;
    const padding = 34.0;
    final graphWidth = totalWidth - padding;
    final relativeX = (localX - padding).clamp(0.0, graphWidth);
    final ratio = relativeX / graphWidth;
    final index = (ratio * (count - 1)).round().clamp(0, count - 1);
    setState(() => _hoveredIndex = index);
  }

  Widget _buildChartLegend(List<Map<String, dynamic>> trends, _MetricInfo activeMetric) {
    if (_hoveredIndex != null && _hoveredIndex! < trends.length) {
      final point = trends[_hoveredIndex!];
      final date = point['date'] ?? '';
      final actualVal = (point['actual']?[activeMetric.key] as num?)?.toDouble() ?? 0.0;
      final projVal = (point['projected']?[activeMetric.key] as num?)?.toDouble() ?? 0.0;
      final diff = projVal > 0 ? ((actualVal - projVal) / projVal) * 100 : 0.0;
      final isFavorable = activeMetric.isLowerBetter ? diff <= 0 : diff >= 0;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.paper,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderSage),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.touch_app, size: 14, color: AppTheme.forge),
                const SizedBox(width: 4),
                Text(
                  date,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
              ],
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 2,
              children: [
                Text(
                  'Actual: ${activeMetric.formatValue(actualVal)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.forge),
                ),
                Text(
                  'Target: ${activeMetric.formatValue(projVal)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: isFavorable ? AppTheme.verdictLime : AppTheme.statusRejected.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isFavorable ? AppTheme.forge : AppTheme.statusRejected,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 14, height: 3, decoration: const BoxDecoration(color: AppTheme.forge, borderRadius: BorderRadius.all(Radius.circular(2)))),
                const SizedBox(width: 5),
                const Text('Actual Telemetry', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 2,
                  decoration: const BoxDecoration(color: Color(0xFF94A3B8)),
                ),
                const SizedBox(width: 5),
                const Text('Projected Baseline', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
        const Text(
          'Drag/Tap to inspect',
          style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildTrendStats(List<Map<String, dynamic>> trends, _MetricInfo activeMetric) {
    if (trends.isEmpty) return const SizedBox.shrink();

    final actualValues = trends.map((t) => (t['actual']?[activeMetric.key] as num?)?.toDouble() ?? 0.0).toList();
    final minVal = actualValues.reduce(math.min);
    final maxVal = actualValues.reduce(math.max);
    final avgVal = actualValues.reduce((a, b) => a + b) / actualValues.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _statChip('MINIMUM', activeMetric.formatValue(minVal)),
        _statChip('AVERAGE', activeMetric.formatValue(avgVal)),
        _statChip('MAXIMUM', activeMetric.formatValue(maxVal)),
        _statChip('SNAPSHOTS', '${trends.length} days'),
      ],
    );
  }

  Widget _statChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 5 MANDATORY KPIS DISPLAY (SECTION 1.3 / FR-09)
  // ---------------------------------------------------------------------------
  Widget _buildKpiSection(Map<String, dynamic> kpis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            const Text(
              '5 MANDATORY METRICS (PROJECTED VS ACTUAL)',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5),
            ),
            Text(
              'Tap card to inspect telemetry',
              style: TextStyle(fontSize: 10, color: AppTheme.forge.withOpacity(0.8), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _kpiInteractiveCard('roi', kpis['roi']),
        _kpiInteractiveCard('conversionRate', kpis['conversionRate']),
        _kpiInteractiveCard('ctr', kpis['ctr']),
        _kpiInteractiveCard('cpa', kpis['cpa']),
        _kpiInteractiveCard('aov', kpis['aov']),
      ],
    );
  }

  Widget _kpiInteractiveCard(String metricKey, Map<String, dynamic>? data) {
    final info = _metrics[metricKey]!;
    final isSelected = _selectedMetric == metricKey;

    final proj = (data?['projected'] as num?)?.toDouble() ?? 0.0;
    final act = (data?['actual'] as num?)?.toDouble() ?? 0.0;
    final diff = proj > 0 ? (((act - proj) / proj) * 100) : 0.0;
    final isFavorable = info.isLowerBetter ? diff <= 0 : diff >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.paper : AppTheme.leaf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppTheme.forge : AppTheme.borderSage,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              _selectedMetric = metricKey;
              _hoveredIndex = null;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Metric Name & Actual Value
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              info.title,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? AppTheme.forge : AppTheme.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.forge,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('ACTIVE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.verdictLime)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            info.formatValue(act),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppTheme.forge : AppTheme.textPrimary,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isFavorable ? AppTheme.verdictLime : AppTheme.statusRejected.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isFavorable ? AppTheme.forge : AppTheme.statusRejected,
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isFavorable ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                  size: 10,
                                  color: isFavorable ? AppTheme.forge : AppTheme.statusRejected,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isFavorable ? AppTheme.forge : AppTheme.statusRejected,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Target Projected Value Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'TARGET PROJECTED',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      info.formatValue(proj),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CHANNEL ECONOMICS & ALLOCATION
  // ---------------------------------------------------------------------------
  Widget _buildChannelEconomicsCard(List<dynamic> breakdown, double totalBudget, int totalCampaigns) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSage),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Channel Economics & Yield',
                style: AppTheme.serifHeadline(fontSize: 15),
              ),
              Text(
                'Total: \$${NumberFormat('#,###').format(totalBudget)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.forge,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Aggregated spend across $totalCampaigns active campaign flight(s)',
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),

          if (breakdown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No active channel campaigns match current filter.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            )
          else
            ...breakdown.map((ch) {
              final name = ch['channel'] ?? 'Unknown';
              final count = ch['campaigns'] ?? ch['count'] ?? 0;
              final budget = (ch['budget'] as num?)?.toDouble() ?? 0.0;
              final percent = totalBudget > 0 ? (budget / totalBudget) : 0.0;
              final color = AppTheme.getChannelColor(name);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('($count)', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '\$${NumberFormat('#,###').format(budget)} (${(percent * 100).toStringAsFixed(0)}%)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: AppTheme.paper,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CUSTOM PAINTER FOR HISTORICAL PERFORMANCE CURVES
// ---------------------------------------------------------------------------
class _HistoricalTrendPainter extends CustomPainter {
  final List<Map<String, dynamic>> trends;
  final String metricKey;
  final Color accentColor;
  final int? hoveredIndex;

  _HistoricalTrendPainter({
    required this.trends,
    required this.metricKey,
    required this.accentColor,
    this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (trends.isEmpty) return;

    const leftPadding = 34.0;
    const bottomPadding = 22.0;
    const topPadding = 12.0;
    const rightPadding = 10.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - bottomPadding - topPadding;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    // 1. Calculate Min and Max across both Projected and Actual
    double minVal = double.infinity;
    double maxVal = -double.infinity;

    for (final t in trends) {
      final act = (t['actual']?[metricKey] as num?)?.toDouble() ?? 0.0;
      final proj = (t['projected']?[metricKey] as num?)?.toDouble() ?? 0.0;
      minVal = math.min(minVal, math.min(act, proj));
      maxVal = math.max(maxVal, math.max(act, proj));
    }

    if (minVal == double.infinity) minVal = 0.0;
    if (maxVal == -double.infinity) maxVal = 10.0;
    if (minVal == maxVal) {
      minVal -= 1.0;
      maxVal += 1.0;
    }

    // Add padding to y bounds
    final yRange = maxVal - minVal;
    final boundedMin = math.max(0.0, minVal - (yRange * 0.1));
    final boundedMax = maxVal + (yRange * 0.1);
    final effectiveRange = (boundedMax - boundedMin) == 0 ? 1.0 : (boundedMax - boundedMin);

    // 2. Draw Horizontal Grid Lines & Y-Axis Labels
    final gridPaint = Paint()
      ..color = AppTheme.borderSage.withOpacity(0.55)
      ..strokeWidth = 1.0;

    const yTicks = 4;
    for (int i = 0; i <= yTicks; i++) {
      final normY = i / yTicks;
      final y = topPadding + chartHeight - (normY * chartHeight);
      final value = boundedMin + (normY * effectiveRange);

      // Horizontal dashed line
      _drawDashedHorizontal(canvas, leftPadding, y, size.width - rightPadding, gridPaint);

      // Label
      final labelSpan = TextSpan(
        text: value >= 100 ? value.round().toString() : value.toStringAsFixed(1),
        style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary, fontFamily: 'monospace'),
      );
      final tp = TextPainter(text: labelSpan, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(leftPadding - tp.width - 6, y - (tp.height / 2)));
    }

    // 3. Compute Coordinates for Projected & Actual
    final n = trends.length;
    final projPoints = <Offset>[];
    final actualPoints = <Offset>[];

    for (int i = 0; i < n; i++) {
      final x = leftPadding + (n == 1 ? chartWidth / 2 : (i / (n - 1)) * chartWidth);

      final proj = (trends[i]['projected']?[metricKey] as num?)?.toDouble() ?? 0.0;
      final act = (trends[i]['actual']?[metricKey] as num?)?.toDouble() ?? 0.0;

      final normProjY = ((proj - boundedMin) / effectiveRange).clamp(0.0, 1.0);
      final normActY = ((act - boundedMin) / effectiveRange).clamp(0.0, 1.0);

      projPoints.add(Offset(x, topPadding + chartHeight - (normProjY * chartHeight)));
      actualPoints.add(Offset(x, topPadding + chartHeight - (normActY * chartHeight)));
    }

    // 4. Draw Projected Line (Muted Dashed Slate)
    final projPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    _drawDashedPolyline(canvas, projPoints, projPaint);

    // 5. Draw Actual Telemetry Gradient Area & Solid Curve
    if (actualPoints.isNotEmpty) {
      final areaPath = Path()..moveTo(actualPoints.first.dx, topPadding + chartHeight);
      for (final pt in actualPoints) {
        areaPath.lineTo(pt.dx, pt.dy);
      }
      areaPath.lineTo(actualPoints.last.dx, topPadding + chartHeight);
      areaPath.close();

      final gradientPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accentColor.withOpacity(0.22),
            accentColor.withOpacity(0.01),
          ],
        ).createShader(Rect.fromLTWH(leftPadding, topPadding, chartWidth, chartHeight))
        ..style = PaintingStyle.fill;
      canvas.drawPath(areaPath, gradientPaint);

      // Solid Stroke Curve
      final strokePaint = Paint()
        ..color = accentColor
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final strokePath = Path()..moveTo(actualPoints.first.dx, actualPoints.first.dy);
      for (int i = 1; i < actualPoints.length; i++) {
        strokePath.lineTo(actualPoints[i].dx, actualPoints[i].dy);
      }
      canvas.drawPath(strokePath, strokePaint);
    }

    // 6. Draw X-Axis Date Labels (First, Middle, Last)
    if (n > 0) {
      _drawXAxisLabel(canvas, trends.first['date'] ?? '', leftPadding, size.height - 10, Alignment.centerLeft);
      if (n > 2) {
        final midIdx = n ~/ 2;
        _drawXAxisLabel(canvas, trends[midIdx]['date'] ?? '', leftPadding + (chartWidth / 2), size.height - 10, Alignment.center);
      }
      _drawXAxisLabel(canvas, trends.last['date'] ?? '', size.width - rightPadding, size.height - 10, Alignment.centerRight);
    }

    // 7. Interactive Scrubber Crosshair & Telemetry Dots
    if (hoveredIndex != null && hoveredIndex! >= 0 && hoveredIndex! < n) {
      final pX = actualPoints[hoveredIndex!].dx;

      // Vertical crosshair
      final crosshairPaint = Paint()
        ..color = AppTheme.forge.withOpacity(0.6)
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(pX, topPadding), Offset(pX, topPadding + chartHeight), crosshairPaint);

      // Projected Dot
      final projDot = projPoints[hoveredIndex!];
      canvas.drawCircle(projDot, 4.0, Paint()..color = const Color(0xFF94A3B8));
      canvas.drawCircle(projDot, 2.0, Paint()..color = AppTheme.leaf);

      // Actual Dot
      final actDot = actualPoints[hoveredIndex!];
      canvas.drawCircle(actDot, 5.5, Paint()..color = AppTheme.forge);
      canvas.drawCircle(actDot, 3.0, Paint()..color = AppTheme.verdictLime);
    }
  }

  void _drawXAxisLabel(Canvas canvas, String dateStr, double x, double y, Alignment align) {
    if (dateStr.length > 5) {
      dateStr = dateStr.substring(5); // Show MM-DD for neat brevity
    }
    final span = TextSpan(
      text: dateStr,
      style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary, fontFamily: 'monospace'),
    );
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    double offsetX = x;
    if (align == Alignment.center) {
      offsetX -= tp.width / 2;
    } else if (align == Alignment.centerRight) {
      offsetX -= tp.width;
    }
    tp.paint(canvas, Offset(offsetX, y - tp.height));
  }

  void _drawDashedHorizontal(Canvas canvas, double x1, double y, double x2, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double currentX = x1;
    while (currentX < x2) {
      canvas.drawLine(Offset(currentX, y), Offset(math.min(currentX + dashWidth, x2), y), paint);
      currentX += dashWidth + dashSpace;
    }
  }

  void _drawDashedPolyline(Canvas canvas, List<Offset> points, Paint paint) {
    const dashLength = 4.0;
    const gapLength = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final dx = p2.dx - p1.dx;
      final dy = p2.dy - p1.dy;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance == 0) continue;

      final unitX = dx / distance;
      final unitY = dy / distance;

      double traveled = 0;
      bool draw = true;
      while (traveled < distance) {
        final length = draw ? dashLength : gapLength;
        final nextTraveled = math.min(traveled + length, distance);
        if (draw) {
          canvas.drawLine(
            Offset(p1.dx + unitX * traveled, p1.dy + unitY * traveled),
            Offset(p1.dx + unitX * nextTraveled, p1.dy + unitY * nextTraveled),
            paint,
          );
        }
        traveled = nextTraveled;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HistoricalTrendPainter oldDelegate) {
    return oldDelegate.trends != trends ||
        oldDelegate.metricKey != metricKey ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.accentColor != accentColor;
  }
}
