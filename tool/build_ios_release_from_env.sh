#!/usr/bin/env bash
set -euo pipefail

APP_ENVIRONMENT="${1:-staging}"
shift || true

DART_DEFINE_FILE="$(./tool/resolve_dart_define_file.sh "${APP_ENVIRONMENT}")"
APP_CONFIG_FILE="ios/Flutter/AppConfig.xcconfig"
GOOGLE_SERVICE_INFO_PLIST="ios/Runner/GoogleService-Info.plist"

if [[ ! -f "${APP_CONFIG_FILE}" ]]; then
  echo "Missing ${APP_CONFIG_FILE}. Create it from ios/Flutter/AppConfig.xcconfig.example."
  exit 1
fi

if [[ ! -f "${GOOGLE_SERVICE_INFO_PLIST}" ]]; then
  echo "Missing ${GOOGLE_SERVICE_INFO_PLIST}. Add the production Firebase plist before building iOS."
  exit 1
fi

TEAM_ID="$(awk -F '=' '/FANZONE_DEVELOPMENT_TEAM/ {gsub(/[[:space:]]/, "", $2); print $2}' "${APP_CONFIG_FILE}" | tail -n1)"
BUNDLE_ID="$(awk -F '=' '/FANZONE_APP_BUNDLE_IDENTIFIER/ {gsub(/[[:space:]]/, "", $2); print $2}' "${APP_CONFIG_FILE}" | tail -n1)"
APS_ENVIRONMENT="$(awk -F '=' '/FANZONE_APS_ENVIRONMENT/ {gsub(/[[:space:]]/, "", $2); print $2}' "${APP_CONFIG_FILE}" | tail -n1)"

if [[ -z "${TEAM_ID}" || "${TEAM_ID}" == 'YOUR_TEAM_ID' || "${TEAM_ID}" == *'$('* ]]; then
  echo "FANZONE_DEVELOPMENT_TEAM is not set to a real Apple Team ID in ${APP_CONFIG_FILE}."
  exit 1
fi

if [[ -z "${BUNDLE_ID}" || "${BUNDLE_ID}" == 'com.yourcompany.fanzone' || "${BUNDLE_ID}" == *'$('* ]]; then
  echo "FANZONE_APP_BUNDLE_IDENTIFIER is not set to a production bundle identifier in ${APP_CONFIG_FILE}."
  exit 1
fi

if [[ "${APS_ENVIRONMENT}" != "development" && "${APS_ENVIRONMENT}" != "production" ]]; then
  echo "FANZONE_APS_ENVIRONMENT must be set to development or production in ${APP_CONFIG_FILE}."
  exit 1
fi

echo "Building iOS release for ${APP_ENVIRONMENT} using ${DART_DEFINE_FILE}"

flutter build ios --release --no-codesign \
  --dart-define-from-file="${DART_DEFINE_FILE}" \
  "$@"
