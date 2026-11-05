import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bit_loggers_app/screens/calendar_screen.dart';
import 'package:bit_loggers_app/services/api_service.dart';
import 'package:bit_loggers_app/models/models.dart';
import 'package:bit_loggers_app/theme/app_theme.dart';

class MockCalendarApiService extends ApiService {
  List<ScheduleEvent> events = [];
  bool seedCalled = false;

  MockCalendarApiService({List<ScheduleEvent>? initialEvents}) {
    if (initialEvents != null) {
      events = List.from(initialEvents);
    }
  }

  @override
  Future<List<ScheduleEvent>> getCalendar({String? start, String? end, String? channel}) async {
    return List.from(events);
  }

  @override
  Future<List<Campaign>> getCampaigns({String? status, String? channel}) async {
    return [
      Campaign(
        campaignId: 'camp-seed-1',
        title: 'Approved Launch Campaign',
        ownerId: 'usr-1',
        ownerName: 'Alex Marketer',
        status: 'Approved',
        currentVersionId: 'ver-seed-1',
        createdAt: '2026-11-01T00:00:00Z',
        updatedAt: '2026-11-01T00:00:00Z',
      ),
    ];
  }

  @override
  Future<Map<String, dynamic>> seedCalendar() async {
    seedCalled = true;
    final now = DateTime.now();
    events = [
      ScheduleEvent(
        scheduleId: 'sch-1',
        campaignId: 'camp-seed-1',
        title: 'Q4 Festive Creator Blitz',
        channel: 'Social',
        versionNo: 1,
        budget: 28000.0,
        startsAt: now.subtract(const Duration(days: 1)).toIso8601String(),
        endsAt: now.add(const Duration(days: 3)).toIso8601String(),
        status: 'SCHEDULED',
      ),
      ScheduleEvent(
        scheduleId: 'sch-2',
        campaignId: 'camp-seed-2',
        title: 'High-Intent Search Surge',
        channel: 'Search',
        versionNo: 1,
        budget: 36000.0,
        startsAt: now.toIso8601String(),
        endsAt: now.add(const Duration(days: 5)).toIso8601String(),
        status: 'SCHEDULED',
      ),
    ];
    return {'seeded': 2, 'status': 'success'};
  }
}

void main() {
  testWidgets('CalendarScreen interface remains visible at all times, even with 0 events', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Mock API returning zero events
    final mockApi = MockCalendarApiService(initialEvents: []);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.campaignGridTheme,
        home: CalendarScreen(api: mockApi),
      ),
    );

    // While loading, subtle progress indicator is shown, but interface is rendered
    expect(find.text('Flight Calendar'), findsOneWidget);

    // Settle async fetch (which triggers auto-seed or empty day view)
    await tester.pumpAndSettle();

    // Verify calendar UI elements are present
    expect(find.text('Flight Calendar'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);

    // Channel filter chips are rendered
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Social'), findsWidgets);
    expect(find.text('Search'), findsWidgets);
    expect(find.text('Email'), findsWidgets);

    // Day of week single-letter abbreviations are visible in Month view
    expect(find.text('M'), findsOneWidget);
    expect(find.text('W'), findsOneWidget);
    expect(find.text('F'), findsOneWidget);
  });

  testWidgets('CalendarScreen renders scheduled flights and allows switching between Month and Week views', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    final now = DateTime.now();
    final sampleEvents = [
      ScheduleEvent(
        scheduleId: 'sch-101',
        campaignId: 'camp-101',
        title: 'Q4 Festive Creator Blitz',
        channel: 'Social',
        versionNo: 1,
        budget: 28000.0,
        startsAt: now.subtract(const Duration(days: 1)).toIso8601String(),
        endsAt: now.add(const Duration(days: 3)).toIso8601String(),
        status: 'SCHEDULED',
      ),
      ScheduleEvent(
        scheduleId: 'sch-102',
        campaignId: 'camp-102',
        title: 'High-Intent Search Surge',
        channel: 'Search',
        versionNo: 1,
        budget: 36000.0,
        startsAt: now.toIso8601String(),
        endsAt: now.add(const Duration(days: 5)).toIso8601String(),
        status: 'SCHEDULED',
      ),
    ];

    final mockApi = MockCalendarApiService(initialEvents: sampleEvents);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.campaignGridTheme,
        home: CalendarScreen(api: mockApi),
      ),
    );

    await tester.pumpAndSettle();

    // Verify events appear in selected day dossier
    expect(find.textContaining('Festive Creator Blitz'), findsWidgets);

    // Switch to Week view
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    // Verify Weekly Flight Lanes are active
    expect(find.text('Channel'), findsOneWidget);

    // Toggle back to Month view
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();

    expect(find.text('Flight Calendar'), findsOneWidget);
  });
}
