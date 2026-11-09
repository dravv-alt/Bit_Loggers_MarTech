import 'dart:ui';
import 'package:flutter/material.dart';

/// CampaignGrid "Obsidian Vitreum" (Aether Pro) Design System
/// Transcends generic AI slop, sterile grays, and warm beige templates with
/// an abyssal oceanic cyan-black ground, vitreous smoked quartz crystal slabs,
/// specular rim lighting, and vibrant bioluminescent jewel accents.
class AppTheme {
  // --- Abyssal Canvas & Vitreous Slabs (Deep Oceanic Cyan-Black) ---
  static const Color canvasAbyssal = Color(0xFF080C0F); // Deep Oceanic Cyan-Black Ground
  static const Color canvasVoid = Color(0xFF0B1117);    // Recessed Telemetry Well / Graph Ground
  static const Color slabQuartz = Color(0xFF111820);    // Vitreous Smoked Quartz Primary Inset Slab
  static const Color slabElevated = Color(0xFF16222D);  // Elevated Modal / Hero Spotlight Quartz
  static const Color slabPill = Color(0xFF1C2A37);      // Segmented Toggle / Recessed Control Surface

  // Aliases for compatibility
  static const Color paper = canvasAbyssal;
  static const Color canvas = canvasAbyssal;
  static const Color forge = canvasAbyssal;
  static const Color leaf = Color(0xFFF4F8FA);          // Prismatic Silver-White
  static const Color bone = Color(0xFF16222D);
  static const Color borderSage = Color(0xFF1E2E3D);    // 0.5pt Quartz Hairline
  static const Color borderCard = Color(0xFF243644);    // 0.75pt Bevel Hairline
  static const Color cardBorder = borderCard;

  // --- Bioluminescent Jewel-Tone Accents ---
  static const Color phosphorChartreuse = Color(0xFFD4FF38); // High-voltage Primary Action & ROI
  static const Color glacialCyan = Color(0xFF38E8FF);        // Telemetry, Live Clicks, Correlation Trace
  static const Color solarTangerine = Color(0xFFFF8438);     // Flight Pacing, Due Today, Attention
  static const Color signalCoral = Color(0xFFFF3B5C);        // Conflicts, Failure Simulation, Rejection
  static const Color imperialAmethyst = Color(0xFFB366FF);   // Gemini Argon Engine, Multi-channel Flights
  static const Color celadonSage = Color(0xFF22C55E);        // Verified Signoff, Cryptographic Check

  // Brand & Action Roles
  static const Color brandAccent = phosphorChartreuse;       // Dominant Primary Focus
  static const Color brandDark = canvasAbyssal;
  static const Color primary = phosphorChartreuse;
  static const Color card = slabQuartz;
  static const Color surface = slabQuartz;

  // Compatibility Action Tokens
  static const Color verdictLime = celadonSage;
  static const Color verdictLimeDark = Color(0xFF16A34A);
  static const Color accentGold = solarTangerine;
  static const Color moss = celadonSage;
  static const Color warmAmber = solarTangerine;
  static const Color crimsonNeedle = signalCoral;

  // Apple HIG Chromatic Tokens (Bioluminescent Scale)
  static const Color appleBlue = glacialCyan;
  static const Color appleBlueDark = Color(0xFF1B6B7A);
  static const Color appleBlueLight = Color(0xFF122C38);
  static const Color appleIndigo = imperialAmethyst;
  static const Color applePurple = Color(0xFFC084FC);
  static const Color applePink = Color(0xFFF472B6);
  static const Color appleRed = signalCoral;
  static const Color appleOrange = solarTangerine;
  static const Color appleYellow = Color(0xFFFACC15);
  static const Color appleGreen = celadonSage;
  static const Color appleMint = Color(0xFF2DD4BF);
  static const Color appleTeal = Color(0xFF06B6D4);

  // --- Semantic Color Tokens ---
  static const Color systemBackground = canvasAbyssal;
  static const Color secondarySystemBackground = slabQuartz;
  static const Color tertiarySystemBackground = slabElevated;
  static const Color separator = Color(0xFF1E2E3D);
  static const Color rimKeyLight = Color(0xFF3A5266);

  // --- High-Contrast Typography Spectrum ---
  static const Color textPrimary = Color(0xFFF4F8FA);   // 100% White-Ice (Crisp readable)
  static const Color textSecondary = Color(0xFF94A7B8); // 75% Slate-Silver
  static const Color textMuted = Color(0xFF586E82);     // 50% Muted Dusk
  static const Color textGhost = Color(0xFF334656);     // 30% Dark Graphite
  static const Color textInverse = Color(0xFF081402);   // Deep Ink on Phosphor Chartreuse
  static const Color textInverseMuted = Color(0xFF1E2E3D);

