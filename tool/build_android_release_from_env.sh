#!/usr/bin/env bash
set -euo pipefail

APP_ENVIRONMENT="${1:-staging}"
shift || true

DART_DEFINE_FILE="$(./tool/resolve_dart_define_file.sh "${APP_ENVIRONMENT}")"
PUBSPEC_VERSION="$(awk -F': ' '/^version: /{print $2; exit}' pubspec.yaml)"
BUILD_NAME="${PUBSPEC_VERSION%%+*}"
BUILD_NUMBER="${PUBSPEC_VERSION#*+}"

BUILD_ARGS=(
  --dart-define-from-file="${DART_DEFINE_FILE}"
  --dart-define=APP_VERSION="${BUILD_NAME}"
  --build-name="${BUILD_NAME}"
)

if [[ "${BUILD_NUMBER}" != "${PUBSPEC_VERSION}" ]]; then
  BUILD_ARGS+=(--build-number="${BUILD_NUMBER}")
fi

echo "Building Android APK for ${APP_ENVIRONMENT} using ${DART_DEFINE_FILE}"

flutter build apk --release \
  "${BUILD_ARGS[@]}" \
  "$@"

# Flutter currently leaves the app-level GeneratedPluginRegistrant.java in a
# dev-plugin state after the build on this toolchain. Sanitize it post-build so
# the workspace stays production-safe for the next release invocation.
(
  cd android
  ./gradlew :app:sanitizeReleaseGeneratedPluginRegistrant >/dev/null
)
