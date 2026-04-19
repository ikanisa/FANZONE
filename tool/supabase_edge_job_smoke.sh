#!/usr/bin/env bash
set -euo pipefail

if [[ -f ".env" ]]; then
  set -a
  source .env
  set +a
fi

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  echo "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in the environment or .env."
  exit 1
fi

call_edge() {
  local function_name="$1"
  local bearer="$2"
  local payload="$3"
  shift 3

  curl -sS -o /tmp/"${function_name}".body -w '%{http_code}' \
    -X POST "${SUPABASE_URL}/functions/v1/${function_name}" \
    -H "Authorization: Bearer ${bearer}" \
    -H "Content-Type: application/json" \
    "$@" \
    -d "${payload}"
}

expect_status() {
  local label="$1"
  local actual="$2"
  local expected="$3"

  if [[ "${actual}" != "${expected}" ]]; then
    echo "${label} expected HTTP ${expected} but got ${actual}"
    cat /tmp/"${label%% *}".body 2>/dev/null || true
    exit 1
  fi
}

expect_non_auth_error() {
  local label="$1"
  local actual="$2"

  if [[ "${actual}" == "401" || "${actual}" == "403" ]]; then
    echo "${label} still failed at the auth layer (${actual})"
    cat /tmp/"${label%% *}".body 2>/dev/null || true
    exit 1
  fi
}

echo "Verifying unauthorized access is rejected..."
auto_settle_unauth="$(call_edge "auto-settle" "invalid-token" '{}')"
expect_status "auto-settle unauthorized" "${auto_settle_unauth}" "401"

push_notify_unauth="$(call_edge "push-notify" "invalid-token" '{}')"
expect_status "push-notify unauthorized" "${push_notify_unauth}" "401"

team_news_unauth="$(call_edge "gemini-team-news" "invalid-token" '{}')"
expect_status "gemini-team-news unauthorized" "${team_news_unauth}" "401"

currency_unauth="$(call_edge "gemini-currency-rates" "invalid-token" '{}')"
expect_status "gemini-currency-rates unauthorized" "${currency_unauth}" "401"

echo "Verifying authorized requests pass the auth layer..."
auto_settle_auth="$(call_edge "auto-settle" "${SUPABASE_SERVICE_ROLE_KEY}" '{}' \
  -H "x-cron-secret: ${CRON_SECRET:-}")"
if [[ "${auto_settle_auth}" != "200" && "${auto_settle_auth}" != "207" ]]; then
  echo "auto-settle authorized expected HTTP 200 or 207 but got ${auto_settle_auth}"
  cat /tmp/auto-settle.body 2>/dev/null || true
  exit 1
fi

push_notify_auth="$(call_edge "push-notify" "${SUPABASE_SERVICE_ROLE_KEY}" '{}')"
if [[ "${push_notify_auth}" != "400" ]]; then
  expect_non_auth_error "push-notify authorized" "${push_notify_auth}"
  echo "push-notify authorized expected validation HTTP 400 but got ${push_notify_auth}"
  cat /tmp/push-notify.body 2>/dev/null || true
  exit 1
fi

team_news_auth="$(call_edge "gemini-team-news" "${SUPABASE_SERVICE_ROLE_KEY}" '{}')"
if [[ "${team_news_auth}" != "400" ]]; then
  expect_non_auth_error "gemini-team-news authorized" "${team_news_auth}"
  echo "gemini-team-news authorized expected validation HTTP 400 but got ${team_news_auth}"
  cat /tmp/gemini-team-news.body 2>/dev/null || true
  exit 1
fi

echo "Supabase edge job smoke passed."
