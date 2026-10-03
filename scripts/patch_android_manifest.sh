#!/usr/bin/env bash
# Re-applies HWC's Android manifest customizations after `flutter create`
# regenerates android/ (which is gitignored -- see .gitignore -- to keep
# Gradle wrapper/binary bloat out of version control). Without this, a
# fresh clone or CI run produces a stock manifest missing permissions this
# app actually needs (camera for the Food Scanner, notifications for
# reminders), and features that depend on them fail at runtime -- and the
# installed app would show the default `flutter create` label instead of
# HWC's real name.
#
# Run this after every `flutter create --platforms=android .` -- CI does
# this automatically (see .github/workflows/ci.yml); after a fresh clone
# or deleting android/ locally, run it yourself:
#   flutter create --platforms=android --org com.bkknex .
#   ./scripts/patch_android_manifest.sh
set -euo pipefail

MANIFEST="android/app/src/main/AndroidManifest.xml"

if [ ! -f "$MANIFEST" ]; then
  echo "$MANIFEST not found -- run 'flutter create --platforms=android .' first" >&2
  exit 1
fi

changed=0

if ! grep -q 'android.permission.CAMERA' "$MANIFEST"; then
  sed -i '/<manifest /a\
    <!-- Required by image_picker for the Food Scanner and Health Report Reader camera flows. -->\
    <uses-permission android:name="android.permission.CAMERA"/>\
    <uses-feature android:name="android.hardware.camera" android:required="false"/>' "$MANIFEST"
  changed=1
fi

if ! grep -q 'android.permission.POST_NOTIFICATIONS' "$MANIFEST"; then
  sed -i '/<manifest /a\
    <!-- Required (Android 13+) by flutter_local_notifications for wellness reminders. -->\
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>' "$MANIFEST"
  changed=1
fi

if ! grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  sed -i '/<manifest /a\
    <!-- Flutter only injects INTERNET into the debug/profile manifests; a release/Play build needs it declared in main for Supabase, the Worker, AdMob and FCM. -->\
    <uses-permission android:name="android.permission.INTERNET"/>' "$MANIFEST"
  changed=1
fi

if ! grep -q 'android.permission.RECORD_AUDIO' "$MANIFEST"; then
  sed -i '/<manifest /a\
    <!-- Required by speech_to_text for real on-device voice input in AI Talk. -->\
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>' "$MANIFEST"
  changed=1
fi

APP_LABEL="Health-Wellness-Companion"
if ! grep -q "android:label=\"$APP_LABEL\"" "$MANIFEST"; then
  sed -i "s/android:label=\"[^\"]*\"/android:label=\"$APP_LABEL\"/" "$MANIFEST"
  changed=1
fi

# HWC's production AdMob App ID (an identifier, not a credential -- it ships
# in every APK). google_mobile_ads crashes at MobileAds.instance.initialize()
# without this meta-data, so it is not optional. It is the same in every
# build type on purpose: Google recommends testing with the *production App
# ID + Google's test ad UNIT IDs*, and lib/core/ads/ad_unit_ids.dart
# selects test units for debug/profile and production units for release by
# build mode, so debug builds can never serve or click production ads.
ADMOB_APP_ID="ca-app-pub-1918372113970166~1511164770"

if ! grep -q 'com.google.android.gms.ads.APPLICATION_ID' "$MANIFEST"; then
  # Inserted after the line that closes the multi-line <application ...>
  # opening tag (android:icon=...">), not after the bare "<application"
  # substring -- that would land the meta-data inside the tag's own
  # attribute list, which is invalid XML.
  sed -i "/android:icon=\"@mipmap\/ic_launcher\">/a\\
        <meta-data android:name=\"com.google.android.gms.ads.APPLICATION_ID\" android:value=\"$ADMOB_APP_ID\"/>" "$MANIFEST"
  changed=1
elif ! grep -q "android:value=\"$ADMOB_APP_ID\"" "$MANIFEST"; then
  # Already present with a different value (e.g. the old Google test App
  # ID from before production IDs existed) -- replace it in place. Skipping
  # here is how a stale test ID would survive in a long-lived local android/.
  sed -i "s|\(com.google.android.gms.ads.APPLICATION_ID\" android:value=\"\)[^\"]*\"|\1$ADMOB_APP_ID\"|" "$MANIFEST"
  changed=1
fi

# Must stay byte-identical to Env.authRedirectUrl's scheme/host (see
# lib/core/config/env.dart). Deliberately NOT the app's applicationId
# (com.bkknex.bkknex_health_app) -- that string's underscores are illegal
# in a URI scheme per RFC 3986, which made Supabase's GoTrue backend
# silently reject the redirect_to allow-list match and fall back to Site
# URL. Hyphens are valid scheme characters and Android's manifest scheme
# matching is a plain string, so it doesn't need to match applicationId.
DEEPLINK_SCHEME="com.bkknex.bkknex-health-app"

if ! grep -q 'login-callback' "$MANIFEST"; then
  # Deep link for Supabase Auth email confirmation / password reset --
  # see Env.authRedirectUrl. Inserted after MainActivity's existing
  # MAIN/LAUNCHER intent-filter, still inside the same <activity> block.
  sed -i '/<category android:name="android.intent.category.LAUNCHER"\/>/,/<\/intent-filter>/{
    /<\/intent-filter>/a\
            <intent-filter android:autoVerify="false">\
                <action android:name="android.intent.action.VIEW"/>\
                <category android:name="android.intent.category.DEFAULT"/>\
                <category android:name="android.intent.category.BROWSABLE"/>\
                <data android:scheme="'"$DEEPLINK_SCHEME"'" android:host="login-callback"/>\
            </intent-filter>
  }' "$MANIFEST"
  changed=1
fi

# FCM: tell Firebase which notification channel to use for pushes it displays
# while the app is in the background/terminated. The channel itself is created
# (importance high) at app start by lib/data/push/local_push_presenter.dart;
# this id must match PUSH_CHANNEL_ID there and ANDROID_CHANNEL_ID in the
# Worker's src/push/fcm.ts. Harmless when Firebase isn't configured.
if ! grep -q 'com.google.firebase.messaging.default_notification_channel_id' "$MANIFEST"; then
  sed -i "/android:icon=\"@mipmap\/ic_launcher\">/a\\
        <meta-data android:name=\"com.google.firebase.messaging.default_notification_channel_id\" android:value=\"hwc_push\"/>" "$MANIFEST"
  changed=1
fi

if [ "$changed" -eq 1 ]; then
  echo "Manifest permissions patched: $MANIFEST"
else
  echo "Manifest permissions already present -- nothing to do."
fi
