import 'package:flutter/material.dart';
import '../models/models.dart';
import 'v3_components.dart';
import 'v3_tokens.dart';

class V3NavItemDef {
  final String key;
  final String label;
  final IconData icon;
  final int? badge;

  const V3NavItemDef({
    required this.key,
    required this.label,
    required this.icon,
    this.badge,
  });
}

class V3Sidebar extends StatefulWidget {
  final V3Palette palette;
  final bool mobileDrawer;
  final String selectedSection;
  final ValueChanged<String> onSelectSection;
  final List<User> users;
  final User currentUser;
  final ValueChanged<User> onSelectUser;
  final int pipelineCount;
  final int unreadCount;
  final bool isDark;
  final ValueChanged<bool> onToggleDark;
  final String activeVersion;
  final ValueChanged<String> onSwitchVersion;
  final VoidCallback? onCloseDrawer;
  final int searchFocusTrigger;

  const V3Sidebar({
    super.key,
    required this.palette,
    required this.selectedSection,
    required this.onSelectSection,
    required this.users,
    required this.currentUser,
    required this.onSelectUser,
    required this.pipelineCount,
    required this.unreadCount,
    required this.isDark,
    required this.onToggleDark,
    required this.activeVersion,
    required this.onSwitchVersion,
    this.mobileDrawer = false,
    this.onCloseDrawer,
    this.searchFocusTrigger = 0,
  });

  @override
  State<V3Sidebar> createState() => _V3SidebarState();
}

