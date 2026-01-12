import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme provider for managing light/dark mode
class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  static const String _themeKey = 'theme_mode';

  /// Get current theme mode
  ThemeMode get themeMode => _themeMode;

  /// Check if dark mode is active
  bool get isDark => _themeMode == ThemeMode.dark;

  /// Load saved theme preference from storage
  Future<void> loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themeKey);
      if (savedTheme != null) {
        _themeMode = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load theme preference: $e');
    }
  }

  /// Toggle between light and dark theme
  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();

    // Save preference
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _themeKey,
        _themeMode == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (e) {
      debugPrint('Failed to save theme preference: $e');
    }
  }

  /// Set specific theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    // Save preference
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _themeKey,
        mode == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (e) {
      debugPrint('Failed to save theme preference: $e');
    }
  }
}

