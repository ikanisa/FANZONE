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

BUNDLE_ID="$(awk -F '=' '/FANZONE_APP_BUNDLE_IDENTIFIER/ {gsub(/[[:space:]]/, "", $2); print $2}' "${APP_CONFIG_FILE}" | tail -n1)"
APS_ENVIRONMENT="$(awk -F '=' '/FANZONE_APS_ENVIRONMENT/ {gsub(/[[:space:]]/, "", $2); print $2}' "${APP_CONFIG_FILE}" | tail -n1)"
TEAM_ID="$(awk -F '=' '/FANZONE_DEVELOPMENT_TEAM/ {gsub(/[[:space:]]/, "", $2); print $2}' "${APP_CONFIG_FILE}" | tail -n1)"

if [[ -z "${BUNDLE_ID}" || "${BUNDLE_ID}" == 'com.yourcompany.fanzone' || "${BUNDLE_ID}" == *'$('* ]]; then
  echo "FANZONE_APP_BUNDLE_IDENTIFIER is not set to a production bundle identifier in ${APP_CONFIG_FILE}."
  exit 1
fi

if [[ "${APS_ENVIRONMENT}" != "development" && "${APS_ENVIRONMENT}" != "production" ]]; then
  echo "FANZONE_APS_ENVIRONMENT must be set to development or production in ${APP_CONFIG_FILE}."
  exit 1
fi

HAS_SIGNING_TEAM=1
ALLOW_PROVISIONING_UPDATES="${FANZONE_IOS_ALLOW_PROVISIONING_UPDATES:-1}"
FORCE_UNSIGNED="${FANZONE_IOS_FORCE_UNSIGNED:-0}"
if [[ -z "${TEAM_ID}" || "${TEAM_ID}" == 'YOUR_TEAM_ID' || "${TEAM_ID}" == *'$('* ]]; then
  HAS_SIGNING_TEAM=0
  echo "Warning: FANZONE_DEVELOPMENT_TEAM is not set to a real Apple Team ID in ${APP_CONFIG_FILE}."
  echo "Proceeding with an unsigned archive only. App Store signing/upload remains blocked until this is configured."
elif [[ "${FORCE_UNSIGNED}" == "1" ]]; then
  HAS_SIGNING_TEAM=0
  echo "FANZONE_IOS_FORCE_UNSIGNED=1 set. Building an unsigned archive without IPA export."
fi

echo "Building iOS release for ${APP_ENVIRONMENT} using ${DART_DEFINE_FILE}"

ARCHIVE_PATH="build/ios/archive/Runner.xcarchive"

DART_DEFINES="$(
  python3 - "${DART_DEFINE_FILE}" <<'PY'
import base64
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)

def encode_value(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)

print(
    ",".join(
        base64.b64encode(
            f"{key}={encode_value(value)}".encode("utf-8")
        ).decode("utf-8")
        for key, value in data.items()
    )
)
PY
)"

rm -rf "${ARCHIVE_PATH}"

XCODEBUILD_SIGNING_ARGS=()
if [[ "${HAS_SIGNING_TEAM}" -eq 1 ]]; then
  XCODEBUILD_SIGNING_ARGS+=(
    "DEVELOPMENT_TEAM=${TEAM_ID}"
    "PRODUCT_BUNDLE_IDENTIFIER=${BUNDLE_ID}"
  )
  if [[ "${ALLOW_PROVISIONING_UPDATES}" == "1" ]]; then
    XCODEBUILD_SIGNING_ARGS+=(-allowProvisioningUpdates)
  fi
else
  XCODEBUILD_SIGNING_ARGS+=(
    CODE_SIGNING_ALLOWED=NO
    CODE_SIGNING_REQUIRED=NO
    CODE_SIGN_IDENTITY=""
  )
fi

xcodebuild \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  DART_DEFINES="${DART_DEFINES}" \
  "${XCODEBUILD_SIGNING_ARGS[@]}" \
  archive \
  -archivePath "${ARCHIVE_PATH}" \
  "$@"

if [[ "${HAS_SIGNING_TEAM}" -eq 1 && "${FANZONE_IOS_SKIP_EXPORT:-0}" != "1" ]]; then
  EXPORT_PATH="build/ios/ipa"
  EXPORT_OPTIONS_PLIST="$(mktemp "${TMPDIR:-/tmp}/fanzone-export-options.XXXXXX.plist")"
  EXPORT_METHOD="${FANZONE_IOS_EXPORT_METHOD:-app-store-connect}"

  rm -rf "${EXPORT_PATH}"
  cat > "${EXPORT_OPTIONS_PLIST}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
  <key>method</key>
  <string>${EXPORT_METHOD}</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
</dict>
</plist>
PLIST

  XCODEBUILD_EXPORT_ARGS=()
  if [[ "${ALLOW_PROVISIONING_UPDATES}" == "1" ]]; then
    XCODEBUILD_EXPORT_ARGS+=(-allowProvisioningUpdates)
  fi

  xcodebuild \
    -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_PATH}" \
    -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}" \
    "${XCODEBUILD_EXPORT_ARGS[@]}"

  rm -f "${EXPORT_OPTIONS_PLIST}"
  echo "Exported iOS IPA to ${EXPORT_PATH}"
fi
