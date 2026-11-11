import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'v3_components.dart';
import 'v3_tokens.dart';

class V3CalendarView extends StatefulWidget {
  final ApiService api;
  final V3Palette palette;
  final ValueChanged<String> onInspectCampaign;

  const V3CalendarView({
    super.key,
    required this.api,
    required this.palette,
    required this.onInspectCampaign,
  });

  @override
  State<V3CalendarView> createState() => _V3CalendarViewState();
}

class _V3CalendarViewState extends State<V3CalendarView> {
  static const _channels = ['All', 'Social', 'Search', 'Email', 'Display', 'Video'];

  List<ScheduleEvent> _events = [];
  String _channelFilter = 'All';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await widget.api.getCalendar();
      if (mounted) {
        setState(() {
          _events = res;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  ({String range, int days}) _formatRange(String startIso, String endIso) {
    final s = DateTime.tryParse(startIso)?.toLocal() ?? DateTime.now();
    final e = DateTime.tryParse(endIso)?.toLocal() ?? s.add(const Duration(days: 7));
    final fmt = DateFormat('MMM d');
    final days = math.max(1, e.difference(s).inDays);
    return (range: '${fmt.format(s)} — ${fmt.format(e)}', days: days);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final filtered = _events
        .where((e) =>
            _channelFilter == 'All' || e.channel.toLowerCase() == _channelFilter.toLowerCase())
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.bgSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.borderDefault),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              V3SegmentedControl<String>(
                palette: p,
                selected: _channelFilter,
                options: _channels
                    .map((c) => V3SegmentedOption(
                          id: c,
                          label: c == 'All' ? 'All lanes' : c,
                        ))
                    .toList(),
                onSelect: (ch) => setState(() => _channelFilter = ch),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  V3Chip(
                    label: 'Overlap guard active',
                    tone: 'lime',
                    palette: p,
                    leadingIcon: Icons.verified_user_outlined,
                  ),
                  const SizedBox(width: 8),
                  V3Button(
                    label: _loading ? 'Syncing…' : 'Refresh',
                    icon: Icons.refresh_rounded,
                    small: true,
                    palette: p,
                    onTap: _load,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (filtered.isEmpty)
          V3DashedBox(
            palette: p,
            minHeight: 220,
            padding: const EdgeInsets.all(24),
            borderRadius: 16,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_outlined, size: 30, color: p.iconTertiary),
                const SizedBox(height: 10),
                Text('No active flights in this lane', style: V3Tokens.headline(p)),
                const SizedBox(height: 6),
                Text(
                  'Approved campaign proposals can be scheduled onto a conflict-free channel window from the Pipeline view.',
                  textAlign: TextAlign.center,
                  style: V3Tokens.bodyRegular(p),
                ),
              ],
            ),
          )
        else
          ...filtered.map((evt) {
            final r = _formatRange(evt.startsAt, evt.endsAt);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: V3HoverCard(
                palette: p,
                onTap: () => widget.onInspectCampaign(evt.campaignId),
                padding: const EdgeInsets.all(16),
                borderRadius: 16,
                builder: (hovered) => LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 560;
                      final leftInfo = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              V3Chip(
                                label: evt.channel,
                                tone: V3Tokens.channelChipTone(evt.channel),
                                palette: p,
                              ),
                              V3Badge(label: 'v${evt.versionNo}', palette: p),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  V3StatusDot(colorKey: 'green', palette: p),
                                  const SizedBox(width: 5),
                                  Text(evt.status, style: V3Tokens.caption(p)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            evt.title,
                            style: V3Tokens.title2(p).copyWith(
                              fontSize: 17,
                              color: hovered ? p.accentText : p.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Flight lock bound to exact approved version v${evt.versionNo}',
                            style: V3Tokens.bodyRegular(p),
                          ),
                        ],
                      );

                      final rightInfo = Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: p.bgSecondary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${r.days}-day window',
                                  style: V3Tokens.caption(p, color: p.textTertiary),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.event_available_outlined,
                                        size: 14, color: p.iconSecondary),
                                    const SizedBox(width: 5),
                                    Text(r.range, style: V3Tokens.bodyMedium(p)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          V3Button(
                            label: 'Open brief',
                            icon: Icons.visibility_outlined,
                            small: true,
                            palette: p,
                            onTap: () => widget.onInspectCampaign(evt.campaignId),
                          ),
                        ],
                      );

                      if (wide) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [Expanded(child: leftInfo), rightInfo],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [leftInfo, const SizedBox(height: 12), rightInfo],
                      );
                    },
                  ),
              ),
            );
          }),
      ],
    );
  }
}
