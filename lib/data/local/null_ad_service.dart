import 'package:flutter/widgets.dart';

import '../../domain/ads/ad_service.dart';

/// Real, honest "no ad" implementation — used for a Premium user (who
/// should never see an ad at all) and in tests (where the real
/// `google_mobile_ads` platform channel doesn't exist). Same pattern as
/// `NullVoiceProvider`/`NullFamilyRepository` elsewhere in this app: never
/// fakes an ad, just correctly reports there isn't one.
class NullAdService implements AdService {
  @override
  Future<void> initialize() async {}

  @override
  Widget? bannerAdWidget() => null;

  @override
  Future<void> maybeShowAppOpenAd() async {}
}
