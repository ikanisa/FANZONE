BEGIN;

-- ============================================================
-- 20260421000000_critical_safety_refactor.sql
--
-- Phase 1 of the full-stack Supabase refactor.
-- Addresses critical safety issues found during the deep audit:
--
--   1. otp_verifications table (missing from migration chain)
--   2. SET search_path on SECURITY DEFINER functions
--   3. Unique dedup index on live_match_events
--   4. Missing FK on prediction_slip_selections.match_id
--   5. RLS + policies on rate_limits table
--   6. Performance indexes
--   7. get_live_matches() convenience RPC
--   8. Request log cleanup function + cron
--   9. Match finish auto-settlement trigger
--  10. refresh_materialized_views() RPC
-- ============================================================

-- ==================================================================
-- 1. otp_verifications — used by whatsapp-otp Edge Function
--    This was created via dashboard but never in a migration file.
--    A fresh `supabase db reset` would break without this.
-- ==================================================================

CREATE TABLE IF NOT EXISTS public.otp_verifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone text NOT NULL,
  otp_hash text NOT NULL,
  verified boolean NOT NULL DEFAULT false,
  attempts integer NOT NULL DEFAULT 0,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_otp_verifications_phone_verified
  ON public.otp_verifications (phone, verified, expires_at DESC);

CREATE INDEX IF NOT EXISTS idx_otp_verifications_phone_created
  ON public.otp_verifications (phone, created_at DESC);

ALTER TABLE public.otp_verifications ENABLE ROW LEVEL SECURITY;

-- Only service_role (Edge Functions) should read/write this table.
-- No user-facing access at all.
REVOKE ALL ON public.otp_verifications FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.otp_verifications TO service_role;

-- ==================================================================
-- 2. Harden SECURITY DEFINER functions with SET search_path
--    Functions from 001, 005, 008, 014, 20260418031500 that were
--    created without explicit search_path.
-- ==================================================================

