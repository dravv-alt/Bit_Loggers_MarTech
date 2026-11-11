import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'v3_tokens.dart';

enum V3ButtonVariant { primary, secondary, ghost, danger }

class V3Button extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final V3ButtonVariant variant;
  final V3Palette palette;
  final bool small;

  const V3Button({
    super.key,
    required this.label,
    required this.palette,
    this.icon,
    this.onTap,
    this.variant = V3ButtonVariant.secondary,
    this.small = false,
  });

  @override
  State<V3Button> createState() => _V3ButtonState();
}

class _V3ButtonState extends State<V3Button> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final disabled = widget.onTap == null;
    final height = widget.small ? 32.0 : 38.0;
    final hPad = widget.small ? 10.0 : 14.0;
    final fontSize = widget.small ? 12.5 : 13.5;

    Gradient? bgGrad;
    Color? bgColor;
    Color fgColor;
    Border? border;

    switch (widget.variant) {
      case V3ButtonVariant.primary:
        bgGrad = disabled
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _hovered
                    ? [p.accent400, p.accent500]
                    : [p.accent500, p.accent600],
              );
        bgColor = disabled ? p.bgTertiary : null;
        fgColor = disabled ? p.textTertiary : Colors.white;
        border = Border.all(
          color: disabled ? p.borderDefault : p.accent600,
          width: 1,
        );
        break;
      case V3ButtonVariant.danger:
        bgGrad = disabled
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _hovered
                    ? const [Color(0xFFF87171), Color(0xFFEF4444)]
                    : const [Color(0xFFEF4444), Color(0xFFDC2626)],
              );
        bgColor = disabled ? p.bgTertiary : null;
        fgColor = Colors.white;
        border = Border.all(color: const Color(0xFFDC2626), width: 1);
        break;
      case V3ButtonVariant.ghost:
        bgColor = disabled
            ? p.bgSecondary
            : _hovered
                ? (p.isDark
                    ? const Color(0xFF1E3A8A).withOpacity(0.65)
                    : p.accentBgSoft)
                : (p.isDark
                    ? const Color(0xFF1E3A8A).withOpacity(0.45)
                    : p.accentBgSoft.withOpacity(0.8));
        fgColor = disabled
            ? p.textTertiary
            : (p.isDark ? const Color(0xFF93C5FD) : p.accent700);
        border = null;
        break;
      case V3ButtonVariant.secondary:
        bgColor = disabled
            ? p.bgSecondary
            : (_hovered ? p.bgSecondary : p.bgPrimary);
        fgColor = disabled ? p.textTertiary : p.textPrimary;
        border = Border.all(
          color: _hovered && !disabled ? p.borderHover : p.borderDefault,
          width: 1,
        );
        break;
    }

    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
        onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 110),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            height: height,
            padding: EdgeInsets.symmetric(horizontal: hPad),
            decoration: BoxDecoration(
              gradient: bgGrad,
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: border,
              boxShadow: widget.variant == V3ButtonVariant.secondary && !disabled
                  ? [BoxShadow(color: p.cardShadowColor, blurRadius: 2, offset: const Offset(0, 1))]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: widget.small ? 14 : 15, color: fgColor),
                  const SizedBox(width: 6),
                ],
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    color: fgColor,
                    letterSpacing: -0.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Interactive hover container matching BoardUI `hover:border-border-button-hover` cards.
class V3HoverCard extends StatefulWidget {
  final V3Palette palette;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Widget Function(bool hovered) builder;

  const V3HoverCard({
    super.key,
    required this.palette,
    required this.builder,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = 16,
  });

  @override
  State<V3HoverCard> createState() => _V3HoverCardState();
}

class _V3HoverCardState extends State<V3HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: p.bgInner,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: _hovered ? p.borderHover : p.borderDefault,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: p.cardShadowColor,
                blurRadius: _hovered ? 6 : 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: widget.builder(_hovered),
        ),
      ),
    );
  }
}

