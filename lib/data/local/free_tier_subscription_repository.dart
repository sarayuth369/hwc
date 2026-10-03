import '../../domain/repositories/subscription_repository.dart';

/// Always-free fallback for test harnesses and backend-less builds. It never
/// claims a purchase that didn't happen. The production app uses
/// `SupabaseSubscriptionRepository`.
class FreeTierSubscriptionRepository implements SubscriptionRepository {
  @override
  Future<SubscriptionTier> currentTier() async => SubscriptionTier.free;
}
