import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme_mode_controller.dart';
import '../../../data/local/notification_service.dart';
import '../../../domain/models/auth_failure.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../widgets/senior_mode_toggle.dart';
import '../family/family_mode_screen.dart';
import '../health_report/health_report_reader_screen.dart';
import 'subscription_screen.dart';

/// App version shown in About — kept as a plain constant rather than
/// pulling in `package_info_plus` for one string; update alongside
/// `pubspec.yaml`'s `version:` field.
const _appVersion = '0.1.0';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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

  Future<void> _toggleReminder(bool enabled) async {
    final notificationService = context.read<NotificationService>();
    await notificationService.setEnabled(enabled);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _pickReminderTime() async {
    final notificationService = context.read<NotificationService>();
    final picked = await showTimePicker(
      context: context,
      initialTime: notificationService.reminderTime,
    );
    if (picked == null) return;
    await notificationService.setEnabled(true, time: picked);
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<AppThemeModeController>();
    final notificationService = context.watch<NotificationService>();
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
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  key: const Key('waterReminderSwitch'),
                  title: const Text('Water reminder'),
                  subtitle: const Text('A daily nudge to stay hydrated'),
                  value: notificationService.isEnabled,
                  onChanged: _toggleReminder,
                ),
                if (notificationService.isEnabled)
                  ListTile(
                    key: const Key('waterReminderTimeTile'),
                    leading: const Icon(Icons.access_time),
                    title: const Text('Reminder time'),
                    trailing: Text(
                      notificationService.reminderTime.format(context),
                    ),
                    onTap: _pickReminderTime,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Features'),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const Key('healthReportReaderTile'),
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Health Report Reader'),
                  subtitle: const Text('AI-assisted rough read of a document photo'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const HealthReportReaderScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('familyModeTile'),
                  leading: const Icon(Icons.family_restroom_outlined),
                  title: const Text('Family Mode'),
                  subtitle: const Text("Keep an eye on a loved one's wellness"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FamilyModeScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Subscription'),
          Card(
            child: ListTile(
              key: const Key('subscriptionTile'),
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('HWC Premium'),
              subtitle: const Text('AI Coach · Advanced Insights · No ads'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Coming Soon'),
          const Card(
            child: ListTile(
              leading: Icon(Icons.watch_outlined),
              title: Text('Wearable Sync'),
              subtitle: Text('Apple Health / Google Fit integration'),
              enabled: false,
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
