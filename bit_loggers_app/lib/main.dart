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
import 'v2/v2_shell.dart';
import 'v2/v2_tokens.dart';
import 'v3/v3_shell.dart';
import 'v3/v3_tokens.dart';

void main() {
  runApp(const BitLoggersApp());
}

class BitLoggersApp extends StatefulWidget {
  const BitLoggersApp({super.key});

  @override
  State<BitLoggersApp> createState() => _BitLoggersAppState();
}

class _BitLoggersAppState extends State<BitLoggersApp> {
  final ApiService _sharedApi = ApiService();
  late String _appVersion; // 'v1' | 'v2' | 'v3'
  bool _v3Dark = false;

  @override
  void initState() {
    super.initState();
    final vParam = Uri.base.queryParameters['v'];
    final themeParam = Uri.base.queryParameters['theme'];
    if (vParam == '1') {
      _appVersion = 'v1';
    } else if (vParam == '3') {
      _appVersion = 'v3';
    } else if (vParam == '2') {
      _appVersion = 'v2';
    } else if (themeParam != null && themeParam.isNotEmpty) {
      _appVersion = 'v1';
    } else {
      _appVersion = 'v2';
    }

    final darkParam = Uri.base.queryParameters['dark'] ?? Uri.base.queryParameters['mode'];
    if (darkParam == '1' || darkParam == 'dark') {
      _v3Dark = true;
    }

    if (themeParam != null && themeParam.isNotEmpty) {
      AppTheme.setThemeById(themeParam);
    }

    final roleParam = Uri.base.queryParameters['role'];
    if (roleParam != null && roleParam.toLowerCase() == 'reviewer') {
      _sharedApi.currentUser = User(
        id: 'usr-reviewer-1',
        name: 'Marcus Vance (Reviewer)',
        email: 'marcus.reviewer@bitloggers.com',
        role: 'reviewer',
      );
    }
  }

  void _setAppVersion(String version) {
    setState(() => _appVersion = version);
  }

