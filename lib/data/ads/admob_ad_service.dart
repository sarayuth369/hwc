import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/ads/ad_unit_ids.dart';
import '../../domain/ads/ad_service.dart';
import 'ad_consent_manager.dart';

/// Google: an App Open ad is only valid for 4 hours after it loads; showing
/// a stale one fails or earns nothing, so it is discarded and re-requested.
const appOpenAdMaxAge = Duration(hours: 4);

/// Minimum gap between two App Open impressions, regardless of how often the
/// app is resumed -- a wellness app should not greet users with a full-screen
/// ad every time they glance back at it.
const appOpenAdCooldown = Duration(hours: 4);

/// After a failed banner request, don't hammer the ad server: the next
/// attempt waits at least this long (retries happen naturally the next time
/// a banner-hosting screen builds, not on a timer).
const bannerRetryInterval = Duration(seconds: 60);

/// The "large anchored adaptive" banner can be up to 15% of screen height
/// (well over 100dp on a tall phone). HWC targets seniors and keeps content
/// readable above the bar, so anything taller than this falls back to the
/// standard 320x50 banner instead of eating the screen.
const maxBannerHeightDp = 100;

/// Pure policy: may an already-loaded App Open ad be shown right now?
/// Pulled out so the rules are unit-testable without mocking the AdMob SDK.
bool canShowAppOpenAd({
  required DateTime now,
  required DateTime? lastShownAt,
  required bool hasLoadedAd,
  required bool isShowingAd,
  DateTime? adLoadedAt,
  Duration cooldown = appOpenAdCooldown,
  Duration maxAdAge = appOpenAdMaxAge,
}) {
  if (!hasLoadedAd || isShowingAd) return false;
  if (adLoadedAt != null && now.difference(adLoadedAt) >= maxAdAge) return false;
  if (lastShownAt == null) return true;
  return now.difference(lastShownAt) >= cooldown;
}

/// Picks the banner size: the anchored adaptive size when Google returns one
/// of a sensible height, otherwise the standard 320x50 banner.
AdSize pickBannerSize(AnchoredAdaptiveBannerAdSize? adaptive) {
  if (adaptive == null || adaptive.height > maxBannerHeightDp) return AdSize.banner;
  return adaptive;
}

/// Real `google_mobile_ads` integration. Ad units come from [AdUnitIds] by
/// build mode (release = production, debug/profile = Google test units).
///
/// Startup safety: [initialize] is fire-and-forget, catches everything, and
/// nothing in the app awaits it -- a failed/slow/denied consent flow, an SDK
/// error or no network simply means no ads, never a crash or a blocked UI.
class AdMobAdService extends ChangeNotifier implements AdService {
  AdMobAdService({
    AdConsentManager? consentManager,
    AdUnitIds? unitIds,
    DateTime Function()? clock,
  })  : _consent = consentManager ?? AdConsentManager(),
        _ids = unitIds ?? AdUnitIds.current,
        _now = clock ?? DateTime.now;

  final AdConsentManager _consent;
  final AdUnitIds _ids;
  final DateTime Function() _now;

  bool _disposed = false;
  // True only after consent allowed ad requests AND the SDK initialized.
  bool _adsAllowed = false;
  Future<void>? _initFuture;

  BannerAd? _banner;
  bool _bannerLoaded = false;
  bool _bannerLoading = false;
  DateTime? _lastBannerFailureAt;
  int? _pendingBannerWidth;

  AppOpenAd? _appOpenAd;
  DateTime? _appOpenLoadedAt;
  bool _appOpenLoading = false;
  bool _showingAppOpenAd = false;
  DateTime? _lastAppOpenAdShownAt;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  Future<void> initialize() => _initFuture ??= _initialize();

