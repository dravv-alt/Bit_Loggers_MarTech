import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'v2_components.dart';
import 'v2_detail_diff_spend.dart';
import 'v2_mappers.dart';
import 'v2_tokens.dart';

/// Notifications Center in CampaignGrid v2 ("The Perforated Ledger & Facet Instrument").
class V2NotificationsScreen extends StatefulWidget {
  final ApiService api;
  final List<ScheduleEvent> calendarEvents;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onDataMutated;

  const V2NotificationsScreen({
    super.key,
    required this.api,
    this.calendarEvents = const [],
    this.onOpenCalendar,
    this.onDataMutated,
  });

  @override
  State<V2NotificationsScreen> createState() => _V2NotificationsScreenState();
}

class _V2NotificationsScreenState extends State<V2NotificationsScreen> {
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _loading = true;
  bool _markingAll = false;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.api.getNotifications();
      final list = (data['notifications'] as List<AppNotification>?) ?? [];
      final unread = (data['unreadCount'] as int?) ?? list.where((n) => !n.isRead).length;
      if (!mounted) return;
      setState(() {
        _notifications = list;
        _unreadCount = unread;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAll || _unreadCount == 0) return;
    setState(() => _markingAll = true);
    try {
      await widget.api.markAllNotificationsRead();
      widget.onDataMutated?.call();
      await _load();
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _handleTapNotification(AppNotification notif) async {
    if (!notif.isRead) {
      setState(() {
        _notifications = _notifications
            .map(
              (item) => item.notificationId == notif.notificationId
                  ? AppNotification(
                      notificationId: item.notificationId,
                      title: item.title,
                      message: item.message,
                      channel: item.channel,
                      priority: item.priority,
                      isRead: true,
                      createdAt: item.createdAt,
                      campaignId: item.campaignId,
                    )
                  : item,
            )
            .toList();
        _unreadCount = _notifications.where((n) => !n.isRead).length;
      });
      await widget.api.markNotificationRead(notif.notificationId);
      widget.onDataMutated?.call();
    }

    if (!mounted) return;
    final campId = notif.campaignId;
    if (campId != null && campId.isNotEmpty) {
      final res = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => V2CampaignDetailScreen(
            api: widget.api,
            campaignId: campId,
            calendarEvents: widget.calendarEvents,
            onOpenCalendar: widget.onOpenCalendar,
            onDataMutated: widget.onDataMutated,
          ),
        ),
      );
      if (!mounted) return;
      if (res == 'OPEN_CALENDAR') {
        widget.onOpenCalendar?.call();
        Navigator.pop(context, 'OPEN_CALENDAR');
        return;
      }
      await _load();
    }
  }

  String _statusKey(AppNotification n) {
    final text = '${n.title} ${n.message}'.toLowerCase();
    if (text.contains('revis') ||
        text.contains('change') ||
        text.contains('edit') ||
        text.contains('requested')) {
      return 'changes';
    }
    if (text.contains('reject') ||
        text.contains('block') ||
        text.contains('conflict') ||
        text.contains('pause') ||
        text.contains('fail')) {
      return 'blocked';
    }
    if (text.contains('schedul') || text.contains('flight') || text.contains('publish')) {
      return 'scheduled';
    }
    if (text.contains('approv')) {
      return 'approved';
    }
    return 'review';
  }

  String _badgeLabel(String statusKey) {
    switch (statusKey) {
      case 'changes':
        return 'Changes requested';
      case 'blocked':
        return 'Attention needed';
      case 'scheduled':
        return 'Flight scheduled';
      case 'approved':
        return 'Approved';
      default:
        return 'Awaiting review';
    }
  }

  String _categoryKey(AppNotification n) {
    final text = '${n.title} ${n.message}'.toLowerCase();
    if (text.contains('schedul') ||
        text.contains('flight') ||
        text.contains('slot') ||
        text.contains('calendar')) {
      return 'flights';
    }
    return 'decisions';
  }

  List<AppNotification> _filteredList() {
    switch (_filter) {
      case 'unread':
        return _notifications.where((n) => !n.isRead).toList();
      case 'decisions':
        return _notifications.where((n) => _categoryKey(n) == 'decisions').toList();
      case 'flights':
        return _notifications.where((n) => _categoryKey(n) == 'flights').toList();
      default:
        return _notifications;
    }
  }

  String _relativeTime(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return 'Recent';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return V2Mappers.formatShortTimestamp(iso);
  }

