import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/accessibility_mode.dart';

/// Single source of truth for Senior Mode (contract 4). There is exactly one
/// [AccessibilityMode] driving the shared theme token tree — no parallel
/// "senior screens" or duplicated routes exist anywhere in this app.
class AccessibilityModeController extends ChangeNotifier {
  AccessibilityModeController(this._prefs)
      : _mode = AccessibilityMode.values.byName(
          _prefs.getString(_storageKey) ?? AccessibilityMode.normal.name,
        );

  static const _storageKey = 'accessibility_mode_v1';
  final SharedPreferences _prefs;
  AccessibilityMode _mode;

  AccessibilityMode get mode => _mode;
  bool get isSenior => _mode == AccessibilityMode.senior;

  Future<void> setMode(AccessibilityMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    await _prefs.setString(_storageKey, mode.name);
    notifyListeners();
  }

  Future<void> toggle() =>
      setMode(isSenior ? AccessibilityMode.normal : AccessibilityMode.senior);
}
