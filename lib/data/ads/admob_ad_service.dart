import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/config/env.dart';
import '../../domain/ads/ad_service.dart';

/// Real `google_mobile_ads` integration. Uses Google's own published test
/// ad unit IDs by default (see `Env.bannerAdUnitId`/`appOpenAdUnitId`) --
/// this genuinely serves real (test-labeled) ad creative from Google's ad
/// network today, not a placeholder. Swapping to production ad units is a
/// `--dart-define` change, no code change.
class AdMobAdService implements AdService {
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

  void _loadBanner() {
    final banner = BannerAd(
      adUnitId: Env.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => _bannerLoaded = true,
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _banner = null;
          _bannerLoaded = false;
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
    if (ad == null || _showingAppOpenAd) return;

    // Never more than once every 4 hours, regardless of how often the app
    // is resumed -- this is exactly the "avoid showing it in an annoying
    // way" requirement, not a cosmetic choice.
    final last = _lastAppOpenAdShownAt;
    if (last != null && DateTime.now().difference(last) < const Duration(hours: 4)) {
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
