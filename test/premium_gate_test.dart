import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bkknex_health_app/domain/billing/premium_controller.dart';
import 'package:bkknex_health_app/domain/repositories/subscription_repository.dart';
import 'package:bkknex_health_app/presentation/widgets/premium_gate.dart';

import 'support/fake_repositories.dart';

Widget _harness(PremiumController controller) => ChangeNotifierProvider<PremiumController>.value(
      value: controller,
      child: const MaterialApp(
        home: Scaffold(
          body: PremiumGate(
            featureName: 'AI Health Coach',
            child: Text('Unlocked feature content'),
          ),
        ),
      ),
    );

PremiumController _controller(SubscriptionTier tier) => buildPremiumController(
      billing: FakeBillingService(),
      subscriptions: FakeSubscriptionRepository(tier),
    );

void main() {
  testWidgets('shows the locked upsell on the free tier, never the feature',
      (tester) async {
    final controller = _controller(SubscriptionTier.free);
    await controller.refreshEntitlement();
    await tester.pumpWidget(_harness(controller));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('premiumGateMessage')), findsOneWidget);
    expect(find.text('Unlocked feature content'), findsNothing);
  });

  testWidgets('shows the real feature when the tier is premium', (tester) async {
    final controller = _controller(SubscriptionTier.premium);
    await controller.refreshEntitlement();
    await tester.pumpWidget(_harness(controller));
    await tester.pumpAndSettle();

    expect(find.text('Unlocked feature content'), findsOneWidget);
    expect(find.byKey(const Key('premiumGateMessage')), findsNothing);
  });

  testWidgets(
      'shows neither the feature nor the locked upsell until the entitlement '
      'is known (a subscriber never sees a flash of "locked")', (tester) async {
    final controller = _controller(SubscriptionTier.premium);
    await tester.pumpWidget(_harness(controller));

    expect(find.text('Unlocked feature content'), findsNothing);
    expect(find.byKey(const Key('premiumGateMessage')), findsNothing);

    await controller.refreshEntitlement();
    await tester.pumpAndSettle();
    expect(find.text('Unlocked feature content'), findsOneWidget);
  });
}
