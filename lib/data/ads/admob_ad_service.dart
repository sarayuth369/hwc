import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/config/env.dart';
import '../../domain/ads/ad_service.dart';

/// How long to wait between App Open ad impressions, regardless of how
/// often the app is resumed — pulled out as a pure, unit-testable function
/// of (now, lastShownAt) rather than left inline, so the cooldown logic
/// doesn't require mocking the whole AdMob SDK to verify.
bool canShowAppOpenAd({
  required DateTime now,
  required DateTime? lastShownAt,
  required bool hasLoadedAd,
  required bool isShowingAd,
  Duration cooldown = const Duration(hours: 4),
}) {
  if (!hasLoadedAd || isShowingAd) return false;
  if (lastShownAt == null) return true;
  return now.difference(lastShownAt) >= cooldown;
}

/// Real `google_mobile_ads` integration. Uses Google's own published test
/// ad unit IDs by default (see `Env.bannerAdUnitId`/`appOpenAdUnitId`) --
/// this genuinely serves real (test-labeled) ad creative from Google's ad
/// network today, not a placeholder. Swapping to production ad units is a
/// `--dart-define` change, no code change.
class AdMobAdService extends ChangeNotifier implements AdService {
  BannerAd? _banner;
  bool _bannerLoaded = false;
  AppOpenAd? _appOpenAd;
  bool _showingAppOpenAd = false;
  DateTime? _lastAppOpenAdShownAt;

  @override
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _loadBanner();
    _loadAppOpenAd();
  }

  @override
  void dispose() {
    _banner?.dispose();
    _appOpenAd?.dispose();
    super.dispose();
  }

  void _loadBanner() {
    final banner = BannerAd(
      adUnitId: Env.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        // The first `AdBannerBar` to build is very likely to do so before
        // this finishes loading -- without notifying listeners here, that
        // widget would check once, see null, and never ask again, so a
        // banner that loaded a second later would just never appear.
        onAdLoaded: (_) {
          _bannerLoaded = true;
          notifyListeners();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _banner = null;
          _bannerLoaded = false;
          notifyListeners();
        },
      ),
    );
    _banner = banner;
    banner.load();
  }

  void _loadAppOpenAd() {
    AppOpenAd.load(
      adUnitId: Env.appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) => _appOpenAd = ad,
        onAdFailedToLoad: (_) => _appOpenAd = null,
      ),
    );
  }

  @override
  Widget? bannerAdWidget() {
    final banner = _banner;
    if (banner == null || !_bannerLoaded) return null;
    return SizedBox(
      width: banner.size.width.toDouble(),
      height: banner.size.height.toDouble(),
      child: AdWidget(ad: banner),
    );
  }

  @override
  Future<void> maybeShowAppOpenAd() async {
    final ad = _appOpenAd;
    if (ad == null ||
        !canShowAppOpenAd(
          now: DateTime.now(),
          lastShownAt: _lastAppOpenAdShownAt,
          hasLoadedAd: true,
          isShowingAd: _showingAppOpenAd,
        )) {
      return;
    }

    _showingAppOpenAd = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        _showingAppOpenAd = false;
        _loadAppOpenAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _appOpenAd = null;
        _showingAppOpenAd = false;
        _loadAppOpenAd();
      },
    );
    _lastAppOpenAdShownAt = DateTime.now();
    await ad.show();
  }
}