  Future<void> _initialize() async {
    try {
      final canRequestAds = await _consent.gatherConsentAndCheckCanRequestAds();
      if (_disposed) return;
      if (!canRequestAds) {
        debugPrint('AdMobAdService: ads not requested (consent unavailable or not granted).');
        return;
      }
      await MobileAds.instance.initialize();
      if (_disposed) return;
      _adsAllowed = true;
      _loadAppOpenAd();
      final width = _pendingBannerWidth;
      if (width != null) unawaited(prepareBanner(width));
    } catch (e) {
      debugPrint('AdMobAdService: initialization failed, continuing without ads: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _banner?.dispose();
    _banner = null;
    _appOpenAd?.dispose();
    _appOpenAd = null;
    super.dispose();
  }

  // --- Banner -------------------------------------------------------------

  @override
  Future<void> prepareBanner(int widthDp) async {
    _pendingBannerWidth = widthDp;
    if (_disposed || !_adsAllowed || _banner != null || _bannerLoading) return;
    final lastFailure = _lastBannerFailureAt;
    if (lastFailure != null && _now().difference(lastFailure) < bannerRetryInterval) return;

    _bannerLoading = true;
    try {
      final adaptive = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(widthDp);
      if (_disposed) {
        _bannerLoading = false;
        return;
      }
      final banner = BannerAd(
        adUnitId: _ids.banner,
        size: pickBannerSize(adaptive),
        request: const AdRequest(),
        listener: BannerAdListener(
          // The first `AdBannerBar` to build is very likely to do so before
          // this finishes loading -- notifying lets it rebuild once the ad
          // is actually ready instead of checking once and giving up.
          onAdLoaded: (_) {
            _bannerLoaded = true;
            _bannerLoading = false;
            _notify();
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('AdMobAdService: banner failed to load: ${error.message}');
            ad.dispose();
            if (identical(_banner, ad)) _banner = null;
            _bannerLoaded = false;
            _bannerLoading = false;
            _lastBannerFailureAt = _now();
            _notify();
          },
        ),
      );
      _banner = banner;
      await banner.load();
    } catch (e) {
      debugPrint('AdMobAdService: banner setup failed: $e');
      _banner?.dispose();
      _banner = null;
      _bannerLoaded = false;
      _bannerLoading = false;
      _lastBannerFailureAt = _now();
    }
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

  // --- App Open -----------------------------------------------------------

  void _loadAppOpenAd() {
    if (_disposed || !_adsAllowed || _appOpenLoading) return;
    _appOpenLoading = true;
    try {
      AppOpenAd.load(
        adUnitId: _ids.appOpen,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _appOpenLoading = false;
            if (_disposed) {
              ad.dispose();
              return;
            }
            _appOpenAd?.dispose();
            _appOpenAd = ad;
            _appOpenLoadedAt = _now();
          },
          onAdFailedToLoad: (error) {
            debugPrint('AdMobAdService: app open ad failed to load: ${error.message}');
            _appOpenLoading = false;
            _appOpenAd = null;
          },
        ),
      );
    } catch (e) {
      debugPrint('AdMobAdService: app open load failed: $e');
      _appOpenLoading = false;
    }
  }

  @override
  Future<void> maybeShowAppOpenAd() async {
    if (_disposed || !_adsAllowed) return;
    final ad = _appOpenAd;
    if (ad == null) {
      // Nothing ready (still loading, or an earlier load failed) -- carry on
      // normally and make sure a request is in flight for next time.
      _loadAppOpenAd();
      return;
    }

    final now = _now();
    final loadedAt = _appOpenLoadedAt;
    if (loadedAt != null && now.difference(loadedAt) >= appOpenAdMaxAge) {
      ad.dispose();
      _appOpenAd = null;
      _loadAppOpenAd();
      return;
    }
    if (!canShowAppOpenAd(
      now: now,
      lastShownAt: _lastAppOpenAdShownAt,
      hasLoadedAd: true,
      isShowingAd: _showingAppOpenAd,
      adLoadedAt: loadedAt,
    )) {
      return;
    }

    // An ad object can be shown exactly once.
    _appOpenAd = null;
    _showingAppOpenAd = true;
    _lastAppOpenAdShownAt = now;
    void finish(Ad shown) {
      shown.dispose();
      _showingAppOpenAd = false;
      _loadAppOpenAd();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: finish,
      onAdFailedToShowFullScreenContent: (shown, error) {
        debugPrint('AdMobAdService: app open ad failed to show: ${error.message}');
        finish(shown);
      },
    );
    try {
      await ad.show();
    } catch (e) {
      debugPrint('AdMobAdService: app open show threw: $e');
      finish(ad);
    }
  }

  // --- Privacy choices ----------------------------------------------------

  @override
  Future<bool> isPrivacyOptionsRequired() => _consent.isPrivacyOptionsRequired();

  @override
  Future<void> showPrivacyOptions() async {
    await _consent.showPrivacyOptions();
    // If the user just granted consent after starting the session without
    // it, start ads now instead of waiting for the next launch.
    if (!_adsAllowed && !_disposed) {
      _initFuture = null;
      unawaited(initialize());
    }
  }
}
