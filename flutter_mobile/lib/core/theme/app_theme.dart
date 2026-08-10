import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Palette Constants requested for CareConnect
  static const Color darkBackground = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF151E30);
  static const Color darkCard = Color(0xFF1A2437);
  static const Color primaryRed = Color(0xFFE93F41);
  static const Color darkRed = Color(0xFFD92F32);
  static const Color lightRed = Color(0xFFF04446);
  static const Color emergencyRed = Color(0xFFE93F41);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color successGreen = Color(0xFF22C55E);
  static const Color infoBlue = Color(0xFF3B82F6);
  static const Color textWhite = Colors.white;
  static const Color textSecondary = Color(0xFF94A3B8);

  // Backward-compatible properties
  static const Color primary = Color(0xFFE93F41);
  static const Color primaryTeal = Color(0xFFE93F41);
  static const Color primarySoft = Color(0x26E93F41);
  static const Color background = darkBackground;
  static const Color success = successGreen;
  static const Color warning = accentAmber;
  static const Color danger = emergencyRed;
  static const Color error = emergencyRed;

  static ThemeData lightTheme(bool darkModeEnabled) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryRed,
      brightness: Brightness.dark,
      surface: darkCard,
      onSurface: textWhite,
    );

    final base = ThemeData.from(
      colorScheme: scheme,
      useMaterial3: true,
    );

    return base.copyWith(
      scaffoldBackgroundColor: darkBackground,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: textWhite,
        displayColor: textWhite,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkCard,
        foregroundColor: textWhite,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        color: darkCard,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkCard,
        indicatorColor: primaryRed.withValues(alpha: 0.24),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2E3D52)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2E3D52)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryRed, width: 2),
        ),
      ),
    );
  }
}
