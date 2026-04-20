BEGIN;

-- ============================================================
-- Gemini API Cost Optimization Migration
-- 1. Calendar-gated match sync (skip when no live matches)
-- 2. Currency rate daily cron
-- 3. Team news hourly dispatcher + cron
-- ============================================================

-- ------------------------------------------------------------------
-- 1. Calendar-gated match sync wrapper
-- ------------------------------------------------------------------
-- This function checks if ANY matches are in the live window before
-- invoking the real (expensive) sync cycle. If no matches are live,
-- it returns immediately with zero Gemini API cost.

CREATE OR REPLACE FUNCTION public.run_match_sync_cycle_if_live(
  p_fetch_type text DEFAULT 'events',
  p_limit integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_now timestamptz := timezone('utc', now());
  v_live_window integer;
  v_live_count integer;
  v_result jsonb;
BEGIN
  -- Get runtime settings
  SELECT live_window_after_kickoff_minutes
  INTO v_live_window
  FROM public.match_sync_runtime_settings
  LIMIT 1;
  v_live_window := coalesce(v_live_window, 210);

  -- Count matches that are currently live or about to kick off
  -- Uses direct column math since match_kickoff_at_utc may not exist
  SELECT count(*) INTO v_live_count
  FROM public.matches m
  WHERE public.normalize_match_status_value(m.status)
        NOT IN ('finished', 'cancelled', 'postponed')
    AND (
      -- Already marked as live
      public.normalize_match_status_value(m.status) = 'live'
      -- OR kickoff is within the live window (past) or imminent (15m future buffer)
      OR (m.date + coalesce(m.kickoff_time, '00:00:00'::time))::timestamptz
         BETWEEN v_now - make_interval(mins => v_live_window)
             AND v_now + interval '15 minutes'
    );

  -- If no live or imminent matches, skip entirely (zero Gemini cost)
  IF v_live_count = 0 THEN
    v_result := jsonb_build_object(
      'skipped', true,
      'reason', 'no_live_matches',
      'checked_at', v_now,
      'live_window_minutes', v_live_window
    );

    -- Log the skip for observability (use 'completed' to satisfy check constraint)
    INSERT INTO public.cron_job_log (job_name, status, result, completed_at)
    VALUES (
      'match-sync-' || p_fetch_type || '-gated',
      'completed',
      v_result,
      now()
    );

    RETURN v_result;
  END IF;

  -- Matches are live/imminent → run the real cycle
  RETURN public.run_match_sync_cycle(p_fetch_type, p_limit);
END;
$$;

GRANT EXECUTE ON FUNCTION public.run_match_sync_cycle_if_live(text, integer)
TO service_role;
REVOKE ALL ON FUNCTION public.run_match_sync_cycle_if_live(text, integer)
FROM anon, authenticated;

-- ------------------------------------------------------------------
-- 2. Update existing match-sync cron jobs to use gated wrapper
-- ------------------------------------------------------------------

DO $$
BEGIN
  -- Unschedule old match-sync-events
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'match-sync-events') THEN
    PERFORM cron.unschedule('match-sync-events');
  END IF;

  -- Unschedule old match-sync-odds
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'match-sync-odds') THEN
    PERFORM cron.unschedule('match-sync-odds');
  END IF;

  -- Events: every 1 minute, but gated (zero cost when no live matches)
  PERFORM cron.schedule(
    'match-sync-events',
    '* * * * *',
    $cron$SELECT public.run_match_sync_cycle_if_live('events');$cron$
  );

  -- Odds: every 15 minutes, but gated
  PERFORM cron.schedule(
    'match-sync-odds',
    '*/15 * * * *',
    $cron$SELECT public.run_match_sync_cycle_if_live('odds', 8);$cron$
  );
END $$;

-- ------------------------------------------------------------------
-- 3. Currency rate daily cron (1x per day at 06:00 UTC)
-- ------------------------------------------------------------------

DO $$
BEGIN
  -- Remove if already exists
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'fanzone-currency-rates-daily') THEN
    PERFORM cron.unschedule('fanzone-currency-rates-daily');
  END IF;

  PERFORM cron.schedule(
    'fanzone-currency-rates-daily',
    '0 6 * * *',
    $job$
    SELECT net.http_post(
      url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'fanzone_project_url')
        || '/functions/v1/gemini-currency-rates',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'fanzone_cron_secret')
      ),
      body := '{}'::jsonb
    );
    $job$
  );
END $$;

-- ------------------------------------------------------------------
-- 4. Team news hourly dispatcher
-- ------------------------------------------------------------------

-- Dispatcher function: picks top N teams by fan count needing refresh
CREATE OR REPLACE FUNCTION public.dispatch_team_news_refresh(
  p_max_teams integer DEFAULT 5
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_now timestamptz := timezone('utc', now());
  v_project_url text;
  v_cron_secret text;
  v_dispatched integer := 0;
  v_request_id bigint;
  rec record;
BEGIN
  -- Get vault secrets
  SELECT
    (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'fanzone_project_url'),
    (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'fanzone_cron_secret')
  INTO v_project_url, v_cron_secret;

  IF v_project_url IS NULL THEN
    RETURN jsonb_build_object('error', 'Missing fanzone_project_url vault secret');
  END IF;

  -- Pick teams with the most fans that haven't been refreshed in the last hour
  FOR rec IN
    SELECT
      t.id AS team_id,
      t.name AS team_name,
      count(uf.user_id) AS fan_count
    FROM public.teams t
    INNER JOIN public.user_favourite_teams uf ON uf.team_id = t.id
    LEFT JOIN public.team_news_ingestion_runs tnir
      ON tnir.team_id = t.id
      AND tnir.status IN ('running', 'completed')
      AND tnir.created_at >= v_now - interval '1 hour'
    WHERE t.is_active = true
      AND tnir.id IS NULL  -- No recent refresh
    GROUP BY t.id, t.name
    ORDER BY fan_count DESC
    LIMIT p_max_teams
  LOOP
    BEGIN
      v_request_id := net.http_post(
        url := v_project_url || '/functions/v1/gemini-team-news',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-cron-secret', v_cron_secret
        ),
        body := jsonb_build_object(
          'teamId', rec.team_id,
          'teamName', rec.team_name,
          'maxArticles', 5
        ),
        timeout_milliseconds := 60000
      );
      v_dispatched := v_dispatched + 1;
    EXCEPTION WHEN others THEN
      -- Log but don't fail the whole batch
      RAISE WARNING 'Failed to dispatch news for team %: %', rec.team_id, SQLERRM;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'dispatched', v_dispatched,
    'max_teams', p_max_teams,
    'ran_at', v_now
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.dispatch_team_news_refresh(integer) TO service_role;
REVOKE ALL ON FUNCTION public.dispatch_team_news_refresh(integer) FROM anon, authenticated;

-- Schedule: minute 15 of every hour
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'fanzone-team-news-hourly') THEN
    PERFORM cron.unschedule('fanzone-team-news-hourly');
  END IF;

  PERFORM cron.schedule(
    'fanzone-team-news-hourly',
    '15 * * * *',
    $job$SELECT public.dispatch_team_news_refresh(5);$job$
  );
END $$;

COMMIT;

-- Total new cron jobs: 2 (currency daily, news hourly)
-- Modified cron jobs: 2 (match-sync-events, match-sync-odds → now gated)
