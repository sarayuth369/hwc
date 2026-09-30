import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/user_profile.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/profile_repository.dart';
import '../../widgets/premium_promo_card.dart';
import '../settings/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<UserProfile?> _profileFuture;
  String? _displayNameOverride;

  @override
  void initState() {
    super.initState();
    _profileFuture = context.read<ProfileRepository>().fetchProfile();
  }

  Future<void> _signOut() async {
    await context.read<AuthRepository>().signOut();
    // AuthGate is listening to authStateChanges and will swap the whole
    // tree back to SignInScreen automatically — nothing to navigate here.
  }

  Future<void> _editDisplayName(String current) async {
    final controller = TextEditingController(text: current);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit name'),
        content: TextField(
          key: const Key('editDisplayNameField'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Display name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('saveDisplayNameButton'),
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || !mounted) return;
    await context.read<ProfileRepository>().updateDisplayName(newName);
    if (!mounted) return;
    setState(() => _displayNameOverride = newName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<UserProfile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        final displayName = _displayNameOverride ?? snapshot.data?.displayName;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                    child: Icon(Icons.person, size: 40, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (displayName == null || displayName.isEmpty)
                            ? 'Your Profile'
                            : displayName,
                        key: const Key('profileDisplayName'),
                        style: theme.textTheme.titleLarge,
                      ),
                      IconButton(
                        key: const Key('editDisplayNameButton'),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _editDisplayName(displayName ?? ''),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const PremiumPromoCard(),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('signOutButton'),
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }
}
