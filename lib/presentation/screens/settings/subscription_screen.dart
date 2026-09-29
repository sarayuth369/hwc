import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/billing/billing_product.dart';
import '../../../domain/billing/billing_service.dart';
import '../../../domain/repositories/subscription_repository.dart';

const _premiumFeatures = [
  'AI Health Coach — deeper, personalized guidance',
  'Food Scan AI — unlimited photo-based nutrition estimates',
  'Advanced Insights — weekly trend analysis',
  'Family Mode — keep an eye on a loved one\'s wellness',
  'Health Report Reader — unlimited document reads',
  'No ads',
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
        padding: const EdgeInsets.all(16),
        children: [
          Icon(
            Icons.workspace_premium_outlined,
            size: 48,
            color: theme.colorScheme.tertiary,
          ),
          const SizedBox(height: 12),
          Text('Get more from HWC', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          if (isPremium)
            Container(
              key: const Key('premiumActiveBadge'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 18, color: theme.colorScheme.tertiary),
                  const SizedBox(width: 6),
                  Text('Premium active', style: TextStyle(color: theme.colorScheme.tertiary)),
                ],
              ),
            ),
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
            const SizedBox(height: 16),
            if (_loadingProducts)
              const Center(child: CircularProgressIndicator())
            else ...[
              FilledButton(
                key: const Key('subscribeButton'),
                onPressed: _purchasing ? null : _purchase,
                child: Text(_purchasing ? 'Please wait...' : 'Subscribe'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('restorePurchasesButton'),
                onPressed: _restoring ? null : _restore,
                child: Text(_restoring ? 'Restoring...' : 'Restore purchases'),
              ),
              if (!hasRealProducts) ...[
                const SizedBox(height: 16),
                Card(
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.12),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'These plans aren\'t set up for purchase in Google Play '
                      'yet — prices above are illustrative until M configures '
                      'hwc_premium_monthly / hwc_premium_yearly in Play '
                      'Console. Tapping Subscribe won\'t charge anyone before then.',
                      key: Key('subscriptionNotConfiguredMessage'),
                    ),
                  ),
                ),
              ],
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!, key: const Key('subscriptionMessage')),
            ],
          ],
        ],
      ),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: theme.textTheme.titleMedium,
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
            const SizedBox(height: 4),
            Text(
              price,
              style: theme.textTheme.headlineSmall,
              overflow: TextOverflow.ellipsis,
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
