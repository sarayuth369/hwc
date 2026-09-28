import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Base design tokens shared by every screen. Senior-friendly defaults are
/// baked in from day one (large type, high contrast, big touch targets) —
/// [SeniorModeTheme] scales these up further, it does not introduce a
/// parallel design language.
class AppTheme {
  const AppTheme();

  double get bodyFontSize => 16;
  double get titleFontSize => 22;
  double get headlineFontSize => 28;

  double get minTouchTarget => 48;

  Duration get transitionDuration => const Duration(milliseconds: 200);

  /// How many taps deep the primary nav allows.
  int get maxNavDepth => 3;

  Color get primary => const Color(0xFF0B5FFF);
  Color get onPrimary => Colors.white;
  Color get background => const Color(0xFFF7F9FC);
  Color get onBackground => const Color(0xFF131A2B);
  Color get surface => Colors.white;
  Color get error => const Color(0xFFB3261E);

  ThemeData toThemeData() {
    final colorScheme = ColorScheme.light(
      primary: primary,
      onPrimary: onPrimary,
      surface: surface,
      onSurface: onBackground,
      error: error,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: TextTheme(
        bodyLarge: TextStyle(fontSize: bodyFontSize, color: onBackground),
        bodyMedium: TextStyle(fontSize: bodyFontSize, color: onBackground),
        titleLarge: TextStyle(
          fontSize: titleFontSize,
          fontWeight: FontWeight.w600,
          color: onBackground,
        ),
        headlineMedium: TextStyle(
          fontSize: headlineFontSize,
          fontWeight: FontWeight.bold,
          color: onBackground,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: Size(minTouchTarget * 2, minTouchTarget),
          textStyle: TextStyle(fontSize: bodyFontSize),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}
