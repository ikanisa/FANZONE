-- ============================================================
-- 20260418031500_fullstack_hardening.sql
-- Complete backend hardening for FANZONE production launch.
--
-- Contents:
--   1) settle_pool — transactional FET distribution to winners
--   2) void_pool — cancel pool + refund all stakes
--   3) auto_settle_pools — settle all eligible pools for a match
--   4) settle_prediction_slips — settle free solo predictions
--   5) Rate limiting functions
--   6) Admin operational RPCs (ban, freeze, credit/debit)
--   7) Daily challenge schema + RPC
--   8) Notification device tokens table
--   9) User profile enhancements (ban, streaks)
--  10) RLS hardening for engagement tables
--  11) FET supply management
-- ============================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════
-- 1) RPC: settle_pool — Settle a pool after match completion
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION settle_pool(
  p_pool_id UUID,
  p_official_home_score INT,
  p_official_away_score INT
) RETURNS JSONB AS $$
DECLARE
  v_pool RECORD;
  v_winner_count INT := 0;
  v_loser_count INT := 0;
  v_payout_per_winner BIGINT := 0;
  v_entry RECORD;
  v_is_winner BOOLEAN;
  v_balance_before BIGINT;
BEGIN
  -- Lock the pool
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

  -- Count winners (exact score match)
  SELECT COUNT(*) INTO v_winner_count
  FROM public.prediction_challenge_entries
  WHERE challenge_id = p_pool_id
    AND status = 'active'
    AND predicted_home_score = p_official_home_score
    AND predicted_away_score = p_official_away_score;

  v_loser_count := v_pool.total_participants - v_winner_count;

  -- Calculate payout
  IF v_winner_count > 0 THEN
    v_payout_per_winner := v_pool.total_pool_fet / v_winner_count;
  END IF;

  -- Process each entry
  FOR v_entry IN
    SELECT * FROM public.prediction_challenge_entries
    WHERE challenge_id = p_pool_id AND status = 'active'
    FOR UPDATE
  LOOP
    v_is_winner := (
      v_entry.predicted_home_score = p_official_home_score
      AND v_entry.predicted_away_score = p_official_away_score
    );

    -- Update entry status
    UPDATE public.prediction_challenge_entries
    SET status = CASE WHEN v_is_winner THEN 'won' ELSE 'lost' END,
        payout_fet = CASE WHEN v_is_winner THEN v_payout_per_winner ELSE 0 END,
        settled_at = now()
    WHERE id = v_entry.id;

    -- Credit winner wallets
    IF v_is_winner AND v_payout_per_winner > 0 THEN
      -- Get current balance
      SELECT available_balance_fet INTO v_balance_before
      FROM public.fet_wallets
      WHERE user_id = v_entry.user_id
      FOR UPDATE;

      -- Credit wallet
      UPDATE public.fet_wallets
      SET available_balance_fet = available_balance_fet + v_payout_per_winner,
          updated_at = now()
      WHERE user_id = v_entry.user_id;

      -- Record transaction
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

  -- If no winners, return stakes to all participants
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

  -- Update pool record
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
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ═══════════════════════════════════════════════════════════════
-- 2) RPC: void_pool — Cancel a pool + refund all stakes
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION void_pool(
  p_pool_id UUID,
  p_reason TEXT DEFAULT 'Admin cancelled'
) RETURNS JSONB AS $$
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

  -- Refund all active entries
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

  -- Update pool
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
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ═══════════════════════════════════════════════════════════════
-- 3) RPC: auto_settle_pools — Settle all pools for a finished match
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION auto_settle_pools(
  p_match_id TEXT,
  p_home_score INT,
  p_away_score INT
) RETURNS JSONB AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ═══════════════════════════════════════════════════════════════
-- 4) RPC: settle_prediction_slips — Settle free predictions
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION settle_prediction_slips_for_match(
  p_match_id TEXT,
  p_official_home_score INT,
  p_official_away_score INT
) RETURNS JSONB AS $$
DECLARE
  v_selection RECORD;
  v_is_correct BOOLEAN;
  v_settled_count INT := 0;
  v_slip_ids UUID[];
