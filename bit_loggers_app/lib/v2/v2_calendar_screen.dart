import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'v2_components.dart';
import 'v2_tokens.dart';

class _V2LaneModel {
  final String id;
  final String? campaignId;
  final String channel;
  final String title;
  final String version;
  final String owner;
  final String status; // 'scheduled', 'review', 'blocked', 'approved'
  final String word;
  final int startIdx;
  final int endIdx;
  final double budget;
  final int dailyBurn;
  final String? conflictHolder;
  final int? conflictStartIdx;
  final int? conflictEndIdx;

  const _V2LaneModel({
    required this.id,
    this.campaignId,
    required this.channel,
    required this.title,
    required this.version,
    required this.owner,
    required this.status,
    required this.word,
    required this.startIdx,
    required this.endIdx,
    required this.budget,
    required this.dailyBurn,
    this.conflictHolder,
    this.conflictStartIdx,
    this.conflictEndIdx,
  });

  _V2LaneModel copyWith({
    int? startIdx,
    int? endIdx,
    String? status,
    String? word,
  }) =>
      _V2LaneModel(
        id: id,
        campaignId: campaignId,
        channel: channel,
        title: title,
        version: version,
        owner: owner,
        status: status ?? this.status,
        word: word ?? this.word,
        startIdx: startIdx ?? this.startIdx,
        endIdx: endIdx ?? this.endIdx,
        budget: budget,
        dailyBurn: dailyBurn,
        conflictHolder: conflictHolder,
        conflictStartIdx: conflictStartIdx,
        conflictEndIdx: conflictEndIdx,
      );
}

/// Screen 09: 5-Day Rolling Omnichannel Gantt Matrix with Slot Shift & Conflict Guardian.
class V2CalendarScreen extends StatefulWidget {
  final List<Campaign> campaigns;
  final List<ScheduleEvent> calendarEvents;
  final void Function(String? campaignId, bool forceConflictBlocked, DateTime start, DateTime end) onScheduleSelected;

  const V2CalendarScreen({
    super.key,
    required this.campaigns,
    required this.calendarEvents,
    required this.onScheduleSelected,
  });

  @override
  State<V2CalendarScreen> createState() => _V2CalendarScreenState();
}

