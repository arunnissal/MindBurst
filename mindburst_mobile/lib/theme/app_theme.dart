import 'package:flutter/material.dart';

class AppTheme {
  // Canvas & Surfaces
  static const Color background = Color(0xFFF8FAFC); // Slate-50
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE2E8F0); // Slate-200
  static const Color textPrimary = Color(0xFF0F172A); // Slate-900
  static const Color textSecondary = Color(0xFF64748B); // Slate-500

  // Brand Palette: Electric Indigo & Violet
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFFEEF2FF);
  static const Color primaryDark = Color(0xFF3730A3);
  static const Color accent = Color(0xFF7C3AED);

  // Backward compatibility aliases
  static const Color scaffoldBg = background;
  static const Color surfaceBg = background;
  static const Color greenAccent = shoppingEmerald;
  static const Color goldAccent = Color(0xFF4F46E5);
  static const Color goldAccentLight = Color(0xFFEEF2FF);
  static const Color goldBorder = Color(0xFFE0E7FF);
  static const Color deleteRed = Color(0xFFEF4444);

  // Semantic Category Colors
  static const Color reminderAmber = Color(0xFFF59E0B);
  static const Color reminderAmberLight = Color(0xFFFEF3C7);
  static const Color taskIndigo = Color(0xFF4F46E5);
  static const Color shoppingEmerald = Color(0xFF10B981);
  static const Color carrySky = Color(0xFF0284C7);
  static const Color noteViolet = Color(0xFF8B5CF6);
  static const Color eventRose = Color(0xFFF43F5E);
  static const Color ideaCyan = Color(0xFF06B6D4);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient reminderGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: cardBg,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: primary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
        iconTheme: IconThemeData(color: primary),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 1.0,
        shadowColor: Colors.black.withOpacity(0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardBorder, width: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 2.0),
        ),
        hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
      ),
    );
  }
}
