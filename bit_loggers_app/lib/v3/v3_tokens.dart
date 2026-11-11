import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// BoardUI v3 Light & Dark Token System converted natively for Flutter.
@immutable
class V3Palette {
  final bool isDark;
  final Color bgFull;
  final Color bgPrimary;
  final Color bgInner;
  final Color bgSecondary;
  final Color bgTertiary;
  final Color bgSecondaryHover;
  final Color borderDefault;
  final Color borderHover;
  final Color borderActive;
  final Color separator;
  final Color sidebarBorder;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color iconPrimary;
  final Color iconSecondary;
  final Color iconTertiary;

  final Color accent400;
  final Color accent500;
  final Color accent600;
  final Color accent700;
  final Color accentBgSoft;
  final Color accentText;

  final Color chartNeutral;
  final Color chartCursor;
  final Color chartTrack;
  final Color chartLime;
  final Color chartLimeActive;
  final Color chartIndigo;
  final Color chartIndigoActive;

  final Color cardShadowColor;
  final Color sidebarShadowColor;

  const V3Palette({
    required this.isDark,
    required this.bgFull,
    required this.bgPrimary,
    required this.bgInner,
    required this.bgSecondary,
    required this.bgTertiary,
    required this.bgSecondaryHover,
    required this.borderDefault,
    required this.borderHover,
    required this.borderActive,
    required this.separator,
    required this.sidebarBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.iconPrimary,
    required this.iconSecondary,
    required this.iconTertiary,
    required this.accent400,
    required this.accent500,
    required this.accent600,
    required this.accent700,
    required this.accentBgSoft,
    required this.accentText,
    required this.chartNeutral,
    required this.chartCursor,
    required this.chartTrack,
    required this.chartLime,
    required this.chartLimeActive,
    required this.chartIndigo,
    required this.chartIndigoActive,
    required this.cardShadowColor,
    required this.sidebarShadowColor,
  });

  static const light = V3Palette(
    isDark: false,
    bgFull: Color(0xFFFFFFFF),
    bgPrimary: Color(0xFFFFFFFF),
    bgInner: Color(0xFFFFFFFF),
    bgSecondary: Color(0xFFF7F7F7),
    bgTertiary: Color(0xFFEBEBEB),
    bgSecondaryHover: Color(0xFFEBEBEB),
    borderDefault: Color(0xFFEBEBEB),
    borderHover: Color(0xFFD4D4D4),
    borderActive: Color(0xFFA3A3A3),
    separator: Color(0xFFEBEBEB),
    sidebarBorder: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0A0A0A),
    textSecondary: Color(0xFF737373),
    textTertiary: Color(0xFFA3A3A3),
    iconPrimary: Color(0xFF0A0A0A),
    iconSecondary: Color(0xFF737373),
    iconTertiary: Color(0xFFA3A3A3),
    accent400: Color(0xFF3392FF),
    accent500: Color(0xFF2B7FFF),
    accent600: Color(0xFF155DFC),
    accent700: Color(0xFF1447E6),
    accentBgSoft: Color(0xFFDBEAFE),
    accentText: Color(0xFF155DFC),
    chartNeutral: Color(0xFFD4D4D4),
    chartCursor: Color(0xFFD4D4D4),
    chartTrack: Color(0xFFEBEBEB),
    chartLime: Color(0xFF9AE600),
    chartLimeActive: Color(0xFF7CCF00),
    chartIndigo: Color(0xFF7C86FF),
    chartIndigoActive: Color(0xFF615FFF),
    cardShadowColor: Color(0x0D000000),
    sidebarShadowColor: Color(0x14000000),
  );

  static const dark = V3Palette(
    isDark: true,
    bgFull: Color(0xFF121212),
    bgPrimary: Color(0xFF262626),
    bgInner: Color(0xFF1E1E1E),
    bgSecondary: Color(0xFF171717),
    bgTertiary: Color(0xFF262626),
    bgSecondaryHover: Color(0xFF262626),
    borderDefault: Color(0xFF2E2E2E),
    borderHover: Color(0xFF404040),
    borderActive: Color(0xFF525252),
    separator: Color(0xFF2E2E2E),
    sidebarBorder: Color(0xFF2E2E2E),
    textPrimary: Color(0xFFFAFAFA),
    textSecondary: Color(0xFFA3A3A3),
    textTertiary: Color(0xFF737373),
    iconPrimary: Color(0xFFFAFAFA),
    iconSecondary: Color(0xFFA3A3A3),
    iconTertiary: Color(0xFF525252),
    accent400: Color(0xFF3392FF),
    accent500: Color(0xFF2B7FFF),
    accent600: Color(0xFF155DFC),
    accent700: Color(0xFF1D4ED8),
    accentBgSoft: Color(0xFF172554),
    accentText: Color(0xFF60A5FA),
    chartNeutral: Color(0xFF404040),
    chartCursor: Color(0xFF525252),
    chartTrack: Color(0xFF262626),
    chartLime: Color(0xFF9AE600),
    chartLimeActive: Color(0xFF84CC16),
    chartIndigo: Color(0xFF818CF8),
    chartIndigoActive: Color(0xFF6366F1),
    cardShadowColor: Color(0x28000000),
    sidebarShadowColor: Color(0x45000000),
  );

  ({Color bg, Color fg}) chipColors(String tone) {
    if (isDark) {
      switch (tone) {
        case 'lime':
          return (bg: const Color(0xFF243310), fg: const Color(0xFFA3E635));
        case 'yellow':
          return (bg: const Color(0xFF362B0F), fg: const Color(0xFFFACC15));
        case 'rose':
          return (bg: const Color(0xFF3B131D), fg: const Color(0xFFFB7185));
        case 'cyan':
          return (bg: const Color(0xFF0E333E), fg: const Color(0xFF22D3EE));
        case 'orange':
          return (bg: const Color(0xFF3C200D), fg: const Color(0xFFFB923C));
        case 'blue':
          return (bg: const Color(0xFF142A4F), fg: const Color(0xFF60A5FA));
        case 'purple':
          return (bg: const Color(0xFF2D1645), fg: const Color(0xFFC084FC));
        default:
          return (bg: const Color(0xFF2B2B2B), fg: const Color(0xFFD4D4D4));
      }
    } else {
      switch (tone) {
        case 'lime':
          return (bg: const Color(0xFFECFCCA), fg: const Color(0xFF35530E));
        case 'yellow':
          return (bg: const Color(0xFFFEF9C2), fg: const Color(0xFF854D0E));
        case 'rose':
          return (bg: const Color(0xFFFFE4E6), fg: const Color(0xFF9F1239));
        case 'cyan':
          return (bg: const Color(0xFFCEFAFE), fg: const Color(0xFF155E75));
        case 'orange':
          return (bg: const Color(0xFFFFEDD4), fg: const Color(0xFF9A3412));
        case 'blue':
          return (bg: const Color(0xFFDBEAFE), fg: const Color(0xFF1D4ED8));
        case 'purple':
          return (bg: const Color(0xFFF3E8FF), fg: const Color(0xFF6B21A8));
        default:
          return (bg: const Color(0xFFEBEBEB), fg: const Color(0xFF525252));
      }
    }
  }
}

