import 'package:flutter/material.dart';
import 'v3_tokens.dart';

enum V3ButtonVariant { primary, secondary, ghost, danger }

class V3Button extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final height = small ? 32.0 : 38.0;
    final hPad = small ? 10.0 : 14.0;
    final fontSize = small ? 12.5 : 13.5;

    Gradient? bgGrad;
    Color? bgColor;
    Color fgColor;
    Border? border;

    switch (variant) {
      case V3ButtonVariant.primary:
        bgGrad = disabled
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [palette.accent500, palette.accent600],
              );
        bgColor = disabled ? palette.bgTertiary : null;
        fgColor = disabled ? palette.textTertiary : Colors.white;
        border = Border.all(
          color: disabled ? palette.borderDefault : palette.accent600,
          width: 1,
        );
        break;
      case V3ButtonVariant.danger:
        bgGrad = disabled
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              );
        bgColor = disabled ? palette.bgTertiary : null;
        fgColor = Colors.white;
        border = Border.all(color: const Color(0xFFDC2626), width: 1);
        break;
      case V3ButtonVariant.ghost:
        bgColor = palette.isDark
            ? const Color(0xFF1E3A8A).withOpacity(0.45)
            : palette.accentBgSoft;
        fgColor = palette.isDark ? const Color(0xFF93C5FD) : palette.accent700;
        border = null;
        break;
      case V3ButtonVariant.secondary:
        bgColor = palette.bgPrimary;
        fgColor = disabled ? palette.textTertiary : palette.textPrimary;
        border = Border.all(color: palette.borderDefault, width: 1);
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: hPad),
        decoration: BoxDecoration(
          gradient: bgGrad,
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: border,
          boxShadow: variant == V3ButtonVariant.secondary
              ? [BoxShadow(color: palette.cardShadowColor, blurRadius: 2, offset: const Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: small ? 14 : 15, color: fgColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
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
    );
  }
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.bgPrimary,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: palette.borderDefault, width: 0.75),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    s.caption ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: V3Tokens.bodyMedium(palette, color: palette.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(5, 3, 8, 3),
                  decoration: BoxDecoration(
                    color: dc.bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(deltaIcon, size: 14, color: dc.fg),
                      const SizedBox(width: 4),
                      Text(
                        s.delta,
                        style: V3Tokens.caption(palette, color: dc.fg, weight: FontWeight.w600),
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
