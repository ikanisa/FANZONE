#!/usr/bin/env bash
# Verify release evidence gates agree with the current matrix state.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MATRIX="${ROOT_DIR}/docs/release/world-class-evidence-matrix.md"
GATE="${ROOT_DIR}/tool/check_world_class_evidence.sh"

if [[ ! -f "${MATRIX}" ]]; then
  echo "Missing evidence matrix: ${MATRIX}" >&2
  exit 1
fi

if [[ ! -x "${GATE}" ]]; then
  echo "Missing executable world-class gate: ${GATE}" >&2
  exit 1
fi

matrix_has_blockers=false
if awk '
  /^## P[01] Evidence Matrix$/ { in_scope=1; next }
  /^## / { in_scope=0 }
  in_scope && /^\|/ && $0 !~ /\| ---/ && $0 !~ /\| Control \|/ {
    if ($0 ~ /PENDING|PARTIAL|WAIVED|evidence required/) found=1
  }
  END { exit found ? 0 : 1 }
' "${MATRIX}"; then
  matrix_has_blockers=true
fi

gate_log="$(mktemp "${TMPDIR:-/tmp}/fanzone-world-class-gate.XXXXXX")"
trap 'rm -f "${gate_log}"' EXIT

if "${GATE}" >"${gate_log}" 2>&1; then
  if [[ "${matrix_has_blockers}" == true ]]; then
    echo "World-class gate passed even though the P0/P1 matrix still has blockers." >&2
    cat "${gate_log}" >&2
    exit 1
  fi
else
  if [[ "${matrix_has_blockers}" != true ]]; then
    echo "World-class gate failed even though the P0/P1 matrix has no textual blockers." >&2
    cat "${gate_log}" >&2
    exit 1
  fi
fi

echo "Release evidence contract validation passed."
