#!/usr/bin/env bash
# Non-destructive FANZONE local go-live readiness gate.
set -euo pipefail

MODE="${1:---local}"

if [[ "${MODE}" != "--local" ]]; then
  echo "Usage: $0 --local" >&2
  echo "This script runs local, non-mutating checks only. Provider evidence is tracked in docs/release/production-go-live-task-register.md." >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

run() {
  echo
  echo "==> $*"
  "$@"
}

run_shell() {
  echo
  echo "==> $*"
  bash -lc "$*"
}

echo "FANZONE local go-live readiness gate"
echo "Repo: ${ROOT_DIR}"

run git status --short

if [[ -n "$(git status --short)" ]]; then
  echo "Working tree is not clean. Commit or stash changes before release." >&2
  exit 1
fi

echo
echo "==> tracked-file secret regex scan"
SECRET_JWT_PATTERN='eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}'
SECRET_PAT_PATTERN='sbp_[A-Za-z0-9_-]{20,}'
SECRET_DB_PATTERN='postgresql:/{2}[^[:space:]]+:[^[:space:]]+@'
SECRET_PATTERN="(${SECRET_JWT_PATTERN}|${SECRET_PAT_PATTERN}|${SECRET_DB_PATTERN})"
if git grep -nE "${SECRET_PATTERN}" -- \
  ':!.github/workflows/ci.yml' \
  ':!.github/workflows/secret-regex-scan.yml' \
  ':!docs/free-account-release.md' \
  ':!docs/secret-rotation-runbook.md' \
  ':!tool/go_live_readiness.sh' \
  ':!tool/full_history_secret_scan.sh' \
  ':!tool/mobile_release_static_audit.sh' \
  ':!.env*.example' \
  ':!**/.env*.example' \
  ':!**/package-lock.json'; then
  echo "Potential live credential found in tracked files." >&2
  exit 1
fi

run tool/full_history_secret_scan.sh
run tool/audit_repo_hygiene.sh
run tool/product_boundary_scan.sh
run tool/mobile_release_static_audit.sh

run flutter analyze
run flutter test --coverage

run npm run typecheck --workspaces --if-present
run npm run lint --workspaces --if-present
run npm run test --workspaces --if-present
run node tool/test_bff_health.mjs
run npm run build --workspaces --if-present

run deno fmt --check supabase/functions
run_shell "find supabase/functions -name '*.ts' -print0 | xargs -0 deno check"
run deno test --allow-env supabase/functions
run deno test test/core_order_lifecycle_test.ts

run bash -n \
  tool/validate_release_env.sh \
  tool/validate_web_release_env.sh \
  tool/preflight_build_check.sh \
  tool/audit_repo_hygiene.sh \
  tool/product_boundary_scan.sh \
  tool/mobile_release_static_audit.sh \
  tool/android_deep_link_smoke.sh \
  tool/android_signature_verify.sh \
  tool/full_history_secret_scan.sh \
  tool/verify_deployed_web_surface.sh \
  tool/verify_production_envs.sh \
  tool/create_supabase_backup_evidence.sh \
  tool/generate_release_baseline_inventory.sh \
  tool/collect_world_class_evidence.sh \
  tool/check_world_class_evidence.sh \
  tool/validate_release_evidence_contract.sh \
  tool/supabase_live_validation.sh \
  tool/supabase_rls_audit.sh \
  tool/supabase_fet_supply_smoke.sh \
  tool/supabase_release_readiness_hardening.sh \
  tool/supabase_hospitality_core_phase2.sh \
  tool/supabase_order_lifecycle_smoke.sh \
  tool/supabase_manual_payment_reconciliation_smoke.sh \
  tool/supabase_staff_call_acknowledgement_smoke.sh \
  tool/supabase_api_authorization_abuse_tests.sh \
  tool/supabase_whatsapp_auth_smoke.sh \
  tool/run_supabase_cron_job.sh \
  tool/generate_incident_readiness_bundle.mjs \
  tool/supabase_app_edge_smoke.sh \
  tool/supabase_game_edge_smoke.sh \
  tool/supabase_observability_telemetry_hardening.sh \
  tool/supabase_operations_observability_snapshot.sh
