#!/usr/bin/env bash
set -euo pipefail

if ! command -v psql >/dev/null 2>&1; then
  echo "psql is required to run the bootstrap smoke test."
  exit 1
fi

db_url="${SUPABASE_BOOTSTRAP_DB_URL:-${SUPABASE_DB_URL:-}}"
if [[ -z "${db_url}" ]]; then
  echo "Set SUPABASE_BOOTSTRAP_DB_URL (preferred) or SUPABASE_DB_URL to a disposable/reset database."
  exit 1
fi

echo "Applying repo migrations to bootstrap target..."
if [[ -d "supabase/bootstrap" ]]; then
  while IFS= read -r bootstrap_sql; do
    echo "  -> ${bootstrap_sql}"
    psql "${db_url}" \
      --set ON_ERROR_STOP=1 \
      --file "${bootstrap_sql}"
  done < <(find "supabase/bootstrap" -maxdepth 1 -type f -name '*.sql' | sort)
fi

while IFS= read -r migration; do
  echo "  -> ${migration}"
  psql "${db_url}" \
    --set ON_ERROR_STOP=1 \
    --file "${migration}"
done < <(find "supabase/migrations" -maxdepth 1 -type f -name '*.sql' | sort)

echo "Running bootstrap verification suites..."
psql "${db_url}" --set ON_ERROR_STOP=1 --file "supabase/tests/bootstrap_required_objects.sql"
psql "${db_url}" --set ON_ERROR_STOP=1 --file "supabase/tests/admin_data_plane_verification.sql"
psql "${db_url}" --set ON_ERROR_STOP=1 --file "supabase/tests/whatsapp_auth_verification.sql"

echo "Supabase bootstrap smoke passed."
