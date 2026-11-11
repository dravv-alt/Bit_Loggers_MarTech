import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'v3_components.dart';
import 'v3_tokens.dart';

class V3ChartPoint {
  final String label;
  final double current;
  final double previous;

  const V3ChartPoint({
    required this.label,
    required this.current,
    required this.previous,
  });
}

({String label, String tone}) _describeDelta(double current, double previous) {
  if (previous <= 0) return (label: 'New', tone: 'neutral');
  final change = ((current - previous) / previous) * 100.0;
  final rounded = (change * 10).round() / 10.0;
  if (rounded == 0) return (label: '0%', tone: 'neutral');
  return (
    label: '${rounded > 0 ? '+' : ''}$rounded%',
    tone: rounded > 0 ? 'lime' : 'rose',
  );
}

/// Interactive BoardUI Area + Dashed Comparison Chart matching Recharts RevenueChartCard.
class V3RevenueAreaChartCard extends StatefulWidget {
  final String title;
  final List<V3ChartPoint> data;
  final V3Palette palette;

  const V3RevenueAreaChartCard({
    super.key,
    required this.title,
    required this.data,
    required this.palette,
  });

  @override
  State<V3RevenueAreaChartCard> createState() => _V3RevenueAreaChartCardState();
}

class _V3RevenueAreaChartCardState extends State<V3RevenueAreaChartCard> {
  int? _activeIdx;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final pts = widget.data;
    final totalCurrent = pts.fold<double>(0.0, (s, e) => s + e.current);
    final totalPrev = pts.fold<double>(0.0, (s, e) => s + e.previous);

    final pt = (_activeIdx != null && _activeIdx! >= 0 && _activeIdx! < pts.length)
        ? pts[_activeIdx!]
        : null;
    final headline = pt?.current ?? totalCurrent;
    final prev = pt?.previous ?? totalPrev;
    final delta = _describeDelta(headline, prev);
    final labelText = pt != null ? pt.label : widget.title;

