import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bit_loggers_app/screens/analytics_screen.dart';
import 'package:bit_loggers_app/services/api_service.dart';
import 'package:bit_loggers_app/theme/app_theme.dart';

class MockAnalyticsApiService extends ApiService {
  @override
  Future<Map<String, dynamic>> getAnalytics({
    String? channel,
    String? startDate,
    String? endDate,
    String? interval,
  }) async {
    return {
      'dateRange': {
        'startDate': startDate ?? '2026-10-03',
        'endDate': endDate ?? '2026-11-02',
        'interval': interval ?? '1 day',
      },
      'summary': {
        'totalCampaigns': 5,
        'totalBudget': 150000,
        'kpis': {
          'conversionRate': {'name': 'Conversion Rate', 'unit': '%', 'projected': 3.8, 'actual': 4.2},
          'ctr': {'name': 'Click-Through Rate', 'unit': '%', 'projected': 4.5, 'actual': 5.1},
          'roi': {'name': 'Return on Investment', 'unit': 'x', 'projected': 4.1, 'actual': 4.6},
          'cpa': {'name': 'Cost Per Acquisition', 'unit': '\$', 'projected': 24.5, 'actual': 21.0},
          'aov': {'name': 'Average Order Value', 'unit': '\$', 'projected': 110.0, 'actual': 122.0},
        },
      },
      'channelBreakdown': [
        {'channel': 'Social', 'campaigns': 2, 'budget': 60000},
        {'channel': 'Search', 'campaigns': 2, 'budget': 50000},
        {'channel': 'Email', 'campaigns': 1, 'budget': 40000},
      ],
      'trends': [
        {
          'date': '2026-10-03',
          'projected': {'conversionRate': 3.5, 'ctr': 4.1, 'roi': 3.9, 'cpa': 25.0, 'aov': 105.0},
          'actual': {'conversionRate': 3.9, 'ctr': 4.6, 'roi': 4.2, 'cpa': 22.5, 'aov': 114.0},
        },
        {
          'date': '2026-10-15',
          'projected': {'conversionRate': 3.8, 'ctr': 4.4, 'roi': 4.1, 'cpa': 24.5, 'aov': 110.0},
          'actual': {'conversionRate': 4.2, 'ctr': 5.0, 'roi': 4.5, 'cpa': 21.2, 'aov': 120.0},
        },
        {
          'date': '2026-11-02',
          'projected': {'conversionRate': 4.0, 'ctr': 4.6, 'roi': 4.3, 'cpa': 24.0, 'aov': 112.0},
          'actual': {'conversionRate': 4.5, 'ctr': 5.3, 'roi': 4.8, 'cpa': 20.5, 'aov': 125.0},
        },
      ],
    };
  }
}

void main() {
  testWidgets('AnalyticsScreen renders 5 mandatory KPIs and historical chart', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockApi = MockAnalyticsApiService();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.campaignGridTheme,
        home: AnalyticsScreen(api: mockApi),
      ),
    );

    // Initial loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let the async fetch complete
    await tester.pumpAndSettle();

    // Verify Title and Subtitle
    expect(find.text('Intelligence & Analytics'), findsOneWidget);
    expect(find.text('TimescaleDB Continuous Aggregations (FR-09)'), findsOneWidget);

    // Verify Presets are present
    expect(find.text('Last 7 Days'), findsOneWidget);
    expect(find.text('Last 30 Days'), findsOneWidget);
    expect(find.text('Quarter to Date'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);

    // Verify 5 Mandatory KPIs
    expect(find.text('Return on Investment'), findsOneWidget);
    expect(find.text('Conversion Rate'), findsOneWidget);
    expect(find.text('Click-Through Rate'), findsOneWidget);
    expect(find.text('Cost Per Acquisition'), findsOneWidget);
    expect(find.text('Average Order Value'), findsOneWidget);

    // Tap on a different metric tab (Conv Rate)
    await tester.tap(find.text('Conv Rate'));
    await tester.pumpAndSettle();

    // Verify it switches active metric
    expect(find.text('ACTIVE'), findsOneWidget);

    // Scroll to Channel Breakdown
    await tester.scrollUntilVisible(
      find.text('Channel Economics & Yield'),
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Verify Channel Breakdown
    expect(find.text('Channel Economics & Yield'), findsOneWidget);
    expect(find.text('Social'), findsWidgets);
    expect(find.text('Search'), findsWidgets);
    expect(find.text('Email'), findsWidgets);
  });
}
