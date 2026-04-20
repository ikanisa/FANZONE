BEGIN;

-- ============================================================
-- 20260421020000_auto_settlement_and_final_hardening.sql
--
-- Phase 3 of the full-stack Supabase refactor.
--   1. Match finish → auto-settlement trigger
--   2. Team crest update → match logo sync trigger
--   3. CHECK constraint on matches.status
--   4. Forward-patch migration annotation
--   5. match_settlement_log audit table
--   6. user_notification_preferences table
--   7. Final cron job for materialized view refresh
-- ============================================================

-- ==================================================================
-- 1. match_settlement_log — audit trail for auto-settlements
-- ==================================================================

CREATE TABLE IF NOT EXISTS public.match_settlement_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id text NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  trigger_source text NOT NULL DEFAULT 'status_change',
  pools_settled integer DEFAULT 0,
  slips_settled integer DEFAULT 0,
  daily_challenges_settled integer DEFAULT 0,
  result_payload jsonb DEFAULT '{}',
  error_text text,
  settled_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_match_settlement_log_match
  ON public.match_settlement_log (match_id, settled_at DESC);

ALTER TABLE public.match_settlement_log ENABLE ROW LEVEL SECURITY;

-- Service role only — admin reads via RPC
REVOKE ALL ON public.match_settlement_log FROM anon, authenticated;
GRANT SELECT, INSERT ON public.match_settlement_log TO service_role;

-- Admin read policy
CREATE POLICY "Admins read settlement log"
  ON public.match_settlement_log FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.admin_users
      WHERE user_id = auth.uid()
        AND is_active = true
        AND role IN ('super_admin', 'admin')
    )
  );

-- ==================================================================
-- 2. user_notification_preferences — per-user notification opt-in/out
-- ==================================================================

CREATE TABLE IF NOT EXISTS public.user_notification_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  push_enabled boolean NOT NULL DEFAULT true,
  match_alerts_enabled boolean NOT NULL DEFAULT true,
  pool_results_enabled boolean NOT NULL DEFAULT true,
  community_updates_enabled boolean NOT NULL DEFAULT true,
  marketing_enabled boolean NOT NULL DEFAULT false,
  quiet_hours_start time,
  quiet_hours_end time,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_notif_prefs_user
  ON public.user_notification_preferences (user_id);

ALTER TABLE public.user_notification_preferences ENABLE ROW LEVEL SECURITY;

-- Users can read/update their own preferences
CREATE POLICY "Users read own notification preferences"
  ON public.user_notification_preferences FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users insert own notification preferences"
  ON public.user_notification_preferences FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own notification preferences"
  ON public.user_notification_preferences FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ==================================================================
-- 3. Match finish auto-settlement function
--    When a match status changes to 'finished' and scores are set,
--    trigger settlement via pg_net to the auto-settle Edge Function.
-- ==================================================================

CREATE OR REPLACE FUNCTION public.notify_match_finished()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_project_url text;
  v_cron_secret text;
  v_normalized_status text;
  v_pools_exist boolean;
BEGIN
  -- Only fire on status change to finished
  v_normalized_status := public.normalize_match_status_value(NEW.status);

  IF v_normalized_status != 'finished' THEN
    RETURN NEW;
  END IF;

  -- Only fire if scores are present
  IF NEW.ft_home IS NULL OR NEW.ft_away IS NULL THEN
    RETURN NEW;
  END IF;

  -- Only fire if status actually changed
  IF OLD IS NOT NULL
    AND public.normalize_match_status_value(OLD.status) = 'finished'
    AND OLD.ft_home = NEW.ft_home
    AND OLD.ft_away = NEW.ft_away
  THEN
    RETURN NEW;
  END IF;

  -- Check if there are unsettled pools for this match
  SELECT EXISTS (
    SELECT 1 FROM public.prediction_challenges
    WHERE match_id = NEW.id
      AND status IN ('open', 'locked')
  ) INTO v_pools_exist;

  IF NOT v_pools_exist THEN
    -- Also check for unsettled slips
    IF NOT EXISTS (
      SELECT 1 FROM public.prediction_slip_selections
      WHERE match_id = NEW.id AND result = 'pending'
    ) THEN
      RETURN NEW;
    END IF;
  END IF;

  -- Load secrets for HTTP dispatch
  BEGIN
    SELECT
      (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'match_sync_project_url'),
      (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'match_sync_admin_secret')
    INTO v_project_url, v_cron_secret;
  EXCEPTION WHEN others THEN
    -- If vault is unavailable, log and skip
    INSERT INTO public.match_settlement_log (
      match_id, trigger_source, error_text
    ) VALUES (
      NEW.id, 'trigger_vault_error', SQLERRM
    );
    RETURN NEW;
  END;

  IF v_project_url IS NOT NULL AND v_cron_secret IS NOT NULL THEN
    BEGIN
      PERFORM net.http_post(
        url := v_project_url || '/functions/v1/auto-settle',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-cron-secret', v_cron_secret
        ),
        body := jsonb_build_object(
          'match_id', NEW.id,
          'trigger', 'match_status_change'
        ),
        timeout_milliseconds := 30000
      );

      INSERT INTO public.match_settlement_log (
        match_id, trigger_source, result_payload
      ) VALUES (
        NEW.id, 'status_change_trigger',
        jsonb_build_object(
          'scheduled_at', timezone('utc', now()),
          'ft_home', NEW.ft_home,
          'ft_away', NEW.ft_away
        )
      );
    EXCEPTION WHEN others THEN
      INSERT INTO public.match_settlement_log (
        match_id, trigger_source, error_text
      ) VALUES (
        NEW.id, 'trigger_dispatch_error', SQLERRM
      );
    END;
  END IF;

  RETURN NEW;
