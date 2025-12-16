import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class DarkModeToggle extends StatelessWidget {
  const DarkModeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService.instance;
    
    return IconButton(
      icon: Text(
        themeService.isDarkMode ? '🌙' : '☀️',
        style: const TextStyle(fontSize: 24),
      ),
      onPressed: () {
        themeService.toggleTheme();
      },
      tooltip: themeService.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
    );
  }
}

