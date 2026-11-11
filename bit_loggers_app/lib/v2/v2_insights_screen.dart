import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'v2_tokens.dart';

/// Screen 14: Insights & Attributed Performance Trends with CPA Dark Anchor.
class V2InsightsScreen extends StatefulWidget {
  final ApiService api;
  final VoidCallback onOpenSpendMeter;

  const V2InsightsScreen({
    super.key,
    required this.api,
    required this.onOpenSpendMeter,
  });

  @override
  State<V2InsightsScreen> createState() => _V2InsightsScreenState();
}

class _V2InsightsScreenState extends State<V2InsightsScreen> {
  String _range = '30 days';
  int _scrubIndex = 4;
  Map<String, dynamic>? _analytics;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final interval = _range == '7 days'
        ? '7d'
        : _range == 'Quarter'
            ? '90d'
            : '30d';
    try {
      final data = await widget.api.getAnalytics(interval: interval);
      if (mounted) {
        setState(() {
          _analytics = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = (_analytics?['summary'] as Map<String, dynamic>?) ?? {};
    final kpisMap = (summary['kpis'] as Map<String, dynamic>?) ?? {};
    final trendsRaw = (_analytics?['trends'] as List<dynamic>?) ?? [];

    final chartPts = <_ChartPoint>[];
    if (trendsRaw.isNotEmpty) {
      final slice = trendsRaw.length > 6 ? trendsRaw.sublist(trendsRaw.length - 6) : trendsRaw;
      for (int i = 0; i < slice.length; i++) {
        final item = slice[i] as Map<String, dynamic>;
        final proj = (item['projected']?['roi'] as num?)?.toDouble() ?? (3.8 + i * 0.12);
        final act = (item['actual']?['roi'] as num?)?.toDouble() ?? (4.0 + i * 0.16);
        final conv = (item['actual']?['conversionRate'] as num?)?.toDouble() ?? (2.8 + i * 0.12);
        final dStr = item['date']?.toString() ?? '';
        final shortDate = dStr.length >= 10 ? dStr.substring(5) : 'Day ${i + 1}';
        final spend = (6200 + i * 3800);
        chartPts.add(
          _ChartPoint(
            label: shortDate,
            spendText: V2Tokens.formatCurrency(spend),
            convText: '${conv.toStringAsFixed(1)}%',
            projectedVal: proj,
            actualVal: act,
          ),
        );
      }
    } else {
      chartPts.addAll([
        const _ChartPoint(label: 'Day 1', spendText: '\$6,200', convText: '2.6%', projectedVal: 3.4, actualVal: 3.6),
        const _ChartPoint(label: 'Day 2', spendText: '\$10,400', convText: '2.8%', projectedVal: 3.7, actualVal: 4.0),
        const _ChartPoint(label: 'Day 3', spendText: '\$14,800', convText: '2.9%', projectedVal: 3.9, actualVal: 4.3),
        const _ChartPoint(label: 'Day 4', spendText: '\$18,100', convText: '3.0%', projectedVal: 4.1, actualVal: 4.5),
        const _ChartPoint(label: 'Day 5', spendText: '\$21,000', convText: '3.1%', projectedVal: 4.3, actualVal: 4.8),
        const _ChartPoint(label: 'Day 6', spendText: '\$25,000', convText: '3.3%', projectedVal: 4.5, actualVal: 5.0),
      ]);
    }

    final safeIdx = _scrubIndex.clamp(0, chartPts.length - 1);
    final activePt = chartPts[safeIdx];

    String valFor(String key, String fallback, {bool prefixDollar = false, String suffix = ''}) {
      final raw = kpisMap[key]?['actual'];
      if (raw is num) {
        final formatted = key == 'cpa' || key == 'aov'
            ? raw.toStringAsFixed(2)
            : raw.toStringAsFixed(1);
        return prefixDollar ? '\$$formatted' : '$formatted$suffix';
      }
      return fallback;
    }

    final cpaText = valFor('cpa', '\$11.40', prefixDollar: true);
    final kpis = [
      (name: 'Conversion rate', val: valFor('conversionRate', '4.1%', suffix: '%'), delta: '+0.4%', darkAnchor: false),
      (name: 'CTR', val: valFor('ctr', '4.9%', suffix: '%'), delta: '+0.2%', darkAnchor: false),
      (name: 'ROI', val: valFor('roi', '4.4x', suffix: 'x'), delta: '+0.3x', darkAnchor: false),
      (name: 'CPA', val: cpaText, delta: 'Ceiling \$25.00 · Inspect meter →', darkAnchor: true),
      (name: 'AOV', val: valFor('aov', '\$118.00', prefixDollar: true), delta: '+\$4.10', darkAnchor: false),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      children: [
        Text('Insights', style: V2Tokens.t1()),
        const SizedBox(height: 12),

        // Date Range Segmented Bar
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: V2Tokens.surfaceRecessed,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: V2Tokens.hairline, width: 1),
          ),
          child: Row(
            children: ['7 days', '30 days', 'Quarter'].map((rng) {
              final selected = _range == rng;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _range = rng);
                    _load();
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 36),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? V2Tokens.surfaceCard : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: selected
                          ? Border.all(color: V2Tokens.inkPrussian, width: 1.5)
                          : null,
                    ),
                    child: Text(
                      rng,
                      style: V2Tokens.t4(
                        color: selected ? V2Tokens.textPrimary : V2Tokens.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Interactive Trend Curve Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: V2Tokens.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: V2Tokens.hairline, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '${activePt.label} · Spend ${activePt.spendText} · Conv ${activePt.convText}',
                      overflow: TextOverflow.ellipsis,
                      style: V2Tokens.t4(color: V2Tokens.inkPrussian),
                    ),
                  ),
                  Text(
                    _loading ? 'Loading…' : 'Tap points',
                    style: V2Tokens.t4(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 112,
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onTapDown: (details) {
                        final relX = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                        final nearest = (relX * (chartPts.length - 1)).round();
                        setState(() => _scrubIndex = nearest);
                      },
                      onHorizontalDragUpdate: (details) {
                        final relX = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                        final nearest = (relX * (chartPts.length - 1)).round();
                        setState(() => _scrubIndex = nearest);
                      },
                      child: CustomPaint(
                        painter: _V2TrendPainter(
                          points: chartPts,
                          activeIdx: safeIdx,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 5 KPI Cards (CPA as Dark Anchor trigger to Spend Live)
        ...kpis.map((kpi) {
          if (kpi.darkAnchor) {
            return InkWell(
              onTap: widget.onOpenSpendMeter,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: V2Tokens.inkPrussian,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(kpi.name, style: V2Tokens.t3(color: V2Tokens.bgPlaster)),
                        const SizedBox(height: 2),
                        Text(kpi.delta, style: V2Tokens.t4(color: V2Tokens.cadmiumYellow)),
                      ],
                    ),
                    Text(kpi.val, style: V2Tokens.t1(mono: true, color: V2Tokens.labelOnInk)),
                  ],
                ),
              ),
            );
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: V2Tokens.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: V2Tokens.hairline, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(kpi.name, style: V2Tokens.t3(fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: V2Tokens.approvedChipBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(kpi.delta, style: V2Tokens.t4(color: V2Tokens.approvedSolid)),
                    ),
                    const SizedBox(width: 8),
                    Text(kpi.val, style: V2Tokens.t2(mono: true)),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _ChartPoint {
  final String label;
  final String spendText;
  final String convText;
  final double projectedVal;
  final double actualVal;

  const _ChartPoint({
    required this.label,
    required this.spendText,
    required this.convText,
    required this.projectedVal,
    required this.actualVal,
  });
}

class _V2TrendPainter extends CustomPainter {
  final List<_ChartPoint> points;
  final int activeIdx;

  const _V2TrendPainter({
    required this.points,
    required this.activeIdx,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    double minV = points.first.projectedVal;
    double maxV = points.first.actualVal;
    for (final p in points) {
      if (p.projectedVal < minV) minV = p.projectedVal;
      if (p.actualVal < minV) minV = p.actualVal;
      if (p.projectedVal > maxV) maxV = p.projectedVal;
      if (p.actualVal > maxV) maxV = p.actualVal;
    }
    final span = (maxV - minV) < 0.2 ? 1.0 : (maxV - minV);

    Offset pointAt(int i, double val) {
      const padX = 16.0;
      const padY = 14.0;
      final usableW = size.width - padX * 2;
      final usableH = size.height - padY * 2;
      final x = padX + (i / (points.length - 1)) * usableW;
      final norm = (val - minV) / span;
      final y = size.height - padY - norm * usableH;
      return Offset(x, y);
    }

    // Projected dashed line
    final projPaint = Paint()
      ..color = V2Tokens.textSecondary
      ..strokeWidth = 1.75
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      final a = pointAt(i, points[i].projectedVal);
      final b = pointAt(i + 1, points[i + 1].projectedVal);
      final dist = (b - a).distance;
      const step = 7.0;
      for (double d = 0; d < dist; d += step * 2) {
        final t1 = (d / dist).clamp(0.0, 1.0);
        final t2 = ((d + step) / dist).clamp(0.0, 1.0);
        canvas.drawLine(Offset.lerp(a, b, t1)!, Offset.lerp(a, b, t2)!, projPaint);
      }
    }

    // Vertical active scrubber hairline
    final activePt = pointAt(activeIdx, points[activeIdx].actualVal);
    canvas.drawLine(
      Offset(activePt.dx, 6),
      Offset(activePt.dx, size.height - 6),
      Paint()
        ..color = V2Tokens.inkPrussian
        ..strokeWidth = 1.25,
    );

    // Bold Cadmium Yellow Actual Curve
    final actPath = Path();
    for (int i = 0; i < points.length; i++) {
      final pt = pointAt(i, points[i].actualVal);
      if (i == 0) {
        actPath.moveTo(pt.dx, pt.dy);
      } else {
        actPath.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(
      actPath,
      Paint()
        ..color = V2Tokens.cadmiumYellow
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    // Data point nodes
    for (int i = 0; i < points.length; i++) {
      final pt = pointAt(i, points[i].actualVal);
      final selected = i == activeIdx;
      final r = selected ? 5.5 : 3.5;
      canvas.drawCircle(
        pt,
        r,
        Paint()..color = selected ? V2Tokens.cadmiumYellow : V2Tokens.inkPrussian,
      );
      canvas.drawCircle(
        pt,
        r,
        Paint()
          ..color = V2Tokens.inkPrussian
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _V2TrendPainter oldDelegate) =>
      oldDelegate.activeIdx != activeIdx || oldDelegate.points != points;
}

