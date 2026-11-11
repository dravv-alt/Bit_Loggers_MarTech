import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'v3_components.dart';
import 'v3_tokens.dart';

class _FlightSpan {
  final ScheduleEvent event;
  final DateTime startDay;
  final DateTime endDay;
  final int spanDays;

  const _FlightSpan({
    required this.event,
    required this.startDay,
    required this.endDay,
    required this.spanDays,
  });
}

class _WeekBarPlacement {
  final _FlightSpan flight;
  final int startCol;
  final int endCol;
  final int track;
  final bool clippedLeft;
  final bool clippedRight;

  const _WeekBarPlacement({
    required this.flight,
    required this.startCol,
    required this.endCol,
    required this.track,
    required this.clippedLeft,
    required this.clippedRight,
  });

  int get colSpan => endCol - startCol + 1;
}

class V3CalendarView extends StatefulWidget {
  final ApiService api;
  final V3Palette palette;
  final ValueChanged<String> onInspectCampaign;

  const V3CalendarView({
    super.key,
    required this.api,
    required this.palette,
    required this.onInspectCampaign,
  });

  @override
  State<V3CalendarView> createState() => _V3CalendarViewState();
}

class _V3CalendarViewState extends State<V3CalendarView> {
  static const _channels = ['All', 'Social', 'Search', 'Email', 'Display', 'Video'];
  static const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const int _maxVisibleTracks = 3;

