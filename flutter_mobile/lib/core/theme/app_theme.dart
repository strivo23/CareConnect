import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFFFF3B30);
  static const Color primarySoft = Color(0xFFFFE5E5);
  static const Color background = Colors.white;
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  static ThemeData lightTheme(bool darkModeEnabled) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: darkModeEnabled ? Brightness.dark : Brightness.light,
      surface: darkModeEnabled ? const Color(0xFF1E242C) : Colors.white,
    );

    final base = ThemeData.from(
      colorScheme: scheme,
      useMaterial3: true,
    );

    return base.copyWith(
      scaffoldBackgroundColor: darkModeEnabled ? const Color(0xFF111418) : scheme.surface,
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: darkModeEnabled ? const Color(0xFF1E242C) : scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkModeEnabled ? const Color(0xFF1E242C) : scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkModeEnabled ? const Color(0xFF1E242C) : scheme.surface,
        indicatorColor: primary.withValues(alpha: 0.16),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkModeEnabled ? const Color(0xFF282E38) : scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
