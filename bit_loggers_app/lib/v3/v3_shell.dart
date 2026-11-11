import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../state/campaign_state_machine.dart';
import 'v3_analytics_view.dart';
import 'v3_calendar_view.dart';
import 'v3_components.dart';
import 'v3_detail_drawer.dart';
import 'v3_governance_view.dart';
import 'v3_notifications_view.dart';
import 'v3_pipeline_view.dart';
import 'v3_proposal_studio_modal.dart';
import 'v3_sidebar.dart';
import 'v3_tokens.dart';

class _ToastEntry {
  final String id;
  final String title;
  final String description;
  final String status;

  const _ToastEntry({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
  });
}

class _SectionMeta {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionMeta(this.title, this.subtitle, this.icon);
}

class V3Shell extends StatefulWidget {
  final ApiService api;
  final ValueChanged<String> onSwitchVersion;
  final bool isDark;
  final ValueChanged<bool> onToggleDark;
  final String initialSection;
  final String initialPipelineView;
  final String initialGovernanceTab;

  const V3Shell({
    super.key,
    required this.api,
    required this.onSwitchVersion,
    required this.isDark,
    required this.onToggleDark,
    this.initialSection = 'pipeline',
    this.initialPipelineView = 'board',
    this.initialGovernanceTab = 'audit',
  });

  @override
  State<V3Shell> createState() => _V3ShellState();
}

class _V3ShellState extends State<V3Shell> {
  static const Map<String, _SectionMeta> _meta = {
    'pipeline': _SectionMeta(
      'Pipeline',
      'Track versioned briefs across authoring, compliance review, and live flights.',
      Icons.view_kanban_outlined,
    ),
    'calendar': _SectionMeta(
      'Calendar',
      'Coordinate conflict-free channel windows bound to approved campaign versions.',
      Icons.calendar_today_outlined,
    ),
    'analytics': _SectionMeta(
      'Analytics',
      'Monitor projected vs actual ROI, conversion, and CPA performance across channels.',
      Icons.bar_chart_rounded,
    ),
    'notifications': _SectionMeta(
      'Notifications',
      'Real-time review decisions, revision requests, and scheduled flight alerts.',
      Icons.notifications_none_rounded,
    ),
    'governance': _SectionMeta(
      'Governance & QA',
      'Inspect audit transitions, transactional outbox retries, diagnostics, and 14 checks.',
      Icons.verified_user_outlined,
    ),
  };

  late String _activeSection;
  bool _mobileDrawerOpen = false;
  bool _loading = true;
  int _searchFocusTrigger = 0;

  List<User> _users = [];
  List<Campaign> _campaigns = [];
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;

  String? _inspectCampaignId;
  String _inspectInitialTab = 'overview';
  bool _studioOpen = false;
  Campaign? _editingCampaign;
  bool _deepLinkHandled = false;

  final List<_ToastEntry> _toasts = [];

  @override
  void initState() {
    super.initState();
    _activeSection = _meta.containsKey(widget.initialSection) ? widget.initialSection : 'pipeline';
    _loadWorkspace();
  }

