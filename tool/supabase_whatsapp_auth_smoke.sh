#!/usr/bin/env bash
set -euo pipefail

if [[ -f ".env" ]]; then
  set -a
  source .env
  set +a
fi

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "SUPABASE_URL and SUPABASE_ANON_KEY must be set in the environment or .env."
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

call_whatsapp_auth() {
  local label="$1"
  local payload="$2"

  curl -sS \
    -o "${tmp_dir}/${label}.body" \
    -w '%{http_code}' \
    -X POST "${SUPABASE_URL}/functions/v1/whatsapp-otp" \
    -H "Content-Type: application/json" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
    -d "${payload}"
}

expect_status() {
  local label="$1"
  local actual="$2"
  local expected="$3"

  if [[ "${actual}" != "${expected}" ]]; then
    echo "${label} expected HTTP ${expected} but got ${actual}"
    cat "${tmp_dir}/${label}.body" 2>/dev/null || true
    exit 1
  fi
}

echo "Inspecting auth settings for alternate built-in login modes..."
auth_settings_json="$(
  curl -sS \
    "${SUPABASE_URL}/auth/v1/settings" \
    -H "apikey: ${SUPABASE_ANON_KEY}"
)"

AUTH_SETTINGS_JSON="${auth_settings_json}" python3 - <<'PY'
import json
import os
import sys

payload = json.loads(os.environ["AUTH_SETTINGS_JSON"])

def read_flag(*keys):
    for key in keys:
        value = payload.get(key)
        if isinstance(value, bool):
            return key, value
    return None, None

email_key, email_enabled = read_flag("external_email_enabled", "email_enabled")
phone_key, phone_enabled = read_flag("external_phone_enabled", "phone_enabled", "sms_enabled")

if email_enabled is True:
    print(f"Built-in email auth is enabled via {email_key}; expected it to be disabled.")
    sys.exit(1)

if phone_enabled is True:
    print(f"Built-in phone auth is enabled via {phone_key}; expected it to be disabled in favor of whatsapp-otp.")
    sys.exit(1)

print(
    "auth.settings OK"
    f" (email={email_enabled if email_key else 'unknown'},"
    f" phone={phone_enabled if phone_key else 'unknown'})"
)
PY

echo "Verifying public WhatsApp auth function validation..."
missing_action_status="$(call_whatsapp_auth "missing_action" '{"phone":"+35699123456"}')"
expect_status "missing_action" "${missing_action_status}" "400"

invalid_phone_status="$(call_whatsapp_auth "invalid_phone" '{"action":"send","phone":"not-a-phone"}')"
expect_status "invalid_phone" "${invalid_phone_status}" "400"

missing_otp_status="$(call_whatsapp_auth "missing_otp" '{"action":"verify","phone":"+35699123456"}')"
expect_status "missing_otp" "${missing_otp_status}" "400"

invalid_otp_status="$(call_whatsapp_auth "invalid_otp" '{"action":"verify","phone":"+35699123456","otp":"12"}')"
expect_status "invalid_otp" "${invalid_otp_status}" "400"

if [[ -n "${WHATSAPP_AUTH_TEST_PHONE:-}" ]]; then
  echo "Running live WhatsApp OTP send smoke..."
  send_status="$(call_whatsapp_auth "live_send" "$(printf '{"action":"send","phone":"%s"}' "${WHATSAPP_AUTH_TEST_PHONE}")")"
  expect_status "live_send" "${send_status}" "200"

  if [[ -n "${WHATSAPP_AUTH_TEST_OTP:-}" ]]; then
    echo "Running live WhatsApp OTP verify smoke..."
    verify_status="$(call_whatsapp_auth "live_verify" "$(printf '{"action":"verify","phone":"%s","otp":"%s"}' "${WHATSAPP_AUTH_TEST_PHONE}" "${WHATSAPP_AUTH_TEST_OTP}")")"
    expect_status "live_verify" "${verify_status}" "200"

    LIVE_VERIFY_BODY="$(cat "${tmp_dir}/live_verify.body")" python3 - <<'PY'
import json
import os
import sys

payload = json.loads(os.environ["LIVE_VERIFY_BODY"])

if payload.get("success") is not True:
    print("Live WhatsApp verify response did not report success.")
    sys.exit(1)

if not isinstance(payload.get("access_token"), str) or not payload["access_token"]:
    print("Live WhatsApp verify response is missing access_token.")
    sys.exit(1)

if not isinstance(payload.get("session_string"), str) or not payload["session_string"]:
    print("Live WhatsApp verify response is missing session_string.")
    sys.exit(1)

print("live_verify payload OK")
PY
  fi
fi

echo "Supabase WhatsApp auth smoke passed."
