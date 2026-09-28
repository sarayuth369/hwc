import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/repositories/family_repository.dart';

/// Explains Family/Caregiver mode and shows the real (currently always
/// empty) connection list via `FamilyRepository`. Never fabricates a
/// connection or exposes health data without real authorization — that
/// needs new Supabase RLS policies that don't exist yet.
class FamilyModeScreen extends StatelessWidget {
  const FamilyModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Family Mode')),
      body: FutureBuilder<List<Object>>(
        future: context.read<FamilyRepository>().connections(),
        builder: (context, snapshot) {
          final connections = snapshot.data ?? const [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Icon(
                Icons.family_restroom_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text('Keep an eye on a loved one', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text(
                'Family Mode will let a trusted caregiver see a summary of '
                'a loved one\'s wellness — with their explicit permission. '
                'This needs new privacy controls we haven\'t built yet, so '
                'it isn\'t available in this build.',
              ),
              const SizedBox(height: 24),
              if (connections.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No connections yet.',
                      key: Key('familyModeEmptyState'),
                    ),
                  ),
                )
              else
                for (final connection in connections) Text('$connection'),
            ],
          );
        },
      ),
    );
  }
}