  String _channelLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'in-app':
        return 'In-app';
      case 'push':
        return 'Push alert';
      case 'email':
        return 'Email digest';
      default:
        final clean = raw.trim();
        if (clean.isEmpty) return 'In-app';
        return '${clean[0].toUpperCase()}${clean.substring(1)}';
    }
  }

  String _prioritySuffix(String raw) {
    switch (raw.toLowerCase()) {
      case 'high':
        return ' · High priority';
      case 'low':
        return ' · Routine';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final decisionsCount =
        _notifications.where((n) => _categoryKey(n) == 'decisions').length;
    final flightsCount =
        _notifications.where((n) => _categoryKey(n) == 'flights').length;
    final filtered = _filteredList();

    final chips = [
      (id: 'all', label: 'All ${_notifications.length}'),
      (id: 'unread', label: 'Unread $_unreadCount'),
      (id: 'decisions', label: 'Decisions $decisionsCount'),
      (id: 'flights', label: 'Flights $flightsCount'),
    ];

    return Scaffold(
      backgroundColor: V2Tokens.bgPlaster,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(
              children: [
                // Top Navigation Chrome
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: V2Tokens.hairline, width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 40),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.chevron_left_rounded,
                                size: 19,
                                color: V2Tokens.textPrimary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'Pipeline',
                                style: V2Tokens.t3(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_unreadCount > 0)
                        InkWell(
                          onTap: _markingAll ? null : _markAllRead,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 38),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: V2Tokens.surfaceCard,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: V2Tokens.hairline,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.done_all_rounded,
                                  size: 14,
                                  color: _markingAll
                                      ? V2Tokens.textSecondary
                                      : V2Tokens.inkPrussian,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _markingAll ? 'Updating...' : 'Mark all read',
                                  style: V2Tokens.t4(
                                    color: _markingAll
                                        ? V2Tokens.textSecondary
                                        : V2Tokens.inkPrussian,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: V2Tokens.surfaceRecessed,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: V2Tokens.hairline, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_rounded,
                                size: 13,
                                color: V2Tokens.approvedSolid,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'All caught up',
                                style: V2Tokens.t4(color: V2Tokens.textSecondary),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Main Content
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: V2Tokens.inkPrussian,
                          ),
                        )
                      : RefreshIndicator(
                          color: V2Tokens.inkPrussian,
                          backgroundColor: V2Tokens.surfaceCard,
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                            children: [
                              // Page Header
                              Row(
                                children: [
                                  V2FacetCell(
                                    status: _unreadCount > 0 ? 'changes' : 'approved',
                                    size: 12,
                                    selected: _unreadCount > 0,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _unreadCount > 0
                                        ? '$_unreadCount unread across your campaigns'
                                        : 'Workspace dispatches · All acknowledged',
                                    style: V2Tokens.t3(color: V2Tokens.textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Notifications', style: V2Tokens.t1()),
                              const SizedBox(height: 12),

                              // Filter Pills with Prussian Active Border & Cadmium Yellow Indicator
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: chips.map((chip) {
                                    final isSelected = _filter == chip.id;
                                    return GestureDetector(
                                      onTap: () => setState(() => _filter = chip.id),
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        clipBehavior: Clip.antiAlias,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? V2Tokens.surfaceCard
                                              : V2Tokens.surfaceRecessed,
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(
                                            color: isSelected
                                                ? V2Tokens.inkPrussian
                                                : V2Tokens.hairline,
                                            width: isSelected ? 1.5 : 1.0,
                                          ),
                                        ),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.fromLTRB(
                                                12,
                                                8,
                                                12,
                                                10,
                                              ),
                                              child: Text(
                                                chip.label,
                                                style: V2Tokens.t4(
                                                  color: isSelected
                                                      ? V2Tokens.textPrimary
                                                      : V2Tokens.textSecondary,
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
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Inset Grouped Ledger Table
                              Container(
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: V2Tokens.surfaceCard,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: V2Tokens.hairline,
                                    width: 1,
                                  ),
                                ),
                                child: filtered.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          children: [
                                            const V2FacetCell(
                                              status: 'approved',
                                              size: 16,
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              _filter == 'unread'
                                                  ? 'No unread dispatches'
                                                  : 'No notifications in this view',
                                              style: V2Tokens.t2(),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'New review decisions, change requests, and flight locks appear here.',
                                              style: V2Tokens.t3(
                                                color: V2Tokens.textSecondary,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      )
                                    : Column(
                                        children: List.generate(filtered.length, (idx) {
                                          final notif = filtered[idx];
                                          final isLast = idx == filtered.length - 1;
                                          return _buildNotificationRow(notif, isLast);
                                        }),
                                      ),
                              ),

                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  'Dispatches mirror immutable campaign decisions and schedule locks.',
                                  style: V2Tokens.t4(color: V2Tokens.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationRow(AppNotification notif, bool isLast) {
    final statusKey = _statusKey(notif);
    final isUnread = !notif.isRead;
    final hasCampaign = notif.campaignId != null && notif.campaignId!.isNotEmpty;

    return InkWell(
      onTap: () => _handleTapNotification(notif),
      child: Container(
        decoration: BoxDecoration(
          color: isUnread ? V2Tokens.changedRowTint : Colors.transparent,
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: V2Tokens.hairline, width: 1),
                ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: V2FacetCell(
                status: statusKey,
                size: 13,
                selected: isUnread,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: V2StatusBadge(
                          status: statusKey,
                          customLabel: _badgeLabel(statusKey),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _relativeTime(notif.createdAt),
                        style: V2Tokens.t4(color: V2Tokens.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    notif.title,
                    style: V2Tokens.t2(
                      color: isUnread ? V2Tokens.textPrimary : V2Tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.message,
                    style: V2Tokens.t3(color: V2Tokens.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '${_channelLabel(notif.channel)}${_prioritySuffix(notif.priority)}',
                          style: V2Tokens.t4(color: V2Tokens.textSecondary),
                        ),
                      ),
                      if (hasCampaign) ...[
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Inspect campaign',
                              style: V2Tokens.t4(color: V2Tokens.inkPrussian),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 13,
                              color: V2Tokens.inkPrussian,
                            ),
                          ],
                        ),
                      ] else if (isUnread) ...[
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Mark read',
                              style: V2Tokens.t4(color: V2Tokens.inkPrussian),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: V2Tokens.inkPrussian,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

