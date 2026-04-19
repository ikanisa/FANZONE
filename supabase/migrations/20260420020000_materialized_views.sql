-- ============================================================
-- 20260420020000_materialized_views.sql
-- Materialized views for high-frequency aggregation queries.
--
-- 1. mv_crowd_predictions — aggregate prediction stats per match
-- 2. mv_global_leaderboard — pre-computed wallet-based rankings
-- 3. Refresh functions for pg_cron scheduling
-- ============================================================

BEGIN;

-- =================================================================
-- 1. CROWD PREDICTIONS MATERIALIZED VIEW
-- =================================================================

-- Aggregate prediction statistics per match for the "crowd thinks" widget.
-- Refreshed every 5 minutes via pg_cron or Edge Function.
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_crowd_predictions AS
SELECT
  pce.challenge_id,
  pc.match_id,
  COUNT(DISTINCT pce.user_id)::integer AS total_predictions,
  ROUND(AVG(pce.predicted_home_score)::numeric, 1) AS avg_home_score,
  ROUND(AVG(pce.predicted_away_score)::numeric, 1) AS avg_away_score,
  -- Most popular scoreline
  MODE() WITHIN GROUP (
    ORDER BY (pce.predicted_home_score || '-' || pce.predicted_away_score)
  ) AS most_popular_scoreline,
  -- Win/Draw/Lose distribution
  COUNT(*) FILTER (WHERE pce.predicted_home_score > pce.predicted_away_score)::integer AS home_win_count,
  COUNT(*) FILTER (WHERE pce.predicted_home_score = pce.predicted_away_score)::integer AS draw_count,
  COUNT(*) FILTER (WHERE pce.predicted_home_score < pce.predicted_away_score)::integer AS away_win_count,
  -- Timing
  MAX(pce.joined_at) AS last_prediction_at,
  now() AS refreshed_at
FROM public.prediction_challenge_entries pce
JOIN public.prediction_challenges pc ON pc.id = pce.challenge_id
WHERE pc.status IN ('open', 'locked', 'settled')
GROUP BY pce.challenge_id, pc.match_id
WITH DATA;

-- Unique index required for CONCURRENTLY refresh
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_crowd_predictions_challenge
  ON public.mv_crowd_predictions (challenge_id);

CREATE INDEX IF NOT EXISTS idx_mv_crowd_predictions_match
  ON public.mv_crowd_predictions (match_id);

-- =================================================================
-- 2. GLOBAL LEADERBOARD MATERIALIZED VIEW
-- =================================================================

-- Pre-computed wallet-based rankings to replace the public_leaderboard view.
-- Refreshed every 10 minutes via pg_cron.
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_global_leaderboard AS
SELECT
  fw.user_id,
  COALESCE(p.display_name, p.favorite_team_name, 'Fan') AS display_name,
  p.fan_id,
  p.country_code,
  fw.available_balance_fet AS available_balance,
  fw.locked_balance_fet AS locked_balance,
  (fw.available_balance_fet + fw.locked_balance_fet) AS total_balance,
  RANK() OVER (ORDER BY (fw.available_balance_fet + fw.locked_balance_fet) DESC) AS rank,
  -- Stats
  (
    SELECT COUNT(*)::integer
    FROM public.prediction_challenge_entries e
    WHERE e.user_id = fw.user_id AND e.status = 'won'
  ) AS total_wins,
  (
    SELECT COUNT(*)::integer
    FROM public.prediction_challenge_entries e
    WHERE e.user_id = fw.user_id
  ) AS total_predictions,
  p.active_country,
  fw.updated_at AS balance_updated_at,
  now() AS refreshed_at
FROM public.fet_wallets fw
JOIN public.profiles p ON p.user_id = fw.user_id
WHERE (fw.available_balance_fet + fw.locked_balance_fet) > 0
  AND COALESCE(p.is_anonymous, false) = false
ORDER BY total_balance DESC
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_global_leaderboard_user
  ON public.mv_global_leaderboard (user_id);

CREATE INDEX IF NOT EXISTS idx_mv_global_leaderboard_rank
  ON public.mv_global_leaderboard (rank);

CREATE INDEX IF NOT EXISTS idx_mv_global_leaderboard_country
  ON public.mv_global_leaderboard (active_country, rank);

-- =================================================================
-- 3. REFRESH FUNCTIONS (for pg_cron or Edge Function calls)
-- =================================================================

-- Refresh crowd predictions (safe CONCURRENTLY)
CREATE OR REPLACE FUNCTION public.refresh_crowd_predictions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_job_id uuid;
BEGIN
  INSERT INTO public.cron_job_log (job_name, status)
  VALUES ('refresh_crowd_predictions', 'running')
  RETURNING id INTO v_job_id;

  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_crowd_predictions;

    UPDATE public.cron_job_log
    SET status = 'completed',
        completed_at = now(),
        duration_ms = EXTRACT(EPOCH FROM (now() - started_at))::integer * 1000
    WHERE id = v_job_id;
  EXCEPTION WHEN OTHERS THEN
    UPDATE public.cron_job_log
    SET status = 'failed',
        completed_at = now(),
        error_message = SQLERRM,
        duration_ms = EXTRACT(EPOCH FROM (now() - started_at))::integer * 1000
    WHERE id = v_job_id;
    RAISE;
  END;
