import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/accessibility/accessibility_mode_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_mode_controller.dart';
import 'core/theme/senior_mode_theme.dart';
import 'domain/models/accessibility_mode.dart';
import 'presentation/screens/auth/auth_gate.dart';

class HealthApp extends StatelessWidget {
  const HealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<AccessibilityModeController>().mode;
    final themeMode = context.watch<AppThemeModeController>().themeMode;
    final AppTheme tokens = mode == AccessibilityMode.senior
        ? const SeniorModeTheme()
        : const AppTheme();

    return MaterialApp(
      title: 'AI Health Companion',
      debugShowCheckedModeBanner: false,
      theme: tokens.toThemeData(),
      darkTheme: tokens.toDarkThemeData(),
      themeMode: themeMode,
      home: const AuthGate(),
    );
  }
}
