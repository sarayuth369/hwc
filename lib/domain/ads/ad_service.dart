import 'package:flutter/widgets.dart';

/// Ad-provider-agnostic seam. The only implementation today is
/// `AdMobAdService` (real `google_mobile_ads` calls, not a simulation).
/// Every call site checks `SubscriptionRepository` itself before asking for
/// an ad — Premium users should never see one — so this service doesn't
/// need to know about entitlement at all.
abstract class AdService {
  Future<void> initialize();

  /// Returns null when no ad is available/configured yet (e.g. the banner
  /// hasn't loaded, or ads are disabled) — callers render nothing rather
  /// than a placeholder box, so a missing ad never leaves a dead gap.
  Widget? bannerAdWidget();

  /// Shows the App Open ad if one is ready and it's been long enough since
  /// the last one — never on every single resume, which would be an
  /// annoying, non-compliant pattern. No-ops silently if nothing is ready.
  Future<void> maybeShowAppOpenAd();
}
