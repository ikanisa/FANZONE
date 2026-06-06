#!/usr/bin/env bash
set -euo pipefail

sql_files=(
  "supabase/tests/public_url_safety_contract.sql"
  "supabase/tests/public_url_safety_existing_data.sql"
)
evidence_dir="output/release-evidence/public-url-safety"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="${evidence_dir}/${timestamp}.log"
db_url="${SUPABASE_PUBLIC_URL_SAFETY_DB_URL:-${SUPABASE_RLS_DB_URL:-${SUPABASE_DB_URL:-}}}"

mkdir -p "${evidence_dir}"

run_linked_query() {
  if ! command -v supabase >/dev/null 2>&1; then
    return 1
  fi
  if [[ ! -f "supabase/.temp/project-ref" ]]; then
    return 1
  fi

  for sql_file in "${sql_files[@]}"; do
    echo "Running ${sql_file}"
    supabase db query --linked --file "${sql_file}"
  done
}

{
  echo "FANZONE public URL safety contract"
  echo "Timestamp UTC: ${timestamp}"
  echo "SQL:"
  printf ' - %s\n' "${sql_files[@]}"
  echo "Log: ${log_file}"
  echo

  if [[ -z "${db_url}" ]]; then
    if run_linked_query; then
      exit 0
    fi
    echo "Linked Supabase query failed. Set SUPABASE_PUBLIC_URL_SAFETY_DB_URL/SUPABASE_RLS_DB_URL/SUPABASE_DB_URL for direct psql execution." >&2
    exit 1
  fi

  if ! command -v psql >/dev/null 2>&1; then
    echo "psql is required to run public URL safety with a direct database URL." >&2
    exit 1
  fi

  for sql_file in "${sql_files[@]}"; do
    echo "Running ${sql_file}"
    psql "${db_url}" \
      --set ON_ERROR_STOP=1 \
      --file "${sql_file}"
  done
} 2>&1 | tee "${log_file}"
