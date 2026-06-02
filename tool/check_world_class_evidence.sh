#!/usr/bin/env bash
# Fail closed if the FANZONE world-class evidence matrix and backing evidence
# validators are not launch-ready.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MATRIX="${ROOT_DIR}/docs/release/world-class-evidence-matrix.md"
VALIDATORS=(
  "Secret rotation evidence|node|tool/validate_secret_rotation_evidence.mjs"
  "Critical user-flow UAT evidence|node|tool/validate_critical_uat_signoff.mjs"
  "Android release evidence|node|tool/validate_android_release_evidence.mjs"
  "iOS TestFlight evidence|node|tool/validate_ios_testflight_evidence.mjs"
  "Operations readiness evidence|node|tool/validate_operations_readiness_evidence.mjs"
  "Privacy/legal readiness evidence|node|tool/validate_privacy_legal_readiness_evidence.mjs"
  "Load/reliability evidence|node|tool/validate_load_reliability_evidence.mjs"
)

if [[ ! -f "${MATRIX}" ]]; then
  echo "Missing evidence matrix: ${MATRIX}" >&2
  exit 1
fi

failures=0

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "${value}"
}

is_launch_ready_status() {
  case "$1" in
    PASS | N/A) return 0 ;;
    *) return 1 ;;
  esac
}

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

    local leading control flutter venue admin tv evidence trailing
    IFS='|' read -r leading control flutter venue admin tv evidence trailing <<<"${row}"
    control="$(trim "${control}")"
    flutter="$(trim "${flutter}")"
    venue="$(trim "${venue}")"
    admin="$(trim "${admin}")"
    tv="$(trim "${tv}")"
    evidence="$(trim "${evidence}")"

    local status
    for status in "${flutter}" "${venue}" "${admin}" "${tv}"; do
      if ! is_launch_ready_status "${status}"; then
        echo "${section} row is not launch-ready (${control}): ${row}" >&2
        failures=$((failures + 1))
        break
      fi
    done

    if [[ -z "${evidence}" || "${evidence}" == "TBD" ]]; then
      echo "${section} row is missing an evidence reference (${control}): ${row}" >&2
      failures=$((failures + 1))
    fi

    local evidence_lower
    evidence_lower="$(printf '%s' "${evidence}" | tr '[:upper:]' '[:lower:]')"
    if [[ "${evidence_lower}" == *"evidence required"* ]]; then
      echo "${section} row evidence is still an acceptance requirement, not proof (${control}): ${row}" >&2
      failures=$((failures + 1))
    fi
  done <<<"${body}"
}

run_validator() {
  local spec="$1"
  local label command script
  IFS='|' read -r label command script <<<"${spec}"

  echo "==> ${label}: ${command} ${script}"
  if (cd "${ROOT_DIR}" && "${command}" "${script}"); then
    echo "${label} validator passed."
  else
    echo "${label} validator failed." >&2
    failures=$((failures + 1))
  fi
}

check_section "P0 Evidence Matrix"
check_section "P1 Evidence Matrix"

for validator in "${VALIDATORS[@]}"; do
  run_validator "${validator}"
done

if [[ "${failures}" -ne 0 ]]; then
  echo "World-class evidence gate failed with ${failures} issue(s)." >&2
  exit 1
fi

echo "World-class evidence gate passed."
