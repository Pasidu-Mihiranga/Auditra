import 'package:flutter/material.dart';

/// Centralized color palette for the application.
/// Matches the Auditra web app blue-based palette.
class AppColors {
  // Core Palette
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color secondary = Color(0xFF60A5FA);
  static const Color background = Color(0xFFF0F4F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardInner = Color(0xFFF8FAFC);

  // Text
  static const Color text = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  // Status Colors
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);

  // UI Specific
  static const Color divider = Color(0xFFE2E8F0);
  static const Color shadow = Color(0x1F000000); // 12% Black

  // Semantic Aliases
  static const Color accent = primaryLight;
  static const Color danger = error;

  // Card Gradients
  static const List<Color> cardGradient = [
    surface,
    cardInner,
    Color(0xFFF0F4F8),
  ];

  // Primary gradients
  static const List<Color> primaryGradient = [
    primaryLight,
    primary,
  ];

  static const List<Color> primaryDarkGradient = [
    primary,
    primaryDark,
  ];
}
