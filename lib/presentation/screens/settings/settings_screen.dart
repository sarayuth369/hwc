import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme_mode_controller.dart';
import '../../../domain/models/auth_failure.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../widgets/senior_mode_toggle.dart';

/// App version shown in About — kept as a plain constant rather than
/// pulling in `package_info_plus` for one string; update alongside
/// `pubspec.yaml`'s `version:` field.
const _appVersion = '0.1.0';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final controller = TextEditingController();
    final authRepository = context.read<AuthRepository>();
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Change password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('newPasswordField'),
                controller: controller,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password (min 6 characters)',
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error!,
                  key: const Key('changePasswordError'),
                  style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('savePasswordButton'),
              onPressed: () async {
                final newPassword = controller.text;
                if (newPassword.length < 6) {
                  setDialogState(
                    () => error = 'Password must be at least 6 characters.',
                  );
                  return;
                }
                try {
                  await authRepository.updatePassword(newPassword);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                } on AuthFailure catch (failure) {
                  setDialogState(() => error = failure.message);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

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
          const _SectionLabel('Account'),
          Card(
            child: ListTile(
              key: const Key('changePasswordTile'),
              leading: const Icon(Icons.password_outlined),
              title: const Text('Change password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showChangePasswordDialog(context),
            ),
          ),
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
              subtitle: Text(
                'AI Health Coach · Food Scan AI · Advanced Insights · '
                'Family Mode — Coming soon',
              ),
              trailing: Icon(Icons.chevron_right),
              onTap: null,
            ),
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Coming Soon'),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.description_outlined),
                  title: Text('Health Report Reader'),
                  subtitle: Text('Upload and summarize lab reports'),
                  enabled: false,
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.family_restroom_outlined),
                  title: Text('Family Mode'),
                  subtitle: Text("Keep an eye on a loved one's wellness"),
                  enabled: false,
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.watch_outlined),
                  title: Text('Wearable Sync'),
                  subtitle: Text('Apple Health / Google Fit integration'),
                  enabled: false,
                ),
              ],
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
                  leading: Icon(Icons.description_outlined),
                  title: Text('Terms of Service'),
                  subtitle: Text(
                    'HWC is a wellness companion, not a medical device. It '
                    'does not diagnose, prescribe, or change medications.',
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
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.numbers_outlined),
                  title: Text('App version'),
                  subtitle: Text(_appVersion),
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
