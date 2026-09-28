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
  exit 0
fi

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
