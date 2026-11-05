import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bit_loggers_app/screens/kanban_screen.dart';
import 'package:bit_loggers_app/services/api_service.dart';
import 'package:bit_loggers_app/models/models.dart';
import 'package:bit_loggers_app/theme/app_theme.dart';

class MockKanbanApiService extends ApiService {
  @override
  Future<List<Campaign>> getCampaigns({String? status, String? channel}) async {
    return [
      Campaign(
        campaignId: 'camp-test-01',
        title: 'Summer Solar Flash Sale',
        ownerId: 'usr-marketer-1',
        ownerName: 'Alice Cooper',
        status: 'Scheduled',
        currentVersionId: 'ver-01',
        currentVersion: CampaignVersion(
          versionId: 'ver-01',
          campaignId: 'camp-test-01',
          versionNo: 1,
          objective: 'Drive consumer adoption for eco-friendly solar.',
          targetAudience: 'Homeowners aged 30-55',
          channel: 'Social',
          budget: 18500,
          kpiProjected: KpiMetrics(conversionRate: 4.2, ctr: 4.8, roi: 4.6, cpa: 21.50, aov: 145.00),
          createdBy: 'usr-marketer-1',
          createdAt: DateTime.now().toIso8601String(),
        ),
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      ),
      Campaign(
        campaignId: 'camp-test-02',
        title: 'Enterprise AI Assistant Rollout',
        ownerId: 'usr-marketer-1',
        ownerName: 'Alice Cooper',
        status: 'Submitted',
        currentVersionId: 'ver-02',
        currentVersion: CampaignVersion(
          versionId: 'ver-02',
          campaignId: 'camp-test-02',
          versionNo: 2,
          objective: 'B2B enterprise inbound demos.',
          targetAudience: 'VP Marketing, CMOs',
          channel: 'Search',
          budget: 28000,
          kpiProjected: KpiMetrics(conversionRate: 4.8, ctr: 6.5, roi: 5.5, cpa: 42.00, aov: 240.00),
          createdBy: 'usr-marketer-1',
          createdAt: DateTime.now().toIso8601String(),
        ),
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      ),
    ];
  }
}

void main() {
  testWidgets('KanbanScreen dual-mode view and architectural header test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    final api = MockKanbanApiService();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.campaignGridTheme,
        home: KanbanScreen(
          api: api,
          onRefresh: () {},
          isOverviewHub: false,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Executive Header
    expect(find.text('Campaign Registry'), findsOneWidget);
    expect(find.text('Ledger'), findsOneWidget);
    expect(find.text('Board'), findsOneWidget);
    expect(find.text('1 Awaiting sign-off'), findsOneWidget);
    expect(find.text('1 Scheduled flights'), findsOneWidget);

    // Verify Ledger Cards Rendered
    expect(find.text('Summer Solar Flash Sale'), findsOneWidget);
    expect(find.text('Enterprise AI Assistant Rollout'), findsOneWidget);
    expect(find.text('SCHEDULED FLIGHT'), findsOneWidget);
    expect(find.text('IN REVIEW'), findsOneWidget);

    // Toggle to Kanban Board Mode
    await tester.tap(find.text('Board'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify Kanban Column Headers
    expect(find.text('DRAFT'), findsOneWidget);
    expect(find.text('IN REVIEW'), findsOneWidget);
    expect(find.text('CHANGES'), findsOneWidget);
    expect(find.text('APPROVED'), findsOneWidget);
    expect(find.text('SCHEDULED'), findsOneWidget);

    // Toggle back to Ledger Mode
    await tester.tap(find.text('Ledger'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Summer Solar Flash Sale'), findsOneWidget);
  });
}