    return Container(
      height: 320,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: p.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.borderDefault, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(labelText, style: V3Tokens.bodyMedium(p, color: p.textSecondary)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          V3Tokens.formatMoney(headline),
                          style: V3Tokens.title1(p, semiBold: false),
                        ),
                        const SizedBox(width: 8),
                        V3Chip(label: delta.label, tone: delta.tone, palette: p),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${V3Tokens.formatMoney(prev)} ${pt != null ? 'a year earlier' : 'last year'}',
                      style: V3Tokens.caption(p, color: p.textTertiary),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _legendItem(p, p.chartLimeActive, 'This year'),
                  const SizedBox(width: 12),
                  _legendItem(p, p.chartNeutral, 'Last year'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return MouseRegion(
                  onExit: (_) => setState(() => _activeIdx = null),
                  onHover: (evt) => _selectAtX(evt.localPosition.dx, constraints.maxWidth),
                  child: GestureDetector(
                    onHorizontalDragUpdate: (d) =>
                        _selectAtX(d.localPosition.dx, constraints.maxWidth),
                    onHorizontalDragEnd: (_) => setState(() => _activeIdx = null),
                    onTapDown: (d) => _selectAtX(d.localPosition.dx, constraints.maxWidth),
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: _RevenueAreaPainter(
                        points: pts,
                        activeIndex: _activeIdx,
                        palette: p,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _selectAtX(double x, double width) {
    if (widget.data.length < 2) return;
    const leftPad = 42.0;
    const rightPad = 8.0;
    final plotW = math.max(1.0, width - leftPad - rightPad);
    final t = ((x - leftPad) / plotW).clamp(0.0, 1.0);
    final idx = (t * (widget.data.length - 1)).round().clamp(0, widget.data.length - 1);
    if (_activeIdx != idx) {
      setState(() => _activeIdx = idx);
    }
  }
}

/// Interactive BoardUI Dual Bar Chart matching Recharts OrdersChartCard.
class V3ConversionsBarChartCard extends StatefulWidget {
  final String title;
  final List<V3ChartPoint> data;
  final V3Palette palette;

  const V3ConversionsBarChartCard({
    super.key,
    required this.title,
    required this.data,
    required this.palette,
  });

  @override
  State<V3ConversionsBarChartCard> createState() => _V3ConversionsBarChartCardState();
}

class _V3ConversionsBarChartCardState extends State<V3ConversionsBarChartCard> {
  int? _activeIdx;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final pts = widget.data;
    final totalCurrent = pts.fold<double>(0.0, (s, e) => s + e.current);
    final totalPrev = pts.fold<double>(0.0, (s, e) => s + e.previous);

    final pt = (_activeIdx != null && _activeIdx! >= 0 && _activeIdx! < pts.length)
        ? pts[_activeIdx!]
        : null;
    final headline = pt?.current ?? totalCurrent;
    final prev = pt?.previous ?? totalPrev;
    final delta = _describeDelta(headline, prev);
    final labelText = pt != null ? pt.label : widget.title;

    return Container(
      height: 320,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: p.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.borderDefault, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(labelText, style: V3Tokens.bodyMedium(p, color: p.textSecondary)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          _formatInt(headline.round()),
                          style: V3Tokens.title1(p, semiBold: false),
                        ),
                        const SizedBox(width: 8),
                        V3Chip(label: delta.label, tone: delta.tone, palette: p),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatInt(prev.round())} ${pt != null ? 'a year earlier' : 'last year'}',
                      style: V3Tokens.caption(p, color: p.textTertiary),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _legendItem(p, p.chartIndigoActive, 'This year'),
                  const SizedBox(width: 12),
                  _legendItem(p, p.chartNeutral, 'Last year'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return MouseRegion(
                  onExit: (_) => setState(() => _activeIdx = null),
                  onHover: (evt) => _selectAtX(evt.localPosition.dx, constraints.maxWidth),
                  child: GestureDetector(
                    onHorizontalDragUpdate: (d) =>
                        _selectAtX(d.localPosition.dx, constraints.maxWidth),
                    onHorizontalDragEnd: (_) => setState(() => _activeIdx = null),
                    onTapDown: (d) => _selectAtX(d.localPosition.dx, constraints.maxWidth),
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: _ConversionsBarPainter(
                        points: pts,
                        activeIndex: _activeIdx,
                        palette: p,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _selectAtX(double x, double width) {
    if (widget.data.isEmpty) return;
    const leftPad = 42.0;
    const rightPad = 8.0;
    final plotW = math.max(1.0, width - leftPad - rightPad);
    final idx = (((x - leftPad) / plotW) * widget.data.length)
        .floor()
        .clamp(0, widget.data.length - 1);
    if (_activeIdx != idx) {
      setState(() => _activeIdx = idx);
    }
  }

  String _formatInt(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final rem = s.length - i;
      if (i > 0 && rem % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

Widget _legendItem(V3Palette p, Color dotColor, String label) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: V3Tokens.caption(p)),
    ],
  );
}

class _RevenueAreaPainter extends CustomPainter {
  final List<V3ChartPoint> points;
  final int? activeIndex;
  final V3Palette palette;

  const _RevenueAreaPainter({
    required this.points,
    required this.activeIndex,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    const leftPad = 42.0;
    const rightPad = 10.0;
    const topPad = 8.0;
    const bottomPad = 24.0;

    final plotW = size.width - leftPad - rightPad;
    final plotH = size.height - topPad - bottomPad;
    if (plotW <= 10 || plotH <= 10) return;

    double maxY = 1000.0;
    for (final pt in points) {
      maxY = math.max(maxY, math.max(pt.current, pt.previous));
    }
    maxY *= 1.12;

    // Y axis labels (4 ticks)
    for (int tIdx = 0; tIdx <= 3; tIdx++) {
      final frac = tIdx / 3.0;
      final val = maxY * (1.0 - frac);
      final y = topPad + plotH * frac;
      final label = val >= 1000 ? '\$${(val / 1000).round()}k' : '\$${val.round()}';
      final tp = TextPainter(
        text: TextSpan(text: label, style: V3Tokens.caption(palette, color: palette.textTertiary)),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 8, y - tp.height / 2));
    }

    Offset pointAt(int idx, double value) {
      final x = leftPad + (idx / (points.length - 1)) * plotW;
      final y = topPad + plotH - (value / maxY) * plotH;
      return Offset(x, y);
    }

    Path smoothPath(List<Offset> offsets) {
      final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (int i = 0; i < offsets.length - 1; i++) {
        final p0 = offsets[i];
        final p1 = offsets[i + 1];
        final cx = (p0.dx + p1.dx) / 2.0;
        path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
      }
      return path;
    }

    final prevOffsets = [
      for (int i = 0; i < points.length; i++) pointAt(i, points[i].previous),
    ];
    final curOffsets = [
      for (int i = 0; i < points.length; i++) pointAt(i, points[i].current),
    ];

    // Previous dashed line
    final prevPath = smoothPath(prevOffsets);
    final prevPaint = Paint()
      ..color = palette.chartNeutral
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    for (final metric in prevPath.computeMetrics()) {
      double dist = 0.0;
      while (dist < metric.length) {
        final next = math.min(dist + 5.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), prevPaint);
        dist += 9.5;
      }
    }

    // Current gradient fill
    final areaPath = smoothPath(curOffsets)
      ..lineTo(curOffsets.last.dx, topPad + plotH)
      ..lineTo(curOffsets.first.dx, topPad + plotH)
      ..close();
    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, topPad),
        Offset(0, topPad + plotH),
        [palette.chartLime.withOpacity(0.32), palette.chartLime.withOpacity(0.0)],
      );
    canvas.drawPath(areaPath, fillPaint);

    // Current spline
    canvas.drawPath(
      smoothPath(curOffsets),
      Paint()
        ..color = palette.chartLimeActive
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // X axis labels
    final step = points.length > 8 ? 1 : 1;
    for (int i = 0; i < points.length; i += step) {
      if (points.length > 8 && i % 2 == 1 && i != points.length - 1) continue;
      final x = leftPad + (i / (points.length - 1)) * plotW;
      final tp = TextPainter(
        text: TextSpan(
          text: points[i].label,
          style: V3Tokens.caption(palette, color: palette.textTertiary),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, topPad + plotH + 7));
    }

    // Active hover dot
    if (activeIndex != null && activeIndex! >= 0 && activeIndex! < curOffsets.length) {
      final act = curOffsets[activeIndex!];
      canvas.drawLine(
        Offset(act.dx, topPad),
        Offset(act.dx, topPad + plotH),
        Paint()
          ..color = palette.chartCursor
          ..strokeWidth = 1.0,
      );
      canvas.drawCircle(
        act,
        7,
        Paint()..color = palette.chartLimeActive.withOpacity(0.25),
      );
      canvas.drawCircle(act, 4.5, Paint()..color = palette.chartLimeActive);
      canvas.drawCircle(
        act,
        4.5,
        Paint()
          ..color = palette.bgSecondary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RevenueAreaPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.activeIndex != activeIndex ||
      oldDelegate.palette != palette;
}

class _ConversionsBarPainter extends CustomPainter {
  final List<V3ChartPoint> points;
  final int? activeIndex;
  final V3Palette palette;

  const _ConversionsBarPainter({
    required this.points,
    required this.activeIndex,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const leftPad = 42.0;
    const rightPad = 8.0;
    const topPad = 8.0;
    const bottomPad = 24.0;

    final plotW = size.width - leftPad - rightPad;
    final plotH = size.height - topPad - bottomPad;
    if (plotW <= 10 || plotH <= 10) return;

    double maxY = 100.0;
    for (final pt in points) {
      maxY = math.max(maxY, math.max(pt.current, pt.previous));
    }
    maxY *= 1.12;

    for (int tIdx = 0; tIdx <= 3; tIdx++) {
      final frac = tIdx / 3.0;
      final val = maxY * (1.0 - frac);
      final y = topPad + plotH * frac;
      final label = val >= 1000 ? '${(val / 1000).toStringAsFixed(1)}k' : '${val.round()}';
      final tp = TextPainter(
        text: TextSpan(text: label, style: V3Tokens.caption(palette, color: palette.textTertiary)),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 8, y - tp.height / 2));
    }

    final slotW = plotW / points.length;
    final barW = math.min(9.0, math.max(4.0, slotW * 0.28));
    const pairGap = 3.0;

    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final slotCenterX = leftPad + slotW * (i + 0.5);
      final prevH = (pt.previous / maxY) * plotH;
      final curH = (pt.current / maxY) * plotH;

      final isActive = activeIndex == i;
      if (isActive) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(slotCenterX - slotW * 0.42, topPad, slotW * 0.84, plotH),
            const Radius.circular(6),
          ),
          Paint()..color = palette.chartTrack.withOpacity(0.55),
        );
      }

      // Previous bar
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(
            slotCenterX - barW - pairGap / 2,
            topPad + plotH - prevH,
            barW,
            prevH,
          ),
          topLeft: const Radius.circular(3.5),
          topRight: const Radius.circular(3.5),
        ),
        Paint()..color = palette.chartNeutral,
      );

      // Current bar
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(
            slotCenterX + pairGap / 2,
            topPad + plotH - curH,
            barW,
            curH,
          ),
          topLeft: const Radius.circular(3.5),
          topRight: const Radius.circular(3.5),
        ),
        Paint()..color = isActive ? palette.chartIndigo : palette.chartIndigoActive,
      );

      if (points.length <= 8 || i % 2 == 0 || i == points.length - 1) {
        final tp = TextPainter(
          text: TextSpan(
            text: pt.label,
            style: V3Tokens.caption(palette, color: palette.textTertiary),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(slotCenterX - tp.width / 2, topPad + plotH + 7));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConversionsBarPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.activeIndex != activeIndex ||
      oldDelegate.palette != palette;
}
