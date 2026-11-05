import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bit_loggers_app/screens/sync_hub_screen.dart';
import 'package:bit_loggers_app/services/api_service.dart';
import 'package:bit_loggers_app/models/models.dart';
import 'package:bit_loggers_app/theme/app_theme.dart';

class MockSyncHubApiService extends ApiService {
  bool emailFailing = false;
  List<OutboxEventItem> outboxList = [
    OutboxEventItem(
      eventId: 'evt-test-outbox-001',
      eventType: 'CAMPAIGN_SUBMITTED_EMAIL',
      payload: {'recipient': 'marcus.reviewer@bitloggers.com', 'subject': 'Campaign V1 Ready For Review'},
      status: 'PROCESSED',
      attempts: 1,
      maxAttempts: 5,
      createdAt: '2026-11-03T10:00:00Z',
      processedAt: '2026-11-03T10:00:04Z',
    ),
    OutboxEventItem(
      eventId: 'evt-test-outbox-002',
      eventType: 'CAMPAIGN_DECISION_EMAIL',
      payload: {'recipient': 'alice.marketer@bitloggers.com', 'subject': 'Decision: APPROVED'},
      status: 'PENDING',
      attempts: 0,
      maxAttempts: 5,
      createdAt: '2026-11-03T10:05:00Z',
    ),
  ];

  @override
  Future<Map<String, dynamic>> getOutbox() async {
    final pendingCount = outboxList.where((e) => e.status == 'PENDING').length;
    final processedCount = outboxList.where((e) => e.status == 'PROCESSED').length;
    final failedCount = outboxList.where((e) => e.status == 'FAILED').length;

    return {
      'events': outboxList,
      'stats': OutboxStats(
        pending: pendingCount,
        processed: processedCount,
        failed: failedCount,
        total: outboxList.length,
        isEmailServiceFailing: emailFailing,
      ),
      'isEmailServiceFailing': emailFailing,
    };
  }

  @override
  Future<List<dynamic>> processOutbox() async {
    for (int i = 0; i < outboxList.length; i++) {
      if (outboxList[i].status == 'PENDING') {
        outboxList[i] = OutboxEventItem(
          eventId: outboxList[i].eventId,
          eventType: outboxList[i].eventType,
          payload: outboxList[i].payload,
          status: 'PROCESSED',
          attempts: outboxList[i].attempts + 1,
          maxAttempts: outboxList[i].maxAttempts,
          createdAt: outboxList[i].createdAt,
          processedAt: DateTime.now().toIso8601String(),
        );
      }
    }
    return [{'status': 'PROCESSED', 'event_id': 'evt-test-outbox-002'}];
  }

  @override
  Future<bool> toggleEmailFailure({bool? failing}) async {
    emailFailing = failing ?? !emailFailing;
    return emailFailing;
  }

  @override
  Future<Map<String, dynamic>> syncBatch(List<OfflineSyncAction> actions) async {
    return {
      'processed': actions.length,
      'synced': actions.length,
      'failed': 0,
      'results': actions.map((a) => {
        'action_id': a.actionId,
        'idempotency_key': a.idempotencyKey,
        'status': 'SYNCED',
        'is_replay': false,
        'response_code': 200,
        'data': {'campaign_id': 'camp-synced-123', 'status': 'Draft'},
      }).toList(),
    };
  }
}

void main() {
  testWidgets('SyncHubScreen renders Mobile Offline Queue and Transactional Outbox tabs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockApi = MockSyncHubApiService();
    mockApi.syncQueue.clearAll();
    mockApi.syncQueue.setOfflineSimulation(false);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.campaignGridTheme,
        home: SyncHubScreen(api: mockApi),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Subtitle
    expect(find.text('Sync & Outbox Hub'), findsOneWidget);
    expect(find.text('FR-13 Mobile Queue · FR-14 Transactional Outbox'), findsOneWidget);

    // Verify Tab Headers
    expect(find.text('Queue'), findsOneWidget);
    expect(find.text('Outbox'), findsOneWidget);

    // Verify Offline Simulation Card on Tab 1
    expect(find.text('Network Connectivity Online'), findsOneWidget);

    // Tap the Offline Simulation toggle switch
    final toggleFinder = find.byType(Switch).first;
    await tester.tap(toggleFinder);
    await tester.pumpAndSettle();

    expect(find.text('Offline Simulation Active'), findsOneWidget);
    expect(mockApi.syncQueue.isOfflineSimulationEnabled, isTrue);

    // Enqueue an action using the "Add Mock" button
    final addMockFinder = find.text('Add Mock');
    expect(addMockFinder, findsOneWidget);
    await tester.tap(addMockFinder);
    await tester.pumpAndSettle();

    // Verify action is displayed in queue with Idempotency Key
    expect(mockApi.syncQueue.pendingCount, 1);
    expect(find.text('CREATE_CAMPAIGN'), findsOneWidget);
    expect(find.text('Idempotency Key: '), findsOneWidget);

    // Tap "Drain & Sync Now" button
    final drainBtnFinder = find.text('Drain & Sync Now');
    expect(drainBtnFinder, findsOneWidget);
    await tester.tap(drainBtnFinder);
    await tester.pumpAndSettle();

    // Verify status became SYNCED (one on filter pill, one on action badge)
    expect(mockApi.syncQueue.syncedCount, 1);
    expect(mockApi.syncQueue.pendingCount, 0);
    expect(find.text('SYNCED'), findsNWidgets(2));

    // Switch to Tab 2: Transactional Outbox
    await tester.tap(find.text('Outbox'));
    await tester.pumpAndSettle();

    // Verify Outbox banner & worker info
    expect(find.text('Transactional Outbox Worker (4s Poll Loop)'), findsOneWidget);
    expect(find.text('SKIP LOCKED'), findsOneWidget);
    expect(find.text('Inject Email Service Outage'), findsOneWidget);

    // Verify outbox event items
    expect(find.text('CAMPAIGN_SUBMITTED_EMAIL'), findsOneWidget);
    expect(find.text('CAMPAIGN_DECISION_EMAIL'), findsOneWidget);

    // Tap "Force Run Outbox Worker Now"
    final forceRunFinder = find.text('Force Run Outbox Worker Now');
    expect(forceRunFinder, findsOneWidget);
    await tester.tap(forceRunFinder);
    await tester.pump();
    await tester.pump();

    // Verify outbox worker processed pending events
    expect(mockApi.outboxList.any((e) => e.eventId == 'evt-test-outbox-002' && e.status == 'PROCESSED'), isTrue);
    await tester.pumpAndSettle();

    // Tap the event card to open the inspection modal
    await tester.tap(find.text('CAMPAIGN_SUBMITTED_EMAIL').first);
    await tester.pumpAndSettle();

    // Verify detail inspection modal
    expect(find.text('PostgreSQL Transactional Outbox Event'), findsOneWidget);
    expect(find.text('Payload (JSON)'), findsOneWidget);
  });
}
