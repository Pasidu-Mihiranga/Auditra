import 'package:flutter/material.dart';

/// Responsive utility methods for calculating sizes based on screen dimensions
class ResponsiveUtils {
  /// Get responsive width as a percentage of screen width
  static double getResponsiveWidth(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.width * percentage;
  }
  
  /// Get responsive height as a percentage of screen height
  static double getResponsiveHeight(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.height * percentage;
  }
  
  /// Get responsive font size based on screen width
  /// Scales font size based on screen width (base on 360px width)
  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    final scaleFactor = width / 360;
    return baseSize * scaleFactor.clamp(0.8, 1.3);
  }
  
  /// Get responsive padding based on screen width
  static double getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 12.0;
    if (width < 400) return 14.0;
    if (width < 500) return 16.0;
    return 20.0;
  }
  
  /// Get responsive icon size based on screen width
  static double getResponsiveIconSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 18.0;
    if (width < 400) return 20.0;
    return 24.0;
  }
}
