-- Non-mutating contract for scheduler run history and missed-run alert data.

DO $$
DECLARE
  v_start_rpc regprocedure := to_regprocedure(
    'public.cron_job_start(text,jsonb)'
  );
  v_finish_rpc regprocedure := to_regprocedure(
    'public.cron_job_finish(uuid,text,jsonb,text)'
  );
  v_snapshot_rpc regprocedure := to_regprocedure(
    'public.admin_scheduler_health_snapshot(timestamp with time zone)'
  );
  v_function_def text;
BEGIN
  IF v_start_rpc IS NULL THEN
    RAISE EXCEPTION 'Missing cron_job_start(text,jsonb)';
  END IF;

  IF v_finish_rpc IS NULL THEN
    RAISE EXCEPTION 'Missing cron_job_finish(uuid,text,jsonb,text)';
  END IF;

  IF v_snapshot_rpc IS NULL THEN
    RAISE EXCEPTION 'Missing admin_scheduler_health_snapshot(timestamptz)';
  END IF;

  IF has_function_privilege('anon', v_start_rpc, 'EXECUTE')
     OR has_function_privilege('authenticated', v_start_rpc, 'EXECUTE') THEN
    RAISE EXCEPTION 'Client roles must not execute cron_job_start';
  END IF;

  IF has_function_privilege('anon', v_finish_rpc, 'EXECUTE')
     OR has_function_privilege('authenticated', v_finish_rpc, 'EXECUTE') THEN
    RAISE EXCEPTION 'Client roles must not execute cron_job_finish';
  END IF;

  IF has_function_privilege('anon', v_snapshot_rpc, 'EXECUTE') THEN
    RAISE EXCEPTION 'Anonymous users must not execute admin_scheduler_health_snapshot';
  END IF;

  IF NOT has_function_privilege('service_role', v_start_rpc, 'EXECUTE')
     OR NOT has_function_privilege('service_role', v_finish_rpc, 'EXECUTE') THEN
    RAISE EXCEPTION 'Service role must execute scheduler run-history RPCs';
  END IF;

  IF NOT has_function_privilege('authenticated', v_snapshot_rpc, 'EXECUTE')
     OR NOT has_function_privilege('service_role', v_snapshot_rpc, 'EXECUTE') THEN
    RAISE EXCEPTION 'Admins/service role must execute admin_scheduler_health_snapshot';
  END IF;

  IF has_table_privilege('anon', 'public.cron_job_log', 'SELECT')
     OR has_table_privilege('authenticated', 'public.cron_job_log', 'SELECT') THEN
    RAISE EXCEPTION 'Client roles must not read raw cron_job_log rows';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.scheduler_job_expectations
    WHERE job_name = 'settle-match-pools'
      AND command = 'tool/run_supabase_cron_job.sh settle-match-pools'
      AND max_lag_minutes > 0
  ) THEN
    RAISE EXCEPTION 'Missing settle-match-pools scheduler expectation';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.scheduler_job_expectations
    WHERE job_name = 'dispatch-match-alerts'
      AND command = 'tool/run_supabase_cron_job.sh dispatch-match-alerts'
      AND max_lag_minutes > 0
  ) THEN
    RAISE EXCEPTION 'Missing dispatch-match-alerts scheduler expectation';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.scheduler_job_expectations
    WHERE job_name = 'sync-livescore-football'
      AND command = 'tool/run_supabase_cron_job.sh sync-livescore-football'
      AND max_lag_minutes > 0
  ) THEN
    RAISE EXCEPTION 'Missing sync-livescore-football scheduler expectation';
  END IF;

  v_function_def := pg_get_functiondef(v_snapshot_rpc);
  IF position('missed_run' in v_function_def) = 0
     OR position('alert_required' in v_function_def) = 0
     OR position('Admin scheduler health snapshot requires a platform admin' in v_function_def) = 0 THEN
    RAISE EXCEPTION 'admin_scheduler_health_snapshot must include missed-run and admin guard logic';
  END IF;
END $$;

SELECT 'scheduler_run_history_alerts_passed' AS result;