BEGIN
  -- Settle each selection for this match
  FOR v_selection IN
    SELECT s.* FROM public.prediction_slip_selections s
    JOIN public.prediction_slips sl ON sl.id = s.slip_id
    WHERE s.match_id = p_match_id AND s.result = 'pending'
    FOR UPDATE OF s
  LOOP
    v_is_correct := CASE s.market
      WHEN 'exact_score' THEN
        v_selection.selection = (p_official_home_score || '-' || p_official_away_score)
      WHEN 'match_result' THEN
        v_selection.selection = CASE
          WHEN p_official_home_score > p_official_away_score THEN '1'
          WHEN p_official_home_score < p_official_away_score THEN '2'
          ELSE 'X'
        END
      WHEN 'over_under' THEN
        CASE
          WHEN v_selection.selection = 'over_2.5' THEN (p_official_home_score + p_official_away_score) > 2
          WHEN v_selection.selection = 'under_2.5' THEN (p_official_home_score + p_official_away_score) < 3
          ELSE FALSE
        END
      WHEN 'btts' THEN
        CASE
          WHEN v_selection.selection = 'yes' THEN p_official_home_score > 0 AND p_official_away_score > 0
          WHEN v_selection.selection = 'no' THEN p_official_home_score = 0 OR p_official_away_score = 0
          ELSE FALSE
        END
      ELSE FALSE
    END;

    UPDATE public.prediction_slip_selections
    SET result = CASE WHEN v_is_correct THEN 'won' ELSE 'lost' END
    WHERE id = v_selection.id;

    v_slip_ids := v_slip_ids || v_selection.slip_id;
    v_settled_count := v_settled_count + 1;
  END LOOP;

  -- Update parent slips
  UPDATE public.prediction_slips sl
  SET status = CASE
    WHEN NOT EXISTS (
      SELECT 1 FROM public.prediction_slip_selections
      WHERE slip_id = sl.id AND result = 'pending'
    ) THEN
      CASE
        WHEN NOT EXISTS (
          SELECT 1 FROM public.prediction_slip_selections
          WHERE slip_id = sl.id AND result = 'lost'
        ) THEN 'settled_win'
        ELSE 'settled_loss'
      END
    ELSE sl.status
  END,
  settled_at = CASE
    WHEN NOT EXISTS (
      SELECT 1 FROM public.prediction_slip_selections
      WHERE slip_id = sl.id AND result = 'pending'
    ) THEN now()
    ELSE sl.settled_at
  END,
  updated_at = now()
  WHERE sl.id = ANY(v_slip_ids);

  -- Credit FET for winning slips
  INSERT INTO public.fet_wallet_transactions (
    user_id, tx_type, direction, amount_fet,
    balance_before_fet, balance_after_fet,
    reference_type, reference_id, title
  )
  SELECT
    sl.user_id,
    'prediction_earn',
    'credit',
    sl.projected_earn_fet,
    COALESCE(w.available_balance_fet, 0),
    COALESCE(w.available_balance_fet, 0) + sl.projected_earn_fet,
    'prediction_slip',
    sl.id,
    'Prediction win — earned ' || sl.projected_earn_fet || ' FET'
  FROM public.prediction_slips sl
  LEFT JOIN public.fet_wallets w ON w.user_id = sl.user_id
  WHERE sl.id = ANY(v_slip_ids)
    AND sl.status = 'settled_win'
    AND sl.projected_earn_fet > 0;

  UPDATE public.fet_wallets w
  SET available_balance_fet = w.available_balance_fet + sl.projected_earn_fet,
      updated_at = now()
  FROM public.prediction_slips sl
  WHERE w.user_id = sl.user_id
    AND sl.id = ANY(v_slip_ids)
    AND sl.status = 'settled_win'
    AND sl.projected_earn_fet > 0;

  RETURN jsonb_build_object(
    'match_id', p_match_id,
    'selections_settled', v_settled_count,
    'slips_affected', array_length(v_slip_ids, 1)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ═══════════════════════════════════════════════════════════════
-- 5) Rate limiting table + helper
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.rate_limits (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL,
  action TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rate_limits_lookup
  ON public.rate_limits (user_id, action, created_at DESC);

-- Auto-cleanup: delete entries older than 24h
CREATE OR REPLACE FUNCTION cleanup_rate_limits()
RETURNS VOID AS $$
BEGIN
  DELETE FROM public.rate_limits
  WHERE created_at < now() - interval '24 hours';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Rate check helper
CREATE OR REPLACE FUNCTION check_rate_limit(
  p_user_id UUID,
  p_action TEXT,
  p_max_count INT,
  p_window_hours INT DEFAULT 1
) RETURNS BOOLEAN AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add rate limiting to create_pool
CREATE OR REPLACE FUNCTION create_pool_rate_limited(
  p_match_id TEXT,
  p_home_score INT,
  p_away_score INT,
  p_stake BIGINT
) RETURNS JSONB AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add rate limiting to transfers
CREATE OR REPLACE FUNCTION transfer_fet_rate_limited(
  p_recipient_email TEXT,
  p_amount INT
) RETURNS VOID AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ═══════════════════════════════════════════════════════════════
-- 6) Admin operational RPCs
-- ═══════════════════════════════════════════════════════════════

