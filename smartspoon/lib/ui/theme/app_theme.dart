import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = base.textTheme;
    const scheme = ColorScheme.light(
      primary: Color(0xFF6C63FF),
      onPrimary: Colors.white,
      secondary: Color(0xFF7C3AED),
      surface: Colors.white,
      onSurface: Colors.black,
      surfaceVariant: Color(0xFFF5F5F5),
      outline: Color(0xFFE5E7EB),
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surfaceVariant,
      textTheme: GoogleFonts.latoTextTheme(
        textTheme,
      ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: scheme.onSurface),
        titleTextStyle: GoogleFonts.lato(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: scheme.outline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: scheme.primary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        backgroundColor: scheme.surface,
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = base.textTheme;
    const scheme = ColorScheme.dark(
      primary: Color(0xFF8B77FF),
      onPrimary: Colors.white,
      secondary: Color(0xFF8B5CF6),
      surface: Color(0xFF121212),
      onSurface: Colors.white,
      surfaceVariant: Color(0xFF1F1F1F),
      outline: Color(0xFF2A2A2A),
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: GoogleFonts.latoTextTheme(
        textTheme,
      ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: scheme.onSurface),
        titleTextStyle: GoogleFonts.lato(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: scheme.outline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: scheme.primary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        backgroundColor: scheme.surfaceVariant,
      ),
    );
  }
}
