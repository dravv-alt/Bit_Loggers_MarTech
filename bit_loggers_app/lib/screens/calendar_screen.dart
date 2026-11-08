import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'campaign_detail_screen.dart';

/// FR-08: Internal Campaign Calendar
/// Interactive Visual Flight Board with:
/// 1. Monthly Grid View with multi-channel flight pills & conflict dots
/// 2. Weekly Flight Lanes Board (Gantt-style channel lanes)
/// 3. Conflict Detection Engine (409 SCHEDULING_CONFLICT identification)
/// 4. Day & Flight inspection dossier drawer
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
      final allCampaigns = await widget.api.getCampaigns(status: 'Approved');

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
          const SnackBar(
            content: Text('Sample multi-channel flights seeded successfully.'),
            backgroundColor: AppTheme.forge,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to seed: $e'), backgroundColor: AppTheme.statusRejected),
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
      backgroundColor: AppTheme.paper,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Navigation Bar
            _buildCalendarHeader(),

            // Conflict Warning Alert (if any collisions exist)
            if (activeConflicts.isNotEmpty) _buildConflictBanner(activeConflicts),

            // Channel Filter Chips
            _buildChannelFilterBar(),

            // Subtle loading indicator (preserves calendar interface at all times)
            if (_loading)
              const LinearProgressIndicator(
                minHeight: 2.5,
                color: AppTheme.forge,
                backgroundColor: AppTheme.borderSage,
              ),

            // View Content (Month Grid or Week Flight Lanes)
            // THE CALENDAR INTERFACE IS ALWAYS VISIBLE AT ALL TIMES
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetch,
                color: AppTheme.forge,
                child: _activeView == 'month'
                    ? _buildMonthView()
                    : _buildWeekView(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showScheduleDialog,
        backgroundColor: AppTheme.forge,
        foregroundColor: AppTheme.leaf,
        icon: const Icon(Icons.calendar_month, size: 18),
        label: const Text(
          'Schedule flight',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        color: AppTheme.paper,
        border: Border(bottom: BorderSide(color: AppTheme.borderSage, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Flight Calendar',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _activeView == 'month'
                          ? monthFormat.format(_focusedDate)
                          : weekFormat,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // View Toggle (Month / Week)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppTheme.leaf,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.borderSage, width: 1),
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
          const SizedBox(height: 12),

          // Date Navigator Controls (< Previous, Today, Next >)
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.chevron_left, color: AppTheme.forge, size: 22),
                tooltip: 'Previous',
                onPressed: () {
                  setState(() {
                    if (_activeView == 'month') {
                      _focusedDate = DateTime(_focusedDate.year, _focusedDate.month - 1, 1);
                    } else {
                      _focusedDate = _focusedDate.subtract(const Duration(days: 7));
                    }
                  });
                },
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  setState(() {
                    _focusedDate = DateTime.now();
                    _selectedDay = _focusedDate;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.paper,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderSage),
                  ),
                  child: const Text(
                    'Today',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.forge),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.chevron_right, color: AppTheme.forge, size: 22),
                tooltip: 'Next',
                onPressed: () {
                  setState(() {
                    if (_activeView == 'month') {
                      _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + 1, 1);
                    } else {
                      _focusedDate = _focusedDate.add(const Duration(days: 7));
                    }
                  });
                },
              ),
              const Spacer(),
              // Flight count chip or quick seed action
              if (_events.isEmpty)
                InkWell(
                  onTap: _seedDemoFlights,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.forge,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 12, color: AppTheme.leaf),
                        SizedBox(width: 4),
                        Text(
                          'Seed flights',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.leaf),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.forge.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_filteredEvents.length} flights',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.forge),
                    ),
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
    return GestureDetector(
      onTap: () => setState(() => _activeView = viewKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.forge : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? AppTheme.leaf : AppTheme.textSecondary,
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
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.statusRejected.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.statusRejected, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: AppTheme.statusRejected),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Channel Collision Detected',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.statusRejected,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${conflicts.length} overlapping booking(s) found on ${conflicts.map((c) => c['channel']).toSet().join(', ')}. Post-review flight adjustment required.',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary, height: 1.25),
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
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _channels.length,
        itemBuilder: (context, i) {
          final ch = _channels[i];
          final isSelected = _selectedChannel.toLowerCase() == ch.toLowerCase();

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(ch),
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.leaf : AppTheme.textPrimary,
              ),
              selected: isSelected,
              selectedColor: AppTheme.forge,
              backgroundColor: AppTheme.leaf,
              side: const BorderSide(color: AppTheme.borderSage, width: 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (_) {
                setState(() => _selectedChannel = ch);
              },
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 4. MONTHLY GRID VIEW
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      children: [
        // Calendar Grid Container (Leaf Card with sage border)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.leaf,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderSage, width: 1),
          ),
          child: Column(
            children: [
              // Day of Week Headers
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Divider(color: AppTheme.borderSage, height: 1),
              ),

              // Calendar Days Grid
              for (int row = 0; row < totalRows; row++) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (int col = 0; col < 7; col++) ...[
                      Builder(builder: (context) {
                        final cellIndex = row * 7 + col;
                        final dayNumber = cellIndex - leadingEmpty + 1;

                        if (dayNumber < 1 || dayNumber > daysInMonth) {
                          return const SizedBox(width: 40, height: 46);
                        }

                        final date = DateTime(year, month, dayNumber);
                        final isSelected = _isSameDay(date, _selectedDay);
                        final isToday = _isSameDay(date, DateTime.now());
                        final dayEvents = _eventsOnDay(date);
                        final conflicts = _conflictsOnDay(date);

                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedDay = date);
                          },
                          child: Container(
                            width: 40,
                            height: 48,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.forge
                                  : (isToday ? AppTheme.verdictLime.withOpacity(0.3) : Colors.transparent),
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? Border.all(color: AppTheme.verdictLime, width: 1.5)
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$dayNumber',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected
                                        ? AppTheme.leaf
                                        : (isToday ? AppTheme.forge : AppTheme.textPrimary),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                // Flight Indicators / Collision alert
                                if (conflicts.isNotEmpty) ...[
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.statusRejected,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ] else if (dayEvents.isNotEmpty) ...[
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (int i = 0; i < dayEvents.length.clamp(0, 3); i++) ...[
                                        Container(
                                          width: 4,
                                          height: 4,
                                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppTheme.verdictLime
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
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // DOSSIER SECTION: Active Flights on Selected Date
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                DateFormat('EEEE, d MMMM').format(_selectedDay),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${selectedDayEvents.length} active',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (selectedDayEvents.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.leaf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderSage, width: 1),
            ),
            child: Column(
              children: [
                const Icon(Icons.event_available_outlined, size: 36, color: AppTheme.textSecondary),
                const SizedBox(height: 8),
                Text(
                  'No flights scheduled for ${DateFormat('d MMMM yyyy').format(_selectedDay)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'All channel lanes are open for scheduling on this date.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppTheme.leaf,
                        foregroundColor: AppTheme.forge,
                        side: const BorderSide(color: AppTheme.borderSage),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.add, size: 14, color: AppTheme.forge),
                      label: const Text('Book for this date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.forge)),
                      onPressed: () => _showScheduleDialog(initialDate: _selectedDay),
                    ),
                    if (_events.isEmpty)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFF0F4FF),
                          foregroundColor: AppTheme.brandAccent,
                          side: const BorderSide(color: Color(0xFFCCD9F5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.auto_awesome, size: 14, color: AppTheme.brandAccent),
                        label: const Text(
                          'Seed Sample Flights',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.brandAccent),
                        ),
                        onPressed: _seedDemoFlights,
                      ),
                  ],
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      children: [
        // Channel Occupancy & Booking Density Matrix (.pg7 Alignment)
        _buildChannelOccupancyMatrix(),
        const SizedBox(height: 12),

        // Week Days Header Bar
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.leaf,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderSage, width: 1),
          ),
          child: Row(
            children: [
              const SizedBox(width: 80, child: Center(child: Text('Channel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)))),
              for (final day in weekDays)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        DateFormat('E').format(day),
                        style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _isSameDay(day, DateTime.now()) ? FontWeight.bold : FontWeight.w600,
                          color: _isSameDay(day, DateTime.now()) ? AppTheme.forge : AppTheme.textPrimary,
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
      {'name': 'Social', 'booked': 0.75, 'color': const Color(0xFF2D55A2)},
      {'name': 'Search', 'booked': 0.50, 'color': const Color(0xFF476044)},
      {'name': 'Email', 'booked': 0.40, 'color': const Color(0xFF234C82)},
      {'name': 'Display', 'booked': 0.25, 'color': const Color(0xFF5B6941)},
      {'name': 'Video', 'booked': 0.35, 'color': const Color(0xFF384F45)},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSage, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'CHANNEL OCCUPANCY & DENSITY (.PG7)',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.1, color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4EA),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'HEALTHY CAPACITY',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF137333)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          height: 5,
                          child: LinearProgressIndicator(
                            value: ch['booked'] as double,
                            backgroundColor: AppTheme.paper,
                            valueColor: AlwaysStoppedAnimation<Color>(ch['color'] as Color),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$pct%',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFeatures: [FontFeature.tabularFigures()]),
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
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSage, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Channel Row Title
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
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
                const SizedBox(width: 6),
                Text(
                  channel,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                ),
                const Spacer(),
                Text(
                  '${laneEvents.length} flight(s)',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.borderSage, height: 1),

          // Flight Lane Board
          if (laneEvents.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'No $channel flights this week',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showScheduleDialog(initialChannel: channel),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.paper,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.borderSage),
                      ),
                      child: Text(
                        '+ Book $channel slot',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.forge),
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

    return InkWell(
      onTap: () => _showFlightDetailModal(evt),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: hasConflict
              ? AppTheme.statusRejected.withOpacity(0.12)
              : AppTheme.forge,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasConflict ? AppTheme.statusRejected : AppTheme.forge,
            width: 1,
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
                    color: hasConflict ? AppTheme.statusRejected : AppTheme.verdictLime,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'v${evt.versionNo}',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: hasConflict ? AppTheme.leaf : AppTheme.forge,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    evt.title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: hasConflict ? AppTheme.statusRejected : AppTheme.leaf,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '\$${evt.budget.toInt()}',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: hasConflict ? AppTheme.statusRejected : AppTheme.leaf,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  hasConflict ? Icons.error_outline : Icons.chevron_right,
                  size: 14,
                  color: hasConflict ? AppTheme.statusRejected : AppTheme.textInverseMuted,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.flight_takeoff, size: 11, color: hasConflict ? AppTheme.statusRejected : AppTheme.textInverseMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM').format(end)}',
                    style: TextStyle(fontSize: 10, color: hasConflict ? AppTheme.statusRejected : AppTheme.textInverseMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '${end.difference(start).inDays.clamp(1, 30)}d flight',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: hasConflict ? AppTheme.statusRejected : AppTheme.leaf),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderSage, width: 1),
      ),
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
                      color: AppTheme.getChannelColor(event.channel).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      event.channel,
                      style: TextStyle(
                        color: AppTheme.getChannelColor(event.channel),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.forge.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Version v${event.versionNo}',
                      style: const TextStyle(color: AppTheme.forge, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),

              // Scheduled Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.verdictLime.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 12, color: AppTheme.forge),
                    SizedBox(width: 4),
                    Text(
                      'Scheduled',
                      style: TextStyle(color: AppTheme.forge, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Campaign Title
          Text(
            event.title,
            style: const TextStyle(
              fontFamily: 'serif',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),

          // Flight Span & Budget
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${dateFormat.format(start)} → ${dateFormat.format(end)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '\$${event.budget.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.forge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Spend Wave Burn Bar
          _buildMiniSpendBar(event.budget, 0.65),
          const SizedBox(height: 8),

          // Micro-KPI Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMiniKpiTag('ROI 4.2x', isPrimary: true),
                const SizedBox(width: 6),
                _buildMiniKpiTag('CPA \$21.50'),
                const SizedBox(width: 6),
                _buildMiniKpiTag('CTR 4.8%'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // View Full Dossier CTA
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
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
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.borderSage),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.north_east, size: 13, color: AppTheme.forge),
              label: const Text(
                'Inspect proposal dossier',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: AppTheme.forge, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
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
            const Expanded(
              child: Text(
                'SPEND BURN PACING',
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.1),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${(burnRatio * 100).toInt()}% burned · 75% ceiling',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 10,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.paper,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: burnRatio,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.forge,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(-0.5 + (0.75 * 2) - 1.0, 0),
                child: Container(
                  width: 1.5,
                  height: 10,
                  color: const Color(0xFFB9301D),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isPrimary ? AppTheme.forge : AppTheme.paper,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isPrimary ? AppTheme.forge : AppTheme.borderSage, width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: isPrimary ? AppTheme.leaf : AppTheme.textPrimary,
        ),
      ),
    );
  }

  void _showFlightDetailModal(ScheduleEvent evt) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.leaf,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderSage,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              evt.title,
              style: const TextStyle(fontFamily: 'serif', fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Channel: ${evt.channel} • Version v${evt.versionNo}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            _buildModalDetailRow('Flight starts', evt.startsAt.substring(0, 10)),
            _buildModalDetailRow('Flight ends', evt.endsAt.substring(0, 10)),
            _buildModalDetailRow('Allocated budget', '\$${evt.budget.toInt()}'),
            _buildModalDetailRow('Flight status', evt.status),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.forge,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Open campaign dossier', style: TextStyle(color: AppTheme.leaf, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
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
        const SnackBar(
          content: Text('No approved campaigns pending scheduling. Only approved proposals can be scheduled.'),
          backgroundColor: AppTheme.forge,
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
      backgroundColor: AppTheme.leaf,
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
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: AppTheme.borderSage, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Schedule Campaign Flight',
                  style: TextStyle(fontFamily: 'serif', fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Validates exact approved current version in PostgreSQL transaction.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),

                // Select Approved Campaign
                const Text('Approved Campaign', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.paper,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderSage),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedCampId,
                      items: _approvedCampaigns.map((c) {
                        return DropdownMenuItem(
                          value: c.campaignId,
                          child: Text('${c.title} (v${c.currentVersion?.versionNo ?? 1})', style: const TextStyle(fontSize: 13)),
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
                          const Text('Flight Start', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          InkWell(
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
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.paper,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.borderSage),
                              ),
                              child: Text(DateFormat('yyyy-MM-dd').format(startDate), style: const TextStyle(fontSize: 12)),
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
                          const Text('Flight End', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          InkWell(
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
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.paper,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.borderSage),
                              ),
                              child: Text(DateFormat('yyyy-MM-dd').format(endDate), style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Confirm Schedule Action
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: scheduling
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
                                  backgroundColor: AppTheme.forge,
                                ),
                              );
                              _fetch();
                            } catch (e) {
                              setModalState(() => scheduling = false);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: AppTheme.statusRejected,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.forge,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: scheduling
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.leaf, strokeWidth: 2))
                        : const Text('Commit flight schedule', style: TextStyle(color: AppTheme.leaf, fontWeight: FontWeight.bold)),
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
    return SizedBox(
      width: 40,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
