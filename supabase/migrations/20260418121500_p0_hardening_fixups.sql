-- ============================================================
-- 20260418121500_p0_hardening_fixups.sql
-- P0 hardening follow-up for FANZONE.
--
-- Goals:
--   1) Harden settle/void RPCs with admin checks and deterministic payouts.
--   2) Enforce rate limits on the canonical create_pool / transfer_fet RPCs.
--   3) Block frozen or banned wallets from spending flows.
--   4) Remove stale permissive RLS policies that bypass RPC-only writes.
--   5) Revoke public execute on authenticated-only RPCs.
-- ============================================================

BEGIN;

-- -----------------------------------------------------------------
-- Prerequisite: ensure admin infrastructure tables exist
-- (from 006_admin_infrastructure which may not have run)
-- -----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.admin_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  display_name TEXT NOT NULL DEFAULT '',
  role TEXT NOT NULL DEFAULT 'admin' CHECK (role IN ('super_admin', 'admin', 'moderator', 'viewer')),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
  id BIGSERIAL PRIMARY KEY,
  admin_user_id UUID REFERENCES public.admin_users(id),
  action TEXT NOT NULL,
  module TEXT NOT NULL DEFAULT '',
  target_type TEXT NOT NULL DEFAULT '',
  target_id TEXT NOT NULL DEFAULT '',
  before_state JSONB DEFAULT '{}',
  after_state JSONB DEFAULT '{}',
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------


CREATE OR REPLACE FUNCTION public.is_active_admin_user(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.admin_users
    WHERE user_id = p_user_id
      AND is_active = true
      AND role IN ('super_admin', 'admin')
  );
$$;

