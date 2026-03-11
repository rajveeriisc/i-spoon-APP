import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// SmartSpoon — Premium Dual-Theme Design System
///
/// LIGHT (default): Wellness Light — Oura Ring / Apple Health inspired
///   Background   #F8FAFF  soft blue-white
///   Cards        #FFFFFF  pure white with soft indigo shadow
///   Primary      #4F46E5  Indigo (calm, trusted, premium)
///   Secondary    #0EA5E9  Sky Blue
///   Accent       #10B981  Emerald
///   Text 1°      #0F172A  Near-black slate
///   Text 2°      #475569  Slate-600
///   Border       #E2E8F0  Soft gray
///
/// DARK: Premium Forest — Wellness & Longevity inspired
///   Background   #060D0A  Deepest dark forest
///   Cards        #0C1A14  Dark forest green
///   Primary      #10B981  Emerald (Core wellness color)
///   Secondary    #34D399  Light Emerald
///   Accent       #10B981  Emerald
///   Text 1°      #F1F5F9  Slate-100
///   Text 2°      #A7F3D0  Soft Mint (Emerald-200)
///   Border       #1A2F26  Forest border
/// ─────────────────────────────────────────────────────────────────────────────
class AppTheme {
  // ── LIGHT palette ────────────────────────────────────────────────────────────
  static const Color bg      = Color(0xFFF2FBF5); // very soft/light mint green
  static const Color surface = Color(0xFFFFFFFF);

  static const Color indigo  = Color(0xFF10B981); // Emerald is our new Indigo
  static const Color sky     = Color(0xFF34D399); // Soft Emerald
  static const Color emerald = Color(0xFF10B981);
  static const Color amber   = Color(0xFFF59E0B);
  static const Color rose    = Color(0xFFE11D48);

  static const Color textPrimary   = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary  = Color(0xFF94A3B8);
  static const Color border        = Color(0xFFE2E8F0);
  static const Color cardShadow    = Color(0x1A10B981);

  // ── DARK palette ─────────────────────────────────────────────────────────────
  static const Color darkBg            = Color(0xFF000000); // Pure Black
  static const Color darkSurface       = Color(0xFF000000); // Pure Black
  static const Color darkSurfaceCard   = Color(0xFF000000); // Pure Black
  static const Color darkIndigo        = Color(0xFF10B981); // Emerald
  static const Color darkSky           = Color(0xFF34D399); // Light Emerald
  static const Color darkEmerald       = Color(0xFF10B981);
  static const Color darkAmber         = Color(0xFFFBBF24);
  static const Color darkRose          = Color(0xFFFB7185);
  static const Color darkTextPrimary   = Color(0xFFF8FAFC); // Slate 50
  static const Color darkTextSecondary = Color(0xFFCBD5E1); // Slate 300
  static const Color darkTextTertiary  = Color(0xFF64748B); // Slate 500
  static const Color darkBorder        = Color(0xFF1E293B); // Slate 800 (kept slightly lighter for card borders)
  static const Color darkCardShadow    = Color(0x33000000);

  // ── Legacy aliases (backward compat) ─────────────────────────────────────────
  static const Color turquoise = sky;
  static const Color violet    = indigo;
  static const Color teal      = emerald;
  static const Color pink      = rose;
  static const Color gold      = amber;
  static const Color mint      = emerald;
  static const Color coral     = rose;
  static const Color lavender  = Color(0xFFEDE9FE);
  static const Color navy      = textPrimary;
  static const Color linen     = Color(0xFFF5F3FF);
  static const Color light     = Color(0xFFEDE9FE);
  static const Color warmWhite = surface;

  // Auth-specific
  static const Color authBg      = bg;
  static const Color authSurface = Color(0xFFEEF2FF);
  static const Color authBorder  = Color(0xFFDDD6FE);
  static const Color authMuted   = Color(0xFF64748B);

