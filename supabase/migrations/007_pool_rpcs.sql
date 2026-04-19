-- ============================================================
-- 007_pool_rpcs.sql
-- Transactional RPCs for pool create/join operations.
-- Replaces client-side multi-insert with atomic server-side logic.
-- ============================================================

BEGIN;

-- ======================
-- 1) RPC: create_pool — Create a pool with entry atomically
-- ======================

CREATE OR REPLACE FUNCTION create_pool(
  p_match_id TEXT,
  p_home_score INT,
  p_away_score INT,
  p_stake BIGINT
) RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_balance BIGINT;
  v_pool_id UUID;
  v_entry_id UUID;
  v_match RECORD;
  v_display_name TEXT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Validate stake
  IF p_stake IS NULL OR p_stake < 10 THEN
    RAISE EXCEPTION 'Minimum stake is 10 FET';
  END IF;

  -- Validate scores
  IF p_home_score IS NULL OR p_away_score IS NULL OR p_home_score < 0 OR p_away_score < 0 THEN
    RAISE EXCEPTION 'Scores must be non-negative integers';
  END IF;

  -- Verify match exists and is upcoming
  SELECT id, home_team, away_team, status, date, kickoff_time
  INTO v_match
  FROM public.matches
  WHERE id = p_match_id;

  IF v_match IS NULL THEN
    RAISE EXCEPTION 'Match not found';
  END IF;

  IF v_match.status != 'upcoming' THEN
    RAISE EXCEPTION 'Can only create pools for upcoming matches';
  END IF;

  -- Get user display name
  SELECT COALESCE(
    raw_user_meta_data->>'display_name',
    raw_user_meta_data->>'full_name',
    'Fan ' || RIGHT(phone::text, 4)
  ) INTO v_display_name
  FROM auth.users
  WHERE id = v_user_id;

  -- Check wallet balance
  SELECT available_balance_fet INTO v_balance
  FROM public.fet_wallets
  WHERE user_id = v_user_id
  FOR UPDATE;

  IF v_balance IS NULL OR v_balance < p_stake THEN
    RAISE EXCEPTION 'Insufficient FET balance';
  END IF;

  -- Debit wallet
  UPDATE public.fet_wallets
  SET available_balance_fet = available_balance_fet - p_stake,
      updated_at = now()
  WHERE user_id = v_user_id;

  -- Create pool, lock_at = match date (or 30 min before kickoff)
  INSERT INTO public.prediction_challenges (
    match_id, creator_user_id, stake_fet, currency_code,
    status, lock_at, total_participants, total_pool_fet
  ) VALUES (
    p_match_id, v_user_id, p_stake, 'FET',
    'open', v_match.date - interval '30 minutes', 1, p_stake
  ) RETURNING id INTO v_pool_id;

  -- Create creator entry
  INSERT INTO public.prediction_challenge_entries (
    challenge_id, user_id, predicted_home_score, predicted_away_score,
    stake_fet, status
  ) VALUES (
    v_pool_id, v_user_id, p_home_score, p_away_score,
    p_stake, 'active'
  ) RETURNING id INTO v_entry_id;

  -- Record wallet transaction
  INSERT INTO public.fet_wallet_transactions (
    user_id, tx_type, direction, amount_fet,
    balance_before_fet, balance_after_fet,
    reference_type, reference_id, title
  ) VALUES (
    v_user_id, 'pool_stake', 'debit', p_stake,
    v_balance, v_balance - p_stake,
    'prediction_challenge', v_pool_id,
    'Pool stake: ' || v_match.home_team || ' vs ' || v_match.away_team
  );

  RETURN jsonb_build_object(
    'status', 'created',
    'pool_id', v_pool_id,
    'entry_id', v_entry_id,
    'balance_after', v_balance - p_stake
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ======================
-- 2) RPC: join_pool — Join an existing pool atomically
-- ======================

CREATE OR REPLACE FUNCTION join_pool(
  p_pool_id UUID,
  p_home_score INT,
  p_away_score INT
) RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_balance BIGINT;
  v_pool RECORD;
  v_entry_id UUID;
  v_match RECORD;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Validate scores
  IF p_home_score IS NULL OR p_away_score IS NULL OR p_home_score < 0 OR p_away_score < 0 THEN
    RAISE EXCEPTION 'Scores must be non-negative integers';
  END IF;

  -- Lock the pool row
  SELECT * INTO v_pool
  FROM public.prediction_challenges
  WHERE id = p_pool_id
  FOR UPDATE;

  IF v_pool IS NULL THEN
    RAISE EXCEPTION 'Pool not found';
  END IF;

  IF v_pool.status != 'open' THEN
    RAISE EXCEPTION 'Pool is no longer open';
  END IF;

  IF v_pool.lock_at <= now() THEN
    RAISE EXCEPTION 'Pool is locked (match is about to start)';
  END IF;

  IF v_pool.creator_user_id = v_user_id THEN
    RAISE EXCEPTION 'You cannot join your own pool';
  END IF;

  -- Check for duplicate entry
  IF EXISTS (
    SELECT 1 FROM public.prediction_challenge_entries
    WHERE challenge_id = p_pool_id AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'You already joined this pool';
  END IF;

  -- Check wallet balance
  SELECT available_balance_fet INTO v_balance
  FROM public.fet_wallets
  WHERE user_id = v_user_id
  FOR UPDATE;

  IF v_balance IS NULL OR v_balance < v_pool.stake_fet THEN
    RAISE EXCEPTION 'Insufficient FET balance';
  END IF;

  -- Debit wallet
  UPDATE public.fet_wallets
  SET available_balance_fet = available_balance_fet - v_pool.stake_fet,
      updated_at = now()
  WHERE user_id = v_user_id;

  -- Create entry
  INSERT INTO public.prediction_challenge_entries (
    challenge_id, user_id, predicted_home_score, predicted_away_score,
    stake_fet, status
  ) VALUES (
    p_pool_id, v_user_id, p_home_score, p_away_score,
    v_pool.stake_fet, 'active'
  ) RETURNING id INTO v_entry_id;

  -- Update pool totals
  UPDATE public.prediction_challenges
  SET total_participants = total_participants + 1,
      total_pool_fet = total_pool_fet + v_pool.stake_fet,
      updated_at = now()
  WHERE id = p_pool_id;

  -- Get match info for transaction title
  SELECT home_team, away_team INTO v_match
  FROM public.matches
  WHERE id = v_pool.match_id;

  -- Record wallet transaction
  INSERT INTO public.fet_wallet_transactions (
    user_id, tx_type, direction, amount_fet,
    balance_before_fet, balance_after_fet,
    reference_type, reference_id, title
  ) VALUES (
    v_user_id, 'pool_stake', 'debit', v_pool.stake_fet,
    v_balance, v_balance - v_pool.stake_fet,
    'prediction_challenge', p_pool_id,
    'Joined pool: ' || COALESCE(v_match.home_team, '?') || ' vs ' || COALESCE(v_match.away_team, '?')
  );

  RETURN jsonb_build_object(
    'status', 'joined',
    'entry_id', v_entry_id,
    'balance_after', v_balance - v_pool.stake_fet
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
