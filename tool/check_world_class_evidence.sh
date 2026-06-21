#!/usr/bin/env bash
# Fail closed if the FANZONE world-class evidence matrix and backing evidence
# validators are not launch-ready.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MATRIX="${ROOT_DIR}/docs/release/world-class-evidence-matrix.md"
VALIDATORS=(
  "Secret rotation evidence|node|tool/validate_secret_rotation_evidence.mjs"
  "Critical user-flow UAT evidence|node|tool/validate_critical_uat_signoff.mjs"
  "WhatsApp OTP evidence|node|tool/validate_whatsapp_otp_evidence.mjs"
  "Settings support navigation evidence|node|tool/validate_settings_support_navigation_evidence.mjs"
  "Onboarding fan profile evidence|node|tool/validate_onboarding_fan_profile_evidence.mjs"
  "Privacy/legal code evidence|node|tool/validate_privacy_legal_code_evidence.mjs"
  "Current fullstack Supabase evidence|node|tool/validate_current_fullstack_supabase_evidence.mjs"
  "Edge CORS smoke evidence|node|tool/validate_edge_cors_smoke_evidence.mjs"
  "Admin auth deployment smoke evidence|node|tool/validate_admin_auth_deploy_smoke_evidence.mjs"
  "Flutter coverage evidence|node|tool/validate_flutter_coverage_evidence.mjs"
  "Flutter mobile UX summary|node|tool/generate_flutter_mobile_ux_summary.mjs"
  "Flutter mobile UX matrix inventory|node|tool/validate_flutter_mobile_ux_matrix.mjs"
  "Fullstack platform completion inventory|node|tool/validate_fullstack_platform_completion_matrix.mjs"
  "Games/LiveScore fullstack evidence|node|tool/validate_games_livescore_fullstack_evidence.mjs"
  "Android device UAT evidence|node|tool/validate_android_device_uat_evidence.mjs"
  "Mobile backend UAT evidence|node|tool/validate_mobile_backend_uat_evidence.mjs"
  "Mobile security code evidence|node|tool/validate_mobile_security_code_evidence.mjs"
  "API authorization abuse evidence|node|tool/validate_api_authorization_abuse_evidence.mjs"
  "Android release evidence|node|tool/validate_android_release_evidence.mjs"
  "Cron smoke evidence|node|tool/validate_cron_smoke_evidence.mjs"
  "Scheduler platform manifest evidence|node|tool/validate_scheduler_platform_manifest.mjs"
  "Scheduler provider state evidence|node|tool/validate_scheduler_provider_state_evidence.mjs"
  "Scheduler workflow code evidence|node|tool/validate_scheduler_workflow_code_evidence.mjs"
  "Scheduler post-deploy audit smoke evidence|node|tool/validate_scheduler_post_deploy_audit_smoke.mjs"
  "Observability telemetry code evidence|node|tool/validate_observability_telemetry_code_evidence.mjs"
  "Operations observability snapshot evidence|node|tool/validate_operations_observability_snapshot_evidence.mjs"
  "Incident rollback code evidence|node|tool/validate_incident_rollback_code_evidence.mjs"
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