END;
$$;

-- Refresh global leaderboard (safe CONCURRENTLY)
CREATE OR REPLACE FUNCTION public.refresh_global_leaderboard()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_job_id uuid;
BEGIN
  INSERT INTO public.cron_job_log (job_name, status)
  VALUES ('refresh_global_leaderboard', 'running')
  RETURNING id INTO v_job_id;

  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_global_leaderboard;

    UPDATE public.cron_job_log
    SET status = 'completed',
        completed_at = now(),
        duration_ms = EXTRACT(EPOCH FROM (now() - started_at))::integer * 1000
    WHERE id = v_job_id;
  EXCEPTION WHEN OTHERS THEN
    UPDATE public.cron_job_log
    SET status = 'failed',
        completed_at = now(),
        error_message = SQLERRM,
        duration_ms = EXTRACT(EPOCH FROM (now() - started_at))::integer * 1000
    WHERE id = v_job_id;
    RAISE;
  END;
END;
$$;

-- Grant execute to service_role only (pg_cron / Edge Functions)
REVOKE ALL ON FUNCTION public.refresh_crowd_predictions() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.refresh_global_leaderboard() FROM PUBLIC;

-- =================================================================
-- 4. SECURITY: Admin write policies for sports data tables
-- =================================================================

-- Teams: admin write
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'teams'
      AND policyname = 'Admin write teams'
  ) THEN
    CREATE POLICY "Admin write teams"
      ON public.teams
      FOR ALL
      TO authenticated
      USING (
        EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.is_admin = true)
      )
      WITH CHECK (
        EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.is_admin = true)
      );
  END IF;
END $$;

-- Matches: admin write
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'matches'
      AND policyname = 'Admin write matches'
  ) THEN
    CREATE POLICY "Admin write matches"
      ON public.matches
      FOR ALL
      TO authenticated
      USING (
        EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.is_admin = true)
      )
      WITH CHECK (
        EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.is_admin = true)
      );
  END IF;
END $$;

-- Live match events: admin write
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'live_match_events'
      AND policyname = 'Admin write live match events'
  ) THEN
    CREATE POLICY "Admin write live match events"
      ON public.live_match_events
      FOR ALL
      TO authenticated
      USING (
        EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.is_admin = true)
      )
      WITH CHECK (
        EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.is_admin = true)
      );
  END IF;
END $$;

-- News: admin write
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'news'
      AND policyname = 'Admin write news'
  ) THEN
    CREATE POLICY "Admin write news"
      ON public.news
      FOR ALL
      TO authenticated
      USING (
        EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.is_admin = true)
      )
      WITH CHECK (
        EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.is_admin = true)
      );
  END IF;
END $$;

-- Feature flags: admin write
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'feature_flags'
      AND policyname = 'Admin write feature flags'
  ) THEN
    CREATE POLICY "Admin write feature flags"
      ON public.feature_flags
      FOR ALL
      TO authenticated
      USING (
        EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.is_admin = true)
      )
      WITH CHECK (
        EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.is_admin = true)
      );
  END IF;
END $$;

-- App config remote: admin write
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'app_config_remote'
      AND policyname = 'Admin write app config'
  ) THEN
    CREATE POLICY "Admin write app config"
      ON public.app_config_remote
      FOR ALL
      TO authenticated
      USING (
        EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.is_admin = true)
      )
      WITH CHECK (
        EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.is_admin = true)
      );
  END IF;
END $$;

-- Launch moments: admin write
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'launch_moments'
      AND policyname = 'Admin write launch moments'
  ) THEN
    CREATE POLICY "Admin write launch moments"
      ON public.launch_moments
      FOR ALL
      TO authenticated
      USING (
        EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.is_admin = true)
      )
      WITH CHECK (
        EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.is_admin = true)
      );
  END IF;
END $$;

-- =================================================================
-- 5. PREDICTION TABLE INSERT POLICIES
-- =================================================================

-- Prediction challenges: authenticated users can create
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'prediction_challenges'
      AND policyname = 'Authenticated insert prediction challenges'
  ) THEN
    CREATE POLICY "Authenticated insert prediction challenges"
      ON public.prediction_challenges
      FOR INSERT
      TO authenticated
      WITH CHECK (creator_user_id = auth.uid());
  END IF;
END $$;

-- Prediction challenge entries: authenticated users can insert their own
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'prediction_challenge_entries'
      AND policyname = 'Authenticated insert prediction entries'
  ) THEN
    CREATE POLICY "Authenticated insert prediction entries"
      ON public.prediction_challenge_entries
      FOR INSERT
      TO authenticated
      WITH CHECK (user_id = auth.uid());
  END IF;
END $$;

COMMIT;
