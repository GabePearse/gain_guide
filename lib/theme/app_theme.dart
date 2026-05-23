import 'package:flutter/material.dart';

class AppTheme {
  static const Color ink = Color(0xFF171A16);
  static const Color muted = Color(0xFF73786F);
  static const Color surface = Color(0xFFF4F6F0);
  static const Color card = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF24735A);
  static const Color accent = Color(0xFFC7553F);
  static const Color gold = Color(0xFFB9852D);
  static const Color line = Color(0xFFE3E6DD);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: accent,
      surface: card,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        foregroundColor: ink,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0.5,
        color: card,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: line,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: const BorderSide(color: line),
          foregroundColor: ink,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: ink,
        foregroundColor: Colors.white,
        extendedTextStyle: TextStyle(fontWeight: FontWeight.w800),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w900
                : FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: line,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 26,
          height: 1.1,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
        headlineMedium: TextStyle(
          fontSize: 32,
          height: 1.08,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        bodyLarge: TextStyle(fontSize: 16, height: 1.45),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45),
        bodySmall: TextStyle(fontSize: 12, height: 1.35),
      ).apply(
        bodyColor: ink,
        displayColor: ink,
      ),
    );
  }
}
