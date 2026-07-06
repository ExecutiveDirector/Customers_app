import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { system, light, dark }

class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'app_theme_mode';
  static const _dynamicKey = 'use_dynamic_color';

  AppThemeMode _mode = AppThemeMode.system;
  bool _useDynamicColor = false;

  AppThemeMode get mode => _mode;
  bool get useDynamicColor => _useDynamicColor;

  ThemeMode get themeMode {
    switch (_mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
      default:
        return ThemeMode.system;
    }
  }

  ThemeProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_prefKey) ?? 'system';
    _mode = AppThemeMode.values.firstWhere(
      (e) => e.toString().split('.').last == str,
      orElse: () => AppThemeMode.system,
    );
    _useDynamicColor = prefs.getBool(_dynamicKey) ?? false;
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, mode.toString().split('.').last);
  }

  Future<void> setUseDynamicColor(bool v) async {
    _useDynamicColor = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dynamicKey, v);
  }
}