import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bit_loggers_app/screens/campaign_wizard_screen.dart';
import 'package:bit_loggers_app/services/api_service.dart';
import 'package:bit_loggers_app/models/models.dart';
import 'package:bit_loggers_app/theme/app_theme.dart';

class MockWizardApiService extends ApiService {
  Map<String, dynamic>? lastCreatedPayload;
  String? lastSubmittedCampaignId;

  @override
  Future<Campaign> createCampaign(Map<String, dynamic> body) async {
    lastCreatedPayload = body;
    const campId = 'camp-wizard-test-01';
    const verId = 'ver-01';
    return Campaign(
      campaignId: campId,
      title: body['title'] ?? 'Test Campaign',
      ownerId: currentUser.id,
      ownerName: currentUser.name,
      status: 'Draft',
      currentVersionId: verId,
      currentVersion: CampaignVersion(
        versionId: verId,
        campaignId: campId,
        versionNo: 1,
        objective: body['objective'] ?? '',
        targetAudience: body['target_audience'] ?? '',
        channel: body['channel'] ?? 'Social',
        budget: (body['budget'] as num?)?.toDouble() ?? 10000,
        kpiProjected: KpiMetrics.fromJson(body['kpi_projected']),
        createdBy: currentUser.id,
        createdAt: DateTime.now().toIso8601String(),
      ),
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  @override
  Future<Map<String, dynamic>> submitCampaign(String id, {String? idempotencyKey}) async {
    lastSubmittedCampaignId = id;
    return {'success': true, 'status': 'Submitted', 'campaign_id': id};
  }

  @override
  Future<Map<String, dynamic>> draftWithAI(String prompt, {String? channel, double? budget}) async {
    return {
      'title': 'AI Suggested Title',
      'objective': 'AI Generated Objective',
      'target_audience': 'AI Targeted Audience',
      'channel': 'Search',
      'budget': 15000,
      'kpi_projected': {
        'conversionRate': 4.0,
        'ctr': 5.0,
        'roi': 4.5,
        'cpa': 20.0,
        'aov': 100.0,
      },
      'ai_summary': 'Summary by Gemini Argon',
    };
  }
}

void main() {
  testWidgets('CampaignWizardScreen renders high-contrast editorial pill buttons and creates campaign', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockApi = MockWizardApiService();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.campaignGridTheme,
        home: CampaignWizardScreen(api: mockApi),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & AppBar
    expect(find.text('Author Campaign Proposal'), findsOneWidget);

    // Verify Gemini Argon Assistant Card
    expect(find.text('GEMINI ARGON AI STRATEGIST'), findsOneWidget);
    expect(find.text('Draft AI'), findsOneWidget);

    // Verify Save Draft button exists and has high-contrast color (AppTheme.forge)
    final saveDraftText = tester.widget<Text>(find.text('Save Draft'));
    expect(saveDraftText.style?.color, AppTheme.forge);
    expect(saveDraftText.style?.color != Colors.white, isTrue);

    // Verify Submit for Review button exists and has high-contrast color (AppTheme.leaf)
    final submitText = tester.widget<Text>(find.text('Submit for Review'));
    expect(submitText.style?.color, AppTheme.leaf);
    expect(submitText.style?.color != Colors.black, isTrue);

    // Fill in required fields
    await tester.enterText(find.widgetWithText(TextField, 'e.g. Summer Solar Flash Sale'), 'Q4 Peak Festive Push');
    await tester.enterText(find.widgetWithText(TextField, 'State marketing target...'), 'Acquire 5,000 new customers before Diwali.');
    await tester.enterText(find.widgetWithText(TextField, 'Target segment, persona...'), 'High-intent urban shoppers looking for jewelry deals.');

    await tester.pumpAndSettle();

    // Tap "Save Draft"
    await tester.tap(find.text('Save Draft'));
    await tester.pumpAndSettle();

    expect(mockApi.lastCreatedPayload, isNotNull);
    expect(mockApi.lastCreatedPayload?['title'], 'Q4 Peak Festive Push');
    expect(mockApi.lastCreatedPayload?['objective'], 'Acquire 5,000 new customers before Diwali.');
  });
}
