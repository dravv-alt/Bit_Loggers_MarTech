import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'v2_activity_screen.dart';
import 'v2_calendar_screen.dart';
import 'v2_components.dart';
import 'v2_detail_diff_spend.dart';
import 'v2_diagnostics_screen.dart';
import 'v2_insights_screen.dart';
import 'v2_mappers.dart';
import 'v2_notifications_screen.dart';
import 'v2_pipeline_screen.dart';
import 'v2_sheets.dart';
import 'v2_sync_hub_screen.dart';
import 'v2_tokens.dart';
import 'v2_verification_screen.dart';

/// Unified interactive shell for CampaignGrid v2 ("The Perforated Ledger & Facet Instrument").
class V2Shell extends StatefulWidget {
  final ApiService api;
  final ValueChanged<String> onSwitchVersion;
  final int initialTab;

  const V2Shell({
    super.key,
    required this.api,
    required this.onSwitchVersion,
    this.initialTab = 0,
  });

  @override
  State<V2Shell> createState() => _V2ShellState();
}

class _V2ShellState extends State<V2Shell> {
  String _activeTab = 'pipeline'; // 'pipeline' | 'calendar' | 'insights' | 'activity'
  String _pipelineFilter = 'review';
  List<Campaign> _campaigns = [];
  List<ScheduleEvent> _calendarEvents = [];
  List<AuditEventItem> _auditEvents = [];
  List<User> _users = [];
  int _unreadCount = 0;
  bool _loading = true;
  int _leaseSeconds = 202;
  Timer? _leaseTimer;
  String? _initialDeepLinkHandled;

