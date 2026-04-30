BEGIN;

DROP FUNCTION IF EXISTS public.install_openfootball_sync_schedule(
  text,
  text,
  text,
  text,
  jsonb,
  text
);

DROP FUNCTION IF EXISTS public.remove_openfootball_sync_schedule(text);
DROP FUNCTION IF EXISTS public.refresh_materialized_views();

CREATE OR REPLACE FUNCTION public.remove_lean_runtime_schedules()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_job_name text;
  v_job_id bigint;
  v_removed_count integer := 0;
  v_has_cron boolean;
  v_job_names text[] := ARRAY[
    'market-sync-openfootball',
    'fanzone-currency-rates-daily',
    'fanzone-team-news-hourly',
    'cleanup-match-sync-log',
    'refresh-materialized-views',
    'cleanup-old-update-runs',
    'daily-screenshot-odds',
    'fanzone-import-football-data',
    'fanzone-generate-predictions',
    'fanzone-score-predictions',
    'fanzone-dispatch-match-alerts'
  ];
BEGIN
  SELECT exists(SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') INTO v_has_cron;
  IF NOT v_has_cron THEN
    RAISE NOTICE 'pg_cron not enabled, skipping cron job removal';
    RETURN jsonb_build_object('removed_jobs', 0, 'skipped', true);
  END IF;

  FOREACH v_job_name IN ARRAY v_job_names LOOP
    LOOP
      EXECUTE format('SELECT jobid FROM cron.job WHERE jobname = %L LIMIT 1', v_job_name)
      INTO v_job_id;

      EXIT WHEN v_job_id IS NULL;

      PERFORM cron.unschedule(v_job_id);
      v_removed_count := v_removed_count + 1;
      v_job_id := NULL;
    END LOOP;
  END LOOP;

  RETURN jsonb_build_object('removed_jobs', v_removed_count);
END;
$$;

ALTER FUNCTION public.remove_lean_runtime_schedules() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.remove_lean_runtime_schedules() FROM PUBLIC;
GRANT ALL ON FUNCTION public.remove_lean_runtime_schedules() TO service_role;

CREATE OR REPLACE FUNCTION public.install_lean_runtime_schedules(
  p_import_schedule text DEFAULT '0 2 * * *',
  p_generate_schedule text DEFAULT '*/15 * * * *',
  p_score_schedule text DEFAULT '2-59/15 * * * *',
  p_alerts_schedule text DEFAULT '*/5 * * * *'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_project_url text;
  v_cron_secret text;
  v_import_job_id bigint;
  v_generate_job_id bigint;
  v_score_job_id bigint;
  v_alert_job_id bigint;
  v_has_cron boolean;
  v_has_vault boolean;
BEGIN
  SELECT exists(SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') INTO v_has_cron;
  SELECT exists(SELECT 1 FROM pg_extension WHERE extname = 'supabase_vault') INTO v_has_vault;

  IF NOT v_has_cron OR NOT v_has_vault THEN
    RAISE NOTICE 'pg_cron or vault not enabled, skipping schedule installation';
    RETURN jsonb_build_object('skipped', true);
  END IF;

  EXECUTE 'SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = ''fanzone_project_url'' LIMIT 1'
  INTO v_project_url;

  EXECUTE 'SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = ''fanzone_cron_secret'' LIMIT 1'
  INTO v_cron_secret;

  IF coalesce(trim(v_project_url), '') = '' THEN
    RAISE NOTICE 'Missing vault secret fanzone_project_url, skipping schedule installation';
    RETURN jsonb_build_object('skipped', true, 'reason', 'missing_project_url');
  END IF;

  IF coalesce(trim(v_cron_secret), '') = '' THEN
    RAISE NOTICE 'Missing vault secret fanzone_cron_secret, skipping schedule installation';
    RETURN jsonb_build_object('skipped', true, 'reason', 'missing_cron_secret');
  END IF;

  PERFORM public.remove_lean_runtime_schedules();

  v_import_job_id := cron.schedule(
    'fanzone-import-football-data',
    p_import_schedule,
    $cron$
      SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'fanzone_project_url')
          || '/functions/v1/import-football-data',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'fanzone_cron_secret')
        ),
        body := coalesce(
          (SELECT decrypted_secret::jsonb FROM vault.decrypted_secrets WHERE name = 'fanzone_import_payload' LIMIT 1),
          '{"mode":"scheduled"}'::jsonb
        )
      );
    $cron$
  );

  v_generate_job_id := cron.schedule(
    'fanzone-generate-predictions',
    p_generate_schedule,
    $cron$
      SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'fanzone_project_url')
          || '/functions/v1/generate-predictions',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'fanzone_cron_secret')
        ),
        body := '{}'::jsonb
      );
    $cron$
  );

  v_score_job_id := cron.schedule(
    'fanzone-score-predictions',
    p_score_schedule,
    $cron$
      SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'fanzone_project_url')
          || '/functions/v1/score-predictions',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'fanzone_cron_secret')
        ),
        body := '{}'::jsonb
      );
    $cron$
  );

  v_alert_job_id := cron.schedule(
    'fanzone-dispatch-match-alerts',
    p_alerts_schedule,
    $cron$
      SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'fanzone_project_url')
          || '/functions/v1/dispatch-match-alerts',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'fanzone_cron_secret')
        ),
        body := '{}'::jsonb
      );
    $cron$
  );

  RETURN jsonb_build_object(
    'import_job_id', v_import_job_id,
    'generate_job_id', v_generate_job_id,
    'score_job_id', v_score_job_id,
    'alerts_job_id', v_alert_job_id
  );
