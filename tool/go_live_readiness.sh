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
SECRET_PATTERN='(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql://[^[:space:]]+:[^[:space:]]+@)'
if git grep -nE "${SECRET_PATTERN}" -- \
  ':!.github/workflows/ci.yml' \
  ':!.github/workflows/secret-regex-scan.yml' \
  ':!docs/free-account-release.md' \
  ':!docs/secret-rotation-runbook.md' \
  ':!tool/go_live_readiness.sh' \
  ':!.env*.example' \
  ':!**/.env*.example' \
  ':!**/package-lock.json'; then
  echo "Potential live credential found in tracked files." >&2
  exit 1
fi

run tool/full_history_secret_scan.sh
run tool/audit_repo_hygiene.sh

run flutter analyze
run flutter test

run npm run typecheck --workspaces --if-present
run npm run lint --workspaces --if-present
run npm run test --workspaces --if-present
run node tool/test_bff_health.mjs
run npm run build --workspaces --if-present

run deno fmt --check supabase/functions
run_shell "find supabase/functions -name '*.ts' -print0 | xargs -0 deno check"
run deno test --allow-env supabase/functions

run bash -n \
  tool/validate_release_env.sh \
  tool/validate_web_release_env.sh \
  tool/preflight_build_check.sh \
  tool/audit_repo_hygiene.sh \
  tool/full_history_secret_scan.sh \
  tool/verify_deployed_web_surface.sh \
  tool/verify_production_envs.sh \
  tool/create_supabase_backup_evidence.sh \
  tool/collect_world_class_evidence.sh \
  tool/check_world_class_evidence.sh \
  tool/supabase_live_validation.sh \
  tool/supabase_rls_audit.sh \
  tool/supabase_fet_supply_smoke.sh \
  tool/run_supabase_cron_job.sh
run node --check tool/test_bff_health.mjs

echo
echo "Local go-live checks passed."
echo "External/provider tasks still require evidence in docs/release/production-go-live-task-register.md."
