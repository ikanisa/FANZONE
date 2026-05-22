#!/usr/bin/env bash
# Create a production Supabase backup evidence bundle without printing secrets.
set -euo pipefail

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
out_dir="output/release-evidence/${timestamp}/backup"
mkdir -p "${out_dir}"

pg_dump_bin="${PG_DUMP_BIN:-pg_dump}"
pg_restore_bin="${PG_RESTORE_BIN:-pg_restore}"
if [[ -x "/usr/local/opt/postgresql@17/bin/pg_dump" ]]; then
  pg_dump_bin="${PG_DUMP_BIN:-/usr/local/opt/postgresql@17/bin/pg_dump}"
fi
if [[ -x "/usr/local/opt/postgresql@17/bin/pg_restore" ]]; then
  pg_restore_bin="${PG_RESTORE_BIN:-/usr/local/opt/postgresql@17/bin/pg_restore}"
fi

dump_format="custom"
dump_file="${out_dir}/fanzone-public-${timestamp}.dump"
manifest_file="${out_dir}/backup-manifest.txt"

if [[ -n "${SUPABASE_DB_URL:-}" ]]; then
  if ! command -v "${pg_dump_bin}" >/dev/null 2>&1; then
    echo "pg_dump is required when SUPABASE_DB_URL is used." >&2
    exit 1
  fi

  if ! command -v "${pg_restore_bin}" >/dev/null 2>&1; then
    echo "pg_restore is required when SUPABASE_DB_URL is used." >&2
    exit 1
  fi

  "${pg_dump_bin}" "${SUPABASE_DB_URL}" \
    --format=custom \
    --schema=public \
    --role=postgres \
    --no-owner \
    --no-privileges \
    --file="${dump_file}"

  "${pg_restore_bin}" --list "${dump_file}" >"${out_dir}/restore-list.txt"
elif [[ -f "supabase/.temp/project-ref" ]]; then
  if ! command -v "${pg_dump_bin}" >/dev/null 2>&1; then
    echo "pg_dump is required." >&2
    exit 1
  fi

  if ! command -v "${pg_restore_bin}" >/dev/null 2>&1; then
    echo "pg_restore is required." >&2
    exit 1
  fi

  tmp_script="$(mktemp)"
  tmp_env="$(mktemp)"
  chmod 600 "${tmp_script}"
  chmod 600 "${tmp_env}"
  trap 'rm -f "${tmp_script}" "${tmp_env}"' EXIT

  supabase db dump --linked --schema public --dry-run >"${tmp_script}"
  grep -E '^export PG(HOST|PORT|USER|PASSWORD|DATABASE)=' "${tmp_script}" >"${tmp_env}"

  # The CLI dry-run includes temporary PG* connection exports. Source only
  # those exports, then run pg_dump locally so no secret values are printed.
  # shellcheck source=/dev/null
  source "${tmp_env}"

  "${pg_dump_bin}" \
    --format=custom \
    --schema=public \
    --role=postgres \
    --no-owner \
    --no-privileges \
    --file="${dump_file}"

  "${pg_restore_bin}" --list "${dump_file}" >"${out_dir}/restore-list.txt"
else
  echo "SUPABASE_DB_URL or a linked Supabase CLI project is required to create backup evidence." >&2
  exit 1
fi

{
  echo "created_at_utc=${timestamp}"
  echo "dump_format=${dump_format}"
  echo "dump_file=${dump_file}"
  echo "pg_dump_version=$("${pg_dump_bin}" --version)"
  if command -v shasum >/dev/null 2>&1; then
    echo "sha256=$(shasum -a 256 "${dump_file}" | awk '{print $1}')"
  elif command -v sha256sum >/dev/null 2>&1; then
    echo "sha256=$(sha256sum "${dump_file}" | awk '{print $1}')"
  fi
  echo "restore_list=${out_dir}/restore-list.txt"
  echo "secret_values_printed=false"
} >"${manifest_file}"

echo "Backup evidence created: ${manifest_file}"
