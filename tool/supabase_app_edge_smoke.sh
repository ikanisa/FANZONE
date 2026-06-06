#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  shift
fi
if [[ "${FANZONE_APP_EDGE_DRY_RUN:-}" == "1" || "${FANZONE_APP_EDGE_DRY_RUN:-}" == "true" ]]; then
  DRY_RUN=true
fi

if [[ -f ".env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source .env
  set +a
fi

APP_FUNCTIONS=("$@")
if [[ "$#" -eq 0 ]]; then
  APP_FUNCTIONS=(
    order_create
    order_mark_paid
    order_update_status
    payment-hub
    ring_bell
    menu_ocr_parse
    generate-pool-social-card
  )
fi

payload_for() {
  local function_name="$1"
  case "${function_name}" in
    order_create)
      printf '{"venue_id":"00000000-0000-4000-8000-000000000000","table_number":"T1","payment_method":"cash","items":[{"menu_item_id":"00000000-0000-4000-8000-000000000001","quantity":1}]}'
      ;;
    order_mark_paid)
      printf '{"order_id":"00000000-0000-4000-8000-000000000000","payment_method":"cash","note":"Release smoke only"}'
      ;;
    order_update_status)
      printf '{"order_id":"00000000-0000-4000-8000-000000000000","status":"accepted","reason":"Release smoke only"}'
      ;;
    payment-hub)
      printf '{"order_id":"00000000-0000-4000-8000-000000000000","venue_id":"00000000-0000-4000-8000-000000000000","method":"momo"}'
      ;;
    ring_bell)
      printf '{"venue_id":"00000000-0000-4000-8000-000000000000","table_id":"00000000-0000-4000-8000-000000000001","message":"Release smoke only"}'
      ;;
    menu_ocr_parse)
      printf '{"venue_id":"00000000-0000-4000-8000-000000000000","image_base64":"ZmFrZQ==","mime_type":"image/png"}'
      ;;
    generate-pool-social-card)
      printf '{"pool_id":"00000000-0000-4000-8000-000000000000"}'
      ;;
    *)
      echo "Unsupported app Edge Function: ${function_name}" >&2
      echo "Usage: $0 [order_create] [order_mark_paid] [order_update_status] [payment-hub] [ring_bell] [menu_ocr_parse] [generate-pool-social-card]" >&2
      exit 1
      ;;
  esac
}

call_app_edge() {
  local function_name="$1"
  local payload="$2"
  shift 2

  local -a curl_args=(
    -sS
    -o /tmp/"${function_name}".body
    -w '%{http_code}'
    -X POST "${SUPABASE_URL}/functions/v1/${function_name}"
    -H "Content-Type: application/json"
  )

  curl "${curl_args[@]}" "$@" -d "${payload}"
}

expect_status() {
  local label="$1"
  local body_file="$2"
  local actual="$3"
  local expected="$4"

  if [[ "${actual}" != "${expected}" ]]; then
    echo "${label} expected HTTP ${expected} but got ${actual}" >&2
    cat "${body_file}" 2>/dev/null || true
    exit 1
  fi
}

expect_non_auth_error() {
  local label="$1"
  local body_file="$2"
  local actual="$3"

  if [[ "${actual}" == "401" || "${actual}" == "403" ]]; then
    echo "${label} still failed at the auth layer (${actual})" >&2
    cat "${body_file}" 2>/dev/null || true
    exit 1
  fi
}

for function_name in "${APP_FUNCTIONS[@]}"; do
  payload="$(payload_for "${function_name}")"

  if [[ "${DRY_RUN}" == true ]]; then
    echo "Dry run: ${function_name}"
    echo "Payload: ${payload}"
    continue
  fi

  if [[ -z "${SUPABASE_URL:-}" ]]; then
    echo "SUPABASE_URL must be set in the environment or .env." >&2
    exit 1
  fi

  echo "Checking ${function_name} rejects anonymous calls..."
  unauth_status="$(call_app_edge "${function_name}" "${payload}")"
  expect_status "${function_name} anonymous" "/tmp/${function_name}.body" "${unauth_status}" "401"

  if [[ -n "${FANZONE_UAT_USER_JWT:-}" ]]; then
    echo "Checking ${function_name} accepts authenticated requests past auth..."
    auth_status="$(call_app_edge "${function_name}" "${payload}" \
      -H "Authorization: Bearer ${FANZONE_UAT_USER_JWT}")"
    expect_non_auth_error "${function_name} authenticated" "/tmp/${function_name}.body" "${auth_status}"
  else
    echo "Skipping ${function_name} authenticated probe because FANZONE_UAT_USER_JWT is not set."
  fi
done

echo "Supabase app Edge smoke passed."
