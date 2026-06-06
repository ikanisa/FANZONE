#!/usr/bin/env bash
# Credential-free scheduler smoke for release inventory.
# Validates required cron payloads and deployed anonymous rejection.
set -euo pipefail

tool/run_supabase_cron_job.sh --dry-run settle-match-pools
tool/run_supabase_cron_job.sh --dry-run dispatch-match-alerts
tool/run_supabase_cron_job.sh --dry-run sync-livescore-football
tool/supabase_edge_job_smoke.sh --unauthorized-only

echo "Scheduler payload and unauthorized Edge smoke passed."
