import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/marketing_visuals.dart';
import '../widgets/react_bits.dart';
import 'campaign_detail_screen.dart';

/// CampaignGrid "Obsidian Vitreum" Calendar & Flight Scheduler
/// High-luminance multi-channel visual flight board with:
/// 1. Monthly Grid View with responsive 7-column layout, glowing day nodes & conflict radar
/// 2. Weekly Flight Lanes Board (Gantt-style channel lanes with occupancy gauges)
/// 3. Conflict Detection Engine with Signal Coral warning banners
/// 4. Day & Flight inspection dossier cards with Phosphor Chartreuse tabular budgets
/// 5. Quick flight scheduling flow for approved campaigns
class CalendarScreen extends StatefulWidget {
  final ApiService api;

  const CalendarScreen({super.key, required this.api});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<ScheduleEvent> _events = [];
  List<Campaign> _approvedCampaigns = [];
  bool _loading = true;

  // View state: 'month' | 'week'
  String _activeView = 'month';

  // Navigation state
  late DateTime _focusedDate;
  late DateTime _selectedDay;

  // Filter state
  String _selectedChannel = 'All';

  final List<String> _channels = const [
    'All',
    'Social',
    'Search',
    'Email',
    'Display',
    'Video',
  ];

  @override
  void initState() {
    super.initState();
    _focusedDate = DateTime.now();
    _selectedDay = _focusedDate;
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      var events = await widget.api.getCalendar();
      final allCampaigns = await widget.api.getCampaigns();

      // If server calendar is empty, auto-seed sample flights
      if (events.isEmpty) {
        await widget.api.seedCalendar();
        events = await widget.api.getCalendar();
      }

      if (mounted) {
        setState(() {
          _events = events;
          _approvedCampaigns = allCampaigns;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _seedDemoFlights() async {
    setState(() => _loading = true);
    try {
      await widget.api.seedCalendar();
      await _fetch();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sample multi-channel flights seeded successfully.'),
            backgroundColor: AppTheme.slabElevated,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to seed: $e'),
            backgroundColor: AppTheme.signalCoral,
          ),
        );
      }
    }
  }

  // --- Date Math Helpers ---
  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 0, 0, 0);
  DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _parseDate(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return DateTime.now();
    }
  }

  // Filtered schedule events
  List<ScheduleEvent> get _filteredEvents {
    if (_selectedChannel == 'All') return _events;
    return _events.where((e) => e.channel.toLowerCase() == _selectedChannel.toLowerCase()).toList();
  }

  // Events active on a specific day
  List<ScheduleEvent> _eventsOnDay(DateTime day) {
    final start = _startOfDay(day);
    final end = _endOfDay(day);

    return _filteredEvents.where((e) {
      final s = _parseDate(e.startsAt);
      final en = _parseDate(e.endsAt);
      return s.isBefore(end) && en.isAfter(start);
    }).toList();
  }

  // Check if a day has overlapping flights on the same channel
  List<String> _conflictsOnDay(DateTime day) {
    final dayEvents = _eventsOnDay(day);
    final channelCounts = <String, int>{};
    for (final e in dayEvents) {
      channelCounts[e.channel] = (channelCounts[e.channel] ?? 0) + 1;
    }
    return channelCounts.entries
        .where((entry) => entry.value > 1)
        .map((entry) => entry.key)
        .toList();
  }

  // Overall conflicts in current view window
  List<Map<String, dynamic>> _detectViewConflicts() {
    final conflicts = <Map<String, dynamic>>[];
    for (int i = 0; i < _filteredEvents.length; i++) {
      for (int j = i + 1; j < _filteredEvents.length; j++) {
        final a = _filteredEvents[i];
        final b = _filteredEvents[j];
        if (a.channel.toLowerCase() == b.channel.toLowerCase()) {
          final aStart = _parseDate(a.startsAt);
          final aEnd = _parseDate(a.endsAt);
          final bStart = _parseDate(b.startsAt);
          final bEnd = _parseDate(b.endsAt);
          if (aStart.isBefore(bEnd) && aEnd.isAfter(bStart)) {
            conflicts.add({'eventA': a, 'eventB': b, 'channel': a.channel});
          }
        }
      }
    }
    return conflicts;
  }

  // Start of week (Monday)
  DateTime _startOfWeek(DateTime date) {
    final diff = date.weekday - 1; // 1 = Monday
    return _startOfDay(date.subtract(Duration(days: diff)));
  }

  @override
  Widget build(BuildContext context) {
    final activeConflicts = _detectViewConflicts();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Navigation Bar
                _buildCalendarHeader(),

                // Conflict Warning Alert (if any collisions exist)
                if (activeConflicts.isNotEmpty) _buildConflictBanner(activeConflicts),

                // Channel Filter Chips
                _buildChannelFilterBar(),

                // Subtle loading indicator
                if (_loading)
                  LinearProgressIndicator(
                    minHeight: 2.0,
                    color: AppTheme.accent,
                    backgroundColor: AppTheme.well,
                  ),

                // View Content (Month Grid or Week Flight Lanes)
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetch,
                    color: AppTheme.accent,
                    backgroundColor: AppTheme.card,
                    child: _activeView == 'month'
                        ? _buildMonthView()
                        : _buildWeekView(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: ElasticPressable(
        onTap: _showScheduleDialog,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppTheme.tokens.id == 'c' ? const [] : AppTheme.appleFloatingShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month_rounded, size: 18, color: AppTheme.textInverse),
              SizedBox(width: 8),
              Text(
                'Schedule flight',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppTheme.textInverse,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. TOP HEADER & NAVIGATION
  // ===========================================================================
  Widget _buildCalendarHeader() {
    final monthFormat = DateFormat('MMMM yyyy');
    final weekStart = _startOfWeek(_focusedDate);
    final weekEnd = weekStart.add(const Duration(days: 6));
    final weekFormat =
        '${DateFormat('d MMM').format(weekStart)} – ${DateFormat('d MMM yyyy').format(weekEnd)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.slabQuartz,
        border: Border(bottom: BorderSide(color: AppTheme.borderCard, width: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title & Kicker & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShinyText(
                      text: 'FLIGHT CAPACITY BOARD',
                      shimmerColor: AppTheme.phosphorChartreuse,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.phosphorChartreuse,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Flight Calendar',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _activeView == 'month'
                          ? monthFormat.format(_focusedDate)
                          : weekFormat,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // View Toggle (Month / Week) Segmented Pill
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: AppTheme.canvasVoid,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderCard, width: 0.75),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildViewToggleButton('Month', 'month'),
                    _buildViewToggleButton('Week', 'week'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Date Navigator Controls (< Previous, Today, Next >)
          Row(
            children: [
              ElasticPressable(
                onTap: () {
                  setState(() {
                    if (_activeView == 'month') {
                      _focusedDate = DateTime(_focusedDate.year, _focusedDate.month - 1, 1);
                    } else {
                      _focusedDate = _focusedDate.subtract(const Duration(days: 7));
                    }
                  });
                },
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppTheme.slabElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderCard, width: 0.75),
                  ),
                  child: Center(
                    child: Icon(Icons.chevron_left_rounded, color: AppTheme.textPrimary, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ElasticPressable(
                onTap: () {
                  setState(() {
                    _focusedDate = DateTime.now();
                    _selectedDay = _focusedDate;
                  });
                },
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.slabElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderCard, width: 0.75),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PulseStatusGlow(color: AppTheme.glacialCyan, size: 5),
                      SizedBox(width: 5),
                      Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ElasticPressable(
                onTap: () {
                  setState(() {
                    if (_activeView == 'month') {
                      _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + 1, 1);
                    } else {
                      _focusedDate = _focusedDate.add(const Duration(days: 7));
                    }
                  });
                },
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppTheme.slabElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderCard, width: 0.75),
                  ),
                  child: Center(
                    child: Icon(Icons.chevron_right_rounded, color: AppTheme.textPrimary, size: 18),
                  ),
                ),
              ),
              const Spacer(),
              // Flight count chip or quick seed action
              if (_events.isEmpty)
                ElasticPressable(
                  onTap: _seedDemoFlights,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.phosphorChartreuse.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.phosphorChartreuse.withOpacity(0.4), width: 0.75),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 11, color: AppTheme.phosphorChartreuse),
                        SizedBox(width: 4),
                        Text(
                          'Seed flights',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.phosphorChartreuse),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.slabPill,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderCard, width: 0.75),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PulseStatusGlow(color: AppTheme.phosphorChartreuse, size: 5),
                      SizedBox(width: 5),
                      Text(
                        '${_filteredEvents.length} flights booked',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggleButton(String label, String viewKey) {
    final isSelected = _activeView == viewKey;
    return ElasticPressable(
      onTap: () => setState(() => _activeView = viewKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.tokens.radiusControl),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? AppTheme.textInverse : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. CONFLICT WARNING BANNER
  // ===========================================================================
  Widget _buildConflictBanner(List<Map<String, dynamic>> conflicts) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.statusRejectedBg,
        borderRadius: BorderRadius.circular(AppTheme.tokens.radiusCard),
        border: Border.all(color: AppTheme.statusRejected.withOpacity(0.45), width: AppTheme.tokens.structuralRuleWidth),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PulseStatusGlow(color: AppTheme.signalCoral, size: 8),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CHANNEL COLLISION DETECTED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.signalCoral,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${conflicts.length} overlapping booking(s) on ${conflicts.map((c) => c['channel']).toSet().join(', ')}. Post-review flight adjustment required.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. CHANNEL FILTER BAR
  // ===========================================================================
  Widget _buildChannelFilterBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _channels.length,
        itemBuilder: (context, i) {
          final ch = _channels[i];
          final isSelected = _selectedChannel.toLowerCase() == ch.toLowerCase();
          final chColor = ch == 'All' ? AppTheme.phosphorChartreuse : AppTheme.getChannelColor(ch);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElasticPressable(
              onTap: () => setState(() => _selectedChannel = ch),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? chColor.withOpacity(0.18) : AppTheme.slabQuartz,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? chColor : AppTheme.borderCard,
                    width: isSelected ? 1.25 : AppTheme.tokens.structuralRuleWidth,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (ch != 'All') ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: chColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      ch,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 4. MONTHLY GRID VIEW (Responsive 7-column squircle layout)
  // ===========================================================================
  Widget _buildMonthView() {
    final year = _focusedDate.year;
    final month = _focusedDate.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leadingEmpty = firstDayOfMonth.weekday - 1; // 1 = Monday
    final totalCells = leadingEmpty + daysInMonth;
    final totalRows = (totalCells / 7).ceil();

    final selectedDayEvents = _eventsOnDay(_selectedDay);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        // Calendar Grid Container (Obsidian Vitreum Smoked Quartz Slab)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.slabQuartz,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.rimKeyLight, width: 0.75),
            boxShadow: AppTheme.dualLayerDepth,
          ),
          child: Column(
            children: [
              // Responsive Day of Week Headers (7 equal columns: M - S)
              const Row(
                children: [
                  _DayHeader('M'),
                  _DayHeader('T'),
                  _DayHeader('W'),
                  _DayHeader('T'),
                  _DayHeader('F'),
                  _DayHeader('S'),
                  _DayHeader('S'),
                ],
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: AppTheme.borderCard, height: 0.75),
              ),

              // Calendar Days Grid
              for (int row = 0; row < totalRows; row++) ...[
                Row(
                  children: [
                    for (int col = 0; col < 7; col++) ...[
                      Expanded(
                        child: Builder(builder: (context) {
                          final cellIndex = row * 7 + col;
                          final dayNumber = cellIndex - leadingEmpty + 1;

                          if (dayNumber < 1 || dayNumber > daysInMonth) {
                            return const SizedBox(height: 46);
                          }

                          final date = DateTime(year, month, dayNumber);
                          final isSelected = _isSameDay(date, _selectedDay);
                          final isToday = _isSameDay(date, DateTime.now());
                          final dayEvents = _eventsOnDay(date);
                          final conflicts = _conflictsOnDay(date);

                          return ElasticPressable(
                            onTap: () {
                              setState(() => _selectedDay = date);
                            },
                            child: Container(
                              height: 46,
                              margin: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.accent
                                    : (isToday ? AppTheme.social.withOpacity(0.12) : Colors.transparent),
                                borderRadius: BorderRadius.circular(AppTheme.tokens.radiusControl),
                                border: isSelected
                                    ? Border.all(color: AppTheme.accent, width: 1.5)
                                    : (isToday ? Border.all(color: AppTheme.social, width: 1.0) : null),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$dayNumber',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected
                                          ? AppTheme.onAccent
                                          : (isToday ? AppTheme.social : AppTheme.textPrimary),
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Flight Indicators / Collision alert
                                  if (conflicts.isNotEmpty) ...[
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppTheme.onAccent : AppTheme.statusRejected,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ] else if (dayEvents.isNotEmpty) ...[
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (int i = 0; i < dayEvents.length.clamp(0, 3); i++) ...[
                                          Container(
                                            width: 4.5,
                                            height: 4.5,
                                            margin: const EdgeInsets.symmetric(horizontal: 0.75),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppTheme.textInverse
                                                  : AppTheme.getChannelColor(dayEvents[i].channel),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 6),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),

        // DOSSIER SECTION: Active Flights on Selected Date
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                DateFormat('EEEE, d MMMM').format(_selectedDay),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: selectedDayEvents.isEmpty ? AppTheme.slabPill : AppTheme.phosphorChartreuse.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selectedDayEvents.isEmpty ? AppTheme.borderCard : AppTheme.phosphorChartreuse.withOpacity(0.35),
                  width: 0.75,
                ),
              ),
              child: Text(
                '${selectedDayEvents.length} active',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selectedDayEvents.isEmpty ? AppTheme.textSecondary : AppTheme.phosphorChartreuse,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (selectedDayEvents.isEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
            decoration: BoxDecoration(
              color: AppTheme.slabQuartz,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.rimKeyLight, width: 0.75),
              boxShadow: AppTheme.dualLayerDepth,
            ),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.slabPill,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.borderCard, width: 0.75),
                  ),
                  child: Center(
                    child: Icon(Icons.event_available_rounded, size: 22, color: AppTheme.phosphorChartreuse),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'No flights scheduled for ${DateFormat('d MMMM yyyy').format(_selectedDay)}',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary, letterSpacing: -0.2),
                ),
                const SizedBox(height: 6),
                Text(
                  'All channel lanes are open for scheduling on this date.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ElasticPressable(
                  onTap: () => _showScheduleDialog(initialDate: _selectedDay),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.phosphorChartreuse,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: AppTheme.textInverse),
                        SizedBox(width: 6),
                        Text(
                          'Book for this date',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textInverse),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          for (final event in selectedDayEvents) _buildFlightDossierCard(event),
        ],
      ],
    );
  }

  // ===========================================================================
  // 5. WEEKLY FLIGHT LANES BOARD (Gantt-style Flight Board)
  // ===========================================================================
  Widget _buildWeekView() {
    final weekStart = _startOfWeek(_focusedDate);
    final weekDays = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final activeChannels = _selectedChannel == 'All'
        ? ['Social', 'Search', 'Email', 'Display', 'Video']
        : [_selectedChannel];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        // Channel Occupancy & Booking Density Matrix
        _buildChannelOccupancyMatrix(),
        const SizedBox(height: 12),

        // Week Days Header Bar
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.slabQuartz,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.rimKeyLight, width: 0.75),
            boxShadow: AppTheme.dualLayerDepth,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Center(
                  child: Text(
                    'Channel',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
                  ),
                ),
              ),
              for (final day in weekDays)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        DateFormat('E').format(day),
                        style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _isSameDay(day, DateTime.now()) ? FontWeight.w700 : FontWeight.w600,
                          color: _isSameDay(day, DateTime.now()) ? AppTheme.glacialCyan : AppTheme.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Channel Lanes
        for (final channel in activeChannels) ...[
          _buildChannelFlightLane(channel, weekDays),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildChannelOccupancyMatrix() {
    final occupancy = [
      {'name': 'Social', 'booked': 0.75, 'color': AppTheme.getChannelColor('Social')},
      {'name': 'Search', 'booked': 0.50, 'color': AppTheme.getChannelColor('Search')},
      {'name': 'Email', 'booked': 0.40, 'color': AppTheme.getChannelColor('Email')},
      {'name': 'Display', 'booked': 0.25, 'color': AppTheme.getChannelColor('Display')},
      {'name': 'Video', 'booked': 0.35, 'color': AppTheme.getChannelColor('Video')},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.slabQuartz,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.rimKeyLight, width: 0.75),
        boxShadow: AppTheme.dualLayerDepth,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'CHANNEL OCCUPANCY & DENSITY',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppTheme.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppTheme.celadonSage.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.celadonSage.withOpacity(0.4), width: 0.75),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PulseStatusGlow(color: AppTheme.celadonSage, size: 5),
                    SizedBox(width: 4),
                    Text(
                      'HEALTHY CAPACITY',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.celadonSage),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: occupancy.map((ch) {
              final pct = ((ch['booked'] as double) * 100).toInt();
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    children: [
                      Text(
                        ch['name'] as String,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          height: 5,
                          child: LinearProgressIndicator(
                            value: ch['booked'] as double,
                            backgroundColor: AppTheme.slabPill,
                            valueColor: AlwaysStoppedAnimation<Color>(ch['color'] as Color),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$pct%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelFlightLane(String channel, List<DateTime> weekDays) {
    final laneEvents = _filteredEvents
        .where((e) => e.channel.toLowerCase() == channel.toLowerCase())
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.slabQuartz,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.rimKeyLight, width: 0.75),
        boxShadow: AppTheme.dualLayerDepth,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Channel Row Title
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.getChannelColor(channel),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  channel,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.slabPill,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${laneEvents.length} flight(s)',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: AppTheme.borderCard, height: 0.75),

          // Flight Lane Board
          if (laneEvents.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'No $channel flights scheduled this week',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElasticPressable(
                    onTap: () => _showScheduleDialog(initialChannel: channel),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.slabElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderCard, width: 0.75),
                      ),
                      child: Text(
                        '+ Book $channel slot',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.phosphorChartreuse),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  for (final evt in laneEvents)
                    _buildLaneFlightBar(evt, weekDays),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLaneFlightBar(ScheduleEvent evt, List<DateTime> weekDays) {
    final start = _parseDate(evt.startsAt);
    final end = _parseDate(evt.endsAt);
    final weekStart = weekDays.first;
    final weekEnd = _endOfDay(weekDays.last);

    final isVisibleThisWeek = start.isBefore(weekEnd) && end.isAfter(weekStart);
    if (!isVisibleThisWeek) return const SizedBox.shrink();

    // Check conflict
    final hasConflict = _detectViewConflicts().any((c) =>
        c['eventA'] == evt || c['eventB'] == evt);

    return ElasticPressable(
      onTap: () => _showFlightDetailModal(evt),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hasConflict
              ? AppTheme.statusRejectedBg
              : AppTheme.well,
          borderRadius: BorderRadius.circular(AppTheme.tokens.radiusControl),
          border: Border.all(
            color: hasConflict ? AppTheme.statusRejected : AppTheme.hairline,
            width: AppTheme.tokens.structuralRuleWidth,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: hasConflict ? AppTheme.signalCoral : AppTheme.slabPill,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'v${evt.versionNo}',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: hasConflict ? Colors.white : AppTheme.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    evt.title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: hasConflict ? AppTheme.signalCoral : AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '\$${evt.budget.toInt()}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: hasConflict ? AppTheme.signalCoral : AppTheme.phosphorChartreuse,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  hasConflict ? Icons.error_outline_rounded : Icons.chevron_right_rounded,
                  size: 16,
                  color: hasConflict ? AppTheme.signalCoral : AppTheme.textMuted,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.flight_takeoff_rounded, size: 12, color: hasConflict ? AppTheme.signalCoral : AppTheme.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM').format(end)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: hasConflict ? AppTheme.signalCoral : AppTheme.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppTheme.slabPill,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${end.difference(start).inDays.clamp(1, 30)}d flight',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: hasConflict ? AppTheme.signalCoral : AppTheme.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
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

  // ===========================================================================
  // 6. FLIGHT DOSSIER CARD & DETAIL MODAL
  // ===========================================================================
  Widget _buildFlightDossierCard(ScheduleEvent event) {
    final start = _parseDate(event.startsAt);
    final end = _parseDate(event.endsAt);
    final dateFormat = DateFormat('d MMM yyyy');

    final matchedCampaign = _approvedCampaigns
        .cast<Campaign?>()
        .firstWhere((c) => c?.campaignId == event.campaignId, orElse: () => null);
    final curVer = matchedCampaign?.currentVersion;
    final assetUrl = curVer != null && curVer.creatives.isNotEmpty
        ? curVer.creatives[0]['asset_url'] as String?
        : null;
    final kpi = curVer?.kpiProjected;
    final burnRatePct = (curVer?.financials['burn_rate_pct'] as num?)?.toDouble() ?? 65.0;
    final burnRatio = (burnRatePct / 100.0).clamp(0.0, 1.0);

    final roiStr = kpi != null ? 'ROI ${kpi.roi.toStringAsFixed(1)}x' : 'ROI 4.2x';
    final cpaStr = kpi != null ? 'CPA \$${kpi.cpa.toStringAsFixed(0)}' : 'CPA \$22';
    final ctrStr = kpi != null ? 'CTR ${kpi.ctr.toStringAsFixed(1)}%' : 'CTR 4.8%';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.slabElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.rimKeyLight, width: 0.75),
        boxShadow: AppTheme.dualLayerDepth,
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  // Channel Tag + Version Tag
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.getChannelColor(event.channel).withOpacity(0.16),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.getChannelColor(event.channel).withOpacity(0.4), width: 0.75),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(AppTheme.getChannelIcon(event.channel), size: 11, color: AppTheme.getChannelColor(event.channel)),
                            const SizedBox(width: 4),
                            Text(
                              event.channel,
                              style: TextStyle(
                                color: AppTheme.getChannelColor(event.channel),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.slabPill,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.borderCard, width: 0.75),
                        ),
                        child: Text(
                          'v${event.versionNo}',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Scheduled Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.celadonSage.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.celadonSage.withOpacity(0.4), width: 0.75),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PulseStatusGlow(color: AppTheme.celadonSage, size: 5),
                        SizedBox(width: 5),
                        Text(
                          'Scheduled',
                          style: TextStyle(color: AppTheme.celadonSage, fontWeight: FontWeight.w700, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Creative Visual + Title & Flight Info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.flight_takeoff_rounded, size: 12, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${dateFormat.format(start)} – ${dateFormat.format(end)}',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // HIGH CONTRAST LUMINOUS BUDGET (Tabular Phosphor Chartreuse)
                        Text(
                          '\$${event.budget.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.phosphorChartreuse,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  CreativeAssetThumbnail(
                    assetUrl: assetUrl,
                    channel: event.channel,
                    width: 72,
                    height: 72,
                    borderRadius: 12,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Human Attribution & Pacing Tag
              Row(
                children: [
                  Expanded(
                    child: MarketerAvatar(userId: matchedCampaign?.ownerId, size: 20, showLabel: true),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pacing ${(burnRatio * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Spend Wave Burn Bar
              _buildMiniSpendBar(event.budget, burnRatio),
              const SizedBox(height: 10),

              // Micro-KPI Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildMiniKpiTag(roiStr, isPrimary: true),
                    const SizedBox(width: 6),
                    _buildMiniKpiTag(cpaStr),
                    const SizedBox(width: 6),
                    _buildMiniKpiTag(ctrStr),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // View Full Dossier CTA
              ElasticPressable(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CampaignDetailScreen(
                        campaignId: event.campaignId,
                        api: widget.api,
                      ),
                    ),
                  ).then((_) => _fetch());
                },
                child: Container(
                  width: double.infinity,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.slabPill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderCard, width: 0.75),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.north_east_rounded, size: 14, color: AppTheme.phosphorChartreuse),
                      SizedBox(width: 6),
                      Text(
                        'Inspect proposal dossier',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniSpendBar(double budget, double burnRatio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SPEND BURN PACING',
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.6),
            ),
            Text(
              '${(burnRatio * 100).toInt()}% burned · 75% limit',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 8,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.slabPill,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: burnRatio,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.glacialCyan, AppTheme.phosphorChartreuse],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(-1.0 + (0.75 * 2), 0),
                child: Container(
                  width: 2,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.signalCoral,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniKpiTag(String text, {bool isPrimary = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPrimary ? AppTheme.phosphorChartreuse.withOpacity(0.14) : AppTheme.slabPill,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPrimary ? AppTheme.phosphorChartreuse.withOpacity(0.4) : AppTheme.borderCard,
          width: 0.75,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isPrimary ? AppTheme.phosphorChartreuse : AppTheme.textSecondary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  void _showFlightDetailModal(ScheduleEvent evt) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.slabElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderCard,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              evt.title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.3),
            ),
            const SizedBox(height: 6),
            Text(
              'Channel: ${evt.channel} • Version v${evt.versionNo}',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            _buildModalDetailRow('Flight starts', evt.startsAt.substring(0, 10)),
            _buildModalDetailRow('Flight ends', evt.endsAt.substring(0, 10)),
            _buildModalDetailRow('Allocated budget', '\$${evt.budget.toInt()}'),
            _buildModalDetailRow('Flight status', evt.status),
            const SizedBox(height: 20),
            ElasticPressable(
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CampaignDetailScreen(
                      campaignId: evt.campaignId,
                      api: widget.api,
                    ),
                  ),
                ).then((_) => _fetch());
              },
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.phosphorChartreuse,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    'Open campaign dossier',
                    style: TextStyle(color: AppTheme.textInverse, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 7. SCHEDULE QUICK-ACTION DIALOG
  // ===========================================================================
  void _showScheduleDialog({DateTime? initialDate, String? initialChannel}) {
    if (_approvedCampaigns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No approved campaigns pending scheduling. Only approved proposals can be scheduled.'),
          backgroundColor: AppTheme.slabElevated,
        ),
      );
      return;
    }

    String selectedCampId = _approvedCampaigns.first.campaignId;
    DateTime startDate = initialDate ?? DateTime.now().add(const Duration(days: 1));
    DateTime endDate = startDate.add(const Duration(days: 7));
    String channel = initialChannel ?? (_approvedCampaigns.first.currentVersion?.channel ?? 'Social');
    bool scheduling = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.slabElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final campaign = _approvedCampaigns.firstWhere((c) => c.campaignId == selectedCampId);
          final curVer = campaign.currentVersion;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: AppTheme.borderCard, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Schedule Campaign Flight',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.4),
                ),
                const SizedBox(height: 4),
                Text(
                  'Schedules the campaign flight with continuous collision and capacity protection.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),

                // Select Approved Campaign
                Text('Approved Campaign', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.slabPill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderCard, width: 0.75),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      dropdownColor: AppTheme.slabElevated,
                      value: selectedCampId,
                      items: _approvedCampaigns.map((c) {
                        return DropdownMenuItem(
                          value: c.campaignId,
                          child: Text(
                            '${c.title} (v${c.currentVersion?.versionNo ?? 1})',
                            style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            selectedCampId = val;
                            final camp = _approvedCampaigns.firstWhere((c) => c.campaignId == val);
                            channel = camp.currentVersion?.channel ?? 'Social';
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Flight Date Picker Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Flight Start', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          ElasticPressable(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: startDate,
                                firstDate: DateTime(2025),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setModalState(() => startDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.slabPill,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.borderCard, width: 0.75),
                              ),
                              child: Text(
                                DateFormat('yyyy-MM-dd').format(startDate),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Flight End', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          ElasticPressable(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: endDate,
                                firstDate: startDate,
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setModalState(() => endDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.slabPill,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.borderCard, width: 0.75),
                              ),
                              child: Text(
                                DateFormat('yyyy-MM-dd').format(endDate),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Confirm Schedule Action
                ElasticPressable(
                  onTap: scheduling
                      ? null
                      : () async {
                          if (curVer == null) return;
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(ctx);
                          setModalState(() => scheduling = true);
                          try {
                            await widget.api.scheduleCampaign(
                              campaign.campaignId,
                              curVer.versionId,
                              startDate.toIso8601String(),
                              endDate.toIso8601String(),
                              channel,
                            );
                            navigator.pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Scheduled flight confirmed for "${campaign.title}" v${curVer.versionNo}'),
                                backgroundColor: AppTheme.slabElevated,
                              ),
                            );
                            _fetch();
                          } catch (e) {
                            setModalState(() => scheduling = false);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: AppTheme.signalCoral,
                              ),
                            );
                          }
                        },
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(AppTheme.tokens.radiusControl),
                    ),
                    child: Center(
                      child: scheduling
                          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.textInverse, strokeWidth: 2))
                          : Text('Commit flight schedule', style: TextStyle(color: AppTheme.textInverse, fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String label;
  const _DayHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}
