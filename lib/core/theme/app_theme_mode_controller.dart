import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single source of truth for the System/Light/Dark preference — same
/// persistence pattern as `AccessibilityModeController`.
class AppThemeModeController extends ChangeNotifier {
  AppThemeModeController(this._prefs)
      : _themeMode = ThemeMode.values.byName(
          _prefs.getString(_storageKey) ?? ThemeMode.system.name,
        );

  static const _storageKey = 'app_theme_mode_v1';
  final SharedPreferences _prefs;
  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    await _prefs.setString(_storageKey, mode.name);
    notifyListeners();
  }
}
