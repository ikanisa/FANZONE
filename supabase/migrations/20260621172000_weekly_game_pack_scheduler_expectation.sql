-- Add weekly AI game-pack generation to scheduler health expectations.

INSERT INTO public.scheduler_job_expectations (
  job_name,
  command,
  schedule_expression,
  max_lag_minutes,
  missed_run_severity,
  owner_label,
  backup_owner_label
)
VALUES (
  'generate-weekly-game-packs',
  'tool/run_supabase_cron_job.sh generate-weekly-game-packs',
  'weekly Monday 03:17 UTC',
  10080,
  'high',
  'games-operations-owner',
  'incident-commander'
)
ON CONFLICT (job_name) DO UPDATE
SET command = EXCLUDED.command,
    schedule_expression = EXCLUDED.schedule_expression,
    max_lag_minutes = EXCLUDED.max_lag_minutes,
    missed_run_severity = EXCLUDED.missed_run_severity,
    owner_label = EXCLUDED.owner_label,
    backup_owner_label = EXCLUDED.backup_owner_label,
    updated_at = timezone('utc', now());