class V3Tokens {
  static String channelChipTone(String channel) {
    switch (channel.toLowerCase()) {
      case 'social':
        return 'blue';
      case 'search':
        return 'orange';
      case 'email':
        return 'purple';
      case 'display':
        return 'cyan';
      case 'video':
        return 'rose';
      default:
        return 'lime';
    }
  }

  static String statusChipTone(String status) {
    switch (status) {
      case 'Submitted':
        return 'yellow';
      case 'ChangesRequested':
        return 'orange';
      case 'Approved':
        return 'cyan';
      case 'Scheduled':
        return 'lime';
      case 'Rejected':
        return 'rose';
      default:
        return 'neutral';
    }
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'Submitted':
        return 'Awaiting review';
      case 'ChangesRequested':
        return 'Changes requested';
      case 'Approved':
        return 'Approved';
      case 'Scheduled':
        return 'Scheduled';
      case 'Rejected':
        return 'Rejected';
      default:
        return 'Draft';
    }
  }

  static String formatMoney(num amount) {
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return fmt.format(amount.round());
  }

  static String formatRelativeTime(String? iso) {
    if (iso == null || iso.isEmpty) return 'Recent';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return 'Recent';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  static TextStyle title1(V3Palette p, {bool semiBold = true}) => TextStyle(
        fontSize: 24,
        height: 1.2,
        letterSpacing: -0.6,
        fontWeight: semiBold ? FontWeight.w600 : FontWeight.w500,
        color: p.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle title2(V3Palette p) => TextStyle(
        fontSize: 19,
        height: 1.25,
        letterSpacing: -0.4,
        fontWeight: FontWeight.w600,
        color: p.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle headline(V3Palette p) => TextStyle(
        fontSize: 15.5,
        height: 1.3,
        letterSpacing: -0.25,
        fontWeight: FontWeight.w600,
        color: p.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle bodyMedium(V3Palette p, {Color? color}) => TextStyle(
        fontSize: 13.5,
        height: 1.38,
        letterSpacing: -0.15,
        fontWeight: FontWeight.w500,
        color: color ?? p.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle bodyRegular(V3Palette p, {Color? color}) => TextStyle(
        fontSize: 13.5,
        height: 1.4,
        letterSpacing: -0.1,
        fontWeight: FontWeight.w400,
        color: color ?? p.textSecondary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle caption(V3Palette p, {Color? color, FontWeight weight = FontWeight.w500}) =>
      TextStyle(
        fontSize: 12,
        height: 1.3,
        letterSpacing: -0.05,
        fontWeight: weight,
        color: color ?? p.textSecondary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static ThemeData buildThemeData(V3Palette p) {
    return ThemeData(
      useMaterial3: true,
      brightness: p.isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: p.bgFull,
      colorScheme: ColorScheme(
        brightness: p.isDark ? Brightness.dark : Brightness.light,
        primary: p.accent500,
        onPrimary: Colors.white,
        secondary: p.bgSecondary,
        onSecondary: p.textPrimary,
        error: const Color(0xFFEF4444),
        onError: Colors.white,
        surface: p.bgPrimary,
        onSurface: p.textPrimary,
      ),
      dividerColor: p.separator,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.isDark ? const Color(0xFF262626) : const Color(0xFF0A0A0A),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
