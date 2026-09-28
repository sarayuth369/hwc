import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bkknex_health_app/domain/repositories/subscription_repository.dart';
import 'package:bkknex_health_app/presentation/widgets/premium_gate.dart';

class _FakeSubscriptionRepository implements SubscriptionRepository {
  _FakeSubscriptionRepository(this.tier);
  final SubscriptionTier tier;

  @override
  Future<SubscriptionTier> currentTier() async => tier;
}

void main() {
  testWidgets('shows the locked upsell on the free tier, never the feature',
      (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SubscriptionRepository>.value(
            value: _FakeSubscriptionRepository(SubscriptionTier.free),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PremiumGate(
              featureName: 'AI Health Coach',
              child: Text('Unlocked feature content'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('premiumGateMessage')), findsOneWidget);
    expect(find.text('Unlocked feature content'), findsNothing);
  });

  testWidgets('shows the real feature when the tier is premium', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SubscriptionRepository>.value(
            value: _FakeSubscriptionRepository(SubscriptionTier.premium),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PremiumGate(
              featureName: 'AI Health Coach',
              child: Text('Unlocked feature content'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unlocked feature content'), findsOneWidget);
    expect(find.byKey(const Key('premiumGateMessage')), findsNothing);
  });
}