  String _v3SectionFromQuery() {
    final tab = Uri.base.queryParameters['tab'] ?? '0';
    switch (tab) {
      case '1':
      case 'calendar':
        return 'calendar';
      case '2':
      case 'analytics':
        return 'analytics';
      case '3':
      case 'notifications':
        return 'notifications';
      case '4':
      case 'governance':
        return 'governance';
      default:
        return 'pipeline';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabParam = int.tryParse(Uri.base.queryParameters['tab'] ?? '') ?? 0;

    return ValueListenableBuilder<CgTokens>(
      valueListenable: AppTheme.activeThemeNotifier,
      builder: (context, currentTokens, _) {
        final v3Palette = _v3Dark ? V3Palette.dark : V3Palette.light;
        final ThemeData activeTheme;
        final Widget activeHome;

        if (_appVersion == 'v3') {
          activeTheme = V3Tokens.buildThemeData(v3Palette);
          activeHome = V3Shell(
            api: _sharedApi,
            onSwitchVersion: _setAppVersion,
            isDark: _v3Dark,
            onToggleDark: (dark) => setState(() => _v3Dark = dark),
            initialSection: _v3SectionFromQuery(),
            initialPipelineView: Uri.base.queryParameters['pview'] ?? 'board',
            initialGovernanceTab: Uri.base.queryParameters['gtab'] ?? 'audit',
          );
        } else if (_appVersion == 'v2') {
          activeTheme = V2Tokens.buildThemeData();
          activeHome = V2Shell(
            api: _sharedApi,
            initialTab: tabParam,
            onSwitchVersion: _setAppVersion,
          );
        } else {
          activeTheme = AppTheme.campaignGridTheme;
          activeHome = MainShell(
            api: _sharedApi,
            onSwitchVersion: _setAppVersion,
          );
        }

        return MaterialApp(
          title: 'CampaignGrid — Bit Loggers',
          debugShowCheckedModeBanner: false,
          theme: activeTheme,
          home: activeHome,
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  final ApiService? api;
  final ValueChanged<String>? onSwitchVersion;

  const MainShell({super.key, this.api, this.onSwitchVersion});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final ApiService _api;
  int _currentIndex = 0;
  List<User> _users = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiService();
    final themeParam = Uri.base.queryParameters['theme'];
    if (themeParam != null && themeParam.isNotEmpty) {
      AppTheme.setThemeById(themeParam);
    }
    final tabParam = Uri.base.queryParameters['tab'];
    if (tabParam != null) {
      final parsed = int.tryParse(tabParam);
      if (parsed != null && parsed >= 0 && parsed <= 3) {
        _currentIndex = parsed;
      }
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
          style: TextStyle(color: AppTheme.page, fontWeight: FontWeight.w500),
        ),
        backgroundColor: AppTheme.textPrimary,
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
    final isCompact = MediaQuery.of(context).size.width < 680;

    return Scaffold(
      backgroundColor: AppTheme.systemBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 14,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(AppTheme.tokens.structuralRuleWidth),
          child: Divider(
            color: AppTheme.hairline,
            height: AppTheme.tokens.structuralRuleWidth,
            thickness: AppTheme.tokens.structuralRuleWidth,
          ),
        ),
        title: Row(
          children: [
            AppTheme.buildBrandMonogram(size: 28),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CampaignGrid',
                    style: TextStyle(
                      fontSize: isCompact ? 16 : 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Quick 3-Way Version Switcher (v1 | v2 | v3)
          if (widget.onSwitchVersion != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppTheme.well,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppTheme.hairline,
                      width: AppTheme.tokens.structuralRuleWidth,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: ['v1', 'v2', 'v3'].map((v) {
                      final isSel = v == 'v1';
                      return GestureDetector(
                        onTap: isSel ? null : () => widget.onSwitchVersion?.call(v),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: isSel ? AppTheme.accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            v,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isSel ? AppTheme.onAccent : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

          // Theme Switcher Dropdown (Compact cue on mobile, full name on desktop)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ValueListenableBuilder<CgTokens>(
              valueListenable: AppTheme.activeThemeNotifier,
              builder: (context, currentTheme, _) {
                return PopupMenuButton<String>(
                  tooltip: 'Switch theme',
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(currentTheme.radiusControl),
                    side: BorderSide(color: currentTheme.hairline, width: currentTheme.structuralRuleWidth),
                  ),
                  color: currentTheme.card,
                  offset: const Offset(0, 42),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: currentTheme.well,
                      borderRadius: BorderRadius.circular(currentTheme.radiusControl),
                      border: Border.all(color: currentTheme.hairline, width: currentTheme.structuralRuleWidth),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: currentTheme.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isCompact ? currentTheme.shortName : currentTheme.name,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: currentTheme.text,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.arrow_drop_down, size: 15, color: currentTheme.textSecondary),
                      ],
                    ),
                  ),
                  itemBuilder: (context) => AppTheme.availableThemes.map((theme) {
                    final isSelected = theme.id == currentTheme.id;
                    return PopupMenuItem<String>(
                      value: theme.id,
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: theme.accent,
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.hairline, width: 0.5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  theme.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? theme.accent : currentTheme.text,
                                  ),
                                ),
                                Text(
                                  theme.subtitle,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: currentTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check, size: 16, color: theme.accent),
                        ],
                      ),
                    );
                  }).toList(),
                  onSelected: (themeId) {
                    AppTheme.setThemeById(themeId);
                    setState(() {});
                  },
                );
              },
            ),
          ),

          // Offline Sync Hub (full icon/badge on wide screens, or warning badge when pending/offline on mobile)
          AnimatedBuilder(
            animation: _api.syncQueue,
            builder: (context, _) {
              final pending = _api.syncQueue.pendingCount;
              final isOffline = _api.syncQueue.isOfflineSimulationEnabled;
              if (pending == 0 && !isOffline) {
                if (isCompact) return const SizedBox.shrink();
                return IconButton(
                  icon: Icon(Icons.cloud_sync_outlined, size: 20, color: AppTheme.textPrimary),
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
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SyncHubScreen(api: _api)),
                      );
                    },
                    borderRadius: BorderRadius.circular(AppTheme.tokens.radiusControl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOffline ? AppTheme.warning.withOpacity(0.16) : AppTheme.approved.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(AppTheme.tokens.radiusControl),
                        border: Border.all(
                          color: isOffline ? AppTheme.warning : AppTheme.approved,
                          width: 0.75,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOffline ? Icons.wifi_off_rounded : Icons.sync_rounded,
                            size: 12,
                            color: isOffline ? AppTheme.warning : AppTheme.approved,
                          ),
                          if (!isCompact || pending > 0) ...[
                            const SizedBox(width: 3),
                            Text(
                              isOffline ? (pending > 0 ? '$pending' : 'Offline') : '$pending',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: isOffline ? AppTheme.warning : AppTheme.approved,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // System Verification Tests (wide screens only; grouped into More menu on mobile)
          if (!isCompact)
            IconButton(
              icon: Icon(Icons.shield_outlined, size: 20, color: AppTheme.textPrimary),
              tooltip: 'System verification',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TestRunnerScreen(api: _api)),
                );
              },
            ),

          // Notifications Alert Bell
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                padding: EdgeInsets.all(isCompact ? 6 : 8),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(Icons.notifications_none_rounded, size: 20, color: AppTheme.textPrimary),
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
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppTheme.collision,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),

          // Workspace Tools Menu (Sync, Verification, Audit Ledger, Diagnostics)
          PopupMenuButton<String>(
            padding: EdgeInsets.all(isCompact ? 6 : 8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Icon(Icons.more_horiz, size: 20, color: AppTheme.textPrimary),
            color: AppTheme.card,
            tooltip: 'Workspace tools & audit',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.tokens.radiusCard),
              side: BorderSide(color: AppTheme.hairline, width: AppTheme.tokens.structuralRuleWidth),
            ),
            itemBuilder: (context) => [
              if (widget.onSwitchVersion != null) ...[
                PopupMenuItem(
                  value: 'switch_v2',
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_mosaic_outlined, size: 16, color: AppTheme.accent),
                      const SizedBox(width: 8),
                      Text('Switch to v2 workspace',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'switch_v3',
                  child: Row(
                    children: [
                      Icon(Icons.layers_rounded, size: 16, color: AppTheme.social),
                      const SizedBox(width: 8),
                      Text('Switch to v3 BoardUI',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
              ],
              PopupMenuItem(
                value: 'sync_hub',
                child: Row(
                  children: [
                    Icon(Icons.cloud_sync_rounded, size: 16, color: AppTheme.social),
                    const SizedBox(width: 8),
                    Text('Sync hub & outbox', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'tests',
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: AppTheme.approved),
                    const SizedBox(width: 8),
                    Text('System verification', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'audit',
                child: Row(
                  children: [
                    Icon(Icons.history_edu_rounded, size: 16, color: AppTheme.warning),
                    const SizedBox(width: 8),
                    Text('Audit ledger', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'diagnostics',
                child: Row(
                  children: [
                    Icon(Icons.terminal_rounded, size: 16, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    Text('Diagnostics', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                  ],
                ),
              ),
            ],
            onSelected: (val) {
              if (val == 'switch_v2') {
                widget.onSwitchVersion?.call('v2');
              } else if (val == 'switch_v3') {
                widget.onSwitchVersion?.call('v3');
              } else if (val == 'sync_hub') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => SyncHubScreen(api: _api)));
              } else if (val == 'tests') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => TestRunnerScreen(api: _api)));
              } else if (val == 'audit') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => AuditScreen(api: _api)));
              } else if (val == 'diagnostics') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => DiagnosticsScreen(api: _api)));
              }
            },
          ),

