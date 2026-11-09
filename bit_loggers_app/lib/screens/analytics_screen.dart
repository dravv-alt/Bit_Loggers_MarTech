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

  static Map<String, _MetricInfo> _metrics = {
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
            colorScheme: ColorScheme.light(
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
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.label,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              'Live performance telemetry',
              style: TextStyle(fontSize: 11, color: AppTheme.secondaryLabel, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppTheme.textPrimary),
            tooltip: 'Refresh Telemetry',
            onPressed: _fetch,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppTheme.forge))
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
            Icon(Icons.warning_amber_rounded, size: 48, color: AppTheme.statusRejected),
            const SizedBox(height: 12),
            Text(
              'Telemetry Feed Error',
              style: AppTheme.serifHeadline(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Failed to load telemetry snapshots.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.secondarySystemBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.appleCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Date Range Presets & Custom Picker Trigger
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  dateRangeStr,
                  style: TextStyle(
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
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _datePreset == 'Custom' ? AppTheme.label : AppTheme.tertiarySystemBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Custom',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _datePreset == 'Custom' ? Colors.white : AppTheme.label,
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
          Divider(height: 16, color: AppTheme.separator),

          // Row 2: Channel filter pills
          Row(
            children: [
              Text(
                'CHANNEL:',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.secondaryLabel, letterSpacing: 0.5),
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
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? Colors.white : AppTheme.label,
                          ),
                          selectedColor: AppTheme.label,
                          backgroundColor: AppTheme.tertiarySystemBackground,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide.none,
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
            color: isSelected ? AppTheme.label : AppTheme.tertiarySystemBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? Colors.white : AppTheme.label,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.secondarySystemBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.appleCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title + Telemetry Badge
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                'Historical performance flights',
                style: AppTheme.headline,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4EA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF137333), shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    const Text(
                      'Live telemetry',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF137333)),
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
                        color: isSelected ? AppTheme.label : AppTheme.tertiarySystemBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        metric.shortTitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? Colors.white : AppTheme.label,
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
                  child: Text('No time-series snapshots recorded for this range.', style: TextStyle(color: AppTheme.textSecondary)),
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
          Divider(height: 0.5, color: AppTheme.separator),
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
          color: AppTheme.tertiarySystemBackground,
          borderRadius: BorderRadius.circular(10),
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
                Icon(Icons.touch_app, size: 14, color: AppTheme.forge),
                const SizedBox(width: 4),
                Text(
                  date,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
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
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.forge),
                ),
                Text(
                  'Target: ${activeMetric.formatValue(projVal)}',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
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
                Container(width: 14, height: 3, decoration: BoxDecoration(color: AppTheme.forge, borderRadius: BorderRadius.all(Radius.circular(2)))),
                const SizedBox(width: 5),
                Text('Actual Telemetry', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
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
                Text('Projected Baseline', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
        Text(
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
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
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
  // PERFORMANCE BENCHMARKS — METRIC TILES
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
            Text(
              'Performance benchmarks (projected vs actual)',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.secondaryLabel),
            ),
            Text(
              'Tap card to inspect telemetry',
              style: TextStyle(fontSize: 10, color: AppTheme.forge.withOpacity(0.8), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Hero Tile for Cost Per Acquisition (with spend wave burn bar and 75% red needle)
        _buildBentoHeroTile(kpis['cpa']),
        const SizedBox(height: 10),

        // 2x2 Bento Matrix for the other 4 metrics (ROI, Conv Rate, CTR, AOV)
        _buildBentoKpiGrid(kpis),
        const SizedBox(height: 14),

        // Conversion Funnel Bento Card (4.9M Volume Rollup)
        _buildConversionFunnelCard(),
      ],
    );
  }

  Widget _buildBentoHeroTile(Map<String, dynamic>? cpaData) {
    final info = _metrics['cpa']!;
    final proj = (cpaData?['projected'] as num?)?.toDouble() ?? 24.5;
    final act = (cpaData?['actual'] as num?)?.toDouble() ?? 21.0;
    final diff = proj > 0 ? (((act - proj) / proj) * 100) : 0.0;
    final isSelected = _selectedMetric == 'cpa';

    return InkWell(
      onTap: () => setState(() => _selectedMetric = 'cpa'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.secondarySystemBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? AppTheme.appleFloatingShadow
              : AppTheme.appleCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          info.title, // 'Cost Per Acquisition'
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
                          child: Text('ACTIVE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.verdictLime)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4EA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}% vs target',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF137333),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  info.formatValue(act),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Target: ${info.formatValue(proj)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Spend wave burn bar with red needle at 75% ceiling
            Text(
              'Spend wave pacing · 75% budget ceiling',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.secondaryLabel,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 18,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Track background
                  Container(
                    height: 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.tertiarySystemBackground,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  // Filled progress (62% burn)
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
                  // Red needle at 75% ceiling
                  Align(
                    alignment: const Alignment(-0.5 + (0.75 * 2) - 1.0, 0),
                    child: Container(
                      width: 2,
                      height: 18,
                      color: const Color(0xFFB9301D),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Current flight: 62% burned',
                    style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Ceiling: 75%',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB9301D)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBentoKpiGrid(Map<String, dynamic> kpis) {
    final keys = ['roi', 'conversionRate', 'ctr', 'aov'];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildBentoMetricCell(keys[0], kpis[keys[0]])),
            const SizedBox(width: 8),
            Expanded(child: _buildBentoMetricCell(keys[1], kpis[keys[1]])),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildBentoMetricCell(keys[2], kpis[keys[2]])),
            const SizedBox(width: 8),
            Expanded(child: _buildBentoMetricCell(keys[3], kpis[keys[3]])),
          ],
        ),
      ],
    );
  }

  Widget _buildBentoMetricCell(String metricKey, Map<String, dynamic>? data) {
    final info = _metrics[metricKey]!;
    final isSelected = _selectedMetric == metricKey;
    final proj = (data?['projected'] as num?)?.toDouble() ?? 0.0;
    final act = (data?['actual'] as num?)?.toDouble() ?? 0.0;
    final diff = proj > 0 ? (((act - proj) / proj) * 100) : 0.0;
    final isFavorable = info.isLowerBetter ? diff <= 0 : diff >= 0;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedMetric = metricKey;
          _hoveredIndex = null;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.paper : AppTheme.secondarySystemBackground,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected ? AppTheme.appleFloatingShadow : AppTheme.appleCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    info.title, // 'Return on Investment', 'Conversion Rate', etc.
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppTheme.forge : AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.forge,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('ACTIVE', style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: AppTheme.verdictLime)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              info.formatValue(act),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: isSelected ? AppTheme.forge : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tgt: ${info.formatValue(proj)}',
                  style: TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: isFavorable ? const Color(0xFFE6F4EA) : const Color(0xFFFDE8E4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: isFavorable ? const Color(0xFF137333) : const Color(0xFF9C3A27),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversionFunnelCard() {
    final aggregates = _data?['aggregates'] as Map<String, dynamic>?;

    final double impressions = (aggregates?['impressions'] as num?)?.toDouble() ?? 5996319.0;
    final double clicks = (aggregates?['clicks'] as num?)?.toDouble() ?? 261835.0;
    final double conversions = (aggregates?['conversions'] as num?)?.toDouble() ?? 12066.0;
    final double revenue = (aggregates?['revenue'] as num?)?.toDouble() ?? 2251971.0;

    final double ctr = impressions > 0 ? (clicks / impressions * 100) : 4.4;
    final double convRate = clicks > 0 ? (conversions / clicks * 100) : 4.6;
    final double aov = conversions > 0 ? (revenue / conversions) : 186.0;

    String formatVolume(double val, {bool isCurrency = false}) {
      if (val >= 1000000) {
        return (isCurrency ? '\$' : '') + (val / 1000000).toStringAsFixed(2) + 'M';
      } else if (val >= 1000) {
        return (isCurrency ? '\$' : '') + (val / 1000).toStringAsFixed(1) + 'K';
      }
      return (isCurrency ? '\$' : '') + val.toStringAsFixed(0);
    }

    final stages = [
      {
        'name': 'Impressions',
        'volume': formatVolume(impressions),
        'pct': '100%',
        'bar': 1.0,
      },
      {
        'name': 'Clicks (Traffic)',
        'volume': formatVolume(clicks),
        'pct': '${ctr.toStringAsFixed(1)}% CTR',
        'bar': 0.72,
      },
      {
        'name': 'Conversions (Leads)',
        'volume': formatVolume(conversions),
        'pct': '${convRate.toStringAsFixed(1)}% CVR',
        'bar': 0.45,
      },
      {
        'name': 'Attributed Revenue',
        'volume': formatVolume(revenue, isCurrency: true),
        'pct': '\$${aov.toStringAsFixed(0)} AOV',
        'bar': 0.30,
      },
    ];

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
              Expanded(
                child: Text(
                  'CONVERSION FUNNEL (${formatVolume(impressions)} VOLUME)',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.12,
                    color: AppTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'TimescaleDB rollup',
                style: TextStyle(fontSize: 9, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...stages.map((st) {
            final barVal = st['bar'] as double;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          st['name'] as String,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            st['volume'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${st['pct']})',
                            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: barVal,
                      minHeight: 4,
                      backgroundColor: AppTheme.paper,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.forge),
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

  // ---------------------------------------------------------------------------
  // CHANNEL ECONOMICS & ALLOCATION
  // ---------------------------------------------------------------------------
  Widget _buildChannelEconomicsCard(List<dynamic> breakdown, double totalBudget, int totalCampaigns) {
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
                style: TextStyle(
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
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),

          if (breakdown.isEmpty)
            Padding(
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
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('($count)', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "\$${NumberFormat('#,###').format(budget)} (${(percent * 100).toStringAsFixed(0)}%)",
                          style: TextStyle(
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
      ..color = AppTheme.separator
      ..strokeWidth = 0.5;

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
        style: TextStyle(fontSize: 9, color: AppTheme.textSecondary, fontFamily: 'monospace'),
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
      style: TextStyle(fontSize: 9, color: AppTheme.textSecondary, fontFamily: 'monospace'),
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
