import 'dart:ui';
import 'package:flutter/material.dart';

/// CampaignGrid Bespoke Atelier & Warm Editorial Design System
/// Replaces cold sterile gray canvases and generic electric blue/Tailwind palettes
/// with warm alabaster cotton paper, deep obsidian umber ink, and artisanal pigments.
class AppTheme {
  // Bespoke Surface & Ink Tokens (Warm Alabaster & Limewash Linen ground — ZERO sterile gray)
  static const Color paper = Color(0xFFF9F7F2);        // Warm Alabaster / Limewash Linen canvas
  static const Color canvas = paper;                   // Semantic canvas alias
  static const Color forge = Color(0xFF181715);        // Deep Obsidian Umber ink black
  static const Color leaf = Color(0xFFFFFFFF);         // Warm Ivory Cotton card & sheet surface
  static const Color borderSage = Color(0xFFE6E1D6);   // Raw Linen 0.5pt hairline border
  static const Color borderCard = Color(0xFFE6E1D6);   // Card border
  static const Color brandAccent = Color(0xFFB8532F);  // Seville Terracotta / Burnt Ochre accent
  static const Color brandDark = Color(0xFF181715);    // Deep Umber brand mark

  // Action & Verdict Tokens (Artisanal Pigments — No Tailwind Neon)
  static const Color verdictLime = Color(0xFF2A5940);  // Forest Pine Sage
  static const Color verdictLimeDark = Color(0xFF1F4835); // Deep British Racing Green
  static const Color accentGold = Color(0xFFC07722);   // Burnished Amber Gold
  static const Color moss = Color(0xFF1F4835);         // British Racing Green
  static const Color warmAmber = Color(0xFFB46C1E);    // Warm Honey Amber
  static const Color bone = Color(0xFFF0EDE4);         // Warm Oat track surface
  static const Color crimsonNeedle = Color(0xFF932F23);// Venetian Oxblood needle

  // Compatibility Tokens
  static const Color primary = Color(0xFF181715);      // Deep Obsidian Umber Primary Action Ink
  static const Color card = leaf;
  static const Color surface = leaf;
  static const Color cardBorder = borderSage;

  // Artisanal Pigment Palette (Replaces generic Electric Blue with Parisian Twilight Indigo & natural dyes)
  static const Color appleBlue = Color(0xFF233E5B);       // Parisian Twilight Indigo (Restrained, deep, artisanal)
  static const Color appleBlueDark = Color(0xFF182B3F);
  static const Color appleBlueLight = Color(0xFFEDF2F7);  // Soft atmospheric mist
  static const Color appleIndigo = Color(0xFF4A3E6D);     // Byzantine Nightshade
  static const Color applePurple = Color(0xFF58334E);     // Blackberry Plum
  static const Color applePink = Color(0xFFA63D56);       // Damask Rose
  static const Color appleRed = Color(0xFF932F23);        // Venetian Oxblood
  static const Color appleOrange = Color(0xFFB46C1E);     // Warm Honey Amber
  static const Color appleYellow = Color(0xFFC78426);     // Polished Brass
  static const Color appleGreen = Color(0xFF1F4835);      // British Racing Green
  static const Color appleMint = Color(0xFF285C50);       // Alpine Pine
  static const Color appleTeal = Color(0xFF225B64);       // Aegean Spruce

  // Bespoke Warm Semantic Palette (Warm Alabaster System — NO cold gray #F2F2F7)
  static const Color systemBackground = Color(0xFFF9F7F2);          // Warm Alabaster Canvas
  static const Color secondarySystemBackground = Color(0xFFFFFFFF); // Warm Ivory Cotton Surface
  static const Color tertiarySystemBackground = Color(0xFFF0EDE4);  // Warm Oat / Recessed Fields
  static const Color label = Color(0xFF181715);                      // Deep Obsidian Umber (high contrast warm ink)
  static const Color secondaryLabel = Color(0xFF6B665E);             // French Mineral Slate
  static const Color tertiaryLabel = Color(0xFF9E988E);              // Warm Sandstone
  static const Color quaternaryLabel = Color(0xFFC7C2B8);            // Soft Weathered Flax
  static const Color separator = Color(0xFFE6E1D6);                  // 0.5pt Raw Linen Hairline

