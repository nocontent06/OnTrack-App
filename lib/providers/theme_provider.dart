import 'package:flutter/material.dart';

enum AppThemeMode { system, light, dark, oledDark }

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _mode = AppThemeMode.system;

  AppThemeMode get mode => _mode;

  void setMode(AppThemeMode mode) {
    _mode = mode;
    notifyListeners();
  }

  ThemeMode get themeMode {
    switch (_mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.oledDark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  ThemeData get darkTheme {
    if (_mode == AppThemeMode.oledDark) {
      return ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        canvasColor: Colors.black,
        cardColor: Colors.black,
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.black,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
          surface: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.black,
          indicatorColor: Colors.teal.shade700,
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else {
      return ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
      );
    }
  }
}