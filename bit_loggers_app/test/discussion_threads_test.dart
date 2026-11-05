import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bit_loggers_app/models/models.dart';
import 'package:bit_loggers_app/screens/campaign_detail_screen.dart';
import 'package:bit_loggers_app/services/api_service.dart';
import 'package:bit_loggers_app/theme/app_theme.dart';

class MockDiscussionApiService extends ApiService {
  final List<DiscussionMessage> discussionDb = [
    DiscussionMessage(
      messageId: 'msg-1',
      authorName: 'Alice Cooper',
      authorRole: 'marketer',
      content: 'Can @Marcus Vance review this Q4 target?',
      createdAt: '2026-11-02T10:00:00Z',
      versionId: 'ver-1',
      versionNo: 1,
      mentions: ['usr-reviewer-1'],
    ),
    DiscussionMessage(
      messageId: 'msg-2',
      authorName: 'Marcus Vance',
      authorRole: 'reviewer',
      content: 'Approved from my end, looks solid.',
      createdAt: '2026-11-02T10:05:00Z',
      parentMessageId: 'msg-1',
      versionId: 'ver-1',
      versionNo: 1,
    ),
  ];

  @override
  Future<Campaign> getCampaign(String id) async {
    return Campaign(
      campaignId: id,
      title: 'Q4 Festive Launch',
      status: 'InReview',
      ownerId: 'usr-marketer-1',
      ownerName: 'Alice Cooper (Marketer)',
      createdAt: '2026-11-01T08:00:00Z',
      updatedAt: '2026-11-02T08:00:00Z',
      currentVersionId: 'ver-1',
      currentVersion: CampaignVersion(
        versionId: 'ver-1',
        campaignId: id,
        versionNo: 1,
        objective: 'Expand Q4 GMV',
        targetAudience: 'Metro consumers 25-45',
        channel: 'Social',
        budget: 45000,
        kpiProjected: KpiMetrics(conversionRate: 3.8, ctr: 4.5, roi: 4.1, cpa: 24.5, aov: 110.0),
        createdBy: 'usr-marketer-1',
        createdAt: '2026-11-01T08:00:00Z',
      ),
      versions: [
        CampaignVersion(
          versionId: 'ver-1',
          campaignId: id,
          versionNo: 1,
          objective: 'Expand Q4 GMV',
          targetAudience: 'Metro consumers 25-45',
          channel: 'Social',
          budget: 45000,
          kpiProjected: KpiMetrics(conversionRate: 3.8, ctr: 4.5, roi: 4.1, cpa: 24.5, aov: 110.0),
          createdBy: 'usr-marketer-1',
          createdAt: '2026-11-01T08:00:00Z',
        ),
      ],
    );
  }

  @override
  Future<List<DiscussionMessage>> getDiscussions(String id, {String? versionId}) async {
    if (versionId != null) {
      return discussionDb.where((d) => d.versionId == versionId).toList();
    }
    return List.from(discussionDb);
  }

  @override
  Future<List<Collaborator>> getCollaborators(String id) async {
    return [
      Collaborator(userId: 'usr-marketer-1', name: 'Alice Cooper', role: 'marketer', email: 'alice@bitloggers.com'),
      Collaborator(userId: 'usr-reviewer-1', name: 'Marcus Vance', role: 'reviewer', email: 'marcus@bitloggers.com'),
    ];
  }

  @override
  Future<DiscussionMessage> postDiscussion(
    String id,
    String content, {
    String? parentMessageId,
    String? versionId,
    bool isInternalOnly = false,
  }) async {
    final newMsg = DiscussionMessage(
      messageId: 'msg-${discussionDb.length + 1}',
      authorName: currentUser.name,
      authorRole: currentUser.role,
      content: content,
      createdAt: DateTime.now().toIso8601String(),
      parentMessageId: parentMessageId,
      versionId: versionId,
      versionNo: versionId != null ? 1 : null,
      isInternalOnly: isInternalOnly,
    );
    discussionDb.add(newMsg);
    return newMsg;
  }
}

void main() {
  testWidgets('CampaignDetailScreen renders threaded discussions with version anchor and @mentions', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockApi = MockDiscussionApiService();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.campaignGridTheme,
        home: CampaignDetailScreen(
          campaignId: 'camp-test-1',
          api: mockApi,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Scroll down to the Discussions card
    await tester.scrollUntilVisible(
      find.text('Discussions & Threads'),
      300.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Verify Title & FR-12 Badge
    expect(find.text('Discussions & Threads'), findsOneWidget);
    expect(find.text('FR-12 Anchored'), findsOneWidget);

    // Verify Version Filter Chips
    expect(find.text('All Versions'), findsOneWidget);
    expect(find.text('v1.0 (Social)'), findsOneWidget);

    // Verify Top-Level Message and Threaded Reply
    expect(find.text('Alice Cooper'), findsWidgets);
    expect(find.text('Marcus Vance'), findsWidgets);
    expect(find.text('v1.0'), findsWidgets);
    expect(find.text('Reply'), findsWidgets);

    // Test Replying mode: tap 'Reply' on top-level message
    await tester.tap(find.text('Reply').first);
    await tester.pumpAndSettle();

    // Verify Replying banner appears
    expect(find.textContaining('Replying to Alice Cooper'), findsOneWidget);

    // Test @mention trigger: enter '@' in the text field
    final textFieldFinder = find.byType(TextField).last;
    await tester.enterText(textFieldFinder, 'Hello @');
    await tester.pumpAndSettle();

    // Verify mention suggestions overlay appeared with collaborator
    expect(find.text('Marcus Vance'), findsWidgets);

    // Cancel replying mode
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.textContaining('Replying to Alice Cooper'), findsNothing);
  });
}
