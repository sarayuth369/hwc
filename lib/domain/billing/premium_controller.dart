import 'dart:async';

import 'package:flutter/foundation.dart';

import '../repositories/current_user_service.dart';
import '../repositories/subscription_repository.dart';
import 'billing_product.dart';
import 'billing_service.dart';
import 'entitlement_verifier.dart';

/// Where an in-flight purchase currently is. Anything other than [idle]
/// disables the purchase buttons, which is what prevents duplicate
/// submissions.
enum PurchasePhase { idle, purchasing, pending, verifying }

/// One user-facing outcome message to show on the Premium screen.
enum PremiumNotice {
  none,
  success,
  cancelled,
  pending,
  billingUnavailable,
  productUnavailable,
  signInRequired,
  error,

  /// Google Play confirmed the purchase but our server could not verify it
  /// yet. The user is NOT granted Premium until it is verified; the
  /// purchase is left un-acknowledged and re-verified on the next restore.
  verificationUnavailable,
  verificationRejected,
  restoreNothingFound,
}

/// The ONE authoritative Premium state used by the whole UI (ads, gates,
/// promo cards, the subscription screen).
///
/// Premium is never set from a button click or a client-side "purchase
/// succeeded" signal. The only ways [isPremium] becomes true are:
///   1. the backend verified a Google Play purchase with Google and answered
///      `entitled` (Worker -> Play Developer API -> Supabase `subscriptions`),
///   2. the signed-in user's own server-written `subscriptions` row says so
///      ([SubscriptionRepository]).
class PremiumController extends ChangeNotifier {
  PremiumController({
    required BillingService billing,
    required SubscriptionRepository subscriptions,
    required EntitlementVerifier verifier,
    required CurrentUserService currentUser,
  })  : _billing = billing,
        _subscriptions = subscriptions,
        _verifier = verifier,
        _currentUser = currentUser;

  final BillingService _billing;
  final SubscriptionRepository _subscriptions;
  final EntitlementVerifier _verifier;
  final CurrentUserService _currentUser;

  SubscriptionTier _tier = SubscriptionTier.free;
  bool _loaded = false;
  Completer<void> _ready = Completer<void>();

  BillingCatalog? _catalog;
  bool _catalogLoading = false;

  PurchasePhase _phase = PurchasePhase.idle;
  PremiumNotice _notice = PremiumNotice.none;
  bool _restoring = false;

  StreamSubscription<BillingPurchase>? _sub;
  Future<void> _queue = Future<void>.value();
  bool _started = false;
  bool _disposed = false;
  int _generation = 0;

  /// True while the user explicitly asked to restore (so outcomes are shown
  /// instead of being silent like the automatic startup restore).
  bool _userRestore = false;
  int _restoreEvents = 0;

  SubscriptionTier get tier => _tier;
  bool get isPremium => _tier == SubscriptionTier.premium;

  /// False until the first entitlement read finished. UI that would show an
  /// ad or an upsell must wait for this, so a Premium user never briefly
  /// sees either at startup.
  bool get entitlementLoaded => _loaded;

  /// Completes when the first entitlement read finished (whatever it found).
  Future<void> get ready => _ready.future;

  BillingCatalog? get catalog => _catalog;
  bool get catalogLoading => _catalogLoading;
  PurchasePhase get phase => _phase;
  PremiumNotice get notice => _notice;
  bool get restoring => _restoring;
  bool get busy => _phase != PurchasePhase.idle || _restoring;