-- 2a. settle_pool (from 20260418031500)
CREATE OR REPLACE FUNCTION settle_pool(
  p_pool_id UUID,
  p_official_home_score INT,
  p_official_away_score INT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_pool RECORD;
  v_winner_count INT := 0;
  v_loser_count INT := 0;
  v_payout_per_winner BIGINT := 0;
  v_entry RECORD;
  v_is_winner BOOLEAN;
  v_balance_before BIGINT;
BEGIN
  SELECT * INTO v_pool
  FROM public.prediction_challenges
  WHERE id = p_pool_id
  FOR UPDATE;

  IF v_pool IS NULL THEN
    RAISE EXCEPTION 'Pool not found';
  END IF;

  IF v_pool.status NOT IN ('open', 'locked') THEN
    RAISE EXCEPTION 'Pool already settled or cancelled (status: %)', v_pool.status;
  END IF;

  IF p_official_home_score IS NULL OR p_official_away_score IS NULL THEN
    RAISE EXCEPTION 'Official scores are required';
  END IF;

  SELECT COUNT(*) INTO v_winner_count
  FROM public.prediction_challenge_entries
  WHERE challenge_id = p_pool_id
    AND status = 'active'
    AND predicted_home_score = p_official_home_score
    AND predicted_away_score = p_official_away_score;

  v_loser_count := v_pool.total_participants - v_winner_count;

  IF v_winner_count > 0 THEN
    v_payout_per_winner := v_pool.total_pool_fet / v_winner_count;
  END IF;

  FOR v_entry IN
    SELECT * FROM public.prediction_challenge_entries
    WHERE challenge_id = p_pool_id AND status = 'active'
    FOR UPDATE
  LOOP
    v_is_winner := (
      v_entry.predicted_home_score = p_official_home_score
      AND v_entry.predicted_away_score = p_official_away_score
    );

    UPDATE public.prediction_challenge_entries
    SET status = CASE WHEN v_is_winner THEN 'won' ELSE 'lost' END,
        payout_fet = CASE WHEN v_is_winner THEN v_payout_per_winner ELSE 0 END,
        settled_at = now()
    WHERE id = v_entry.id;

    IF v_is_winner AND v_payout_per_winner > 0 THEN
      SELECT available_balance_fet INTO v_balance_before
      FROM public.fet_wallets
      WHERE user_id = v_entry.user_id
      FOR UPDATE;

      UPDATE public.fet_wallets
      SET available_balance_fet = available_balance_fet + v_payout_per_winner,
          updated_at = now()
      WHERE user_id = v_entry.user_id;

      INSERT INTO public.fet_wallet_transactions (
        user_id, tx_type, direction, amount_fet,
        balance_before_fet, balance_after_fet,
        reference_type, reference_id, title
      ) VALUES (
        v_entry.user_id, 'pool_payout', 'credit', v_payout_per_winner,
        COALESCE(v_balance_before, 0),
        COALESCE(v_balance_before, 0) + v_payout_per_winner,
        'prediction_challenge', p_pool_id,
        'Pool payout — won ' || v_payout_per_winner || ' FET'
      );
    END IF;
  END LOOP;

  IF v_winner_count = 0 THEN
    FOR v_entry IN
      SELECT * FROM public.prediction_challenge_entries
      WHERE challenge_id = p_pool_id AND status = 'lost'
      FOR UPDATE
    LOOP
      SELECT available_balance_fet INTO v_balance_before
      FROM public.fet_wallets
      WHERE user_id = v_entry.user_id
      FOR UPDATE;

      UPDATE public.fet_wallets
      SET available_balance_fet = available_balance_fet + v_entry.stake_fet,
          updated_at = now()
      WHERE user_id = v_entry.user_id;

      UPDATE public.prediction_challenge_entries
      SET status = 'refunded',
          payout_fet = v_entry.stake_fet,
          settled_at = now()
      WHERE id = v_entry.id;

      INSERT INTO public.fet_wallet_transactions (
        user_id, tx_type, direction, amount_fet,
        balance_before_fet, balance_after_fet,
        reference_type, reference_id, title
      ) VALUES (
        v_entry.user_id, 'pool_refund', 'credit', v_entry.stake_fet,
        COALESCE(v_balance_before, 0),
        COALESCE(v_balance_before, 0) + v_entry.stake_fet,
        'prediction_challenge', p_pool_id,
        'Pool refund — no winners'
      );
    END LOOP;
  END IF;

  UPDATE public.prediction_challenges
  SET status = 'settled',
      settled_at = now(),
      official_home_score = p_official_home_score,
      official_away_score = p_official_away_score,
      winner_count = v_winner_count,
      loser_count = v_loser_count,
      payout_per_winner_fet = v_payout_per_winner,
      updated_at = now()
  WHERE id = p_pool_id;

  RETURN jsonb_build_object(
    'status', 'settled',
    'pool_id', p_pool_id,
    'winner_count', v_winner_count,
    'loser_count', v_loser_count,
    'payout_per_winner', v_payout_per_winner,
    'total_pool', v_pool.total_pool_fet,
    'refunded', (v_winner_count = 0)
  );
END;
$$;

-- 2b. void_pool (from 20260418031500)
CREATE OR REPLACE FUNCTION void_pool(
  p_pool_id UUID,
  p_reason TEXT DEFAULT 'Admin cancelled'
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_pool RECORD;
  v_entry RECORD;
  v_balance_before BIGINT;
  v_refund_count INT := 0;
BEGIN
  SELECT * INTO v_pool
  FROM public.prediction_challenges
  WHERE id = p_pool_id
  FOR UPDATE;

  IF v_pool IS NULL THEN
    RAISE EXCEPTION 'Pool not found';
  END IF;

  IF v_pool.status IN ('settled', 'cancelled') THEN
    RAISE EXCEPTION 'Pool already % — cannot void', v_pool.status;
  END IF;

  FOR v_entry IN
    SELECT * FROM public.prediction_challenge_entries
    WHERE challenge_id = p_pool_id AND status = 'active'
    FOR UPDATE
  LOOP
    SELECT available_balance_fet INTO v_balance_before
    FROM public.fet_wallets
    WHERE user_id = v_entry.user_id
    FOR UPDATE;

    UPDATE public.fet_wallets
    SET available_balance_fet = available_balance_fet + v_entry.stake_fet,
        updated_at = now()
    WHERE user_id = v_entry.user_id;

    UPDATE public.prediction_challenge_entries
    SET status = 'cancelled',
        payout_fet = v_entry.stake_fet,
        settled_at = now()
    WHERE id = v_entry.id;

    INSERT INTO public.fet_wallet_transactions (
      user_id, tx_type, direction, amount_fet,
      balance_before_fet, balance_after_fet,
      reference_type, reference_id, title
    ) VALUES (
      v_entry.user_id, 'pool_refund', 'credit', v_entry.stake_fet,
      COALESCE(v_balance_before, 0),
      COALESCE(v_balance_before, 0) + v_entry.stake_fet,
      'prediction_challenge', p_pool_id,
      'Pool voided: ' || COALESCE(p_reason, 'cancelled')
    );

    v_refund_count := v_refund_count + 1;
  END LOOP;

  UPDATE public.prediction_challenges
  SET status = 'cancelled',
      cancelled_at = now(),
      void_reason = p_reason,
      updated_at = now()
  WHERE id = p_pool_id;

  RETURN jsonb_build_object(
    'status', 'voided',
    'pool_id', p_pool_id,
    'refunded_entries', v_refund_count,
    'reason', p_reason
  );
END;
$$;

-- 2c. auto_settle_pools (from 20260418031500)
CREATE OR REPLACE FUNCTION auto_settle_pools(
  p_match_id TEXT,
  p_home_score INT,
  p_away_score INT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pool RECORD;
  v_result JSONB;
  v_settled INT := 0;
  v_results JSONB[] := '{}';
BEGIN
  FOR v_pool IN
    SELECT id FROM public.prediction_challenges
    WHERE match_id = p_match_id
      AND status IN ('open', 'locked')
  LOOP
    v_result := settle_pool(v_pool.id, p_home_score, p_away_score);
    v_results := v_results || v_result;
    v_settled := v_settled + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'match_id', p_match_id,
    'pools_settled', v_settled,
    'results', to_jsonb(v_results)
  );
END;
$$;

-- 2d. check_rate_limit (from 20260418031500)
CREATE OR REPLACE FUNCTION check_rate_limit(
  p_user_id UUID,
  p_action TEXT,
  p_max_count INT,
  p_window_hours INT DEFAULT 1
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INT;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM public.rate_limits
  WHERE user_id = p_user_id
    AND action = p_action
    AND created_at > now() - (p_window_hours || ' hours')::interval;

  IF v_count >= p_max_count THEN
    RETURN FALSE;
  END IF;

  INSERT INTO public.rate_limits (user_id, action)
  VALUES (p_user_id, p_action);

  RETURN TRUE;
END;
$$;

-- 2e. cleanup_rate_limits (from 20260418031500)
CREATE OR REPLACE FUNCTION cleanup_rate_limits()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.rate_limits
  WHERE created_at < now() - interval '24 hours';
END;
$$;

-- 2f. create_pool_rate_limited (from 20260418031500)
CREATE OR REPLACE FUNCTION create_pool_rate_limited(
  p_match_id TEXT,
  p_home_score INT,
  p_away_score INT,
  p_stake BIGINT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT check_rate_limit(v_user_id, 'create_pool', 5, 1) THEN
    RAISE EXCEPTION 'Rate limit exceeded — max 5 pools per hour';
  END IF;

  RETURN create_pool(p_match_id, p_home_score, p_away_score, p_stake);
END;
$$;

-- 2g. transfer_fet_rate_limited (from 20260418031500)
CREATE OR REPLACE FUNCTION transfer_fet_rate_limited(
  p_recipient_email TEXT,
  p_amount INT
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT check_rate_limit(v_user_id, 'transfer_fet', 10, 24) THEN
    RAISE EXCEPTION 'Rate limit exceeded — max 10 transfers per day';
  END IF;

  PERFORM transfer_fet(p_recipient_email, p_amount);
END;
$$;

-- 2h. admin_ban_user (from 20260418031500)
CREATE OR REPLACE FUNCTION admin_ban_user(
  p_target_user_id UUID,
  p_reason TEXT DEFAULT 'Policy violation',
  p_until TIMESTAMPTZ DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
BEGIN
  v_admin_id := auth.uid();
  IF NOT EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE user_id = v_admin_id AND is_active = true
      AND role IN ('super_admin', 'admin')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  INSERT INTO public.user_status (user_id, is_banned, banned_until, ban_reason)
  VALUES (p_target_user_id, true, p_until, p_reason)
  ON CONFLICT (user_id) DO UPDATE
  SET is_banned = true,
      banned_until = p_until,
      ban_reason = p_reason,
      updated_at = now();

  INSERT INTO public.admin_audit_logs (
    admin_user_id, action, module, target_type, target_id,
    after_state, metadata
  )
  SELECT au.id, 'ban_user', 'users', 'user', p_target_user_id::text,
    jsonb_build_object('banned', true, 'reason', p_reason, 'until', p_until),
    '{}'::jsonb
  FROM public.admin_users au WHERE au.user_id = v_admin_id;

  RETURN jsonb_build_object('status', 'banned', 'user_id', p_target_user_id);
END;
$$;

-- 2i. admin_unban_user (from 20260418031500)
CREATE OR REPLACE FUNCTION admin_unban_user(
  p_target_user_id UUID
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
BEGIN
  v_admin_id := auth.uid();
  IF NOT EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE user_id = v_admin_id AND is_active = true
      AND role IN ('super_admin', 'admin')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  UPDATE public.user_status
  SET is_banned = false, banned_until = NULL, ban_reason = NULL, updated_at = now()
  WHERE user_id = p_target_user_id;

  INSERT INTO public.admin_audit_logs (
    admin_user_id, action, module, target_type, target_id,
    after_state
  )
  SELECT au.id, 'unban_user', 'users', 'user', p_target_user_id::text,
    jsonb_build_object('banned', false)
  FROM public.admin_users au WHERE au.user_id = v_admin_id;

  RETURN jsonb_build_object('status', 'unbanned', 'user_id', p_target_user_id);
END;
$$;

-- 2j. admin_freeze_wallet / admin_unfreeze_wallet (from 20260418031500)
CREATE OR REPLACE FUNCTION admin_freeze_wallet(
  p_target_user_id UUID,
  p_reason TEXT DEFAULT 'Suspicious activity'
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
BEGIN
  v_admin_id := auth.uid();
  IF NOT EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE user_id = v_admin_id AND is_active = true
      AND role IN ('super_admin', 'admin')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  INSERT INTO public.user_status (user_id, wallet_frozen, wallet_freeze_reason)
  VALUES (p_target_user_id, true, p_reason)
  ON CONFLICT (user_id) DO UPDATE
  SET wallet_frozen = true,
      wallet_freeze_reason = p_reason,
      updated_at = now();

  INSERT INTO public.admin_audit_logs (
    admin_user_id, action, module, target_type, target_id,
    after_state
  )
  SELECT au.id, 'freeze_wallet', 'wallets', 'user', p_target_user_id::text,
    jsonb_build_object('frozen', true, 'reason', p_reason)
  FROM public.admin_users au WHERE au.user_id = v_admin_id;

  RETURN jsonb_build_object('status', 'frozen', 'user_id', p_target_user_id);
END;
$$;

CREATE OR REPLACE FUNCTION admin_unfreeze_wallet(
  p_target_user_id UUID
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
BEGIN
  v_admin_id := auth.uid();
  IF NOT EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE user_id = v_admin_id AND is_active = true
      AND role IN ('super_admin', 'admin')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  UPDATE public.user_status
  SET wallet_frozen = false, wallet_freeze_reason = NULL, updated_at = now()
  WHERE user_id = p_target_user_id;

  INSERT INTO public.admin_audit_logs (
    admin_user_id, action, module, target_type, target_id,
    after_state
  )
  SELECT au.id, 'unfreeze_wallet', 'wallets', 'user', p_target_user_id::text,
    jsonb_build_object('frozen', false)
  FROM public.admin_users au WHERE au.user_id = v_admin_id;

  RETURN jsonb_build_object('status', 'unfrozen', 'user_id', p_target_user_id);
END;
$$;

-- 2k. admin_credit_fet (from 20260418031500)
CREATE OR REPLACE FUNCTION admin_credit_fet(
  p_target_user_id UUID,
  p_amount BIGINT,
  p_reason TEXT DEFAULT 'Admin credit'
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
  v_balance_before BIGINT;
BEGIN
  v_admin_id := auth.uid();
  IF NOT EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE user_id = v_admin_id AND is_active = true
      AND role IN ('super_admin', 'admin')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be positive';
  END IF;

  SELECT available_balance_fet INTO v_balance_before
  FROM public.fet_wallets
  WHERE user_id = p_target_user_id
  FOR UPDATE;

  INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
  VALUES (p_target_user_id, p_amount, 0)
  ON CONFLICT (user_id) DO UPDATE
  SET available_balance_fet = fet_wallets.available_balance_fet + p_amount,
      updated_at = now();

  INSERT INTO public.fet_wallet_transactions (
    user_id, tx_type, direction, amount_fet,
    balance_before_fet, balance_after_fet,
    reference_type, title
  ) VALUES (
    p_target_user_id, 'admin_credit', 'credit', p_amount,
    COALESCE(v_balance_before, 0),
    COALESCE(v_balance_before, 0) + p_amount,
    'admin_action',
    'Admin credit: ' || COALESCE(p_reason, '')
  );

  INSERT INTO public.admin_audit_logs (
    admin_user_id, action, module, target_type, target_id,
    after_state
  )
  SELECT au.id, 'credit_fet', 'wallets', 'user', p_target_user_id::text,
    jsonb_build_object('amount', p_amount, 'reason', p_reason)
  FROM public.admin_users au WHERE au.user_id = v_admin_id;

  RETURN jsonb_build_object(
    'status', 'credited',
    'user_id', p_target_user_id,
    'amount', p_amount,
    'new_balance', COALESCE(v_balance_before, 0) + p_amount
  );
END;
$$;

-- 2l. admin_debit_fet (from 20260418031500)
CREATE OR REPLACE FUNCTION admin_debit_fet(
  p_target_user_id UUID,
  p_amount BIGINT,
  p_reason TEXT DEFAULT 'Admin debit'
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
  v_balance_before BIGINT;
BEGIN
  v_admin_id := auth.uid();
  IF NOT EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE user_id = v_admin_id AND is_active = true
      AND role IN ('super_admin', 'admin')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be positive';
  END IF;

  SELECT available_balance_fet INTO v_balance_before
  FROM public.fet_wallets
  WHERE user_id = p_target_user_id
  FOR UPDATE;

  IF v_balance_before IS NULL OR v_balance_before < p_amount THEN
    RAISE EXCEPTION 'Insufficient balance (has % FET, requested %)', COALESCE(v_balance_before, 0), p_amount;
  END IF;

  UPDATE public.fet_wallets
  SET available_balance_fet = available_balance_fet - p_amount,
      updated_at = now()
  WHERE user_id = p_target_user_id;

  INSERT INTO public.fet_wallet_transactions (
    user_id, tx_type, direction, amount_fet,
    balance_before_fet, balance_after_fet,
    reference_type, title
  ) VALUES (
    p_target_user_id, 'admin_debit', 'debit', p_amount,
    v_balance_before,
    v_balance_before - p_amount,
    'admin_action',
    'Admin debit: ' || COALESCE(p_reason, '')
  );

  INSERT INTO public.admin_audit_logs (
    admin_user_id, action, module, target_type, target_id,
    after_state
  )
  SELECT au.id, 'debit_fet', 'wallets', 'user', p_target_user_id::text,
    jsonb_build_object('amount', p_amount, 'reason', p_reason)
  FROM public.admin_users au WHERE au.user_id = v_admin_id;

  RETURN jsonb_build_object(
    'status', 'debited',
    'user_id', p_target_user_id,
    'amount', p_amount,
    'new_balance', v_balance_before - p_amount
  );
END;
$$;

-- 2m. support_team (from 005)
CREATE OR REPLACE FUNCTION support_team(p_team_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_fan_id TEXT;
  v_existing RECORD;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.teams WHERE id = p_team_id AND is_active = true) THEN
    RAISE EXCEPTION 'Team not found or inactive';
  END IF;

  v_fan_id := generate_anonymous_fan_id(v_user_id, p_team_id);

  SELECT * INTO v_existing
  FROM public.team_supporters
  WHERE team_id = p_team_id AND user_id = v_user_id;

  IF v_existing IS NOT NULL THEN
    IF v_existing.is_active THEN
      RETURN jsonb_build_object('status', 'already_supporting', 'anonymous_fan_id', v_fan_id);
    ELSE
      UPDATE public.team_supporters
      SET is_active = true, joined_at = now()
      WHERE id = v_existing.id;

      UPDATE public.teams
      SET fan_count = GREATEST(fan_count + 1, 0), updated_at = now()
      WHERE id = p_team_id;

      RETURN jsonb_build_object('status', 'reactivated', 'anonymous_fan_id', v_fan_id);
    END IF;
  END IF;

  INSERT INTO public.team_supporters (team_id, user_id, anonymous_fan_id)
  VALUES (p_team_id, v_user_id, v_fan_id);

  UPDATE public.teams
  SET fan_count = fan_count + 1, updated_at = now()
  WHERE id = p_team_id;

  RETURN jsonb_build_object('status', 'joined', 'anonymous_fan_id', v_fan_id);
END;
$$;

-- 2n. unsupport_team (from 005)
CREATE OR REPLACE FUNCTION unsupport_team(p_team_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_existing RECORD;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_existing
  FROM public.team_supporters
  WHERE team_id = p_team_id AND user_id = v_user_id AND is_active = true;

  IF v_existing IS NULL THEN
    RETURN jsonb_build_object('status', 'not_supporting');
  END IF;

  UPDATE public.team_supporters
  SET is_active = false
  WHERE id = v_existing.id;

  UPDATE public.teams
  SET fan_count = GREATEST(fan_count - 1, 0), updated_at = now()
  WHERE id = p_team_id;

  RETURN jsonb_build_object('status', 'left');
END;
$$;

-- 2o. contribute_fet_to_team (from 005)
CREATE OR REPLACE FUNCTION contribute_fet_to_team(
  p_team_id TEXT,
  p_amount_fet BIGINT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_balance BIGINT;
  v_contribution_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_amount_fet IS NULL OR p_amount_fet <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than zero';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.teams
    WHERE id = p_team_id AND is_active = true AND fet_contributions_enabled = true
  ) THEN
    RAISE EXCEPTION 'FET contributions not enabled for this team';
  END IF;

  SELECT available_balance_fet INTO v_balance
  FROM public.fet_wallets
  WHERE user_id = v_user_id
  FOR UPDATE;

  IF v_balance IS NULL OR v_balance < p_amount_fet THEN
    RAISE EXCEPTION 'Insufficient FET balance';
  END IF;

  UPDATE public.fet_wallets
  SET available_balance_fet = available_balance_fet - p_amount_fet,
      updated_at = now()
  WHERE user_id = v_user_id;

  INSERT INTO public.team_contributions (team_id, user_id, contribution_type, amount_fet, status)
  VALUES (p_team_id, v_user_id, 'fet', p_amount_fet, 'completed')
  RETURNING id INTO v_contribution_id;

  INSERT INTO public.fet_wallet_transactions (
    user_id, tx_type, direction, amount_fet,
    balance_before_fet, balance_after_fet,
    reference_type, reference_id, title
  ) VALUES (
    v_user_id, 'contribution', 'debit', p_amount_fet,
    v_balance, v_balance - p_amount_fet,
    'team_contribution', v_contribution_id,
    'Team contribution'
  );

  RETURN jsonb_build_object(
    'status', 'completed',
    'contribution_id', v_contribution_id,
    'balance_after', v_balance - p_amount_fet
  );
END;
$$;

-- 2p. get_team_anonymous_fans (from 005)
CREATE OR REPLACE FUNCTION get_team_anonymous_fans(
  p_team_id TEXT,
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0
) RETURNS TABLE (
  anonymous_fan_id TEXT,
  joined_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT ts.anonymous_fan_id, ts.joined_at
  FROM public.team_supporters ts
  WHERE ts.team_id = p_team_id AND ts.is_active = true
  ORDER BY ts.joined_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

-- ==================================================================
-- 3. Unique dedup index on live_match_events
--    The event_signature column was added via ALTER but the unique
--    index may not exist on all environments.
-- ==================================================================

-- First ensure the column exists
ALTER TABLE public.live_match_events
  ADD COLUMN IF NOT EXISTS event_signature text;

-- Create unique index for deduplication
CREATE UNIQUE INDEX IF NOT EXISTS live_match_events_match_signature_idx
  ON public.live_match_events (match_id, event_signature)
  WHERE event_signature IS NOT NULL;

-- ==================================================================
-- 4. Missing FK on prediction_slip_selections.match_id
-- ==================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE constraint_type = 'FOREIGN KEY'
      AND table_schema = 'public'
      AND table_name = 'prediction_slip_selections'
      AND constraint_name = 'prediction_slip_selections_match_id_fkey'
  ) THEN
    -- Only add FK if all existing match_ids exist in matches table
    IF NOT EXISTS (
      SELECT 1
      FROM public.prediction_slip_selections pss
      WHERE NOT EXISTS (
        SELECT 1 FROM public.matches m WHERE m.id = pss.match_id
      )
      LIMIT 1
    ) THEN
      ALTER TABLE public.prediction_slip_selections
        ADD CONSTRAINT prediction_slip_selections_match_id_fkey
        FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE CASCADE;
    END IF;
  END IF;
END $$;

-- ==================================================================
-- 5. RLS + policies on rate_limits table
-- ==================================================================

ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;

-- Rate limits are managed by SECURITY DEFINER functions only.
-- No direct user access needed.
REVOKE ALL ON public.rate_limits FROM anon, authenticated;
GRANT SELECT, INSERT, DELETE ON public.rate_limits TO service_role;

-- ==================================================================
-- 6. Performance indexes
-- ==================================================================

-- Matches by date + status for calendar/fixture queries
CREATE INDEX IF NOT EXISTS idx_matches_date_status
  ON public.matches (date DESC, status);

-- Matches by competition for listing pages
CREATE INDEX IF NOT EXISTS idx_matches_competition_date
  ON public.matches (competition_id, date DESC);

-- Profiles by phone for auth lookup
CREATE INDEX IF NOT EXISTS idx_profiles_phone_number
  ON public.profiles (phone_number)
  WHERE phone_number IS NOT NULL;

-- ==================================================================
-- 7. get_live_matches() convenience RPC
-- ==================================================================

CREATE OR REPLACE FUNCTION public.get_live_matches()
RETURNS SETOF public.matches
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT m.*
  FROM public.matches m
  WHERE public.normalize_match_status_value(m.status) = 'live'
  ORDER BY m.date ASC, m.kickoff_time ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_live_matches() TO anon, authenticated;

-- ==================================================================
-- 8. Request log cleanup function + cron
-- ==================================================================

CREATE OR REPLACE FUNCTION public.cleanup_match_sync_request_log(
  p_retain_days integer DEFAULT 7
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted integer;
BEGIN
  DELETE FROM public.match_sync_request_log
  WHERE completed_at IS NOT NULL
    AND completed_at < now() - make_interval(days => p_retain_days);

  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  RETURN jsonb_build_object(
    'deleted', v_deleted,
    'retain_days', p_retain_days,
    'cleaned_at', timezone('utc', now())
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.cleanup_match_sync_request_log(integer) TO service_role;

-- Schedule cleanup weekly
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cleanup-match-sync-log') THEN
    PERFORM cron.unschedule('cleanup-match-sync-log');
  END IF;

  PERFORM cron.schedule(
    'cleanup-match-sync-log',
    '0 3 * * 0',
    $cron$SELECT public.cleanup_match_sync_request_log(7);$cron$
  );
END $$;

-- Also schedule rate_limits cleanup daily
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cleanup-rate-limits') THEN
    PERFORM cron.unschedule('cleanup-rate-limits');
  END IF;

  PERFORM cron.schedule(
    'cleanup-rate-limits',
    '0 4 * * *',
    $cron$SELECT public.cleanup_rate_limits();$cron$
  );
END $$;

-- ==================================================================
-- 9. refresh_materialized_views() RPC
-- ==================================================================

CREATE OR REPLACE FUNCTION public.refresh_materialized_views()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_refreshed text[] := '{}';
  v_view_name text;
BEGIN
  FOR v_view_name IN
    SELECT matviewname
    FROM pg_matviews
    WHERE schemaname = 'public'
    ORDER BY matviewname
  LOOP
    BEGIN
      EXECUTE format('REFRESH MATERIALIZED VIEW CONCURRENTLY public.%I', v_view_name);
      v_refreshed := v_refreshed || v_view_name;
    EXCEPTION WHEN others THEN
      -- Fallback to non-concurrent refresh if unique index is missing
      BEGIN
        EXECUTE format('REFRESH MATERIALIZED VIEW public.%I', v_view_name);
        v_refreshed := v_refreshed || v_view_name;
      EXCEPTION WHEN others THEN
        NULL; -- skip views that can't be refreshed
      END;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'refreshed', to_jsonb(v_refreshed),
    'refreshed_at', timezone('utc', now())
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.refresh_materialized_views() TO service_role;

-- ==================================================================
-- 10. Vault secret cleanup — remove legacy openfootball fallbacks
--     Redefine enqueue_match_sync_jobs with clean vault queries.
-- ==================================================================

CREATE OR REPLACE FUNCTION public.enqueue_match_sync_jobs(
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
  v_project_url text;
  v_anon_key text;
  v_admin_secret text;
  v_timeout_milliseconds integer;
  v_request_id bigint;
  v_dispatched integer := 0;
  v_enqueue_failures integer := 0;
  v_request_payload jsonb;
  v_error_text text;
  v_live_poll_interval_seconds integer := 60;
  v_live_window_after_kickoff_minutes integer := 210;
  v_max_event_requests_per_cycle integer := 24;
  v_limit integer;
  rec record;
BEGIN
  IF p_fetch_type NOT IN ('events', 'odds') THEN
    RAISE EXCEPTION 'Unsupported fetch type: %', p_fetch_type;
  END IF;

  SELECT
    live_poll_interval_seconds,
    live_window_after_kickoff_minutes,
    max_event_requests_per_cycle
  INTO
    v_live_poll_interval_seconds,
    v_live_window_after_kickoff_minutes,
    v_max_event_requests_per_cycle
  FROM public.match_sync_runtime_settings
  LIMIT 1;

  v_limit := greatest(
    coalesce(
      p_limit,
      CASE
        WHEN p_fetch_type = 'events' THEN v_max_event_requests_per_cycle
        ELSE 8
      END
    ),
    1
  );

  v_timeout_milliseconds := CASE
    WHEN p_fetch_type = 'events' THEN 45000
    ELSE 30000
  END;

  -- Clean vault queries: no legacy openfootball fallbacks
  SELECT
    (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'match_sync_project_url'),
    (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'match_sync_anon_key'),
    (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'match_sync_admin_secret')
  INTO v_project_url, v_anon_key, v_admin_secret;

  IF v_project_url IS NULL OR v_anon_key IS NULL OR v_admin_secret IS NULL THEN
    RAISE EXCEPTION 'Missing vault secrets for match sync dispatcher. Required: match_sync_project_url, match_sync_anon_key, match_sync_admin_secret';
  END IF;

  FOR rec IN
    WITH candidates AS (
      SELECT
        m.id,
        m.home_team,
        m.away_team,
        c.name AS competition_name,
        m.source_url,
        public.normalize_match_status_value(m.status) AS normalized_status,
        public.match_kickoff_at_utc(m.date, m.kickoff_time) AS kickoff_at,
        live.status AS live_status,
        live.next_check_at,
        live.consecutive_failures
      FROM public.matches AS m
      LEFT JOIN public.competitions AS c ON c.id = m.competition_id
      LEFT JOIN public.match_live_state AS live ON live.match_id = m.id
      LEFT JOIN public.match_sync_state AS sync ON sync.match_id = m.id
      WHERE NOT EXISTS (
          SELECT 1
          FROM public.match_sync_request_log AS log
          WHERE log.match_id = m.id
            AND log.fetch_type = p_fetch_type
            AND log.completed_at IS NULL
            AND log.requested_at >= v_now - CASE
              WHEN p_fetch_type = 'events'
                THEN make_interval(secs => greatest(v_live_poll_interval_seconds * 2, 120))
              ELSE interval '45 minutes'
            END
        )
        AND (
          CASE
            WHEN p_fetch_type = 'events' THEN
              (
                coalesce(live.next_check_at, 'epoch'::timestamptz) <= v_now
                AND public.normalize_match_status_value(m.status) NOT IN ('finished', 'cancelled', 'postponed')
                AND (
                  public.normalize_match_status_value(coalesce(live.status, m.status)) = 'live'
                  OR public.normalize_match_status_value(m.status) = 'live'
                  OR public.match_kickoff_at_utc(m.date, m.kickoff_time)
                    BETWEEN v_now - make_interval(mins => greatest(v_live_window_after_kickoff_minutes, 30))
                    AND v_now
                )
              )
            WHEN p_fetch_type = 'odds' THEN
              public.normalize_match_status_value(m.status) IN ('upcoming', 'live')
              AND public.match_kickoff_at_utc(m.date, m.kickoff_time) BETWEEN
                v_now - interval '2 hours' AND v_now + interval '36 hours'
              AND coalesce(sync.last_odds_refresh_at, 'epoch'::timestamptz) <=
                v_now - CASE
                  WHEN public.normalize_match_status_value(m.status) = 'live' THEN interval '10 minutes'
                  WHEN coalesce(sync.consecutive_odds_failures, 0) >= 3 THEN interval '60 minutes'
                  ELSE interval '30 minutes'
                END
            ELSE false
          END
        )
      ORDER BY
        CASE
          WHEN public.normalize_match_status_value(coalesce(live.status, m.status)) = 'live' THEN 0
          ELSE 1
        END,
        kickoff_at ASC,
        m.id ASC
      LIMIT v_limit
    )
    SELECT * FROM candidates
  LOOP
    v_request_payload := jsonb_build_object(
      'teamA', rec.home_team,
      'teamB', rec.away_team,
      'matchId', rec.id,
      'fetchType', p_fetch_type,
      'competitionName', rec.competition_name,
      'sourceUrl', rec.source_url,
      'kickoffAt', rec.kickoff_at
    );

    BEGIN
      v_request_id := net.http_post(
        url := v_project_url || '/functions/v1/gemini-sports-data',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || v_anon_key,
          'apikey', v_anon_key,
          'x-match-sync-secret', v_admin_secret
        ),
        body := v_request_payload,
        timeout_milliseconds := v_timeout_milliseconds
      );

      INSERT INTO public.match_sync_request_log (
        match_id, fetch_type, request_id, request_payload, requested_at
      )
      VALUES (rec.id, p_fetch_type, v_request_id, v_request_payload, v_now);

      IF p_fetch_type = 'events' THEN
        INSERT INTO public.match_sync_state (
          match_id, last_events_refresh_at, last_events_status,
          last_events_http_status, last_events_error, updated_at
        )
        VALUES (rec.id, v_now, 'queued', NULL, NULL, v_now)
        ON CONFLICT (match_id) DO UPDATE
        SET
          last_events_refresh_at = greatest(
            coalesce(public.match_sync_state.last_events_refresh_at, 'epoch'::timestamptz),
            excluded.last_events_refresh_at
          ),
          last_events_status = 'queued',
          last_events_http_status = NULL,
          last_events_error = NULL,
          updated_at = excluded.updated_at;
      ELSE
        INSERT INTO public.match_sync_state (
          match_id, last_odds_refresh_at, last_odds_status,
          last_odds_http_status, last_odds_error, updated_at
        )
        VALUES (rec.id, v_now, 'queued', NULL, NULL, v_now)
        ON CONFLICT (match_id) DO UPDATE
        SET
          last_odds_refresh_at = greatest(
            coalesce(public.match_sync_state.last_odds_refresh_at, 'epoch'::timestamptz),
            excluded.last_odds_refresh_at
          ),
          last_odds_status = 'queued',
          last_odds_http_status = NULL,
          last_odds_error = NULL,
          updated_at = excluded.updated_at;
      END IF;

      v_dispatched := v_dispatched + 1;
    EXCEPTION WHEN others THEN
      v_error_text := SQLERRM;

      INSERT INTO public.match_sync_request_log (
        match_id, fetch_type, request_id, request_payload,
        response_status, success, error_text, requested_at, completed_at
      )
      VALUES (rec.id, p_fetch_type, NULL, v_request_payload, NULL, false, v_error_text, v_now, v_now);

      IF p_fetch_type = 'events' THEN
        INSERT INTO public.match_sync_state (
          match_id, last_events_refresh_at, last_events_http_status,
          last_events_error, consecutive_event_failures, updated_at
        )
        VALUES (rec.id, v_now, NULL, v_error_text, 1, v_now)
        ON CONFLICT (match_id) DO UPDATE
        SET
          last_events_refresh_at = excluded.last_events_refresh_at,
          last_events_http_status = excluded.last_events_http_status,
          last_events_error = excluded.last_events_error,
          consecutive_event_failures = public.match_sync_state.consecutive_event_failures + 1,
          updated_at = excluded.updated_at;
      ELSE
        INSERT INTO public.match_sync_state (
          match_id, last_odds_refresh_at, last_odds_http_status,
          last_odds_error, consecutive_odds_failures, updated_at
        )
        VALUES (rec.id, v_now, NULL, v_error_text, 1, v_now)
        ON CONFLICT (match_id) DO UPDATE
        SET
          last_odds_refresh_at = excluded.last_odds_refresh_at,
          last_odds_http_status = excluded.last_odds_http_status,
          last_odds_error = excluded.last_odds_error,
          consecutive_odds_failures = public.match_sync_state.consecutive_odds_failures + 1,
          updated_at = excluded.updated_at;
      END IF;

      v_enqueue_failures := v_enqueue_failures + 1;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'fetch_type', p_fetch_type,
    'queued', v_dispatched,
    'queue_failures', v_enqueue_failures,
    'enqueued_at', v_now
  );
END;
$$;

COMMIT;
