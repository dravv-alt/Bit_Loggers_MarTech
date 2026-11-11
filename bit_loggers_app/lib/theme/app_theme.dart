import 'package:flutter/material.dart';

/// Campaign Grid Theme Tokens (Compliant with heydamir/unslop anti-slop guidelines)
/// Represents a cohesive design token set with quiet chrome, purposeful accents,
/// strict contrast ratios, and content-first color allocation.
class CgTokens {
  final String id;
  final String name;
  final String shortName;
  final String subtitle;
  final Color page;
  final Color card;
  final Color well;
  final Color hairline;
  final Color text;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color onAccent;
  final Color approved;
  final Color warning;
  final Color collision;
  final Color social;
  final Color search;
  final Color email;
  final Color display;
  final Color video;
  final double radiusCard;
  final double radiusControl;
  final double radiusTag;
  final double structuralRuleWidth;
  final bool isDark;

  const CgTokens({
    required this.id,
    required this.name,
    required this.shortName,
    required this.subtitle,
    required this.page,
    required this.card,
    required this.well,
    required this.hairline,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.approved,
    required this.warning,
    required this.collision,
    required this.social,
    required this.search,
    required this.email,
    required this.display,
    required this.video,
    required this.radiusCard,
    required this.radiusControl,
    required this.radiusTag,
    this.structuralRuleWidth = 0.75,
    this.isDark = false,
  });

  Color getChannelColor(String channel) {
    switch (channel.toLowerCase().trim()) {
      case 'social':
      case 'paid social':
        return social;
      case 'search':
      case 'paid search':
        return search;
      case 'email':
      case 'crm':
        return email;
      case 'display':
      case 'programmatic':
        return display;
      case 'video':
      case 'youtube':
        return video;
      case 'influencer':
        return social;
      default:
        return textSecondary;
    }
  }
}

// ============================================================================
// THE THREE UNSLOP THEME DEFINITIONS
// ============================================================================

/// Theme A: Gesso & Pigment
/// Idea: Editorial advertising dispatch desk & print proof sheet.
/// Neutrals are gesso, paper and ink; accents are historical artist pigments.
const CgTokens gessoPigment = CgTokens(
  id: 'a',
  name: 'Gesso & Pigment',
  shortName: 'Gesso',
  subtitle: 'Warm paper · Vermilion',
  page: Color(0xFFF6F2E9),        // Warm paper
  card: Color(0xFFFFFDF8),        // Warm off-white (not pure white)
  well: Color(0xFFECE5D8),        // Raised sandstone well
  hairline: Color(0x1F1F1B16),    // #1F1B16 at ~10% (quiet hairline)
  text: Color(0xFF1F1B16),        // Deep carbon ink
  textSecondary: Color(0xFF51493F), // Warm graphite slate (5.8:1)
  textMuted: Color(0xFF6B6256),   // Stone muted (5.4:1 on page, passes AA)
  accent: Color(0xFFC4402A),      // Vermilion (White text on it is 5.1:1)
  onAccent: Color(0xFFFFFFFF),
  approved: Color(0xFF3F7D4E),    // Terre verte
  warning: Color(0xFFA8721A),     // Ochre dark
  collision: Color(0xFF9E2A3B),   // Deep madder (distinct from vermilion)
  social: Color(0xFF4A76B8),      // Smalt blue
  search: Color(0xFF2F8A78),      // Verdigris
  email: Color(0xFFB24C69),       // Madder rose
  display: Color(0xFFC28F2C),     // Naples ochre
  video: Color(0xFF2B4A63),       // Prussian
  radiusCard: 12,
  radiusControl: 8,
  radiusTag: 4,
  structuralRuleWidth: 0.75,
  isDark: false,
);

/// Theme B: Chiaroscuro
/// Idea: Rembrandt-style lighting. Warm umber ground with one gold highlight.
/// Completely avoids the generic dark-blue/cyan-black vibecoded slop.
const CgTokens chiaroscuro = CgTokens(
  id: 'b',
  name: 'Chiaroscuro',
  shortName: 'Umber',
  subtitle: 'Warm umber · Gold leaf',
  page: Color(0xFF14110D),        // Warm umber (not pure black)
  card: Color(0xFF1D1913),        // Warm dark card
  well: Color(0xFF28231B),        // Raised well
  hairline: Color(0x1EF2EADB),    // #F2EADB at 12%
  text: Color(0xFFF2EADB),        // Bone white (not harsh white)
  textSecondary: Color(0xFFC2B8A4), // Warm muted stone
  textMuted: Color(0xFF9A8F7B),   // Dark umber text (5.9:1 on page)
  accent: Color(0xFFE8B13A),      // Gold leaf
  onAccent: Color(0xFF1A1510),    // Dark ink text (9:1 on gold)
  approved: Color(0xFF7FB069),    // Terre verte lifted
  warning: Color(0xFFD4932E),     // Ochre
  collision: Color(0xFFF2667A),   // Alizarin
  social: Color(0xFF6E9BD6),      // Smalt lifted
  search: Color(0xFF4DB39C),      // Verdigris lifted
  email: Color(0xFFD9708C),       // Madder rose lifted
  display: Color(0xFFD9803A),     // Sienna
  video: Color(0xFFD9583B),       // Cinnabar
  radiusCard: 12,
  radiusControl: 8,
  radiusTag: 4,
  structuralRuleWidth: 0.75,
  isDark: true,
);

