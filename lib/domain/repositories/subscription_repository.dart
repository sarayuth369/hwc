enum SubscriptionTier { free, premium }

/// The user's server-backed entitlement. The production implementation
/// (`SupabaseSubscriptionRepository`) reads the `subscriptions` row that only
/// the Worker can write, after it verified a Google Play purchase with
/// Google. UI should not call this directly: it observes `PremiumController`,
/// the single authoritative Premium state built on top of it.
/// `FreeTierSubscriptionRepository` (always free) is only the default for
/// builds/tests with no backend.
abstract class SubscriptionRepository {
  Future<SubscriptionTier> currentTier();
}
