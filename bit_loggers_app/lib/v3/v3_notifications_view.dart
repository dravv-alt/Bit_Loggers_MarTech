import 'package:flutter/material.dart';
import '../models/models.dart';
import 'v3_components.dart';
import 'v3_tokens.dart';

class V3NotificationsView extends StatefulWidget {
  final List<AppNotification> notifications;
  final int unreadCount;
  final V3Palette palette;
  final ValueChanged<String> onMarkRead;
  final VoidCallback onMarkAllRead;
  final ValueChanged<String> onInspectCampaign;
  final VoidCallback onRefresh;

  const V3NotificationsView({
    super.key,
    required this.notifications,
    required this.unreadCount,
    required this.palette,
    required this.onMarkRead,
    required this.onMarkAllRead,
    required this.onInspectCampaign,
    required this.onRefresh,
  });

  @override
  State<V3NotificationsView> createState() => _V3NotificationsViewState();
}

class _V3NotificationsViewState extends State<V3NotificationsView> {
  String _tab = 'all'; // 'all' | 'mentions' | 'system'

  bool _isSystem(AppNotification n) {
    final lower = '${n.title} ${n.message}'.toLowerCase();
    return lower.contains('schedul') || lower.contains('flight');
  }

  bool _isRevision(AppNotification n) {
    final lower = '${n.title} ${n.message}'.toLowerCase();
    return lower.contains('revis') || lower.contains('change') || lower.contains('reject');
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final all = widget.notifications;
    final mentions = all.where((n) => !_isSystem(n)).toList();
    final system = all.where(_isSystem).toList();
    final shown = _tab == 'mentions'
        ? mentions
        : _tab == 'system'
            ? system
            : all;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Sync Banner
        Container(
          padding: const EdgeInsets.all(14),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.unreadCount > 0
                        ? '${widget.unreadCount} unread workspace dispatches'
                        : 'All workspace dispatches acknowledged',
                    style: V3Tokens.bodyMedium(p),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Synced from durable outbox delivery across in-app, push, and email lanes.',
                    style: V3Tokens.caption(p),
                  ),
                ],
              ),
              V3Button(
                label: 'Refresh feed',
                icon: Icons.refresh_rounded,
                small: true,
                palette: p,
                onTap: widget.onRefresh,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Main Notification Center Panel
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: p.bgPrimary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.borderDefault),
            boxShadow: [
              BoxShadow(
                color: p.cardShadowColor,
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Workspace notifications', style: V3Tokens.title2(p)),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.unreadCount} unread',
                        style: V3Tokens.caption(p),
                      ),
                    ],
                  ),
                  V3Button(
                    label: 'Mark all read',
                    small: true,
                    variant: V3ButtonVariant.ghost,
                    palette: p,
                    onTap: widget.unreadCount > 0 ? widget.onMarkAllRead : null,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              V3SegmentedControl<String>(
                palette: p,
                selected: _tab,
                options: [
                  V3SegmentedOption(id: 'all', label: 'All', count: all.length),
                  V3SegmentedOption(id: 'mentions', label: 'Mentions', count: mentions.length),
                  V3SegmentedOption(id: 'system', label: 'System', count: system.length),
                ],
                onSelect: (t) => setState(() => _tab = t),
              ),
              const SizedBox(height: 14),

              if (shown.isEmpty)
                V3DashedBox(
                  palette: p,
                  minHeight: 130,
                  padding: const EdgeInsets.all(28),
                  borderRadius: 14,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none_rounded, size: 28, color: p.iconTertiary),
                      const SizedBox(height: 8),
                      Text('No notifications in this view', style: V3Tokens.bodyMedium(p)),
                    ],
                  ),
                )
              else
                ...shown.map((n) {
                  final isFlight = _isSystem(n);
                  final isRev = _isRevision(n);
                  final iconBg = isRev
                      ? p.chipColors('rose').bg
                      : isFlight
                          ? p.chipColors('lime').bg
                          : p.chipColors('blue').bg;
                  final iconFg = isRev
                      ? p.chipColors('rose').fg
                      : isFlight
                          ? p.chipColors('lime').fg
                          : p.chipColors('blue').fg;
                  final iconData = isFlight
                      ? Icons.event_available_outlined
                      : isRev
                          ? Icons.error_rounded
                          : Icons.mark_email_read_outlined;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: n.isRead ? p.bgInner : p.bgSecondary.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: p.borderDefault),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: iconBg,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(iconData, size: 17, color: iconFg),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(n.title, style: V3Tokens.bodyMedium(p)),
                                    ),
                                    const SizedBox(width: 10),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${n.channel} · ${V3Tokens.formatRelativeTime(n.createdAt)}',
                                          style: V3Tokens.caption(p, color: p.textTertiary),
                                        ),
                                        if (!n.isRead) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(
                                              color: p.accent500,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(n.message, style: V3Tokens.bodyRegular(p)),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    if (n.campaignId != null && n.campaignId!.isNotEmpty)
                                      V3Button(
                                        label: 'Inspect brief',
                                        small: true,
                                        variant: V3ButtonVariant.primary,
                                        palette: p,
                                        onTap: () {
                                          if (!n.isRead) widget.onMarkRead(n.notificationId);
                                          widget.onInspectCampaign(n.campaignId!);
                                        },
                                      ),
                                    if (!n.isRead)
                                      V3Button(
                                        label: 'Mark read',
                                        small: true,
                                        palette: p,
                                        onTap: () => widget.onMarkRead(n.notificationId),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}
