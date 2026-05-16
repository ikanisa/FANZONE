#!/usr/bin/env bash
# Fail closed if the FANZONE world-class evidence matrix is not launch-ready.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MATRIX="${ROOT_DIR}/docs/release/world-class-evidence-matrix.md"

if [[ ! -f "${MATRIX}" ]]; then
  echo "Missing evidence matrix: ${MATRIX}" >&2
  exit 1
fi

failures=0

check_section() {
  local section="$1"
  local body
  body="$(
    awk -v section="## ${section}" '
      $0 == section { in_section=1; next }
      in_section && /^## / { exit }
      in_section { print }
    ' "${MATRIX}"
  )"

  if [[ -z "${body}" ]]; then
    echo "Missing section: ${section}" >&2
    failures=$((failures + 1))
    return
  fi

  while IFS= read -r row; do
    [[ "${row}" != \|* ]] && continue
    [[ "${row}" == *"---"* ]] && continue
    [[ "${row}" == *"| Control |"* ]] && continue

    if [[ "${row}" == *"PENDING"* || "${row}" == *"PARTIAL"* || "${row}" == *"WAIVED"* ]]; then
      echo "${section} is not launch-ready: ${row}" >&2
      failures=$((failures + 1))
    fi

    evidence="$(
      awk -F '|' '{ gsub(/^[[:space:]]+|[[:space:]]+$/, "", $7); print $7 }' <<<"${row}"
    )"
    if [[ -z "${evidence}" ]]; then
      echo "${section} row is missing an evidence reference: ${row}" >&2
      failures=$((failures + 1))
    fi
  done <<<"${body}"
}

check_section "P0 Evidence Matrix"
check_section "P1 Evidence Matrix"

if [[ "${failures}" -ne 0 ]]; then
  echo "World-class evidence gate failed with ${failures} issue(s)." >&2
  exit 1
fi

echo "World-class evidence gate passed."
