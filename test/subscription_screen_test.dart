import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bkknex_health_app/domain/billing/billing_service.dart';
import 'package:bkknex_health_app/domain/billing/entitlement_verifier.dart';
import 'package:bkknex_health_app/domain/billing/premium_controller.dart';
import 'package:bkknex_health_app/domain/repositories/subscription_repository.dart';
import 'package:bkknex_health_app/presentation/screens/settings/subscription_screen.dart';

import 'support/fake_repositories.dart';

class _Rig {
  _Rig({
    BillingCatalog? catalog,
    SubscriptionTier initial = SubscriptionTier.free,
  })  : repo = FakeSubscriptionRepository(initial),
        billing = FakeBillingService(catalog: catalog ?? fakePlayCatalog()) {
    verifier = FakeEntitlementVerifier(repository: repo);
    controller = buildPremiumController(
      billing: billing,
      subscriptions: repo,
      verifier: verifier,
    );
  }

  final FakeSubscriptionRepository repo;
  final FakeBillingService billing;
  late final FakeEntitlementVerifier verifier;
  late final PremiumController controller;
}

Future<void> _pump(WidgetTester tester, _Rig rig) async {
  await tester.binding.setSurfaceSize(const Size(390, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  // HomeShell starts the controller (purchase listener + entitlement) for the
  // whole signed-in session; the Premium screen only ever opens inside it.
  await rig.controller.start();
  await tester.pumpWidget(
    ChangeNotifierProvider<PremiumController>.value(
      value: rig.controller,
      child: const MaterialApp(home: SubscriptionScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

String _messageText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('subscriptionMessage'))).data!;

void main() {
  group('plans', () {
    testWidgets('shows the monthly and yearly prices exactly as Google Play returned them',
        (tester) async {
      await _pump(tester, _Rig());
      expect(find.text(r'$3.99'), findsOneWidget);
      expect(find.text(r'$44.99'), findsOneWidget);
      expect(find.text('per month'), findsOneWidget);
      expect(find.text('per year'), findsOneWidget);
    });

    testWidgets('no hard-coded fallback price when Play data is unavailable', (tester) async {
      final rig = _Rig(
        catalog: const BillingCatalog.unavailable(BillingCatalogStatus.productNotFound),
      );
      await _pump(tester, rig);

      expect(find.text(r'$3.99'), findsNothing);
      expect(find.text(r'$44.99'), findsNothing);
      expect(find.byKey(const Key('subscriptionCatalogMessage')), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byKey(const Key('subscribeButton')));
      expect(button.onPressed, isNull, reason: 'nothing to buy yet');
    });

    testWidgets('Play Billing unavailable on the device is explained, not a crash', (tester) async {
      final rig = _Rig(
        catalog: const BillingCatalog.unavailable(BillingCatalogStatus.billingUnavailable),
      );
      await _pump(tester, rig);
      expect(find.byKey(const Key('subscriptionCatalogMessage')), findsOneWidget);
      expect(find.textContaining("isn't available on this device"), findsOneWidget);
      expect(find.byKey(const Key('retryCatalogButton')), findsNothing);
    });

    testWidgets('a transient load error offers Try again, which re-queries Play', (tester) async {
      final rig = _Rig(catalog: const BillingCatalog.unavailable(BillingCatalogStatus.error));
      await _pump(tester, rig);
      expect(rig.billing.loadCatalogCalls, 1);

      rig.billing.catalog = fakePlayCatalog();
      await tester.tap(find.byKey(const Key('retryCatalogButton')));
      await tester.pumpAndSettle();

      expect(rig.billing.loadCatalogCalls, 2);
      expect(find.text(r'$3.99'), findsOneWidget);
      expect(find.byKey(const Key('subscriptionCatalogMessage')), findsNothing);
    });

    testWidgets('re-queries products and purchases every time the screen opens', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      expect(rig.billing.loadCatalogCalls, 1);
      // once at app start (controller.start) + once when this screen opened
      expect(rig.billing.restoreCalls, 2);
    });
  });

  group('purchasing', () {
    testWidgets('yearly is preselected; Subscribe starts the yearly base plan for this account',
        (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      expect(find.textContaining(r'Subscribe — $44.99 / year'), findsOneWidget);

      await tester.tap(find.byKey(const Key('subscribeButton')));
      await tester.pump();

      expect(rig.billing.purchaseRequests.single.basePlanId, 'yearly');
      expect(rig.billing.purchaseAccountIds.single, 'test-user');
    });

    testWidgets('choosing Monthly then Subscribe starts the monthly base plan', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await tester.tap(find.byKey(const Key('planMonthly')));
      await tester.pump();
      expect(find.textContaining(r'Subscribe — $3.99 / month'), findsOneWidget);

      await tester.tap(find.byKey(const Key('subscribeButton')));
      await tester.pump();
      expect(rig.billing.purchaseRequests.single.basePlanId, 'monthly');
    });

    testWidgets('the button locks while a purchase is in flight (no duplicate submission)',
        (tester) async {
      final rig = _Rig();
      rig.billing.purchaseGate = Completer<void>();
      await _pump(tester, rig);

      await tester.tap(find.byKey(const Key('subscribeButton')));
      await tester.pump();
      expect(find.text('Waiting for Google Play...'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byKey(const Key('subscribeButton')));
      expect(button.onPressed, isNull);

      await tester.tap(find.byKey(const Key('subscribeButton')), warnIfMissed: false);
      await tester.pump();
      expect(rig.billing.purchaseRequests, hasLength(1));

      rig.billing.purchaseGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a verified purchase flips the screen to the active state', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await tester.tap(find.byKey(const Key('subscribeButton')));
      await tester.pump();

      rig.billing.emit(fakePurchase());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('premiumActiveBadge')), findsOneWidget);
      expect(find.byKey(const Key('activeSubscriptionCard')), findsOneWidget);
      expect(find.byKey(const Key('subscribeButton')), findsNothing);
      expect(find.byKey(const Key('manageSubscriptionButton')), findsOneWidget);
      expect(_messageText(tester), contains('now active'));
    });

    testWidgets('cancelling shows a "not charged" message and the user can retry', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await tester.tap(find.byKey(const Key('subscribeButton')));
      await tester.pump();

      rig.billing.emit(fakePurchase(status: BillingPurchaseStatus.canceled, token: null));
      await tester.pumpAndSettle();

      expect(_messageText(tester), contains('not been charged'));
      final button = tester.widget<FilledButton>(find.byKey(const Key('subscribeButton')));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('a pending payment is explained and keeps the button locked', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await tester.tap(find.byKey(const Key('subscribeButton')));
      await tester.pump();

      rig.billing.emit(fakePurchase(status: BillingPurchaseStatus.pending, token: null));
      await tester.pumpAndSettle();

      expect(_messageText(tester), contains('pending'));
      expect(find.text('Payment pending'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byKey(const Key('subscribeButton')));
      expect(button.onPressed, isNull);
      expect(find.byKey(const Key('premiumActiveBadge')), findsNothing);
    });

    testWidgets('a store error shows a plain message', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await tester.tap(find.byKey(const Key('subscribeButton')));
      await tester.pump();

      rig.billing.emit(fakePurchase(status: BillingPurchaseStatus.error, token: null));
      await tester.pumpAndSettle();
      expect(_messageText(tester), contains('Something went wrong'));
    });

    testWidgets(
        'Play charged but the server cannot verify yet: says so, does NOT unlock Premium',
        (tester) async {
      final rig = _Rig();
      rig.verifier.outcome = VerificationOutcome.notConfigured;
      await _pump(tester, rig);
      await tester.tap(find.byKey(const Key('subscribeButton')));
      await tester.pump();

      rig.billing.emit(fakePurchase());
      await tester.pumpAndSettle();

      expect(_messageText(tester), contains("couldn't confirm it with our server yet"));
      expect(find.byKey(const Key('premiumActiveBadge')), findsNothing);
      expect(find.byKey(const Key('subscribeButton')), findsOneWidget);
    });
  });

  group('restore', () {
    testWidgets('with nothing to restore, says so', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await tester.tap(find.byKey(const Key('restorePurchasesButton')));
      await tester.pumpAndSettle();
      expect(_messageText(tester), contains('No active HWC Premium subscription'));
    });

    testWidgets('restores an existing subscription', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      rig.billing.restoreEmits = [
        fakePurchase(status: BillingPurchaseStatus.restored, token: 'tok-owned'),
      ];
      await tester.tap(find.byKey(const Key('restorePurchasesButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('premiumActiveBadge')), findsOneWidget);
    });

    testWidgets('the button is also available to an active subscriber', (tester) async {
      final rig = _Rig(initial: SubscriptionTier.premium);
      await _pump(tester, rig);
      expect(find.byKey(const Key('restorePurchasesButton')), findsOneWidget);
    });
  });

  group('active subscription', () {
    testWidgets('a subscriber sees the active state, no purchase controls, and a Play manage link',
        (tester) async {
      final rig = _Rig(initial: SubscriptionTier.premium);
      await _pump(tester, rig);

      expect(find.byKey(const Key('premiumActiveBadge')), findsOneWidget);
      expect(find.byKey(const Key('activeSubscriptionCard')), findsOneWidget);
      expect(find.byKey(const Key('subscribeButton')), findsNothing);
      expect(find.byKey(const Key('planMonthly')), findsNothing);
      expect(find.byKey(const Key('manageSubscriptionButton')), findsOneWidget);
    });
  });

  group('disclosure', () {
    testWidgets('states auto-renewal, Google Play pricing, cancelation and restore, with legal links',
        (tester) async {
      await _pump(tester, _Rig());
      final text = tester.widget<Text>(find.byKey(const Key('subscriptionDisclosure'))).data!;

      expect(text, contains('renews automatically'));
      expect(text, contains('price shown by Google Play'));
      expect(text, contains('cancel'));
      expect(text, contains('Restore purchases'));
      expect(find.byKey(const Key('subscriptionTermsLink')), findsOneWidget);
      expect(find.byKey(const Key('subscriptionPrivacyLink')), findsOneWidget);
    });

    testWidgets('makes no medical or financial claims in the benefit list', (tester) async {
      await _pump(tester, _Rig());
      for (final banned in ['cure', 'diagnos', 'guarantee', 'return on investment']) {
        expect(find.textContaining(banned, findRichText: true), findsNothing, reason: banned);
      }
    });
  });
}
