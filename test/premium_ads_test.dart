import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bkknex_health_app/core/accessibility/accessibility_mode_controller.dart';
import 'package:bkknex_health_app/core/theme/app_theme_mode_controller.dart';
import 'package:bkknex_health_app/data/local/null_ad_service.dart';
import 'package:bkknex_health_app/domain/ads/ad_service.dart';
import 'package:bkknex_health_app/domain/billing/billing_product.dart';
import 'package:bkknex_health_app/domain/billing/premium_controller.dart';
import 'package:bkknex_health_app/domain/repositories/subscription_repository.dart';
import 'package:bkknex_health_app/presentation/screens/home/home_shell.dart';
import 'package:bkknex_health_app/presentation/widgets/ad_banner_bar.dart';
import 'package:bkknex_health_app/presentation/widgets/premium_promo_card.dart';

import 'support/fake_push.dart';
import 'support/fake_repositories.dart';

/// Records ad requests, and "has" a banner as soon as one is requested.
class _RecordingAdService extends NullAdService {
  int bannerRequests = 0;
  int appOpenRequests = 0;

  @override
  Future<void> prepareBanner(int widthDp) async {
    // Like the real service: a banner "loads" on first request and tells
    // listeners, so the bar rebuilds with it.
    if (bannerRequests++ == 0) notifyListeners();
  }

  @override
  Widget? bannerAdWidget() => bannerRequests > 0
      ? const SizedBox(key: Key('fakeBanner'), height: 50, width: double.infinity)
      : null;

  @override
  Future<void> maybeShowAppOpenAd() async => appOpenRequests++;
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('AdBannerBar follows the single Premium state', () {
    Future<void> pumpBar(
      WidgetTester tester, {
      required PremiumController premium,
      required _RecordingAdService ads,
    }) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AdService>.value(value: ads),
            ChangeNotifierProvider<PremiumController>.value(value: premium),
          ],
          child: const MaterialApp(home: Scaffold(body: AdBannerBar())),
        ),
      );
      await tester.pumpAndSettle();
    }

    PremiumController controllerFor(SubscriptionTier tier, {FakeBillingService? billing}) =>
        buildPremiumController(
          billing: billing ?? FakeBillingService(),
          subscriptions: FakeSubscriptionRepository(tier),
        );

    testWidgets('a free user gets an ad request and sees the banner', (tester) async {
      final ads = _RecordingAdService();
      final premium = controllerFor(SubscriptionTier.free);
      await premium.refreshEntitlement();
      await pumpBar(tester, premium: premium, ads: ads);
      await tester.pumpAndSettle();

      expect(ads.bannerRequests, greaterThan(0));
      expect(find.byKey(const Key('fakeBanner')), findsOneWidget);
    });

    testWidgets('a Premium user triggers NO ad request and sees no banner', (tester) async {
      final ads = _RecordingAdService();
      final premium = controllerFor(SubscriptionTier.premium);
      await premium.refreshEntitlement();
      await pumpBar(tester, premium: premium, ads: ads);

      expect(ads.bannerRequests, 0);
      expect(find.byKey(const Key('fakeBanner')), findsNothing);
    });

    testWidgets('no ad request is made until the entitlement is known', (tester) async {
      final ads = _RecordingAdService();
      final premium = controllerFor(SubscriptionTier.premium); // not loaded yet
      await pumpBar(tester, premium: premium, ads: ads);

      expect(ads.bannerRequests, 0, reason: 'a subscriber must never trigger a request at startup');
      expect(find.byKey(const Key('fakeBanner')), findsNothing);
    });

    testWidgets('a verified purchase removes the banner immediately', (tester) async {
      final ads = _RecordingAdService();
      final billing = FakeBillingService(catalog: fakePlayCatalog());
      final repo = FakeSubscriptionRepository();
      final premium = buildPremiumController(
        billing: billing,
        subscriptions: repo,
        verifier: FakeEntitlementVerifier(repository: repo),
      );
      await premium.start();
      await premium.loadCatalog();
      await pumpBar(tester, premium: premium, ads: ads);
      expect(find.byKey(const Key('fakeBanner')), findsOneWidget);

      await premium.purchase(BillingPeriod.monthly);
      billing.emit(fakePurchase());
      await tester.pumpAndSettle();

      expect(premium.isPremium, isTrue);
      expect(find.byKey(const Key('fakeBanner')), findsNothing);
    });
  });

  group('PremiumPromoCard', () {
    Future<void> pumpCard(WidgetTester tester, PremiumController premium) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<PremiumController>.value(
          value: premium,
          child: const MaterialApp(home: Scaffold(body: PremiumPromoCard())),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('is shown to a free user', (tester) async {
      final premium = buildPremiumController(
        billing: FakeBillingService(),
        subscriptions: FakeSubscriptionRepository(),
      );
      await premium.refreshEntitlement();
      await pumpCard(tester, premium);
      expect(find.byKey(const Key('premiumPromoCard')), findsOneWidget);
    });

    testWidgets('is hidden for a Premium user', (tester) async {
      final premium = buildPremiumController(
        billing: FakeBillingService(),
        subscriptions: FakeSubscriptionRepository(SubscriptionTier.premium),
      );
      await premium.refreshEntitlement();
      await pumpCard(tester, premium);
      expect(find.byKey(const Key('premiumPromoCard')), findsNothing);
    });

    testWidgets('leads to the real subscription flow', (tester) async {
      final premium = buildPremiumController(
        billing: FakeBillingService(catalog: fakePlayCatalog()),
        subscriptions: FakeSubscriptionRepository(),
      );
      await premium.refreshEntitlement();
      await pumpCard(tester, premium);

      await tester.tap(find.byKey(const Key('premiumPromoCard')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('subscribeButton')), findsOneWidget);
      expect(find.text(r'$44.99'), findsOneWidget);
    });
  });

  group('App Open ad on the real HomeShell', () {
    Future<_RecordingAdService> pumpShell(
      WidgetTester tester, {
      required SubscriptionTier tier,
    }) async {
      final ads = _RecordingAdService();
      await tester.binding.setSurfaceSize(const Size(390, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AccessibilityModeController(prefs)),
            ChangeNotifierProvider(create: (_) => AppThemeModeController(prefs)),
            ...fullProviderSet(
              prefs: prefs,
              pushService: FakePushService(),
              adService: ads,
              subscriptionRepository: FakeSubscriptionRepository(tier),
            ),
          ],
          child: const MaterialApp(home: HomeShell()),
        ),
      );
      await tester.pumpAndSettle();
      return ads;
    }

    testWidgets('a free user is eligible: the cold-start App Open ad is requested', (tester) async {
      final ads = await pumpShell(tester, tier: SubscriptionTier.free);
      expect(ads.appOpenRequests, 1);
    });

    testWidgets('a Premium user never has an App Open ad requested', (tester) async {
      final ads = await pumpShell(tester, tier: SubscriptionTier.premium);
      expect(ads.appOpenRequests, 0);
      expect(ads.bannerRequests, 0);
    });
  });
}
