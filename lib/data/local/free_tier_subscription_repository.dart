import '../../domain/repositories/subscription_repository.dart';

/// The only implementation available today — no payment provider (IAP,
/// Stripe, RevenueCat, etc.) is configured, so every user is genuinely on
/// the free tier. Never claims a purchase that didn't happen.
class FreeTierSubscriptionRepository implements SubscriptionRepository {
  @override
  Future<SubscriptionTier> currentTier() async => SubscriptionTier.free;
}
