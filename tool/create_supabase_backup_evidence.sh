#!/usr/bin/env bash
# Create a production Supabase backup evidence bundle without printing secrets.
set -euo pipefail

if [[ -z "${SUPABASE_DB_URL:-}" ]]; then
  echo "SUPABASE_DB_URL is required to create backup evidence." >&2
  exit 1
fi

if ! command -v pg_dump >/dev/null 2>&1; then
  echo "pg_dump is required." >&2
  exit 1
fi

if ! command -v pg_restore >/dev/null 2>&1; then
  echo "pg_restore is required." >&2
  exit 1
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
out_dir="output/release-evidence/${timestamp}/backup"
mkdir -p "${out_dir}"

dump_file="${out_dir}/fanzone-public-${timestamp}.dump"
manifest_file="${out_dir}/backup-manifest.txt"

pg_dump "${SUPABASE_DB_URL}" \
  --format=custom \
  --schema=public \
  --no-owner \
  --no-privileges \
  --file="${dump_file}"

pg_restore --list "${dump_file}" >"${out_dir}/restore-list.txt"

{
  echo "created_at_utc=${timestamp}"
  echo "dump_file=${dump_file}"
  if command -v shasum >/dev/null 2>&1; then
    echo "sha256=$(shasum -a 256 "${dump_file}" | awk '{print $1}')"
  elif command -v sha256sum >/dev/null 2>&1; then
    echo "sha256=$(sha256sum "${dump_file}" | awk '{print $1}')"
  fi
  echo "restore_list=${out_dir}/restore-list.txt"
  echo "secret_values_printed=false"
} >"${manifest_file}"

echo "Backup evidence created: ${manifest_file}"
