import 'package:flutter/widgets.dart';

/// Ad-provider-agnostic seam. The only implementation today is
/// `AdMobAdService` (real `google_mobile_ads` calls, not a simulation).
/// Every call site checks `SubscriptionRepository` itself before asking for
/// an ad — Premium users should never see one — so this service doesn't
/// need to know about entitlement at all.
///
/// Extends [ChangeNotifier] so `AdBannerBar` can rebuild once a banner
/// finishes loading asynchronously after the widget's first build —
/// without this, an ad that loaded a second late (a slow network, a cold
/// cache) would never appear at all, since nothing would ever ask
/// `bannerAdWidget()` again.
abstract class AdService extends ChangeNotifier {
  /// Gathers consent (Google UMP) and, only if ads may be requested,
  /// initializes the Mobile Ads SDK and starts loading. Must never throw and
  /// must never be awaited on the startup path -- the app has to be fully
  /// usable whether or not ads ever become available.
  Future<void> initialize();

  /// Asks the service to load a banner sized for a screen/slot [widthDp]
  /// logical pixels wide (anchored adaptive). Idempotent and cheap to call
  /// on every build -- a no-op when a banner is already loaded/loading,
  /// ads are not allowed, or a recent attempt just failed.
  Future<void> prepareBanner(int widthDp);

  /// Returns null when no ad is available/configured yet (e.g. the banner
  /// hasn't loaded, or ads are disabled) — callers render nothing rather
  /// than a placeholder box, so a missing ad never leaves a dead gap.
  Widget? bannerAdWidget();

  /// Shows the App Open ad if one is ready and it's been long enough since
  /// the last one — never on every single resume, which would be an
  /// annoying, non-compliant pattern. No-ops silently if nothing is ready.
  /// Callers should invoke this both on cold start (after the first frame)
  /// and on every subsequent app resume — the service itself enforces the
  /// cooldown either way, so calling it "too often" is always safe.
  Future<void> maybeShowAppOpenAd();

  /// True when Google requires an in-app "privacy choices" entry point for
  /// this user (UMP privacy-options requirement). Settings shows the entry
  /// only when this is true.
  Future<bool> isPrivacyOptionsRequired();

  /// Opens Google's privacy-options form (change/withdraw ad consent).
  Future<void> showPrivacyOptions();
}
