import 'package:flutter/material.dart';

const _premiumFeatures = [
  'AI Health Coach — deeper, personalized guidance',
  'Food Scan AI — unlimited photo-based nutrition estimates',
  'Advanced Insights — weekly trend analysis',
  'Family Mode — keep an eye on a loved one\'s wellness',
  'Health Report Reader — unlimited document reads',
  'No ads',
];

/// A real screen (not a stub row) with an honest state: no payment
/// provider is configured, so there is nothing to purchase yet. Never
/// shows a working "Subscribe" button that doesn't actually charge anyone.
class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('HWC Premium')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Icon(
            Icons.workspace_premium_outlined,
            size: 48,
            color: theme.colorScheme.tertiary,
          ),
          const SizedBox(height: 12),
          Text('Get more from HWC', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                for (final feature in _premiumFeatures)
                  ListTile(
                    leading: Icon(Icons.check, color: theme.colorScheme.secondary),
                    title: Text(feature),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: theme.colorScheme.tertiary.withValues(alpha: 0.12),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Payment is not yet configured for this build — there is '
                'nothing to purchase right now. Everything above stays free '
                'until a payment provider is set up.',
                key: Key('subscriptionNotConfiguredMessage'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
