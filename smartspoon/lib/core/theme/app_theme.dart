import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // New Palette
  static const Color sky = Color(0xFF73C7E3);
  static const Color linen = Color(0xFFFFF9F0);
  static const Color turquoise = Color(0xFF24B0BA);
  static const Color light = Color(0xFFF0F2F2);
  static const Color navy = Color(0xFF2E4A70);
  static const Color gold = Color(0xFFCF8A40);

  static ThemeData lightTheme() {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = base.textTheme;
    
    const scheme = ColorScheme.light(
      primary: turquoise,
      onPrimary: Colors.white,
      secondary: sky,
      onSecondary: navy,
      tertiary: gold,
      surface: Colors.white,
      onSurface: navy,
      surfaceContainerHighest: linen, // Main background
      outline: sky,
      error: Color(0xFFD32F2F),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: linen,
      primaryColor: turquoise,
      textTheme: GoogleFonts.latoTextTheme(textTheme).apply(
        bodyColor: navy,
        displayColor: navy,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: linen,
        elevation: 0,
        iconTheme: const IconThemeData(color: navy),
        titleTextStyle: GoogleFonts.lato(
          color: navy,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: sky),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: BorderSide(color: sky.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: turquoise, width: 2),
        ),
        labelStyle: const TextStyle(color: navy),
        hintStyle: TextStyle(color: navy.withValues(alpha: 0.5)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: turquoise,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          textStyle: GoogleFonts.lato(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: sky.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: sky.withValues(alpha: 0.2), width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: linen,
        selectedItemColor: turquoise,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        elevation: 8,
      ),
    );
  }

  static ThemeData darkTheme() {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = base.textTheme;

    // Dark mode mapping:
    // Background -> Navy
    // Surface -> Darker Navy
    // Primary -> Turquoise
    // Text -> Linen
    
    const scheme = ColorScheme.dark(
      primary: turquoise,
      onPrimary: navy,
      secondary: sky,
      onSecondary: navy,
      tertiary: gold,
      surface: Color(0xFF1A2C42), // Darker Navy
      onSurface: linen,
      surfaceContainerHighest: navy,
      outline: sky,
      error: Color(0xFFEF5350),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: navy,
      primaryColor: turquoise,
      textTheme: GoogleFonts.latoTextTheme(textTheme).apply(
        bodyColor: linen,
        displayColor: linen,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: navy,
        elevation: 0,
        iconTheme: const IconThemeData(color: linen),
        titleTextStyle: GoogleFonts.lato(
          color: linen,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A2C42),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: BorderSide(color: sky.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: BorderSide(color: sky.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: turquoise, width: 2),
        ),
        labelStyle: const TextStyle(color: linen),
        hintStyle: TextStyle(color: linen.withValues(alpha: 0.5)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: turquoise,
          foregroundColor: navy,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          textStyle: GoogleFonts.lato(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A2C42),
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: sky.withValues(alpha: 0.1), width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: navy,
        selectedItemColor: turquoise,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        elevation: 8,
      ),
    );
  }
}
