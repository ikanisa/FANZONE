#!/usr/bin/env bash
set -euo pipefail

if [[ -f ".env" ]]; then
  set -a
  source .env
  set +a
fi

if [[ -z "${SUPABASE_URL:-}" ]]; then
  echo "SUPABASE_URL must be set in the environment or .env."
  exit 1
fi

if [[ -z "${CRON_SECRET:-}" || -z "${PUSH_NOTIFY_SECRET:-}" ]]; then
  echo "CRON_SECRET and PUSH_NOTIFY_SECRET must be set for edge auth smoke coverage."
  exit 1
fi

call_edge() {
  local function_name="$1"
  local bearer="$2"
  local payload="$3"
  shift 3

  local -a curl_args=(
    -sS
    -o /tmp/"${function_name}".body
    -w '%{http_code}'
    -X POST "${SUPABASE_URL}/functions/v1/${function_name}"
    -H "Content-Type: application/json"
  )

  if [[ -n "${bearer}" ]]; then
    curl_args+=(-H "Authorization: Bearer ${bearer}")
  fi

  curl "${curl_args[@]}" "$@" -d "${payload}"
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
import_football_unauth="$(call_edge "import-football-data" "" '{}')"
expect_status "import-football-data unauthorized" "${import_football_unauth}" "401"

settle_pools_unauth="$(call_edge "settle-match-pools" "" '{}')"
expect_status "settle-match-pools unauthorized" "${settle_pools_unauth}" "401"

dispatch_match_alerts_unauth="$(call_edge "dispatch-match-alerts" "" '{}')"
expect_status "dispatch-match-alerts unauthorized" "${dispatch_match_alerts_unauth}" "401"

push_notify_unauth="$(call_edge "push-notify" "" '{}')"
expect_status "push-notify unauthorized" "${push_notify_unauth}" "401"

echo "Verifying authorized requests pass the auth layer..."
import_football_auth="$(call_edge "import-football-data" "" '{}' \
  -H "x-cron-secret: ${CRON_SECRET}")"
if [[ "${import_football_auth}" != "200" && "${import_football_auth}" != "400" ]]; then
  expect_non_auth_error "import-football-data authorized" "${import_football_auth}"
  echo "import-football-data authorized expected HTTP 200 or validation HTTP 400 but got ${import_football_auth}"
  cat /tmp/import-football-data.body 2>/dev/null || true
  exit 1
fi

settle_pools_auth="$(call_edge "settle-match-pools" "" '{}' \
  -H "x-cron-secret: ${CRON_SECRET}")"
if [[ "${settle_pools_auth}" != "200" && "${settle_pools_auth}" != "400" ]]; then
  expect_non_auth_error "settle-match-pools authorized" "${settle_pools_auth}"
  echo "settle-match-pools authorized expected HTTP 200 or validation HTTP 400 but got ${settle_pools_auth}"
  cat /tmp/settle-match-pools.body 2>/dev/null || true
  exit 1
fi

dispatch_match_alerts_auth="$(call_edge "dispatch-match-alerts" "" '{}' \
  -H "x-cron-secret: ${CRON_SECRET}")"
if [[ "${dispatch_match_alerts_auth}" != "200" && "${dispatch_match_alerts_auth}" != "207" ]]; then
  echo "dispatch-match-alerts authorized expected HTTP 200 or 207 but got ${dispatch_match_alerts_auth}"
  cat /tmp/dispatch-match-alerts.body 2>/dev/null || true
  exit 1
fi

push_notify_auth="$(call_edge "push-notify" "" '{}' \
  -H "x-push-notify-secret: ${PUSH_NOTIFY_SECRET}")"
if [[ "${push_notify_auth}" != "400" ]]; then
  expect_non_auth_error "push-notify authorized" "${push_notify_auth}"
  echo "push-notify authorized expected validation HTTP 400 but got ${push_notify_auth}"
  cat /tmp/push-notify.body 2>/dev/null || true
  exit 1
fi

echo "Supabase edge job smoke passed."
