#!/usr/bin/env bash
set -euo pipefail

# Local/free-account replacement for GitHub scheduled workflows.
# Requires SUPABASE_URL and either CRON_SECRET or a service-role key in the
# environment or .env. CRON_SECRET remains the production scheduler default;
# the service-role bearer path is for controlled operator smoke only.
# Usage:
#   tool/run_supabase_cron_job.sh settle-match-pools
#   tool/run_supabase_cron_job.sh dispatch-match-alerts
#   tool/run_supabase_cron_job.sh sync-livescore-football
#   tool/run_supabase_cron_job.sh generate-weekly-game-packs

json_bool() {
  local value="${1:-}"
  case "$(printf '%s' "${value}" | tr '[:upper:]' '[:lower:]')" in
    true|1|yes) printf 'true' ;;
    false|0|no) printf 'false' ;;
    *)
      echo "Expected boolean value, got '${value}'." >&2
      exit 1
      ;;
  esac
}

json_int() {
  local value="${1:-}"
  if [[ ! "${value}" =~ ^[0-9]+$ ]]; then
    echo "Expected non-negative integer value, got '${value}'." >&2
    exit 1
  fi
  printf '%s' "${value}"
}

json_slug() {
  local value="${1:-}"
  if [[ ! "${value}" =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo "Expected slug value, got '${value}'." >&2
    exit 1
  fi
  printf '%s' "${value}"
}

if [[ -f ".env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source ".env"
  set +a
fi

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  shift
fi
if [[ "${FANZONE_CRON_DRY_RUN:-}" == "1" || "${FANZONE_CRON_DRY_RUN:-}" == "true" ]]; then
  DRY_RUN=true
fi

JOB="${1:-}"
case "${JOB}" in
  settle-match-pools)
    PAYLOAD='{"limit":50}'
    ;;
  dispatch-match-alerts)
    PAYLOAD='{}'
    ;;
  sync-livescore-football)
    LIVESCORE_RESOURCE_ID="$(json_slug "${LIVESCORE_RESOURCE_ID:-livescore_world_cup_2026}")"
    LIVESCORE_APPLY="$(json_bool "${LIVESCORE_APPLY:-true}")"
    LIVESCORE_INCLUDE_DETAILS="$(json_bool "${LIVESCORE_INCLUDE_DETAILS:-false}")"
    LIVESCORE_INCLUDE_SCOREBOARD="$(json_bool "${LIVESCORE_INCLUDE_SCOREBOARD:-true}")"
    LIVESCORE_LIMIT="$(json_int "${LIVESCORE_LIMIT:-200}")"
    LIVESCORE_DELAY_MS="$(json_int "${LIVESCORE_DELAY_MS:-750}")"
    PAYLOAD="{\"resource_id\":\"${LIVESCORE_RESOURCE_ID}\",\"apply\":${LIVESCORE_APPLY},\"include_details\":${LIVESCORE_INCLUDE_DETAILS},\"include_scoreboard\":${LIVESCORE_INCLUDE_SCOREBOARD},\"limit\":${LIVESCORE_LIMIT},\"delay_ms\":${LIVESCORE_DELAY_MS}}"
    ;;
  generate-weekly-game-packs)
    GAME_PACK_WEEK_START="${GAME_PACK_WEEK_START:-}"
    GAME_PACK_TARGET_COUNT="$(json_int "${GAME_PACK_TARGET_COUNT:-100}")"
    GAME_PACK_BATCH_SIZE="$(json_int "${GAME_PACK_BATCH_SIZE:-5}")"
    GAME_PACK_DRY_RUN="$(json_bool "${GAME_PACK_DRY_RUN:-false}")"
    if [[ -n "${GAME_PACK_WEEK_START}" && ! "${GAME_PACK_WEEK_START}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
      echo "Expected GAME_PACK_WEEK_START as YYYY-MM-DD, got '${GAME_PACK_WEEK_START}'." >&2
      exit 1
    fi
    if [[ -n "${GAME_PACK_WEEK_START}" ]]; then
      PAYLOAD="{\"weekStart\":\"${GAME_PACK_WEEK_START}\",\"marketCodes\":[\"MT\",\"RW\"],\"targetPackCount\":${GAME_PACK_TARGET_COUNT},\"questionsPerPack\":20,\"batchSize\":${GAME_PACK_BATCH_SIZE},\"dryRun\":${GAME_PACK_DRY_RUN}}"
    else
      PAYLOAD="{\"marketCodes\":[\"MT\",\"RW\"],\"targetPackCount\":${GAME_PACK_TARGET_COUNT},\"questionsPerPack\":20,\"batchSize\":${GAME_PACK_BATCH_SIZE},\"dryRun\":${GAME_PACK_DRY_RUN}}"
    fi
    ;;
  *)
    echo "Usage: $0 [--dry-run] settle-match-pools|dispatch-match-alerts|sync-livescore-football|generate-weekly-game-packs" >&2
    exit 1
    ;;
esac

if [[ "${DRY_RUN}" == true ]]; then
  echo "Dry run: ${JOB}"
  echo "Payload: ${PAYLOAD}"
  exit 0
fi

if [[ -z "${SUPABASE_URL:-}" ]]; then
  echo "SUPABASE_URL must be set in the environment or .env." >&2
  exit 1
fi

auth_header_name=""
auth_header_value=""
if [[ -n "${CRON_SECRET:-}" ]]; then
  auth_header_name="x-cron-secret"
  auth_header_value="${CRON_SECRET}"
elif [[ -n "${EDGE_SERVICE_ROLE_KEY:-}" ]]; then
  auth_header_name="Authorization"
  auth_header_value="Bearer ${EDGE_SERVICE_ROLE_KEY}"
elif [[ -n "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  auth_header_name="Authorization"
  auth_header_value="Bearer ${SUPABASE_SERVICE_ROLE_KEY}"
fi

if [[ -z "${auth_header_name}" ]]; then
  echo "CRON_SECRET, EDGE_SERVICE_ROLE_KEY, or SUPABASE_SERVICE_ROLE_KEY must be set in the environment or .env." >&2
  exit 1
fi

RESPONSE="$(curl -sS -w '\n%{http_code}' \
  -X POST \
  -H "Content-Type: application/json" \
  -H "${auth_header_name}: ${auth_header_value}" \
  "${SUPABASE_URL}/functions/v1/${JOB}" \
  -d "${PAYLOAD}")"

HTTP_CODE="$(printf '%s\n' "${RESPONSE}" | tail -1)"
BODY="$(printf '%s\n' "${RESPONSE}" | sed '$d')"

echo "HTTP Status: ${HTTP_CODE}"
echo "${BODY}"

if [[ "${HTTP_CODE}" -lt 200 || "${HTTP_CODE}" -ge 300 ]]; then
  echo "${JOB} failed." >&2
  exit 1
fi
