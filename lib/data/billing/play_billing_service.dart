import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../../domain/billing/billing_product.dart';
import '../../domain/billing/billing_service.dart';

/// Real `in_app_purchase` (Google Play Billing) integration. No product is
/// configured in Play Console yet, so `queryProducts()` correctly returns
/// an empty list right now via `notFoundIDs` -- that is genuinely what the
/// store reports for these product IDs today, never a hardcoded fallback
/// price pretending to be real. Once M creates
/// `hwc_premium_monthly`/`hwc_premium_yearly` in Play Console, this starts
/// returning real products and real prices with no code change needed.
class PlayBillingService implements BillingService {
  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<List<BillingProduct>> queryProducts() async {
    if (!await isAvailable()) return [];
    final response = await _iap.queryProductDetails(HwcProductIds.all.toSet());
    return response.productDetails.map((details) {
      final period = details.id == HwcProductIds.yearly
          ? BillingPeriod.yearly
          : BillingPeriod.monthly;
      return BillingProduct(
        productId: details.id,
        period: period,
        formattedPrice: details.price,
      );
    }).toList();
  }

  @override
  Future<PurchaseOutcome> purchase(BillingProduct product) async {
    if (!await isAvailable()) return PurchaseOutcome.notConfigured;
    final response = await _iap.queryProductDetails({product.productId});
    if (response.productDetails.isEmpty) return PurchaseOutcome.notConfigured;

    final completer = Completer<PurchaseOutcome>();
    _subscription?.cancel();
    _subscription = _iap.purchaseStream.listen((purchases) {
      for (final purchase in purchases) {
        if (purchase.productID != product.productId) continue;
        switch (purchase.status) {
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            if (purchase.pendingCompletePurchase) {
              _iap.completePurchase(purchase);
            }
            if (!completer.isCompleted) completer.complete(PurchaseOutcome.success);
          case PurchaseStatus.canceled:
            if (!completer.isCompleted) completer.complete(PurchaseOutcome.cancelled);
          case PurchaseStatus.error:
            if (!completer.isCompleted) completer.complete(PurchaseOutcome.error);
          case PurchaseStatus.pending:
            break;
        }
      }
    });

    final purchaseParam = PurchaseParam(productDetails: response.productDetails.first);
    final started = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    if (!started && !completer.isCompleted) {
      completer.complete(PurchaseOutcome.error);
    }
    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () => PurchaseOutcome.pending,
    );
  }

  @override
  Future<void> restorePurchases() => _iap.restorePurchases();
}
