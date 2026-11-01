import 'package:flutter/material.dart';
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

void main() {
  runApp(const BitLoggersApp());
}

class BitLoggersApp extends StatelessWidget {
  const BitLoggersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bit Loggers MarTech Platform',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
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
    setState(() {
      _users = u;
      if (u.isNotEmpty) _api.currentUser = u.first;
      _unreadCount = n['unreadCount'] ?? 0;
    });
  }

  void _switchUser(User user) {
    setState(() {
      _api.currentUser = user;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched profile to ${user.name} (${user.role.toUpperCase()})'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      KanbanScreen(api: _api, onRefresh: _initData),
      CalendarScreen(api: _api),
      AnalyticsScreen(api: _api),
      AuditScreen(api: _api),
      DiagnosticsScreen(api: _api),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, Color(0xFF0284C7)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('⚡', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Bit Loggers',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'MarTech Platform',
                    style: TextStyle(fontSize: 9, color: AppTheme.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Architecture Tests shortcut
          IconButton(
            icon: const Icon(Icons.verified_user_outlined, color: Color(0xFF10B981)),
            tooltip: '14/14 Architecture Tests',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TestRunnerScreen(api: _api)),
              );
            },
          ),

          // Notifications Bell
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_outlined),
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
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                    child: Text(
                      '$_unreadCount',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
            ],
          ),

          // Role Switcher Menu
          PopupMenuButton<User>(
            tooltip: 'Switch User Role',
            itemBuilder: (context) {
              return _users.map((u) {
                return PopupMenuItem<User>(
                  value: u,
                  child: Row(
                    children: [
                      Icon(
                        u.role == 'marketer' ? Icons.edit_note : Icons.shield_outlined,
                        size: 16,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text('${u.name} (${u.role})', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                );
              }).toList();
            },
            onSelected: _switchUser,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: AppTheme.primary,
                    child: Text(
                      _api.currentUser.name.substring(0, 1),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.primary.withOpacity(0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppTheme.primary),
            label: 'Kanban',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: AppTheme.primary),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics, color: AppTheme.primary),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_tree_outlined),
            selectedIcon: Icon(Icons.account_tree, color: AppTheme.primary),
            label: 'Audit',
          ),
          NavigationDestination(
            icon: Icon(Icons.terminal_outlined),
            selectedIcon: Icon(Icons.terminal, color: AppTheme.primary),
            label: 'Diagnostics',
          ),
        ],
      ),
    );
  }
}
