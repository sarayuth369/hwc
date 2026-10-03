import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/legal_links.dart';
import '../../../domain/billing/billing_product.dart';
import '../../../domain/billing/billing_service.dart';
import '../../../domain/billing/premium_controller.dart';

/// Opens Google Play's subscription management page for HWC Premium.
const _manageSubscriptionUrl =
    'https://play.google.com/store/account/subscriptions'
    '?sku=${HwcSubscription.productId}&package=com.bkknex.bkknex_health_app';

const _premiumFeatures = [
  (Icons.psychology_outlined, 'AI Health Coach', 'Deeper, personalized guidance'),
  (Icons.camera_alt_outlined, 'Food Scan AI', 'Unlimited photo-based nutrition estimates'),
  (Icons.insights_outlined, 'Advanced Insights', 'Weekly trend analysis'),
  (Icons.family_restroom_outlined, 'Family Mode', "Keep an eye on a loved one's wellness"),
  (Icons.description_outlined, 'Health Report Reader', 'Unlimited document reads'),
  (Icons.block_flipped, 'No ads', 'A clean, uninterrupted experience'),
];

/// Paywall wired to the real Google Play subscription (`hwc_premium`:
/// `monthly` / `yearly` base plans) through [PremiumController]. Prices come
/// from Google Play, the active state comes from the server-verified
/// entitlement, and nothing here ever marks a user Premium by itself.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  BillingPeriod _selected = BillingPeriod.yearly;
  late final PremiumController _premium;

  @override
  void initState() {
    super.initState();
    _premium = context.read<PremiumController>();
    // Re-query products, the server entitlement and existing purchases every
    // time the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _premium.onPremiumScreenOpened();
    });
  }

  @override
  void dispose() {
    // Don't carry a stale message into the next visit.
    final premium = _premium;
    Future.microtask(premium.clearNotice);
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  static String? _noticeText(PremiumNotice notice) => switch (notice) {
        PremiumNotice.none => null,
        PremiumNotice.success => 'Thank you! HWC Premium is now active.',
        PremiumNotice.cancelled => 'Purchase cancelled. You have not been charged.',
        PremiumNotice.pending =>
          'Your payment is pending. Premium turns on automatically once Google Play confirms it.',
        PremiumNotice.billingUnavailable =>
          "Google Play Billing isn't available on this device right now.",
        PremiumNotice.productUnavailable =>
          "This plan can't be loaded from Google Play right now. Please try again in a moment.",
        PremiumNotice.signInRequired => 'Please sign in to subscribe.',
        PremiumNotice.error => 'Something went wrong with the purchase. Please try again.',
        PremiumNotice.verificationUnavailable =>
          "Google Play received your purchase, but we couldn't confirm it with our server yet. "
              'Premium turns on automatically once we can — you can also tap Restore purchases.',
        PremiumNotice.verificationRejected =>
          "We couldn't verify this purchase for your account. If you were charged, please contact support.",
        PremiumNotice.restoreNothingFound =>
          'No active HWC Premium subscription was found for this Google account.',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final premium = context.watch<PremiumController>();
    final isPremium = premium.isPremium;
    final catalog = premium.catalog;
    final monthly = catalog?.productFor(BillingPeriod.monthly);
    final yearly = catalog?.productFor(BillingPeriod.yearly);
    final selectedProduct = _selected == BillingPeriod.monthly ? monthly : yearly;
    final notice = _noticeText(premium.notice);

    final buttonLabel = switch (premium.phase) {
      PurchasePhase.purchasing => 'Waiting for Google Play...',
      PurchasePhase.verifying => 'Confirming your purchase...',
      PurchasePhase.pending => 'Payment pending',
      PurchasePhase.idle => selectedProduct == null
          ? 'Subscribe'
          : 'Subscribe — ${selectedProduct.formattedPrice} / ${_selected == BillingPeriod.monthly ? 'month' : 'year'}',
    };
    final canSubscribe = !premium.busy && selectedProduct != null;

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
                if (isPremium)
                  _ActiveSubscriptionCard(
                    theme: theme,
                    onManage: () => _openUrl(_manageSubscriptionUrl),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _PlanCard(
                          key: const Key('planMonthly'),
                          label: 'Monthly',
                          price: monthly?.formattedPrice ?? '—',
                          unit: 'per month',
                          selected: _selected == BillingPeriod.monthly,
                          onTap: () => setState(() => _selected = BillingPeriod.monthly),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PlanCard(
                          key: const Key('planYearly'),
                          label: 'Yearly',
                          price: yearly?.formattedPrice ?? '—',
                          unit: 'per year',
                          badge: 'Best value',
                          selected: _selected == BillingPeriod.yearly,
                          onTap: () => setState(() => _selected = BillingPeriod.yearly),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (premium.catalogLoading && catalog == null)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    if (catalog != null && catalog.status != BillingCatalogStatus.loaded) ...[
                      _CatalogProblem(
                        status: catalog.status,
                        theme: theme,
                        onRetry: premium.catalogLoading ? null : premium.loadCatalog,
                      ),
                      const SizedBox(height: 16),
                    ],
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
                        onPressed: canSubscribe ? () => premium.purchase(_selected) : null,
                        child: Text(buttonLabel, textAlign: TextAlign.center),
                      ),
                    ),
                  ],
                ],
                if (notice != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    notice,
                    key: const Key('subscriptionMessage'),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    key: const Key('restorePurchasesButton'),
                    onPressed: premium.busy ? null : premium.restore,
                    child: Text(premium.restoring ? 'Restoring...' : 'Restore purchases'),
                  ),
                ),
                const SizedBox(height: 8),
                _Disclosure(theme: theme, onOpen: _openUrl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Plain, factual subscription terms (Google Play subscription policy).
class _Disclosure extends StatelessWidget {
  const _Disclosure({required this.theme, required this.onOpen});

  final ThemeData theme;
  final Future<void> Function(String url) onOpen;

  @override
  Widget build(BuildContext context) {
    final small = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Payment is charged to your Google Play account. The subscription renews '
          'automatically each month or year at the price shown by Google Play, unless '
          'you cancel it in Google Play before the renewal date. You can manage or '
          'cancel any time in Google Play → Subscriptions. Tap Restore purchases to '
          're-check a subscription on this Google account.',
          key: const Key('subscriptionDisclosure'),
          style: small,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            TextButton(
              key: const Key('subscriptionTermsLink'),
              onPressed: () => onOpen(LegalLinks.terms),
              child: const Text('Terms of Service'),
            ),
            TextButton(
              key: const Key('subscriptionPrivacyLink'),
              onPressed: () => onOpen(LegalLinks.privacy),
              child: const Text('Privacy Policy'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActiveSubscriptionCard extends StatelessWidget {
  const _ActiveSubscriptionCard({required this.theme, required this.onManage});

  final ThemeData theme;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('activeSubscriptionCard'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your HWC Premium subscription is active',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Billed through Google Play. You can change or cancel it any time there.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('manageSubscriptionButton'),
              onPressed: onManage,
              child: const Text('Manage subscription in Google Play'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Explains why no plans are shown instead of a vague failure.
class _CatalogProblem extends StatelessWidget {
  const _CatalogProblem({required this.status, required this.theme, required this.onRetry});

  final BillingCatalogStatus status;
  final ThemeData theme;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      BillingCatalogStatus.billingUnavailable =>
        "Google Play Billing isn't available on this device, so plans can't be shown right now.",
      BillingCatalogStatus.productNotFound =>
        "HWC Premium plans aren't available from Google Play for this account yet.",
      _ => "We couldn't load the plans from Google Play. Please check your connection and try again.",
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 20, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  key: const Key('subscriptionCatalogMessage'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (status != BillingCatalogStatus.billingUnavailable)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('retryCatalogButton'),
                onPressed: onRetry,
                child: const Text('Try again'),
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
    required this.unit,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final String price;
  final String unit;
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
                  Text(
                    unit,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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
