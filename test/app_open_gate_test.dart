import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:bkknex_health_app/core/ads/app_open_gate.dart';
import 'package:bkknex_health_app/data/ads/admob_ad_service.dart';

bool _allows({
  bool isPremium = false,
  bool isShellForegroundRoute = true,
  int tabIndex = 0,
  bool isColdStart = false,
  Duration? awayFor = const Duration(minutes: 5),
}) =>
    AppOpenGate.allows(
      isPremium: isPremium,
      isShellForegroundRoute: isShellForegroundRoute,
      tabIndex: tabIndex,
      isColdStart: isColdStart,
      awayFor: awayFor,
    );

void main() {
  group('AppOpenGate (is the user free to be interrupted?)', () {
    test('allowed on Home after a real absence', () => expect(_allows(), isTrue));

    test('never for Premium', () => expect(_allows(isPremium: true), isFalse));

    test('never while a pushed screen / sheet / dialog is over the shell '
        '(Food Scanner, Quick Add, Health Report Reader, ...)', () {
      expect(_allows(isShellForegroundRoute: false), isFalse);
    });

    test('never on the AI Talk tab (user may be typing or speaking)', () {
      expect(_allows(tabIndex: AppOpenGate.aiTalkTabIndex), isFalse);
    });

    test('a brief pause/resume (permission dialog, notification shade) is not an absence', () {
      expect(_allows(awayFor: const Duration(seconds: 5)), isFalse);
      expect(_allows(awayFor: null), isFalse);
      expect(_allows(awayFor: AppOpenGate.minimumAwayTime), isTrue);
    });

    test('cold start does not need an absence', () {
      expect(_allows(isColdStart: true, awayFor: null), isTrue);
    });

    test('cold start still respects every other rule', () {
      expect(_allows(isColdStart: true, awayFor: null, isPremium: true), isFalse);
      expect(_allows(isColdStart: true, awayFor: null, isShellForegroundRoute: false), isFalse);
    });
  });

  group('canShowAppOpenAd expiry (Google: ads are valid for 4 hours)', () {
    final now = DateTime(2026, 1, 1, 12);

    test('a fresh ad can be shown', () {
      expect(
        canShowAppOpenAd(
          now: now,
          lastShownAt: null,
          hasLoadedAd: true,
          isShowingAd: false,
          adLoadedAt: now.subtract(const Duration(minutes: 10)),
        ),
        isTrue,
      );
    });

    test('an ad loaded 4h or more ago is expired and refused', () {
      expect(
        canShowAppOpenAd(
          now: now,
          lastShownAt: null,
          hasLoadedAd: true,
          isShowingAd: false,
          adLoadedAt: now.subtract(appOpenAdMaxAge),
        ),
        isFalse,
      );
    });
  });

  group('pickBannerSize', () {
    test('uses the adaptive size when its height is reasonable', () {
      final adaptive = AnchoredAdaptiveBannerAdSize(null, width: 392, height: 60);
      expect(pickBannerSize(adaptive), same(adaptive));
    });

    test('falls back to the standard 320x50 banner when Google returns nothing', () {
      expect(pickBannerSize(null), AdSize.banner);
    });

    test('falls back to the standard banner rather than eating a tall screen', () {
      final tall = AnchoredAdaptiveBannerAdSize(null, width: 392, height: maxBannerHeightDp + 40);
      expect(pickBannerSize(tall), AdSize.banner);
    });
  });
}
