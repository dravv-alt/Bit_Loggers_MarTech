import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Design tokens for CampaignGrid v2 ("The Perforated Ledger & Facet Instrument").
class V2Tokens {
  V2Tokens._();

  // Core Surfaces & Inks
  static const Color bgPlaster = Color(0xFFF2F0EB);
  static const Color outerCanvas = Color(0xFFE5E2DA);
  static const Color surfaceCard = Color(0xFFFBFAF7);
  static const Color surfaceRecessed = Color(0xFFE9E6DF);
  static const Color hairline = Color(0xFFD8D3C7);
  static const Color textPrimary = Color(0xFF122230);
  static const Color textSecondary = Color(0xFF46535F);
  static const Color inkPrussian = Color(0xFF16324A);
  static const Color labelOnInk = Color(0xFFFFFFFF);
  static const Color cadmiumYellow = Color(0xFFF0B323);
  static const Color changedRowTint = Color(0xFFF8F2E4);

  // Semantic Status Tokens
  static const Color approvedSolid = Color(0xFF1F7A5C);
  static const Color approvedChipBg = Color(0xFFE4F0EC);

  static const Color changesSolid = Color(0xFF8A5200);
  static const Color changesChipBg = Color(0xFFF6ECD9);

  static const Color blockedSolid = Color(0xFFB3281A);
  static const Color blockedChipBg = Color(0xFFF7E5E2);
  static const Color blockedStripeAlt = Color(0xFFF2D2CD);

  static const Color reviewSolid = Color(0xFF21496A);
  static const Color reviewChipBg = Color(0xFFE3ECF3);

  static const Color brandSolid = Color(0xFF16324A);
  static const Color brandUpper = Color(0xFFD8D3C7);

  // Strict 4-Tier Typography Scale (11px minimum floor across the entire app)
  static TextStyle t1({Color color = textPrimary, bool mono = false}) => TextStyle(
        fontFamily: mono ? 'monospace' : null,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: mono ? -0.5 : -0.9,
        height: 1.08,
        color: color,
        fontFeatures: mono ? const [FontFeature.tabularFigures()] : null,
      );

  static TextStyle t2({Color color = textPrimary, bool mono = false}) => TextStyle(
        fontFamily: mono ? 'monospace' : null,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: mono ? -0.1 : -0.24,
        height: 1.25,
        color: color,
        fontFeatures: mono ? const [FontFeature.tabularFigures()] : null,
      );

  static TextStyle t3({
    Color color = textPrimary,
    FontWeight fontWeight = FontWeight.w500,
    TextDecoration? decoration,
  }) =>
      TextStyle(
        fontSize: 13,
        fontWeight: fontWeight,
        letterSpacing: -0.06,
        height: 1.38,
        color: color,
        decoration: decoration,
      );

  static TextStyle t4({Color color = textSecondary, FontWeight fontWeight = FontWeight.w600}) =>
      TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        fontWeight: fontWeight,
        letterSpacing: 0.22,
        height: 1.15,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static ThemeData buildThemeData() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgPlaster,
      canvasColor: surfaceCard,
      cardColor: surfaceCard,
      dividerColor: hairline,
      colorScheme: const ColorScheme.light(
        primary: inkPrussian,
        onPrimary: labelOnInk,
        secondary: cadmiumYellow,
        onSecondary: textPrimary,
        surface: surfaceCard,
        onSurface: textPrimary,
        error: blockedSolid,
        onError: labelOnInk,
        outline: hairline,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceCard,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: inkPrussian,
        contentTextStyle: t3(color: labelOnInk),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static V2StatusStyle statusStyle(String statusKey) {
    switch (normalizeStatusKey(statusKey)) {
      case 'approved':
        return const V2StatusStyle(
          key: 'approved',
          solid: approvedSolid,
          chipBg: approvedChipBg,
          label: 'Approved',
        );
      case 'scheduled':
        return const V2StatusStyle(
          key: 'scheduled',
          solid: approvedSolid,
          chipBg: approvedChipBg,
          label: 'Scheduled',
        );
      case 'changes':
        return const V2StatusStyle(
          key: 'changes',
          solid: changesSolid,
          chipBg: changesChipBg,
          label: 'Changes',
        );
      case 'blocked':
        return const V2StatusStyle(
          key: 'blocked',
          solid: blockedSolid,
          chipBg: blockedChipBg,
          label: 'Blocked',
        );
      case 'brand':
        return const V2StatusStyle(
          key: 'brand',
          solid: brandSolid,
          chipBg: reviewChipBg,
          label: 'Draft',
        );
      case 'review':
      default:
        return const V2StatusStyle(
          key: 'review',
          solid: reviewSolid,
          chipBg: reviewChipBg,
          label: 'In review',
        );
    }
  }

  static String normalizeStatusKey(String raw) {
    final s = raw.trim().toLowerCase();
    if (s == 'approved') return 'approved';
    if (s == 'scheduled') return 'scheduled';
    if (s == 'changesrequested' || s == 'changes_requested' || s == 'changes') return 'changes';
    if (s == 'rejected' || s == 'blocked' || s == 'conflict' || s == 'failed') return 'blocked';
    if (s == 'draft' || s == 'brand') return 'brand';
    return 'review';
  }

  static String formatVersionTag(int versionNo) => 'V$versionNo.0';

  static String formatCurrency(num value) => '\$${NumberFormat('#,##0').format(value)}';

  static String formatLease(int secs) {
    final clamped = secs < 0 ? 0 : secs;
    final m = (clamped ~/ 60).toString().padLeft(2, '0');
    final s = (clamped % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static String cleanPersonName(String raw) {
    final idx = raw.indexOf(' (');
    return idx > 0 ? raw.substring(0, idx) : raw;
  }
}

class V2StatusStyle {
  final String key;
  final Color solid;
  final Color chipBg;
  final String label;

  const V2StatusStyle({
    required this.key,
    required this.solid,
    required this.chipBg,
    required this.label,
  });
}

