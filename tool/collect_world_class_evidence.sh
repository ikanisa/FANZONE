#!/usr/bin/env bash
# Collect non-destructive production evidence for FANZONE release review.
set -euo pipefail

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
out_dir="output/release-evidence/${timestamp}"
mkdir -p "${out_dir}"
failures=0

run_and_capture() {
  local name="$1"
  shift
  echo "==> ${name}"
  if "$@" >"${out_dir}/${name}.log" 2>&1; then
    echo "PASS ${name}" | tee -a "${out_dir}/summary.txt"
  else
    echo "FAIL ${name} (see ${out_dir}/${name}.log)" | tee -a "${out_dir}/summary.txt"
    failures=$((failures + 1))
  fi
}

optional_url_check() {
  local name="$1"
  local surface="$2"
  local url="${3:-}"
  if [[ -z "${url}" ]]; then
    echo "PENDING ${name} (URL env not set)" | tee -a "${out_dir}/summary.txt"
    return 0
  fi
  run_and_capture "${name}" tool/verify_deployed_web_surface.sh "${surface}" "${url}"
}

has_env_name() {
  local name="$1"
  [[ -n "${!name:-}" ]] && return 0
  [[ -f ".env" ]] && grep -Eq "^${name}=" ".env" && return 0
  return 1
}

echo "FANZONE world-class production evidence run: ${timestamp}" >"${out_dir}/summary.txt"
echo "secret_values_printed=false" >>"${out_dir}/summary.txt"

run_and_capture "full_history_secret_scan" tool/full_history_secret_scan.sh

if [[ -f ".env.production" ]]; then
  run_and_capture "production_env_isolation" tool/verify_production_envs.sh .env.production
else
  echo "PENDING production_env_isolation (.env.production not present)" | tee -a "${out_dir}/summary.txt"
fi

if [[ -n "${SUPABASE_DB_URL:-}" || -f "supabase/.temp/project-ref" ]]; then
  run_and_capture "supabase_live_validation" tool/supabase_live_validation.sh
else
  echo "PENDING supabase_live_validation (SUPABASE_DB_URL/link not available)" | tee -a "${out_dir}/summary.txt"
fi

optional_url_check "website_deployed_headers" website "${FANZONE_WEBSITE_URL:-}"
optional_url_check "admin_deployed_bff_headers" admin "${FANZONE_ADMIN_URL:-}"
optional_url_check "venue_deployed_bff_headers" venue-portal "${FANZONE_VENUE_PORTAL_URL:-}"
optional_url_check "tv_deployed_headers" tv-display "${FANZONE_TV_DISPLAY_URL:-}"

if has_env_name "SUPABASE_URL" && has_env_name "CRON_SECRET"; then
  run_and_capture "cron_settle_match_pools" tool/run_supabase_cron_job.sh settle-match-pools
  run_and_capture "cron_dispatch_match_alerts" tool/run_supabase_cron_job.sh dispatch-match-alerts
else
  echo "PENDING cron_smoke (SUPABASE_URL/CRON_SECRET not set in environment or .env)" | tee -a "${out_dir}/summary.txt"
fi

if [[ -n "${SUPABASE_DB_URL:-}" || -f "supabase/.temp/project-ref" ]]; then
  run_and_capture "backup_evidence" tool/create_supabase_backup_evidence.sh
else
  echo "PENDING backup_evidence (SUPABASE_DB_URL/link not available)" | tee -a "${out_dir}/summary.txt"
fi

echo "Evidence summary: ${out_dir}/summary.txt"

if [[ "${failures}" -ne 0 ]]; then
  echo "Evidence collection completed with ${failures} failing check(s)." >&2
  exit 1
fi
