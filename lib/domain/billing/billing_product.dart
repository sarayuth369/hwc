enum BillingPeriod { monthly, yearly }

class BillingProduct {
  const BillingProduct({
    required this.productId,
    required this.period,
    required this.formattedPrice,
  });

  final String productId;
  final BillingPeriod period;

  /// Store-formatted price (e.g. "$3.99"), read from the real Play Store
  /// product once one is configured there. Never a guessed/hardcoded
  /// currency string presented as if it came from the store.
  final String formattedPrice;
}
