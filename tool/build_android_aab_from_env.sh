#!/usr/bin/env bash
# Build a signed Android App Bundle (AAB) for Google Play submission.
# Usage: ./tool/build_android_aab_from_env.sh <staging|production>
set -euo pipefail

APP_ENVIRONMENT="${1:-staging}"
shift || true

DART_DEFINE_FILE="$(./tool/resolve_dart_define_file.sh "${APP_ENVIRONMENT}")"

echo "Building AAB for environment: ${APP_ENVIRONMENT}"
echo "──────────────────────────────────────────────────"

flutter build appbundle --release \
  --dart-define-from-file="${DART_DEFINE_FILE}" \
  "$@"

AAB_PATH="build/app/outputs/bundle/release/app-release.aab"
if [[ -f "$AAB_PATH" ]]; then
  SIZE=$(du -h "$AAB_PATH" | cut -f1)
  echo ""
  echo "✅ AAB built successfully: $AAB_PATH ($SIZE)"
  echo "Upload this file to Google Play Console → Internal Testing track."
else
  echo "❌ AAB not found at expected path."
  exit 1
fi