-- User status table for bans/suspensions (separate from auth.users which we cannot ALTER)

CREATE TABLE IF NOT EXISTS public.user_status (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  is_banned BOOLEAN DEFAULT false,
  banned_until TIMESTAMPTZ,
  ban_reason TEXT,
  is_suspended BOOLEAN DEFAULT false,
  suspended_until TIMESTAMPTZ,
  suspend_reason TEXT,
  wallet_frozen BOOLEAN DEFAULT false,
  wallet_freeze_reason TEXT,
  prediction_streak INT DEFAULT 0,
  longest_streak INT DEFAULT 0,
  total_predictions INT DEFAULT 0,
  total_pools_entered INT DEFAULT 0,
  total_pools_won INT DEFAULT 0,
  total_fet_earned BIGINT DEFAULT 0,
  total_fet_spent BIGINT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_status_banned ON public.user_status (is_banned) WHERE is_banned = true;

-- Admin: Ban user
CREATE OR REPLACE FUNCTION admin_ban_user(
  p_target_user_id UUID,
  p_reason TEXT DEFAULT 'Policy violation',
  p_until TIMESTAMPTZ DEFAULT NULL
) RETURNS JSONB AS $$
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

  -- Audit log
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Admin: Unban user
CREATE OR REPLACE FUNCTION admin_unban_user(
  p_target_user_id UUID
) RETURNS JSONB AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Admin: Freeze wallet
CREATE OR REPLACE FUNCTION admin_freeze_wallet(
  p_target_user_id UUID,
  p_reason TEXT DEFAULT 'Suspicious activity'
) RETURNS JSONB AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Admin: Unfreeze wallet
CREATE OR REPLACE FUNCTION admin_unfreeze_wallet(
  p_target_user_id UUID
) RETURNS JSONB AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Admin: Credit FET to user
CREATE OR REPLACE FUNCTION admin_credit_fet(
  p_target_user_id UUID,
  p_amount BIGINT,
  p_reason TEXT DEFAULT 'Admin credit'
) RETURNS JSONB AS $$
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

  -- Create wallet if not exists
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Admin: Debit FET from user
CREATE OR REPLACE FUNCTION admin_debit_fet(
  p_target_user_id UUID,
  p_amount BIGINT,
  p_reason TEXT DEFAULT 'Admin debit'
) RETURNS JSONB AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ═══════════════════════════════════════════════════════════════
-- 7) Daily challenge schema + RPC
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.daily_challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  date DATE NOT NULL UNIQUE,
  match_id TEXT NOT NULL,
  match_name TEXT NOT NULL DEFAULT '',
  title TEXT NOT NULL DEFAULT 'Daily Challenge',
  description TEXT,
  reward_fet BIGINT NOT NULL DEFAULT 50,
  bonus_exact_fet BIGINT NOT NULL DEFAULT 200,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'settled', 'cancelled')),
  official_home_score INT,
  official_away_score INT,
  total_entries INT DEFAULT 0,
  total_winners INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  settled_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.daily_challenge_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id UUID NOT NULL REFERENCES public.daily_challenges(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  predicted_home_score INT NOT NULL,
  predicted_away_score INT NOT NULL,
  result TEXT DEFAULT 'pending' CHECK (result IN ('pending', 'correct_result', 'exact_score', 'wrong')),
  payout_fet BIGINT DEFAULT 0,
  submitted_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (challenge_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_daily_challenges_date ON public.daily_challenges (date DESC);
CREATE INDEX IF NOT EXISTS idx_daily_challenge_entries_user ON public.daily_challenge_entries (user_id, submitted_at DESC);

-- RPC: Submit daily challenge prediction (free, one per day)
CREATE OR REPLACE FUNCTION submit_daily_prediction(
  p_challenge_id UUID,
  p_home_score INT,
  p_away_score INT
) RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_challenge RECORD;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_challenge
  FROM public.daily_challenges
  WHERE id = p_challenge_id AND status = 'active';

  IF v_challenge IS NULL THEN
    RAISE EXCEPTION 'Challenge not found or inactive';
  END IF;

  IF v_challenge.date < CURRENT_DATE THEN
    RAISE EXCEPTION 'Challenge has expired';
  END IF;

  -- Insert or update (one entry per user per challenge)
  INSERT INTO public.daily_challenge_entries (
    challenge_id, user_id, predicted_home_score, predicted_away_score
  ) VALUES (
    p_challenge_id, v_user_id, p_home_score, p_away_score
  )
  ON CONFLICT (challenge_id, user_id)
  DO UPDATE SET
    predicted_home_score = p_home_score,
    predicted_away_score = p_away_score,
    submitted_at = now();

  -- Update entry count
  UPDATE public.daily_challenges
  SET total_entries = (
    SELECT COUNT(*) FROM public.daily_challenge_entries
    WHERE challenge_id = p_challenge_id
  )
  WHERE id = p_challenge_id;

  RETURN jsonb_build_object(
    'status', 'submitted',
    'challenge_id', p_challenge_id,
    'prediction', p_home_score || '-' || p_away_score
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Settle daily challenge
CREATE OR REPLACE FUNCTION settle_daily_challenge(
  p_challenge_id UUID,
  p_home_score INT,
  p_away_score INT
) RETURNS JSONB AS $$
DECLARE
  v_challenge RECORD;
  v_entry RECORD;
  v_is_result BOOLEAN;
  v_is_exact BOOLEAN;
  v_payout BIGINT;
  v_balance_before BIGINT;
  v_winner_count INT := 0;
BEGIN
  SELECT * INTO v_challenge
  FROM public.daily_challenges
  WHERE id = p_challenge_id
  FOR UPDATE;

  IF v_challenge IS NULL THEN
    RAISE EXCEPTION 'Challenge not found';
  END IF;

  IF v_challenge.status != 'active' THEN
    RAISE EXCEPTION 'Challenge already settled';
  END IF;

  FOR v_entry IN
    SELECT * FROM public.daily_challenge_entries
    WHERE challenge_id = p_challenge_id AND result = 'pending'
    FOR UPDATE
  LOOP
    v_is_exact := (v_entry.predicted_home_score = p_home_score AND v_entry.predicted_away_score = p_away_score);

    v_is_result := v_is_exact OR (
      SIGN(v_entry.predicted_home_score - v_entry.predicted_away_score) =
      SIGN(p_home_score - p_away_score)
    );

    IF v_is_exact THEN
      v_payout := v_challenge.bonus_exact_fet;
    ELSIF v_is_result THEN
      v_payout := v_challenge.reward_fet;
    ELSE
      v_payout := 0;
    END IF;

    UPDATE public.daily_challenge_entries
    SET result = CASE
      WHEN v_is_exact THEN 'exact_score'
      WHEN v_is_result THEN 'correct_result'
      ELSE 'wrong'
    END,
    payout_fet = v_payout
    WHERE id = v_entry.id;

    IF v_payout > 0 THEN
      v_winner_count := v_winner_count + 1;

      SELECT available_balance_fet INTO v_balance_before
      FROM public.fet_wallets
      WHERE user_id = v_entry.user_id
      FOR UPDATE;

      INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
      VALUES (v_entry.user_id, v_payout, 0)
      ON CONFLICT (user_id) DO UPDATE
      SET available_balance_fet = fet_wallets.available_balance_fet + v_payout,
          updated_at = now();

      INSERT INTO public.fet_wallet_transactions (
        user_id, tx_type, direction, amount_fet,
        balance_before_fet, balance_after_fet,
        reference_type, reference_id, title
      ) VALUES (
        v_entry.user_id, 'daily_challenge', 'credit', v_payout,
        COALESCE(v_balance_before, 0),
        COALESCE(v_balance_before, 0) + v_payout,
        'daily_challenge', p_challenge_id,
        CASE WHEN v_is_exact THEN 'Daily challenge — exact score bonus!'
        ELSE 'Daily challenge — correct result'
        END
      );
    END IF;
  END LOOP;

  UPDATE public.daily_challenges
  SET status = 'settled',
      official_home_score = p_home_score,
      official_away_score = p_away_score,
      total_winners = v_winner_count,
      settled_at = now()
  WHERE id = p_challenge_id;

  RETURN jsonb_build_object(
    'status', 'settled',
    'challenge_id', p_challenge_id,
    'total_winners', v_winner_count
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ═══════════════════════════════════════════════════════════════
-- 8) Push notification device tokens
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, token)
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON public.device_tokens (user_id) WHERE is_active = true;

-- Notification preferences
CREATE TABLE IF NOT EXISTS public.notification_preferences (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  goal_alerts BOOLEAN DEFAULT true,
  pool_updates BOOLEAN DEFAULT true,
  daily_challenge BOOLEAN DEFAULT true,
  wallet_activity BOOLEAN DEFAULT true,
  community_news BOOLEAN DEFAULT true,
  marketing BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Notification log
CREATE TABLE IF NOT EXISTS public.notification_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT,
  data JSONB DEFAULT '{}',
  sent_at TIMESTAMPTZ DEFAULT now(),
  read_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_notification_log_user ON public.notification_log (user_id, sent_at DESC);


-- ═══════════════════════════════════════════════════════════════
-- 9) RLS hardening for engagement tables
-- ═══════════════════════════════════════════════════════════════

-- fet_wallets: users read own only
ALTER TABLE public.fet_wallets ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'fet_wallets' AND policyname = 'Users read own wallet'
  ) THEN
    CREATE POLICY "Users read own wallet"
      ON public.fet_wallets FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END $$;

-- fet_wallet_transactions: users read own only
ALTER TABLE public.fet_wallet_transactions ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'fet_wallet_transactions' AND policyname = 'Users read own transactions'
  ) THEN
    CREATE POLICY "Users read own transactions"
      ON public.fet_wallet_transactions FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END $$;

