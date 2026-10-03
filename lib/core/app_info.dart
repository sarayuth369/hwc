/// App version reported to the backend (e.g. with the push token) and shown
/// in Settings -- kept as a plain constant rather than pulling in
/// `package_info_plus` for one string; update alongside `pubspec.yaml`'s
/// `version:` field.
class AppInfo {
  const AppInfo._();

  static const String version = '0.1.0';
}
