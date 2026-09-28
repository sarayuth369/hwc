enum SubscriptionTier { free, premium }

/// Real feature-gating architecture, not a placeholder — any screen can
/// depend on this today and gate a feature behind `tier == premium`. No
/// payment provider is configured yet, so every implementation currently
/// available returns `free` — see `FreeTierSubscriptionRepository`. Wiring
/// a real provider (RevenueCat, Stripe, platform billing, etc.) later only
/// means adding a new implementation of this interface, not touching every
/// call site that checks it.
abstract class SubscriptionRepository {
  Future<SubscriptionTier> currentTier();
}