  List<ScheduleEvent> _events = [];
  String _channelFilter = 'All';
  String _viewMode = 'month'; // 'month' | 'list'
  bool _loading = true;
  late DateTime _focusedMonth;
  DateTime? _selectedDay;
  String? _hoveredScheduleId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _load();
  }

  DateTime _dayOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await widget.api.getCalendar();
      if (!mounted) return;
      DateTime nextMonth = _focusedMonth;
      if (res.isNotEmpty) {
        final spans = _parseSpans(res);
        final hasInFocused = spans.any((s) =>
            _monthOverlaps(nextMonth, s.startDay, s.endDay));
        if (!hasInFocused) {
          final first = spans.first.startDay;
          nextMonth = DateTime(first.year, first.month, 1);
        }
      }
      setState(() {
        _events = res;
        _focusedMonth = nextMonth;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _monthOverlaps(DateTime monthFirst, DateTime startDay, DateTime endDay) {
    final daysInMonth = DateUtils.getDaysInMonth(monthFirst.year, monthFirst.month);
    final monthEnd = DateTime(monthFirst.year, monthFirst.month, daysInMonth);
    return !endDay.isBefore(monthFirst) && !startDay.isAfter(monthEnd);
  }

  List<_FlightSpan> _parseSpans(List<ScheduleEvent> source) {
    final nowDay = _dayOnly(DateTime.now());
    final parsed = <_FlightSpan>[];
    for (final evt in source) {
      final sRaw = DateTime.tryParse(evt.startsAt)?.toLocal() ?? nowDay;
      final eRaw = DateTime.tryParse(evt.endsAt)?.toLocal() ?? sRaw.add(const Duration(days: 4));
      final sDay = _dayOnly(sRaw);
      final rawEnd = _dayOnly(eRaw);
      final eDay = rawEnd.isBefore(sDay) ? sDay : rawEnd;
      final spanDays = math.max(1, eDay.difference(sDay).inDays);
      parsed.add(_FlightSpan(
        event: evt,
        startDay: sDay,
        endDay: eDay,
        spanDays: spanDays,
      ));
    }
    parsed.sort((a, b) {
      final cmp = a.startDay.compareTo(b.startDay);
      if (cmp != 0) return cmp;
      return b.spanDays.compareTo(a.spanDays);
    });
    return parsed;
  }

  String _formatCompactRange(_FlightSpan span) {
    final fmt = DateFormat('MMM d');
    if (_sameDay(span.startDay, span.endDay)) {
      return fmt.format(span.startDay);
    }
    return '${fmt.format(span.startDay)} — ${fmt.format(span.endDay)}';
  }

  void _shiftMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta, 1);
      _selectedDay = null;
    });
  }

  void _jumpToToday() {
    final nowDay = _dayOnly(DateTime.now());
    setState(() {
      _focusedMonth = DateTime(nowDay.year, nowDay.month, 1);
      _selectedDay = nowDay;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final filteredEvents = _events
        .where((e) =>
            _channelFilter == 'All' || e.channel.toLowerCase() == _channelFilter.toLowerCase())
        .toList();
    final spans = _parseSpans(filteredEvents);

    final monthSpans = spans
        .where((s) => _monthOverlaps(_focusedMonth, s.startDay, s.endDay))
        .toList();

    final listSpans = _viewMode == 'month' && _selectedDay != null
        ? spans
            .where((s) =>
                !_selectedDay!.isBefore(s.startDay) && !_selectedDay!.isAfter(s.endDay))
            .toList()
        : (_viewMode == 'month' ? monthSpans : spans);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(p),
        const SizedBox(height: 16),

        if (_viewMode == 'month') ...[
          _buildMonthCalendarCard(p, spans, monthSpans),
          const SizedBox(height: 18),
        ],

        _buildFlightsSectionHeader(p, listSpans.length),
        const SizedBox(height: 10),

        if (listSpans.isEmpty)
          V3DashedBox(
            palette: p,
            minHeight: 160,
            padding: const EdgeInsets.all(24),
            borderRadius: 16,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_outlined, size: 28, color: p.iconTertiary),
                const SizedBox(height: 10),
                Text(
                  _selectedDay != null
                      ? 'No flights active on ${DateFormat('MMM d').format(_selectedDay!)}'
                      : 'No active flights in this window',
                  style: V3Tokens.headline(p),
                ),
                const SizedBox(height: 5),
                Text(
                  _selectedDay != null
                      ? 'Channel capacity is clear on this date. Select another date or clear the day filter.'
                      : 'Approved campaign proposals can be scheduled onto a conflict-free channel window from the Pipeline view.',
                  textAlign: TextAlign.center,
                  style: V3Tokens.bodyRegular(p),
                ),
                if (_selectedDay != null) ...[
                  const SizedBox(height: 12),
                  V3Button(
                    label: 'Show all ${DateFormat('MMMM').format(_focusedMonth)} flights',
                    small: true,
                    palette: p,
                    onTap: () => setState(() => _selectedDay = null),
                  ),
                ],
              ],
            ),
          )
        else
          ...listSpans.map((span) => _buildFlightCard(p, span)),
      ],
    );
  }

  Widget _buildToolbar(V3Palette p) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.borderDefault),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          V3SegmentedControl<String>(
            palette: p,
            selected: _channelFilter,
            options: _channels
                .map((c) => V3SegmentedOption(
                      id: c,
                      label: c == 'All' ? 'All lanes' : c,
                    ))
                .toList(),
            onSelect: (ch) => setState(() => _channelFilter = ch),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              V3Chip(
                label: 'Overlap guard active',
                tone: 'lime',
                palette: p,
                leadingIcon: Icons.verified_user_outlined,
              ),
              V3SegmentedControl<String>(
                palette: p,
                selected: _viewMode,
                options: const [
                  V3SegmentedOption(
                    id: 'month',
                    label: 'Month',
                    icon: Icons.calendar_month_outlined,
                  ),
                  V3SegmentedOption(
                    id: 'list',
                    label: 'Schedule',
                    icon: Icons.view_agenda_outlined,
                  ),
                ],
                onSelect: (m) => setState(() => _viewMode = m),
              ),
              V3Button(
                label: _loading ? 'Syncing…' : 'Refresh',
                icon: Icons.refresh_rounded,
                small: true,
                palette: p,
                onTap: _load,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCalendarCard(
    V3Palette p,
    List<_FlightSpan> allSpans,
    List<_FlightSpan> monthSpans,
  ) {
    final firstOfMonth = _focusedMonth;
    final leadingOffset = firstOfMonth.weekday % 7; // Sunday = 0
    final gridStart = firstOfMonth.subtract(Duration(days: leadingOffset));
    final daysInMonth = DateUtils.getDaysInMonth(firstOfMonth.year, firstOfMonth.month);
    final weekCount = ((leadingOffset + daysInMonth) / 7).ceil();
    final totalMonthBudget = monthSpans.fold<double>(0, (acc, s) => acc + s.event.budget);
    final monthLabel = DateFormat('MMMM yyyy').format(firstOfMonth);

    return Container(
      decoration: BoxDecoration(
        color: p.bgPrimary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.borderDefault),
        boxShadow: [
          BoxShadow(
            color: p.cardShadowColor,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Calendar Month Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(monthLabel, style: V3Tokens.title2(p)),
                    V3Badge(
                      label:
                          '${monthSpans.length} ${monthSpans.length == 1 ? 'flight' : 'flights'} • ${V3Tokens.formatMoney(totalMonthBudget)}',
                      palette: p,
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _navIconButton(
                      p,
                      icon: Icons.chevron_left_rounded,
                      tooltip: 'Previous month',
                      onTap: () => _shiftMonth(-1),
                    ),
                    const SizedBox(width: 6),
                    V3Button(
                      label: 'Today',
                      small: true,
                      palette: p,
                      onTap: _jumpToToday,
                    ),
                    const SizedBox(width: 6),
                    _navIconButton(
                      p,
                      icon: Icons.chevron_right_rounded,
                      tooltip: 'Next month',
                      onTap: () => _shiftMonth(1),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 7-Column Weekday Strip
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: p.bgSecondary,
              border: Border(
                top: BorderSide(color: p.separator),
                bottom: BorderSide(color: p.separator),
              ),
            ),
            child: Row(
              children: List.generate(7, (idx) {
                final isWeekend = idx == 0 || idx == 6;
                return Expanded(
                  child: Center(
                    child: Text(
                      _weekdays[idx],
                      style: V3Tokens.caption(
                        p,
                        color: isWeekend ? p.textTertiary : p.textSecondary,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Calendar Weeks Matrix
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktopGrid = constraints.maxWidth >= 660;
              return Column(
                children: List.generate(weekCount, (weekIdx) {
                  final weekStart = gridStart.add(Duration(days: weekIdx * 7));
                  final isLastWeek = weekIdx == weekCount - 1;
                  if (isDesktopGrid) {
                    return _buildDesktopWeekRow(
                      p,
                      weekStart: weekStart,
                      colWidth: constraints.maxWidth / 7,
                      spans: allSpans,
                      isLastWeek: isLastWeek,
                    );
                  }
                  return _buildMobileWeekRow(
                    p,
                    weekStart: weekStart,
                    spans: allSpans,
                    isLastWeek: isLastWeek,
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _navIconButton(
    V3Palette p, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 34,
            height: 32,
            decoration: BoxDecoration(
              color: p.bgPrimary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.borderDefault),
            ),
            child: Icon(icon, size: 18, color: p.iconPrimary),
          ),
        ),
      ),
    );
  }

  List<_WeekBarPlacement> _layoutWeekBars(DateTime weekStart, List<_FlightSpan> spans) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final weekSpans = spans
        .where((s) => !s.endDay.isBefore(weekStart) && !s.startDay.isAfter(weekEnd))
        .toList();

    final placements = <_WeekBarPlacement>[];
    final trackLastCols = <int>[];

    for (final span in weekSpans) {
      final rawStart = span.startDay.difference(weekStart).inDays;
      final rawEnd = span.endDay.difference(weekStart).inDays;
      final startCol = rawStart.clamp(0, 6);
      final endCol = rawEnd.clamp(0, 6);

      int chosenTrack = -1;
      for (int t = 0; t < trackLastCols.length; t++) {
        if (startCol > trackLastCols[t]) {
          chosenTrack = t;
          trackLastCols[t] = endCol;
          break;
        }
      }
      if (chosenTrack == -1) {
        chosenTrack = trackLastCols.length;
        trackLastCols.add(endCol);
      }

      placements.add(_WeekBarPlacement(
        flight: span,
        startCol: startCol,
        endCol: endCol,
        track: chosenTrack,
        clippedLeft: span.startDay.isBefore(weekStart),
        clippedRight: span.endDay.isAfter(weekEnd),
      ));
    }
    return placements;
  }

  Widget _buildDesktopWeekRow(
    V3Palette p, {
    required DateTime weekStart,
    required double colWidth,
    required List<_FlightSpan> spans,
    required bool isLastWeek,
  }) {
    final today = _dayOnly(DateTime.now());
    final placements = _layoutWeekBars(weekStart, spans);
    final visibleBars = placements.where((pl) => pl.track < _maxVisibleTracks).toList();
    final overflowPerCol = <int, int>{};
    for (final pl in placements) {
      if (pl.track >= _maxVisibleTracks) {
        for (int col = pl.startCol; col <= pl.endCol; col++) {
          overflowPerCol[col] = (overflowPerCol[col] ?? 0) + 1;
        }
      }
    }

    final maxTracks = visibleBars.isEmpty
        ? 0
        : visibleBars.map((e) => e.track + 1).reduce(math.max);
    final hasOverflow = overflowPerCol.isNotEmpty;
    final rowHeight = math.max(102.0, 40.0 + maxTracks * 25.0 + (hasOverflow ? 22.0 : 12.0));

    return Container(
      height: rowHeight,
      decoration: BoxDecoration(
        border: isLastWeek ? null : Border(bottom: BorderSide(color: p.separator)),
      ),
      child: Stack(
        children: [
          // 7 Day Columns Backdrop
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(7, (col) {
              final day = weekStart.add(Duration(days: col));
              final inMonth = day.month == _focusedMonth.month && day.year == _focusedMonth.year;
              final isToday = _sameDay(day, today);
              final isSelected = _selectedDay != null && _sameDay(day, _selectedDay!);
              final isWeekend = col == 0 || col == 6;

              final Color cellBg;
              if (isSelected) {
                cellBg = p.accentBgSoft.withOpacity(p.isDark ? 0.42 : 0.55);
              } else if (!inMonth) {
                cellBg = p.bgSecondary.withOpacity(0.6);
              } else if (isWeekend) {
                cellBg = p.bgSecondary.withOpacity(0.28);
              } else {
                cellBg = Colors.transparent;
              }

              final dayLabel = day.day == 1
                  ? '${DateFormat('MMM').format(day)} 1'
                  : '${day.day}';

              return Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        if (_selectedDay != null && _sameDay(_selectedDay!, day)) {
                          _selectedDay = null;
                        } else {
                          _selectedDay = day;
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 7, 8, 6),
                      decoration: BoxDecoration(
                        color: cellBg,
                        border: col == 6
                            ? null
                            : Border(right: BorderSide(color: p.separator)),
                      ),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: isToday
                            ? Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: p.accent500,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${day.day}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              )
                            : Text(
                                dayLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: inMonth ? FontWeight.w500 : FontWeight.w400,
                                  color: isSelected
                                      ? p.accentText
                                      : (inMonth ? p.textSecondary : p.textTertiary),
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),

          // Continuous Multi-Day Flight Bars
          ...visibleBars.map((pl) {
            final evt = pl.flight.event;
            final tone = V3Tokens.channelChipTone(evt.channel);
            final colors = p.chipColors(tone);
            final isHovered = _hoveredScheduleId == evt.scheduleId;
            final left = pl.startCol * colWidth + (pl.clippedLeft ? 0.0 : 5.0);
            final rightInset = pl.clippedRight ? 0.0 : 5.0;
            final barWidth = math.max(
              24.0,
              pl.colSpan * colWidth - (pl.clippedLeft ? 0.0 : 5.0) - rightInset,
            );
            final top = 36.0 + pl.track * 25.0;

            return Positioned(
              left: left,
              top: top,
              width: barWidth,
              height: 22,
              child: Tooltip(
                message:
                    '${evt.title} (${evt.channel} v${evt.versionNo})\n${_formatCompactRange(pl.flight)} • ${V3Tokens.formatMoney(evt.budget)}',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _hoveredScheduleId = evt.scheduleId),
                  onExit: (_) => setState(() {
                    if (_hoveredScheduleId == evt.scheduleId) _hoveredScheduleId = null;
                  }),
                  child: GestureDetector(
                    onTap: () => widget.onInspectCampaign(evt.campaignId),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      decoration: BoxDecoration(
                        color: colors.bg,
                        borderRadius: BorderRadius.horizontal(
                          left: pl.clippedLeft ? Radius.zero : const Radius.circular(6),
                          right: pl.clippedRight ? Radius.zero : const Radius.circular(6),
                        ),
                        border: Border.all(
                          color: isHovered
                              ? colors.fg
                              : colors.fg.withOpacity(p.isDark ? 0.35 : 0.25),
                          width: isHovered ? 1.2 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (!pl.clippedLeft) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: colors.fg,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Expanded(
                            child: Text(
                              pl.colSpan >= 2
                                  ? '${evt.channel}: ${evt.title}'
                                  : evt.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: colors.fg,
                                letterSpacing: -0.1,
                                decoration: isHovered ? TextDecoration.underline : null,
                                decorationColor: colors.fg,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          if (pl.colSpan >= 3 && !pl.clippedRight) ...[
                            const SizedBox(width: 6),
                            Text(
                              V3Tokens.formatMoney(evt.budget),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: colors.fg.withOpacity(0.85),
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),

          // Overflow "+N more" indicators
          ...overflowPerCol.entries.map((entry) {
            return Positioned(
              left: entry.key * colWidth + 6,
              bottom: 5,
              child: Text(
                '+${entry.value} more',
                style: V3Tokens.caption(p, color: p.accentText, weight: FontWeight.w600)
                    .copyWith(fontSize: 10.5),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMobileWeekRow(
    V3Palette p, {
    required DateTime weekStart,
    required List<_FlightSpan> spans,
    required bool isLastWeek,
  }) {
    final today = _dayOnly(DateTime.now());
    return Container(
      height: 54,
      decoration: BoxDecoration(
        border: isLastWeek ? null : Border(bottom: BorderSide(color: p.separator)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(7, (col) {
          final day = weekStart.add(Duration(days: col));
          final inMonth = day.month == _focusedMonth.month && day.year == _focusedMonth.year;
          final isToday = _sameDay(day, today);
          final isSelected = _selectedDay != null && _sameDay(day, _selectedDay!);
          final daySpans = spans
              .where((s) => !day.isBefore(s.startDay) && !day.isAfter(s.endDay))
              .toList();

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  if (_selectedDay != null && _sameDay(_selectedDay!, day)) {
                    _selectedDay = null;
                  } else {
                    _selectedDay = day;
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? p.accentBgSoft.withOpacity(p.isDark ? 0.45 : 0.65)
                      : (!inMonth ? p.bgSecondary.withOpacity(0.55) : Colors.transparent),
                  border: col == 6 ? null : Border(right: BorderSide(color: p.separator)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: isToday
                          ? BoxDecoration(color: p.accent500, shape: BoxShape.circle)
                          : (isSelected
                              ? BoxDecoration(
                                  border: Border.all(color: p.accent500, width: 1.2),
                                  shape: BoxShape.circle,
                                )
                              : null),
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: (isToday || isSelected) ? FontWeight.w700 : FontWeight.w500,
                          color: isToday
                              ? Colors.white
                              : (isSelected
                                  ? p.accentText
                                  : (inMonth ? p.textPrimary : p.textTertiary)),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    if (daySpans.isNotEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: daySpans.take(3).map((s) {
                          final fg = p.chipColors(V3Tokens.channelChipTone(s.event.channel)).fg;
                          return Container(
                            width: 10,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: fg,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }).toList(),
                      )
                    else
                      const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFlightsSectionHeader(V3Palette p, int count) {
    final title = _viewMode == 'month' && _selectedDay != null
        ? 'Flights on ${DateFormat('EEEE, MMM d').format(_selectedDay!)}'
        : (_viewMode == 'month'
            ? '${DateFormat('MMMM').format(_focusedMonth)} flight schedule'
            : 'All scheduled channel flights');
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: V3Tokens.headline(p)),
            const SizedBox(width: 8),
            V3Badge(label: '$count', palette: p),
          ],
        ),
        if (_viewMode == 'month' && _selectedDay != null)
          V3Button(
            label: 'Clear day filter',
            icon: Icons.close_rounded,
            small: true,
            variant: V3ButtonVariant.ghost,
            palette: p,
            onTap: () => setState(() => _selectedDay = null),
          ),
      ],
    );
  }

  Widget _buildFlightCard(V3Palette p, _FlightSpan span) {
    final evt = span.event;
    final rangeLabel = _formatCompactRange(span);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: V3HoverCard(
        palette: p,
        onTap: () => widget.onInspectCampaign(evt.campaignId),
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        builder: (hovered) => LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 560;
            final leftInfo = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    V3Chip(
                      label: evt.channel,
                      tone: V3Tokens.channelChipTone(evt.channel),
                      palette: p,
                    ),
                    V3Badge(label: 'v${evt.versionNo}', palette: p),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        V3StatusDot(colorKey: 'green', palette: p),
                        const SizedBox(width: 5),
                        Text(evt.status, style: V3Tokens.caption(p)),
                      ],
                    ),
                    if (evt.budget > 0)
                      Text(
                        V3Tokens.formatMoney(evt.budget),
                        style: V3Tokens.caption(p, color: p.textSecondary, weight: FontWeight.w600),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  evt.title,
                  style: V3Tokens.title2(p).copyWith(
                    fontSize: 17,
                    color: hovered ? p.accentText : p.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Flight lock bound to exact approved version v${evt.versionNo}',
                  style: V3Tokens.bodyRegular(p),
                ),
              ],
            );

            final rightInfo = Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: p.bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${span.spanDays}-day window',
                        style: V3Tokens.caption(p, color: p.textTertiary),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_available_outlined,
                            size: 14,
                            color: p.iconSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(rangeLabel, style: V3Tokens.bodyMedium(p)),
                        ],
                      ),
                    ],
                  ),
                ),
                V3Button(
                  label: 'Open brief',
                  icon: Icons.visibility_outlined,
                  small: true,
                  palette: p,
                  onTap: () => widget.onInspectCampaign(evt.campaignId),
                ),
              ],
            );

            if (wide) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Expanded(child: leftInfo), const SizedBox(width: 12), rightInfo],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [leftInfo, const SizedBox(height: 12), rightInfo],
            );
          },
        ),
      ),
    );
  }
}