class _V3SidebarState extends State<V3Sidebar> {
  bool _collapsed = false;
  bool _searchOpen = false;
  String _navQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void didUpdateWidget(covariant V3Sidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchFocusTrigger != oldWidget.searchFocusTrigger) {
      setState(() {
        _collapsed = false;
        _searchOpen = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<V3NavItemDef> get _primaryItems => [
        V3NavItemDef(
          key: 'pipeline',
          label: 'Pipeline',
          icon: Icons.view_kanban_outlined,
          badge: widget.pipelineCount,
        ),
        const V3NavItemDef(
          key: 'calendar',
          label: 'Calendar',
          icon: Icons.calendar_today_outlined,
        ),
        const V3NavItemDef(
          key: 'analytics',
          label: 'Analytics',
          icon: Icons.bar_chart_rounded,
        ),
        V3NavItemDef(
          key: 'notifications',
          label: 'Notifications',
          icon: Icons.notifications_none_rounded,
          badge: widget.unreadCount > 0 ? widget.unreadCount : null,
        ),
        const V3NavItemDef(
          key: 'governance',
          label: 'Governance & QA',
          icon: Icons.verified_user_outlined,
        ),
      ];

  void _openSettingsDialog() {
    final p = widget.palette;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.bgPrimary,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.borderDefault, width: 1),
        ),
        title: Text('Workspace Settings', style: V3Tokens.title2(p)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Switch interface generations or theme cleanly without losing backend state.',
              style: V3Tokens.bodyRegular(p),
            ),
            const SizedBox(height: 16),
            Text('Application edition', style: V3Tokens.caption(p)),
            const SizedBox(height: 8),
            V3VersionSwitcher(
              activeVersion: widget.activeVersion,
              onSelectVersion: (v) {
                Navigator.pop(ctx);
                widget.onCloseDrawer?.call();
                widget.onSwitchVersion(v);
              },
              palette: p,
            ),
            const SizedBox(height: 16),
            Text('Appearance', style: V3Tokens.caption(p)),
            const SizedBox(height: 8),
            V3SegmentedControl<bool>(
              palette: p,
              selected: widget.isDark,
              options: const [
                V3SegmentedOption(id: false, label: 'Light mode', icon: Icons.wb_sunny_outlined),
                V3SegmentedOption(id: true, label: 'Dark mode', icon: Icons.nightlight_round),
              ],
              onSelect: (dark) {
                widget.onToggleDark(dark);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: p.accentText)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final isCol = !widget.mobileDrawer && _collapsed;
    final width = isCol ? 64.0 : 258.0;
    final q = _navQuery.trim().toLowerCase();
    final shownItems =
        _primaryItems.where((it) => it.label.toLowerCase().contains(q)).toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: width,
      height: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isCol ? 10 : 12, vertical: 12),
      decoration: BoxDecoration(
        color: p.bgSecondary,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.sidebarBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: p.sidebarShadowColor,
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // User Switcher + Collapse/Close button
          if (isCol)
            Column(
              children: [
                IconButton(
                  tooltip: 'Expand sidebar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Icon(Icons.view_sidebar_outlined, size: 19, color: p.iconSecondary),
                  onPressed: () => setState(() => _collapsed = false),
                ),
                const SizedBox(height: 6),
                _buildUserAvatar(p, widget.currentUser),
              ],
            )
          else
            Row(
              children: [
                Expanded(child: _buildUserMenu(p)),
                IconButton(
                  tooltip: widget.mobileDrawer ? 'Close navigation' : 'Collapse sidebar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                  icon: Icon(
                    widget.mobileDrawer ? Icons.close_rounded : Icons.view_sidebar_outlined,
                    size: 19,
                    color: p.iconSecondary,
                  ),
                  onPressed: widget.mobileDrawer
                      ? widget.onCloseDrawer
                      : () {
                          setState(() {
                            _searchOpen = false;
                            _navQuery = '';
                            _searchCtrl.clear();
                            _collapsed = true;
                          });
                        },
                ),
              ],
            ),

          const SizedBox(height: 12),

          // Quick Search control
          if (isCol)
            InkWell(
              onTap: () => setState(() {
                _collapsed = false;
                _searchOpen = true;
              }),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: p.bgTertiary,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.search_rounded, size: 18, color: p.iconSecondary),
              ),
            )
          else if (_searchOpen)
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: p.bgTertiary,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: p.borderActive, width: 1.2),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 17, color: p.iconSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocusNode,
                      autofocus: true,
                      style: V3Tokens.bodyMedium(p),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Search navigation…',
                        hintStyle: V3Tokens.bodyMedium(p, color: p.textTertiary),
                      ),
                      onChanged: (v) => setState(() => _navQuery = v),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _searchOpen = false;
                      _navQuery = '';
                      _searchCtrl.clear();
                    }),
                    child: Icon(Icons.close_rounded, size: 16, color: p.iconSecondary),
                  ),
                ],
              ),
            )
          else
            InkWell(
              onTap: () => setState(() => _searchOpen = true),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: p.bgTertiary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 17, color: p.iconSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Quick Search',
                        style: V3Tokens.bodyMedium(p, color: p.textSecondary),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: p.isDark ? const Color(0xFF404040) : const Color(0xFFD4D4D4),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.keyboard_command_key_rounded,
                            size: 11,
                            color: p.textSecondary,
                          ),
                          const SizedBox(width: 1),
                          Text(
                            'L',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: p.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Primary Nav Rows
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (shownItems.isEmpty && !isCol)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Text('No results', style: V3Tokens.bodyRegular(p, color: p.textTertiary)),
                  )
                else
                  ...shownItems.map((item) {
                    final isSel = widget.selectedSection == item.key;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _buildNavTile(
                        p: p,
                        icon: item.icon,
                        label: item.label,
                        badge: item.badge,
                        selected: isSel,
                        collapsed: isCol,
                        onTap: () {
                          widget.onSelectSection(item.key);
                          if (widget.mobileDrawer) widget.onCloseDrawer?.call();
                        },
                      ),
                    );
                  }),
              ],
            ),
          ),

          // Bottom Theme Toggle, Secondary Actions & Brand Footer
          Column(
            children: [
              // Light / Dark Mode Switch
              if (isCol)
                InkWell(
                  onTap: () => widget.onToggleDark(!widget.isDark),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 38,
                    height: 36,
                    decoration: BoxDecoration(
                      color: p.bgTertiary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.isDark ? Icons.nightlight_round : Icons.wb_sunny_outlined,
                      size: 17,
                      color: p.iconPrimary,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: p.bgTertiary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => widget.onToggleDark(false),
                          child: Container(
                            height: 30,
                            decoration: BoxDecoration(
                              color: !widget.isDark ? p.bgPrimary : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: !widget.isDark
                                  ? [
                                      BoxShadow(
                                        color: p.cardShadowColor,
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              Icons.wb_sunny_outlined,
                              size: 15,
                              color: !widget.isDark ? p.textPrimary : p.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => widget.onToggleDark(true),
                          child: Container(
                            height: 30,
                            decoration: BoxDecoration(
                              color: widget.isDark ? p.bgPrimary : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: widget.isDark
                                  ? [
                                      BoxShadow(
                                        color: p.cardShadowColor,
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              Icons.nightlight_round,
                              size: 15,
                              color: widget.isDark ? p.textPrimary : p.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 10),
              _buildNavTile(
                p: p,
                icon: Icons.support_agent_outlined,
                label: 'Architecture & QA',
                selected: false,
                collapsed: isCol,
                onTap: () {
                  widget.onSelectSection('governance');
                  if (widget.mobileDrawer) widget.onCloseDrawer?.call();
                },
              ),
              const SizedBox(height: 2),
              _buildNavTile(
                p: p,
                icon: Icons.settings_outlined,
                label: 'Settings',
                selected: false,
                collapsed: isCol,
                onTap: _openSettingsDialog,
              ),
              const SizedBox(height: 10),

              // Bottom Workspace Edition Card
              PopupMenuButton<String>(
                tooltip: 'Switch workspace version',
                color: p.bgPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: p.borderDefault),
                ),
                onSelected: (v) {
                  widget.onCloseDrawer?.call();
                  widget.onSwitchVersion(v);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'v1',
                    child: Text('CampaignGrid v1 (Studio Classics)', style: V3Tokens.bodyMedium(p)),
                  ),
                  PopupMenuItem(
                    value: 'v2',
                    child: Text('CampaignGrid v2 (Perforated Ledger)', style: V3Tokens.bodyMedium(p)),
                  ),
                  PopupMenuItem(
                    value: 'v3',
                    child: Text('CampaignGrid v3 (BoardUI · Active)', style: V3Tokens.bodyMedium(p, color: p.accentText)),
                  ),
                ],
                child: Container(
                  padding: EdgeInsets.all(isCol ? 4 : 9),
                  decoration: BoxDecoration(
                    color: p.bgPrimary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.borderDefault, width: 1),
                  ),
                  child: isCol
                      ? _buildBrandSquare(p)
                      : Row(
                          children: [
                            _buildBrandSquare(p),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CampaignGrid v3',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: V3Tokens.bodyMedium(p),
                                  ),
                                  Text(
                                    '${widget.currentUser.role} · BoardUI',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: V3Tokens.caption(p),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: p.iconSecondary),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrandSquare(V3Palette p) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.accent500, p.accent600],
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Icon(Icons.layers_rounded, size: 17, color: Colors.white),
    );
  }

  Widget _buildUserAvatar(V3Palette p, User u) {
    final initial = u.name.isNotEmpty ? u.name[0].toUpperCase() : 'A';
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: p.bgTertiary,
        shape: BoxShape.circle,
        border: Border.all(color: p.borderDefault),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.textPrimary),
      ),
    );
  }

  Widget _buildUserMenu(V3Palette p) {
    return PopupMenuButton<User>(
      tooltip: 'Switch active user',
      color: p.bgPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: p.borderDefault),
      ),
      onSelected: widget.onSelectUser,
      itemBuilder: (_) => widget.users.map((u) {
        final active = u.id == widget.currentUser.id;
        return PopupMenuItem<User>(
          value: u,
          child: Row(
            children: [
              _buildUserAvatar(p, u),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      V3Tokens.cleanPersonName(u.name),
                      style: V3Tokens.bodyMedium(
                        p,
                        color: active ? p.accentText : p.textPrimary,
                      ),
                    ),
                    Text(u.role, style: V3Tokens.caption(p)),
                  ],
                ),
              ),
              if (active) Icon(Icons.check_rounded, size: 16, color: p.accent500),
            ],
          ),
        );
      }).toList(),
      child: Row(
        children: [
          _buildUserAvatar(p, widget.currentUser),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              V3Tokens.cleanPersonName(widget.currentUser.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: V3Tokens.bodyMedium(p),
            ),
          ),
          Icon(Icons.unfold_more_rounded, size: 15, color: p.iconSecondary),
        ],
      ),
    );
  }

  Widget _buildNavTile({
    required V3Palette p,
    required IconData icon,
    required String label,
    int? badge,
    required bool selected,
    required bool collapsed,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 38,
        padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 10),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [p.accent500, p.accent600],
                )
              : null,
          borderRadius: BorderRadius.circular(10),
          border: selected ? Border.all(color: p.accent500, width: 1) : null,
        ),
        child: collapsed
            ? Center(
                child: Icon(
                  icon,
                  size: 19,
                  color: selected ? Colors.white : p.iconSecondary,
                ),
              )
            : Row(
                children: [
                  Icon(
                    icon,
                    size: 19,
                    color: selected ? Colors.white : p.iconSecondary,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: selected ? Colors.white : p.textSecondary,
                      ),
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withOpacity(0.22)
                            : p.bgTertiary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$badge',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : p.textSecondary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
