import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Senior Mode token overrides (contract 4): larger type scale, higher
/// contrast, bigger touch targets, reduced motion, and a shallower nav
/// depth — layered onto the same [AppTheme] token tree every screen already
/// consumes, not a second design system.
class SeniorModeTheme extends AppTheme {
  const SeniorModeTheme();

  @override
  double get bodyFontSize => 22;

  @override
  double get titleFontSize => 30;

  @override
  double get headlineFontSize => 36;

  @override
  double get minTouchTarget => 64;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  int get maxNavDepth => 2;

  @override
  Color get primary => const Color(0xFF00408A);

  @override
  Color get background => Colors.white;

  @override
  Color get onBackground => Colors.black;

  @override
  double get iconSize => 32;

  @override
  double get spacingMd => 20;

  @override
  double get spacingLg => 28;
}
