import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/repositories/subscription_repository.dart';
import '../screens/settings/subscription_screen.dart';

/// Compact HWC Premium upsell — reused wherever it's called from (Home,
/// Profile) so the same purple/blue-gradient + gold-CTA visual language
/// shows consistently across the app, not just on the full Settings ->
/// Premium screen. Renders nothing once the user is actually premium (no
/// point upselling someone who already has it), and the whole card is one
/// tap target straight into [SubscriptionScreen] -- never a fake purchase
/// shortcut of its own.
class PremiumPromoCard extends StatefulWidget {
  const PremiumPromoCard({super.key});

  @override
  State<PremiumPromoCard> createState() => _PremiumPromoCardState();
}

class _PremiumPromoCardState extends State<PremiumPromoCard> {
  late final Future<SubscriptionTier> _tierFuture =
      context.read<SubscriptionRepository>().currentTier();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SubscriptionTier>(
      future: _tierFuture,
      builder: (context, snapshot) {
        if (snapshot.data == SubscriptionTier.premium) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Material(
          key: const Key('premiumPromoCard'),
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6A11CB), Color(0xFF2447E0)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6A11CB).withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFC107),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.workspace_premium, color: Colors.black87, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Go Premium',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Deeper AI coaching, unlimited food scans, no ads.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC107),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'UPGRADE NOW',
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
