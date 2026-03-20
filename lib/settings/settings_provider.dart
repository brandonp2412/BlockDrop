import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { system, light, dark, black }

enum AppStyle { classic, modern, bubbles }

class SettingsProvider extends ChangeNotifier {
  static const _themeKey = 'theme_mode';
  static const _styleKey = 'app_style';

  AppThemeMode _themeMode = AppThemeMode.system;
  AppStyle _style = AppStyle.classic;

  AppThemeMode get themeMode => _themeMode;
  AppStyle get style => _style;

  ThemeMode get flutterThemeMode {
    switch (_themeMode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
      case AppThemeMode.black:
        return ThemeMode.dark;
    }
  }

  bool get isBlackMode => _themeMode == AppThemeMode.black;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? 0;
    final styleIndex = prefs.getInt(_styleKey) ?? 0;
    _themeMode = AppThemeMode.values[themeIndex.clamp(
      0,
      AppThemeMode.values.length - 1,
    )];
    _style = AppStyle.values[styleIndex.clamp(0, AppStyle.values.length - 1)];
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }

  Future<void> setStyle(AppStyle newStyle) async {
    _style = newStyle;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_styleKey, newStyle.index);
  }
}
