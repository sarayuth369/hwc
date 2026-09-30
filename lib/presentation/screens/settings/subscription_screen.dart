import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/billing/billing_product.dart';
import '../../../domain/billing/billing_service.dart';
import '../../../domain/repositories/subscription_repository.dart';

const _premiumFeatures = [
  (Icons.psychology_outlined, 'AI Health Coach', 'Deeper, personalized guidance'),
  (Icons.camera_alt_outlined, 'Food Scan AI', 'Unlimited photo-based nutrition estimates'),
  (Icons.insights_outlined, 'Advanced Insights', 'Weekly trend analysis'),
  (Icons.family_restroom_outlined, 'Family Mode', "Keep an eye on a loved one's wellness"),
  (Icons.description_outlined, 'Health Report Reader', 'Unlimited document reads'),
  (Icons.block_flipped, 'No ads', 'A clean, uninterrupted experience'),
];

/// Real paywall UI wired to the real `BillingService` (Google Play
/// Billing). No product is configured in Play Console yet, so purchasing
/// honestly reports that instead of faking a successful charge — see
/// `PlayBillingService`'s own doc comment for exactly what's real vs.
/// pending on M's side.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  BillingPeriod _selected = BillingPeriod.yearly;
  List<BillingProduct> _products = [];
  bool _loadingProducts = true;
  bool _purchasing = false;
  bool _restoring = false;
  String? _message;
  SubscriptionTier _tier = SubscriptionTier.free;

  @override
  void initState() {
    super.initState();
    _loadEntitlement();
    _loadProducts();
  }

  Future<void> _loadEntitlement() async {
    final tier = await context.read<SubscriptionRepository>().currentTier();
    if (mounted) setState(() => _tier = tier);
  }

  Future<void> _loadProducts() async {
    final products = await context.read<BillingService>().queryProducts();
    if (mounted) {
      setState(() {
        _products = products;
        _loadingProducts = false;
      });
    }
  }

  BillingProduct? _productFor(BillingPeriod period) =>
      _products.where((p) => p.period == period).firstOrNull;

  Future<void> _purchase() async {
    final product = _productFor(_selected);
    if (product == null) return;
    setState(() {
      _purchasing = true;
      _message = null;
    });
    final outcome = await context.read<BillingService>().purchase(product);
    if (!mounted) return;
    setState(() {
      _purchasing = false;
      _message = switch (outcome) {
        PurchaseOutcome.success => 'Thank you! Premium is now active.',
        PurchaseOutcome.cancelled => 'Purchase cancelled.',
        PurchaseOutcome.pending => 'Purchase pending — this can take a moment.',
        PurchaseOutcome.notConfigured =>
          'This plan isn\'t available for purchase yet.',
        PurchaseOutcome.error => 'Something went wrong. Please try again.',
      };
    });
    if (outcome == PurchaseOutcome.success) _loadEntitlement();
  }

  Future<void> _restore() async {
    setState(() => _restoring = true);
    await context.read<BillingService>().restorePurchases();
    await _loadEntitlement();
    if (mounted) {
      setState(() {
        _restoring = false;
        _message = 'Restore requested — any active purchase will reappear shortly.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPremium = _tier == SubscriptionTier.premium;
    final monthly = _productFor(BillingPeriod.monthly);
    final yearly = _productFor(BillingPeriod.yearly);
    final hasRealProducts = _products.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('HWC Premium')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _HeroHeader(isPremium: isPremium, theme: theme),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final (icon, title, subtitle) in _premiumFeatures)
                        _BenefitRow(icon: icon, title: title, subtitle: subtitle, theme: theme),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (!isPremium) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _PlanCard(
                          key: const Key('planMonthly'),
                          label: 'Monthly',
                          price: monthly?.formattedPrice ?? r'$3.99/mo',
                          selected: _selected == BillingPeriod.monthly,
                          onTap: () => setState(() => _selected = BillingPeriod.monthly),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PlanCard(
                          key: const Key('planYearly'),
                          label: 'Yearly',
                          price: yearly?.formattedPrice ?? r'$44.99/yr',
                          badge: 'Best value',
                          selected: _selected == BillingPeriod.yearly,
                          onTap: () => setState(() => _selected = BillingPeriod.yearly),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_loadingProducts)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x59FFC107),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: FilledButton(
                        key: const Key('subscribeButton'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC107),
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onPressed: _purchasing ? null : _purchase,
                        child: Text(_purchasing
                            ? 'Please wait...'
                            : 'Subscribe — ${_selected == BillingPeriod.monthly ? monthly?.formattedPrice ?? r'$3.99/mo' : yearly?.formattedPrice ?? r'$44.99/yr'}'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        key: const Key('restorePurchasesButton'),
                        onPressed: _restoring ? null : _restore,
                        child: Text(_restoring ? 'Restoring...' : 'Restore purchases'),
                      ),
                    ),
                    if (!hasRealProducts) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, size: 20, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'These plans aren\'t set up for purchase in Google Play '
                                'yet — prices above are illustrative until M configures '
                                'hwc_premium_monthly / hwc_premium_yearly in Play '
                                'Console. Tapping Subscribe won\'t charge anyone before then.',
                                key: const Key('subscriptionNotConfiguredMessage'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _message!,
                      key: const Key('subscriptionMessage'),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The paywall's hero banner — a tasteful brand-blue gradient surface
/// (rather than a plain icon on the scaffold background) so the screen
/// reads as a deliberate premium upsell, not a settings sub-page.
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.isPremium, required this.theme});

  final bool isPremium;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      decoration: const BoxDecoration(
        // Same purple/blue + gold direction as `PremiumPromoCard` (Home/
        // Profile) so Premium reads as one consistent brand moment
        // wherever the user meets it, not a different look per screen.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6A11CB), Color(0xFF2447E0)],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFFFFC107),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium, size: 40, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          Text(
            'Get more from HWC',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Unlock deeper AI guidance and a calmer, ad-free experience.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
          if (isPremium) ...[
            const SizedBox(height: 16),
            Container(
              key: const Key('premiumActiveBadge'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 18, color: Color(0xFF6A11CB)),
                  SizedBox(width: 6),
                  Text(
                    'Premium active',
                    style: TextStyle(
                      color: Color(0xFF6A11CB),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.theme,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: theme.colorScheme.primary, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    super.key,
    required this.label,
    required this.price,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final String price;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              // Leaves room on the right for the selection-state icon
              // stacked on top, rather than fighting it for space in a Row
              // (this exact card was already overflow-fixed once before at
              // this ~137px width -- keep new elements out of that Row).
              padding: const EdgeInsets.fromLTRB(16, 16, 28, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badge!,
                            style: TextStyle(fontSize: 10, color: theme.colorScheme.secondary),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    price,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
                color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
