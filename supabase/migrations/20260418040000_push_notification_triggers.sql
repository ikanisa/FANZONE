-- ============================================================
-- 20260418040000_push_notification_triggers.sql
-- Push notification integration + auto-settlement cron.
--
-- Contents:
--   1) Helper RPC: send_push_to_user (via pg_net → Edge Function)
--   2) Notification helper RPCs for pool/challenge events
--   3) pg_cron job for auto-settlement (every 15 minutes)
--   4) DB trigger: notify on pool settlement
-- ============================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════
-- 1) Helper: Send push notification via Edge Function
-- ═══════════════════════════════════════════════════════════════

-- Requires pg_net extension (available on Supabase by default)
-- CREATE EXTENSION IF NOT EXISTS pg_net;  -- already enabled on Supabase

CREATE OR REPLACE FUNCTION send_push_to_user(
  p_user_id UUID,
  p_type TEXT,
  p_title TEXT,
  p_body TEXT,
  p_data JSONB DEFAULT '{}'
) RETURNS VOID AS $$
DECLARE
  v_supabase_url TEXT;
  v_service_key TEXT;
  v_push_notify_secret TEXT;
  v_payload JSONB;
BEGIN
  -- Read from vault or env
  v_supabase_url := current_setting('app.settings.supabase_url', true);
  v_service_key := current_setting('app.settings.service_role_key', true);
  v_push_notify_secret := nullif(current_setting('app.settings.push_notify_secret', true), '');

  IF v_supabase_url IS NULL OR v_service_key IS NULL THEN
    RAISE NOTICE 'Push notification config not set — skipping';
    RETURN;
  END IF;

  v_payload := jsonb_build_object(
    'user_id', p_user_id,
    'type', p_type,
    'title', p_title,
    'body', p_body,
    'data', p_data
  );

  PERFORM net.http_post(
    url := v_supabase_url || '/functions/v1/push-notify',
    headers := jsonb_strip_nulls(
      jsonb_build_object(
        'Authorization', 'Bearer ' || v_service_key,
        'Content-Type', 'application/json',
        'x-push-notify-secret', v_push_notify_secret
      )
    ),
    body := v_payload
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ═══════════════════════════════════════════════════════════════
-- 2) Convenience RPCs for common notifications
-- ═══════════════════════════════════════════════════════════════

-- Notify all pool participants when settled
CREATE OR REPLACE FUNCTION notify_pool_settled(
  p_pool_id UUID
) RETURNS VOID AS $$
DECLARE
  v_pool RECORD;
  v_entry RECORD;
BEGIN
  SELECT * INTO v_pool
  FROM public.prediction_challenges
  WHERE id = p_pool_id;

  IF v_pool IS NULL OR v_pool.status != 'settled' THEN
    RETURN;
  END IF;

  FOR v_entry IN
    SELECT user_id, status, payout_fet
    FROM public.prediction_challenge_entries
    WHERE challenge_id = p_pool_id
  LOOP
    IF v_entry.status = 'won' THEN
      PERFORM send_push_to_user(
        v_entry.user_id,
        'pool_settled',
        '🎉 Pool Won!',
        'You won ' || v_entry.payout_fet || ' FET in ' || v_pool.match_name || '!',
        jsonb_build_object('pool_id', p_pool_id, 'screen', '/predict')
      );
    ELSE
      PERFORM send_push_to_user(
        v_entry.user_id,
        'pool_settled',
        'Pool Settled',
        v_pool.match_name || ' — ' || v_pool.official_home_score || '-' || v_pool.official_away_score,
        jsonb_build_object('pool_id', p_pool_id, 'screen', '/predict')
      );
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Notify daily challenge winners
CREATE OR REPLACE FUNCTION notify_daily_challenge_winners(
  p_challenge_id UUID
) RETURNS VOID AS $$
DECLARE
  v_challenge RECORD;
  v_entry RECORD;
BEGIN
  SELECT * INTO v_challenge
  FROM public.daily_challenges
  WHERE id = p_challenge_id;

  IF v_challenge IS NULL OR v_challenge.status != 'settled' THEN
    RETURN;
  END IF;

  FOR v_entry IN
    SELECT user_id, result, payout_fet
    FROM public.daily_challenge_entries
    WHERE challenge_id = p_challenge_id
      AND result IN ('correct_result', 'exact_score')
      AND payout_fet > 0
  LOOP
    PERFORM send_push_to_user(
      v_entry.user_id,
      'daily_challenge',
      CASE WHEN v_entry.result = 'exact_score'
        THEN '🎯 Exact Score Bonus!'
        ELSE '✅ Daily Challenge Won!'
      END,
      'You earned ' || v_entry.payout_fet || ' FET! ' || v_challenge.match_name,
      jsonb_build_object('challenge_id', p_challenge_id, 'screen', '/profile')
    );
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Notify on FET wallet credit
CREATE OR REPLACE FUNCTION notify_wallet_credit()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.direction = 'credit' AND NEW.amount_fet >= 10 THEN
    PERFORM send_push_to_user(
      NEW.user_id,
      'wallet_credit',
      '💰 FET Received',
      NEW.title || ' — +' || NEW.amount_fet || ' FET',
      jsonb_build_object('screen', '/profile/wallet')
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger on wallet transactions (credit only, >= 10 FET)
DROP TRIGGER IF EXISTS trg_notify_wallet_credit ON public.fet_wallet_transactions;
CREATE TRIGGER trg_notify_wallet_credit
  AFTER INSERT ON public.fet_wallet_transactions
  FOR EACH ROW
  WHEN (NEW.direction = 'credit' AND NEW.amount_fet >= 10)
  EXECUTE FUNCTION notify_wallet_credit();


-- ═══════════════════════════════════════════════════════════════
-- 3) pg_cron: Auto-settlement every 15 minutes
-- ═══════════════════════════════════════════════════════════════

-- pg_cron is available on Supabase Pro plans.
-- If not available, the GitHub Actions cron fallback will be used.

DO $outer$
BEGIN
  -- Check if pg_cron is available
  IF EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) THEN
    -- Schedule auto-settle via Edge Function call
    PERFORM cron.schedule(
      'fanzone-auto-settle',
      '*/15 * * * *',
      $inner$
      SELECT net.http_post(
        url := current_setting('app.settings.supabase_url') || '/functions/v1/auto-settle',
        headers := jsonb_build_object(
          'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
          'Content-Type', 'application/json',
          'x-cron-secret', current_setting('app.settings.cron_secret', true)
        ),
        body := '{}'::jsonb
      );
      $inner$
    );

    -- Schedule rate limit cleanup daily at 3 AM
    PERFORM cron.schedule(
      'fanzone-cleanup-rate-limits',
      '0 3 * * *',
      $inner$ SELECT cleanup_rate_limits(); $inner$
    );

    RAISE NOTICE 'pg_cron jobs scheduled successfully';
  ELSE
    RAISE NOTICE 'pg_cron not available — use GitHub Actions cron fallback';
  END IF;
END $outer$;



-- ═══════════════════════════════════════════════════════════════
-- 4) Grants
-- ═══════════════════════════════════════════════════════════════

GRANT EXECUTE ON FUNCTION send_push_to_user(UUID, TEXT, TEXT, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION notify_pool_settled(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION notify_daily_challenge_winners(UUID) TO authenticated;

COMMIT;
