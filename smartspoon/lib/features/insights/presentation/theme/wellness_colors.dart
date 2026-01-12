import 'package:flutter/material.dart';

/// Wellness-focused color palette for the Analytics Dashboard
/// Designed for calming, health-focused UI with full dark mode support
class WellnessColors {
  // Primary Blue Spectrum - Main charts, metrics
  static const Color primaryBlue = Color(0xFF4A90E2);
  static const Color lightBlue = Color(0xFF7DB3F5);
  static const Color deepBlue = Color(0xFF2C5F8D);
  
  // Healing Green Spectrum - Positive trends
  static const Color primaryGreen = Color(0xFF5FB88A);
  static const Color sageGreen = Color(0xFF8FC9A8);
  static const Color forestGreen = Color(0xFF3A8863);
  
  // Warm Comfort Spectrum - Moderate alerts
  static const Color softPeach = Color(0xFFFFB58F);
  static const Color coral = Color(0xFFFF9277);
  static const Color sunsetOrange = Color(0xFFFF7F50);
  
  // Alert Spectrum
  static const Color warmRed = Color(0xFFE57373);
  static const Color amber = Color(0xFFFFB74D);
  
  // Neutral Foundation - Light Mode
  static const Color backgroundCream = Color(0xFFF8F9FA);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color softGray = Color(0xFFE8EDF2);
  static const Color textCharcoal = Color(0xFF2E3A4A);
  static const Color textSlate = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  
  // Dark Mode Variants
  static const Color darkBackground = Color(0xFF1A1F2E);
  static const Color darkCard = Color(0xFF252B3B);
  static const Color darkBorder = Color(0xFF2E3A4A);
  static const Color darkTextPrimary = Color(0xFFE8EDF2);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  
  // Helper methods
  static Color getBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : backgroundCream;
  }
  
  static Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkCard
        : cardWhite;
  }
  
  static Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBorder
        : softGray;
  }
  
  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextPrimary
        : textCharcoal;
  }
  
  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextSecondary
        : textSlate;
  }
  
  static Color getTextMuted(BuildContext context) {
    return textMuted;
  }
}
