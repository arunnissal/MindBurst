import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFFFAFAFA);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF737373);
  static const Color goldAccent = Color(0xFFC5A059);
  static const Color goldAccentLight = Color(0xFFF7F3E9);
  static const Color goldBorder = Color(0xFFE8E2D5);
  static const Color deleteRed = Color(0xFFE53935);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      primaryColor: goldAccent,
      colorScheme: ColorScheme.light(
        primary: goldAccent,
        surface: cardBg,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: goldAccent,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
        iconTheme: IconThemeData(color: goldAccent),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: goldBorder, width: 0.8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: goldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: goldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: goldAccent, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
      ),
    );
  }
}