  // Atmospheric Canvas Gradients (Warm Alabaster luminous veil instead of blue-gray)
  static const LinearGradient appleCanvasGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFAF6EE), // Luminous warm alabaster veil
      Color(0xFFF9F7F2), // Smooth warm cotton
      Color(0xFFF9F7F2),
    ],
    stops: [0.0, 0.4, 1.0],
  );

  static const LinearGradient appleHeroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF24221F), // Deep Velvet Umber
      Color(0xFF141311), // Midnight Obsidian
    ],
  );

  static const LinearGradient appleAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF181715), // Deep Umber Ink
      Color(0xFF2B2724), // Warm Charcoal
    ],
  );

  // Dual-Layer Ambient Warm Lighting (Warm umber contact + soft diffuse illumination)
  static const List<BoxShadow> appleCardShadow = [
    BoxShadow(
      color: Color(0x0A2B2010), // Warm umber contact (4%)
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x0E2B2010), // Warm diffuse key light (5.5%)
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> appleGlowBlue = [
    BoxShadow(
      color: Color(0x20233E5B), // Soft Parisian indigo ambient glow
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> appleFloatingShadow = [
    BoxShadow(
      color: Color(0x0F2B2010),
      blurRadius: 8,
      offset: Offset(0, 3),
    ),
    BoxShadow(
      color: Color(0x182B2010),
      blurRadius: 28,
      offset: Offset(0, 12),
    ),
  ];

  // Text Colors
  static const Color textPrimary = Color(0xFF181715);   // Deep Obsidian Umber
  static const Color textSecondary = Color(0xFF6B665E); // French Mineral Slate
  static const Color textMuted = Color(0xFF9E988E);     // Warm Sandstone
  static const Color textInverse = Color(0xFFFDFBF7);   // Warm Ivory on dark controls
  static const Color textInverseMuted = Color(0xFFD4CEC3);

  // Artisanal Semantic Status Tints
  static const Color statusApproved = Color(0xFF1F4835);       // British Racing Green
  static const Color statusApprovedBg = Color(0xFFEAF2ED);     // Soft Celadon Wash

  static const Color statusChanges = Color(0xFFB46C1E);        // Warm Honey Amber
  static const Color statusChangesBg = Color(0xFFFAF1E3);      // Soft Wheat Wash

  static const Color statusRejected = Color(0xFF932F23);       // Venetian Oxblood
  static const Color statusRejectedBg = Color(0xFFF9ECE9);     // Soft Antique Rose Wash

  static const Color statusDraft = Color(0xFF6B665E);          // French Mineral Slate
  static const Color statusDraftBg = Color(0xFFF0EDE4);        // Soft Oat Wash

  static const Color statusSubmitted = Color(0xFF233E5B);      // Parisian Twilight Indigo
  static const Color statusSubmittedBg = Color(0xFFEDF2F7);    // Soft Indigo Mist

  static const Color statusScheduled = Color(0xFF4A3E6D);      // Byzantine Nightshade
  static const Color statusScheduledBg = Color(0xFFF2EFF7);    // Soft Violet Mist

  // Channel Palette (Artisanal pigment tones — NO generic Tailwind hexes)
  static Color getChannelColor(String channel) {
    switch (channel.toLowerCase().trim()) {
      case 'social':
      case 'paid social':
        return const Color(0xFF213B56); // Deep Venetian Cobalt
      case 'email':
        return const Color(0xFF532E4E); // Blackberry Plum
      case 'search':
        return const Color(0xFF6E532B); // Cyprus Bronze
      case 'display':
        return const Color(0xFF934F27); // Seville Rust Ochre
      case 'video':
        return const Color(0xFF832A38); // Cordovan Oxblood
      case 'influencer':
        return const Color(0xFF20555E); // Aegean Spruce
      default:
        return const Color(0xFF5E5950); // Warm Mineral Umber
    }
  }

  static IconData getChannelIcon(String channel) {
    switch (channel.toLowerCase()) {
      case 'social':
      case 'paid social':
        return Icons.campaign_outlined;
      case 'email':
        return Icons.alternate_email_rounded;
      case 'search':
        return Icons.search_rounded;
      case 'display':
        return Icons.view_carousel_outlined;
      case 'influencer':
        return Icons.person_pin_circle_outlined;
      case 'video':
        return Icons.smart_display_outlined;
      default:
        return Icons.hub_outlined;
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

  /// Builds the clean wireframe status indicator (subtle tint, crisp text, NO round pill)
  static Widget buildStatusIndicator(String status, {double fontSize = 10}) {
    final fg = getStatusColor(status);
    final bg = getStatusBgColor(status);
    String label = status;
    if (status == 'Submitted' || status == 'InReview') label = 'In review';
    if (status == 'ChangesRequested') label = 'Changes';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withOpacity(0.15), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: fg,
          letterSpacing: 0.02,
        ),
      ),
    );
  }

  /// Builds the brand monogram (CG)
  static Widget buildBrandMonogram({double size = 26}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: forge,
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        'CG',
        style: TextStyle(
          color: leaf,
          fontSize: size * 0.44,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  /// Typographic Helpers
  static TextStyle serifHeadline({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w600,
    Color color = textPrimary,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFamily: 'serif',
      letterSpacing: -0.4,
      height: 1.2,
    );
  }

  static TextStyle wireframeHeading({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w600,
    Color color = textPrimary,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: -0.5,
      height: 1.2,
    );
  }

  static TextStyle wireframeEyebrow({
    double fontSize = 9,
    FontWeight fontWeight = FontWeight.w600,
    Color color = textSecondary,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: 0.08,
      height: 1.2,
    );
  }

  static TextStyle groteskBody({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color color = textPrimary,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.4,
    );
  }

  static TextStyle tabularFigures({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.bold,
    Color color = textPrimary,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  // --- Apple HIG SF Pro Dynamic Typography Scale ---
  static const TextStyle largeTitle = TextStyle(
    fontSize: 34,
    height: 41 / 34,
    letterSpacing: -1.05,
    fontWeight: FontWeight.w700,
    color: label,
  );

  static const TextStyle title1 = TextStyle(
    fontSize: 28,
    height: 34 / 28,
    letterSpacing: -0.80,
    fontWeight: FontWeight.w700,
    color: label,
  );

  static const TextStyle title2 = TextStyle(
    fontSize: 22,
    height: 28 / 22,
    letterSpacing: -0.70,
    fontWeight: FontWeight.w600,
    color: label,
  );

  static const TextStyle title3 = TextStyle(
    fontSize: 20,
    height: 25 / 20,
    letterSpacing: -0.60,
    fontWeight: FontWeight.w600,
    color: label,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 17,
    height: 22 / 17,
    letterSpacing: -0.43,
    fontWeight: FontWeight.w600,
    color: label,
  );

  static const TextStyle body = TextStyle(
    fontSize: 17,
    height: 22 / 17,
    letterSpacing: -0.43,
    fontWeight: FontWeight.w400,
    color: label,
  );

  static const TextStyle callout = TextStyle(
    fontSize: 16,
    height: 20 / 16,
    letterSpacing: -0.32,
    fontWeight: FontWeight.w400,
    color: label,
  );

  static const TextStyle subhead = TextStyle(
    fontSize: 15,
    height: 19 / 15,
    letterSpacing: 0.0,
    fontWeight: FontWeight.w400,
    color: secondaryLabel,
  );

  static const TextStyle footnote = TextStyle(
    fontSize: 13,
    height: 16 / 13,
    letterSpacing: 0.03,
    fontWeight: FontWeight.w400,
    color: secondaryLabel,
  );

  static const TextStyle caption1 = TextStyle(
    fontSize: 12,
    height: 15 / 12,
    letterSpacing: 0.12,
    fontWeight: FontWeight.w500,
    color: secondaryLabel,
  );

  static const TextStyle caption2 = TextStyle(
    fontSize: 11,
    height: 14 / 11,
    letterSpacing: 0.15,
    fontWeight: FontWeight.w500,
    color: tertiaryLabel,
  );

  // --- Apple HIG Grouped List & Surface Containers ---
  static Widget buildAppleGroupedCard({
    required List<Widget> children,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    VoidCallback? onTap,
  }) {
    final cardContent = Container(
      decoration: BoxDecoration(
        color: secondarySystemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: appleCardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: cardContent,
        ),
      );
    }
    return cardContent;
  }

  static ThemeData get campaignGridTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: systemBackground,
      primaryColor: primary,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: textInverse,
        secondary: brandAccent,
        onSecondary: textInverse,
        surface: secondarySystemBackground,
        onSurface: label,
        error: appleRed,
        onError: textInverse,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: systemBackground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: label,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: label),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary, // Deep Obsidian Umber Ink
          foregroundColor: textInverse, // Warm Ivory text
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          minimumSize: const Size(44, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: secondarySystemBackground,
          foregroundColor: label,
          side: const BorderSide(color: separator, width: 1.0),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: -0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          minimumSize: const Size(44, 44),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: label,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: -0.2),
          minimumSize: const Size(44, 44),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF181715),
        contentTextStyle: TextStyle(color: Color(0xFFFDFBF7), fontSize: 13, fontWeight: FontWeight.w500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
      cardTheme: CardTheme(
        color: secondarySystemBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: separator,
        thickness: 0.5,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tertiarySystemBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: separator, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: separator, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandAccent, width: 1.5),
        ),
        hintStyle: const TextStyle(color: secondaryLabel, fontSize: 13),
      ),
    );
  }
}
