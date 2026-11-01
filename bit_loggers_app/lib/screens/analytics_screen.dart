import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  final ApiService api;

  const AnalyticsScreen({super.key, required this.api});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String _selectedChannel = 'All';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await widget.api.getAnalytics(
        channel: _selectedChannel == 'All' ? null : _selectedChannel,
      );
      setState(() {
        _data = res;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final kpis = _data!['summary']?['kpis'] as Map<String, dynamic>? ?? {};
    final breakdown = (_data!['channelBreakdown'] as List?) ?? [];
    final totalBudget = (_data!['summary']?['totalBudget'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Intelligence & Analytics (Pillar 2)'),
        actions: [
          DropdownButton<String>(
            value: _selectedChannel,
            dropdownColor: AppTheme.card,
            underline: const SizedBox(),
            items: ['All', 'Social', 'Email', 'Search', 'Display', 'Influencer', 'Video']
                .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12))))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedChannel = val);
                _fetch();
              }
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('5 MANDATORY KPIS (PROJECTED VS ACTUAL)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              Text('Budget: \$${totalBudget.toInt()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
            ],
          ),
          const SizedBox(height: 12),

          // The 5 KPI Cards
          _kpiCard('Conversion Rate', kpis['conversionRate'], '%', AppTheme.primary),
          _kpiCard('Click-Through Rate', kpis['ctr'], '%', const Color(0xFF3B82F6)),
          _kpiCard('Return on Investment (ROI)', kpis['roi'], 'x', const Color(0xFF10B981)),
          _kpiCard('Cost Per Acquisition (CPA)', kpis['cpa'], '\$', const Color(0xFFF59E0B), isCurrency: true),
          _kpiCard('Average Order Value (AOV)', kpis['aov'], '\$', const Color(0xFFA855F7), isCurrency: true),

          const SizedBox(height: 20),
          const Text('CHANNEL ECONOMICS & YIELD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),

          // Channel Breakdown List
          ...breakdown.map((ch) {
            final name = ch['channel'] ?? '';
            final count = ch['count'] ?? 0;
            final budget = (ch['budget'] as num?)?.toDouble() ?? 0.0;
            final roi = (ch['roi'] as num?)?.toDouble() ?? 0.0;
            final conv = (ch['conv'] as num?)?.toDouble() ?? 0.0;
            final color = AppTheme.getChannelColor(name);

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        Text('$count campaign(s)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Budget: \$${budget.toInt()}', style: const TextStyle(fontSize: 12, color: Color(0xFF10B981))),
                        Text('ROI: ${roi}x', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                        Text('Conv: $conv%', style: const TextStyle(fontSize: 12, color: Colors.blueAccent)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _kpiCard(String title, Map<String, dynamic>? data, String unit, Color color, {bool isCurrency = false}) {
    final proj = (data?['projected'] as num?)?.toDouble() ?? 0.0;
    final act = (data?['actual'] as num?)?.toDouble() ?? 0.0;
    final diff = proj > 0 ? (((act - proj) / proj) * 100).toStringAsFixed(1) : '0';
    final isPos = !diff.startsWith('-');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      isCurrency ? '\$$act' : '$act$unit',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color, fontFamily: 'monospace'),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPos ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${isPos ? '+' : ''}$diff%',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPos ? Colors.green : Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('TARGET PROJECTED', style: TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  isCurrency ? '\$$proj' : '$proj$unit',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

