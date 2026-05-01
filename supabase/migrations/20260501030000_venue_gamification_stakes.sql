-- ============================================================================
-- Venue Match Stakes & Gamification
-- Migration: 20260501030000_venue_gamification_stakes.sql
-- Purpose: Allow venues to create token-based prediction pools for guests.
-- ============================================================================

BEGIN;

-- ── Enums ────────────────────────────────────────────────────────────────────

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'venue_stake_status') THEN
    CREATE TYPE public.venue_stake_status AS ENUM ('open', 'settled', 'cancelled');
  END IF;
END
$$;

-- ── Table 1: venue_match_stakes ──────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.venue_match_stakes (
  id              uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  venue_id        uuid NOT NULL REFERENCES public.venues (id) ON DELETE CASCADE,
  match_id        text NOT NULL REFERENCES public.matches (id) ON DELETE CASCADE,
  entry_fee_fet   bigint NOT NULL DEFAULT 0 CHECK (entry_fee_fet >= 0),
  total_pool_fet  bigint NOT NULL DEFAULT 0 CHECK (total_pool_fet >= 0),
  status          public.venue_stake_status NOT NULL DEFAULT 'open',
  created_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  
  -- Ensure only one active stake per venue per match
  CONSTRAINT venue_match_stake_unique UNIQUE (venue_id, match_id)
);

