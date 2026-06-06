-- Scheduler run history, missed-run detection, and admin-only health snapshot.

CREATE TABLE IF NOT EXISTS public.scheduler_job_expectations (
  job_name text PRIMARY KEY,
  command text NOT NULL,
  provider text NOT NULL DEFAULT 'supabase_edge_cron',
  schedule_expression text NOT NULL,
  timezone text NOT NULL DEFAULT 'UTC',
  max_lag_minutes integer NOT NULL CHECK (max_lag_minutes > 0),
  missed_run_severity text NOT NULL DEFAULT 'high'
    CHECK (missed_run_severity IN ('low', 'medium', 'high', 'critical')),
  owner_label text NOT NULL DEFAULT 'operations-owner',
  backup_owner_label text NOT NULL DEFAULT 'incident-commander',
  is_active boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

INSERT INTO public.scheduler_job_expectations (
  job_name,
  command,
  provider,
  schedule_expression,
  timezone,
  max_lag_minutes,
  missed_run_severity,
  owner_label,
  backup_owner_label
)
VALUES
  (
    'settle-match-pools',
    'tool/run_supabase_cron_job.sh settle-match-pools',
    'supabase_edge_cron',
    'every 15 minutes',
    'UTC',
    45,
    'high',
    'operations-owner',
    'incident-commander'
  ),
  (
    'dispatch-match-alerts',
    'tool/run_supabase_cron_job.sh dispatch-match-alerts',
    'supabase_edge_cron',
    'every 5 minutes',
    'UTC',
    20,
    'high',
    'operations-owner',
    'incident-commander'
  ),
  (
    'sync-livescore-football',
    'tool/run_supabase_cron_job.sh sync-livescore-football',
    'supabase_edge_cron',
    'hourly during active football windows',
    'UTC',
    180,
    'high',
    'operations-owner',
    'incident-commander'
  )
ON CONFLICT (job_name) DO UPDATE SET
  command = EXCLUDED.command,
  provider = EXCLUDED.provider,
  schedule_expression = EXCLUDED.schedule_expression,
  timezone = EXCLUDED.timezone,
  max_lag_minutes = EXCLUDED.max_lag_minutes,
  missed_run_severity = EXCLUDED.missed_run_severity,
  owner_label = EXCLUDED.owner_label,
  backup_owner_label = EXCLUDED.backup_owner_label,
  is_active = true,
  updated_at = timezone('utc', now());

CREATE INDEX IF NOT EXISTS idx_scheduler_job_expectations_active
  ON public.scheduler_job_expectations (is_active, job_name);

REVOKE ALL ON TABLE public.cron_job_log FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.cron_job_log TO service_role;

REVOKE ALL ON TABLE public.scheduler_job_expectations FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.scheduler_job_expectations TO service_role;

CREATE OR REPLACE FUNCTION public.cron_job_start(
  p_job_name text,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_run_id uuid;
BEGIN
  IF coalesce(auth.role(), '') <> 'service_role' THEN
    RAISE EXCEPTION 'cron_job_start requires service role';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.scheduler_job_expectations
    WHERE job_name = p_job_name
      AND is_active = true
  ) THEN
    RAISE EXCEPTION 'Unknown scheduler job: %', p_job_name;
  END IF;

  INSERT INTO public.cron_job_log (
    job_name,
    status,
    started_at,
    result
  )
  VALUES (
    p_job_name,
    'running',
    timezone('utc', now()),
    jsonb_build_object(
      'metadata', coalesce(p_metadata, '{}'::jsonb),
      'source', 'edge_function'
    )
  )
  RETURNING id INTO v_run_id;

  RETURN v_run_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.cron_job_finish(
  p_run_id uuid,
  p_status text,
  p_result jsonb DEFAULT '{}'::jsonb,
  p_error_message text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_started_at timestamptz;
BEGIN
  IF coalesce(auth.role(), '') <> 'service_role' THEN
    RAISE EXCEPTION 'cron_job_finish requires service role';
  END IF;

  IF p_status NOT IN ('completed', 'failed') THEN
    RAISE EXCEPTION 'cron_job_finish status must be completed or failed';
  END IF;

  SELECT started_at INTO v_started_at
  FROM public.cron_job_log
  WHERE id = p_run_id
  FOR UPDATE;

  IF v_started_at IS NULL THEN
    RAISE EXCEPTION 'Unknown scheduler run: %', p_run_id;
  END IF;

  UPDATE public.cron_job_log
  SET
    status = p_status,
    completed_at = timezone('utc', now()),
    duration_ms = greatest(
      0,
      extract(epoch FROM (timezone('utc', now()) - v_started_at))::integer * 1000
    ),
    result = coalesce(p_result, '{}'::jsonb),
    error_message = CASE
      WHEN p_error_message IS NULL THEN NULL
      ELSE left(p_error_message, 1000)
    END
  WHERE id = p_run_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_scheduler_health_snapshot(
  p_now timestamptz DEFAULT timezone('utc', now())
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_claim_role text := coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb ->> 'role',
    auth.role(),
    ''
  );
  v_jobs jsonb;
BEGIN
  IF coalesce(v_claim_role, '') <> 'service_role'
     AND NOT public.is_admin_manager(v_actor) THEN
    RAISE EXCEPTION 'Admin scheduler health snapshot requires a platform admin';
  END IF;

  WITH latest_any AS (
    SELECT DISTINCT ON (job_name)
      job_name,
      status,
      started_at,
      completed_at,
      duration_ms,
      error_message
    FROM public.cron_job_log
    ORDER BY job_name, started_at DESC
  ),
  latest_success AS (
    SELECT DISTINCT ON (job_name)
      job_name,
      completed_at
    FROM public.cron_job_log
    WHERE status = 'completed'
      AND completed_at IS NOT NULL
    ORDER BY job_name, completed_at DESC
  ),
  latest_failure AS (
    SELECT DISTINCT ON (job_name)
      job_name,
      completed_at,
      error_message
    FROM public.cron_job_log
    WHERE status = 'failed'
    ORDER BY job_name, coalesce(completed_at, started_at) DESC
  )
  SELECT jsonb_agg(
    jsonb_build_object(
      'job_name', e.job_name,
      'command', e.command,
      'provider', e.provider,
      'schedule_expression', e.schedule_expression,
      'timezone', e.timezone,
      'max_lag_minutes', e.max_lag_minutes,
      'owner_label', e.owner_label,
      'backup_owner_label', e.backup_owner_label,
      'last_status', la.status,
      'last_started_at', la.started_at,
      'last_completed_at', ls.completed_at,
      'last_failed_at', lf.completed_at,
      'duration_ms', la.duration_ms,
      'missed_run', (
        ls.completed_at IS NULL
        OR ls.completed_at < p_now - make_interval(mins => e.max_lag_minutes)
      ),
      'alert_required', (
        ls.completed_at IS NULL
        OR ls.completed_at < p_now - make_interval(mins => e.max_lag_minutes)
        OR la.status = 'failed'
      ),
      'severity', CASE
        WHEN ls.completed_at IS NULL
          OR ls.completed_at < p_now - make_interval(mins => e.max_lag_minutes)
          OR la.status = 'failed'
        THEN e.missed_run_severity
        ELSE 'ok'
      END,
      'health_status', CASE
        WHEN ls.completed_at IS NULL THEN 'missing_history'
        WHEN ls.completed_at < p_now - make_interval(mins => e.max_lag_minutes) THEN 'missed_run'
        WHEN la.status = 'failed' THEN 'last_run_failed'
        ELSE 'healthy'
      END
    )
    ORDER BY e.job_name
  )
  INTO v_jobs
  FROM public.scheduler_job_expectations e
  LEFT JOIN latest_any la USING (job_name)
  LEFT JOIN latest_success ls USING (job_name)
  LEFT JOIN latest_failure lf USING (job_name)
  WHERE e.is_active = true;

  RETURN jsonb_build_object(
    'generated_at', p_now,
    'jobs', coalesce(v_jobs, '[]'::jsonb),
    'missed_run_count',
      coalesce((
        SELECT count(*)
        FROM jsonb_array_elements(coalesce(v_jobs, '[]'::jsonb)) AS job
        WHERE coalesce((job ->> 'missed_run')::boolean, false)
      ), 0),
    'alert_required_count',
      coalesce((
        SELECT count(*)
        FROM jsonb_array_elements(coalesce(v_jobs, '[]'::jsonb)) AS job
        WHERE coalesce((job ->> 'alert_required')::boolean, false)
      ), 0)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.cron_job_start(text, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cron_job_start(text, jsonb) TO service_role;

REVOKE ALL ON FUNCTION public.cron_job_finish(uuid, text, jsonb, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cron_job_finish(uuid, text, jsonb, text) TO service_role;

REVOKE ALL ON FUNCTION public.admin_scheduler_health_snapshot(timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_scheduler_health_snapshot(timestamptz)
  TO authenticated, service_role;

COMMENT ON FUNCTION public.cron_job_start(text, jsonb)
  IS 'Starts a backend-only scheduler run-history record for Edge cron jobs.';
COMMENT ON FUNCTION public.cron_job_finish(uuid, text, jsonb, text)
  IS 'Finishes a backend-only scheduler run-history record with bounded result/error payloads.';
COMMENT ON FUNCTION public.admin_scheduler_health_snapshot(timestamptz)
  IS 'Admin-only scheduler history and missed-run alert snapshot for operations dashboards.';
