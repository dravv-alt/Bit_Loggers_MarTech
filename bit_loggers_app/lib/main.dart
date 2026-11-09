import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/models.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'screens/kanban_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/audit_screen.dart';
import 'screens/diagnostics_screen.dart';
import 'screens/test_runner_screen.dart';
import 'screens/sync_hub_screen.dart';
import 'screens/campaign_detail_screen.dart';

void main() {
  runApp(const BitLoggersApp());
}

class BitLoggersApp extends StatelessWidget {
  const BitLoggersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampaignGrid — Bit Loggers',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.campaignGridTheme,
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final ApiService _api = ApiService();
  int _currentIndex = 0;
  List<User> _users = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    final tabParam = Uri.base.queryParameters['tab'];
    if (tabParam != null) {
      final parsed = int.tryParse(tabParam);
      if (parsed != null && parsed >= 0 && parsed <= 3) {
        _currentIndex = parsed;
      }
    }
    final roleParam = Uri.base.queryParameters['role'];
    if (roleParam != null && roleParam.toLowerCase() == 'reviewer') {
      _api.currentUser = User(
        id: 'usr-reviewer-1',
        name: 'Bob Miller (Reviewer)',
        email: 'bob.reviewer@bitloggers.com',
        role: 'reviewer',
      );
    }
    _initData();
  }

  Future<void> _initData() async {
    await _api.checkConnection();
    final u = await _api.getUsers();
    final n = await _api.getNotifications();
    if (mounted) {
      setState(() {
        _users = u;
        if (u.isNotEmpty && _api.currentUser.id.isEmpty) {
          _api.currentUser = u.first;
        }
        _unreadCount = n['unreadCount'] ?? 0;
      });
    }
  }

  void _switchUser(User user) {
    setState(() {
      _api.currentUser = user;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Operating as ${user.name} (${user.role})',
          style: const TextStyle(color: AppTheme.textInverse),
        ),
        backgroundColor: AppTheme.forge,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReviewer = _api.currentUser.role.toLowerCase() == 'reviewer';
    final formattedDate = DateFormat('EEEE, d MMMM').format(DateTime.now());

    // Navigation Screens matching the exact CampaignGrid spec:
    // 0: Home / Hub
    // 1: Campaigns / Review Queue
    // 2: Calendar
    // 3: Insights (Analytics & 5 KPIs)
    // Extra utilities accessible via top action menu: Audit, Diagnostics, 14 Tests
    final screens = [
      KanbanScreen(
        api: _api,
        onRefresh: _initData,
        isOverviewHub: true,
      ),
      KanbanScreen(
        api: _api,
        onRefresh: _initData,
        isOverviewHub: false,
      ),
      CalendarScreen(api: _api),
      AnalyticsScreen(api: _api),
    ];

    final screenParam = Uri.base.queryParameters['screen'];
    if (screenParam == 'detail') {
      return CampaignDetailScreen(
        campaignId: Uri.base.queryParameters['id'] ?? 'camp-03',
        api: _api,
      );
    }
    if (screenParam == 'sync') {
      return Scaffold(body: SyncHubScreen(api: _api));
    }
    if (screenParam == 'audit') {
      return Scaffold(body: AuditScreen(api: _api));
    }
    if (screenParam == 'diagnostics') {
      return Scaffold(body: DiagnosticsScreen(api: _api));
    }

    final currentScreen = _currentIndex < screens.length ? screens[_currentIndex] : screens[0];

    return Scaffold(
      backgroundColor: AppTheme.systemBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.secondarySystemBackground,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(color: AppTheme.separator, height: 0.5),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'CampaignGrid',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.label,
                letterSpacing: -0.4,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              formattedDate,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.secondaryLabel,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.05,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // Offline Sync Hub Button
          AnimatedBuilder(
            animation: _api.syncQueue,
            builder: (context, _) {
              final pending = _api.syncQueue.pendingCount;
              final isOffline = _api.syncQueue.isOfflineSimulationEnabled;
              if (pending == 0 && !isOffline) {
                return IconButton(
                  icon: const Icon(Icons.cloud_sync_outlined, size: 21, color: AppTheme.label),
                  tooltip: 'Sync hub',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SyncHubScreen(api: _api)),
                    );
                  },
                );
              }
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SyncHubScreen(api: _api)),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: isOffline ? const Color(0xFFFFEDD5) : AppTheme.verdictLime.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: AppTheme.appleCardShadow,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOffline ? Icons.wifi_off : Icons.sync,
                            size: 13,
                            color: isOffline ? const Color(0xFFC2410C) : AppTheme.verdictLimeDark,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOffline ? (pending > 0 ? '$pending pending' : 'offline') : '$pending sync',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isOffline ? const Color(0xFF9A3412) : AppTheme.verdictLimeDark,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // System Verification Tests
          IconButton(
            icon: const Icon(Icons.shield_outlined, size: 20, color: AppTheme.label),
            tooltip: 'System verification',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TestRunnerScreen(api: _api)),
              );
            },
          ),

          // Ledger & Diagnostics Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: AppTheme.label),
            tooltip: 'Governance & audit',
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'sync_hub',
                child: Row(
                  children: [
                    Icon(Icons.cloud_sync, size: 16, color: AppTheme.label),
                    SizedBox(width: 8),
                    Text('Sync hub & outbox', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'audit',
                child: Row(
                  children: [
                    Icon(Icons.history_edu, size: 16, color: AppTheme.label),
                    SizedBox(width: 8),
                    Text('Audit ledger', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'diagnostics',
                child: Row(
                  children: [
                    Icon(Icons.terminal, size: 16, color: AppTheme.label),
                    SizedBox(width: 8),
                    Text('Diagnostics', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
            onSelected: (val) {
              if (val == 'sync_hub') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => SyncHubScreen(api: _api)));
              } else if (val == 'audit') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => AuditScreen(api: _api)));
              } else if (val == 'diagnostics') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => DiagnosticsScreen(api: _api)));
              }
            },
          ),

          // Notifications Alert Bell
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_outlined, size: 20, color: AppTheme.label),
                tooltip: 'Notifications',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NotificationsScreen(api: _api)),
                  );
                  _initData();
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  top: 9,
                  right: 9,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.crimsonNeedle,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),

          // User Profile Pill (SJ / AL / MV)
          PopupMenuButton<User>(
            tooltip: 'Switch user role',
            itemBuilder: (context) {
              return _users.map((u) {
                return PopupMenuItem<User>(
                  value: u,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: u.role == 'marketer' ? AppTheme.label : AppTheme.tertiarySystemBackground,
                        child: Text(
                          u.name.split(' ').map((n) => n[0]).take(2).join(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: u.role == 'marketer' ? Colors.white : AppTheme.label,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${u.name} (${u.role})', style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                );
              }).toList();
            },
            onSelected: _switchUser,
            child: Padding(
              padding: const EdgeInsets.only(left: 4, right: 12),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppTheme.secondarySystemBackground,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.appleCardShadow,
                ),
                child: Center(
                  child: Text(
                    _api.currentUser.name.isNotEmpty
                        ? _api.currentUser.name.split(' ').map((n) => n[0]).take(2).join()
                        : 'SJ',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.label,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.appleCanvasGradient,
        ),
        child: currentScreen,
      ),
      // Bespoke Inset Tab Bar (Warm Ivory ground, Antique Hairline, Obsidian Umber active indicator)
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.secondarySystemBackground,
          border: Border(top: BorderSide(color: AppTheme.separator, width: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Color(0x0A2B2010),
              blurRadius: 12,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(
                  child: _buildNavItem(
                    index: 0,
                    label: 'Home',
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    index: 1,
                    label: isReviewer ? 'Review' : 'Campaigns',
                    icon: isReviewer ? Icons.fact_check_outlined : Icons.view_kanban_outlined,
                    activeIcon: isReviewer ? Icons.fact_check_rounded : Icons.view_kanban_rounded,
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    index: 2,
                    label: 'Calendar',
                    icon: Icons.calendar_today_outlined,
                    activeIcon: Icons.calendar_month_rounded,
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    index: 3,
                    label: 'Insights',
                    icon: Icons.insights_outlined,
                    activeIcon: Icons.insights_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final active = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: active ? 16 : 0, vertical: 3),
              decoration: BoxDecoration(
                color: active ? AppTheme.tertiarySystemBackground : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                active ? activeIcon : icon,
                size: 21,
                color: active ? AppTheme.label : AppTheme.secondaryLabel,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppTheme.label : AppTheme.secondaryLabel,
                letterSpacing: -0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
