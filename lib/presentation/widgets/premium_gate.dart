import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/billing/premium_controller.dart';
import '../screens/settings/subscription_screen.dart';

/// Wraps a feature that should only be usable on the premium tier. Shows
/// [child] only when the authoritative [PremiumController] says Premium
/// (server-verified); otherwise the locked state with a link to the real
/// Subscription screen — never fakes an unlocked feature.
class PremiumGate extends StatelessWidget {
  const PremiumGate({
    required this.featureName,
    required this.child,
    super.key,
  });

  final String featureName;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<PremiumController>();
    // Unlock only on the authoritative Premium state; until it is known show
    // nothing rather than flashing the locked upsell at a subscriber.
    if (!premium.entitlementLoaded) return const SizedBox.shrink();
    if (premium.isPremium) return child;
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock_outline, color: theme.colorScheme.tertiary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$featureName is part of HWC Premium',
                        key: const Key('premiumGateMessage'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('premiumGateLearnMoreButton'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionScreen(),
                    ),
                  ),
                  child: const Text('Learn more'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
