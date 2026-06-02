#!/usr/bin/env bash
set -euo pipefail

AAB_PATH="${FANZONE_AAB_PATH:-build/app/outputs/bundle/release/app-release.aab}"
APK_PATH="${FANZONE_APK_PATH:-build/app/outputs/flutter-apk/app-release.apk}"
LOG_DIR="${FANZONE_SIGNATURE_LOG_DIR:-output/release-evidence/android-signature}"
TIMESTAMP="$(date -u +"%Y%m%dT%H%M%SZ")"
LOG_PATH="${FANZONE_SIGNATURE_LOG:-${LOG_DIR}/${TIMESTAMP}.log}"

mkdir -p "${LOG_DIR}"
exec > >(tee "${LOG_PATH}") 2>&1

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

find_apksigner() {
  if command -v apksigner >/dev/null 2>&1; then
    command -v apksigner
    return
  fi

  local sdk_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-${HOME}/Library/Android/sdk}}"
  find -L "${sdk_root}" -path '*/build-tools/*/apksigner' -type f 2>/dev/null |
    sort -V |
    tail -1
}

[[ -f "${AAB_PATH}" ]] || fail "AAB not found: ${AAB_PATH}"
[[ -f "${APK_PATH}" ]] || fail "APK not found: ${APK_PATH}"
command -v jarsigner >/dev/null 2>&1 || fail "jarsigner is not available"

APKSIGNER="$(find_apksigner)"
[[ -n "${APKSIGNER}" && -x "${APKSIGNER}" ]] || fail "apksigner is not available"

echo "FANZONE Android signature verification"
echo "Timestamp UTC: ${TIMESTAMP}"
echo "AAB: ${AAB_PATH}"
echo "APK: ${APK_PATH}"
echo "apksigner: ${APKSIGNER}"
echo "Log: ${LOG_PATH}"
echo ""

echo "== AAB jarsigner verification =="
jarsigner -verify "${AAB_PATH}"

echo ""
echo "== AAB jarsigner strict verification =="
set +e
jarsigner -verify -strict "${AAB_PATH}"
STRICT_EXIT=$?
set -e
echo "strict_exit=${STRICT_EXIT}"
if [[ "${STRICT_EXIT}" -ne 0 && "${STRICT_EXIT}" -ne 4 ]]; then
  fail "Unexpected jarsigner strict exit code: ${STRICT_EXIT}"
fi

echo ""
echo "== APK apksigner verification =="
"${APKSIGNER}" verify --verbose --print-certs "${APK_PATH}"

echo ""
echo "Android signature verification completed."
