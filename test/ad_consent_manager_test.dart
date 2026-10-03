import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:bkknex_health_app/data/ads/ad_consent_manager.dart';

class _FakeConsentInformation implements ConsentInformation {
  bool canRequest = true;
  bool updateFails = false;
  bool updateNeverReturns = false;
  bool canRequestThrows = false;
  PrivacyOptionsRequirementStatus privacyStatus = PrivacyOptionsRequirementStatus.notRequired;
  int updateCalls = 0;

  @override
  void requestConsentInfoUpdate(
    ConsentRequestParameters params,
    OnConsentInfoUpdateSuccessListener successListener,
    OnConsentInfoUpdateFailureListener failureListener,
  ) {
    updateCalls++;
    if (updateNeverReturns) return;
    if (updateFails) {
      failureListener(FormError(errorCode: 3, message: 'network'));
    } else {
      successListener();
    }
  }

  @override
  Future<bool> canRequestAds() async {
    if (canRequestThrows) throw Exception('channel unavailable');
    return canRequest;
  }

  @override
  Future<PrivacyOptionsRequirementStatus> getPrivacyOptionsRequirementStatus() async => privacyStatus;

  @override
  Future<bool> isConsentFormAvailable() async => true;

  @override
  Future<ConsentStatus> getConsentStatus() async => ConsentStatus.unknown;

  @override
  Future<void> reset() async {}
}

void main() {
  late _FakeConsentInformation info;
  late int formShown;
  late int privacyFormShown;

  AdConsentManager manager({
    Future<void> Function(OnConsentFormDismissedListener)? showForm,
    Duration timeout = const Duration(seconds: 1),
  }) {
    return AdConsentManager(
      consentInformation: info,
      showFormIfRequired: showForm ??
          (done) async {
            formShown++;
            done(null);
          },
      showPrivacyForm: (done) async {
        privacyFormShown++;
        done(null);
      },
      infoUpdateTimeout: timeout,
    );
  }

  setUp(() {
    info = _FakeConsentInformation();
    formShown = 0;
    privacyFormShown = 0;
  });

  test('updates consent info, shows the form if required, then reports canRequestAds', () async {
    info.canRequest = true;
    expect(await manager().gatherConsentAndCheckCanRequestAds(), isTrue);
    expect(info.updateCalls, 1);
    expect(formShown, 1);
  });

  test('when consent does not allow ads, ads are not requested', () async {
    info.canRequest = false;
    expect(await manager().gatherConsentAndCheckCanRequestAds(), isFalse);
  });

  test('a failed consent-info update still falls back to the cached consent state (no crash)', () async {
    info
      ..updateFails = true
      ..canRequest = true;
    expect(await manager().gatherConsentAndCheckCanRequestAds(), isTrue);
  });

  test('a consent-info update that never answers times out instead of hanging ads forever', () async {
    info
      ..updateNeverReturns = true
      ..canRequest = true;
    final result = await manager(timeout: const Duration(milliseconds: 50))
        .gatherConsentAndCheckCanRequestAds();
    expect(result, isTrue);
  });

  test('a consent form that throws does not crash the flow', () async {
    info.canRequest = false;
    final result = await manager(showForm: (done) async => throw Exception('no activity'))
        .gatherConsentAndCheckCanRequestAds();
    expect(result, isFalse);
  });

  test('if even canRequestAds() fails, the answer is "no ads", never an exception', () async {
    info.canRequestThrows = true;
    expect(await manager().gatherConsentAndCheckCanRequestAds(), isFalse);
  });

  test('privacy options entry is reported only when Google requires it', () async {
    info.privacyStatus = PrivacyOptionsRequirementStatus.notRequired;
    expect(await manager().isPrivacyOptionsRequired(), isFalse);
    info.privacyStatus = PrivacyOptionsRequirementStatus.unknown;
    expect(await manager().isPrivacyOptionsRequired(), isFalse);
    info.privacyStatus = PrivacyOptionsRequirementStatus.required;
    expect(await manager().isPrivacyOptionsRequired(), isTrue);
  });

  test('showPrivacyOptions opens the form and returns once dismissed', () async {
    await manager().showPrivacyOptions();
    expect(privacyFormShown, 1);
  });

  test('showPrivacyOptions swallows a form that throws', () async {
    final m = AdConsentManager(
      consentInformation: info,
      showPrivacyForm: (done) async => throw Exception('boom'),
    );
    await m.showPrivacyOptions();
  });
}
