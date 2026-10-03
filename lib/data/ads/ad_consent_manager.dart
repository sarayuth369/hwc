import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Google User Messaging Platform (UMP) consent handling, following Google's
/// current flow: update consent info on every launch -> show the consent
/// form only if Google says one is required (EEA/UK/Switzerland etc. -- the
/// region logic is Google's, nothing here assumes a country) -> only then
/// ask `canRequestAds()` whether ads may be requested.
///
/// Never throws and never blocks startup: any failure collapses to "use
/// whatever consent state Google has cached" (`canRequestAds()`), and if
/// even that fails, to "no ads" -- the app is fully usable without ads.
class AdConsentManager {
  AdConsentManager({
    ConsentInformation? consentInformation,
    Future<void> Function(OnConsentFormDismissedListener)? showFormIfRequired,
    Future<void> Function(OnConsentFormDismissedListener)? showPrivacyForm,
    this.infoUpdateTimeout = const Duration(seconds: 10),
  })  : _info = consentInformation,
        _showFormIfRequired = showFormIfRequired ?? ConsentForm.loadAndShowConsentFormIfRequired,
        _showPrivacyForm = showPrivacyForm ?? ConsentForm.showPrivacyOptionsForm;

  // Resolved lazily: `ConsentInformation.instance` touches a platform
  // channel, which must not happen at construction time in a widget test.
  final ConsentInformation? _info;
  ConsentInformation get _consent => _info ?? ConsentInformation.instance;

  final Future<void> Function(OnConsentFormDismissedListener) _showFormIfRequired;
  final Future<void> Function(OnConsentFormDismissedListener) _showPrivacyForm;
  final Duration infoUpdateTimeout;

  /// Runs the consent flow and returns whether ads may be requested.
  Future<bool> gatherConsentAndCheckCanRequestAds() async {
    try {
      await _updateConsentInfo();
      await _showFormIfRequiredSafely();
    } catch (e) {
      debugPrint('AdConsentManager: consent flow failed ($e); falling back to cached consent state.');
    }
    return _canRequestAdsSafely();
  }

  Future<void> _updateConsentInfo() {
    final done = Completer<void>();
    _consent.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        if (!done.isCompleted) done.complete();
      },
      (FormError error) {
        debugPrint('AdConsentManager: consent info update failed: ${error.message}');
        if (!done.isCompleted) done.complete();
      },
    );
    // Bounded: a slow/offline network must not keep the flow (and therefore
    // ads) hanging forever -- falls through to the cached consent state.
    return done.future.timeout(infoUpdateTimeout, onTimeout: () {});
  }

  Future<void> _showFormIfRequiredSafely() async {
    final done = Completer<void>();
    unawaited(_showFormIfRequired((FormError? error) {
      if (error != null) {
        debugPrint('AdConsentManager: consent form error: ${error.message}');
      }
      if (!done.isCompleted) done.complete();
    }).catchError((Object e) {
      debugPrint('AdConsentManager: consent form threw: $e');
      if (!done.isCompleted) done.complete();
    }));
    // No timeout here on purpose: this future spans the user reading and
    // answering the form. It never blocks the UI -- the caller is
    // fire-and-forget and ads simply wait for the answer.
    await done.future;
  }

  Future<bool> _canRequestAdsSafely() async {
    try {
      return await _consent.canRequestAds();
    } catch (e) {
      debugPrint('AdConsentManager: canRequestAds failed ($e); not requesting ads.');
      return false;
    }
  }

  /// Whether Google requires an in-app "privacy choices" entry point for
  /// this user (true for users in regions where UMP shows a form).
  Future<bool> isPrivacyOptionsRequired() async {
    try {
      return await _consent.getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  /// Opens Google's privacy-options form. Returns once it is dismissed.
  Future<void> showPrivacyOptions() async {
    final done = Completer<void>();
    try {
      unawaited(_showPrivacyForm((FormError? error) {
        if (error != null) {
          debugPrint('AdConsentManager: privacy options form error: ${error.message}');
        }
        if (!done.isCompleted) done.complete();
      }).catchError((Object e) {
        debugPrint('AdConsentManager: privacy options form threw: $e');
        if (!done.isCompleted) done.complete();
      }));
    } catch (_) {
      return;
    }
    await done.future;
  }
}
