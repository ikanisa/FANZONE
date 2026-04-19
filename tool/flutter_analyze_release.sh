#!/usr/bin/env bash
set -euo pipefail

OUTPUT_FILE="$(mktemp)"
trap 'rm -f "${OUTPUT_FILE}"' EXIT

ANALYZE_STATUS=0
dart analyze --format machine >"${OUTPUT_FILE}" || ANALYZE_STATUS=$?

cat "${OUTPUT_FILE}"

if rg -q '^(ERROR|WARNING)\|' "${OUTPUT_FILE}"; then
  echo "Release analyzer gate failed: warning or error diagnostics are present." >&2
  exit 1
fi

if [[ ${ANALYZE_STATUS} -ne 0 ]] && ! rg -q '^(INFO|WARNING|ERROR)\|' "${OUTPUT_FILE}"; then
  echo "dart analyze exited unexpectedly with status ${ANALYZE_STATUS}." >&2
  exit "${ANALYZE_STATUS}"
fi

INFO_COUNT="$(rg -c '^INFO\|' "${OUTPUT_FILE}" || true)"
echo "Release analyzer gate passed with ${INFO_COUNT} info-level diagnostics."