-- prediction_challenges: public read, auth write via RPC only
ALTER TABLE public.prediction_challenges ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'prediction_challenges' AND policyname = 'Public read challenges'
  ) THEN
    CREATE POLICY "Public read challenges"
      ON public.prediction_challenges FOR SELECT
      USING (true);
  END IF;
END $$;

-- prediction_challenge_entries: users read own, auth write via RPC only
ALTER TABLE public.prediction_challenge_entries ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'prediction_challenge_entries' AND policyname = 'Users read own entries'
  ) THEN
    CREATE POLICY "Users read own entries"
      ON public.prediction_challenge_entries FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END $$;

-- matches: public read
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'matches' AND policyname = 'Public read matches'
  ) THEN
    CREATE POLICY "Public read matches"
      ON public.matches FOR SELECT
      USING (true);
  END IF;
END $$;

-- user_followed_teams: users read/write own only
ALTER TABLE public.user_followed_teams ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'user_followed_teams' AND policyname = 'Users manage own team follows'
  ) THEN
    CREATE POLICY "Users manage own team follows"
      ON public.user_followed_teams FOR ALL
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

-- user_followed_competitions: users read/write own only
ALTER TABLE public.user_followed_competitions ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'user_followed_competitions' AND policyname = 'Users manage own competition follows'
  ) THEN
    CREATE POLICY "Users manage own competition follows"
      ON public.user_followed_competitions FOR ALL
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