END;
$$;

ALTER FUNCTION public.install_lean_runtime_schedules(text, text, text, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.install_lean_runtime_schedules(text, text, text, text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.install_lean_runtime_schedules(text, text, text, text) TO service_role;

DELETE FROM public.feature_flags
WHERE key NOT IN (
  'predictions',
  'wallet',
  'leaderboard',
  'rewards',
  'notifications',
  'deep_linking',
  'featured_events',
  'region_discovery'
);

INSERT INTO public.feature_flags (key, market, platform, enabled, rollout_pct, description)
VALUES
  ('predictions', 'global', 'all', true, 100, 'Enable free football predictions'),
  ('wallet', 'global', 'all', true, 100, 'Enable FET wallet balance and transfers'),
  ('leaderboard', 'global', 'all', true, 100, 'Enable public leaderboard surfaces'),
  ('rewards', 'global', 'all', true, 100, 'Enable prediction reward accounting'),
  ('notifications', 'global', 'all', true, 100, 'Enable match and reward notifications'),
  ('deep_linking', 'global', 'all', true, 100, 'Enable deep linking support'),
  ('featured_events', 'global', 'all', true, 100, 'Enable featured event banners'),
  ('region_discovery', 'global', 'all', true, 100, 'Enable region-aware competition discovery')
ON CONFLICT (key, market, platform) DO UPDATE
SET
  enabled = EXCLUDED.enabled,
  rollout_pct = EXCLUDED.rollout_pct,
  description = EXCLUDED.description,
  updated_at = timezone('utc', now());

INSERT INTO public.app_config_remote (key, value)
VALUES
  ('fet_per_eur', '100'::jsonb),
  ('foundation_grant_fet', '50'::jsonb),
  ('wallet_transfer_daily_limit', '10'::jsonb)
ON CONFLICT (key) DO UPDATE
SET
  value = EXCLUDED.value,
  updated_at = timezone('utc', now());

-- Only install schedules if pg_cron is available
DO $$
BEGIN
  IF exists(SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM public.install_lean_runtime_schedules();
  ELSE
    RAISE NOTICE 'pg_cron not enabled, skipping schedule installation';
  END IF;
END;
$$;

COMMIT;
