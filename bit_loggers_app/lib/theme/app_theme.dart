import 'package:flutter/material.dart';

/// CampaignGrid Token System
/// Grounded in archival governance, ledgers, and editorial authority.
class AppTheme {
  // Core 5 Named Hex Tokens
  static const Color paper = Color(0xFFE8E4D9); // Base background (aged ledger paper)
  static const Color forge = Color(0xFF1B3029); // Deep forest green (committed record / irreversible action)
  static const Color leaf = Color(0xFFFBFAF6);  // Near-white working document surface
  static const Color borderSage = Color(0xFFC9D6C3); // Hairline 1px border
  static const Color verdictLime = Color(0xFFD7F46A); // Consequential approval / primary CTA
  static const Color verdictLimeDark = Color(0xFF2C5E43); // Dark forest green accent

  // Compatibility Tokens
  static const Color primary = forge;
  static const Color card = leaf;
  static const Color surface = leaf;
  static const Color cardBorder = borderSage;

  // Muted Governance Status Colors
  static const Color statusApproved = Color(0xFFD7F46A); // Verdict lime
  static const Color statusChanges = Color(0xFFB8924A);  // Muted ochre
  static const Color statusRejected = Color(0xFFB8755B); // Muted clay
  static const Color statusDraft = Color(0xFF727875);    // Neutral grey
  static const Color statusSubmitted = Color(0xFF1B3029);// Deep forest green (in review)
  static const Color statusScheduled = Color(0xFF244A3A);// Forest teal

  // Text Colors
  static const Color textPrimary = Color(0xFF1B3029);   // Deep forest ink
  static const Color textSecondary = Color(0xFF4A5E54); // Muted sage slate
  static const Color textInverse = Color(0xFFFBFAF6);   // Leaf white on dark forge
  static const Color textInverseMuted = Color(0xFFA3B899);

  // Channel Palette (Muted Editorial)
  static Color getChannelColor(String channel) {
    switch (channel.toLowerCase()) {
      case 'social':
        return const Color(0xFF2C5E43);
      case 'email':
        return const Color(0xFF3B5249);
      case 'search':
        return const Color(0xFF476044);
      case 'display':
        return const Color(0xFF5B6941);
      case 'influencer':
        return const Color(0xFF6E5E3D);
      case 'video':
        return const Color(0xFF2B4D40);
      default:
        return const Color(0xFF384F45);
    }
  }

  static Color getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return statusApproved;
      case 'ChangesRequested':
        return statusChanges;
      case 'Rejected':
        return statusRejected;
      case 'Scheduled':
        return statusScheduled;
      case 'Submitted':
        return statusSubmitted;
      default:
        return statusDraft;
    }
  }

  // Typographic Helpers
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

  static ThemeData get campaignGridTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: paper,
      primaryColor: forge,
      colorScheme: const ColorScheme.light(
        primary: forge,
        onPrimary: leaf,
        secondary: verdictLime,
        onSecondary: forge,
        surface: leaf,
        onSurface: textPrimary,
        error: statusRejected,
        onError: leaf,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: forge,
          foregroundColor: leaf,
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: leaf,
          foregroundColor: forge,
          side: const BorderSide(color: borderSage, width: 1.5),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: forge,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
          borderRadius: BorderRadius.circular(16),
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
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderSage, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderSage, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: forge, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textSecondary, fontSize: 13),
      ),
    );
  }
}
