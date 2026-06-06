#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  shift
fi
if [[ "${FANZONE_GAME_EDGE_DRY_RUN:-}" == "1" || "${FANZONE_GAME_EDGE_DRY_RUN:-}" == "true" ]]; then
  DRY_RUN=true
fi

if [[ -f ".env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source .env
  set +a
fi

GAME_FUNCTIONS=("$@")
if [[ "$#" -eq 0 ]]; then
  GAME_FUNCTIONS=(fan-trivia song-guess music-bingo)
fi

call_game_edge() {
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

for function_name in "${GAME_FUNCTIONS[@]}"; do
  case "${function_name}" in
    fan-trivia|song-guess|music-bingo) ;;
    *)
      echo "Unsupported game Edge Function: ${function_name}" >&2
      echo "Usage: $0 [fan-trivia] [song-guess] [music-bingo]" >&2
      exit 1
      ;;
  esac

  if [[ "${DRY_RUN}" == true ]]; then
    echo "Dry run: ${function_name}"
    echo "Anonymous payload: {\"action\":\"list_sessions\"}"
    echo "Authenticated payload: {\"action\":\"list_sessions\"}"
    continue
  fi

  if [[ -z "${SUPABASE_URL:-}" ]]; then
    echo "SUPABASE_URL must be set in the environment or .env." >&2
    exit 1
  fi

  echo "Checking ${function_name} rejects anonymous calls..."
  unauth_status="$(call_game_edge "${function_name}" '{"action":"list_sessions"}')"
  expect_status "${function_name} anonymous" "/tmp/${function_name}.body" "${unauth_status}" "401"

  if [[ -n "${FANZONE_UAT_USER_JWT:-}" ]]; then
    echo "Checking ${function_name} accepts authenticated list_sessions..."
    auth_status="$(call_game_edge "${function_name}" '{"action":"list_sessions"}' \
      -H "Authorization: Bearer ${FANZONE_UAT_USER_JWT}")"
    expect_status "${function_name} authenticated" "/tmp/${function_name}.body" "${auth_status}" "200"
  else
    echo "Skipping ${function_name} authenticated probe because FANZONE_UAT_USER_JWT is not set."
  fi
done

echo "Supabase game Edge smoke passed."
