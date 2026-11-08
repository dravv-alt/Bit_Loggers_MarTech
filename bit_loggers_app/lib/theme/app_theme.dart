import 'dart:ui';
import 'package:flutter/material.dart';

/// CampaignGrid Wireframe Design System
/// Derived directly from the Framer wireframes (https://campaigngrid.framer.website/).
/// Principles: "No multiple subtexts, no pills, and no BS clear design."
class AppTheme {
  // Core Surface & Ink Tokens (Framer Wireframe Hex values)
  static const Color paper = Color(0xFFF5F6F8);        // Clean, airy wireframe canvas
  static const Color canvas = paper;                   // Semantic canvas alias
  static const Color forge = Color(0xFF20211F);        // Deep charcoal/ink black
  static const Color leaf = Color(0xFFFFFFFF);         // Pure white card & sheet surface
  static const Color borderSage = Color(0xFFDEE2E1);   // Hairline 1px border
  static const Color borderCard = Color(0xFFDEE2E1);   // Card border
  static const Color brandAccent = Color(0xFF2D55A2);  // Cobalt accent / CG monogram
  static const Color brandDark = Color(0xFF20211F);    // Charcoal brand mark

  // Action & Verdict Tokens
  static const Color verdictLime = Color(0xFFD7F46A);  // Architectural Lime highlight (#D7F46A)
  static const Color verdictLimeDark = Color(0xFF2C5E43); // Dark forest green accent
  static const Color accentGold = Color(0xFFF0B323);   // Architectural ochre highlight
  static const Color moss = Color(0xFF137333);         // Visual growth telemetry
  static const Color warmAmber = Color(0xFFD97706);    // Visual pacing accent
  static const Color bone = Color(0xFFE5E7EB);         // Track surface
  static const Color crimsonNeedle = Color(0xFFB9301D);// Pacing warning needle

  // Compatibility Tokens
  static const Color primary = forge;
  static const Color card = leaf;
  static const Color surface = leaf;
  static const Color cardBorder = borderSage;

  // Apple HIG Semantic Palette
  static const Color systemBackground = Color(0xFFF2F2F7);          // Inset grouped canvas
  static const Color secondarySystemBackground = Color(0xFFFFFFFF); // Grouped card surface
  static const Color tertiarySystemBackground = Color(0xFFE5E5EA);  // Search wells & track fields
  static const Color label = Color(0xFF1C1C1E);                      // Primary ink (high contrast)
  static const Color secondaryLabel = Color(0xFF6C6C70);             // Muted subtext & captions
  static const Color tertiaryLabel = Color(0xFF8E8E93);              // Subtle timestamps / badges
  static const Color quaternaryLabel = Color(0xFFAEAEB2);            // Inactive placeholders
  static const Color separator = Color(0x1F000000);                  // 0.5pt Apple hairline divider

  // Apple HIG Dual-Layer Ambient Depth (Physical Lighting Simulation)
  static const List<BoxShadow> appleCardShadow = [
    BoxShadow(
      color: Color(0x06000000), // 2.5% black tight ambient occlusion
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x0A000000), // 4% black soft diffuse key light
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> appleFloatingShadow = [
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];

  // Text Colors
  static const Color textPrimary = Color(0xFF20211F);   // Deep graphite ink
  static const Color textSecondary = Color(0xFF777972); // Muted slate (readable neutral)
  static const Color textMuted = Color(0xFF777972);
  static const Color textInverse = Color(0xFFFFFFFF);   // Pure white on dark buttons
  static const Color textInverseMuted = Color(0xFFB7C5D1);

  // Soft Wireframe Status Tints (Subtle, non-distracting, zero-slop)
  static const Color statusApproved = Color(0xFF137333);
  static const Color statusApprovedBg = Color(0xFFE6F4EA);

  static const Color statusChanges = Color(0xFF9C3A27);
  static const Color statusChangesBg = Color(0xFFFDE8E4);

  static const Color statusRejected = Color(0xFFB9301D);
  static const Color statusRejectedBg = Color(0xFFFBDDD7);

  static const Color statusDraft = Color(0xFF555950);
  static const Color statusDraftBg = Color(0xFFECEDE9);

  static const Color statusSubmitted = Color(0xFF8A542C); // Warm tan / In review
  static const Color statusSubmittedBg = Color(0xFFF8EBDD);

  static const Color statusScheduled = Color(0xFF234C82); // Soft blue / Scheduled
  static const Color statusScheduledBg = Color(0xFFE5EDF7);

  // Channel Palette (Vibrant, distinct, high-contrast modern tones)
  static Color getChannelColor(String channel) {
    switch (channel.toLowerCase().trim()) {
      case 'social':
      case 'paid social':
        return const Color(0xFF2563EB); // Royal Blue
      case 'email':
        return const Color(0xFF7C3AED); // Amethyst Purple
      case 'search':
        return const Color(0xFF059669); // Emerald Green
      case 'display':
        return const Color(0xFFEA580C); // Warm Tangerine / Amber
      case 'video':
        return const Color(0xFFE11D48); // Crimson Rose
      case 'influencer':
        return const Color(0xFF0891B2); // Cyan / Teal
      default:
        return const Color(0xFF64748B); // Cool Slate
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
        border: Border.all(color: borderSage.withOpacity(0.4), width: 0.5),
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
      scaffoldBackgroundColor: paper,
      primaryColor: forge,
      colorScheme: const ColorScheme.light(
        primary: forge,
        onPrimary: leaf,
        secondary: forge,
        onSecondary: leaf,
        surface: leaf,
        onSurface: textPrimary,
        error: statusRejected,
        onError: leaf,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: leaf,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: forge,
          foregroundColor: leaf,
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: leaf,
          foregroundColor: forge,
          side: const BorderSide(color: borderSage, width: 1),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: forge,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: forge,
        contentTextStyle: TextStyle(color: leaf, fontSize: 13, fontWeight: FontWeight.w500),
        behavior: SnackBarBehavior.floating,
      ),
      cardTheme: CardTheme(
        color: leaf,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: borderSage, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderSage,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: leaf,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderSage, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderSage, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: forge, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textSecondary, fontSize: 13),
      ),
    );
  }
}
