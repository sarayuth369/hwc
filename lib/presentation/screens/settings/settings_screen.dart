import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme_mode_controller.dart';
import '../../widgets/senior_mode_toggle.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<AppThemeModeController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionLabel('Appearance'),
          Card(
            child: RadioGroup<ThemeMode>(
              groupValue: themeController.themeMode,
              onChanged: (mode) => themeController.setThemeMode(mode!),
              child: const Column(
                children: [
                  RadioListTile<ThemeMode>(
                    key: Key('themeModeSystem'),
                    title: Text('System'),
                    value: ThemeMode.system,
                  ),
                  RadioListTile<ThemeMode>(
                    key: Key('themeModeLight'),
                    title: Text('Light'),
                    value: ThemeMode.light,
                  ),
                  RadioListTile<ThemeMode>(
                    key: Key('themeModeDark'),
                    title: Text('Dark'),
                    value: ThemeMode.dark,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Accessibility'),
          const Card(child: SeniorModeToggle()),
          const SizedBox(height: 16),
          const _SectionLabel('Notifications'),
          const Card(
            child: SwitchListTile(
              title: Text('Reminders'),
              subtitle: Text('Coming soon'),
              value: false,
              onChanged: null,
            ),
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Subscription'),
          const Card(
            child: ListTile(
              leading: Icon(Icons.workspace_premium_outlined),
              title: Text('HWC Premium'),
              subtitle: Text('Coming soon'),
              trailing: Icon(Icons.chevron_right),
              onTap: null,
            ),
          ),
          const SizedBox(height: 16),
          const _SectionLabel('About'),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.privacy_tip_outlined),
                  title: Text('Privacy'),
                  subtitle: Text(
                    'Your health data is protected by row-level security — '
                    'only you can read or write your own records.',
                  ),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('About HWC'),
                  subtitle: Text(
                    'AI Health & Wellness Companion — not a substitute for '
                    'professional medical advice, diagnosis, or treatment.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}
