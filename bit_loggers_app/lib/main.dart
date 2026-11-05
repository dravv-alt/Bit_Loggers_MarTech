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

    final currentScreen = _currentIndex < screens.length ? screens[_currentIndex] : screens[0];

    return Scaffold(
      backgroundColor: AppTheme.paper,
      appBar: AppBar(
        backgroundColor: AppTheme.paper,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'campaigngrid',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary.withOpacity(0.9),
                letterSpacing: -0.3,
              ),
            ),
            Text(
              formattedDate,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          // FR-13/14 Sync Hub & Outbox Pill / Button
          AnimatedBuilder(
            animation: _api.syncQueue,
            builder: (context, _) {
              final pending = _api.syncQueue.pendingCount;
              final isOffline = _api.syncQueue.isOfflineSimulationEnabled;
              if (pending == 0 && !isOffline) {
                return IconButton(
                  icon: const Icon(Icons.cloud_sync_outlined, size: 20, color: AppTheme.textPrimary),
                  tooltip: 'Sync Hub & Outbox (FR-13/14)',
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
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOffline ? const Color(0xFFFFEDD5) : AppTheme.verdictLime.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isOffline ? const Color(0xFFF97316) : AppTheme.verdictLimeDark,
                          width: 1,
                        ),
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
                            isOffline ? (pending > 0 ? '$pending off' : 'offline') : '$pending sync',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isOffline ? const Color(0xFF9A3412) : AppTheme.verdictLimeDark,
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

          // 14/14 Architecture Tests
          IconButton(
            icon: const Icon(Icons.shield_outlined, size: 20, color: AppTheme.textPrimary),
            tooltip: '14/14 Architecture Tests',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TestRunnerScreen(api: _api)),
              );
            },
          ),

          // Ledger & Diagnostics Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: AppTheme.textPrimary),
            tooltip: 'Governance & Audit',
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'sync_hub',
                child: Row(
                  children: [
                    Icon(Icons.cloud_sync, size: 16, color: AppTheme.forge),
                    SizedBox(width: 8),
                    Text('Sync hub & outbox', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'audit',
                child: Row(
                  children: [
                    Icon(Icons.history_edu, size: 16, color: AppTheme.forge),
                    SizedBox(width: 8),
                    Text('Append-only audit trail', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'diagnostics',
                child: Row(
                  children: [
                    Icon(Icons.terminal, size: 16, color: AppTheme.forge),
                    SizedBox(width: 8),
                    Text('Diagnostic vocabulary', style: TextStyle(fontSize: 13)),
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
                icon: const Icon(Icons.notifications_none_outlined, size: 20, color: AppTheme.textPrimary),
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
                      color: AppTheme.verdictLime,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),

          // User Profile Pill (SJ / AL / MV)
          PopupMenuButton<User>(
            tooltip: 'Switch User Role',
            itemBuilder: (context) {
              return _users.map((u) {
                return PopupMenuItem<User>(
                  value: u,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: u.role == 'marketer' ? AppTheme.forge : AppTheme.borderSage,
                        child: Text(
                          u.name.split(' ').map((n) => n[0]).take(2).join(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: u.role == 'marketer' ? AppTheme.leaf : AppTheme.textPrimary,
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
                decoration: BoxDecoration(
                  color: AppTheme.leaf,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.borderSage, width: 1),
                ),
                child: Center(
                  child: Text(
                    _api.currentUser.name.isNotEmpty
                        ? _api.currentUser.name.split(' ').map((n) => n[0]).take(2).join()
                        : 'SJ',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: currentScreen,
      // Floating Bottom Navigation in Dark Forge (#1B3029) matching the reference image!
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12, top: 4),
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: AppTheme.forge,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.forge.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  index: 0,
                  label: 'Home',
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                ),
                _buildNavItem(
                  index: 1,
                  label: isReviewer ? 'Review Queue' : 'Campaigns',
                  icon: isReviewer ? Icons.fact_check_outlined : Icons.view_kanban_outlined,
                  activeIcon: isReviewer ? Icons.fact_check : Icons.view_kanban,
                ),
                _buildNavItem(
                  index: 2,
                  label: 'Calendar',
                  icon: Icons.calendar_today_outlined,
                  activeIcon: Icons.calendar_today,
                ),
                _buildNavItem(
                  index: 3,
                  label: 'Insights',
                  icon: Icons.insights_outlined,
                  activeIcon: Icons.insights,
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
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.leaf.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? activeIcon : icon,
              size: 18,
              color: active ? AppTheme.verdictLime : AppTheme.leaf.withOpacity(0.6),
            ),
            if (active) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.leaf,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
