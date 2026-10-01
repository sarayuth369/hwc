import 'package:flutter_test/flutter_test.dart';

import 'package:bkknex_health_app/data/ads/admob_ad_service.dart';

void main() {
  final now = DateTime(2026, 1, 1, 12);

  test('shows when no ad has ever been shown and one is loaded', () {
    expect(
      canShowAppOpenAd(now: now, lastShownAt: null, hasLoadedAd: true, isShowingAd: false),
      isTrue,
    );
  });

  test('refuses when no ad is loaded', () {
    expect(
      canShowAppOpenAd(now: now, lastShownAt: null, hasLoadedAd: false, isShowingAd: false),
      isFalse,
    );
  });

  test('refuses while one is already showing', () {
    expect(
      canShowAppOpenAd(now: now, lastShownAt: null, hasLoadedAd: true, isShowingAd: true),
      isFalse,
    );
  });

  test('refuses within the cooldown window', () {
    final shownRecently = now.subtract(const Duration(hours: 1));
    expect(
      canShowAppOpenAd(now: now, lastShownAt: shownRecently, hasLoadedAd: true, isShowingAd: false),
      isFalse,
    );
  });

  test('allows again once the cooldown has fully elapsed', () {
    final shownLongAgo = now.subtract(const Duration(hours: 4, minutes: 1));
    expect(
      canShowAppOpenAd(now: now, lastShownAt: shownLongAgo, hasLoadedAd: true, isShowingAd: false),
      isTrue,
    );
  });

  test('exactly at the cooldown boundary counts as elapsed', () {
    final shownExactly4hAgo = now.subtract(const Duration(hours: 4));
    expect(
      canShowAppOpenAd(now: now, lastShownAt: shownExactly4hAgo, hasLoadedAd: true, isShowingAd: false),
      isTrue,
    );
  });
}
