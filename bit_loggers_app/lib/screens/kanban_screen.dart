import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'campaign_detail_screen.dart';
import 'campaign_wizard_screen.dart';

class KanbanScreen extends StatefulWidget {
  final ApiService api;
  final VoidCallback onRefresh;

  const KanbanScreen({super.key, required this.api, required this.onRefresh});

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  List<Campaign> _campaigns = [];
  bool _loading = true;
  String _selectedChannel = 'All';
  String _searchQuery = '';

  final List<Map<String, String>> _columns = [
    {'id': 'Draft', 'title': 'Draft / Revised'},
    {'id': 'Submitted', 'title': 'Awaiting Review'},
    {'id': 'ChangesRequested', 'title': 'Changes Requested'},
    {'id': 'Approved', 'title': 'Approved (Ready)'},
    {'id': 'Scheduled', 'title': 'Scheduled Flights'},
    {'id': 'Rejected', 'title': 'Rejected'},
  ];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.getCampaigns(
        status: null,
        channel: _selectedChannel == 'All' ? null : _selectedChannel,
      );
      setState(() {
        _campaigns = list;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<Campaign> _getFilteredCampaigns() {
    return _campaigns.where((c) {
      final matchSearch = c.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (c.currentVersion?.objective.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      final matchChannel = _selectedChannel == 'All' || c.currentVersion?.channel == _selectedChannel;
      return matchSearch && matchChannel;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredCampaigns();
    final isMarketer = widget.api.currentUser.role == 'marketer';

    return Scaffold(
      body: Column(
        children: [
          // Filter & Search bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppTheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search campaigns...',
                      prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey),
                      isDense: true,
                      contentPadding: EdgeInsets.all(10),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _selectedChannel,
                  dropdownColor: AppTheme.card,
                  underline: const SizedBox(),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  items: ['All', 'Social', 'Email', 'Search', 'Display', 'Influencer', 'Video']
                      .map((ch) => DropdownMenuItem(value: ch, child: Text(ch)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedChannel = val);
                      _fetch();
                    }
                  },
                ),
              ],
            ),
          ),

          // Kanban Columns
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(12),
                    itemCount: _columns.length,
                    itemBuilder: (context, index) {
                      final col = _columns[index];
                      final colCampaigns = filtered.where((c) {
                        if (col['id'] == 'Draft') return c.status == 'Draft' || c.status == 'Revised';
                        return c.status == col['id'];
                      }).toList();

                      return Container(
                        width: 290,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Column Header
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    col['title']!.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFE2E8F0),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.getStatusColor(col['id']!).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${colCampaigns.length}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.getStatusColor(col['id']!),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Column Cards
                            Expanded(
                              child: colCampaigns.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No campaigns',
                                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(8),
                                      itemCount: colCampaigns.length,
                                      itemBuilder: (context, cIdx) {
                                        return _buildCard(colCampaigns[cIdx]);
                                      },
                                    ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: isMarketer
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CampaignWizardScreen(api: widget.api)),
                );
                if (created == true) {
                  _fetch();
                  widget.onRefresh();
                }
              },
              backgroundColor: AppTheme.primary,
              foregroundColor: const Color(0xFF090D16),
              icon: const Icon(Icons.add),
              label: const Text('New Proposal', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildCard(Campaign camp) {
    final curVer = camp.currentVersion;
    final kpi = curVer?.kpiProjected ?? KpiMetrics(conversionRate: 3.5, ctr: 4.2, roi: 3.8, cpa: 25, aov: 95);
    final chColor = AppTheme.getChannelColor(curVer?.channel ?? 'Social');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CampaignDetailScreen(
                campaignId: camp.campaignId,
                api: widget.api,
              ),
            ),
          );
          _fetch();
          widget.onRefresh();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and Version tag
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      camp.title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                    ),
                    child: Text(
                      'v${curVer?.versionNo ?? 1}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Channel & Budget
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: chColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: chColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      curVer?.channel ?? 'Omnichannel',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: chColor),
                    ),
                  ),
                  Text(
                    '\$${(curVer?.budget ?? 0).toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontFamily: 'monospace'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Objective Snippet
              Text(
                curVer?.objective ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.3),
              ),
              const SizedBox(height: 10),

              // Mini KPI Ribbon
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          'ROI: ${kpi.roi}x',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Conv: ${kpi.conversionRate}%',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'CPA: \$${kpi.cpa.toInt()}',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

