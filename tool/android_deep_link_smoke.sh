#!/usr/bin/env bash
set -euo pipefail

PACKAGE="${FANZONE_ANDROID_PACKAGE:-app.fanzone.football}"
LOG_DIR="${FANZONE_DEEPLINK_SMOKE_LOG_DIR:-output/release-evidence/android-deep-link-smoke}"
TIMESTAMP="$(date -u +"%Y%m%dT%H%M%SZ")"
LOG_PATH="${FANZONE_DEEPLINK_SMOKE_LOG:-${LOG_DIR}/${TIMESTAMP}.log}"
RELEASE_MODE="${FANZONE_DEEPLINK_SMOKE_RELEASE:-0}"

mkdir -p "${LOG_DIR}"
exec > >(tee "${LOG_PATH}") 2>&1

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

run_adb() {
  adb "$@"
}

shell_quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

require_command adb
require_command flutter

echo "FANZONE Android deep-link smoke"
echo "Timestamp UTC: ${TIMESTAMP}"
echo "Package: ${PACKAGE}"
echo "Log: ${LOG_PATH}"
echo "Release mode: ${RELEASE_MODE}"
echo ""

if [[ "${RELEASE_MODE}" == "1" ]]; then
  REQUIRED_VARS=(
    FANZONE_SMOKE_VENUE_ID
    FANZONE_SMOKE_VENUE_SLUG
    FANZONE_SMOKE_POOL_ID
    FANZONE_SMOKE_POOL_SHARE_SLUG
    FANZONE_SMOKE_INVITE_CODE
    FANZONE_SMOKE_CAMP_ID
  )
  for var_name in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var_name:-}" ]]; then
      fail "Release-mode deep-link smoke requires ${var_name}"
    fi
  done
else
  echo "Probe mode uses synthetic route identifiers and is not final release evidence."
  echo "Set FANZONE_DEEPLINK_SMOKE_RELEASE=1 with real FANZONE_SMOKE_* values for release evidence."
fi

VENUE_ID="${FANZONE_SMOKE_VENUE_ID:-venue_smoke}"
VENUE_SLUG="${FANZONE_SMOKE_VENUE_SLUG:-stadium-sports-bar}"
POOL_ID="${FANZONE_SMOKE_POOL_ID:-pool_smoke}"
POOL_SHARE_SLUG="${FANZONE_SMOKE_POOL_SHARE_SLUG:-share_smoke}"
INVITE_CODE="${FANZONE_SMOKE_INVITE_CODE:-android-smoke}"
CAMP_ID="${FANZONE_SMOKE_CAMP_ID:-camp_smoke}"

echo "== Device =="
run_adb devices
DEVICE_COUNT="$(run_adb devices | awk 'NR > 1 && $2 == "device" { count++ } END { print count + 0 }')"
if [[ "${DEVICE_COUNT}" -ne 1 ]]; then
  fail "Expected exactly one connected adb device, found ${DEVICE_COUNT}"
fi

echo ""
echo "== Installed package =="
run_adb shell pm path "${PACKAGE}" >/dev/null || fail "${PACKAGE} is not installed on the connected device"
run_adb shell pm path "${PACKAGE}"

echo ""
echo "== Domain verification =="
APP_LINKS="$(run_adb shell pm get-app-links "${PACKAGE}")"
printf '%s\n' "${APP_LINKS}"
grep -q 'fanzone.ikanisa.com: verified' <<<"${APP_LINKS}" ||
  fail "fanzone.ikanisa.com is not verified for ${PACKAGE}"
grep -q 'fanzone.guest.ikanisa.com: verified' <<<"${APP_LINKS}" ||
  fail "fanzone.guest.ikanisa.com is not verified for ${PACKAGE}"

if [[ "${FANZONE_DEEPLINK_SMOKE_SKIP_FLUTTER_TESTS:-0}" != "1" ]]; then
  echo ""
  echo "== Flutter route normalization tests =="
  flutter test test/app_router_test.dart --plain-name governedAppRouteForPath
fi

declare -a URIS=(
  "https://fanzone.guest.ikanisa.com/venues"
  "https://fanzone.ikanisa.com/venues"
  "https://fanzone.app/venues"
  "fanzone://venues"
  "https://fanzone.guest.ikanisa.com/home"
  "https://fanzone.ikanisa.com/home/matches"
  "https://fanzone.app/home/matches"
  "fanzone://home/matches"
  "https://fanzone.guest.ikanisa.com/v/${VENUE_SLUG}?source=android-smoke"
  "https://fanzone.ikanisa.com/v/${VENUE_SLUG}?source=android-smoke"
  "https://fanzone.app/v/${VENUE_SLUG}?source=android-smoke"
  "fanzone://v/${VENUE_SLUG}?source=android-smoke"
  "https://fanzone.guest.ikanisa.com/bar?v=${VENUE_ID}&source=android-smoke"
  "https://fanzone.ikanisa.com/bar?v=${VENUE_ID}&source=android-smoke"
  "fanzone://bar?v=${VENUE_ID}&source=android-smoke"
  "https://fanzone.guest.ikanisa.com/predict/${POOL_SHARE_SLUG}?invite=${INVITE_CODE}"
  "https://fanzone.guest.ikanisa.com/pools/${POOL_SHARE_SLUG}?invite=${INVITE_CODE}&source=android-smoke"
  "https://fanzone.ikanisa.com/pools/${POOL_SHARE_SLUG}?invite=${INVITE_CODE}&source=android-smoke"
  "https://fanzone.guest.ikanisa.com/pool/${POOL_ID}/join?invite=${INVITE_CODE}&camp=${CAMP_ID}&source=android-smoke"
  "https://fanzone.ikanisa.com/pool/${POOL_ID}/join?invite=${INVITE_CODE}&camp=${CAMP_ID}&source=android-smoke"
  "fanzone://predict/${POOL_SHARE_SLUG}?invite=${INVITE_CODE}"
  "fanzone://pools/${POOL_SHARE_SLUG}?invite=${INVITE_CODE}"
)

echo ""
echo "== Device intent smoke =="
for uri in "${URIS[@]}"; do
  echo "-- ${uri}"
  PACKAGE_ARG="$(shell_quote "${PACKAGE}")"
  URI_ARG="$(shell_quote "${uri}")"
  START_OUTPUT="$(
    run_adb shell \
      "am start -W -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d ${URI_ARG} -p ${PACKAGE_ARG}" 2>&1
  )"
  printf '%s\n' "${START_OUTPUT}"
  grep -Eq "Status: ok|Warning: Activity not started" <<<"${START_OUTPUT}" ||
    fail "Deep link did not start cleanly: ${uri}"
  grep -q "${PACKAGE}" <<<"${START_OUTPUT}" ||
    fail "Deep link was not handled by ${PACKAGE}: ${uri}"

  sleep 2
  FOCUS_OUTPUT="$(run_adb shell dumpsys window | grep -E 'mCurrentFocus|mFocusedApp' || true)"
  printf '%s\n' "${FOCUS_OUTPUT}"
  grep -q "${PACKAGE}" <<<"${FOCUS_OUTPUT}" ||
    fail "${PACKAGE} was not focused after deep link: ${uri}"
done

echo ""
echo "Android deep-link smoke passed."