run node --check tool/test_bff_health.mjs
run node --check tool/validate_edge_function_release_contract.mjs
run node --check tool/validate_secret_rotation_evidence.mjs
run node --check tool/validate_critical_uat_signoff.mjs
run node --check tool/validate_ios_testflight_evidence.mjs
run node --check tool/validate_android_release_evidence.mjs
run node --check tool/validate_android_device_uat_evidence.mjs
run node tool/validate_android_device_uat_evidence.mjs
run node --check tool/validate_mobile_backend_uat_evidence.mjs
run node tool/validate_mobile_backend_uat_evidence.mjs
run node --check tool/validate_mobile_security_code_evidence.mjs
run node tool/validate_mobile_security_code_evidence.mjs
run node --check tool/validate_api_authorization_abuse_evidence.mjs
run node tool/validate_api_authorization_abuse_evidence.mjs
run node --check tool/validate_android_review_metadata.mjs
run node --check tool/validate_operations_readiness_evidence.mjs
run node --check tool/generate_scheduler_workflow_code_evidence.mjs
run node --check tool/validate_scheduler_platform_manifest.mjs
run node tool/validate_scheduler_platform_manifest.mjs
run node --check tool/capture_scheduler_provider_state.mjs
run node --check tool/validate_scheduler_provider_state_evidence.mjs
run node tool/validate_scheduler_provider_state_evidence.mjs
run node --check tool/validate_scheduler_workflow_code_evidence.mjs
run node tool/validate_scheduler_workflow_code_evidence.mjs
run node --check tool/validate_scheduler_post_deploy_audit_smoke.mjs
run node tool/validate_scheduler_post_deploy_audit_smoke.mjs
run node --check tool/validate_cron_smoke_evidence.mjs
run node tool/validate_cron_smoke_evidence.mjs
run node --check tool/validate_observability_telemetry_code_evidence.mjs
run node tool/validate_observability_telemetry_code_evidence.mjs
run node --check tool/validate_operations_observability_snapshot_evidence.mjs
run node tool/validate_operations_observability_snapshot_evidence.mjs
run node --check tool/validate_incident_rollback_code_evidence.mjs
run node tool/validate_incident_rollback_code_evidence.mjs
run node --check tool/validate_whatsapp_otp_evidence.mjs
run node tool/validate_whatsapp_otp_evidence.mjs
run node --check tool/validate_settings_support_navigation_evidence.mjs
run node tool/validate_settings_support_navigation_evidence.mjs
run node --check tool/validate_onboarding_fan_profile_evidence.mjs
run node tool/validate_onboarding_fan_profile_evidence.mjs
run node --check tool/validate_current_fullstack_supabase_evidence.mjs
run node tool/validate_current_fullstack_supabase_evidence.mjs
run node --check tool/capture_edge_cors_smoke.mjs
run node --check tool/validate_edge_cors_smoke_evidence.mjs
run node tool/validate_edge_cors_smoke_evidence.mjs
run node --check tool/capture_admin_auth_deploy_smoke.mjs
run node --check tool/validate_admin_auth_deploy_smoke_evidence.mjs
run node tool/validate_admin_auth_deploy_smoke_evidence.mjs
run node --check tool/validate_flutter_coverage_evidence.mjs
run node tool/validate_flutter_coverage_evidence.mjs
run node --check tool/validate_games_livescore_fullstack_evidence.mjs
run node tool/validate_games_livescore_fullstack_evidence.mjs
run node --check tool/validate_onboarding_team_catalog_evidence.mjs
run node tool/validate_onboarding_team_catalog_evidence.mjs
run node --check tool/supabase_team_catalog_smoke.mjs
run node --check tool/validate_privacy_public_surface_copy.mjs
run node tool/validate_privacy_public_surface_copy.mjs
run node --check tool/validate_privacy_legal_readiness_evidence.mjs
run node --check tool/validate_privacy_legal_code_evidence.mjs
run node tool/validate_privacy_legal_code_evidence.mjs
run node --check tool/validate_load_reliability_evidence.mjs
run node tool/validate_edge_function_release_contract.mjs

echo
echo "Local go-live checks passed."
echo "External/provider tasks still require evidence in docs/release/production-go-live-task-register.md."
