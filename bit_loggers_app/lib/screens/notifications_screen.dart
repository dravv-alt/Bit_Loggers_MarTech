import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'campaign_detail_screen.dart';

/// Campaign Notifications & Real-Time Alerts
/// Modeled directly on Apple HIG Notification Center standards.
class NotificationsScreen extends StatefulWidget {
  final ApiService api;

  const NotificationsScreen({super.key, required this.api});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _loading = true;
  String _filter = 'ALL'; // 'ALL', 'UNREAD', 'DECISIONS', 'FLIGHTS'

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

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  List<AppNotification> get _filteredNotifications {
    return _notifications.where((n) {
      if (_filter == 'UNREAD') return !n.isRead;
      final t = n.title.toLowerCase();
      final m = n.message.toLowerCase();
      if (_filter == 'DECISIONS') {
        return t.contains('approved') || m.contains('approved') || t.contains('changes') || m.contains('changes') || t.contains('reject') || m.contains('reject');
      }
      if (_filter == 'FLIGHTS') {
        return t.contains('flight') || m.contains('flight') || t.contains('schedule') || m.contains('schedule');
      }
      return true;
    }).toList();
  }

  String _formatRelative(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes.clamp(1, 59)} minutes ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours} hours ago';
      } else if (diff.inDays == 1) {
        return 'Yesterday, ${DateFormat('h:mm a').format(dt)}';
      } else {
        return DateFormat('d MMM, h:mm a').format(dt);
      }
    } catch (_) {
      return 'Recently';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.paper,
      appBar: AppBar(
        backgroundColor: AppTheme.leaf,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const Text(
              'Updates from across your workspace.',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Toolbar: All updates · X unread | Mark all read
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppTheme.secondarySystemBackground,
              border: Border(bottom: BorderSide(color: AppTheme.separator, width: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All updates  ·  $_unreadCount unread',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
                if (_unreadCount > 0)
                  InkWell(
                    onTap: _markAllRead,
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                  ),
              ],
            ),
          ),

          // Category Filter Bar
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('All', 'ALL', _notifications.length),
                const SizedBox(width: 6),
                _buildFilterChip('Unread', 'UNREAD', _unreadCount),
                const SizedBox(width: 6),
                _buildFilterChip('Decisions', 'DECISIONS', null),
                const SizedBox(width: 6),
                _buildFilterChip('Flights', 'FLIGHTS', null),
              ],
            ),
          ),

          // Notifications List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.forge))
                : _filteredNotifications.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.notifications_none, size: 36, color: AppTheme.textSecondary),
                              SizedBox(height: 12),
                              Text(
                                'No updates yet',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Reviews, changes, and flight launches will appear here.',
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
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                          itemCount: _filteredNotifications.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final notif = _filteredNotifications[idx];
                            return _buildNotificationCard(notif);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey, int? count) {
    final isSelected = _filter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _filter = filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.label : AppTheme.tertiarySystemBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.white : AppTheme.label,
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.25) : AppTheme.label.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppTheme.label,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(AppNotification notif) {
    final t = notif.title.toLowerCase();
    final m = notif.message.toLowerCase();
    if (t.contains('approved') || m.contains('approved')) return Icons.check_circle_outline_rounded;
    if (t.contains('changes') || m.contains('changes') || t.contains('review') || m.contains('review')) return Icons.rate_review_outlined;
    if (t.contains('reject') || m.contains('reject')) return Icons.cancel_outlined;
    if (t.contains('flight') || m.contains('flight') || t.contains('schedule') || m.contains('schedule')) return Icons.rocket_launch_outlined;
    if (t.contains('alert') || m.contains('alert') || t.contains('warning')) return Icons.warning_amber_rounded;
    return Icons.notifications_none_rounded;
  }

  Color _getCategoryColor(AppNotification notif) {
    final t = notif.title.toLowerCase();
    final m = notif.message.toLowerCase();
    if (t.contains('approved') || m.contains('approved')) return AppTheme.moss;
    if (t.contains('changes') || m.contains('changes')) return AppTheme.warmAmber;
    if (t.contains('reject') || m.contains('reject')) return AppTheme.statusRejected;
    if (t.contains('flight') || m.contains('flight') || t.contains('schedule') || m.contains('schedule')) return AppTheme.brandAccent;
    return AppTheme.forge;
  }

  Widget _buildNotificationCard(AppNotification notif) {
    final relTime = _formatRelative(notif.createdAt);
    final catColor = _getCategoryColor(notif);
    final catIcon = _getCategoryIcon(notif);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.secondarySystemBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.appleCardShadow,
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
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Visual Icon Avatar
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: catColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(catIcon, size: 16, color: catColor),
              ),
              const SizedBox(width: 10),

              // Content Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        if (!notif.isRead)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppTheme.brandAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          relTime,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (notif.campaignId != null)
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Inspect Flight',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.forge,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(Icons.arrow_forward_rounded, size: 10, color: AppTheme.forge),
                            ],
                          ),
                      ],
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
