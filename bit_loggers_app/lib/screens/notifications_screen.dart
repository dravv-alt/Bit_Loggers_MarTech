import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'campaign_detail_screen.dart';

/// FR-11: Campaign Notifications & Real-Time Alerts (ADR-004)
/// Centralized operational alert hub with transactional outbox delivery,
/// unread tracking, mention notifications, and quick campaign navigation.
class NotificationsScreen extends StatefulWidget {
  final ApiService api;

  const NotificationsScreen({super.key, required this.api});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _loading = true;
  String _filter = 'ALL'; // 'ALL', 'UNREAD'

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await widget.api.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = res['notifications'] as List<AppNotification>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await widget.api.markAllNotificationsRead();
      _fetch();
    } catch (_) {}
  }

  List<AppNotification> get _filteredNotifications {
    if (_filter == 'UNREAD') {
      return _notifications.where((n) => !n.isRead).toList();
    }
    return _notifications;
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
      case 'urgent':
        return AppTheme.statusRejected;
      case 'medium':
        return const Color(0xFFB45309);
      default:
        return AppTheme.forge;
    }
  }

  IconData _getNotificationIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('approved')) return Icons.check_circle_outline;
    if (t.contains('rejected') || t.contains('blocked')) return Icons.cancel_outlined;
    if (t.contains('change')) return Icons.edit_note_outlined;
    if (t.contains('submitted') || t.contains('review')) return Icons.send_outlined;
    if (t.contains('mention')) return Icons.alternate_email;
    return Icons.notifications_active_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredNotifications;

    return Scaffold(
      backgroundColor: AppTheme.paper,
      appBar: AppBar(
        backgroundColor: AppTheme.paper,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.forge),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alerts & Notifications',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              '${_notifications.length} total • $_unreadCount unread',
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all, size: 16, color: AppTheme.forge),
              label: const Text(
                'Mark read',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.forge),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.forge),
            tooltip: 'Refresh',
            onPressed: _fetch,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loading)
            const LinearProgressIndicator(
              minHeight: 2.5,
              color: AppTheme.forge,
              backgroundColor: AppTheme.borderSage,
            ),

          // Filter bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: AppTheme.paper,
              border: Border(bottom: BorderSide(color: AppTheme.borderSage, width: 1)),
            ),
            child: Row(
              children: [
                _buildFilterChip('All Alerts (${_notifications.length})', 'ALL'),
                const SizedBox(width: 8),
                _buildFilterChip('Unread ($_unreadCount)', 'UNREAD'),
              ],
            ),
          ),

          // List
          Expanded(
            child: items.isEmpty && !_loading
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.notifications_none_outlined, size: 48, color: AppTheme.textSecondary),
                          const SizedBox(height: 12),
                          Text(
                            _filter == 'UNREAD' ? 'Zero Unread Alerts' : 'No Notifications Yet',
                            style: const TextStyle(fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Submissions, reviewer decisions, discussions, and @mentions will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetch,
                    color: AppTheme.forge,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: items.length,
                      itemBuilder: (context, idx) {
                        final notif = items[idx];
                        return _buildNotificationCard(notif);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String key) {
    final isSelected = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.forge : AppTheme.leaf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderSage, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppTheme.leaf : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notif) {
    final priorityColor = _getPriorityColor(notif.priority);
    final notifIcon = _getNotificationIcon(notif.title);

    DateTime? created;
    try {
      created = DateTime.parse(notif.createdAt).toLocal();
    } catch (_) {}

    final dateStr = created != null
        ? DateFormat('d MMM • HH:mm').format(created)
        : notif.createdAt;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: notif.isRead ? AppTheme.borderSage : AppTheme.forge.withOpacity(0.5),
          width: notif.isRead ? 1 : 1.5,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (notif.campaignId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CampaignDetailScreen(
                  campaignId: notif.campaignId!,
                  api: widget.api,
                ),
              ),
            ).then((_) => _fetch());
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Channel & Priority Tags + Date + Unread Dot
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.forge.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          notif.channel.toUpperCase(),
                          style: const TextStyle(color: AppTheme.forge, fontWeight: FontWeight.bold, fontSize: 9),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          notif.priority.toUpperCase(),
                          style: TextStyle(color: priorityColor, fontWeight: FontWeight.bold, fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(dateStr, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                      if (!notif.isRead) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.verdictLimeDark,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title with Icon
              Row(
                children: [
                  Icon(notifIcon, size: 16, color: AppTheme.forge),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      notif.title,
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 14,
                        fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Message Body
              Text(
                notif.message,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
              ),

              if (notif.campaignId != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Open proposal dossier →',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.forge.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