class _V2CalendarScreenState extends State<V2CalendarScreen> {
  int _windowStart = 0; // 0..2 over 7-day rolling span
  int _selectedDayIdx = 1;
  String _selectedChannel = 'Social';
  late DateTime _anchorDate;
  late List<_V2LaneModel> _lanes;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchorDate = DateTime(now.year, now.month, now.day);
    _lanes = _buildInitialLanes();
  }

  @override
  void didUpdateWidget(covariant V2CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.calendarEvents != widget.calendarEvents ||
        oldWidget.campaigns != widget.campaigns) {
      _lanes = _buildInitialLanes();
    }
  }

  List<_V2LaneModel> _buildInitialLanes() {
    ScheduleEvent? findEvent(String ch) {
      for (final e in widget.calendarEvents) {
        if (e.channel.toLowerCase() == ch.toLowerCase()) return e;
      }
      return null;
    }

    Campaign? findCampaign(String ch) {
      for (final c in widget.campaigns) {
        if ((c.currentVersion?.channel ?? '').toLowerCase() == ch.toLowerCase()) return c;
      }
      return null;
    }

    int clampIdx(DateTime? dt, int fallback) {
      if (dt == null) return fallback;
      final diff = DateTime(dt.year, dt.month, dt.day).difference(_anchorDate).inDays;
      return diff.clamp(0, 6);
    }

    final searchEv = findEvent('Search');
    final searchCamp = findCampaign('Search');
    final socialEv = findEvent('Social');
    final socialCamp = findCampaign('Social');
    final emailEv = findEvent('Email');
    final emailCamp = findCampaign('Email');
    final displayCamp = findCampaign('Display');

    final socialStart = clampIdx(
      socialEv != null ? DateTime.tryParse(socialEv.startsAt)?.toLocal() : null,
      1,
    );
    final socialEnd = clampIdx(
      socialEv != null ? DateTime.tryParse(socialEv.endsAt)?.toLocal() : null,
      5,
    );
    final socialKey = V2Tokens.normalizeStatusKey(socialCamp?.status ?? (socialEv != null ? 'scheduled' : 'review'));

    return [
      _V2LaneModel(
        id: 'lane-search',
        campaignId: searchEv?.campaignId ?? searchCamp?.campaignId,
        channel: 'Search',
        title: searchEv?.title ?? searchCamp?.title ?? 'Enterprise Search',
        version: 'V${searchEv?.versionNo ?? searchCamp?.currentVersion?.versionNo ?? 1}.0',
        owner: V2Tokens.cleanPersonName(searchCamp?.ownerName ?? 'Alice Cooper'),
        status: searchEv != null ? 'scheduled' : V2Tokens.normalizeStatusKey(searchCamp?.status ?? 'approved'),
        word: searchEv != null ? 'Scheduled' : V2Tokens.statusStyle(searchCamp?.status ?? 'approved').label,
        startIdx: clampIdx(searchEv != null ? DateTime.tryParse(searchEv.startsAt)?.toLocal() : null, 0),
        endIdx: clampIdx(searchEv != null ? DateTime.tryParse(searchEv.endsAt)?.toLocal() : null, 4),
        budget: searchEv?.budget ?? searchCamp?.currentVersion?.budget ?? 28000,
        dailyBurn: 3800,
      ),
      _V2LaneModel(
        id: 'lane-social',
        campaignId: socialEv?.campaignId ?? socialCamp?.campaignId,
        channel: 'Social',
        title: socialEv?.title ?? socialCamp?.title ?? 'Summer Solar Flash Sale',
        version: 'V${socialEv?.versionNo ?? socialCamp?.currentVersion?.versionNo ?? 3}.0',
        owner: V2Tokens.cleanPersonName(socialCamp?.ownerName ?? 'Alice Cooper'),
        status: socialKey == 'scheduled' || socialKey == 'approved' ? 'scheduled' : 'review',
        word: socialKey == 'scheduled' ? 'Scheduled' : V2Tokens.statusStyle(socialKey).label,
        startIdx: socialStart,
        endIdx: socialEnd < socialStart ? (socialStart + 3).clamp(0, 6) : socialEnd,
        budget: socialEv?.budget ?? socialCamp?.currentVersion?.budget ?? 25000,
        dailyBurn: 5000,
      ),
      _V2LaneModel(
        id: 'lane-display',
        campaignId: displayCamp?.campaignId,
        channel: 'Display',
        title: displayCamp?.title ?? 'Black Friday Display',
        version: 'V${displayCamp?.currentVersion?.versionNo ?? 2}.0',
        owner: V2Tokens.cleanPersonName(displayCamp?.ownerName ?? 'Marcus Vance'),
        status: 'blocked',
        word: 'Conflict',
        startIdx: 2,
        endIdx: 6,
        budget: displayCamp?.currentVersion?.budget ?? 18000,
        dailyBurn: 4200,
        conflictHolder: 'Winter Promo V1.0',
        conflictStartIdx: 1,
        conflictEndIdx: 3,
      ),
      _V2LaneModel(
        id: 'lane-email',
        campaignId: emailEv?.campaignId ?? emailCamp?.campaignId,
        channel: 'Email',
        title: emailEv?.title ?? emailCamp?.title ?? 'VIP Early Access',
        version: 'V${emailEv?.versionNo ?? emailCamp?.currentVersion?.versionNo ?? 1}.0',
        owner: V2Tokens.cleanPersonName(emailCamp?.ownerName ?? 'Alice Cooper'),
        status: 'scheduled',
        word: 'Scheduled',
        startIdx: clampIdx(emailEv != null ? DateTime.tryParse(emailEv.startsAt)?.toLocal() : null, 1),
        endIdx: clampIdx(emailEv != null ? DateTime.tryParse(emailEv.endsAt)?.toLocal() : null, 3),
        budget: emailEv?.budget ?? 15000,
        dailyBurn: 2600,
      ),
      const _V2LaneModel(
        id: 'lane-video',
        channel: 'Video',
        title: 'Seasonal Reels Launch',
        version: 'V2.0',
        owner: 'Elena Rostova',
        status: 'review',
        word: 'In review',
        startIdx: 3,
        endIdx: 6,
        budget: 18000,
        dailyBurn: 4500,
      ),
    ];
  }

  void _shiftSelectedFlight(int delta) {
    setState(() {
      _lanes = _lanes.map((lane) {
        if (lane.channel != _selectedChannel) return lane;
        final span = lane.endIdx - lane.startIdx;
        final nextStart = (lane.startIdx + delta).clamp(0, 6 - span);
        final nextEnd = nextStart + span;
        if (lane.conflictHolder != null &&
            lane.conflictStartIdx != null &&
            lane.conflictEndIdx != null) {
          final overlaps =
              nextStart <= lane.conflictEndIdx! && nextEnd >= lane.conflictStartIdx!;
          return lane.copyWith(
            startIdx: nextStart,
            endIdx: nextEnd,
            status: overlaps ? 'blocked' : 'approved',
            word: overlaps ? 'Conflict' : 'Clear',
          );
        }
        return lane.copyWith(startIdx: nextStart, endIdx: nextEnd);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final allDays = List.generate(7, (i) {
      final dt = _anchorDate.add(Duration(days: i));
      return (
        idx: i,
        dow: DateFormat('EEE').format(dt).toUpperCase(),
        numStr: DateFormat('dd').format(dt),
        monthDay: DateFormat('MMM dd').format(dt),
        dt: dt,
      );
    });

    final visibleDays = allDays.sublist(_windowStart, _windowStart + 5);
    final selectedFlight = _lanes.firstWhere(
      (l) => l.channel == _selectedChannel,
      orElse: () => _lanes.first,
    );

    final activeOnDay = _lanes.where(
      (f) => _selectedDayIdx >= f.startIdx && _selectedDayIdx <= f.endIdx,
    );
    final dailySpendTotal = activeOnDay.fold<int>(0, (s, f) => s + f.dailyBurn);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      children: [
        // Header + 5-day rolling stepper
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Calendar', style: V2Tokens.t1()),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: _windowStart == 0 ? null : () => setState(() => _windowStart--),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: V2Tokens.surfaceCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: V2Tokens.hairline, width: 1),
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 16,
                      color: _windowStart == 0 ? V2Tokens.hairline : V2Tokens.textPrimary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${visibleDays.first.monthDay}–${visibleDays.last.numStr}',
                    style: V2Tokens.t4(),
                  ),
                ),
                InkWell(
                  onTap: _windowStart == 2 ? null : () => setState(() => _windowStart++),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: V2Tokens.surfaceCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: V2Tokens.hairline, width: 1),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: _windowStart == 2 ? V2Tokens.hairline : V2Tokens.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 5-Day Rolling Pill Strip
        Row(
          children: visibleDays.map((day) {
            final active = _selectedDayIdx == day.idx;
            final dayHasConflict = _lanes.any(
              (f) => f.status == 'blocked' && day.idx >= f.startIdx && day.idx <= f.endIdx,
            );
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedDayIdx = day.idx),
                child: Container(
                  margin: EdgeInsets.only(right: day.idx == visibleDays.last.idx ? 0 : 6),
                  constraints: const BoxConstraints(minHeight: 50),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: BoxDecoration(
                    color: active ? V2Tokens.inkPrussian : V2Tokens.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active
                          ? V2Tokens.inkPrussian
                          : dayHasConflict
                              ? V2Tokens.blockedSolid
                              : V2Tokens.hairline,
                      width: active ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        day.dow,
                        style: V2Tokens.t4(
                          color: active ? V2Tokens.cadmiumYellow : V2Tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        day.numStr,
                        style: V2Tokens.t2(
                          mono: true,
                          color: active ? V2Tokens.labelOnInk : V2Tokens.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        // 5-Channel x 5-Day Spacious Swimlane Matrix
        Container(
          decoration: BoxDecoration(
            color: V2Tokens.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: V2Tokens.hairline, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ...List.generate(_lanes.length, (rIdx) {
                final lane = _lanes[rIdx];
                final isSelected = _selectedChannel == lane.channel;
                final isScheduled = lane.status == 'scheduled' || lane.status == 'approved';
                final isConflict = lane.status == 'blocked';

                final winEnd = _windowStart + 4;
                final clampedStart = lane.startIdx.clamp(_windowStart, winEnd + 1);
                final clampedEnd = lane.endIdx.clamp(_windowStart - 1, winEnd);
                final isVisible = lane.endIdx >= _windowStart && lane.startIdx <= winEnd;

                return InkWell(
                  onTap: () => setState(() => _selectedChannel = lane.channel),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 54),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? V2Tokens.changedRowTint : Colors.transparent,
                      border: rIdx < _lanes.length - 1
                          ? const Border(bottom: BorderSide(color: V2Tokens.hairline, width: 1))
                          : null,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 78,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  V2FacetCell(status: lane.status, size: 10),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      lane.channel,
                                      overflow: TextOverflow.ellipsis,
                                      style: V2Tokens.t3(
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(lane.version, style: V2Tokens.t4()),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SizedBox(
                            height: 38,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final totalW = constraints.maxWidth;
                                final colW = totalW / 5;
                                final barLeft = (clampedStart - _windowStart) * colW;
                                final barSpan = (clampedEnd - clampedStart + 1).clamp(1, 5);
                                final barW = barSpan * colW;

                                return Stack(
                                  children: [
                                    Row(
                                      children: visibleDays.map((d) {
                                        final isDayCol = d.idx == _selectedDayIdx;
                                        return Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: isDayCol
                                                  ? V2Tokens.cadmiumYellow.withOpacity(0.14)
                                                  : Colors.transparent,
                                              border: const Border(
                                                left: BorderSide(color: V2Tokens.hairline, width: 0.7),
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    if (isVisible)
                                      AnimatedPositioned(
                                        duration: const Duration(milliseconds: 180),
                                        curve: Curves.easeOut,
                                        top: 3,
                                        height: 32,
                                        left: barLeft,
                                        width: barW,
                                        child: Container(
                                          clipBehavior: Clip.antiAlias,
                                          decoration: BoxDecoration(
                                            color: isScheduled
                                                ? V2Tokens.approvedSolid
                                                : isConflict
                                                    ? V2Tokens.blockedChipBg
                                                    : V2Tokens.reviewChipBg,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isSelected
                                                  ? V2Tokens.inkPrussian
                                                  : isScheduled
                                                      ? V2Tokens.approvedSolid
                                                      : isConflict
                                                          ? V2Tokens.blockedSolid
                                                          : V2Tokens.reviewSolid,
                                              width: isSelected ? 1.5 : 1.25,
                                            ),
                                          ),
                                          child: CustomPaint(
                                            painter: isConflict
                                                ? const V2DiagonalStripePainter()
                                                : null,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Flexible(
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          isScheduled
                                                              ? Icons.check_rounded
                                                              : isConflict
                                                                  ? Icons.error_outline_rounded
                                                                  : Icons.schedule_rounded,
                                                          size: 12,
                                                          color: isScheduled
                                                              ? V2Tokens.labelOnInk
                                                              : isConflict
                                                                  ? V2Tokens.blockedSolid
                                                                  : V2Tokens.reviewSolid,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            lane.title,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: V2Tokens.t3(
                                                              fontWeight: FontWeight.w600,
                                                              color: isScheduled
                                                                  ? V2Tokens.labelOnInk
                                                                  : isConflict
                                                                      ? V2Tokens.blockedSolid
                                                                      : V2Tokens.reviewSolid,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (barSpan >= 3 || totalW > 420) ...[
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      lane.word,
                                                      style: V2Tokens.t4(
                                                        color: isScheduled
                                                            ? V2Tokens.labelOnInk
                                                            : isConflict
                                                                ? V2Tokens.blockedSolid
                                                                : V2Tokens.reviewSolid,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // Interactive Slot Shift Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  color: V2Tokens.bgPlaster,
                  border: Border(top: BorderSide(color: V2Tokens.hairline, width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '${selectedFlight.channel}: ${allDays[selectedFlight.startIdx].monthDay}–${allDays[selectedFlight.endIdx].numStr}',
                        overflow: TextOverflow.ellipsis,
                        style: V2Tokens.t4(),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: selectedFlight.startIdx == 0 ? null : () => _shiftSelectedFlight(-1),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 36),
                            padding: const EdgeInsets.symmetric(horizontal: 11),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: V2Tokens.surfaceCard,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: V2Tokens.hairline, width: 1),
                            ),
                            child: Text(
                              '◀ −1d',
                              style: V2Tokens.t4(
                                color: selectedFlight.startIdx == 0
                                    ? V2Tokens.hairline
                                    : V2Tokens.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: selectedFlight.endIdx == 6 ? null : () => _shiftSelectedFlight(1),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 36),
                            padding: const EdgeInsets.symmetric(horizontal: 11),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: V2Tokens.surfaceCard,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: V2Tokens.hairline, width: 1),
                            ),
                            child: Text(
                              '+1d ▶',
                              style: V2Tokens.t4(
                                color: selectedFlight.endIdx == 6
                                    ? V2Tokens.hairline
                                    : V2Tokens.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Dark Anchor Flight Summary Card with One-Tap Conflict Resolution
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: V2Tokens.inkPrussian,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            V2FacetCell(status: selectedFlight.status, size: 11),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${selectedFlight.title} · ${selectedFlight.version}',
                                overflow: TextOverflow.ellipsis,
                                style: V2Tokens.t2(color: V2Tokens.labelOnInk),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${selectedFlight.channel} · ${allDays[selectedFlight.startIdx].monthDay}–${allDays[selectedFlight.endIdx].numStr} · ${V2Tokens.formatCurrency(dailySpendTotal)}/d',
                          style: V2Tokens.t4(color: V2Tokens.cadmiumYellow),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      final isBlockedDemo = selectedFlight.status == 'blocked';
                      widget.onScheduleSelected(
                        selectedFlight.campaignId,
                        isBlockedDemo,
                        allDays[selectedFlight.startIdx].dt,
                        allDays[selectedFlight.endIdx].dt,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: V2Tokens.cadmiumYellow,
                      foregroundColor: V2Tokens.textPrimary,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: Text(
                      'Schedule',
                      style: V2Tokens.t3(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              if (selectedFlight.status == 'blocked') ...[
                const SizedBox(height: 10),
                InkWell(
                  onTap: () {
                    _shiftSelectedFlight(2);
                    setState(() => _windowStart = 2);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: V2Tokens.blockedSolid.withOpacity(0.32),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: V2Tokens.blockedSolid, width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Held by ${selectedFlight.conflictHolder ?? 'existing flight'}',
                            overflow: TextOverflow.ellipsis,
                            style: V2Tokens.t4(color: const Color(0xFFFFD2CC)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: V2Tokens.cadmiumYellow,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Shift to clear →',
                            style: V2Tokens.t4(color: V2Tokens.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

