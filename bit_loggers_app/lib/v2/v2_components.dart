import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'v2_tokens.dart';

/// Geometric split-diagonal facet emblem anchored across CampaignGrid v2.
class V2FacetCell extends StatelessWidget {
  final String status;
  final double size;
  final bool selected;

  const V2FacetCell({
    super.key,
    this.status = 'review',
    this.size = 13,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = V2Tokens.statusStyle(status);
    final upper = cfg.key == 'brand' ? V2Tokens.brandUpper : cfg.chipBg;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: EdgeInsets.all(selected ? 2 : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(selected ? 5 : 3),
            border: selected ? Border.all(color: V2Tokens.inkPrussian, width: 1.5) : null,
          ),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2.5),
              border: Border.all(color: cfg.solid, width: 0.6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: CustomPaint(
                painter: _FacetPainter(upper: upper, lower: cfg.solid),
              ),
            ),
          ),
        ),
        if (selected)
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: V2Tokens.cadmiumYellow,
                border: Border.all(color: V2Tokens.inkPrussian, width: 1),
              ),
            ),
          ),
      ],
    );
  }
}

class _FacetPainter extends CustomPainter {
  final Color upper;
  final Color lower;

  const _FacetPainter({required this.upper, required this.lower});

  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(0, size.height)
      ..close();
    final p2 = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(p1, Paint()..color = upper);
    canvas.drawPath(p2, Paint()..color = lower);
  }

  @override
  bool shouldRepaint(covariant _FacetPainter oldDelegate) =>
      oldDelegate.upper != upper || oldDelegate.lower != lower;
}

/// Tactile status pill pairing facet cell + crisp stroke icon + tabular label.
class V2StatusBadge extends StatelessWidget {
  final String status;
  final String? customLabel;

  const V2StatusBadge({
    super.key,
    required this.status,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = V2Tokens.statusStyle(status);
    final IconData icon;
    switch (cfg.key) {
      case 'approved':
      case 'scheduled':
        icon = Icons.check_rounded;
        break;
      case 'changes':
        icon = Icons.loop_rounded;
        break;
      case 'blocked':
        icon = Icons.error_outline_rounded;
        break;
      case 'brand':
        icon = Icons.edit_note_rounded;
        break;
      default:
        icon = Icons.schedule_rounded;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(5, 2, 7, 2),
      decoration: BoxDecoration(
        color: cfg.chipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: V2Tokens.hairline, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          V2FacetCell(status: cfg.key, size: 9),
          const SizedBox(width: 4),
          Icon(icon, size: 11, color: cfg.solid),
          const SizedBox(width: 4),
          Text(
            customLabel ?? cfg.label,
            style: V2Tokens.t4(color: cfg.solid),
          ),
        ],
      ),
    );
  }
}

/// Physical ticket perforation with semicircular notches and dashed hairline seam.
class V2TicketPerforation extends StatelessWidget {
  final Color notchBg;

  const V2TicketPerforation({super.key, this.notchBg = V2Tokens.bgPlaster});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      width: double.infinity,
      child: CustomPaint(
        painter: _PerforationPainter(notchBg: notchBg),
      ),
    );
  }
}

class _PerforationPainter extends CustomPainter {
  final Color notchBg;

  const _PerforationPainter({required this.notchBg});

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final dashPaint = Paint()
      ..color = V2Tokens.hairline
      ..strokeWidth = 1.0;

    // Dashed rule spanning between notches
    const dashW = 5.0;
    const gap = 4.0;
    double x = 12.0;
    while (x < size.width - 12.0) {
      final endX = math.min(x + dashW, size.width - 12.0);
      canvas.drawLine(Offset(x, midY), Offset(endX, midY), dashPaint);
      x += dashW + gap;
    }

    // Left and right semi-circle cutouts
    const r = 7.5;
    final fillPaint = Paint()..color = notchBg;
    final borderPaint = Paint()
      ..color = V2Tokens.hairline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final leftCenter = Offset(0, midY);
    canvas.drawCircle(leftCenter, r, fillPaint);
    canvas.drawArc(
      Rect.fromCircle(center: leftCenter, radius: r),
      -math.pi / 2,
      math.pi,
      false,
      borderPaint,
    );

    final rightCenter = Offset(size.width, midY);
    canvas.drawCircle(rightCenter, r, fillPaint);
    canvas.drawArc(
      Rect.fromCircle(center: rightCenter, radius: r),
      math.pi / 2,
      math.pi,
      false,
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PerforationPainter oldDelegate) =>
      oldDelegate.notchBg != notchBg;
}

