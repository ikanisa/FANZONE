#!/usr/bin/env bash
set -euo pipefail

if ! command -v psql >/dev/null 2>&1; then
  echo "psql is required to run the FET supply smoke test."
  exit 1
fi

db_url="${SUPABASE_FET_DB_URL:-${SUPABASE_DB_URL:-}}"

if [[ -z "${db_url}" ]]; then
  if [[ ! -f "supabase/.temp/pooler-url" ]]; then
    echo "Set SUPABASE_FET_DB_URL or SUPABASE_DB_URL, or link the repo to a Supabase project first."
    exit 1
  fi

  if [[ -z "${SUPABASE_DB_PASSWORD:-}" ]]; then
    echo "SUPABASE_DB_PASSWORD must be set when SUPABASE_FET_DB_URL or SUPABASE_DB_URL is not provided."
    exit 1
  fi

  pooler_url="$(<supabase/.temp/pooler-url)"
  db_url="${pooler_url/@/:${SUPABASE_DB_PASSWORD}@}"
fi

psql "${db_url}" \
  --set ON_ERROR_STOP=1 \
  --file "supabase/tests/fet_supply_cap_smoke.sql"
