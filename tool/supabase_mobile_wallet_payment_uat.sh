#!/usr/bin/env bash
set -euo pipefail

sql_file="supabase/tests/mobile_wallet_payment_confirmation_uat.sql"
evidence_dir="output/release-evidence/mobile-wallet-payment-uat"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="${evidence_dir}/${timestamp}.log"
db_url="${SUPABASE_RLS_DB_URL:-${SUPABASE_DB_URL:-}}"

mkdir -p "${evidence_dir}"

run_linked_query() {
  if ! command -v supabase >/dev/null 2>&1; then
    return 1
  fi
  if [[ ! -f "supabase/.temp/project-ref" ]]; then
    return 1
  fi

  tmp_sql="$(mktemp)"
  trap 'rm -f "${tmp_sql}"' EXIT
  sed '/^\\/d' "${sql_file}" >"${tmp_sql}"
  supabase db query --linked --file "${tmp_sql}"
}

{
  echo "FANZONE mobile wallet payment-confirmation UAT"
  echo "Timestamp UTC: ${timestamp}"
  echo "SQL: ${sql_file}"
  echo "Log: ${log_file}"
  echo

  if [[ -z "${db_url}" ]]; then
    if run_linked_query; then
      exit 0
    fi
    echo "Linked Supabase query failed. Review the SQL error above, or set SUPABASE_RLS_DB_URL/SUPABASE_DB_URL for direct psql execution." >&2
    exit 1
  fi

  if ! command -v psql >/dev/null 2>&1; then
    echo "psql is required to run the mobile wallet payment UAT with a direct database URL." >&2
    exit 1
  fi

  psql "${db_url}" \
    --set ON_ERROR_STOP=1 \
    --file "${sql_file}"
} 2>&1 | tee "${log_file}"
