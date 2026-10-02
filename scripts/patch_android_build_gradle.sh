#!/usr/bin/env bash
# Enables Android core library desugaring in android/app/build.gradle.kts,
# required by flutter_local_notifications (confirmed via the package's own
# example project). Same gitignore/`flutter create`-regeneration problem
# class as the manifest permissions -- see patch_android_manifest.sh's
# header comment for the full explanation of why this script exists.
#
# Run this after every `flutter create --platforms=android .` -- CI does
# this automatically (see .github/workflows/ci.yml); after a fresh clone
# or deleting android/ locally, run it yourself alongside
# patch_android_manifest.sh.
set -euo pipefail

GRADLE_FILE="android/app/build.gradle.kts"

if [ ! -f "$GRADLE_FILE" ]; then
  echo "$GRADLE_FILE not found -- run 'flutter create --platforms=android .' first" >&2
  exit 1
fi

if grep -q "isCoreLibraryDesugaringEnabled" "$GRADLE_FILE"; then
  echo "Core library desugaring already enabled -- nothing to do."
else
  # Enable desugaring inside the existing compileOptions block.
  sed -i '/targetCompatibility = JavaVersion.VERSION_17/a\        isCoreLibraryDesugaringEnabled = true' "$GRADLE_FILE"

  # Add the desugaring dependency as its own top-level block (version pinned
  # to what flutter_local_notifications' own example project uses).
  cat >> "$GRADLE_FILE" <<'EOF'

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
EOF

  echo "Core library desugaring enabled in $GRADLE_FILE"
fi

# Work around a real, reproducible Kotlin/Gradle build-tools-api bug hit on
# this project's Windows dev machine: every Kotlin-compiling plugin module
# (posthog_flutter, url_launcher_android, image_picker_android,
# shared_preferences_android, package_info_plus, ...) failed
# `compileDebugKotlin` with "Could not close incremental caches" -- the
# compiler's own incremental cache `.tab` files get locked (most likely by
# antivirus real-time scanning) right as Kotlin tries to close/rename them
# after a successful compile. Disabling Kotlin's incremental compilation
# avoids that close-and-rename step entirely; it only costs some build
# speed, never correctness. gradle.properties lives under the gitignored
# android/ directory, so this needs the same patch-script treatment.
PROPERTIES_FILE="android/gradle.properties"
if [ -f "$PROPERTIES_FILE" ] && ! grep -q "kotlin.incremental" "$PROPERTIES_FILE"; then
  echo "kotlin.incremental=false" >> "$PROPERTIES_FILE"
  echo "Disabled Kotlin incremental compilation in $PROPERTIES_FILE"
fi

# Disable R8 minification for release builds -- confirmed via a real device
# crash (adb logcat, 2026-10-02) that the stock `flutter create` release
# build type runs R8 with zero custom keep rules (no proguard-rules.pro has
# ever existed in this project), which stripped something `androidx.work`'s
# auto-initializing Room database needs via reflection and crashed the app
# on launch before any Dart code runs -- see HWC_REPORT.md's crash-fix
# entry for the full stack trace. This app also has no production signing
# config yet (still signs release with debug keys), so minification was
# never a deliberate, hardened choice to begin with.
if grep -q "isMinifyEnabled = false" "$GRADLE_FILE"; then
  echo "R8 minification already disabled for release -- nothing to do."
else
  sed -i '/signingConfig = signingConfigs.getByName("debug")/a\            isMinifyEnabled = false\n            isShrinkResources = false' "$GRADLE_FILE"
  echo "Disabled R8 minification/resource shrinking for release in $GRADLE_FILE"
fi