  /// Begin listening to purchase updates and load the entitlement. Call once
  /// the user is signed in. Idempotent.
  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    final generation = ++_generation;
    _sub = _billing.purchases.listen((purchase) {
      _queue = _queue.then((_) => _handle(purchase, generation));
    });
    await refreshEntitlement();
    // Re-query existing purchases at startup so a renewal / reinstall /
    // purchase made elsewhere is re-verified. Silent: no UI noise.
    unawaited(_silently(_billing.restorePurchases));
  }

  /// Stop listening and forget the signed-in user's state (sign-out / shell
  /// teardown), so the next user never inherits Premium.
  void stop() {
    _sub?.cancel();
    _sub = null;
    _started = false;
    _generation++;
    _tier = SubscriptionTier.free;
    _loaded = false;
    if (_ready.isCompleted) _ready = Completer<void>();
    _phase = PurchasePhase.idle;
    _notice = PremiumNotice.none;
    _restoring = false;
    _userRestore = false;
    if (!_disposed) notifyListeners();
  }

  /// Re-reads the server-backed entitlement. On a read failure the last known
  /// value is kept (the repository itself falls back to its own cache).
  Future<void> refreshEntitlement() async {
    final generation = _generation;
    var tier = _tier;
    try {
      tier = await _subscriptions.currentTier();
    } catch (_) {
      // keep the last known value
    }
    if (_disposed || generation != _generation) return;
    _tier = tier;
    _loaded = true;
    if (!_ready.isCompleted) _ready.complete();
    notifyListeners();
  }

  Future<void> loadCatalog() async {
    if (_catalogLoading) return;
    _catalogLoading = true;
    notifyListeners();
    BillingCatalog catalog;
    try {
      catalog = await _billing.loadCatalog();
    } catch (_) {
      catalog = const BillingCatalog.unavailable(BillingCatalogStatus.error);
    }
    if (_disposed) return;
    _catalog = catalog;
    _catalogLoading = false;
    notifyListeners();
  }

  /// Called each time the Premium screen opens: re-query products, the
  /// server entitlement and existing purchases.
  Future<void> onPremiumScreenOpened() async {
    if (_phase == PurchasePhase.purchasing) _phase = PurchasePhase.idle;
    _notice = PremiumNotice.none;
    notifyListeners();
    await Future.wait([
      refreshEntitlement(),
      loadCatalog(),
      _silently(_billing.restorePurchases),
    ]);
  }

  void clearNotice() {
    if (_notice == PremiumNotice.none) return;
    _notice = PremiumNotice.none;
    notifyListeners();
  }

  /// Starts the Play purchase flow for [period]. The result arrives on the
  /// billing stream. Ignored while another purchase/restore is in flight.
  Future<void> purchase(BillingPeriod period) async {
    if (busy || isPremium) return;
    final catalog = _catalog;
    final product = catalog?.productFor(period);
    if (product == null) {
      _notice = catalog?.status == BillingCatalogStatus.billingUnavailable
          ? PremiumNotice.billingUnavailable
          : PremiumNotice.productUnavailable;
      notifyListeners();
      return;
    }
    final accountId = _currentUser.currentUserId;
    if (accountId == null) {
      _notice = PremiumNotice.signInRequired;
      notifyListeners();
      return;
    }

    // Set before the first await: a second tap in the same frame is ignored.
    _phase = PurchasePhase.purchasing;
    _notice = PremiumNotice.none;
    notifyListeners();

    PurchaseStart start;
    try {
      start = await _billing.purchase(product, accountId: accountId);
    } catch (_) {
      start = PurchaseStart.error;
    }
    if (_disposed) return;
    if (start != PurchaseStart.started) {
      _phase = PurchasePhase.idle;
      _notice = switch (start) {
        PurchaseStart.billingUnavailable => PremiumNotice.billingUnavailable,
        PurchaseStart.productUnavailable => PremiumNotice.productUnavailable,
        _ => PremiumNotice.error,
      };
      notifyListeners();
    }
  }

  /// User-initiated "Restore purchases".
  Future<void> restore() async {
    if (_restoring || _phase == PurchasePhase.purchasing) return;
    _restoring = true;
    _userRestore = true;
    _restoreEvents = 0;
    _notice = PremiumNotice.none;
    notifyListeners();

    await _silently(_billing.restorePurchases);
    // Let any purchase events the restore just emitted reach the handler,
    // then wait for their verification to finish.
    await Future<void>.delayed(Duration.zero);
    await _queue;
    await refreshEntitlement();

    if (_disposed) return;
    if (!isPremium && _restoreEvents == 0 && _notice == PremiumNotice.none) {
      _notice = PremiumNotice.restoreNothingFound;
    }
    _restoring = false;
    _userRestore = false;
    notifyListeners();
  }

  Future<void> _handle(BillingPurchase purchase, int generation) async {
    if (_disposed || generation != _generation) return;
    if (purchase.productId != HwcSubscription.productId) return;
    try {
      switch (purchase.status) {
        case BillingPurchaseStatus.pending:
          _phase = PurchasePhase.pending;
          _notice = PremiumNotice.pending;
          notifyListeners();
        case BillingPurchaseStatus.canceled:
          _phase = PurchasePhase.idle;
          _notice = PremiumNotice.cancelled;
          notifyListeners();
        case BillingPurchaseStatus.error:
          if (purchase.alreadyOwned) {
            // The Play account already has it: re-emit it as a restore so it
            // gets verified instead of showing a confusing error.
            _phase = PurchasePhase.idle;
            notifyListeners();
            await _silently(_billing.restorePurchases);
          } else {
            _phase = PurchasePhase.idle;
            _notice = PremiumNotice.error;
            notifyListeners();
          }
        case BillingPurchaseStatus.purchased:
        case BillingPurchaseStatus.restored:
          await _verify(purchase, generation);
      }
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _phase = PurchasePhase.idle;
      _notice = PremiumNotice.error;
      notifyListeners();
    }
  }

  Future<void> _verify(BillingPurchase purchase, int generation) async {
    _restoreEvents++;
    final token = purchase.purchaseToken;
    final userVisible = purchase.status == BillingPurchaseStatus.purchased || _userRestore;
    if (token == null || token.isEmpty) {
      _phase = PurchasePhase.idle;
      if (userVisible) _notice = PremiumNotice.error;
      notifyListeners();
      return;
    }

    _phase = PurchasePhase.verifying;
    notifyListeners();

    final outcome = await _verifier.verify(
      purchaseToken: token,
      productId: purchase.productId,
    );
    if (_disposed || generation != _generation) return;

    switch (outcome) {
      case VerificationOutcome.entitled:
        // Acknowledge with Google only now that the server verified it.
        if (purchase.needsCompletion) await _billing.completePurchase(purchase);
        _phase = PurchasePhase.idle;
        _notice = userVisible ? PremiumNotice.success : PremiumNotice.none;
        await refreshEntitlement();
      case VerificationOutcome.pending:
        _phase = PurchasePhase.pending;
        _notice = PremiumNotice.pending;
      case VerificationOutcome.notEntitled:
        _phase = PurchasePhase.idle;
        if (_userRestore) {
          _notice = PremiumNotice.restoreNothingFound;
        } else if (purchase.status == BillingPurchaseStatus.purchased) {
          _notice = PremiumNotice.error;
        }
      case VerificationOutcome.rejected:
        _phase = PurchasePhase.idle;
        _notice = PremiumNotice.verificationRejected;
      case VerificationOutcome.notConfigured:
      case VerificationOutcome.unavailable:
      case VerificationOutcome.unauthenticated:
        _phase = PurchasePhase.idle;
        if (userVisible) _notice = PremiumNotice.verificationUnavailable;
    }
    notifyListeners();
  }

  Future<void> _silently(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
