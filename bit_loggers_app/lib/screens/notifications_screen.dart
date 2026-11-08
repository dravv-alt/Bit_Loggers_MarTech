import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'campaign_detail_screen.dart';

/// FR-11: Campaign Notifications & Real-Time Alerts
/// Modeled directly on Framer Wireframes (Screen 7: Notifications).
/// "No multiple subtexts, no pills, and no BS clear design."
class NotificationsScreen extends StatefulWidget {
  final ApiService api;

  const NotificationsScreen({super.key, required this.api});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _loading = true;

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
              color: AppTheme.leaf,
              border: Border(bottom: BorderSide(color: AppTheme.borderSage, width: 1)),
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

          // Notifications List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.forge))
                : _notifications.isEmpty
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
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                          itemCount: _notifications.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final notif = _notifications[idx];
                            return _buildNotificationCard(notif);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notif) {
    final relTime = _formatRelative(notif.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.leaf,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: notif.isRead ? AppTheme.borderSage : AppTheme.forge.withOpacity(0.3),
          width: 1,
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
            );
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(14),
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
              Text(
                relTime,
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
