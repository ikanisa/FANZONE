#!/usr/bin/env bash
set -euo pipefail

APP_ENVIRONMENT="${1:-staging}"

PRIMARY_FILE="env/${APP_ENVIRONMENT}.json"
EXAMPLE_FILE="env/${APP_ENVIRONMENT}.example.json"

if [[ -f "${PRIMARY_FILE}" ]]; then
  echo "${PRIMARY_FILE}"
  exit 0
fi

if [[ -f "${EXAMPLE_FILE}" ]]; then
  echo "${EXAMPLE_FILE}"
  exit 0
fi

echo "Missing dart-define file. Expected ${PRIMARY_FILE} or ${EXAMPLE_FILE}." >&2
exit 1
