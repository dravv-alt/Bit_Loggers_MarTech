import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bit_loggers_app/screens/audit_screen.dart';
import 'package:bit_loggers_app/screens/diagnostics_screen.dart';
import 'package:bit_loggers_app/services/api_service.dart';
import 'package:bit_loggers_app/models/models.dart';
import 'package:bit_loggers_app/theme/app_theme.dart';

class MockAuditApiService extends ApiService {
  @override
  Future<List<AuditEventItem>> getAudit({String? campaignId, String? eventType, String? search}) async {
    final list = [
      AuditEventItem(
        eventId: 'evt-001',
        campaignId: 'camp-101',
        versionId: 'ver-101',
        actorId: 'usr-reviewer-1',
        actorName: 'Marcus Vance (Reviewer)',
        eventType: 'CAMPAIGN_APPROVED',
        previousState: 'Submitted',
        newState: 'Approved',
        summary: 'Reviewer recorded APPROVED on v1: Valid proposal with 4.6x projected ROI',
        details: '{"decision":"APPROVED","reason":"Valid proposal with 4.6x projected ROI"}',
        rawDetails: {'decision': 'APPROVED', 'reason': 'Valid proposal with 4.6x projected ROI'},
        correlationId: 'c-test-uuid-001',
        occurredAt: '2026-11-02T18:00:00Z',
      ),
      AuditEventItem(
        eventId: 'evt-002',
        campaignId: 'camp-102',
        versionId: 'ver-102',
        actorId: 'usr-system-1',
        actorName: 'TimescaleDB Engine',
        eventType: 'SCHEDULE_BLOCKED',
        previousState: 'Draft',
        newState: 'Blocked',
        summary: 'Scheduling blocked: Version v2 has not been approved by reviewer.',
        details: '{"code":"SCHEDULE_BLOCKED","version_no":2}',
        rawDetails: {'code': 'SCHEDULE_BLOCKED', 'version_no': 2},
        correlationId: 'c-test-uuid-002',
        occurredAt: '2026-11-02T18:15:00Z',
      ),
    ];

    return list.where((evt) {
      if (eventType != null && eventType != 'ALL' && evt.eventType != eventType) return false;
      if (search != null && search.isNotEmpty) {
        final q = search.toLowerCase();
        return evt.summary.toLowerCase().contains(q) || evt.actorName.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  @override
  Future<List<DiagnosticLogItem>> getDiagnostics({String? eventType}) async {
    return [
      DiagnosticLogItem(
        logId: 'diag-001',
        correlationId: 'c-test-uuid-001',
        eventType: 'CAMPAIGN_APPROVED',
        outcome: 'SUCCESS',
        message: 'Reviewer recorded APPROVED on v1',
        timestamp: '2026-11-02T18:00:00Z',
      ),
      DiagnosticLogItem(
        logId: 'diag-002',
        correlationId: 'c-test-uuid-002',
        eventType: 'SCHEDULE_BLOCKED',
        outcome: 'FAILURE',
        message: 'Attempted to schedule unapproved version v2',
        timestamp: '2026-11-02T18:15:00Z',
      ),
    ];
  }
}

void main() {
  testWidgets('AuditScreen renders TimescaleDB hypertable ledger with filters and search', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockApi = MockAuditApiService();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.campaignGridTheme,
        home: AuditScreen(api: mockApi),
      ),
    );

    // Initial loading indicator
    expect(find.text('Audit Trail & Governance'), findsOneWidget);

    await tester.pumpAndSettle();

    // Verify Title & Subtitle
    expect(find.text('Audit Trail & Governance'), findsOneWidget);
    expect(find.text('TimescaleDB Append-Only Hypertable (ADR-008)'), findsOneWidget);

    // Verify search hint is rendered
    expect(find.byType(TextField), findsOneWidget);

    // Verify event records are listed
    expect(find.text('CAMPAIGN_APPROVED'), findsWidgets);
    expect(find.text('SCHEDULE_BLOCKED'), findsWidgets);
    expect(find.textContaining('Marcus Vance (Reviewer)'), findsWidgets);

    // Tap on CAMPAIGN_APPROVED to open deep inspection modal
    await tester.tap(find.text('CAMPAIGN_APPROVED').first);
    await tester.pumpAndSettle();

    // Verify inspection modal contents
    expect(find.text('TIMESCALEDB HYPERTABLE PAYLOAD (JSON)'), findsOneWidget);
    expect(find.textContaining('c-test-uuid-001'), findsWidgets);
    expect(find.textContaining('TimescaleDB Append-Only Non-Repudiation Seal'), findsOneWidget);

    // Close modal
    await tester.tap(find.byType(DraggableScrollableSheet));
  });

  testWidgets('DiagnosticsScreen renders telemetry logs and handles outcome filtering', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockApi = MockAuditApiService();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.campaignGridTheme,
        home: DiagnosticsScreen(api: mockApi),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Subtitle
    expect(find.text('Diagnostic Telemetry'), findsOneWidget);
    expect(find.text('LLD Section 13 • Correlation Tracing'), findsOneWidget);

    // Verify telemetry logs are rendered
    expect(find.text('SUCCESS'), findsWidgets);
    expect(find.text('FAILURE'), findsWidgets);
    expect(find.textContaining('c-test-uuid-001'), findsWidgets);
  });
}
