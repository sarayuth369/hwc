import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:bkknex_health_app/domain/billing/billing_product.dart';
import 'package:bkknex_health_app/domain/billing/billing_service.dart';
import 'package:bkknex_health_app/domain/billing/entitlement_verifier.dart';
import 'package:bkknex_health_app/domain/billing/premium_controller.dart';
import 'package:bkknex_health_app/domain/repositories/subscription_repository.dart';

import 'support/fake_repositories.dart';

/// Lets queued stream events + async verification settle.
Future<void> settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Rig {
  _Rig({
    SubscriptionTier initial = SubscriptionTier.free,
    BillingCatalog? catalog,
    FakeCurrentUserService? user,
  })  : repo = FakeSubscriptionRepository(initial),
        billing = FakeBillingService(catalog: catalog ?? fakePlayCatalog()) {
    verifier = FakeEntitlementVerifier(repository: repo);
    controller = buildPremiumController(
      billing: billing,
      subscriptions: repo,
      verifier: verifier,
      currentUser: user ?? FakeCurrentUserService(),
    );
  }

  final FakeSubscriptionRepository repo;
  final FakeBillingService billing;
  late final FakeEntitlementVerifier verifier;
  late final PremiumController controller;

  Future<void> started() async {
    await controller.start();
    await controller.loadCatalog();
    await settle();
  }
}

