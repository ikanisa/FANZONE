#!/usr/bin/env bash
set -euo pipefail

lint_args=(--schema public --fail-on error)
if [[ -n "${SUPABASE_DB_URL:-}" ]]; then
  lint_args=(--db-url "${SUPABASE_DB_URL}" "${lint_args[@]}")
elif [[ -f "supabase/.temp/project-ref" ]]; then
  lint_args=(--linked "${lint_args[@]}")
else
  echo "Set SUPABASE_DB_URL or link the Supabase CLI before running live validation." >&2
  exit 1
fi

supabase db lint "${lint_args[@]}"
./tool/supabase_rls_audit.sh
./tool/supabase_fet_supply_smoke.sh
