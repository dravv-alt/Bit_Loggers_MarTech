import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/models.dart';

class ApiService {
  static String baseUrl = 'http://localhost:3000';
  final _uuid = const Uuid();

  // Active user header for RBAC
  User currentUser = User(
    id: 'usr-marketer-1',
    name: 'Alice Cooper (Marketer)',
    email: 'alice.marketer@bitloggers.com',
    role: 'marketer',
  );

  bool isConnected = false;

  Map<String, String> _headers({String? idempotencyKey, int? expectedVersion}) {
    final headers = {
      'Content-Type': 'application/json',
      'x-user-id': currentUser.id,
      'x-correlation-id': 'c-${_uuid.v4().substring(0, 8)}',
    };
    if (idempotencyKey != null) {
      headers['idempotency-key'] = idempotencyKey;
    }
    if (expectedVersion != null) {
      headers['x-expected-version'] = expectedVersion.toString();
    }
    return headers;
  }

  // Check health and ping server
  Future<bool> checkConnection() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/users')).timeout(const Duration(seconds: 2));
      isConnected = res.statusCode == 200;
      return isConnected;
    } catch (_) {
      isConnected = false;
      return false;
    }
  }

  // --- Users ---
  Future<List<User>> getUsers() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/users'), headers: _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['users'] as List).map((u) => User.fromJson(u)).toList();
        return list;
      }
    } catch (_) {}

    // Fallback users
    return [
      User(id: 'usr-marketer-1', name: 'Alice Cooper (Marketer)', email: 'alice.marketer@bitloggers.com', role: 'marketer'),
      User(id: 'usr-reviewer-1', name: 'Marcus Vance (Reviewer)', email: 'marcus.reviewer@bitloggers.com', role: 'reviewer'),
      User(id: 'usr-reviewer-2', name: 'Elena Rostova (Compliance)', email: 'elena.compliance@bitloggers.com', role: 'reviewer'),
      User(id: 'usr-admin-1', name: 'Sarah Jenkins (Admin)', email: 'sarah.admin@bitloggers.com', role: 'admin'),
    ];
  }

  // --- Campaigns List ---
  Future<List<Campaign>> getCampaigns({String? status, String? channel}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/campaigns').replace(queryParameters: {
        if (status != null && status != 'All') 'status': status,
        if (channel != null && channel != 'All') 'channel': channel,
      });
      final res = await http.get(uri, headers: _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['campaigns'] as List).map((c) => Campaign.fromJson(c)).toList();
      }
    } catch (_) {}

    return _fallbackCampaigns();
  }

  // --- Campaign Details ---
  Future<Campaign> getCampaign(String id) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/campaigns/$id'), headers: _headers());
      if (res.statusCode == 200) {
        return Campaign.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}

    final list = _fallbackCampaigns();
    return list.firstWhere((c) => c.campaignId == id, orElse: () => list.first);
  }

  // --- Create Campaign ---
  Future<Campaign> createCampaign(Map<String, dynamic> body) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/campaigns'),
        headers: _headers(),
        body: jsonEncode(body),
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        return Campaign.fromJson(jsonDecode(res.body));
      } else {
        final err = jsonDecode(res.body);
        throw Exception(err['error']?['message'] ?? 'Failed to create campaign');
      }
    } catch (e) {
      if (e is Exception && !e.toString().contains('Failed to create')) {
        // Return local mock created campaign
        final newId = 'camp-${_uuid.v4().substring(0, 8)}';
        const verId = 'ver-v1';
        return Campaign(
          campaignId: newId,
          title: body['title'] ?? 'Untitled',
          ownerId: currentUser.id,
          ownerName: currentUser.name,
          status: 'Draft',
          currentVersionId: verId,
          currentVersion: CampaignVersion(
            versionId: verId,
            campaignId: newId,
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
      rethrow;
    }
  }

  // --- Update Campaign ---
  Future<Campaign> updateCampaign(String id, Map<String, dynamic> body, {int? expectedVersion}) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/campaigns/$id'),
      headers: _headers(expectedVersion: expectedVersion),
      body: jsonEncode(body),
    );
    if (res.statusCode == 200) {
      return Campaign.fromJson(jsonDecode(res.body));
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['error']?['message'] ?? 'Update failed');
    }
  }

  // --- Submit Proposal ---
  Future<Map<String, dynamic>> submitCampaign(String id, {String? idempotencyKey}) async {
    final key = idempotencyKey ?? 'submit-${DateTime.now().millisecondsSinceEpoch}';
    final res = await http.post(
      Uri.parse('$baseUrl/api/campaigns/$id/submit'),
      headers: _headers(idempotencyKey: key),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['error']?['message'] ?? 'Submission failed');
    }
  }

  // --- Review Decisions ---
  Future<Map<String, dynamic>> makeDecision(String id, String type, String versionId, String reason, {String? policyReference}) async {
    final endpoint = type == 'APPROVED'
        ? '/api/campaigns/$id/approve'
        : type == 'CHANGES_REQUESTED'
            ? '/api/campaigns/$id/request-changes'
            : '/api/campaigns/$id/reject';

    final res = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(),
      body: jsonEncode({
        'version_id': versionId,
        'decision': type,
        'reason': reason,
        if (policyReference != null) 'policy_reference': policyReference,
      }),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['error']?['message'] ?? 'Decision submission failed');
    }
  }

  // --- Scheduling ---
  Future<Map<String, dynamic>> scheduleCampaign(String id, String versionId, String startsAt, String endsAt, String channel) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/campaigns/$id/schedule'),
      headers: _headers(),
      body: jsonEncode({
        'version_id': versionId,
        'starts_at': startsAt,
        'ends_at': endsAt,
        'channel': channel,
      }),
    );

    if (res.statusCode == 201 || res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['error']?['message'] ?? 'Scheduling failed');
    }
  }

  // --- Concurrency Edit Lease ---
  Future<Map<String, dynamic>> acquireLock(String id) async {
    final res = await http.post(Uri.parse('$baseUrl/api/campaigns/$id/lock'), headers: _headers());
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['error']?['message'] ?? 'Failed to acquire edit lease');
    }
  }

  Future<void> releaseLock(String id) async {
    await http.delete(Uri.parse('$baseUrl/api/campaigns/$id/lock'), headers: _headers());
  }

  // --- Discussions ---
  Future<List<DiscussionMessage>> getDiscussions(String id) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/campaigns/$id/discussions'), headers: _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['messages'] as List).map((m) => DiscussionMessage.fromJson(m)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> postDiscussion(String id, String content) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/campaigns/$id/discussions'),
      headers: _headers(),
      body: jsonEncode({'content': content}),
    );
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('Failed to post comment');
    }
  }

  // --- Notifications ---
  Future<Map<String, dynamic>> getNotifications() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/notifications'), headers: _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['notifications'] as List).map((n) => AppNotification.fromJson(n)).toList();
        return {'notifications': list, 'unreadCount': data['unreadCount'] ?? 0};
      }
    } catch (_) {}

    return {'notifications': <AppNotification>[], 'unreadCount': 0};
  }

  Future<void> markAllNotificationsRead() async {
    await http.post(Uri.parse('$baseUrl/api/notifications/read-all'), headers: _headers());
  }

  // --- Analytics ---
  Future<Map<String, dynamic>> getAnalytics({String? channel}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/analytics').replace(queryParameters: {
        if (channel != null && channel != 'All') 'channel': channel,
      });
      final res = await http.get(uri, headers: _headers());
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}

    return {
      'summary': {
        'totalCampaigns': 4,
        'totalBudget': 93500.0,
        'kpis': {
          'conversionRate': {'name': 'Conversion Rate', 'unit': '%', 'projected': 3.8, 'actual': 4.1},
          'ctr': {'name': 'Click-Through Rate', 'unit': '%', 'projected': 4.5, 'actual': 4.9},
          'roi': {'name': 'Return on Investment', 'unit': 'x', 'projected': 4.1, 'actual': 4.4},
          'cpa': {'name': 'Cost Per Acquisition', 'unit': '\$', 'projected': 24.5, 'actual': 22.0},
          'aov': {'name': 'Average Order Value', 'unit': '\$', 'projected': 110.0, 'actual': 118.0},
        }
      },
      'channelBreakdown': [
        {'channel': 'Social', 'count': 1, 'budget': 18500.0, 'roi': 4.6, 'conv': 4.2},
        {'channel': 'Email', 'count': 1, 'budget': 22000.0, 'roi': 5.1, 'conv': 5.6},
        {'channel': 'Search', 'count': 1, 'budget': 28000.0, 'roi': 5.5, 'conv': 4.8},
        {'channel': 'Display', 'count': 1, 'budget': 15000.0, 'roi': 1.8, 'conv': 1.5},
      ]
    };
  }

  // --- Calendar ---
  Future<List<ScheduleEvent>> getCalendar() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/calendar'), headers: _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['events'] as List).map((e) => ScheduleEvent.fromJson(e)).toList();
      }
    } catch (_) {}

    return [];
  }

  // --- Audit Trail ---
  Future<List<AuditEventItem>> getAudit() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/audit'), headers: _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['audit'] as List).map((a) => AuditEventItem.fromJson(a)).toList();
      }
    } catch (_) {}
    return [];
  }

  // --- Diagnostics ---
  Future<List<DiagnosticLogItem>> getDiagnostics({String? eventType}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/diagnostics').replace(queryParameters: {
        if (eventType != null && eventType.isNotEmpty) 'event_type': eventType,
      });
      final res = await http.get(uri, headers: _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['logs'] as List).map((l) => DiagnosticLogItem.fromJson(l)).toList();
      }
    } catch (_) {}
    return [];
  }

  // --- AI Drafting ---
  Future<Map<String, dynamic>> draftWithAI(String prompt, {String? channel, double? budget}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/ai/draft'),
      headers: _headers(),
      body: jsonEncode({
        'prompt': prompt,
        'channel': channel ?? 'Social',
        'budget': budget ?? 12500,
      }),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['error']?['message'] ?? 'AI generation failed');
    }
  }

  // --- Run All Architecture Tests (LLD Section 14) ---
  Future<Map<String, dynamic>> runTests() async {
    final res = await http.post(Uri.parse('$baseUrl/api/test/run-all'), headers: _headers());
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception('Failed to run test suite on backend server.');
    }
  }

  // Fallback initial demo campaigns
  List<Campaign> _fallbackCampaigns() {
    return [
      Campaign(
        campaignId: 'camp-01',
        title: 'Summer Solar Flash Sale',
        ownerId: 'usr-marketer-1',
        ownerName: 'Alice Cooper',
        status: 'Scheduled',
        currentVersionId: 'ver-01',
        currentVersion: CampaignVersion(
          versionId: 'ver-01',
          campaignId: 'camp-01',
          versionNo: 1,
          objective: 'Drive consumer adoption for eco-friendly home solar accessories.',
          targetAudience: 'Homeowners aged 30-55 with interest in renewable energy.',
          channel: 'Social',
          budget: 18500,
          kpiProjected: KpiMetrics(conversionRate: 4.2, ctr: 4.8, roi: 4.6, cpa: 21.50, aov: 145.00),
          aiSummary: 'Targeted Instagram & TikTok Reels campaign with high expected summer conversion.',
          createdBy: 'usr-marketer-1',
          createdAt: DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        ),
        createdAt: DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      ),
      Campaign(
        campaignId: 'camp-02',
        title: 'Black Friday Super Savings Pass',
        ownerId: 'usr-marketer-1',
        ownerName: 'Alice Cooper',
        status: 'ChangesRequested',
        currentVersionId: 'ver-02',
        currentVersion: CampaignVersion(
          versionId: 'ver-02',
          campaignId: 'camp-02',
          versionNo: 2,
          objective: 'Pre-launch exclusive membership pass for holiday buyers.',
          targetAudience: 'VIP tier past buyers with >\$100 lifetime spend and loyalty engagement.',
          channel: 'Email',
          budget: 22000,
          kpiProjected: KpiMetrics(conversionRate: 5.6, ctr: 6.2, roi: 5.1, cpa: 17.50, aov: 115.00),
          aiSummary: 'Narrowed VIP cohort email sequences with improved economics.',
          createdBy: 'usr-marketer-1',
          createdAt: DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        ),
        createdAt: DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      ),
      Campaign(
        campaignId: 'camp-03',
        title: 'Enterprise AI Assistant Rollout',
        ownerId: 'usr-marketer-1',
        ownerName: 'Alice Cooper',
        status: 'Submitted',
        currentVersionId: 'ver-03',
        currentVersion: CampaignVersion(
          versionId: 'ver-03',
          campaignId: 'camp-03',
          versionNo: 1,
          objective: 'Drive enterprise B2B inbound demos for workflow intelligence.',
          targetAudience: 'VP Marketing, CMOs, and Marketing Ops directors at Mid-Market tech companies.',
          channel: 'Search',
          budget: 28000,
          kpiProjected: KpiMetrics(conversionRate: 4.8, ctr: 6.5, roi: 5.5, cpa: 42.00, aov: 240.00),
          aiSummary: 'High-intent search keyword campaign targeting corporate marketing leaders.',
          createdBy: 'usr-marketer-1',
          createdAt: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        ),
        createdAt: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      ),
      Campaign(
        campaignId: 'camp-04',
        title: 'Crypto Cashback Loyalty Boost',
        ownerId: 'usr-marketer-1',
        ownerName: 'Alice Cooper',
        status: 'Rejected',
        currentVersionId: 'ver-04',
        currentVersion: CampaignVersion(
          versionId: 'ver-04',
          campaignId: 'camp-04',
          versionNo: 1,
          objective: 'Incentivize checkout using digital token cashback.',
          targetAudience: 'Retail shoppers looking for speculative rewards.',
          channel: 'Display',
          budget: 15000,
          kpiProjected: KpiMetrics(conversionRate: 1.5, ctr: 1.2, roi: 1.8, cpa: 55.00, aov: 60.00),
          aiSummary: 'Display ad network blitz with crypto rebate hooks.',
          createdBy: 'usr-marketer-1',
          createdAt: DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
        ),
        createdAt: DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      ),
    ];
  }
}

