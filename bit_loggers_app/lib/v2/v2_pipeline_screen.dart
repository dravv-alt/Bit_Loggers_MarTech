import 'package:flutter/material.dart';
import '../models/models.dart';
import 'v2_components.dart';
import 'v2_mappers.dart';
import 'v2_tokens.dart';

/// Screen 01: Pipeline Ledger Hub.
class V2PipelineScreen extends StatelessWidget {
  final String viewerName;
  final List<Campaign> campaigns;
  final List<ScheduleEvent> calendarEvents;
  final String selectedFilter;
  final int leaseSeconds;
  final ValueChanged<String> onSelectFilter;
  final ValueChanged<Campaign> onOpenCampaign;
  final VoidCallback onReviewTop;
  final VoidCallback onCreateProposal;

  const V2PipelineScreen({
    super.key,
    required this.viewerName,
    required this.campaigns,
    required this.calendarEvents,
    required this.selectedFilter,
    required this.leaseSeconds,
    required this.onSelectFilter,
    required this.onOpenCampaign,
    required this.onReviewTop,
    required this.onCreateProposal,
  });

  @override
  Widget build(BuildContext context) {
    int countBy(String key) =>
        campaigns.where((c) => V2Tokens.normalizeStatusKey(c.status) == key).length;

    final reviewCount = countBy('review');
    final changesCount = countBy('changes');
    final approvedCount = countBy('approved');
    final scheduledCount = countBy('scheduled');

    final filtered = selectedFilter == 'all'
        ? campaigns
        : campaigns
            .where((c) => V2Tokens.normalizeStatusKey(c.status) == selectedFilter)
            .toList();

    final chips = [
      (id: 'all', label: 'All ${campaigns.length}'),
      (id: 'review', label: 'In review $reviewCount'),
      (id: 'changes', label: 'Changes $changesCount'),
      (id: 'approved', label: 'Approved $approvedCount'),
      (id: 'scheduled', label: 'Scheduled $scheduledCount'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const V2FacetCell(status: 'brand', size: 13),
                      const SizedBox(width: 6),
                      Text(
                        'Campaign Grid · ${V2Tokens.cleanPersonName(viewerName)}',
                        style: V2Tokens.t3(color: V2Tokens.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Pipeline', style: V2Tokens.t1()),
                ],
              ),
              InkWell(
                onTap: onCreateProposal,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 38),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: V2Tokens.surfaceCard,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: V2Tokens.hairline, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, size: 15, color: V2Tokens.inkPrussian),
                      const SizedBox(width: 4),
                      Text('New brief', style: V2Tokens.t4(color: V2Tokens.inkPrussian)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Top Review Summary Card
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: V2Tokens.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: V2Tokens.hairline, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$reviewCount',
                      style: V2Tokens.t1(mono: true),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reviewCount == 1 ? 'proposal waiting for review' : 'waiting for your review',
                      style: V2Tokens.t3(color: V2Tokens.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: campaigns.isEmpty ? onCreateProposal : onReviewTop,
                style: ElevatedButton.styleFrom(
                  backgroundColor: V2Tokens.inkPrussian,
                  foregroundColor: V2Tokens.labelOnInk,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: Text(
                  campaigns.isEmpty ? 'Author brief' : 'Review now',
                  style: V2Tokens.t2(color: V2Tokens.labelOnInk),
                ),
              ),
            ],
          ),
        ),

        // Filter Chips with cadmium yellow bottom bar indicator
        SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, idx) {
              final chip = chips[idx];
              final isSelected = selectedFilter == chip.id;
              return GestureDetector(
                onTap: () => onSelectFilter(chip.id),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: isSelected ? V2Tokens.surfaceCard : V2Tokens.surfaceRecessed,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isSelected ? V2Tokens.inkPrussian : V2Tokens.hairline,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                        child: Text(
                          chip.label,
                          style: V2Tokens.t4(
                            color: isSelected ? V2Tokens.textPrimary : V2Tokens.textSecondary,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          bottom: 0,
                          left: 10,
                          right: 10,
                          child: Container(
                            height: 2.5,
                            color: V2Tokens.cadmiumYellow,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Campaign Ticket Cards
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No campaigns match this filter.',
                      style: V2Tokens.t3(color: V2Tokens.textSecondary),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, idx) {
                    final camp = filtered[idx];
                    return V2FlightTicketCard(
                      campaign: camp,
                      calendarEvents: calendarEvents,
                      leaseSeconds: leaseSeconds,
                      onTap: () => onOpenCampaign(camp),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

