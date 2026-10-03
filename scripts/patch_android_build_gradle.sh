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

# Firebase (FCM push): apply the Google Services Gradle plugin ONLY when
# android/app/google-services.json exists. That file is per-developer local
# configuration (android/ is gitignored and the file is never committed), so
# CI and fresh clones don't have it -- an unconditional plugin would fail
# their builds. Without it the app still builds and runs; Firebase simply
# fails to initialize at runtime and push is disabled (see
# lib/data/push/firebase_fcm_gateway.dart), never a crash.
SETTINGS_FILE="android/settings.gradle.kts"
if [ -f "$SETTINGS_FILE" ] && ! grep -q "com.google.gms.google-services" "$SETTINGS_FILE"; then
  sed -i '/id("org.jetbrains.kotlin.android")/a\    id("com.google.gms.google-services") version "4.4.4" apply false' "$SETTINGS_FILE"
  echo "Declared com.google.gms.google-services plugin in $SETTINGS_FILE"
fi

if ! grep -q "com.google.gms.google-services" "$GRADLE_FILE"; then
  sed -i '/^android {/i\
// Apply only when the local Firebase config exists (see\
// scripts/patch_android_build_gradle.sh).\
if (file("google-services.json").exists()) {\
    apply(plugin = "com.google.gms.google-services")\
}\
' "$GRADLE_FILE"
  echo "Conditionally applied google-services plugin in $GRADLE_FILE"
fi

# ---------------------------------------------------------------------------
# Release signing (Google Play upload key).
#
# `flutter create` ships the release build type signed with the DEBUG key,
# which Google Play rejects. This wires a real release signing config that
# reads android/key.properties (gitignored -- never committed), e.g.:
#
#   storeFile=D:/path/to/hwc-upload.jks     (absolute, or relative to android/)
#   storePassword=...
#   keyAlias=...
#   keyPassword=...
#
# With key.properties present, release builds are signed with that key. With
# it absent, plain `flutter run --release` / CI still work (debug signing),
# but `bundleRelease` (the Play bundle) FAILS with an explanatory error, so a
# debug-signed bundle can never be produced by accident. A debug-signed
# bundle for pure pipeline verification must be requested explicitly with
# the environment variable ORG_GRADLE_PROJECT_allowDebugSignedBundle=true.
# ---------------------------------------------------------------------------
if ! grep -q "keystorePropertiesFile" "$GRADLE_FILE"; then
  SIGNING_TOP=$(mktemp)
  SIGNING_BLOCK=$(mktemp)
  cat > "$SIGNING_TOP" <<'KT'
// Release signing (see scripts/patch_android_build_gradle.sh). key.properties
// is local-only and gitignored.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

gradle.taskGraph.whenReady {
    val buildingPlayBundle = allTasks.any { it.name.contains("bundleRelease", ignoreCase = true) }
    if (buildingPlayBundle &&
        !keystorePropertiesFile.exists() &&
        System.getenv("ORG_GRADLE_PROJECT_allowDebugSignedBundle") != "true"
    ) {
        throw GradleException(
            "Refusing to build a Play bundle: android/key.properties (the upload key " +
                "configuration) is missing, so the release would be signed with the DEBUG " +
                "key, which Google Play rejects. Create the upload keystore and key.properties " +
                "first (see HWC_REPORT.md)."
        )
    }
}

KT
  cat > "$SIGNING_BLOCK" <<'KT'
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

KT
  awk -v f="$SIGNING_TOP" '/^android \{/ && !d { while ((getline l < f) > 0) print l; d=1 } { print }' "$GRADLE_FILE" > "$GRADLE_FILE.tmp" && mv "$GRADLE_FILE.tmp" "$GRADLE_FILE"
  awk -v f="$SIGNING_BLOCK" '/^    buildTypes \{/ && !d { while ((getline l < f) > 0) print l; d=1 } { print }' "$GRADLE_FILE" > "$GRADLE_FILE.tmp" && mv "$GRADLE_FILE.tmp" "$GRADLE_FILE"
  rm -f "$SIGNING_TOP" "$SIGNING_BLOCK"
  sed -i 's|signingConfig = signingConfigs.getByName("debug")|signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")|' "$GRADLE_FILE"
  # Imports must be the first statements in a .kts script.
  { printf 'import java.io.FileInputStream
import java.util.Properties

'; cat "$GRADLE_FILE"; } > "$GRADLE_FILE.tmp" && mv "$GRADLE_FILE.tmp" "$GRADLE_FILE"
  echo "Release signing wired in $GRADLE_FILE"
fi