/// Theme C: Neoplastic
/// Idea: De Stijl and Mondrian, literal fit for Campaign Grid.
/// Plaster ground, 2px structural ink rules, cadmium yellow accent.
const CgTokens neoplastic = CgTokens(
  id: 'c',
  name: 'Neoplastic',
  shortName: 'Plaster',
  subtitle: 'Cool plaster · Cadmium yellow',
  page: Color(0xFFEEEDE6),        // Cool plaster
  card: Color(0xFFF9F8F3),        // Pale panel
  well: Color(0xFFE2E0D6),        // Inset well
  hairline: Color(0x2417181A),    // #17181A at 14%
  text: Color(0xFF17181A),        // Deep architectural ink
  textSecondary: Color(0xFF484A4D), // Muted graphite
  textMuted: Color(0xFF66686B),   // Plaster muted (4.7:1 on page)
  accent: Color(0xFFF2B705),      // Cadmium yellow
  onAccent: Color(0xFF17181A),    // Ink text (9.8:1 on yellow)
  approved: Color(0xFF2E7D55),    // Mondrian green
  warning: Color(0xFFC9701A),     // Structural amber
  collision: Color(0xFFB02A37),   // Architectural carmine
  social: Color(0xFF2F5DA8),      // Mondrian cobalt
  search: Color(0xFF1E7F6B),      // Viridian
  email: Color(0xFFC75A78),       // Rose madder
  display: Color(0xFFD9692B),     // Cadmium orange
  video: Color(0xFFB8322A),       // Carmine
  radiusCard: 4,                  // Sharp 4px modernist corners
  radiusControl: 2,
  radiusTag: 2,
  structuralRuleWidth: 2.0,       // 2px signature structural ink rules
  isDark: false,
);

// ============================================================================
// DYNAMIC APP THEME CONTROLLER & FACADE
// ============================================================================

class AppTheme {
  static final List<CgTokens> availableThemes = [
    gessoPigment,
    chiaroscuro,
    neoplastic,
  ];

  /// Currently active theme notifier. Listen to this in MaterialApp to hot-swap!
  static final ValueNotifier<CgTokens> activeThemeNotifier =
      ValueNotifier<CgTokens>(gessoPigment);

  static CgTokens get tokens => activeThemeNotifier.value;

  static void setTheme(CgTokens theme) {
    activeThemeNotifier.value = theme;
  }

  static void setThemeById(String id) {
    final match = availableThemes.firstWhere(
      (t) => t.id.toLowerCase() == id.toLowerCase(),
      orElse: () => gessoPigment,
    );
    setTheme(match);
  }

  // --- Dynamic Color Roles (Always maps to the current active theme) ---
  static Color get page => tokens.page;
  static Color get card => tokens.card;
  static Color get well => tokens.well;
  static Color get hairline => tokens.hairline;
  static Color get textPrimary => tokens.text;
  static Color get textSecondary => tokens.textSecondary;
  static Color get textMuted => tokens.textMuted;
  static Color get textInverse => tokens.onAccent;
  static Color get accent => tokens.accent;
  static Color get onAccent => tokens.onAccent;
  static Color get approved => tokens.approved;
  static Color get warning => tokens.warning;
  static Color get collision => tokens.collision;
  static Color get social => tokens.social;
  static Color get search => tokens.search;
  static Color get email => tokens.email;
  static Color get display => tokens.display;
  static Color get video => tokens.video;

  // Semantic Action Roles
  static Color get primary => tokens.accent;
  static Color get brandAccent => tokens.accent;
  static Color get brandDark => tokens.text;

  // Status Colors (Never neon, strictly WCAG compliant)
  static Color get statusApproved => tokens.approved;
  static Color get statusChanges => tokens.warning;
  static Color get statusRejected => tokens.collision;
  static Color get statusSubmitted => tokens.accent;
  static Color get statusDraft => tokens.textMuted;
  static Color get statusScheduled => tokens.social;

