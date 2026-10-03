import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../../domain/billing/billing_product.dart';
import '../../domain/billing/billing_service.dart';

/// Real Google Play Billing integration (`in_app_purchase` +
/// `in_app_purchase_android`) for the `hwc_premium` subscription and its
/// `monthly` / `yearly` base plans.
///
/// - Prices are always the store's own localized strings.
/// - The purchase stream is subscribed to at construction (the plugin's
///   stream is a non-buffering broadcast one), so no update is ever missed,
///   including late `pending -> purchased` transitions and restores.
/// - Purchases are acknowledged only via [completePurchase], which the
///   controller calls after the backend verified them.
class PlayBillingService implements BillingService {
  /// Never throws: this is created at app launch (so no purchase update is
  /// missed), and a device without a working Play Billing plugin/Play Store
  /// must simply report "billing unavailable", never crash startup.
  PlayBillingService({InAppPurchase? iap}) {
    try {
      final store = iap ?? InAppPurchase.instance;
      _iap = store;
      _storeSubscription = store.purchaseStream.listen(
        _onStoreUpdate,
        onError: (_) {
          // A stream error must never crash the app; the controller's
          // restore re-surfaces any real purchase.
        },
      );
    } catch (_) {
      _iap = null;
    }
  }

  InAppPurchase? _iap;
  StreamSubscription<List<PurchaseDetails>>? _storeSubscription;

  // Single-subscription: buffers until the PremiumController starts
  // listening, so an update that arrives during app start isn't dropped.
  final _purchases = StreamController<BillingPurchase>();

  @override
  Stream<BillingPurchase> get purchases => _purchases.stream;

  void _onStoreUpdate(List<PurchaseDetails> updates) {
    for (final details in updates) {
      final mapped = mapPurchase(details);
      if (mapped != null) _purchases.add(mapped);
    }
  }

  /// Maps a plugin purchase to ours. Returns null for the plugin's phantom
  /// "purchased" entry (empty product id and token) that it emits when a
  /// query succeeds but the user owns nothing.
  static BillingPurchase? mapPurchase(PurchaseDetails details) {
    final token = details.verificationData.serverVerificationData;
    final noProduct = details.productID.isEmpty;

    if (noProduct &&
        (details.status == PurchaseStatus.purchased ||
            details.status == PurchaseStatus.restored)) {
      return null;
    }

    final status = switch (details.status) {
      PurchaseStatus.purchased => BillingPurchaseStatus.purchased,
      PurchaseStatus.restored => BillingPurchaseStatus.restored,
      PurchaseStatus.pending => BillingPurchaseStatus.pending,
      PurchaseStatus.canceled => BillingPurchaseStatus.canceled,
      PurchaseStatus.error => BillingPurchaseStatus.error,
    };

    final alreadyOwned = (details.error?.message ?? '').contains('itemAlreadyOwned');

    return BillingPurchase(
      // Cancel/error updates for a failed flow carry no product id; we only
      // sell one product, so attribute them to it.
      productId: noProduct ? HwcSubscription.productId : details.productID,
      status: status,
      purchaseToken: token.isEmpty ? null : token,
      needsCompletion: details.pendingCompletePurchase,
      alreadyOwned: alreadyOwned,
      platformHandle: details,
    );
  }

  @override
  Future<BillingCatalog> loadCatalog() async {
    final iap = _iap;
    if (iap == null) {
      return const BillingCatalog.unavailable(BillingCatalogStatus.billingUnavailable);
    }
    try {
      if (!await iap.isAvailable()) {
        return const BillingCatalog.unavailable(BillingCatalogStatus.billingUnavailable);
      }
      final response = await iap.queryProductDetails({HwcSubscription.productId});
      if (response.error != null) {
        return const BillingCatalog.unavailable(BillingCatalogStatus.error);
      }
      return selectBasePlans(response.productDetails);
    } catch (_) {
      return const BillingCatalog.unavailable(BillingCatalogStatus.error);
    }
  }

  /// For subscriptions the plugin returns one entry per base plan/offer of
  /// `hwc_premium`. Pick the plain base-plan offer (no promotional offer id)
  /// of `monthly` and `yearly` by base plan id.
  static BillingCatalog selectBasePlans(List<ProductDetails> details) {
    final products = <BillingProduct>[];
    for (final (basePlanId, period) in const [
      (HwcSubscription.monthlyBasePlanId, BillingPeriod.monthly),
      (HwcSubscription.yearlyBasePlanId, BillingPeriod.yearly),
    ]) {
      for (final d in details) {
        if (d is! GooglePlayProductDetails || d.id != HwcSubscription.productId) continue;
        final index = d.subscriptionIndex;
        final offers = d.productDetails.subscriptionOfferDetails;
        if (index == null || offers == null || index >= offers.length) continue;
        final offer = offers[index];
        if (offer.basePlanId != basePlanId || offer.offerId != null) continue;
        products.add(BillingProduct(
          productId: d.id,
          period: period,
          basePlanId: basePlanId,
          formattedPrice: d.price,
          platformHandle: d,
        ));
        break;
      }
    }
    if (products.isEmpty) {
      return const BillingCatalog.unavailable(BillingCatalogStatus.productNotFound);
    }
    return BillingCatalog(status: BillingCatalogStatus.loaded, products: products);
  }

  @override
  Future<PurchaseStart> purchase(BillingProduct product, {required String accountId}) async {
    final handle = product.platformHandle;
    if (handle is! GooglePlayProductDetails) return PurchaseStart.productUnavailable;
    final iap = _iap;
    if (iap == null) return PurchaseStart.billingUnavailable;
    try {
      if (!await iap.isAvailable()) return PurchaseStart.billingUnavailable;
      final started = await iap.buyNonConsumable(
        purchaseParam: GooglePlayPurchaseParam(
          productDetails: handle,
          offerToken: handle.offerToken,
          // Maps to Google's obfuscatedAccountId: the backend only credits a
          // purchase to the account it is tagged with.
          applicationUserName: accountId,
        ),
      );
      return started ? PurchaseStart.started : PurchaseStart.error;
    } catch (_) {
      return PurchaseStart.error;
    }
  }

  @override
  Future<void> restorePurchases() async {
    final iap = _iap;
    if (iap == null) return;
    try {
      if (!await iap.isAvailable()) return;
      await iap.restorePurchases();
    } catch (_) {}
  }

  @override
  Future<void> completePurchase(BillingPurchase purchase) async {
    final handle = purchase.platformHandle;
    final iap = _iap;
    if (handle is! PurchaseDetails || iap == null) return;
    try {
      await iap.completePurchase(handle);
    } catch (_) {}
  }

  void dispose() {
    _storeSubscription?.cancel();
    _purchases.close();
  }
}