          // User Profile Pill
          PopupMenuButton<User>(
            tooltip: 'Switch user role',
            color: AppTheme.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.tokens.radiusCard),
              side: BorderSide(color: AppTheme.hairline, width: AppTheme.tokens.structuralRuleWidth),
            ),
            itemBuilder: (context) {
              return _users.map((u) {
                final isMarketer = u.role == 'marketer';
                return PopupMenuItem<User>(
                  value: u,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: isMarketer ? AppTheme.accent : AppTheme.social,
                        child: Text(
                          u.name.split(' ').map((n) => n[0]).take(2).join(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isMarketer ? AppTheme.onAccent : Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${u.name} (${u.role})', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                    ],
                  ),
                );
              }).toList();
            },
            onSelected: _switchUser,
            child: Padding(
              padding: const EdgeInsets.only(left: 2, right: 12),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.well,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.hairline, width: AppTheme.tokens.structuralRuleWidth),
                ),
                child: Center(
                  child: Text(
                    _api.currentUser.name.isNotEmpty
                        ? _api.currentUser.name.split(' ').map((n) => n[0]).take(2).join()
                        : 'SJ',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        color: AppTheme.page,
        child: currentScreen,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.card,
          border: Border(top: BorderSide(color: AppTheme.hairline, width: AppTheme.tokens.structuralRuleWidth)),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
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
                color: active ? AppTheme.well : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.tokens.radiusControl),
                border: active
                    ? Border.all(color: AppTheme.accent.withOpacity(0.35), width: AppTheme.tokens.structuralRuleWidth)
                    : null,
              ),
              child: Icon(
                active ? activeIcon : icon,
                size: 20,
                color: active ? AppTheme.accent : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppTheme.accent : AppTheme.textSecondary,
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
