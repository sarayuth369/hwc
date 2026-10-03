/// Result of asking the backend to verify a Google Play purchase.
enum VerificationOutcome {
  /// The backend verified the purchase with Google and recorded Premium.
  entitled,

  /// Verified, but it does not currently grant Premium (expired, on hold...).
  notEntitled,

  /// Verified as still pending payment -- no access yet.
  pending,

  /// The backend refused it (not valid, or belongs to another account).
  rejected,

  /// The backend cannot verify purchases yet (Play credential not set up).
  notConfigured,

  /// Network/backend/Google problem -- retry later; says nothing about
  /// whether the user is entitled.
  unavailable,

  /// No signed-in session.
  unauthenticated,
}

/// Asks the backend (Worker -> Google Play Developer API -> Supabase) whether
/// a purchase token is a real, active HWC Premium subscription for the
/// signed-in user. The client NEVER decides Premium by itself.
abstract class EntitlementVerifier {
  /// Never throws.
  Future<VerificationOutcome> verify({
    required String purchaseToken,
    required String productId,
  });
}