void main() {
  group('entitlement state', () {
    test('is not loaded until the first read, then reflects the server tier (free)', () async {
      final rig = _Rig();
      expect(rig.controller.entitlementLoaded, isFalse);
      expect(rig.controller.isPremium, isFalse);

      await rig.controller.start();
      expect(rig.controller.entitlementLoaded, isTrue);
      expect(rig.controller.isPremium, isFalse);
      await rig.controller.ready; // completes
    });

    test('reflects a server-side premium row', () async {
      final rig = _Rig(initial: SubscriptionTier.premium);
      await rig.controller.start();
      expect(rig.controller.isPremium, isTrue);
    });

    test('a failed read still finishes loading (as free) instead of hanging the UI', () async {
      final rig = _Rig();
      rig.repo.throwOnRead = true;
      await rig.controller.start();
      expect(rig.controller.entitlementLoaded, isTrue);
      expect(rig.controller.isPremium, isFalse);
    });

    test('a failed re-read keeps the last known tier', () async {
      final rig = _Rig(initial: SubscriptionTier.premium);
      await rig.controller.start();
      rig.repo.throwOnRead = true;
      await rig.controller.refreshEntitlement();
      expect(rig.controller.isPremium, isTrue);
    });

    test('stop() forgets the user so the next account never inherits Premium', () async {
      final rig = _Rig(initial: SubscriptionTier.premium);
      await rig.controller.start();
      rig.controller.stop();
      expect(rig.controller.isPremium, isFalse);
      expect(rig.controller.entitlementLoaded, isFalse);
    });
  });

  group('product discovery', () {
    test('exposes the monthly and yearly offers with Play-provided prices', () async {
      final rig = _Rig();
      await rig.started();
      final catalog = rig.controller.catalog!;
      expect(catalog.status, BillingCatalogStatus.loaded);
      expect(catalog.productFor(BillingPeriod.monthly)!.formattedPrice, r'$3.99');
      expect(catalog.productFor(BillingPeriod.monthly)!.basePlanId, 'monthly');
      expect(catalog.productFor(BillingPeriod.yearly)!.formattedPrice, r'$44.99');
      expect(catalog.productFor(BillingPeriod.yearly)!.basePlanId, 'yearly');
      expect(catalog.productFor(BillingPeriod.monthly)!.productId, 'hwc_premium');
    });

    test('passes through "Play Billing unavailable" without crashing', () async {
      final rig = _Rig(
        catalog: const BillingCatalog.unavailable(BillingCatalogStatus.billingUnavailable),
      );
      await rig.started();
      expect(rig.controller.catalog!.status, BillingCatalogStatus.billingUnavailable);
      expect(rig.controller.catalog!.products, isEmpty);
    });
  });

  group('purchase flow', () {
    test('monthly purchase starts the monthly offer, tagged with the signed-in user id', () async {
      final rig = _Rig();
      await rig.started();
      await rig.controller.purchase(BillingPeriod.monthly);

      expect(rig.billing.purchaseRequests.single.basePlanId, 'monthly');
      expect(rig.billing.purchaseAccountIds.single, 'test-user');
      expect(rig.controller.phase, PurchasePhase.purchasing);
      expect(rig.controller.isPremium, isFalse, reason: 'starting a purchase never grants Premium');
    });

    test('yearly purchase starts the yearly offer', () async {
      final rig = _Rig();
      await rig.started();
      await rig.controller.purchase(BillingPeriod.yearly);
      expect(rig.billing.purchaseRequests.single.basePlanId, 'yearly');
    });

    test('a second tap while a purchase is in flight is ignored (no duplicate submission)',
        () async {
      final rig = _Rig();
      await rig.started();
      rig.billing.purchaseGate = Completer<void>();

      final first = rig.controller.purchase(BillingPeriod.yearly);
      final second = rig.controller.purchase(BillingPeriod.yearly);
      rig.billing.purchaseGate!.complete();
      await Future.wait([first, second]);

      expect(rig.billing.purchaseRequests, hasLength(1));
    });

    test('a verified purchase grants Premium and is acknowledged only after verification', () async {
      final rig = _Rig();
      await rig.started();
      await rig.controller.purchase(BillingPeriod.monthly);

      final purchase = fakePurchase(token: 'tok-A');
      rig.billing.emit(purchase);
      await settle();

      expect(rig.verifier.verifiedTokens, ['tok-A']);
      expect(rig.billing.completed, [purchase]);
      expect(rig.controller.isPremium, isTrue);
      expect(rig.controller.phase, PurchasePhase.idle);
      expect(rig.controller.notice, PremiumNotice.success);
    });

    test('the purchase is NOT acknowledged while verification is still running', () async {
      final rig = _Rig();
      await rig.started();
      rig.verifier.gate = Completer<void>();
      await rig.controller.purchase(BillingPeriod.monthly);

      rig.billing.emit(fakePurchase());
      await settle();
      expect(rig.controller.phase, PurchasePhase.verifying);
      expect(rig.billing.completed, isEmpty);
      expect(rig.controller.isPremium, isFalse);

      rig.verifier.gate!.complete();
      await settle();
      expect(rig.billing.completed, hasLength(1));
      expect(rig.controller.isPremium, isTrue);
    });

    test('a purchase the server cannot verify yet never grants Premium and is not acknowledged',
        () async {
      for (final outcome in [
        VerificationOutcome.notConfigured,
        VerificationOutcome.unavailable,
        VerificationOutcome.unauthenticated,
      ]) {
        final rig = _Rig();
        await rig.started();
        rig.verifier.outcome = outcome;
        await rig.controller.purchase(BillingPeriod.monthly);
        rig.billing.emit(fakePurchase());
        await settle();

        expect(rig.controller.isPremium, isFalse, reason: '$outcome');
        expect(rig.billing.completed, isEmpty, reason: '$outcome');
        expect(rig.controller.notice, PremiumNotice.verificationUnavailable, reason: '$outcome');
        expect(rig.controller.phase, PurchasePhase.idle, reason: '$outcome');
      }
    });

    test('a purchase the server rejects (another account / invalid) never grants Premium',
        () async {
      final rig = _Rig();
      await rig.started();
      rig.verifier.outcome = VerificationOutcome.rejected;
      await rig.controller.purchase(BillingPeriod.monthly);
      rig.billing.emit(fakePurchase());
      await settle();

      expect(rig.controller.isPremium, isFalse);
      expect(rig.billing.completed, isEmpty);
      expect(rig.controller.notice, PremiumNotice.verificationRejected);
    });

    test('a client-side "purchased" event with no token is never trusted', () async {
      final rig = _Rig();
      await rig.started();
      await rig.controller.purchase(BillingPeriod.monthly);
      rig.billing.emit(fakePurchase(token: null));
      await settle();

      expect(rig.verifier.verifiedTokens, isEmpty);
      expect(rig.controller.isPremium, isFalse);
      expect(rig.controller.notice, PremiumNotice.error);
    });

    test('pending: shows pending, grants nothing, then completes when it becomes purchased',
        () async {
      final rig = _Rig();
      await rig.started();
      await rig.controller.purchase(BillingPeriod.yearly);

      rig.billing.emit(fakePurchase(status: BillingPurchaseStatus.pending, token: null));
      await settle();
      expect(rig.controller.phase, PurchasePhase.pending);
      expect(rig.controller.notice, PremiumNotice.pending);
      expect(rig.controller.isPremium, isFalse);
      expect(rig.controller.busy, isTrue);

      // Later, with no purchase screen open, Google reports it as purchased.
      rig.billing.emit(fakePurchase(token: 'tok-late'));
      await settle();
      expect(rig.controller.isPremium, isTrue);
      expect(rig.controller.phase, PurchasePhase.idle);
    });

    test('server says still pending: stays pending and grants nothing', () async {
      final rig = _Rig();
      await rig.started();
      rig.verifier.outcome = VerificationOutcome.pending;
      await rig.controller.purchase(BillingPeriod.yearly);
      rig.billing.emit(fakePurchase());
      await settle();

      expect(rig.controller.phase, PurchasePhase.pending);
      expect(rig.controller.isPremium, isFalse);
      expect(rig.billing.completed, isEmpty);
    });

    test('canceled: back to idle with a "not charged" notice', () async {
      final rig = _Rig();
      await rig.started();
      await rig.controller.purchase(BillingPeriod.monthly);
      rig.billing.emit(fakePurchase(status: BillingPurchaseStatus.canceled, token: null));
      await settle();

      expect(rig.controller.phase, PurchasePhase.idle);
      expect(rig.controller.notice, PremiumNotice.cancelled);
      expect(rig.controller.isPremium, isFalse);
      // and the user can try again
      await rig.controller.purchase(BillingPeriod.monthly);
      expect(rig.billing.purchaseRequests, hasLength(2));
    });

    test('store error: back to idle with an error notice', () async {
      final rig = _Rig();
      await rig.started();
      await rig.controller.purchase(BillingPeriod.monthly);
      rig.billing.emit(fakePurchase(status: BillingPurchaseStatus.error, token: null));
      await settle();

      expect(rig.controller.phase, PurchasePhase.idle);
      expect(rig.controller.notice, PremiumNotice.error);
    });

    test('"already owned" triggers a restore instead of an error', () async {
      final rig = _Rig();
      await rig.started();
      rig.billing.restoreEmits = [
        fakePurchase(status: BillingPurchaseStatus.restored, token: 'tok-owned'),
      ];
      await rig.controller.purchase(BillingPeriod.monthly);
      rig.billing.emit(
        fakePurchase(status: BillingPurchaseStatus.error, token: null, alreadyOwned: true),
      );
      await settle();

      expect(rig.billing.restoreCalls, greaterThanOrEqualTo(1));
      expect(rig.verifier.verifiedTokens, contains('tok-owned'));
      expect(rig.controller.isPremium, isTrue);
      expect(rig.controller.notice, isNot(PremiumNotice.error));
    });

    test('events for other products are ignored', () async {
      final rig = _Rig();
      await rig.started();
      rig.billing.emit(fakePurchase(productId: 'something_else'));
      await settle();
      expect(rig.verifier.verifiedTokens, isEmpty);
      expect(rig.controller.isPremium, isFalse);
    });
  });

  group('guards and degradation', () {
    test('Play Billing unavailable: purchase explains it and never calls the store', () async {
      final rig = _Rig(
        catalog: const BillingCatalog.unavailable(BillingCatalogStatus.billingUnavailable),
      );
      await rig.started();
      await rig.controller.purchase(BillingPeriod.monthly);
      expect(rig.controller.notice, PremiumNotice.billingUnavailable);
      expect(rig.billing.purchaseRequests, isEmpty);
      expect(rig.controller.phase, PurchasePhase.idle);
    });

    test('plans not found: purchase explains it', () async {
      final rig = _Rig(
        catalog: const BillingCatalog.unavailable(BillingCatalogStatus.productNotFound),
      );
      await rig.started();
      await rig.controller.purchase(BillingPeriod.yearly);
      expect(rig.controller.notice, PremiumNotice.productUnavailable);
    });

    test('the store refusing to start the flow resets the state', () async {
      final rig = _Rig();
      await rig.started();
      rig.billing.startResult = PurchaseStart.billingUnavailable;
      await rig.controller.purchase(BillingPeriod.monthly);
      expect(rig.controller.phase, PurchasePhase.idle);
      expect(rig.controller.notice, PremiumNotice.billingUnavailable);
    });

    test('purchase requires a signed-in user', () async {
      final user = FakeCurrentUserService()..currentUserId = null;
      final rig = _Rig(user: user);
      await rig.started();
      await rig.controller.purchase(BillingPeriod.monthly);
      expect(rig.controller.notice, PremiumNotice.signInRequired);
      expect(rig.billing.purchaseRequests, isEmpty);
    });

    test('an existing subscriber cannot start a second purchase', () async {
      final rig = _Rig(initial: SubscriptionTier.premium);
      await rig.started();
      await rig.controller.purchase(BillingPeriod.yearly);
      expect(rig.billing.purchaseRequests, isEmpty);
    });
  });

  group('restore', () {
    test('startup re-queries purchases and silently verifies an owned subscription', () async {
      final rig = _Rig();
      rig.billing.restoreEmits = [
        fakePurchase(status: BillingPurchaseStatus.restored, token: 'tok-owned'),
      ];
      await rig.controller.start();
      await settle();

      expect(rig.billing.restoreCalls, 1);
      expect(rig.verifier.verifiedTokens, ['tok-owned']);
      expect(rig.controller.isPremium, isTrue);
      expect(rig.controller.notice, PremiumNotice.none, reason: 'startup restore is silent');
    });

    test('opening the Premium screen re-queries products, entitlement and purchases', () async {
      final rig = _Rig();
      await rig.controller.start();
      final reads = rig.repo.reads;
      final restores = rig.billing.restoreCalls;
      await rig.controller.onPremiumScreenOpened();

      expect(rig.billing.loadCatalogCalls, 1);
      expect(rig.repo.reads, greaterThan(reads));
      expect(rig.billing.restoreCalls, greaterThan(restores));
    });

    test('user restore with an active subscription grants Premium and says so', () async {
      final rig = _Rig();
      await rig.started();
      rig.billing.restoreEmits = [
        fakePurchase(status: BillingPurchaseStatus.restored, token: 'tok-owned'),
      ];
      await rig.controller.restore();

      expect(rig.controller.isPremium, isTrue);
      expect(rig.controller.notice, PremiumNotice.success);
      expect(rig.controller.restoring, isFalse);
    });

    test('user restore with nothing owned says nothing was found', () async {
      final rig = _Rig();
      await rig.started();
      await rig.controller.restore();

      expect(rig.controller.isPremium, isFalse);
      expect(rig.controller.notice, PremiumNotice.restoreNothingFound);
      expect(rig.controller.restoring, isFalse);
    });

    test('user restore of an expired subscription does not grant Premium', () async {
      final rig = _Rig();
      await rig.started();
      rig.verifier.outcome = VerificationOutcome.notEntitled;
      rig.billing.restoreEmits = [
        fakePurchase(status: BillingPurchaseStatus.restored, token: 'tok-old'),
      ];
      await rig.controller.restore();

      expect(rig.controller.isPremium, isFalse);
      expect(rig.controller.notice, PremiumNotice.restoreNothingFound);
      expect(rig.billing.completed, isEmpty);
    });

    test('restore while Play/server is unreachable explains it instead of "nothing found"',
        () async {
      final rig = _Rig();
      await rig.started();
      rig.verifier.outcome = VerificationOutcome.unavailable;
      rig.billing.restoreEmits = [
        fakePurchase(status: BillingPurchaseStatus.restored, token: 'tok-owned'),
      ];
      await rig.controller.restore();

      expect(rig.controller.isPremium, isFalse);
      expect(rig.controller.notice, PremiumNotice.verificationUnavailable);
    });
  });
}