/// Dashed border panel matching BoardUI empty column / empty state containers.
class V3DashedBox extends StatelessWidget {
  final V3Palette palette;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double? minHeight;

  const V3DashedBox({
    super.key,
    required this.palette,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 14,
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(
        color: palette.borderHover,
        radius: borderRadius,
      ),
      child: Container(
        width: double.infinity,
        constraints: minHeight != null ? BoxConstraints(minHeight: minHeight!) : null,
        padding: padding,
        decoration: BoxDecoration(
          color: palette.bgInner.withOpacity(0.5),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: child,
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      double d = 0.0;
      while (d < metric.length) {
        final next = math.min(d + dash, metric.length);
        canvas.drawPath(metric.extractPath(d, next), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class V3Chip extends StatelessWidget {
  final String label;
  final String tone;
  final V3Palette palette;
  final IconData? leadingIcon;
  final bool pill;

  const V3Chip({
    super.key,
    required this.label,
    required this.tone,
    required this.palette,
    this.leadingIcon,
    this.pill = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = palette.chipColors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(pill ? 999 : 6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 12.5, color: c.fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: c.fg,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class V3Badge extends StatelessWidget {
  final String label;
  final V3Palette palette;
  final bool primary;

  const V3Badge({
    super.key,
    required this.label,
    required this.palette,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: primary ? palette.accent500 : palette.bgTertiary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: primary ? Colors.white : palette.textSecondary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class V3StatusDot extends StatelessWidget {
  final String colorKey; // 'green' | 'yellow' | 'indigo' | 'rose'
  final V3Palette palette;

  const V3StatusDot({super.key, required this.colorKey, required this.palette});

  @override
  Widget build(BuildContext context) {
    Color dot;
    Color halo;
    switch (colorKey) {
      case 'green':
        dot = const Color(0xFF16A34A);
        halo = palette.isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7);
        break;
      case 'yellow':
        dot = const Color(0xFFEAB308);
        halo = palette.isDark ? const Color(0xFF422006) : const Color(0xFFFEF9C3);
        break;
      case 'rose':
        dot = const Color(0xFFE11D48);
        halo = palette.isDark ? const Color(0xFF4C0519) : const Color(0xFFFFE4E6);
        break;
      default:
        dot = const Color(0xFF6366F1);
        halo = palette.isDark ? const Color(0xFF1E1B4B) : const Color(0xFFE0E7FF);
        break;
    }
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: halo, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
      ),
    );
  }
}

class V3StatItem {
  final IconData icon;
  final String label;
  final String value;
  final String delta;
  final String deltaTone; // 'lime' | 'rose' | 'neutral'
  final String tileTone; // 'blue' | 'orange' | 'emerald' | 'purple'
  final String? caption;
  final String? hint;

  const V3StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.delta,
    this.deltaTone = 'lime',
    this.tileTone = 'blue',
    this.caption,
    this.hint,
  });
}

class V3StatCardGrid extends StatelessWidget {
  final List<V3StatItem> stats;
  final V3Palette palette;
  final bool footerVariant;

  const V3StatCardGrid({
    super.key,
    required this.stats,
    required this.palette,
    this.footerVariant = true,
  });

  List<Color> _tileGradient(String tone) {
    switch (tone) {
      case 'orange':
        return [const Color(0xFFFF8904), const Color(0xFFFF6900)];
      case 'emerald':
        return [const Color(0xFF00BC7D), const Color(0xFF009966)];
      case 'purple':
        return [const Color(0xFFAD46FF), const Color(0xFF9810FA)];
      default:
        return [palette.accent500, palette.accent600];
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w >= 900 ? 4 : (w >= 540 ? 2 : 1);
        const gap = 12.0;
        final cardW = (w - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: stats.map((s) {
            return SizedBox(
              width: cardW,
              child: footerVariant ? _buildFooterCard(s) : _buildPlainCard(s),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFooterCard(V3StatItem s) {
    final dc = palette.chipColors(s.deltaTone);
    final grad = _tileGradient(s.tileTone);
    final deltaIcon = s.deltaTone == 'lime'
        ? Icons.arrow_circle_up_rounded
        : s.deltaTone == 'rose'
            ? Icons.arrow_circle_down_rounded
            : Icons.remove_circle_outline_rounded;

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: palette.bgSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.borderDefault, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: grad,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(s.icon, size: 18, color: Colors.white),
                    ),
                    if (s.hint != null)
                      Tooltip(
                        message: s.hint!,
                        child: Icon(Icons.info_rounded, size: 17, color: palette.iconSecondary),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(s.label, style: V3Tokens.bodyRegular(palette)),
                const SizedBox(height: 4),
                Text(s.value, style: V3Tokens.title1(palette, semiBold: true).copyWith(fontSize: 28)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: palette.bgPrimary,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: palette.borderDefault, width: 0.75),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    s.caption ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V3Tokens.caption(
                      palette,
                      color: palette.textSecondary,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.fromLTRB(4, 2.5, 7, 2.5),
                  decoration: BoxDecoration(
                    color: dc.bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(deltaIcon, size: 13, color: dc.fg),
                      const SizedBox(width: 3),
                      Text(
                        s.delta,
                        style: V3Tokens.caption(palette, color: dc.fg, weight: FontWeight.w600)
                            .copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlainCard(V3StatItem s) {
    final dc = palette.chipColors(s.deltaTone);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.borderDefault, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: palette.bgPrimary,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: palette.borderDefault, width: 1),
            ),
            child: Icon(s.icon, size: 17, color: palette.iconPrimary),
          ),
          const SizedBox(height: 12),
          Text(s.label, style: V3Tokens.bodyRegular(palette)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(s.value, style: V3Tokens.title1(palette, semiBold: false).copyWith(fontSize: 24)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: dc.bg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  s.delta,
                  style: V3Tokens.caption(palette, color: dc.fg, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class V3SegmentedOption<T> {
  final T id;
  final String label;
  final IconData? icon;
  final int? count;

  const V3SegmentedOption({
    required this.id,
    required this.label,
    this.icon,
    this.count,
  });
}

class V3SegmentedControl<T> extends StatelessWidget {
  final List<V3SegmentedOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelect;
  final V3Palette palette;

  const V3SegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: palette.bgTertiary.withOpacity(palette.isDark ? 0.85 : 0.75),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: options.map((opt) {
            final isSel = opt.id == selected;
            return GestureDetector(
              onTap: () => onSelect(opt.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSel ? palette.bgPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSel
                      ? [
                          BoxShadow(
                            color: palette.cardShadowColor,
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (opt.icon != null) ...[
                      Icon(
                        opt.icon,
                        size: 14,
                        color: isSel ? palette.textPrimary : palette.textSecondary,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      opt.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                        color: isSel ? palette.textPrimary : palette.textSecondary,
                      ),
                    ),
                    if (opt.count != null) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSel ? palette.bgTertiary : palette.bgPrimary,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '${opt.count}',
                          style: V3Tokens.caption(palette, weight: FontWeight.w600)
                              .copyWith(fontSize: 11),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Unified 3-way v1 / v2 / v3 Switcher Pill used inside V3Shell.
class V3VersionSwitcher extends StatelessWidget {
  final String activeVersion; // 'v1' | 'v2' | 'v3'
  final ValueChanged<String> onSelectVersion;
  final V3Palette palette;
  final bool compact;

  const V3VersionSwitcher({
    super.key,
    required this.activeVersion,
    required this.onSelectVersion,
    required this.palette,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: palette.bgSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.borderDefault, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['v1', 'v2', 'v3'].map((v) {
          final isSel = activeVersion == v;
          return GestureDetector(
            onTap: isSel ? null : () => onSelectVersion(v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 9, vertical: 4),
              decoration: BoxDecoration(
                color: isSel ? palette.accent500 : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                v,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isSel ? Colors.white : palette.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