/// Segmented cell gauge with optional delta highlight and ceiling tick.
class V2CellMeter extends StatelessWidget {
  final double amount;
  final double? prevAmount;
  final double maxAmount;
  final double ceilingRatio;
  final int totalCells;
  final double cellHeight;

  const V2CellMeter({
    super.key,
    required this.amount,
    this.prevAmount,
    this.maxAmount = 40000,
    this.ceilingRatio = 0.75,
    this.totalCells = 24,
    this.cellHeight = 10,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMax = math.max(maxAmount, amount * 1.15);
    final filledCount = ((amount / effectiveMax) * totalCells).round().clamp(1, totalCells);
    final prevFilledCount = prevAmount != null
        ? ((prevAmount! / effectiveMax) * totalCells).round().clamp(1, totalCells)
        : (filledCount - 3).clamp(0, totalCells);
    final ceilingIndex = (ceilingRatio * totalCells).round().clamp(1, totalCells - 1);

    final widgets = <Widget>[];
    for (int idx = 0; idx < totalCells; idx++) {
      final isFilled = idx < filledCount;
      final isAddedDelta = isFilled && idx >= math.max(0, prevFilledCount);
      final bg = !isFilled
          ? V2Tokens.surfaceRecessed
          : isAddedDelta
              ? V2Tokens.cadmiumYellow
              : V2Tokens.inkPrussian;

      if (idx == ceilingIndex) {
        widgets.add(
          Container(
            width: 2.5,
            height: cellHeight + 6,
            margin: const EdgeInsets.only(right: 2.5),
            decoration: BoxDecoration(
              color: V2Tokens.blockedSolid,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      }

      widgets.add(
        Expanded(
          child: Container(
            height: cellHeight,
            margin: EdgeInsets.only(right: idx == totalCells - 1 ? 0 : 2.5),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(2),
              border: isAddedDelta
                  ? Border.all(color: V2Tokens.inkPrussian, width: 0.5)
                  : null,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: widgets,
      ),
    );
  }
}

/// Interactive 12-cell Audience targeting distribution bar linking to Diff Inspector.
class V2AudienceSegmentBar extends StatelessWidget {
  final String mode;
  final VoidCallback? onInspectDiff;
  final bool highlighted;

  const V2AudienceSegmentBar({
    super.key,
    required this.mode,
    this.onInspectDiff,
    this.highlighted = false,
  });

  bool get _isTargeted {
    final lower = mode.toLowerCase();
    return lower.contains('lookalike') ||
        lower.contains('vip') ||
        lower.contains('cart') ||
        lower.contains('loyalty') ||
        lower.contains('retarget') ||
        lower.contains('homeowner') ||
        lower.contains('cmo') ||
        lower.contains('director');
  }

  @override
  Widget build(BuildContext context) {
    final targeted = _isTargeted;
    final segments = List.generate(12, (i) {
      if (targeted) {
        if (i < 3) return 'core';
        if (i < 5) return 'lookalike';
        return 'suppressed';
      } else {
        if (i >= 9) return 'waste';
        return 'broad';
      }
    });

    final displayMode = mode.length > 26 ? '${mode.substring(0, 24)}…' : mode;

    return InkWell(
      onTap: onInspectDiff,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: highlighted ? V2Tokens.changedRowTint : V2Tokens.bgPlaster,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlighted ? V2Tokens.inkPrussian : V2Tokens.hairline,
            width: highlighted ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Audience · $displayMode',
                    overflow: TextOverflow.ellipsis,
                    style: V2Tokens.t3(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: targeted ? V2Tokens.approvedChipBg : V2Tokens.changesChipBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    targeted ? '5 of 12 segments active' : '12 of 12 broad reach',
                    style: V2Tokens.t4(
                      color: targeted ? V2Tokens.approvedSolid : V2Tokens.changesSolid,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(12, (idx) {
                final type = segments[idx];
                Color bg;
                if (type == 'core') {
                  bg = V2Tokens.inkPrussian;
                } else if (type == 'lookalike') {
                  bg = V2Tokens.cadmiumYellow;
                } else if (type == 'waste') {
                  bg = V2Tokens.blockedSolid;
                } else if (type == 'broad') {
                  bg = V2Tokens.reviewSolid;
                } else {
                  bg = V2Tokens.surfaceRecessed;
                }
                return Expanded(
                  child: Container(
                    height: 8,
                    margin: EdgeInsets.only(right: idx == 11 ? 0 : 4),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(2),
                      border: type == 'lookalike'
                          ? Border.all(color: V2Tokens.inkPrussian, width: 0.6)
                          : null,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    targeted
                        ? '7 low-intent segments suppressed'
                        : 'Includes 3 high-CPA broad segments',
                    overflow: TextOverflow.ellipsis,
                    style: V2Tokens.t3(color: V2Tokens.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Inspect diff →', style: V2Tokens.t4(color: V2Tokens.inkPrussian)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class V2StampClause {
  final String field; // 'Budget' | 'Audience' | 'Channel'
  final String metricDelta;
  final String note;
  final String clauseStatus;
  final String resolutionTag;

  const V2StampClause({
    required this.field,
    required this.metricDelta,
    required this.note,
    required this.clauseStatus,
    required this.resolutionTag,
  });
}

class V2StampEntry {
  final int versionNo;
  final String versionTag;
  final String status;
  final String stampWord;
  final String actor;
  final String time;
  final List<V2StampClause> clauses;

  const V2StampEntry({
    required this.versionNo,
    required this.versionTag,
    required this.status,
    required this.stampWord,
    required this.actor,
    required this.time,
    required this.clauses,
  });
}

/// Synchronized vertical version timeline with inline clause filtering & diff trigger.
class V2VerticalVersionThread extends StatelessWidget {
  final List<V2StampEntry> stamps;
  final int selectedStampIdx;
  final ValueChanged<int> onSelectStamp;
  final String? activeClauseFilter;
  final ValueChanged<String?>? onHighlightClause;
  final VoidCallback? onOpenDiff;

  const V2VerticalVersionThread({
    super.key,
    required this.stamps,
    required this.selectedStampIdx,
    required this.onSelectStamp,
    this.activeClauseFilter,
    this.onHighlightClause,
    this.onOpenDiff,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
              Text('Version thread', style: V2Tokens.t2()),
              if (onOpenDiff != null)
                InkWell(
                  onTap: onOpenDiff,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: V2Tokens.surfaceRecessed,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: V2Tokens.hairline, width: 1),
                    ),
                    child: Text('Compare diff →', style: V2Tokens.t4(color: V2Tokens.inkPrussian)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: List.generate(stamps.length, (idx) {
              final st = stamps[idx];
              final isSelected = idx == selectedStampIdx;
              final isLast = idx == stamps.length - 1;
              final cfg = V2Tokens.statusStyle(st.status);

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 22,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: V2FacetCell(
                              status: st.status,
                              size: isSelected ? 15 : 12,
                              selected: isSelected,
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 1.5,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                color: V2Tokens.hairline,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onSelectStamp(idx),
                        child: Container(
                          margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
                          padding: EdgeInsets.all(isSelected ? 12 : 8),
                          decoration: BoxDecoration(
                            color: isSelected ? V2Tokens.bgPlaster : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? V2Tokens.inkPrussian : Colors.transparent,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(st.versionTag, style: V2Tokens.t2(mono: true)),
                                      const SizedBox(width: 8),
                                      Text(
                                        st.stampWord,
                                        style: V2Tokens.t3(
                                          color: cfg.solid,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(st.time, style: V2Tokens.t4()),
                                ],
                              ),
                              if (isSelected) ...[
                                const SizedBox(height: 8),
                                RichText(
                                  text: TextSpan(
                                    style: V2Tokens.t3(color: V2Tokens.textSecondary),
                                    children: [
                                      const TextSpan(text: 'Actor: '),
                                      TextSpan(
                                        text: st.actor,
                                        style: V2Tokens.t3(fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...st.clauses.map((clause) {
                                  final isClauseActive = activeClauseFilter == clause.field;
                                  final clauseCfg = V2Tokens.statusStyle(clause.clauseStatus);
                                  return GestureDetector(
                                    onTap: () {
                                      onHighlightClause?.call(isClauseActive ? null : clause.field);
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isClauseActive
                                            ? V2Tokens.changedRowTint
                                            : V2Tokens.surfaceCard,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isClauseActive
                                              ? V2Tokens.inkPrussian
                                              : V2Tokens.hairline,
                                          width: isClauseActive ? 1.5 : 1.0,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  '${clause.field} · ${clause.metricDelta}',
                                                  overflow: TextOverflow.ellipsis,
                                                  style: V2Tokens.t4(color: V2Tokens.textPrimary),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                clause.resolutionTag,
                                                style: V2Tokens.t4(color: clauseCfg.solid),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            clause.note,
                                            style: V2Tokens.t3(color: V2Tokens.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Solid docked 4-tab bottom navigation bar (`Pipeline`, `Calendar`, `Insights`, `Activity`).
class V2SolidBottomBar extends StatelessWidget {
  final String activeTab;
  final ValueChanged<String> onSelectTab;

  const V2SolidBottomBar({
    super.key,
    required this.activeTab,
    required this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const _V2TabSpec('pipeline', 'Pipeline', Icons.view_agenda_outlined),
      const _V2TabSpec('calendar', 'Calendar', Icons.calendar_today_outlined),
      const _V2TabSpec('insights', 'Insights', Icons.show_chart_rounded),
      const _V2TabSpec('activity', 'Activity', Icons.timeline_rounded),
    ];

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: V2Tokens.surfaceCard,
        border: Border(top: BorderSide(color: V2Tokens.hairline, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Row(
                children: tabs.map((tab) {
                  final isActive = activeTab == tab.id;
                  return Expanded(
                    child: InkWell(
                      onTap: () => onSelectTab(tab.id),
                      borderRadius: BorderRadius.circular(14),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive ? V2Tokens.inkPrussian : Colors.transparent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Icon(
                                tab.icon,
                                size: 17,
                                color: isActive ? V2Tokens.labelOnInk : V2Tokens.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              tab.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                letterSpacing: -0.1,
                                height: 1.15,
                                color: isActive ? V2Tokens.textPrimary : V2Tokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _V2TabSpec {
  final String id;
  final String label;
  final IconData icon;

  const _V2TabSpec(this.id, this.label, this.icon);
}

/// Authentic dimmed-parent-peek modal sheet container matching the iOS bottom sheet grammar.
class V2SheetScaffold extends StatelessWidget {
  final String parentTitle;
  final String parentSub;
  final String parentStatus;
  final VoidCallback onClose;
  final Widget? rightAction;
  final Widget child;

  const V2SheetScaffold({
    super.key,
    required this.parentTitle,
    required this.parentSub,
    required this.parentStatus,
    required this.onClose,
    this.rightAction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: V2Tokens.textPrimary,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                // Dimmed parent context peek
                GestureDetector(
                  onTap: onClose,
                  child: Transform.scale(
                    scale: 0.96,
                    alignment: Alignment.topCenter,
                    child: Opacity(
                      opacity: 0.44,
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                        decoration: const BoxDecoration(
                          color: V2Tokens.bgPlaster,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    parentTitle,
                                    overflow: TextOverflow.ellipsis,
                                    style: V2Tokens.t2(),
                                  ),
                                  Text(
                                    parentSub,
                                    overflow: TextOverflow.ellipsis,
                                    style: V2Tokens.t4(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            V2StatusBadge(status: parentStatus),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Active sheet body with grabber & dismiss bar
                Expanded(
                  child: Container(
                    transform: Matrix4.translationValues(0, -8, 0),
                    decoration: const BoxDecoration(
                      color: V2Tokens.bgPlaster,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      border: Border(top: BorderSide(color: V2Tokens.hairline, width: 1)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                          decoration: const BoxDecoration(
                            color: V2Tokens.surfaceCard,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            border: Border(bottom: BorderSide(color: V2Tokens.hairline, width: 1)),
                          ),
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: onClose,
                                child: Container(
                                  width: 36,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: V2Tokens.hairline,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  InkWell(
                                    onTap: onClose,
                                    borderRadius: BorderRadius.circular(8),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(minHeight: 36),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.chevron_left_rounded,
                                            size: 18,
                                            color: V2Tokens.textPrimary,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            'Dismiss sheet',
                                            style: V2Tokens.t3(fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (rightAction != null) rightAction!,
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 45-degree diagonal stripe hatch painter for conflicting calendar slots.
class V2DiagonalStripePainter extends CustomPainter {
  final Color baseColor;
  final Color stripeColor;

  const V2DiagonalStripePainter({
    this.baseColor = V2Tokens.blockedChipBg,
    this.stripeColor = V2Tokens.blockedStripeAlt,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = baseColor);
    final paint = Paint()
      ..color = stripeColor
      ..strokeWidth = 5;

    final maxDim = size.width + size.height;
    for (double x = -size.height; x < maxDim; x += 11) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant V2DiagonalStripePainter oldDelegate) =>
      oldDelegate.baseColor != baseColor || oldDelegate.stripeColor != stripeColor;
}
