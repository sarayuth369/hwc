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

  // Spacing scale — every screen should build layout from these instead of
  // ad-hoc pixel values, so Senior Mode's looser rhythm stays consistent.
  double get spacingXs => 4;
  double get spacingSm => 8;
  double get spacingMd => 16;
  double get spacingLg => 24;
  double get spacingXl => 32;

  // Shape tokens.
  double get radiusSm => 8;
  double get radiusMd => 16;
  double get radiusLg => 24;

  // Elevation tokens (kept low/flat for a calm, non-fussy look).
  double get elevationLow => 0;
  double get elevationMed => 1;

  double get iconSize => 24;

  // "Healthy" palette (replaces the earlier plain blue light theme) —
  // designed from the evidence cited in HWC_DECISIONS.md: healthcare-
  // interface research favoring calm color + minimal layout, EHR studies
  // suggesting blue/green for normal states, and caregiver-interface
  // research favoring green/purple, balanced against WCAG 2.2's 4.5:1 text
  // contrast / 3:1 UI-graphic contrast minimums and its "never color
  // alone" guidance (every semantic color pairs with a text label or icon
  // elsewhere in the UI, never color as the sole signal). A calm teal
  // reads as "health/growth" without the saturated, clinical green this
  // explicitly avoids; every color below was verified against its actual
  // background at implementation time (see HWC_DECISIONS.md for the
  // computed ratios), not chosen by eye.
  Color get primary => const Color(0xFF0B7A69);
  Color get onPrimary => Colors.white;
  Color get background => const Color(0xFFFAF8F3);
  Color get onBackground => const Color(0xFF1F2A24);
  Color get surface => Colors.white;
  Color get onSurface => onBackground;
  Color get error => const Color(0xFFB3261E);
  Color get onError => Colors.white;

  // Semantic colors: wellness-score bands and status rows read off these,
  // not raw hex values scattered across screens. Deliberately a different
  // hue from `primary` (true green vs. primary's blue-green teal) so a
  // success/good state never reads as "just the brand color."
  Color get success => const Color(0xFF2E7D32);
  Color get onSuccess => Colors.white;
  Color get warning => const Color(0xFF9C6B0A);
  Color get onWarning => Colors.white;

  Color get outline => onBackground.withValues(alpha: 0.15);

  ThemeData toThemeData() => _buildThemeData(brightness: Brightness.light);

  /// Real dark variant — not a placeholder. Settings' System/Light/Dark
  /// selector uses this directly.
  ThemeData toDarkThemeData() => _buildThemeData(brightness: Brightness.dark);

  ThemeData _buildThemeData({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1420) : background;
    final onBg = isDark ? const Color(0xFFE7EBF3) : onBackground;
    final surfaceColor = isDark ? const Color(0xFF171E2C) : surface;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      secondary: success,
      onSecondary: onSuccess,
      tertiary: warning,
      onTertiary: onWarning,
      surface: surfaceColor,
      onSurface: onBg,
      error: error,
      onError: onError,
    );

    final baseTextTheme = TextTheme(
      bodyLarge: TextStyle(fontSize: bodyFontSize, color: onBg),
      bodyMedium: TextStyle(fontSize: bodyFontSize, color: onBg),
      labelLarge: TextStyle(
        fontSize: bodyFontSize * 0.875,
        fontWeight: FontWeight.w600,
        color: onBg,
      ),
      titleLarge: TextStyle(
        fontSize: titleFontSize,
        fontWeight: FontWeight.w600,
        color: onBg,
      ),
      headlineMedium: TextStyle(
        fontSize: headlineFontSize,
        fontWeight: FontWeight.bold,
        color: onBg,
      ),
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMd),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      textTheme: baseTextTheme,
      iconTheme: IconThemeData(color: onBg, size: iconSize),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: onBg,
        elevation: elevationLow,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: titleFontSize,
          fontWeight: FontWeight.w600,
          color: onBg,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: elevationMed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: EdgeInsets.symmetric(
          horizontal: spacingMd,
          vertical: spacingMd,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(minTouchTarget * 2, minTouchTarget),
          textStyle: TextStyle(fontSize: bodyFontSize, fontWeight: FontWeight.w600),
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(minTouchTarget * 2, minTouchTarget),
          textStyle: TextStyle(fontSize: bodyFontSize, fontWeight: FontWeight.w600),
          shape: buttonShape,
          side: BorderSide(color: outline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: Size(minTouchTarget * 2, minTouchTarget),
          textStyle: TextStyle(fontSize: bodyFontSize),
          shape: buttonShape,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        indicatorColor: primary.withValues(alpha: 0.15),
        elevation: elevationMed,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: bodyFontSize * 0.75,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.normal,
            color: states.contains(WidgetState.selected) ? primary : onBg,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? primary : onBg,
            size: iconSize,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceColor,
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        labelStyle: TextStyle(fontSize: bodyFontSize * 0.875, color: onBg),
      ),
      pageTransitionsTheme: PageTransitionsTheme(builders: {
        TargetPlatform.android: transitionDuration == Duration.zero
            ? const NoTransitionsBuilder()
            : const ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}

/// Instant page changes for Senior Mode (`transitionDuration == Duration.zero`)
/// — avoids motion that's disorienting at a larger type scale.
class NoTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}