  // Status Background Tints (Subtle 12% washes)
  static Color get statusApprovedBg => tokens.approved.withOpacity(0.12);
  static Color get statusChangesBg => tokens.warning.withOpacity(0.12);
  static Color get statusRejectedBg => tokens.collision.withOpacity(0.12);
  static Color get statusSubmittedBg => tokens.accent.withOpacity(0.12);
  static Color get statusDraftBg => tokens.well;
  static Color get statusScheduledBg => tokens.social.withOpacity(0.12);

  // Surface Aliases for Compatibility
  static Color get systemBackground => tokens.page;
  static Color get secondarySystemBackground => tokens.card;
  static Color get tertiarySystemBackground => tokens.well;
  static Color get slabQuartz => tokens.card;
  static Color get slabElevated => tokens.well;
  static Color get slabPill => tokens.well;
  static Color get slabSubtle => tokens.page;
  static Color get canvasVoid => tokens.well;
  static Color get canvasAbyssal => tokens.page;
  static Color get borderCard => tokens.hairline;
  static Color get borderSage => tokens.hairline;
  static Color get separator => tokens.hairline;
  static Color get rimKeyLight => tokens.hairline;
  static Color get paper => tokens.page;
  static Color get canvas => tokens.page;
  static Color get forge => tokens.text;
  static Color get leaf => tokens.card;
  static Color get bone => tokens.well;
  static Color get label => tokens.text;
  static Color get secondaryLabel => tokens.textSecondary;
  static Color get tertiaryLabel => tokens.textMuted;
  static Color get quaternaryLabel => tokens.textMuted.withOpacity(0.5);
  static Color get verdictLime => tokens.approved;
  static Color get verdictLimeDark => tokens.approved;
  static Color get solarTangerine => tokens.warning;
  static Color get signalCoral => tokens.collision;
  static Color get crimsonNeedle => tokens.collision;
  static Color get phosphorChartreuse => tokens.accent;
  static Color get glacialCyan => tokens.social;
  static Color get imperialAmethyst => tokens.email;
  static Color get celadonSage => tokens.approved;
  static Color get accentGold => tokens.warning;
  static Color get moss => tokens.approved;
  static Color get warmAmber => tokens.warning;
  static Color get appleBlue => tokens.social;
  static Color get appleGreen => tokens.approved;
  static Color get appleRed => tokens.collision;
  static Color get appleOrange => tokens.warning;

  // Channel Color Mapping
  static Color getChannelColor(String channel) => tokens.getChannelColor(channel);

  static IconData getChannelIcon(String channel) {
    switch (channel.toLowerCase().trim()) {
      case 'social':
      case 'paid social':
        return Icons.campaign_rounded;
      case 'email':
      case 'crm':
        return Icons.alternate_email_rounded;
      case 'search':
      case 'paid search':
        return Icons.search_rounded;
      case 'display':
      case 'programmatic':
        return Icons.view_carousel_rounded;
      case 'influencer':
        return Icons.person_pin_circle_rounded;
      case 'video':
      case 'youtube':
        return Icons.smart_display_rounded;
      default:
        return Icons.hub_rounded;
    }
  }