-- ── Table 2: venue_match_stake_entries ───────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.venue_match_stake_entries (
  id              uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  stake_id        uuid NOT NULL REFERENCES public.venue_match_stakes (id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  prediction_id   uuid REFERENCES public.user_predictions (id) ON DELETE SET NULL,
  created_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  
  UNIQUE (stake_id, user_id)
);

-- ── Functions ───────────────────────────────────────────────────────────────

-- Function for a user to join a venue stake
CREATE OR REPLACE FUNCTION public.join_venue_match_stake(p_stake_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_stake public.venue_match_stakes%ROWTYPE;
  v_prediction_id uuid;
  v_balance_before bigint;
BEGIN
  -- 1. Validation
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_stake FROM public.venue_match_stakes WHERE id = p_stake_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Stake not found';
  END IF;

  IF v_stake.status <> 'open' THEN
    RAISE EXCEPTION 'This pool is no longer accepting entries';
  END IF;

  IF EXISTS (SELECT 1 FROM public.venue_match_stake_entries WHERE stake_id = p_stake_id AND user_id = v_user_id) THEN
    RAISE EXCEPTION 'You have already joined this pool';
  END IF;

  -- Verify user has a prediction for this match
  SELECT id INTO v_prediction_id 
  FROM public.user_predictions 
  WHERE user_id = v_user_id AND match_id = v_stake.match_id
  LIMIT 1;

  IF v_prediction_id IS NULL THEN
    RAISE EXCEPTION 'You must make a prediction for this match before joining the pool';
  END IF;

  -- 2. Handle FET Transfer
  SELECT available_balance_fet INTO v_balance_before FROM public.fet_wallets WHERE user_id = v_user_id FOR UPDATE;
  
  IF COALESCE(v_balance_before, 0) < v_stake.entry_fee_fet THEN
    RAISE EXCEPTION 'Insufficient FET balance';
  END IF;

  IF v_stake.entry_fee_fet > 0 THEN
    -- Deduct from user
    UPDATE public.fet_wallets
    SET available_balance_fet = available_balance_fet - v_stake.entry_fee_fet,
        updated_at = now()
    WHERE user_id = v_user_id;

    -- Log transaction
    INSERT INTO public.fet_wallet_transactions (
      user_id, tx_type, direction, amount_fet, balance_before_fet, balance_after_fet,
      reference_type, reference_id, title
    ) VALUES (
      v_user_id, 'venue_stake_entry', 'debit', v_stake.entry_fee_fet,
      COALESCE(v_balance_before, 0), COALESCE(v_balance_before, 0) - v_stake.entry_fee_fet,
      'venue_match_stake', p_stake_id::text,
      'Joined venue pool for match'
    );
  END IF;

  -- 3. Update Stake & Create Entry
  UPDATE public.venue_match_stakes 
  SET total_pool_fet = total_pool_fet + v_stake.entry_fee_fet,
      updated_at = now()
  WHERE id = p_stake_id;

  INSERT INTO public.venue_match_stake_entries (stake_id, user_id, prediction_id)
  VALUES (p_stake_id, v_user_id, v_prediction_id);

  RETURN jsonb_build_object(
    'success', true,
    'entry_fee_fet', v_stake.entry_fee_fet,
    'total_pool_fet', v_stake.total_pool_fet + v_stake.entry_fee_fet
  );
END;
$$;

-- Function to settle a venue stake after a match is finished
CREATE OR REPLACE FUNCTION public.settle_venue_match_stake(p_stake_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_stake public.venue_match_stakes%ROWTYPE;
  v_match public.matches%ROWTYPE;
  v_winner_count bigint;
  v_reward_per_winner bigint;
  v_winner record;
BEGIN
  -- 1. Fetch Stake & Match
  SELECT * INTO v_stake FROM public.venue_match_stakes WHERE id = p_stake_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Stake not found';
  END IF;

  IF v_stake.status <> 'open' THEN
    RAISE EXCEPTION 'Stake is already %', v_stake.status;
  END IF;

  SELECT * INTO v_match FROM public.matches WHERE id = v_stake.match_id;
  IF v_match.match_status NOT IN ('finished', 'FT', 'AET', 'PEN') THEN
    RAISE EXCEPTION 'Match is not finished yet';
  END IF;

  -- 2. Identify Winners
  -- Winners are those whose predicted_result_code matches matches.result_code
  WITH winners AS (
    SELECT e.user_id, e.id as entry_id
    FROM public.venue_match_stake_entries e
    JOIN public.user_predictions p ON p.id = e.prediction_id
    WHERE e.stake_id = p_stake_id
      AND p.predicted_result_code = v_match.result_code
  )
  SELECT count(*) INTO v_winner_count FROM winners;

  -- 3. Distribute Rewards
  IF v_winner_count > 0 THEN
    v_reward_per_winner := floor(v_stake.total_pool_fet / v_winner_count);
    
    FOR v_winner IN (
      SELECT e.user_id, p.id as prediction_id
      FROM public.venue_match_stake_entries e
      JOIN public.user_predictions p ON p.id = e.prediction_id
      WHERE e.stake_id = p_stake_id
        AND p.predicted_result_code = v_match.result_code
    ) LOOP
      -- Update wallet
      UPDATE public.fet_wallets 
      SET available_balance_fet = available_balance_fet + v_reward_per_winner,
          updated_at = now()
      WHERE user_id = v_winner.user_id;

      -- Log transaction
      INSERT INTO public.fet_wallet_transactions (
        user_id, tx_type, direction, amount_fet, reference_type, reference_id, title
      ) VALUES (
        v_winner.user_id, 'venue_stake_win', 'credit', v_reward_per_winner,
        'venue_match_stake', p_stake_id::text,
        'Won venue pool for ' || v_match.home_team_id || ' vs ' || v_match.away_team_id
      );
    END LOOP;
  END IF;

  -- 4. Finalize Stake
  UPDATE public.venue_match_stakes 
  SET status = 'settled',
      updated_at = now()
  WHERE id = p_stake_id;

  RETURN jsonb_build_object(
    'status', 'settled',
    'total_pool_fet', v_stake.total_pool_fet,
    'winner_count', v_winner_count,
    'reward_per_winner', COALESCE(v_reward_per_winner, 0)
  );
END;
$$;

-- Function to settle all pending stakes for finished matches
CREATE OR REPLACE FUNCTION public.settle_all_finished_venue_stakes(p_limit int DEFAULT 50)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_stake_id uuid;
  v_count int := 0;
BEGIN
  FOR v_stake_id IN (
    SELECT s.id
    FROM public.venue_match_stakes s
    JOIN public.matches m ON m.id = s.match_id
    WHERE s.status = 'open'
      AND m.match_status IN ('finished', 'FT', 'AET', 'PEN')
    LIMIT p_limit
  ) LOOP
    PERFORM public.settle_venue_match_stake(v_stake_id);
    v_count := v_count + 1;
  END LOOP;
  
  RETURN v_count;
END;
$$;

-- ── RLS Policies ────────────────────────────────────────────────────────────

ALTER TABLE public.venue_match_stakes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.venue_match_stake_entries ENABLE ROW LEVEL SECURITY;

-- Stakes: Anyone can view active pools; managers can also view cancelled pools.
CREATE POLICY "Users can view active/settled stakes"
  ON public.venue_match_stakes FOR SELECT
  TO authenticated, anon
  USING (
    status IN ('open', 'settled')
    OR public.dinein_is_venue_member(venue_id, ARRAY['owner', 'manager']::public.venue_user_role[])
  );

CREATE POLICY "Venue managers can create stakes"
  ON public.venue_match_stakes FOR INSERT
  TO authenticated
  WITH CHECK (public.dinein_is_venue_member(venue_id, ARRAY['owner', 'manager']::public.venue_user_role[]));

CREATE POLICY "Venue managers can update stakes"
  ON public.venue_match_stakes FOR UPDATE
  TO authenticated
  USING (public.dinein_is_venue_member(venue_id, ARRAY['owner', 'manager']::public.venue_user_role[]))
  WITH CHECK (public.dinein_is_venue_member(venue_id, ARRAY['owner', 'manager']::public.venue_user_role[]));

CREATE POLICY "Venue managers can delete stakes"
  ON public.venue_match_stakes FOR DELETE
  TO authenticated
  USING (public.dinein_is_venue_member(venue_id, ARRAY['owner', 'manager']::public.venue_user_role[]));

-- Entries: Users can see their own; managers can see entries for their venue.
CREATE POLICY "Users and venue managers can view stake entries"
  ON public.venue_match_stake_entries FOR SELECT
  TO authenticated
  USING (
    user_id = (select auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.venue_match_stakes s
      WHERE s.id = stake_id 
      AND public.dinein_is_venue_member(s.venue_id)
    )
  );

-- ── Indexes ──────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS venue_match_stakes_match_idx ON public.venue_match_stakes (match_id);
CREATE INDEX IF NOT EXISTS venue_match_stakes_venue_idx ON public.venue_match_stakes (venue_id);

GRANT SELECT ON public.venue_match_stakes TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.venue_match_stakes TO authenticated;
GRANT SELECT ON public.venue_match_stake_entries TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_venue_match_stake(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.settle_venue_match_stake(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.settle_all_finished_venue_stakes(int) TO authenticated, service_role;

COMMIT;
