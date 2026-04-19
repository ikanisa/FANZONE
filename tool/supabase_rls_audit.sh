#!/usr/bin/env bash
set -euo pipefail

if ! command -v psql >/dev/null 2>&1; then
  echo "psql is required to run the RLS audit."
  exit 1
fi

if [[ ! -f "supabase/.temp/pooler-url" ]]; then
  echo "Missing supabase/.temp/pooler-url. Link the repo to a Supabase project first."
  exit 1
fi

if [[ -z "${SUPABASE_DB_PASSWORD:-}" ]]; then
  echo "SUPABASE_DB_PASSWORD must be set to run the RLS audit."
  exit 1
fi

pooler_url="$(<supabase/.temp/pooler-url)"
db_url="${pooler_url/@/:${SUPABASE_DB_PASSWORD}@}"

psql "${db_url}" \
  --set ON_ERROR_STOP=1 \
  --file "supabase/tests/rls_hardening_audit.sql"