  static Color getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return statusApproved;
      case 'ChangesRequested':
      case 'Changes':
        return statusChanges;
      case 'Rejected':
        return statusRejected;
      case 'Scheduled':
        return statusScheduled;
      case 'Submitted':
      case 'InReview':
      case 'In review':
      case 'Needs review':
        return statusSubmitted;
      default:
        return statusDraft;
    }
  }

  static Color getStatusBgColor(String status) {
    switch (status) {
      case 'Approved':
        return statusApprovedBg;
      case 'ChangesRequested':
      case 'Changes':
        return statusChangesBg;
      case 'Rejected':
        return statusRejectedBg;
      case 'Scheduled':
        return statusScheduledBg;
      case 'Submitted':
      case 'InReview':
      case 'In review':
      case 'Needs review':
        return statusSubmittedBg;
      default:
        return statusDraftBg;
    }
  }

  // --- Depth Shadows (Quiet, Neutral, Non-Glowing per Unslop) ---
  static List<BoxShadow> get appleCardShadow => [
    BoxShadow(
      color: tokens.isDark ? const Color(0x66000000) : const Color(0x0C1F1B16),
      blurRadius: tokens.id == 'c' ? 0 : 4,
      offset: tokens.id == 'c' ? Offset.zero : const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get dualLayerDepth => appleCardShadow;

  static List<BoxShadow> get appleFloatingShadow => [
    BoxShadow(
      color: tokens.isDark ? const Color(0x88000000) : const Color(0x141F1B16),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static const LinearGradient appleCanvasGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Colors.transparent],
  );

  /// Brand Monogram (CG)
  static Widget buildBrandMonogram({double size = 28}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tokens.well,
        borderRadius: BorderRadius.circular(tokens.radiusControl),
        border: Border.all(color: tokens.hairline, width: tokens.structuralRuleWidth),
      ),
      alignment: Alignment.center,
      child: Text(
        'CG',
        style: TextStyle(
          color: tokens.accent,
          fontSize: size * 0.44,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  /// Status Capsule (Compliant with Unslop: clean, non-glowing, distinct contrast)
  static Widget buildStatusIndicator(String status, {double fontSize = 11}) {
    final fg = getStatusColor(status);
    final bg = getStatusBgColor(status);
    String label = status;
    if (status == 'Submitted' || status == 'InReview') label = 'In review';
    if (status == 'ChangesRequested') label = 'Changes';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(tokens.radiusTag),
        border: Border.all(color: fg.withOpacity(0.35), width: tokens.structuralRuleWidth),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4.5),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  /// Typographic Headline Helpers
  static TextStyle get headline => TextStyle(
    fontSize: 17,
    height: 22 / 17,
    letterSpacing: -0.43,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static TextStyle serifHeadline({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? textPrimary,
      letterSpacing: -0.6,
      height: 1.2,
    );
  }

  /// Inset Card Builder
  static Widget buildInsetCard({
    required List<Widget> children,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    VoidCallback? onTap,
    bool elevated = false,
    Color? borderColor,
  }) {
    final cardContent = Container(
      decoration: BoxDecoration(
        color: elevated ? tokens.well : tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        border: Border.all(
          color: borderColor ?? tokens.hairline,
          width: tokens.structuralRuleWidth,
        ),
        boxShadow: elevated ? appleFloatingShadow : appleCardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radiusCard),
          onTap: onTap,
          child: cardContent,
        ),
      );
    }
    return cardContent;
  }

  /// Builds the complete ThemeData reflecting the current tokens
  static ThemeData get campaignGridTheme => buildTheme(tokens);

  static ThemeData buildTheme(CgTokens t) {
    final scheme = ColorScheme(
      brightness: t.isDark ? Brightness.dark : Brightness.light,
      primary: t.accent,
      onPrimary: t.onAccent,
      secondary: t.social,
      onSecondary: Colors.white,
      error: t.collision,
      onError: Colors.white,
      surface: t.card,
      onSurface: t.text,
      surfaceContainerHighest: t.well,
      outline: t.hairline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: t.isDark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      primaryColor: t.accent,
      scaffoldBackgroundColor: t.page,
      cardColor: t.card,
      dividerColor: t.hairline,
      fontFamily: 'SF Pro Display',
      appBarTheme: AppBarTheme(
        backgroundColor: t.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: t.text,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: t.text),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: t.onAccent,
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: -0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusControl)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          minimumSize: const Size(44, 44),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: t.card,
          foregroundColor: t.text,
          side: BorderSide(color: t.hairline, width: t.structuralRuleWidth),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusControl)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(44, 44),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          minimumSize: const Size(44, 44),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.well,
        selectedColor: t.accent,
        checkmarkColor: t.onAccent,
        labelStyle: TextStyle(fontSize: 12, color: t.text, fontWeight: FontWeight.w500),
        secondaryLabelStyle: TextStyle(fontSize: 12, color: t.onAccent, fontWeight: FontWeight.w600),
        side: BorderSide(color: t.hairline, width: t.structuralRuleWidth),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusControl)),
        showCheckmark: false,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return t.onAccent;
          return t.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return t.accent;
          return t.well;
        }),
        trackOutlineColor: WidgetStateProperty.all(t.hairline),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.text,
        contentTextStyle: TextStyle(color: t.page, fontSize: 13, fontWeight: FontWeight.w500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusControl)),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: t.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusCard),
          side: BorderSide(color: t.hairline, width: t.structuralRuleWidth),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.well,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.radiusControl),
          borderSide: BorderSide(color: t.hairline, width: t.structuralRuleWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.radiusControl),
          borderSide: BorderSide(color: t.hairline, width: t.structuralRuleWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.radiusControl),
          borderSide: BorderSide(color: t.accent, width: 1.5),
        ),
        hintStyle: TextStyle(color: t.textMuted, fontSize: 13),
      ),
      cardTheme: CardTheme(
        color: t.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusCard),
          side: BorderSide(color: t.hairline, width: t.structuralRuleWidth),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: t.hairline,
        thickness: t.structuralRuleWidth,
        space: 1,
      ),
    );
  }
}
