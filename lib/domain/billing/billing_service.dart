import 'billing_product.dart';

/// The Google Play identifiers configured in Play Console. Must match
/// exactly -- do not invent alternates.
class HwcSubscription {
  const HwcSubscription._();

  /// Subscription product.
  static const productId = 'hwc_premium';

  /// Base plans of [productId].
  static const monthlyBasePlanId = 'monthly';
  static const yearlyBasePlanId = 'yearly';
}

/// Why the catalog is (not) populated -- lets the UI tell "Play Billing isn't
/// available on this device" apart from "plans aren't configured" apart from
/// a transient error, instead of showing one vague failure.
enum BillingCatalogStatus {
  loaded,
  billingUnavailable,
  productNotFound,
  error,
}

class BillingCatalog {
  const BillingCatalog({required this.status, this.products = const []});

  const BillingCatalog.unavailable(this.status) : products = const [];

  final BillingCatalogStatus status;
  final List<BillingProduct> products;

  BillingProduct? productFor(BillingPeriod period) {
    for (final p in products) {
      if (p.period == period) return p;
    }
    return null;
  }
}

enum BillingPurchaseStatus { purchased, restored, pending, canceled, error }

/// A purchase update from the store, decoupled from `in_app_purchase` types.
class BillingPurchase {
  const BillingPurchase({
    required this.productId,
    required this.status,
    this.purchaseToken,
    this.needsCompletion = false,
    this.alreadyOwned = false,
    this.platformHandle,
  });

  final String productId;
  final BillingPurchaseStatus status;

  /// Google Play purchase token -- sent to our backend for verification.
  final String? purchaseToken;

  /// True when the store still expects this purchase to be completed
  /// (acknowledged). Done ONLY after the backend verified it.
  final bool needsCompletion;

  /// The store reported the user already owns this subscription.
  final bool alreadyOwned;

  final Object? platformHandle;
}

/// What happened when starting a purchase flow. The actual result of the
/// purchase arrives asynchronously on [BillingService.purchases].
enum PurchaseStart { started, billingUnavailable, productUnavailable, error }

/// Billing-provider-agnostic seam so the Premium UI/logic never depends on
/// `in_app_purchase` directly. The only implementation is
/// `PlayBillingService` (real Google Play Billing).
abstract class BillingService {
  /// Every purchase update from the store, for the lifetime of the app
  /// (not just while a purchase screen is open): late `pending -> purchased`
  /// transitions, restores, and purchases made outside the app all arrive
  /// here. Single-subscription, buffering until listened to.
  Stream<BillingPurchase> get purchases;

  /// Queries the `hwc_premium` subscription and exposes its monthly/yearly
  /// base plans with the store's own localized prices. Never throws.
  Future<BillingCatalog> loadCatalog();

  /// Starts the purchase flow for [product], tagging the purchase with
  /// [accountId] (the Supabase user id) so the backend can bind it to the
  /// right account. Never throws.
  Future<PurchaseStart> purchase(BillingProduct product, {required String accountId});

  /// Re-queries the user's existing purchases; each one is re-emitted on
  /// [purchases]. Never throws.
  Future<void> restorePurchases();

  /// Acknowledges/completes [purchase] with the store. Call only once the
  /// backend has verified it. Never throws.
  Future<void> completePurchase(BillingPurchase purchase);
}
