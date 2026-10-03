import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bkknex_health_app/core/ads/ad_unit_ids.dart';

const _prodAppId = 'ca-app-pub-1918372113970166~1511164770';
const _prodAppOpen = 'ca-app-pub-1918372113970166/6735482007';
const _prodBanner = 'ca-app-pub-1918372113970166/3515170725';
const _googleTestPublisher = 'ca-app-pub-3940256099942544';

void main() {
  test('release builds use exactly the production ad units', () {
    final ids = AdUnitIds.forMode(isRelease: true);
    expect(ids.banner, _prodBanner);
    expect(ids.appOpen, _prodAppOpen);
  });

  test('debug/profile builds use Google test units, never production ones', () {
    final ids = AdUnitIds.forMode(isRelease: false);
    expect(ids.banner, startsWith(_googleTestPublisher));
    expect(ids.appOpen, startsWith(_googleTestPublisher));
    expect(ids.banner, isNot(_prodBanner));
    expect(ids.appOpen, isNot(_prodAppOpen));
  });

  test('a release build can never carry a Google test ad unit', () {
    final ids = AdUnitIds.forMode(isRelease: true);
    expect(ids.banner.contains(_googleTestPublisher), isFalse);
    expect(ids.appOpen.contains(_googleTestPublisher), isFalse);
  });

  test('this (debug) test run is using test units', () {
    expect(AdUnitIds.current.banner, startsWith(_googleTestPublisher));
    expect(AdUnitIds.isUsingProductionUnits, isFalse);
  });

  // The Android App ID lives in the gitignored, regenerated AndroidManifest,
  // so the committed source of truth is the patch script. Guard it: the
  // production App ID must be there, and the old Google test App ID (which
  // used to ship in every build) must not be.
  test('the manifest patch script carries the production AdMob App ID only', () {
    final script = File('scripts/patch_android_manifest.sh').readAsStringSync();
    expect(script, contains(_prodAppId));
    expect(script, isNot(contains('ca-app-pub-3940256099942544~')));
  });

  test('no stray AdMob IDs other than the production + Google test ones exist in lib/', () {
    final idPattern = RegExp(r'ca-app-pub-\d{16}[~/]\d{10}');
    final allowed = {
      _prodAppId,
      _prodAppOpen,
      _prodBanner,
      '$_googleTestPublisher/6300978111',
      '$_googleTestPublisher/9257395921',
    };
    final found = <String>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        for (final m in idPattern.allMatches(entity.readAsStringSync())) {
          found.add(m.group(0)!);
        }
      }
    }
    expect(found.difference(allowed), isEmpty, reason: 'unexpected AdMob ID in lib/');
  });
}
