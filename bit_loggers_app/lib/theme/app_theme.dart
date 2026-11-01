import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFF0A0F1D);
  static const Color surface = Color(0xFF0F172A);
  static const Color card = Color(0xFF1E293B);
  static const Color cardBorder = Color(0xFF334155);

  static const Color primary = Color(0xFF06B6D4); // Cyan
  static const Color primaryLight = Color(0xFF22D3EE);
  static const Color secondary = Color(0xFF0284C7); // Blue

  static const Color statusDraft = Color(0xFF94A3B8);
  static const Color statusSubmitted = Color(0xFFF59E0B);
  static const Color statusApproved = Color(0xFF10B981);
  static const Color statusChanges = Color(0xFFF97316);
  static const Color statusScheduled = Color(0xFF8B5CF6);
  static const Color statusRejected = Color(0xFFEF4444);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        surfaceContainer: card,
        error: statusRejected,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardTheme(
        color: card,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: const Color(0xFF090D16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  static Color getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return statusApproved;
      case 'Submitted':
        return statusSubmitted;
      case 'ChangesRequested':
        return statusChanges;
      case 'Scheduled':
        return statusScheduled;
      case 'Rejected':
        return statusRejected;
      default:
        return statusDraft;
    }
  }

  static Color getChannelColor(String channel) {
    switch (channel) {
      case 'Social':
        return const Color(0xFFEC4899);
      case 'Email':
        return const Color(0xFF3B82F6);
      case 'Search':
        return const Color(0xFFF59E0B);
      case 'Display':
        return const Color(0xFFA855F7);
      case 'Influencer':
        return const Color(0xFF10B981);
      case 'Video':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF06B6D4);
    }
  }
}

