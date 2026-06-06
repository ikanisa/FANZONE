#!/usr/bin/env bash
set -euo pipefail

sql_file="supabase/tests/scheduler_run_history_alerts.sql"
evidence_dir="output/release-evidence/scheduler-history-alerts"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="${evidence_dir}/${stamp}.log"

mkdir -p "${evidence_dir}"

{
  echo "FANZONE scheduler run history and missed-run alert contract"
  echo "Captured at: ${stamp}"
  echo "SQL file: ${sql_file}"
  echo
} | tee "${log_file}"

if [[ ! -f "${sql_file}" ]]; then
  echo "Missing SQL contract: ${sql_file}" | tee -a "${log_file}" >&2
  exit 1
fi

if [[ -n "${SUPABASE_SCHEDULER_HISTORY_DB_URL:-}" ]]; then
  if ! command -v psql >/dev/null 2>&1; then
    echo "psql is required when SUPABASE_SCHEDULER_HISTORY_DB_URL is set." | tee -a "${log_file}" >&2
    exit 1
  fi
  psql "${SUPABASE_SCHEDULER_HISTORY_DB_URL}" \
    -v ON_ERROR_STOP=1 \
    -f "${sql_file}" 2>&1 | tee -a "${log_file}"
else
  supabase db query --linked \
    --file "${sql_file}" 2>&1 | tee -a "${log_file}"
fi

echo
echo "Evidence log: ${log_file}"