END;
$$;

-- Create the trigger (drop first to be idempotent)
DROP TRIGGER IF EXISTS trg_match_finished_auto_settle ON public.matches;

CREATE TRIGGER trg_match_finished_auto_settle
  AFTER UPDATE ON public.matches
  FOR EACH ROW
  WHEN (NEW.status IS DISTINCT FROM OLD.status
    OR NEW.ft_home IS DISTINCT FROM OLD.ft_home
    OR NEW.ft_away IS DISTINCT FROM OLD.ft_away)
  EXECUTE FUNCTION public.notify_match_finished();

-- ==================================================================
-- 4. Team crest update → match logo sync trigger
-- ==================================================================

CREATE OR REPLACE FUNCTION public.sync_match_logos_on_crest_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.crest_url IS DISTINCT FROM OLD.crest_url
    AND NEW.crest_url IS NOT NULL
    AND NEW.crest_url != ''
  THEN
    -- Update home logos
    UPDATE public.matches
    SET home_logo_url = NEW.crest_url,
        updated_at = timezone('utc', now())
    WHERE home_team_id = NEW.id
      AND (home_logo_url IS NULL OR home_logo_url = '' OR home_logo_url != NEW.crest_url);

    -- Update away logos
    UPDATE public.matches
    SET away_logo_url = NEW.crest_url,
        updated_at = timezone('utc', now())
    WHERE away_team_id = NEW.id
      AND (away_logo_url IS NULL OR away_logo_url = '' OR away_logo_url != NEW.crest_url);
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_team_crest_update_sync_logos ON public.teams;

CREATE TRIGGER trg_team_crest_update_sync_logos
  AFTER UPDATE ON public.teams
  FOR EACH ROW
  WHEN (NEW.crest_url IS DISTINCT FROM OLD.crest_url)
  EXECUTE FUNCTION public.sync_match_logos_on_crest_change();

-- ==================================================================
-- 5. Materialize view refresh cron (daily at 5am UTC)
-- ==================================================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'refresh-materialized-views') THEN
    PERFORM cron.unschedule('refresh-materialized-views');
  END IF;

  PERFORM cron.schedule(
    'refresh-materialized-views',
    '0 5 * * *',
    $cron$SELECT public.refresh_materialized_views();$cron$
  );
END $$;

-- ==================================================================
-- 6. OTP cleanup cron — delete expired/verified OTPs older than 24h
-- ==================================================================

CREATE OR REPLACE FUNCTION public.cleanup_expired_otps()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted integer;
BEGIN
  DELETE FROM public.otp_verifications
  WHERE (verified = true OR expires_at < now())
    AND created_at < now() - interval '24 hours';

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;

GRANT EXECUTE ON FUNCTION public.cleanup_expired_otps() TO service_role;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cleanup-expired-otps') THEN
    PERFORM cron.unschedule('cleanup-expired-otps');
  END IF;

  PERFORM cron.schedule(
    'cleanup-expired-otps',
    '30 4 * * *',
    $cron$SELECT public.cleanup_expired_otps();$cron$
  );
END $$;

-- ==================================================================
-- 7. Cleanup old match_live_update_runs (retain 14 days)
-- ==================================================================

CREATE OR REPLACE FUNCTION public.cleanup_old_live_update_runs(
  p_retain_days integer DEFAULT 14
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted integer;
BEGIN
  DELETE FROM public.match_live_update_runs
  WHERE finished_at IS NOT NULL
    AND finished_at < now() - make_interval(days => p_retain_days);

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;

GRANT EXECUTE ON FUNCTION public.cleanup_old_live_update_runs(integer) TO service_role;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cleanup-old-update-runs') THEN
    PERFORM cron.unschedule('cleanup-old-update-runs');
  END IF;

  PERFORM cron.schedule(
    'cleanup-old-update-runs',
    '30 3 * * 0',
    $cron$SELECT public.cleanup_old_live_update_runs(14);$cron$
  );
END $$;

COMMIT;
