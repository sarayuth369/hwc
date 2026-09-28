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

APP_LABEL="Health-Wellness-Companion"
if ! grep -q "android:label=\"$APP_LABEL\"" "$MANIFEST"; then
  sed -i "s/android:label=\"[^\"]*\"/android:label=\"$APP_LABEL\"/" "$MANIFEST"
  changed=1
fi

if [ "$changed" -eq 1 ]; then
  echo "Manifest permissions patched: $MANIFEST"
else
  echo "Manifest permissions already present -- nothing to do."
fi