CREATE OR REPLACE FUNCTION public.require_active_admin_user()
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT public.is_active_admin_user(v_user_id) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN v_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.assert_wallet_available(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_banned boolean := false;
  v_banned_until timestamptz;
  v_wallet_frozen boolean := false;
BEGIN
  SELECT
    is_banned,
    banned_until,
    wallet_frozen
  INTO v_is_banned, v_banned_until, v_wallet_frozen
  FROM public.user_status
  WHERE user_id = p_user_id;

  IF coalesce(v_wallet_frozen, false) THEN
    RAISE EXCEPTION 'Wallet is frozen';
  END IF;

  IF coalesce(v_is_banned, false)
     AND (
       v_banned_until IS NULL
       OR v_banned_until > timezone('utc', now())
     ) THEN
    RAISE EXCEPTION 'Account is banned';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.check_rate_limit(
  p_user_id uuid,
  p_action text,
  p_max_count integer,
  p_window interval
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'Rate limit requires a user id';
  END IF;

  IF coalesce(trim(p_action), '') = '' THEN
    RAISE EXCEPTION 'Rate limit requires an action name';
  END IF;

  IF p_max_count IS NULL OR p_max_count <= 0 THEN
    RAISE EXCEPTION 'Rate limit max_count must be positive';
  END IF;

  IF p_window IS NULL OR p_window <= interval '0 seconds' THEN
    RAISE EXCEPTION 'Rate limit window must be positive';
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended(p_user_id::text || ':' || p_action, 0)
  );

  DELETE FROM public.rate_limits
  WHERE user_id = p_user_id
    AND action = p_action
    AND created_at <= now() - p_window;

  SELECT count(*)
  INTO v_count
  FROM public.rate_limits
  WHERE user_id = p_user_id
    AND action = p_action
    AND created_at > now() - p_window;

  IF v_count >= p_max_count THEN
    RETURN false;
  END IF;

  INSERT INTO public.rate_limits (user_id, action)
  VALUES (p_user_id, p_action);

  RETURN true;
END;
$$;

DROP FUNCTION IF EXISTS public.check_rate_limit(uuid, text, integer, integer);
CREATE OR REPLACE FUNCTION public.check_rate_limit(
  p_user_id uuid,
  p_action text,
  p_max_count integer,
  p_window_hours integer
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.check_rate_limit(
    p_user_id,
    p_action,
    p_max_count,
    make_interval(hours => greatest(coalesce(p_window_hours, 1), 1))
  );
$$;

DO $$
DECLARE
  v_constraint_name text;
BEGIN
  SELECT con.conname
  INTO v_constraint_name
  FROM pg_constraint con
  WHERE con.conrelid = 'public.prediction_challenge_entries'::regclass
    AND con.contype = 'c'
    AND pg_get_constraintdef(con.oid) ILIKE '%status%'
  LIMIT 1;

  IF v_constraint_name IS NOT NULL THEN
    EXECUTE format(
      'ALTER TABLE public.prediction_challenge_entries DROP CONSTRAINT %I',
      v_constraint_name
    );
  END IF;

  ALTER TABLE public.prediction_challenge_entries
    ADD CONSTRAINT prediction_challenge_entries_status_check
    CHECK (status IN ('active', 'won', 'lost', 'cancelled', 'refunded'));
EXCEPTION
  WHEN duplicate_object THEN NULL;
END;
$$;

-- -----------------------------------------------------------------
-- Harden canonical pool and wallet RPCs
-- -----------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.create_pool(
  p_match_id text,
  p_home_score integer,
  p_away_score integer,
  p_stake bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_balance bigint;
  v_pool_id uuid;
  v_entry_id uuid;
  v_match record;
  v_lock_at timestamptz;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  PERFORM public.assert_wallet_available(v_user_id);

  IF NOT public.check_rate_limit(v_user_id, 'create_pool', 5, interval '1 hour') THEN
    RAISE EXCEPTION 'Rate limit exceeded — max 5 pools per hour';
  END IF;

  IF p_stake IS NULL OR p_stake < 10 THEN
    RAISE EXCEPTION 'Minimum stake is 10 FET';
  END IF;

  IF p_home_score IS NULL OR p_away_score IS NULL OR p_home_score < 0 OR p_away_score < 0 THEN
    RAISE EXCEPTION 'Scores must be non-negative integers';
  END IF;

  SELECT id, home_team, away_team, status, date, kickoff_time
  INTO v_match
  FROM public.matches
  WHERE id = p_match_id;

  IF v_match IS NULL THEN
    RAISE EXCEPTION 'Match not found';
  END IF;

  IF v_match.status <> 'upcoming' THEN
    RAISE EXCEPTION 'Can only create pools for upcoming matches';
  END IF;

  v_lock_at := (v_match.date::timestamp + coalesce(v_match.kickoff_time, time '00:00')) - interval '30 minutes';
  IF v_lock_at <= now() THEN
    RAISE EXCEPTION 'Pool is locked (match is about to start)';
  END IF;

  SELECT available_balance_fet
  INTO v_balance
  FROM public.fet_wallets
  WHERE user_id = v_user_id
  FOR UPDATE;

  IF v_balance IS NULL OR v_balance < p_stake THEN
    RAISE EXCEPTION 'Insufficient FET balance';
  END IF;

  UPDATE public.fet_wallets
  SET available_balance_fet = available_balance_fet - p_stake,
      updated_at = now()
  WHERE user_id = v_user_id;

  INSERT INTO public.prediction_challenges (
    match_id,
    creator_user_id,
    stake_fet,
    currency_code,
    status,
    lock_at,
    total_participants,
    total_pool_fet
  ) VALUES (
    p_match_id,
    v_user_id,
    p_stake,
    'FET',
    'open',
    v_lock_at,
    1,
    p_stake
  )
  RETURNING id INTO v_pool_id;

  INSERT INTO public.prediction_challenge_entries (
    challenge_id,
    user_id,
    predicted_home_score,
    predicted_away_score,
    stake_fet,
    status
  ) VALUES (
    v_pool_id,
    v_user_id,
    p_home_score,
    p_away_score,
    p_stake,
    'active'
  )
  RETURNING id INTO v_entry_id;

  INSERT INTO public.fet_wallet_transactions (
    user_id,
    tx_type,
    direction,
    amount_fet,
    balance_before_fet,
    balance_after_fet,
    reference_type,
    reference_id,
    title
  ) VALUES (
    v_user_id,
    'pool_stake',
    'debit',
    p_stake,
    v_balance,
    v_balance - p_stake,
    'prediction_challenge',
    v_pool_id,
    'Pool stake: ' || v_match.home_team || ' vs ' || v_match.away_team
  );

  RETURN jsonb_build_object(
    'status', 'created',
    'pool_id', v_pool_id,
    'entry_id', v_entry_id,
    'balance_after', v_balance - p_stake
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.join_pool(
  p_pool_id uuid,
  p_home_score integer,
  p_away_score integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_balance bigint;
  v_pool record;
  v_entry_id uuid;
  v_match record;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  PERFORM public.assert_wallet_available(v_user_id);

  IF p_home_score IS NULL OR p_away_score IS NULL OR p_home_score < 0 OR p_away_score < 0 THEN
    RAISE EXCEPTION 'Scores must be non-negative integers';
  END IF;

  SELECT *
  INTO v_pool
  FROM public.prediction_challenges
  WHERE id = p_pool_id
  FOR UPDATE;

  IF v_pool IS NULL THEN
    RAISE EXCEPTION 'Pool not found';
  END IF;

  IF v_pool.status <> 'open' THEN
    RAISE EXCEPTION 'Pool is no longer open';
  END IF;

  IF coalesce(v_pool.lock_at, now()) <= now() THEN
    RAISE EXCEPTION 'Pool is locked (match is about to start)';
  END IF;

  IF v_pool.creator_user_id = v_user_id THEN
    RAISE EXCEPTION 'You cannot join your own pool';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.prediction_challenge_entries
    WHERE challenge_id = p_pool_id
      AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'You already joined this pool';
  END IF;

  SELECT available_balance_fet
  INTO v_balance
  FROM public.fet_wallets
  WHERE user_id = v_user_id
  FOR UPDATE;

  IF v_balance IS NULL OR v_balance < v_pool.stake_fet THEN
    RAISE EXCEPTION 'Insufficient FET balance';
  END IF;

  UPDATE public.fet_wallets
  SET available_balance_fet = available_balance_fet - v_pool.stake_fet,
      updated_at = now()
  WHERE user_id = v_user_id;

  INSERT INTO public.prediction_challenge_entries (
    challenge_id,
    user_id,
    predicted_home_score,
    predicted_away_score,
    stake_fet,
    status
  ) VALUES (
    p_pool_id,
    v_user_id,
    p_home_score,
    p_away_score,
    v_pool.stake_fet,
    'active'
  )
  RETURNING id INTO v_entry_id;

  UPDATE public.prediction_challenges
  SET total_participants = total_participants + 1,
      total_pool_fet = total_pool_fet + v_pool.stake_fet,
      updated_at = now()
  WHERE id = p_pool_id;

  SELECT home_team, away_team
  INTO v_match
  FROM public.matches
  WHERE id = v_pool.match_id;

  INSERT INTO public.fet_wallet_transactions (
    user_id,
    tx_type,
    direction,
    amount_fet,
    balance_before_fet,
    balance_after_fet,
    reference_type,
    reference_id,
    title
  ) VALUES (
    v_user_id,
    'pool_stake',
    'debit',
    v_pool.stake_fet,
    v_balance,
    v_balance - v_pool.stake_fet,
    'prediction_challenge',
    p_pool_id,
    'Joined pool: ' || coalesce(v_match.home_team, '?') || ' vs ' || coalesce(v_match.away_team, '?')
  );

  RETURN jsonb_build_object(
    'status', 'joined',
    'entry_id', v_entry_id,
    'balance_after', v_balance - v_pool.stake_fet
  );
END;
$$;

DROP FUNCTION IF EXISTS public.transfer_fet(text, integer);
DROP FUNCTION IF EXISTS public.transfer_fet(text, bigint);
DROP FUNCTION IF EXISTS public.transfer_fet(text, int);
DROP FUNCTION IF EXISTS public.transfer_fet_rate_limited(text, integer);
DROP FUNCTION IF EXISTS public.transfer_fet_rate_limited(text, bigint);
DROP FUNCTION IF EXISTS public.transfer_fet_rate_limited(text, int);

CREATE OR REPLACE FUNCTION public.transfer_fet(
  p_recipient_identifier text,
  p_amount_fet bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sender_id uuid;
  v_recipient_id uuid;
  v_sender_balance bigint;
  v_recipient_balance_before bigint := 0;
  v_identifier text;
BEGIN
  v_sender_id := auth.uid();
  IF v_sender_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  PERFORM public.assert_wallet_available(v_sender_id);

  IF NOT public.check_rate_limit(v_sender_id, 'transfer_fet', 10, interval '1 day') THEN
    RAISE EXCEPTION 'Rate limit exceeded — max 10 transfers per day';
  END IF;

  IF p_amount_fet IS NULL OR p_amount_fet <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than zero';
  END IF;

  v_identifier := nullif(trim(p_recipient_identifier), '');
  IF v_identifier IS NULL THEN
    RAISE EXCEPTION 'Recipient identifier is required';
  END IF;

  SELECT id
  INTO v_recipient_id
  FROM auth.users
  WHERE phone = v_identifier
  LIMIT 1;

  IF v_recipient_id IS NULL THEN
    SELECT id
    INTO v_recipient_id
    FROM auth.users
    WHERE email = v_identifier
    LIMIT 1;
  END IF;

  IF v_recipient_id IS NULL THEN
    RAISE EXCEPTION 'Recipient not found';
  END IF;

  IF v_sender_id = v_recipient_id THEN
    RAISE EXCEPTION 'Cannot transfer to yourself';
  END IF;

  SELECT available_balance_fet
  INTO v_sender_balance
  FROM public.fet_wallets
  WHERE user_id = v_sender_id
  FOR UPDATE;

  IF v_sender_balance IS NULL OR v_sender_balance < p_amount_fet THEN
    RAISE EXCEPTION 'Insufficient balance';
  END IF;

  INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
  VALUES (v_recipient_id, 0, 0)
  ON CONFLICT (user_id) DO NOTHING;

  SELECT available_balance_fet
  INTO v_recipient_balance_before
  FROM public.fet_wallets
  WHERE user_id = v_recipient_id
  FOR UPDATE;

  UPDATE public.fet_wallets
  SET available_balance_fet = available_balance_fet - p_amount_fet,
      updated_at = now()
  WHERE user_id = v_sender_id;

  UPDATE public.fet_wallets
  SET available_balance_fet = available_balance_fet + p_amount_fet,
      updated_at = now()
  WHERE user_id = v_recipient_id;

  INSERT INTO public.fet_wallet_transactions (
    user_id,
    tx_type,
    direction,
    amount_fet,
    balance_before_fet,
    balance_after_fet,
    reference_type,
    title
  ) VALUES
    (
      v_sender_id,
      'transfer',
      'debit',
      p_amount_fet,
      v_sender_balance,
      v_sender_balance - p_amount_fet,
      'transfer',
      'Transfer to ' || v_identifier
    ),
    (
      v_recipient_id,
      'transfer',
      'credit',
      p_amount_fet,
      coalesce(v_recipient_balance_before, 0),
      coalesce(v_recipient_balance_before, 0) + p_amount_fet,
      'transfer',
      'Transfer received'
    );

  RETURN jsonb_build_object(
    'success', true,
    'recipient_user_id', v_recipient_id,
    'amount_fet', p_amount_fet
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.create_pool_rate_limited(
  p_match_id text,
  p_home_score integer,
  p_away_score integer,
  p_stake bigint
)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.create_pool(p_match_id, p_home_score, p_away_score, p_stake);
$$;

DROP FUNCTION IF EXISTS public.transfer_fet_rate_limited(text, integer);

CREATE OR REPLACE FUNCTION public.transfer_fet_rate_limited(
  p_recipient_identifier text,
  p_amount_fet bigint
)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.transfer_fet(p_recipient_identifier, p_amount_fet);
$$;

-- -----------------------------------------------------------------
-- Settlement RPCs
-- -----------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.settle_pool(
  p_pool_id uuid,
  p_official_home_score integer,
  p_official_away_score integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid;
  v_pool record;
  v_entry record;
  v_total_entries integer := 0;
  v_winner_count integer := 0;
  v_loser_count integer := 0;
  v_base_payout bigint := 0;
  v_remainder bigint := 0;
  v_remainder_rank integer := 0;
  v_payout bigint := 0;
  v_balance_before bigint := 0;
  v_total_distributed bigint := 0;
BEGIN
  v_admin_id := public.require_active_admin_user();

  SELECT *
  INTO v_pool
  FROM public.prediction_challenges
  WHERE id = p_pool_id
  FOR UPDATE;

  IF v_pool IS NULL THEN
    RAISE EXCEPTION 'Pool not found';
  END IF;

  IF v_pool.status NOT IN ('open', 'locked') THEN
    RAISE EXCEPTION 'Pool already settled or cancelled (status: %)', v_pool.status;
  END IF;

  IF p_official_home_score IS NULL OR p_official_away_score IS NULL
     OR p_official_home_score < 0 OR p_official_away_score < 0 THEN
    RAISE EXCEPTION 'Official scores must be non-negative integers';
  END IF;

  SELECT count(*)
  INTO v_total_entries
  FROM public.prediction_challenge_entries
  WHERE challenge_id = p_pool_id
    AND status = 'active';

  SELECT count(*)
  INTO v_winner_count
  FROM public.prediction_challenge_entries
  WHERE challenge_id = p_pool_id
    AND status = 'active'
    AND predicted_home_score = p_official_home_score
    AND predicted_away_score = p_official_away_score;

  IF v_winner_count > 0 THEN
    v_base_payout := coalesce(v_pool.total_pool_fet, 0) / v_winner_count;
    v_remainder := coalesce(v_pool.total_pool_fet, 0) % v_winner_count;
    v_loser_count := greatest(v_total_entries - v_winner_count, 0);
  ELSE
    v_loser_count := 0;
  END IF;

  FOR v_entry IN
    SELECT *
    FROM public.prediction_challenge_entries
    WHERE challenge_id = p_pool_id
      AND status = 'active'
    ORDER BY id
    FOR UPDATE
  LOOP
    INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
    VALUES (v_entry.user_id, 0, 0)
    ON CONFLICT (user_id) DO NOTHING;

    SELECT available_balance_fet
    INTO v_balance_before
    FROM public.fet_wallets
    WHERE user_id = v_entry.user_id
    FOR UPDATE;

    IF v_winner_count > 0 THEN
      IF v_entry.predicted_home_score = p_official_home_score
         AND v_entry.predicted_away_score = p_official_away_score THEN
        v_payout := v_base_payout;
        IF v_remainder_rank < v_remainder THEN
          v_payout := v_payout + 1;
        END IF;
        v_remainder_rank := v_remainder_rank + 1;

        UPDATE public.prediction_challenge_entries
        SET status = 'won',
            payout_fet = v_payout,
            settled_at = now()
        WHERE id = v_entry.id;

        UPDATE public.fet_wallets
        SET available_balance_fet = available_balance_fet + v_payout,
            updated_at = now()
        WHERE user_id = v_entry.user_id;

        INSERT INTO public.fet_wallet_transactions (
          user_id,
          tx_type,
          direction,
          amount_fet,
          balance_before_fet,
          balance_after_fet,
          reference_type,
          reference_id,
          title
        ) VALUES (
          v_entry.user_id,
          'pool_payout',
          'credit',
          v_payout,
          coalesce(v_balance_before, 0),
          coalesce(v_balance_before, 0) + v_payout,
          'prediction_challenge',
          p_pool_id,
          'Pool payout — won ' || v_payout || ' FET'
        );

        v_total_distributed := v_total_distributed + v_payout;
      ELSE
        UPDATE public.prediction_challenge_entries
        SET status = 'lost',
            payout_fet = 0,
            settled_at = now()
        WHERE id = v_entry.id;
      END IF;
    ELSE
      v_payout := coalesce(v_entry.stake_fet, 0);

      UPDATE public.prediction_challenge_entries
      SET status = 'refunded',
          payout_fet = v_payout,
          settled_at = now()
      WHERE id = v_entry.id;

      UPDATE public.fet_wallets
      SET available_balance_fet = available_balance_fet + v_payout,
          updated_at = now()
      WHERE user_id = v_entry.user_id;

      INSERT INTO public.fet_wallet_transactions (
        user_id,
        tx_type,
        direction,
        amount_fet,
        balance_before_fet,
        balance_after_fet,
        reference_type,
        reference_id,
        title
      ) VALUES (
        v_entry.user_id,
        'pool_refund',
        'credit',
        v_payout,
        coalesce(v_balance_before, 0),
        coalesce(v_balance_before, 0) + v_payout,
        'prediction_challenge',
        p_pool_id,
        'Pool refund — no winners'
      );

      v_total_distributed := v_total_distributed + v_payout;
    END IF;
  END LOOP;

  UPDATE public.prediction_challenges
  SET status = 'settled',
      settled_at = now(),
      official_home_score = p_official_home_score,
      official_away_score = p_official_away_score,
      winner_count = v_winner_count,
      loser_count = v_loser_count,
      payout_per_winner_fet = CASE
        WHEN v_winner_count > 0 THEN v_base_payout
        ELSE 0
      END,
      updated_at = now()
  WHERE id = p_pool_id;

  INSERT INTO public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    after_state
  )
  SELECT
    au.id,
    'settle_pool',
    'challenges',
    'prediction_challenge',
    p_pool_id::text,
    jsonb_build_object(
      'official_home_score', p_official_home_score,
      'official_away_score', p_official_away_score,
      'winner_count', v_winner_count,
      'loser_count', v_loser_count,
      'total_distributed', v_total_distributed
    )
  FROM public.admin_users au
  WHERE au.user_id = v_admin_id;

  RETURN jsonb_build_object(
    'status', 'settled',
    'pool_id', p_pool_id,
    'winner_count', v_winner_count,
    'loser_count', v_loser_count,
    'payout_per_winner', v_base_payout,
    'remainder_distributed', v_remainder,
    'total_pool', coalesce(v_pool.total_pool_fet, 0),
    'total_distributed', v_total_distributed,
    'refunded', v_winner_count = 0
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.void_pool(
  p_pool_id uuid,
  p_reason text DEFAULT 'Admin cancelled'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid;
  v_pool record;
  v_entry record;
  v_balance_before bigint;
  v_refund_count integer := 0;
BEGIN
  v_admin_id := public.require_active_admin_user();

  SELECT *
  INTO v_pool
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
    SELECT *
    FROM public.prediction_challenge_entries
    WHERE challenge_id = p_pool_id
      AND status = 'active'
    FOR UPDATE
  LOOP
    INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
    VALUES (v_entry.user_id, 0, 0)
    ON CONFLICT (user_id) DO NOTHING;

    SELECT available_balance_fet
    INTO v_balance_before
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
      user_id,
      tx_type,
      direction,
      amount_fet,
      balance_before_fet,
      balance_after_fet,
      reference_type,
      reference_id,
      title
    ) VALUES (
      v_entry.user_id,
      'pool_refund',
      'credit',
      v_entry.stake_fet,
      coalesce(v_balance_before, 0),
      coalesce(v_balance_before, 0) + v_entry.stake_fet,
      'prediction_challenge',
      p_pool_id,
      'Pool voided: ' || coalesce(p_reason, 'cancelled')
    );

    v_refund_count := v_refund_count + 1;
  END LOOP;

  UPDATE public.prediction_challenges
  SET status = 'cancelled',
      cancelled_at = now(),
      void_reason = p_reason,
      updated_at = now()
  WHERE id = p_pool_id;

  INSERT INTO public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    after_state
  )
  SELECT
    au.id,
    'void_pool',
    'challenges',
    'prediction_challenge',
    p_pool_id::text,
    jsonb_build_object(
      'reason', p_reason,
      'refunded_entries', v_refund_count
    )
  FROM public.admin_users au
  WHERE au.user_id = v_admin_id;

  RETURN jsonb_build_object(
    'status', 'voided',
    'pool_id', p_pool_id,
    'refunded_entries', v_refund_count,
    'reason', p_reason
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.auto_settle_pools(
  p_match_id text,
  p_home_score integer,
  p_away_score integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid;
  v_pool record;
  v_result jsonb;
  v_settled integer := 0;
  v_results jsonb[] := '{}';
BEGIN
  v_admin_id := public.require_active_admin_user();

  FOR v_pool IN
    SELECT id
    FROM public.prediction_challenges
    WHERE match_id = p_match_id
      AND status IN ('open', 'locked')
  LOOP
    v_result := public.settle_pool(v_pool.id, p_home_score, p_away_score);
    v_results := v_results || v_result;
    v_settled := v_settled + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'match_id', p_match_id,
    'pools_settled', v_settled,
    'results', to_jsonb(v_results),
    'settled_by', v_admin_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.settle_prediction_slips_for_match(
  p_match_id text,
  p_official_home_score integer,
  p_official_away_score integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid;
  v_selection record;
  v_is_correct boolean;
  v_settled_count integer := 0;
  v_slip_ids uuid[] := '{}';
BEGIN
  v_admin_id := public.require_active_admin_user();

  FOR v_selection IN
    SELECT s.*
    FROM public.prediction_slip_selections s
    JOIN public.prediction_slips sl
      ON sl.id = s.slip_id
    WHERE s.match_id = p_match_id
      AND s.result = 'pending'
    FOR UPDATE OF s
  LOOP
    v_is_correct := CASE v_selection.market
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
          ELSE false
        END
      WHEN 'btts' THEN
        CASE
          WHEN v_selection.selection = 'yes' THEN p_official_home_score > 0 AND p_official_away_score > 0
          WHEN v_selection.selection = 'no' THEN p_official_home_score = 0 OR p_official_away_score = 0
          ELSE false
        END
      ELSE false
    END;

    UPDATE public.prediction_slip_selections
    SET result = CASE WHEN v_is_correct THEN 'won' ELSE 'lost' END
    WHERE id = v_selection.id;

    v_slip_ids := array_append(v_slip_ids, v_selection.slip_id);
    v_settled_count := v_settled_count + 1;
  END LOOP;

  IF coalesce(array_length(v_slip_ids, 1), 0) = 0 THEN
    RETURN jsonb_build_object(
      'match_id', p_match_id,
      'selections_settled', 0,
      'slips_affected', 0,
      'settled_by', v_admin_id
    );
  END IF;

  UPDATE public.prediction_slips sl
  SET status = CASE
    WHEN NOT EXISTS (
      SELECT 1
      FROM public.prediction_slip_selections
      WHERE slip_id = sl.id
        AND result = 'pending'
    ) THEN
      CASE
        WHEN NOT EXISTS (
          SELECT 1
          FROM public.prediction_slip_selections
          WHERE slip_id = sl.id
            AND result = 'lost'
        ) THEN 'settled_win'
        ELSE 'settled_loss'
      END
    ELSE sl.status
  END,
  settled_at = CASE
    WHEN NOT EXISTS (
      SELECT 1
      FROM public.prediction_slip_selections
      WHERE slip_id = sl.id
        AND result = 'pending'
    ) THEN now()
    ELSE sl.settled_at
  END,
  updated_at = now()
  WHERE sl.id = ANY(v_slip_ids);

  INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
  SELECT DISTINCT sl.user_id, 0, 0
  FROM public.prediction_slips sl
  WHERE sl.id = ANY(v_slip_ids)
    AND sl.status = 'settled_win'
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.fet_wallet_transactions (
    user_id,
    tx_type,
    direction,
    amount_fet,
    balance_before_fet,
    balance_after_fet,
    reference_type,
    reference_id,
    title
  )
  SELECT
    sl.user_id,
    'prediction_earn',
    'credit',
    sl.projected_earn_fet,
    coalesce(w.available_balance_fet, 0),
    coalesce(w.available_balance_fet, 0) + sl.projected_earn_fet,
    'prediction_slip',
    sl.id,
    'Prediction win — earned ' || sl.projected_earn_fet || ' FET'
  FROM public.prediction_slips sl
  JOIN public.fet_wallets w
    ON w.user_id = sl.user_id
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
    'slips_affected', cardinality(ARRAY(SELECT DISTINCT unnest(v_slip_ids))),
    'settled_by', v_admin_id
  );
END;
$$;

-- -----------------------------------------------------------------
-- RLS cleanup for RPC-only tables
-- -----------------------------------------------------------------

DROP POLICY IF EXISTS "Authenticated can view entries" ON public.prediction_challenge_entries;
DROP POLICY IF EXISTS "Users can create own challenges" ON public.prediction_challenges;
DROP POLICY IF EXISTS "Users can add own challenge entries" ON public.prediction_challenge_entries;
DROP POLICY IF EXISTS "Users insert own slips" ON public.prediction_slips;
DROP POLICY IF EXISTS "Users insert own slip selections" ON public.prediction_slip_selections;

-- -----------------------------------------------------------------
-- Function execution hardening
-- -----------------------------------------------------------------

REVOKE ALL ON FUNCTION public.is_active_admin_user(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.require_active_admin_user() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assert_wallet_available(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.check_rate_limit(uuid, text, integer, interval) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.check_rate_limit(uuid, text, integer, integer) FROM PUBLIC;

REVOKE ALL ON FUNCTION public.create_pool(text, integer, integer, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.join_pool(uuid, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.transfer_fet(text, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_pool_rate_limited(text, integer, integer, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.transfer_fet_rate_limited(text, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.submit_prediction_slip(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.settle_pool(uuid, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.void_pool(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.auto_settle_pools(text, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.settle_prediction_slips_for_match(text, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.submit_daily_prediction(uuid, integer, integer) FROM PUBLIC;
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'support_team'
      AND oidvectortypes(p.proargtypes) = 'text'
  ) THEN
    EXECUTE 'REVOKE ALL ON FUNCTION public.support_team(text) FROM PUBLIC';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'unsupport_team'
      AND oidvectortypes(p.proargtypes) = 'text'
  ) THEN
    EXECUTE 'REVOKE ALL ON FUNCTION public.unsupport_team(text) FROM PUBLIC';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'contribute_fet_to_team'
      AND oidvectortypes(p.proargtypes) = 'text, bigint'
  ) THEN
    EXECUTE 'REVOKE ALL ON FUNCTION public.contribute_fet_to_team(text, bigint) FROM PUBLIC';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_pool(text, integer, integer, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_pool(uuid, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.transfer_fet(text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_pool_rate_limited(text, integer, integer, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.transfer_fet_rate_limited(text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_prediction_slip(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.settle_pool(uuid, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.void_pool(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.auto_settle_pools(text, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.settle_prediction_slips_for_match(text, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_daily_prediction(uuid, integer, integer) TO authenticated;
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'support_team'
      AND oidvectortypes(p.proargtypes) = 'text'
  ) THEN
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.support_team(text) TO authenticated';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'unsupport_team'
      AND oidvectortypes(p.proargtypes) = 'text'
  ) THEN
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.unsupport_team(text) TO authenticated';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'contribute_fet_to_team'
      AND oidvectortypes(p.proargtypes) = 'text, bigint'
  ) THEN
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.contribute_fet_to_team(text, bigint) TO authenticated';
  END IF;
END;
$$;

COMMIT;
