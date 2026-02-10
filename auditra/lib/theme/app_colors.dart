import 'package:flutter/material.dart';

/// Centralized color palette for the application.
/// Uses the defined 9-color theme.
class AppColors {
  // Core Palette
  static const Color darkNavy = Color(0xFF0A1628);
  static const Color strongBlue = Color(0xFF0570B0);
  static const Color blue = Color(0xFF067BC2);
  static const Color lightBlue = Color(0xFF84BCDA);
  static const Color cream = Color(0xFFFFF8E7); // Background
  static const Color yellow = Color(0xFFECC30B);
  static const Color orange = Color(0xFFF09D2A);
  static const Color orangeRed = Color(0xFFF37748);
  static const Color red = Color(0xFFD56062);

  // Semantic Aliases
  static const Color background = cream;
  static const Color surface = cream;
  static const Color text = darkNavy;
  static const Color primary = strongBlue;
  static const Color secondary = lightBlue;
  static const Color accent = orange;
  static const Color error = red;
  static const Color warning = yellow;
  static const Color info = blue;
  static const Color danger = orangeRed;
  static const Color success = lightBlue; // Using Light Blue/Sage equivalent for success/completion

  // UI Specific
  static const Color divider = Color(0xFFE0E0E0);
  static const Color shadow = Color(0x1F000000); // 12% Black
  
  // Card Gradients
  static const List<Color> cardGradient = [
    cream,
    Color(0xFFFFFDF5), // Lighter Cream
    Color(0xFFF0F9FF), // Very light blue tint
  ];
}
