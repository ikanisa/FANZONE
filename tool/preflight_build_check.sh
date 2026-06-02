#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# preflight_build_check.sh — Pre-build validation for FANZONE Flutter builds
# ──────────────────────────────────────────────────────────────────────────────
#
# Run this BEFORE every release build to ensure Supabase credentials are present.
# Without a valid --dart-define-from-file env/*.json, the app compiles with empty strings and
# shows blank screens (no matches, fixtures, teams, or competitions).
#
# Usage:
#   ./tool/preflight_build_check.sh production
#   ./tool/preflight_build_check.sh env/production.json
#
# Exit codes:
#   0 — all checks passed
#   1 — critical issue found (DO NOT build)
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "  ${GREEN}✅${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}❌${NC} $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "  ${YELLOW}⚠️${NC}  $1"; WARN=$((WARN + 1)); }

is_placeholder() {
  local value="${1:-}"
  local normalized
  normalized="$(printf '%s' "${value}" | tr '[:upper:]' '[:lower:]')"
  [[ -z "${normalized}" ||
    "${normalized}" == "replace-me" ||
    "${normalized}" == "change-me" ||
    "${normalized}" == "replace_with_value" ||
    "${normalized}" == your-* ||
    "${normalized}" == *placeholder* ]]
}

key_property() {
  local name="$1"
  local file="${2:-android/key.properties}"
  awk -F '=' -v key="${name}" '
    $1 == key {
      value = substr($0, index($0, "=") + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      print value
      exit
    }
  ' "${file}" 2>/dev/null || true
}

resolve_store_file() {
  local value="$1"
  if [[ "${value}" = /* ]]; then
    printf '%s\n' "${value}"
    return
  fi

  local app_relative="android/app/${value}"
  local android_relative="android/${value}"
  if [[ -f "${app_relative}" || ! -f "${android_relative}" ]]; then
    printf '%s\n' "${app_relative}"
  else
    printf '%s\n' "${android_relative}"
  fi
}

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  FANZONE Pre-Build Validation${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# ── 1. Check env file exists ──────────────────────────────────────────────────
echo -e "${BOLD}1. Environment file${NC}"

ENV_INPUT="${1:-production}"

if [[ -f "$ENV_INPUT" ]]; then
  ENV_FILE="$ENV_INPUT"
else
  ENV_FILE="$(./tool/resolve_dart_define_file.sh "$ENV_INPUT")"
fi

if [[ ! -f "$ENV_FILE" ]]; then
  fail "env file not found: $ENV_FILE"
  echo ""
  echo -e "  ${RED}Create env/<environment>.json with:${NC}"
  echo '    {'
  echo '      "SUPABASE_URL": "https://your-project.supabase.co",'
  echo '      "SUPABASE_ANON_KEY": "your-anon-key"'
  echo '    }'
  echo ""
  echo -e "${RED}${BOLD}BUILD BLOCKED — env file is missing${NC}"
  exit 1
fi
pass "env file exists ($ENV_FILE)"

# ── 2. Check required keys ───────────────────────────────────────────────────
echo ""
echo -e "${BOLD}2. Required Supabase credentials${NC}"

SUPABASE_URL=$(ruby -rjson -e 'data = JSON.parse(File.read(ARGV[0])); print(data["SUPABASE_URL"].to_s)' "$ENV_FILE" 2>/dev/null || true)
SUPABASE_ANON_KEY=$(ruby -rjson -e 'data = JSON.parse(File.read(ARGV[0])); print(data["SUPABASE_ANON_KEY"].to_s)' "$ENV_FILE" 2>/dev/null || true)
APP_ENV=$(ruby -rjson -e 'data = JSON.parse(File.read(ARGV[0])); print(data["APP_ENV"].to_s)' "$ENV_FILE" 2>/dev/null || true)

if [[ -z "$SUPABASE_URL" ]]; then
  fail "SUPABASE_URL is missing or empty in $ENV_FILE"
else
  # Validate URL format
  if [[ "$SUPABASE_URL" == https://*.supabase.co ]]; then
    pass "SUPABASE_URL is set (${SUPABASE_URL:0:40}...)"
  elif [[ "$SUPABASE_URL" == *"placeholder"* ]] || [[ "$SUPABASE_URL" == *"example"* ]]; then
    fail "SUPABASE_URL appears to be a placeholder — use a real project URL"
  else
    warn "SUPABASE_URL is set but doesn't match expected pattern: ${SUPABASE_URL:0:40}"
  fi
fi

if [[ -z "$SUPABASE_ANON_KEY" ]]; then
  fail "SUPABASE_ANON_KEY is missing or empty in $ENV_FILE"
else
  # Validate JWT format (starts with eyJ)
  if [[ "$SUPABASE_ANON_KEY" == eyJ* ]]; then
    pass "SUPABASE_ANON_KEY is set (${#SUPABASE_ANON_KEY} chars, starts with eyJ...)"
  else
    warn "SUPABASE_ANON_KEY doesn't look like a JWT token"
  fi
fi

if [[ -n "$APP_ENV" ]]; then
  pass "APP_ENV is set to $APP_ENV"
else
  warn "APP_ENV is missing in $ENV_FILE"
fi

# ── 3. Check Firebase config ─────────────────────────────────────────────────
echo ""
echo -e "${BOLD}3. Firebase configuration${NC}"

if [[ -f "lib/firebase_options.dart" ]]; then
  pass "lib/firebase_options.dart exists"
else
  fail "lib/firebase_options.dart is missing — run: flutterfire configure"
fi

if [[ -f "android/app/google-services.json" ]]; then
  pass "android/app/google-services.json exists"
else
  warn "android/app/google-services.json is missing (needed for Android push)"
fi

# ── 4. Check signing config ──────────────────────────────────────────────────
echo ""
echo -e "${BOLD}4. Android signing${NC}"

SIGNING_SOURCE=""
STORE_FILE_VALUE=""
STORE_PASSWORD_VALUE=""
KEY_ALIAS_VALUE=""
KEY_PASSWORD_VALUE=""

if [[ -f "android/key.properties" ]]; then
  pass "android/key.properties exists"
  SIGNING_SOURCE="android/key.properties"
  STORE_FILE_VALUE="$(key_property storeFile)"
  STORE_PASSWORD_VALUE="$(key_property storePassword)"
  KEY_ALIAS_VALUE="$(key_property keyAlias)"
  KEY_PASSWORD_VALUE="$(key_property keyPassword)"
elif [[ -n "${FANZONE_UPLOAD_STORE_FILE:-}" ||
  -n "${FANZONE_UPLOAD_STORE_PASSWORD:-}" ||
  -n "${FANZONE_UPLOAD_KEY_ALIAS:-}" ||
  -n "${FANZONE_UPLOAD_KEY_PASSWORD:-}" ]]; then
  SIGNING_SOURCE="FANZONE_UPLOAD_* environment variables"
  STORE_FILE_VALUE="${FANZONE_UPLOAD_STORE_FILE:-}"
  STORE_PASSWORD_VALUE="${FANZONE_UPLOAD_STORE_PASSWORD:-}"
  KEY_ALIAS_VALUE="${FANZONE_UPLOAD_KEY_ALIAS:-}"
  KEY_PASSWORD_VALUE="${FANZONE_UPLOAD_KEY_PASSWORD:-}"
  pass "Android signing values are provided by FANZONE_UPLOAD_* environment variables"
else
  fail "Android production signing is missing; provide android/key.properties or FANZONE_UPLOAD_* environment variables"
fi

if [[ -n "${SIGNING_SOURCE}" ]]; then
  if is_placeholder "${STORE_FILE_VALUE}"; then
    fail "Android signing storeFile is missing or placeholder in ${SIGNING_SOURCE}"
  fi
  if is_placeholder "${STORE_PASSWORD_VALUE}"; then
    fail "Android signing storePassword is missing or placeholder in ${SIGNING_SOURCE}"
  fi
  if is_placeholder "${KEY_ALIAS_VALUE}"; then
    fail "Android signing keyAlias is missing or placeholder in ${SIGNING_SOURCE}"
  fi
  if is_placeholder "${KEY_PASSWORD_VALUE}"; then
    fail "Android signing keyPassword is missing or placeholder in ${SIGNING_SOURCE}"
  fi

  if [[ -n "${STORE_FILE_VALUE}" ]] && ! is_placeholder "${STORE_FILE_VALUE}"; then
    RESOLVED_STORE_FILE="$(resolve_store_file "${STORE_FILE_VALUE}")"
    if [[ -f "${RESOLVED_STORE_FILE}" ]]; then
      pass "Android upload keystore exists"
      if command -v keytool >/dev/null 2>&1 &&
        ! is_placeholder "${STORE_PASSWORD_VALUE}" &&
        ! is_placeholder "${KEY_ALIAS_VALUE}"; then
        if KEYTOOL_STOREPASS="${STORE_PASSWORD_VALUE}" keytool \
          -list \
          -keystore "${RESOLVED_STORE_FILE}" \
          -storepass:env KEYTOOL_STOREPASS \
          -alias "${KEY_ALIAS_VALUE}" >/dev/null 2>&1; then
          pass "Android upload keystore opens and contains the configured alias"
        else
          fail "Android upload keystore could not be opened or does not contain the configured alias"
        fi
      else
        warn "Skipping keystore alias dry check because keytool is unavailable or signing fields are incomplete"
      fi
    else
      fail "Android upload keystore file is missing"
    fi
  fi
fi

# ── 5. Check package/version metadata ─────────────────────────────────────────
echo ""
echo -e "${BOLD}5. Android package + version metadata${NC}"

APP_ID=$(grep -E 'applicationId *= *"' android/app/build.gradle.kts 2>/dev/null | head -1 | sed -E 's/.*applicationId *= *"([^"]+)".*/\1/' || true)
APP_VERSION=$(awk -F': ' '/^version: /{print $2; exit}' pubspec.yaml)

if [[ -n "$APP_ID" ]]; then
  pass "applicationId is $APP_ID"
else
  fail "Could not resolve Android applicationId"
fi

if [[ "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]]; then
  pass "pubspec version is $APP_VERSION"
else
  warn "pubspec version does not match x.y.z+build format: $APP_VERSION"
fi

# ── 6. Connectivity check (optional) ─────────────────────────────────────────
echo ""
echo -e "${BOLD}6. Backend connectivity${NC}"

if [[ -n "$SUPABASE_URL" ]] && command -v curl &>/dev/null; then
  HTTP_CODE=$(curl -sS -o /dev/null -w "%{http_code}" \
    "${SUPABASE_URL}/rest/v1/teams?select=id&limit=1" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    --max-time 5 2>/dev/null || true)
  HTTP_CODE="${HTTP_CODE:-000}"
  
  if [[ "$HTTP_CODE" == "200" ]]; then
    pass "Supabase REST API is reachable (HTTP $HTTP_CODE)"
  elif [[ "$HTTP_CODE" == "000" ]]; then
    warn "Could not reach Supabase (network issue or timeout)"
  else
    warn "Supabase returned HTTP $HTTP_CODE (expected 200)"
  fi
else
  warn "Skipping connectivity check (curl not available or URL missing)"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"

if [[ $FAIL -gt 0 ]]; then
  echo -e "  ${RED}${BOLD}PREFLIGHT FAILED${NC} — $FAIL critical issue(s) found"
  echo ""
  echo -e "  ${BOLD}DO NOT build until all ❌ items are resolved.${NC}"
  echo ""
  echo -e "  ${BOLD}Correct build command:${NC}"
  echo "    ./tool/build_android_release_from_env.sh ${ENV_INPUT}"
  echo "    ./tool/build_android_aab_from_env.sh ${ENV_INPUT}"
  echo ""
  exit 1
else
  echo -e "  ${GREEN}${BOLD}PREFLIGHT PASSED${NC} — $PASS checks OK, $WARN warnings"
  echo ""
  echo -e "  ${BOLD}Build with:${NC}"
  echo "    ./tool/build_android_release_from_env.sh ${ENV_INPUT}"
  echo "    ./tool/build_android_aab_from_env.sh ${ENV_INPUT}"
  echo ""
  exit 0
fi
