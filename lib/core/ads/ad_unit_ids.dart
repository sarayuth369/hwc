import 'package:flutter/foundation.dart';

/// AdMob ad unit IDs, chosen by **build mode** -- never by a flag someone
/// has to remember to pass:
///
/// - Release builds always use HWC's production units.
/// - Debug/profile builds always use Google's published test units, so
///   development, emulators and automated runs can never generate real
///   impressions/clicks on the production units (an account-suspension
///   risk Google explicitly warns about).
///
/// These are identifiers, not credentials -- Google documents them as safe
/// to ship in the app binary. The Android *App ID*
/// (`ca-app-pub-...~...`) is not here: it lives in AndroidManifest.xml and
/// is applied by `scripts/patch_android_manifest.sh`. A production App ID
/// combined with test *ad unit* IDs is the combination Google recommends
/// for testing, so the manifest can safely use the production App ID in
/// every build type.
class AdUnitIds {
  const AdUnitIds({required this.banner, required this.appOpen});

  final String banner;
  final String appOpen;

  /// HWC's production AdMob app (App ID `ca-app-pub-1918372113970166~1511164770`).
  static const production = AdUnitIds(
    banner: 'ca-app-pub-1918372113970166/3515170725',
    appOpen: 'ca-app-pub-1918372113970166/6735482007',
  );

  /// Google's own public test units (Android banner / app open).
  static const test = AdUnitIds(
    banner: 'ca-app-pub-3940256099942544/6300978111',
    appOpen: 'ca-app-pub-3940256099942544/9257395921',
  );

  static AdUnitIds forMode({required bool isRelease}) => isRelease ? production : test;

  /// The IDs for the running build.
  static AdUnitIds get current => forMode(isRelease: kReleaseMode);

  /// False in every debug/profile build -- lets the UI/logs say honestly
  /// that the ads on screen are Google test creatives.
  static bool get isUsingProductionUnits => kReleaseMode;
}