-- New tables RLS
ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_challenge_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_log ENABLE ROW LEVEL SECURITY;

-- daily_challenges: public read
CREATE POLICY "Public read daily challenges"
  ON public.daily_challenges FOR SELECT
  USING (true);

-- daily_challenge_entries: users read own
CREATE POLICY "Users read own daily entries"
  ON public.daily_challenge_entries FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- device_tokens: users manage own
CREATE POLICY "Users manage own device tokens"
  ON public.device_tokens FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- notification_preferences: users manage own
CREATE POLICY "Users manage own notification prefs"
  ON public.notification_preferences FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- notification_log: users read own
CREATE POLICY "Users read own notifications"
  ON public.notification_log FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- user_status: users read own, admins read all
CREATE POLICY "Users read own status"
  ON public.user_status FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);


-- ═══════════════════════════════════════════════════════════════
-- 10) FET supply management views
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW public.fet_supply_overview AS
SELECT
  SUM(available_balance_fet) AS total_available,
  SUM(locked_balance_fet) AS total_locked,
  SUM(available_balance_fet + locked_balance_fet) AS total_supply,
  COUNT(*) AS total_wallets,
  COUNT(*) FILTER (WHERE available_balance_fet > 0) AS active_wallets,
  AVG(available_balance_fet)::BIGINT AS avg_balance,
  MAX(available_balance_fet) AS max_balance
FROM public.fet_wallets;


-- ═══════════════════════════════════════════════════════════════
-- 11) Grants
-- ═══════════════════════════════════════════════════════════════

GRANT EXECUTE ON FUNCTION settle_pool(UUID, INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION void_pool(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION auto_settle_pools(TEXT, INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION create_pool_rate_limited(TEXT, INT, INT, BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION transfer_fet_rate_limited(TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_ban_user(UUID, TEXT, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_unban_user(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_freeze_wallet(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_unfreeze_wallet(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_credit_fet(UUID, BIGINT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_debit_fet(UUID, BIGINT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION submit_daily_prediction(UUID, INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION settle_daily_challenge(UUID, INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION settle_prediction_slips_for_match(TEXT, INT, INT) TO authenticated;

COMMIT;