  static const Color label = textPrimary;
  static const Color secondaryLabel = textSecondary;
  static const Color tertiaryLabel = textMuted;
  static const Color quaternaryLabel = textGhost;

  // --- Atmospheric Gradients ---
  static const LinearGradient appleCanvasGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0D141B), // Subtle oceanic aura at the top
      Color(0xFF080C0F), // Deep void body
      Color(0xFF06090C), // Infinite depth foot
    ],
    stops: [0.0, 0.45, 1.0],
  );

  static const LinearGradient appleHeroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF162533), // Luminous smoked quartz catch
      Color(0xFF0E1720), // Abyssal body
    ],
  );

  static const LinearGradient appleAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      phosphorChartreuse,
      Color(0xFFA6E015),
    ],
  );

  // --- Dual-Layer Depth & Specular Ambient Occlusion ---
  static const List<BoxShadow> appleCardShadow = [
    BoxShadow(
      color: Color(0x66000000), // 40% deep contact shadow
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x1A38E8FF), // Subtle cyan specular bounce
      blurRadius: 1,
      offset: Offset(0, 0),
    ),
  ];
  static const List<BoxShadow> dualLayerDepth = appleCardShadow;

  static const List<BoxShadow> appleFloatingShadow = [
    BoxShadow(
      color: Color(0x88000000),
      blurRadius: 28,
      offset: Offset(0, 12),
    ),
    BoxShadow(
      color: Color(0x223A5266),
      blurRadius: 2,
      offset: Offset(0, -1),
    ),
  ];

  static const List<BoxShadow> appleGlowBlue = [
    BoxShadow(
      color: Color(0x3338E8FF),
      blurRadius: 18,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> phosphorGlow = [
    BoxShadow(
      color: Color(0x40D4FF38),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  // --- Status Roles & Translucent Glow Tints ---
  static const Color statusApproved = celadonSage;
  static const Color statusApprovedBg = Color(0x1F22C55E);

  static const Color statusChanges = solarTangerine;
  static const Color statusChangesBg = Color(0x1FFF8438);

  static const Color statusRejected = signalCoral;
  static const Color statusRejectedBg = Color(0x22FF3B5C);

  static const Color statusDraft = textSecondary;
  static const Color statusDraftBg = Color(0x1F94A7B8);

  static const Color statusSubmitted = glacialCyan;
  static const Color statusSubmittedBg = Color(0x1F38E8FF);

  static const Color statusScheduled = imperialAmethyst;
  static const Color statusScheduledBg = Color(0x22B366FF);

  // --- Channel Jewel Palette ---
  static Color getChannelColor(String channel) {
    switch (channel.toLowerCase().trim()) {
      case 'social':
      case 'paid social':
        return const Color(0xFF388BFF); // Electric Cobalt
      case 'email':
        return imperialAmethyst;         // Imperial Amethyst
      case 'search':
        return const Color(0xFFFFB038); // Solar Amber
      case 'display':
        return const Color(0xFF00DC82); // Bioluminescent Emerald
      case 'video':
        return signalCoral;             // Coral Ruby
      case 'influencer':
        return glacialCyan;             // Glacial Cyan
      default:
        return textSecondary;
    }
  }

  static IconData getChannelIcon(String channel) {
    switch (channel.toLowerCase()) {
      case 'social':
      case 'paid social':
        return Icons.campaign_rounded;
      case 'email':
        return Icons.alternate_email_rounded;
      case 'search':
        return Icons.search_rounded;
      case 'display':
        return Icons.view_carousel_rounded;
      case 'influencer':
        return Icons.person_pin_circle_rounded;
      case 'video':
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

  /// Builds the refined Apple native status capsule with glowing beacon pip
  static Widget buildStatusIndicator(String status, {double fontSize = 11}) {
    final fg = getStatusColor(status);
    final bg = getStatusBgColor(status);
    String label = status;
    if (status == 'Submitted' || status == 'InReview') label = 'In Review';
    if (status == 'ChangesRequested') label = 'Changes';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withOpacity(0.35), width: 0.75),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: fg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: fg.withOpacity(0.8), blurRadius: 4, spreadRadius: 1),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the brand monogram (CG) with glowing phosphor highlight
  static Widget buildBrandMonogram({double size = 28}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: slabElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: rimKeyLight.withOpacity(0.4), width: 0.75),
        boxShadow: const [
          BoxShadow(color: Color(0x44000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'CG',
        style: TextStyle(
          color: phosphorChartreuse,
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
      letterSpacing: -0.6,
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
      letterSpacing: -0.6,
      height: 1.2,
    );
  }

  static TextStyle wireframeEyebrow({
    double fontSize = 10,
    FontWeight fontWeight = FontWeight.w700,
    Color color = textSecondary,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: 0.8,
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
      height: 1.45,
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
      fontFeatures: const [
        FontFeature.tabularFigures(),
        FontFeature.slashedZero(),
      ],
    );
  }

  /// Monumental numeric display figure for executive metrics
  static TextStyle monumentalFigure({
    double fontSize = 32,
    FontWeight fontWeight = FontWeight.w700,
    Color color = textPrimary,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: -1.0,
      fontFeatures: const [
        FontFeature.tabularFigures(),
        FontFeature.slashedZero(),
      ],
    );
  }

  // --- Apple HIG SF Pro Dynamic Typography Scale (Dark Mode Optimized) ---
  static const TextStyle largeTitle = TextStyle(
    fontSize: 34,
    height: 41 / 34,
    letterSpacing: -1.05,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );

  static const TextStyle title1 = TextStyle(
    fontSize: 28,
    height: 34 / 28,
    letterSpacing: -0.80,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );

  static const TextStyle title2 = TextStyle(
    fontSize: 22,
    height: 28 / 22,
    letterSpacing: -0.70,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle title3 = TextStyle(
    fontSize: 20,
    height: 25 / 20,
    letterSpacing: -0.60,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 17,
    height: 22 / 17,
    letterSpacing: -0.43,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 17,
    height: 22 / 17,
    letterSpacing: -0.43,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  static const TextStyle callout = TextStyle(
    fontSize: 16,
    height: 20 / 16,
    letterSpacing: -0.32,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  static const TextStyle subhead = TextStyle(
    fontSize: 15,
    height: 19 / 15,
    letterSpacing: 0.0,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );

  static const TextStyle footnote = TextStyle(
    fontSize: 13,
    height: 16 / 13,
    letterSpacing: 0.03,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );

  static const TextStyle caption1 = TextStyle(
    fontSize: 12,
    height: 15 / 12,
    letterSpacing: 0.12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  static const TextStyle caption2 = TextStyle(
    fontSize: 11,
    height: 14 / 11,
    letterSpacing: 0.15,
    fontWeight: FontWeight.w500,
    color: textMuted,
  );

  // --- Vitreous Inset Quartz Card & Surface Containers ---
  static Widget buildAppleGroupedCard({
    required List<Widget> children,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    VoidCallback? onTap,
    bool elevated = false,
    Color? borderColor,
  }) {
    final cardContent = Container(
      decoration: BoxDecoration(
        color: elevated ? slabElevated : slabQuartz,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? rimKeyLight.withOpacity(0.35),
          width: 0.75,
        ),
        boxShadow: elevated ? appleFloatingShadow : appleCardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: cardContent,
        ),
      );
    }
    return cardContent;
  }

  /// Global ThemeData configured for "Obsidian Vitreum"
  static ThemeData get campaignGridTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: canvasAbyssal,
      primaryColor: phosphorChartreuse,
      colorScheme: const ColorScheme.dark(
        primary: phosphorChartreuse,
        onPrimary: textInverse,
        secondary: glacialCyan,
        onSecondary: textInverse,
        surface: slabQuartz,
        onSurface: textPrimary,
        error: signalCoral,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: slabQuartz,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: phosphorChartreuse, // Luminous Phosphor Chartreuse
          foregroundColor: textInverse,        // Deep Obsidian Text
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          minimumSize: const Size(44, 46),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: slabQuartz,
          foregroundColor: textPrimary,
          side: BorderSide(color: rimKeyLight.withOpacity(0.4), width: 0.75),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: -0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          minimumSize: const Size(44, 44),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: phosphorChartreuse,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: -0.2),
          minimumSize: const Size(44, 44),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: slabElevated,
        contentTextStyle: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: rimKeyLight, width: 0.5),
        ),
      ),
      cardTheme: CardTheme(
        color: slabQuartz,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: rimKeyLight.withOpacity(0.35), width: 0.75),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: separator,
        thickness: 0.5,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: canvasVoid,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: rimKeyLight.withOpacity(0.35), width: 0.75),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: rimKeyLight.withOpacity(0.35), width: 0.75),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: phosphorChartreuse, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textMuted, fontSize: 13),
      ),
    );
  }
}
