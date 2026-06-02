#!/usr/bin/env bash
# Run the non-mutating release readiness SQL contract for entertainment,
# rewards, pool settlement, payment submission, and related hardening.
set -euo pipefail

db_url="${SUPABASE_RELEASE_READINESS_DB_URL:-${SUPABASE_DB_URL:-}}"
sql_file="supabase/tests/release_readiness_hardening.sql"

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

if [[ -z "${db_url}" ]]; then
  if [[ -z "${SUPABASE_DB_PASSWORD:-}" ]]; then
    if command -v supabase >/dev/null 2>&1 && [[ -f "supabase/.temp/project-ref" ]]; then
      run_linked_query
      exit $?
    fi
    echo "Set SUPABASE_RELEASE_READINESS_DB_URL or SUPABASE_DB_URL, provide SUPABASE_DB_PASSWORD for the linked pooler URL, or authenticate/link the Supabase CLI." >&2
    exit 1
  fi

  if [[ ! -f "supabase/.temp/pooler-url" ]]; then
    echo "Set SUPABASE_RELEASE_READINESS_DB_URL or SUPABASE_DB_URL, or link the repo to a Supabase project first." >&2
    exit 1
  fi
  pooler_url="$(<supabase/.temp/pooler-url)"
  db_url="${pooler_url/@/:${SUPABASE_DB_PASSWORD}@}"
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "psql is required to run release readiness hardening with a direct database URL." >&2
  exit 1
fi

psql "${db_url}" \
  --set ON_ERROR_STOP=1 \
  --file "${sql_file}"