  Future<void> _loadWorkspace() async {
    try {
      final results = await Future.wait([
        widget.api.getUsers(),
        widget.api.getCampaigns(),
        widget.api.getNotifications(),
      ]);
      if (!mounted) return;
      final notifsMap = results[2] as Map<String, dynamic>;
      setState(() {
        _users = results[0] as List<User>;
        _campaigns = results[1] as List<Campaign>;
        _notifications = (notifsMap['notifications'] as List<AppNotification>?) ?? [];
        _unreadCount = (notifsMap['unreadCount'] as int?) ?? 0;
        _loading = false;
      });
      _maybeHandleDeepLink();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _maybeHandleDeepLink() {
    if (_deepLinkHandled) return;
    _deepLinkHandled = true;
    final screen = Uri.base.queryParameters['screen'];
    final id = Uri.base.queryParameters['id'];
    if (screen == 'detail' && id != null && id.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _inspectInitialTab = Uri.base.queryParameters['dtab'] ?? 'overview';
          _inspectCampaignId = id;
        });
      });
    } else if (screen == 'studio') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _editingCampaign = null;
          _studioOpen = true;
        });
      });
    }
  }

  void _pushToast(String title, String description, [String status = 'information']) {
    final id = 't-${DateTime.now().microsecondsSinceEpoch}';
    if (!mounted) return;
    setState(() {
      _toasts.insert(0, _ToastEntry(id: id, title: title, description: description, status: status));
      if (_toasts.length > 3) _toasts.removeLast();
    });
    Timer(const Duration(milliseconds: 4200), () {
      if (mounted) {
        setState(() => _toasts.removeWhere((t) => t.id == id));
      }
    });
  }

  void _selectUser(User u) {
    setState(() => widget.api.currentUser = u);
    _loadWorkspace();
    _pushToast(
      'Operating as ${u.name}',
      'Active permissions switched to ${u.role} role.',
      'information',
    );
  }

  Future<void> _markNotificationRead(String id) async {
    await widget.api.markNotificationRead(id);
    await _loadWorkspace();
  }

  Future<void> _markAllRead() async {
    await widget.api.markAllNotificationsRead();
    await _loadWorkspace();
    _pushToast('Notifications cleared', 'All workspace dispatches marked as read.', 'success');
  }

  Future<void> _submitCampaign(String campaignId) async {
    try {
      await widget.api.submitCampaign(campaignId);
      await _loadWorkspace();
      _pushToast(
        'Submitted for review',
        'Brief locked to current version for reviewer signoff.',
        'success',
      );
    } catch (e) {
      _pushToast('Submission failed', e.toString(), 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.isDark ? V3Palette.dark : V3Palette.light;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1024;
    final isCompact = width < 640;
    final meta = _meta[_activeSection] ?? _meta['pipeline']!;
    final user = widget.api.currentUser;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_studioOpen) {
            setState(() {
              _studioOpen = false;
              _editingCampaign = null;
            });
          } else if (_inspectCampaignId != null) {
            setState(() => _inspectCampaignId = null);
          } else if (_mobileDrawerOpen) {
            setState(() => _mobileDrawerOpen = false);
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyL, control: true): () {
          setState(() {
            if (!isDesktop) _mobileDrawerOpen = true;
            _searchFocusTrigger++;
          });
        },
        const SingleActivator(LogicalKeyboardKey.keyL, meta: true): () {
          setState(() {
            if (!isDesktop) _mobileDrawerOpen = true;
            _searchFocusTrigger++;
          });
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: p.bgFull,
          body: SafeArea(
            child: Stack(
              children: [
                // Main Desktop Row or Mobile Body
                Padding(
                  padding: EdgeInsets.all(isDesktop ? 12 : 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isDesktop) ...[
                        V3Sidebar(
                          palette: p,
                          selectedSection: _activeSection,
                          onSelectSection: (s) => setState(() => _activeSection = s),
                          users: _users,
                          currentUser: user,
                          onSelectUser: _selectUser,
                          pipelineCount: _campaigns.length,
                          unreadCount: _unreadCount,
                          isDark: widget.isDark,
                          onToggleDark: widget.onToggleDark,
                          activeVersion: 'v3',
                          onSwitchVersion: widget.onSwitchVersion,
                          searchFocusTrigger: _searchFocusTrigger,
                        ),
                        const SizedBox(width: 16),
                      ],

                      // 1300px Max Centered Canvas
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1300),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildHeader(p, meta, user, isDesktop: isDesktop, isCompact: isCompact),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: _loading
                                      ? Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: p.accent500,
                                          ),
                                        )
                                      : SingleChildScrollView(
                                          padding: const EdgeInsets.only(bottom: 28),
                                          child: AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 160),
                                            switchInCurve: Curves.easeOutCubic,
                                            switchOutCurve: Curves.easeInCubic,
                                            child: KeyedSubtree(
                                              key: ValueKey(_activeSection),
                                              child: _buildActiveSection(p, user),
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Mobile Drawer Sidebar Overlay
                if (!isDesktop && _mobileDrawerOpen)
                  Positioned.fill(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _mobileDrawerOpen = false),
                          child: Container(color: Colors.black.withOpacity(0.45)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: V3Sidebar(
                            palette: p,
                            mobileDrawer: true,
                            onCloseDrawer: () => setState(() => _mobileDrawerOpen = false),
                            selectedSection: _activeSection,
                            onSelectSection: (s) => setState(() => _activeSection = s),
                            users: _users,
                            currentUser: user,
                            onSelectUser: _selectUser,
                            pipelineCount: _campaigns.length,
                            unreadCount: _unreadCount,
                            isDark: widget.isDark,
                            onToggleDark: widget.onToggleDark,
                            activeVersion: 'v3',
                            onSwitchVersion: widget.onSwitchVersion,
                            searchFocusTrigger: _searchFocusTrigger,
                          ),
                        ),
                      ],
                    ),
                  ),

            // Detail Slide-Over Drawer
            if (_inspectCampaignId != null)
              Positioned.fill(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _inspectCampaignId = null),
                      child: Container(color: Colors.black.withOpacity(0.42)),
                    ),
                    V3DetailDrawer(
                      key: ValueKey('drawer-$_inspectCampaignId-$_inspectInitialTab'),
                      api: widget.api,
                      palette: p,
                      campaignId: _inspectCampaignId!,
                      initialTab: _inspectInitialTab,
                      onClose: () => setState(() => _inspectCampaignId = null),
                      onEditCampaign: (c) => setState(() {
                        _editingCampaign = c;
                        _studioOpen = true;
                      }),
                      onMutated: _loadWorkspace,
                      onNotify: _pushToast,
                    ),
                  ],
                ),
              ),

            // Proposal Studio Modal
            if (_studioOpen)
              Positioned.fill(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() {
                        _studioOpen = false;
                        _editingCampaign = null;
                      }),
                      child: Container(color: Colors.black.withOpacity(0.45)),
                    ),
                    V3ProposalStudioModal(
                      api: widget.api,
                      palette: p,
                      campaign: _editingCampaign,
                      onClose: () => setState(() {
                        _studioOpen = false;
                        _editingCampaign = null;
                      }),
                      onSaved: _loadWorkspace,
                      onNotify: _pushToast,
                    ),
                  ],
                ),
              ),

            // Bottom-Right BoardUI Toasts
            if (_toasts.isNotEmpty)
              Positioned(
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _toasts.map((t) {
                    final tone = t.status == 'success'
                        ? 'lime'
                        : t.status == 'error'
                            ? 'rose'
                            : 'blue';
                    final c = p.chipColors(tone);
                    return Container(
                      width: 320,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: p.bgPrimary,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: p.borderDefault),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.14),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
                            child: Icon(
                              t.status == 'error'
                                  ? Icons.error_outline_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 14,
                              color: c.fg,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.title, style: V3Tokens.bodyMedium(p)),
                                Text(t.description, style: V3Tokens.caption(p)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _toasts.removeWhere((x) => x.id == t.id)),
                            child: Icon(Icons.close_rounded, size: 15, color: p.iconSecondary),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    ),
    ),
    );
  }

  Widget _buildHeader(
    V3Palette p,
    _SectionMeta meta,
    User user, {
    required bool isDesktop,
    required bool isCompact,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumb Row
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(Icons.dashboard_outlined, size: 14, color: p.iconSecondary),
            Text('CampaignGrid v3', style: V3Tokens.caption(p)),
            Icon(Icons.chevron_right_rounded, size: 14, color: p.textTertiary),
            Text(V3Tokens.cleanPersonName(user.name), style: V3Tokens.caption(p)),
            Icon(Icons.chevron_right_rounded, size: 14, color: p.textTertiary),
            Icon(meta.icon, size: 14, color: p.textPrimary),
            Text(meta.title, style: V3Tokens.caption(p, color: p.textPrimary, weight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),

        // Title + Actions Row
        LayoutBuilder(
          builder: (context, constraints) {
            final leftTitle = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isDesktop) ...[
                  InkWell(
                    onTap: () => setState(() => _mobileDrawerOpen = true),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: p.bgSecondary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: p.borderDefault),
                      ),
                      child: Icon(Icons.menu_rounded, size: 19, color: p.iconPrimary),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(meta.title, style: V3Tokens.title1(p)),
                          const SizedBox(width: 8),
                          V3Badge(label: 'v3', palette: p, primary: true),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta.subtitle,
                        style: V3Tokens.bodyRegular(p),
                      ),
                    ],
                  ),
                ),
              ],
            );

            final rightActions = Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                V3VersionSwitcher(
                  activeVersion: 'v3',
                  onSelectVersion: widget.onSwitchVersion,
                  palette: p,
                  compact: isCompact,
                ),
                if (!isDesktop)
                  InkWell(
                    onTap: () => widget.onToggleDark(!widget.isDark),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: p.bgPrimary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: p.borderDefault),
                      ),
                      child: Icon(
                        widget.isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                        size: 17,
                        color: p.iconPrimary,
                      ),
                    ),
                  ),
                _buildBellButton(p),
                if (CampaignStateMachine.canCreateCampaign(user))
                  V3Button(
                    label: 'New brief',
                    icon: Icons.add_rounded,
                    variant: V3ButtonVariant.primary,
                    small: isCompact,
                    palette: p,
                    onTap: () => setState(() {
                      _editingCampaign = null;
                      _studioOpen = true;
                    }),
                  ),
              ],
            );

            if (constraints.maxWidth >= 720) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: leftTitle),
                  const SizedBox(width: 12),
                  rightActions,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leftTitle,
                const SizedBox(height: 10),
                rightActions,
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildBellButton(V3Palette p) {
    return PopupMenuButton<String>(
      tooltip: 'Workspace notifications',
      color: p.bgPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.borderDefault),
      ),
      onSelected: (val) {
        if (val == 'all') {
          setState(() => _activeSection = 'notifications');
        } else if (val == 'mark_all') {
          _markAllRead();
        } else {
          for (final n in _notifications) {
            if (n.notificationId == val) {
              if (!n.isRead) _markNotificationRead(n.notificationId);
              if (n.campaignId != null && n.campaignId!.isNotEmpty) {
                setState(() {
                  _inspectInitialTab = 'overview';
                  _inspectCampaignId = n.campaignId;
                });
              }
              break;
            }
          }
        }
      },
      itemBuilder: (_) => [
        ..._notifications.take(4).map((n) => PopupMenuItem<String>(
              value: n.notificationId,
              child: SizedBox(
                width: 260,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (!n.isRead)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(color: p.accent500, shape: BoxShape.circle),
                          ),
                        Expanded(
                          child: Text(
                            n.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: V3Tokens.bodyMedium(p),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      n.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: V3Tokens.caption(p),
                    ),
                  ],
                ),
              ),
            )),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'all',
          child: Text('Open notification center', style: V3Tokens.bodyMedium(p, color: p.accentText)),
        ),
        if (_unreadCount > 0)
          PopupMenuItem<String>(
            value: 'mark_all',
            child: Text('Mark all read', style: V3Tokens.caption(p)),
          ),
      ],
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: p.bgPrimary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.borderDefault),
            ),
            child: Icon(Icons.notifications_none_rounded, size: 18, color: p.iconPrimary),
          ),
          if (_unreadCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveSection(V3Palette p, User user) {
    switch (_activeSection) {
      case 'calendar':
        return V3CalendarView(
          api: widget.api,
          palette: p,
          onInspectCampaign: (cid) => setState(() {
            _inspectInitialTab = 'overview';
            _inspectCampaignId = cid;
          }),
        );
      case 'analytics':
        return V3AnalyticsView(api: widget.api, palette: p);
      case 'notifications':
        return V3NotificationsView(
          notifications: _notifications,
          unreadCount: _unreadCount,
          palette: p,
          onMarkRead: _markNotificationRead,
          onMarkAllRead: _markAllRead,
          onInspectCampaign: (cid) => setState(() {
            _inspectInitialTab = 'overview';
            _inspectCampaignId = cid;
          }),
          onRefresh: _loadWorkspace,
        );
      case 'governance':
        return V3GovernanceView(
          api: widget.api,
          palette: p,
          initialTab: widget.initialGovernanceTab,
          onInspectCampaign: (cid) => setState(() {
            _inspectInitialTab = 'overview';
            _inspectCampaignId = cid;
          }),
          onNotify: _pushToast,
        );
      default:
        return V3PipelineView(
          campaigns: _campaigns,
          currentUser: user,
          palette: p,
          initialViewMode: widget.initialPipelineView,
          onInspectCampaign: (cid, {initialTab = 'overview'}) => setState(() {
            _inspectInitialTab = initialTab;
            _inspectCampaignId = cid;
          }),
          onEditCampaign: (camp) => setState(() {
            _editingCampaign = camp;
            _studioOpen = true;
          }),
          onSubmitCampaign: _submitCampaign,
        );
    }
  }
}
