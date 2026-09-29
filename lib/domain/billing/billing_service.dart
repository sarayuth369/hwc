import 'billing_product.dart';

enum PurchaseOutcome { success, cancelled, pending, error, notConfigured }

/// Real Google Play Billing seam. Product IDs are fixed here so the UI,
/// this interface, and whatever gets configured in Play Console all agree
/// on the same strings — verify these against Play Console before
/// creating the products there.
class HwcProductIds {
  const HwcProductIds._();
  static const monthly = 'hwc_premium_monthly';
  static const yearly = 'hwc_premium_yearly';
  static const all = [monthly, yearly];
}

/// Billing-provider-agnostic interface so the paywall UI never depends on
/// `in_app_purchase` (or any future provider) directly. The only
/// implementation today is `PlayBillingService` — real Google Play Billing
/// calls, not a simulation. Because no product is configured in Play
/// Console yet, `queryProducts()` correctly returns an empty list right
/// now; that is the honest current state, not a bug to work around with a
/// fake fallback price.
abstract class BillingService {
  Future<bool> isAvailable();
  Future<List<BillingProduct>> queryProducts();
  Future<PurchaseOutcome> purchase(BillingProduct product);
  Future<void> restorePurchases();
}
