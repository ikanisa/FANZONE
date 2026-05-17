#!/usr/bin/env bash
# Static mobile release audit for MASVS-style repo checks.
set -euo pipefail

failures=0

fail() {
  echo "$1" >&2
  failures=$((failures + 1))
}

require_file() {
  local path="$1"
  [[ -f "${path}" ]] || fail "Missing required mobile release file: ${path}"
}

require_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"
  if ! rg -q "${pattern}" "${path}"; then
    fail "${message}"
  fi
}

android_manifest="android/app/src/main/AndroidManifest.xml"
android_gradle="android/app/build.gradle.kts"
ios_info="ios/Runner/Info.plist"
ios_entitlements="ios/Runner/Runner.entitlements"

require_file "${android_manifest}"
require_file "${android_gradle}"
require_file "${ios_info}"
require_file "${ios_entitlements}"
require_file "pubspec.yaml"
require_file "lib/core/storage/secure_auth_session_store.dart"
require_file "lib/core/auth/runtime_auth_session_manager.dart"

tracked_mobile_artifacts="$(
  git ls-files | rg '(^|/)\.DS_Store$|^test/failures/|(^|/)google-services\.json$|(^|/)GoogleService-Info\.plist$|(^|/)AppConfig\.xcconfig$|(^|/)key\.properties$|\.jks$|\.keystore$' || true
)"
if [[ -n "${tracked_mobile_artifacts}" ]]; then
  fail "Generated, local, or signing mobile artifacts are tracked:
${tracked_mobile_artifacts}"
fi

for permission in \
  RECORD_AUDIO \
  CAMERA \
  READ_CONTACTS \
  WRITE_CONTACTS \
  READ_SMS \
  SEND_SMS \
  READ_PHONE_STATE \
  READ_EXTERNAL_STORAGE \
  WRITE_EXTERNAL_STORAGE \
  MANAGE_EXTERNAL_STORAGE; do
  if rg -n "android\.permission\.${permission}" "${android_manifest}" \
    | rg -v 'tools:node="remove"' >/tmp/fanzone-mobile-permission.txt; then
    fail "Unexpected active Android permission android.permission.${permission}:
$(cat /tmp/fanzone-mobile-permission.txt)"
  fi
  rm -f /tmp/fanzone-mobile-permission.txt
done

if rg -n 'android:usesCleartextTraffic="true"|android:debuggable="true"' android/app/src >/tmp/fanzone-mobile-insecure-manifest.txt; then
  fail "Android manifest enables an insecure release-sensitive flag:
$(cat /tmp/fanzone-mobile-insecure-manifest.txt)"
fi
rm -f /tmp/fanzone-mobile-insecure-manifest.txt

require_contains "${android_manifest}" 'android:host="fanzone\.guest\.ikanisa\.com"' \
  "Android App Links must include the guest production domain."
require_contains "${android_manifest}" 'android:host="fanzone\.ikanisa\.com"' \
  "Android App Links must include the root production domain."
require_contains "${android_manifest}" 'android:autoVerify="true"' \
  "Android production App Links must request auto verification."
require_contains "${android_gradle}" 'applicationId = "app\.fanzone\.football"' \
  "Android applicationId must be the production package, not a placeholder."
require_contains "${android_gradle}" 'targetSdk = 35' \
  "Android targetSdk must stay on the documented production target."
require_contains "${android_gradle}" 'val requiresReleaseSigning = appEnvironment == "production"' \
  "Production Android signing must fail closed when upload signing is missing."
require_contains "${android_gradle}" 'isMinifyEnabled = hardenReleaseBuild' \
  "Production Android release builds must enable minification through hardenReleaseBuild."
require_contains "${android_gradle}" 'isShrinkResources = hardenReleaseBuild' \
  "Production Android release builds must enable resource shrinking through hardenReleaseBuild."

require_contains "${ios_info}" 'NSLocationWhenInUseUsageDescription' \
  "iOS location usage description is required for nearby venue discovery."
require_contains "${ios_info}" 'UIBackgroundModes' \
  "iOS background mode declaration is required for push notification handling."
require_contains "${ios_info}" '\$\(PRODUCT_BUNDLE_IDENTIFIER\)' \
  "iOS bundle identifier must be injected by release configuration, not hardcoded to a placeholder."
require_contains "${ios_entitlements}" '\$\(FANZONE_APS_ENVIRONMENT\)' \
  "iOS APS environment must be release-configured."
require_contains "${ios_entitlements}" 'applinks:fanzone\.guest\.ikanisa\.com' \
  "iOS associated domains must include the guest production domain."
require_contains "${ios_entitlements}" 'applinks:fanzone\.ikanisa\.com' \
  "iOS associated domains must include the root production domain."

require_contains "pubspec.yaml" 'flutter_secure_storage:' \
  "Flutter secure storage dependency must remain present for auth/session material."
require_contains "lib/core/auth/runtime_auth_session_manager.dart" 'SecureAuthSessionStore\.writeMap' \
  "Runtime auth sessions must use the secure session store."
require_contains "lib/core/storage/secure_auth_session_store.dart" 'FlutterSecureStorage' \
  "SecureAuthSessionStore must be backed by FlutterSecureStorage."

if git grep -nE '(SUPABASE_SERVICE_ROLE_KEY|service_role_key|postgresql://[^[:space:]]+:[^[:space:]]+@|sbp_[A-Za-z0-9_-]{20,})' -- \
  lib android ios \
  ':!ios/Pods/**' \
  ':!**/*.lock' >/tmp/fanzone-mobile-secret-scan.txt; then
  fail "Mobile source appears to contain privileged credentials or service-role references:
$(cat /tmp/fanzone-mobile-secret-scan.txt)"
fi
rm -f /tmp/fanzone-mobile-secret-scan.txt

if [[ "${failures}" -ne 0 ]]; then
  echo "Mobile static release audit failed with ${failures} issue(s)." >&2
  exit 1
fi

echo "Mobile static release audit passed."