  @override
  void initState() {
    super.initState();
    const tabMap = ['pipeline', 'calendar', 'insights', 'activity'];
    if (widget.initialTab >= 0 && widget.initialTab < tabMap.length) {
      _activeTab = tabMap[widget.initialTab];
    }
    _leaseTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _leaseSeconds = _leaseSeconds > 1 ? _leaseSeconds - 1 : 202);
      }
    });
    _loadAll();
  }

  @override
  void dispose() {
    _leaseTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        widget.api.getCampaigns(),
        widget.api.getCalendar(),
        widget.api.getAudit(),
        widget.api.getUsers(),
        widget.api.getNotifications(),
      ]);
      if (!mounted) return;
      final camps = results[0] as List<Campaign>;
      final cal = results[1] as List<ScheduleEvent>;
      final aud = results[2] as List<AuditEventItem>;
      final usrs = results[3] as List<User>;
      final notifs = results[4] as Map<String, dynamic>;

      setState(() {
        _campaigns = camps;
        _calendarEvents = cal;
        _auditEvents = aud;
        _users = usrs;
        _unreadCount = (notifs['unreadCount'] as int?) ?? 0;
        _loading = false;
        // If current filter has 0 items on initial load, switch smoothly to 'all'
        if (_pipelineFilter == 'review' &&
            camps.where((c) => V2Tokens.normalizeStatusKey(c.status) == 'review').isEmpty &&
            camps.isNotEmpty) {
          _pipelineFilter = 'all';
        }
      });

      _maybeOpenDeepLinkedScreen();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _maybeOpenDeepLinkedScreen() {
    final screen = Uri.base.queryParameters['screen'];
    if (screen == null || screen.isEmpty || _initialDeepLinkHandled == screen) return;
    _initialDeepLinkHandled = screen;

    if (screen == 'notifications') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openNotifications();
      });
      return;
    }
    if (screen == 'sync') {
      final initialSec = Uri.base.queryParameters['section'] == 'outbox' ? 1 : 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => V2SyncHubScreen(
              api: widget.api,
              initialSectionIndex: initialSec,
            ),
          ),
        ).then((_) => _loadAll());
      });
      return;
    }
    if (screen == 'diagnostics') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => V2DiagnosticsScreen(api: widget.api)),
        );
      });
      return;
    }
    if (screen == 'verification') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => V2VerificationScreen(api: widget.api)),
        );
      });
      return;
    }

    final idParam = Uri.base.queryParameters['id'];
    final targetCamp = _campaigns.firstWhere(
      (c) => c.campaignId == idParam,
      orElse: () => _campaigns.first,
    );
    final versions = V2Mappers.sortedVersions(targetCamp);
    final targetVer = versions.isNotEmpty ? versions.last : targetCamp.currentVersion;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || targetVer == null) return;
      switch (screen) {
        case 'detail':
          _openCampaignDetail(targetCamp);
          break;
        case 'diff':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => V2DiffScreen(
                campaign: targetCamp,
                initialVersionNo: targetVer.versionNo,
              ),
            ),
          );
          break;
        case 'decision':
          Navigator.push(
            context,
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => V2DecisionSheet(
                api: widget.api,
                campaign: targetCamp,
                targetVersion: targetVer,
              ),
            ),
          ).then((_) => _loadAll());
          break;
        case 'studio':
          _openStudio(existing: targetCamp, baseVersion: targetVer);
          break;
        case 'conflict':
          Navigator.push(
            context,
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => V2ConflictSheet(
                campaign: targetCamp,
                localBudget: targetVer.budget,
                localAudience: targetVer.targetAudience,
                localChannel: targetVer.channel,
              ),
            ),
          );
          break;
        case 'preflight':
          Navigator.push(
            context,
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => V2PreFlightSheet(
                api: widget.api,
                campaign: targetCamp,
                targetVersion: targetVer,
                existingEvents: _calendarEvents,
              ),
            ),
          ).then((_) => _loadAll());
          break;
        case 'spend':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => V2SpendScreen(
                api: widget.api,
                campaign: targetCamp,
                version: targetVer,
                onAuditLogged: _loadAll,
                onReviseRequested: () => _openStudio(existing: targetCamp, baseVersion: targetVer),
              ),
            ),
          );
          break;
      }
    });
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => V2NotificationsScreen(
          api: widget.api,
          calendarEvents: _calendarEvents,
          onOpenCalendar: () {
            if (mounted) setState(() => _activeTab = 'calendar');
          },
          onDataMutated: _loadAll,
        ),
      ),
    ).then((res) {
      if (res == 'OPEN_CALENDAR' && mounted) {
        setState(() => _activeTab = 'calendar');
      }
      _loadAll();
    });
  }

  void _openCampaignDetail(Campaign camp) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => V2CampaignDetailScreen(
          api: widget.api,
          campaignId: camp.campaignId,
          calendarEvents: _calendarEvents,
          onOpenCalendar: () => setState(() => _activeTab = 'calendar'),
          onDataMutated: _loadAll,
        ),
      ),
    ).then((res) {
      if (res == 'OPEN_CALENDAR' && mounted) {
        setState(() => _activeTab = 'calendar');
      }
      _loadAll();
    });
  }

  Future<void> _openStudio({Campaign? existing, CampaignVersion? baseVersion}) async {
    final saved = await Navigator.push<Campaign>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => V2ProposalStudioSheet(
          api: widget.api,
          existingCampaign: existing,
          baseVersion: baseVersion,
          initialLeaseSeconds: _leaseSeconds,
        ),
      ),
    );
    if (saved != null) {
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Proposal "${saved.title}" submitted to review pipeline.',
              style: V2Tokens.t3(color: V2Tokens.labelOnInk),
            ),
          ),
        );
      }
    }
  }

  void _switchUser(User user) {
    setState(() => widget.api.currentUser = user);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Operating as ${V2Tokens.cleanPersonName(user.name)} (${user.role})',
          style: V2Tokens.t3(color: V2Tokens.labelOnInk),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.api.currentUser;
    final cleanName = V2Tokens.cleanPersonName(user.name);
    final roleCap = user.role.isNotEmpty
        ? '${user.role[0].toUpperCase()}${user.role.substring(1)}'
        : 'Marketer';

    return Scaffold(
      backgroundColor: V2Tokens.bgPlaster,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Crisp Workspace Chrome Bar with Role Switcher, Notifications, Tools & v1/v2 Switch
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: V2Tokens.surfaceCard,
                border: Border(bottom: BorderSide(color: V2Tokens.hairline, width: 1)),
              ),
              child: Center(
                heightFactor: 1.0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // User / Role Switcher
                        Flexible(
                          child: PopupMenuButton<User>(
                            tooltip: 'Switch active user & role',
                            color: V2Tokens.surfaceCard,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: V2Tokens.hairline, width: 1),
                            ),
                            onSelected: _switchUser,
                            itemBuilder: (_) => _users.map((u) {
                              final active = u.id == user.id;
                              return PopupMenuItem<User>(
                                value: u,
                                child: Row(
                                  children: [
                                    V2FacetCell(
                                      status: u.role == 'marketer' ? 'brand' : 'approved',
                                      size: 11,
                                      selected: active,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${V2Tokens.cleanPersonName(u.name)} · ${u.role}',
                                        style: V2Tokens.t3(
                                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 34),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: V2Tokens.surfaceRecessed,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: V2Tokens.hairline, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  V2FacetCell(
                                    status: user.role == 'marketer' ? 'brand' : 'approved',
                                    size: 10,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      '${cleanName.split(' ').first} · $roleCap',
                                      overflow: TextOverflow.ellipsis,
                                      style: V2Tokens.t4(color: V2Tokens.textPrimary),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.keyboard_arrow_down_rounded,
                                      size: 15, color: V2Tokens.textSecondary),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Offline Queue indicator if queued or offline simulation active
                            AnimatedBuilder(
                              animation: widget.api.syncQueue,
                              builder: (_, __) {
                                final pending = widget.api.syncQueue.pendingCount;
                                final offline = widget.api.syncQueue.isOfflineSimulationEnabled;
                                if (pending == 0 && !offline) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: InkWell(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => V2SyncHubScreen(api: widget.api),
                                      ),
                                    ).then((_) => _loadAll()),
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: V2Tokens.changesChipBg,
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: V2Tokens.hairline, width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.wifi_off_rounded,
                                              size: 12, color: V2Tokens.changesSolid),
                                          const SizedBox(width: 4),
                                          Text('$pending', style: V2Tokens.t4(color: V2Tokens.changesSolid)),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Notifications Bell
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                IconButton(
                                  padding: const EdgeInsets.all(6),
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  icon: const Icon(
                                    Icons.notifications_none_rounded,
                                    size: 19,
                                    color: V2Tokens.textPrimary,
                                  ),
                                  tooltip: 'Notifications',
                                  onPressed: _openNotifications,
                                ),
                                if (_unreadCount > 0)
                                  Positioned(
                                    top: 7,
                                    right: 7,
                                    child: Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: V2Tokens.blockedSolid,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            // Workspace Tools Menu
                            PopupMenuButton<String>(
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              icon: const Icon(Icons.more_horiz, size: 19, color: V2Tokens.textPrimary),
                              color: V2Tokens.surfaceCard,
                              tooltip: 'Tools & diagnostics',
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: V2Tokens.hairline, width: 1),
                              ),
                              onSelected: (val) {
                                if (val == 'sync') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => V2SyncHubScreen(api: widget.api)),
                                  ).then((_) => _loadAll());
                                } else if (val == 'diag') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => V2DiagnosticsScreen(api: widget.api)),
                                  );
                                } else if (val == 'tests') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => V2VerificationScreen(api: widget.api)),
                                  );
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'sync',
                                  child: Text('Sync hub & outbox', style: V2Tokens.t3()),
                                ),
                                PopupMenuItem(
                                  value: 'diag',
                                  child: Text('Diagnostics', style: V2Tokens.t3()),
                                ),
                                PopupMenuItem(
                                  value: 'tests',
                                  child: Text('System verification', style: V2Tokens.t3()),
                                ),
                              ],
                            ),

                            const SizedBox(width: 4),

                            // v1 / v2 / v3 Application Switcher Pill
                            Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                color: V2Tokens.surfaceRecessed,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: V2Tokens.hairline, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: ['v1', 'v2', 'v3'].map((v) {
                                  final isSel = v == 'v2';
                                  return GestureDetector(
                                    onTap: isSel ? null : () => widget.onSwitchVersion(v),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isSel ? V2Tokens.inkPrussian : Colors.transparent,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        v,
                                        style: V2Tokens.t4(
                                          color: isSel ? V2Tokens.labelOnInk : V2Tokens.textSecondary,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Active Tab View Constrained Cleanly for Desktop & Mobile
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2, color: V2Tokens.inkPrussian),
                    )
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 880),
                        child: _buildBody(),
                      ),
                    ),
            ),

            // Docked 4-Tab Bar
            V2SolidBottomBar(
              activeTab: _activeTab,
              onSelectTab: (tab) => setState(() => _activeTab = tab),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_activeTab) {
      case 'calendar':
        return V2CalendarScreen(
          campaigns: _campaigns,
          calendarEvents: _calendarEvents,
          onScheduleSelected: (campId, forceConflictDemo, start, end) {
            final camp = _campaigns.firstWhere(
              (c) => c.campaignId == campId,
              orElse: () => _campaigns.first,
            );
            final ver = camp.currentVersion;
            if (ver == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => V2PreFlightSheet(
                  api: widget.api,
                  campaign: camp,
                  targetVersion: ver,
                  existingEvents: _calendarEvents,
                  forceUnapprovedDemo: forceConflictDemo &&
                      V2Tokens.normalizeStatusKey(camp.status) != 'approved' &&
                      V2Tokens.normalizeStatusKey(camp.status) != 'scheduled',
                  preferredStart: start,
                  preferredEnd: end,
                ),
              ),
            ).then((res) {
              if (!mounted) return;
              if (res == 'OPEN_REVIEW') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => V2DecisionSheet(
                      api: widget.api,
                      campaign: camp,
                      targetVersion: ver,
                    ),
                  ),
                ).then((_) => _loadAll());
              } else {
                _loadAll();
              }
            });
          },
        );
      case 'insights':
        return V2InsightsScreen(
          api: widget.api,
          onOpenSpendMeter: () {
            if (_campaigns.isEmpty) return;
            final camp = _campaigns.first;
            final ver = camp.currentVersion;
            if (ver == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => V2SpendScreen(
                  api: widget.api,
                  campaign: camp,
                  version: ver,
                  onAuditLogged: _loadAll,
                  onReviseRequested: () => _openStudio(existing: camp, baseVersion: ver),
                ),
              ),
            );
          },
        );
      case 'activity':
        return V2ActivityScreen(
          api: widget.api,
          auditEvents: _auditEvents,
          onRefreshRequested: _loadAll,
        );
      case 'pipeline':
      default:
        return V2PipelineScreen(
          viewerName: widget.api.currentUser.name,
          campaigns: _campaigns,
          calendarEvents: _calendarEvents,
          selectedFilter: _pipelineFilter,
          leaseSeconds: _leaseSeconds,
          onSelectFilter: (f) => setState(() => _pipelineFilter = f),
          onOpenCampaign: _openCampaignDetail,
          onCreateProposal: () => _openStudio(),
          onReviewTop: () {
            if (_campaigns.isEmpty) return;
            final top = _campaigns.firstWhere(
              (c) => V2Tokens.normalizeStatusKey(c.status) == 'review',
              orElse: () => _campaigns.first,
            );
            _openCampaignDetail(top);
          },
        );
    }
  }
}
