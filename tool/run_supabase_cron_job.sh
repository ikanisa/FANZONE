#!/usr/bin/env bash
set -euo pipefail

# Local/free-account replacement for GitHub scheduled workflows.
# Requires SUPABASE_URL and CRON_SECRET in the environment or .env.
# Usage:
#   tool/run_supabase_cron_job.sh settle-match-pools
#   tool/run_supabase_cron_job.sh dispatch-match-alerts

if [[ -f ".env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source ".env"
  set +a
fi

if [[ -z "${SUPABASE_URL:-}" ]]; then
  echo "SUPABASE_URL must be set in the environment or .env." >&2
  exit 1
fi

if [[ -z "${CRON_SECRET:-}" ]]; then
  echo "CRON_SECRET must be set in the environment or .env." >&2
  exit 1
fi

JOB="${1:-}"
case "${JOB}" in
  settle-match-pools)
    PAYLOAD='{"limit":50}'
    ;;
  dispatch-match-alerts)
    PAYLOAD='{}'
    ;;
  *)
    echo "Usage: $0 settle-match-pools|dispatch-match-alerts" >&2
    exit 1
    ;;
esac

RESPONSE="$(curl -sS -w '\n%{http_code}' \
  -X POST \
  -H "Content-Type: application/json" \
  -H "x-cron-secret: ${CRON_SECRET}" \
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

