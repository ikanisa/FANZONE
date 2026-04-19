#!/usr/bin/env bash
set -euo pipefail

APP_ENVIRONMENT="${1:-staging}"
shift || true

DART_DEFINE_FILE="$(./tool/resolve_dart_define_file.sh "${APP_ENVIRONMENT}")"

echo "Building Android APK for ${APP_ENVIRONMENT} using ${DART_DEFINE_FILE}"

flutter build apk --release \
  --dart-define-from-file="${DART_DEFINE_FILE}" \
  "$@"
