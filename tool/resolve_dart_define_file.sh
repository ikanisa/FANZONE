#!/usr/bin/env bash
set -euo pipefail

APP_ENVIRONMENT="${1:-staging}"

PRIMARY_FILE="env/${APP_ENVIRONMENT}.json"
EXAMPLE_FILE="env/${APP_ENVIRONMENT}.example.json"

contains_placeholders() {
  local file="$1"
  rg -q \
    'https://your-project-ref\.supabase\.co|your-anon-key|REPLACE_WITH|YOUR_' \
    "${file}"
}

if [[ -f "${PRIMARY_FILE}" ]]; then
  if contains_placeholders "${PRIMARY_FILE}"; then
    echo "Refusing to use ${PRIMARY_FILE}: it still contains placeholder values." >&2
    exit 1
  fi

  echo "${PRIMARY_FILE}"
  exit 0
fi

if [[ -f "${EXAMPLE_FILE}" ]]; then
  echo "Refusing to use ${EXAMPLE_FILE} for ${APP_ENVIRONMENT}." >&2
  echo "Create ${PRIMARY_FILE} from the example and replace all placeholder values first." >&2
  exit 1
fi

echo "Missing dart-define file. Expected ${PRIMARY_FILE}." >&2
exit 1