  // ── Gradient helpers (light) ──────────────────────────────────────────────────
  static LinearGradient get headerGradient => const LinearGradient(
        colors: [emerald, Color(0xFF059669)], // Emerald to deep emerald
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get backgroundGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFD6F1E8),
          Color(0xFFF9FFFB),
        ],
      );

  // ── Additional Reference Gradients (Light) ────────────────────────────────────
  static LinearGradient get profileBackgroundGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFD6F1E8),
          Color(0xFFF9FFFB),
        ],
      );
      
  static LinearGradient get canvasBackgroundGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFA1D8FF),
          Color(0xFFE6F4FF),
        ],
      );

  static LinearGradient get primaryGradient => const LinearGradient(
        colors: [emerald, sky],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get accentGradient => const LinearGradient(
        colors: [emerald, sky],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // ── Gradient helpers (dark) ───────────────────────────────────────────────────
  static LinearGradient get darkHeaderGradient => const LinearGradient(
        colors: [darkEmerald, Color(0xFF065F46)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get darkBackgroundGradient => const LinearGradient(
        colors: [darkBg, darkSurface],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // ── Card decoration helpers ───────────────────────────────────────────────────
  static BoxDecoration cardDecoration({double radius = 16}) => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: cardShadow,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      );

  static BoxDecoration darkCardDecoration({double radius = 16}) => BoxDecoration(
        color: darkSurfaceCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: darkBorder, width: 1),
        boxShadow: const [
          BoxShadow(
            color: darkCardShadow,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      );

  // ── Light Theme (default) ─────────────────────────────────────────────────────
  static ThemeData lightTheme() {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = base.textTheme;

    const scheme = ColorScheme.light(
      primary: emerald,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFD1FAE5),
      secondary: sky,
      onSecondary: Colors.white,
      tertiary: indigo,
      onTertiary: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: Color(0xFFEEF2FF),
      outline: border,
      error: rose,
      onError: Colors.white,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      primaryColor: emerald,
      textTheme: GoogleFonts.manropeTextTheme(textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        shadowColor: border,
        scrolledUnderElevation: 1,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: GoogleFonts.manrope(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide: const BorderSide(color: indigo, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide: const BorderSide(color: rose),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textTertiary),
        prefixIconColor: textTertiary,
        suffixIconColor: textTertiary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: indigo,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.0),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: indigo,
          side: const BorderSide(color: indigo),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: indigo,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
        shadowColor: cardShadow,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: indigo,
        unselectedItemColor: textTertiary,
        showUnselectedLabels: true,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 12),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? indigo : textTertiary),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? indigo.withValues(alpha: 0.3)
                : border),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: indigo,
        inactiveTrackColor: border,
        thumbColor: indigo,
        overlayColor: indigo.withValues(alpha: 0.15),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFEEF2FF),
        selectedColor: indigo.withValues(alpha: 0.15),
        labelStyle: const TextStyle(color: textPrimary),
        side: const BorderSide(color: border),
        shape: const StadiumBorder(),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: indigo,
        textColor: textPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.manrope(
            color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        contentTextStyle:
            GoogleFonts.manrope(color: textSecondary, fontSize: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: GoogleFonts.manrope(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: indigo,
        linearTrackColor: border,
        circularTrackColor: border,
      ),
      iconTheme: const IconThemeData(color: textSecondary),
    );
  }

  // ── Dark Theme — premium navy ─────────────────────────────────────────────────
  static ThemeData darkTheme() {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = base.textTheme;

    const scheme = ColorScheme.dark(
      primary: darkEmerald,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF2D3561),
      secondary: darkEmerald,
      onSecondary: Colors.white,
      tertiary: darkSky,
      onTertiary: Color(0xFF0F172A),
      surface: darkSurface,
      onSurface: darkTextPrimary,
      surfaceContainerHighest: Color(0xFF263347),
      outline: darkBorder,
      error: darkRose,
      onError: Colors.white,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: darkBg,
      primaryColor: darkEmerald,
      textTheme: GoogleFonts.manropeTextTheme(textTheme).apply(
        bodyColor: darkTextPrimary,
        displayColor: darkTextPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        elevation: 0,
        shadowColor: darkBorder,
        scrolledUnderElevation: 1,
        iconTheme: const IconThemeData(color: darkTextPrimary),
        titleTextStyle: GoogleFonts.manrope(
          color: darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide: const BorderSide(color: darkEmerald, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide: const BorderSide(color: darkRose),
        ),
        labelStyle: const TextStyle(color: darkTextSecondary),
        hintStyle: const TextStyle(color: darkTextTertiary),
        prefixIconColor: darkTextSecondary,
        suffixIconColor: darkTextSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkEmerald,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.0),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkEmerald,
          side: const BorderSide(color: darkEmerald),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkEmerald,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        shadowColor: darkCardShadow,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: darkEmerald,
        unselectedItemColor: darkTextTertiary,
        showUnselectedLabels: true,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 12),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? darkEmerald : darkTextTertiary),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? darkEmerald.withValues(alpha: 0.4)
                : darkBorder),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: darkEmerald,
        inactiveTrackColor: darkBorder,
        thumbColor: darkEmerald,
        overlayColor: darkEmerald.withValues(alpha: 0.20),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurfaceCard,
        selectedColor: darkEmerald.withValues(alpha: 0.25),
        labelStyle: const TextStyle(color: darkTextPrimary),
        side: const BorderSide(color: darkBorder),
        shape: const StadiumBorder(),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: darkEmerald,
        textColor: darkTextPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.manrope(
            color: darkTextPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        contentTextStyle:
            GoogleFonts.manrope(color: darkTextSecondary, fontSize: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkSurfaceCard,
        contentTextStyle: GoogleFonts.manrope(color: darkTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: darkIndigo,
        linearTrackColor: darkBorder,
        circularTrackColor: darkBorder,
      ),
      iconTheme: const IconThemeData(color: darkTextSecondary),
    );
  }
}
