enum BillingPeriod { monthly, yearly }

/// One purchasable HWC Premium offer, read from the real Google Play
/// `hwc_premium` subscription (never hard-coded).
class BillingProduct {
  const BillingProduct({
    required this.productId,
    required this.period,
    required this.basePlanId,
    required this.formattedPrice,
    this.platformHandle,
  });

  /// Play subscription product id (`hwc_premium`).
  final String productId;
  final BillingPeriod period;

  /// Play base plan id (`monthly` / `yearly`).
  final String basePlanId;

  /// Store-formatted, localized price exactly as Google Play returned it
  /// (e.g. "$3.99"). Never a guessed/hardcoded currency string.
  final String formattedPrice;

  /// Opaque, provider-specific object the billing implementation needs to
  /// start this purchase (for Google Play: the `ProductDetails` of this exact
  /// base plan, which carries its offer token). The UI never reads it.
  final Object? platformHandle;
}
