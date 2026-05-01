-- ============================================================================
-- Production Schema Delta
-- Migration: 20260501070000_production_schema_delta.sql
-- Purpose: Reconcile production where earlier hospitality schema objects already
-- exist but the remote migration history diverged from this repo.
-- ============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- Keep the order timestamp trigger aligned with the active order_status enum.
CREATE OR REPLACE FUNCTION public.dinein_set_order_timestamps()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = timezone('utc', now());

  IF tg_op = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
    NEW.status_changed_at = timezone('utc', now());

    IF NEW.status = 'received' AND OLD.accepted_at IS NULL THEN
      NEW.accepted_at = timezone('utc', now());
    END IF;

    IF NEW.status = 'served' AND OLD.served_at IS NULL THEN
      NEW.served_at = timezone('utc', now());
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Support FET token payments and server-side FET credits for paid orders.
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS payment_fet_amount bigint NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS payment_fet_converted_amount decimal(12,2) NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.orders.payment_fet_amount IS 'Amount of FET tokens applied to this order.';
COMMENT ON COLUMN public.orders.payment_fet_converted_amount IS 'Value of applied FET tokens in the order currency.';

CREATE OR REPLACE FUNCTION public.credit_fet_for_order(
  p_user_id uuid,
  p_order_id uuid,
  p_amount bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_balance_before bigint;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'User id is required';
  END IF;

  IF p_order_id IS NULL THEN
    RAISE EXCEPTION 'Order id is required';
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be positive';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.orders
    WHERE id = p_order_id
      AND user_id = p_user_id
      AND payment_status = 'paid'
  ) THEN
    RAISE EXCEPTION 'Paid order not found for user';
  END IF;

  SELECT available_balance_fet
  INTO v_balance_before
  FROM public.fet_wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
  VALUES (p_user_id, p_amount, 0)
  ON CONFLICT (user_id) DO UPDATE
  SET available_balance_fet = public.fet_wallets.available_balance_fet + p_amount,
      updated_at = now();

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
  VALUES (
    p_user_id,
    'order_reward',
    'credit',
    p_amount,
    COALESCE(v_balance_before, 0),
    COALESCE(v_balance_before, 0) + p_amount,
    'order',
    p_order_id::text,
    'FET earned from paid venue order'
  );

  RETURN jsonb_build_object(
    'status', 'credited',
    'user_id', p_user_id,
    'order_id', p_order_id,
    'amount_fet', p_amount
  );
END;
$$;

REVOKE ALL ON FUNCTION public.credit_fet_for_order(uuid, uuid, bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.credit_fet_for_order(uuid, uuid, bigint) TO service_role;

-- Venue match stakes.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typnamespace = 'public'::regnamespace
      AND typname = 'venue_stake_status'
  ) THEN
    CREATE TYPE public.venue_stake_status AS ENUM ('open', 'settled', 'cancelled');
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS public.venue_match_stakes (
  id              uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  venue_id        uuid NOT NULL REFERENCES public.venues (id) ON DELETE CASCADE,
  match_id        text NOT NULL REFERENCES public.matches (id) ON DELETE CASCADE,
  entry_fee_fet   bigint NOT NULL DEFAULT 0 CHECK (entry_fee_fet >= 0),
  total_pool_fet  bigint NOT NULL DEFAULT 0 CHECK (total_pool_fet >= 0),
  status          public.venue_stake_status NOT NULL DEFAULT 'open',
  created_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT venue_match_stake_unique UNIQUE (venue_id, match_id)
);

CREATE TABLE IF NOT EXISTS public.venue_match_stake_entries (
  id              uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  stake_id        uuid NOT NULL REFERENCES public.venue_match_stakes (id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  prediction_id   uuid REFERENCES public.user_predictions (id) ON DELETE SET NULL,
  created_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (stake_id, user_id)
);

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
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_stake
  FROM public.venue_match_stakes
  WHERE id = p_stake_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Stake not found';
  END IF;

  IF v_stake.status <> 'open' THEN
    RAISE EXCEPTION 'This pool is no longer accepting entries';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.venue_match_stake_entries
    WHERE stake_id = p_stake_id
      AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'You have already joined this pool';
  END IF;

  SELECT id INTO v_prediction_id
  FROM public.user_predictions
  WHERE user_id = v_user_id
    AND match_id = v_stake.match_id
  LIMIT 1;

  IF v_prediction_id IS NULL THEN
    RAISE EXCEPTION 'You must make a prediction for this match before joining the pool';
  END IF;

  SELECT available_balance_fet
  INTO v_balance_before
  FROM public.fet_wallets
  WHERE user_id = v_user_id
  FOR UPDATE;

  IF COALESCE(v_balance_before, 0) < v_stake.entry_fee_fet THEN
    RAISE EXCEPTION 'Insufficient FET balance';
  END IF;

  IF v_stake.entry_fee_fet > 0 THEN
    UPDATE public.fet_wallets
    SET available_balance_fet = available_balance_fet - v_stake.entry_fee_fet,
        updated_at = now()
    WHERE user_id = v_user_id;

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
    VALUES (
      v_user_id,
      'venue_stake_entry',
      'debit',
      v_stake.entry_fee_fet,
      COALESCE(v_balance_before, 0),
      COALESCE(v_balance_before, 0) - v_stake.entry_fee_fet,
      'venue_match_stake',
      p_stake_id::text,
      'Joined venue pool for match'
    );
  END IF;

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
  SELECT * INTO v_stake
  FROM public.venue_match_stakes
  WHERE id = p_stake_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Stake not found';
  END IF;

  IF v_stake.status <> 'open' THEN
    RAISE EXCEPTION 'Stake is already %', v_stake.status;
  END IF;

  SELECT * INTO v_match
  FROM public.matches
  WHERE id = v_stake.match_id;

  IF v_match.match_status NOT IN ('finished', 'FT', 'AET', 'PEN') THEN
    RAISE EXCEPTION 'Match is not finished yet';
  END IF;

  WITH winners AS (
    SELECT e.user_id, e.id AS entry_id
    FROM public.venue_match_stake_entries e
    JOIN public.user_predictions p ON p.id = e.prediction_id
    WHERE e.stake_id = p_stake_id
      AND p.predicted_result_code = v_match.result_code
  )
  SELECT count(*) INTO v_winner_count FROM winners;

  IF v_winner_count > 0 THEN
    v_reward_per_winner := floor(v_stake.total_pool_fet / v_winner_count);

    FOR v_winner IN (
      SELECT e.user_id, p.id AS prediction_id
      FROM public.venue_match_stake_entries e
      JOIN public.user_predictions p ON p.id = e.prediction_id
      WHERE e.stake_id = p_stake_id
        AND p.predicted_result_code = v_match.result_code
    ) LOOP
      INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
      VALUES (v_winner.user_id, v_reward_per_winner, 0)
      ON CONFLICT (user_id) DO UPDATE
      SET available_balance_fet = public.fet_wallets.available_balance_fet + v_reward_per_winner,
          updated_at = now();

      INSERT INTO public.fet_wallet_transactions (
        user_id,
        tx_type,
        direction,
        amount_fet,
        reference_type,
        reference_id,
        title
      )
      VALUES (
        v_winner.user_id,
        'venue_stake_win',
        'credit',
        v_reward_per_winner,
        'venue_match_stake',
        p_stake_id::text,
        'Won venue pool for ' || v_match.home_team_id || ' vs ' || v_match.away_team_id
      );
    END LOOP;
  END IF;

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

ALTER TABLE public.venue_match_stakes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.venue_match_stake_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view venue stakes" ON public.venue_match_stakes;
DROP POLICY IF EXISTS "Users can view active/settled stakes" ON public.venue_match_stakes;
CREATE POLICY "Users can view active/settled stakes"
  ON public.venue_match_stakes FOR SELECT
  TO authenticated, anon
  USING (
    status IN ('open', 'settled')
    OR public.dinein_is_venue_member(venue_id, ARRAY['owner', 'manager']::public.venue_user_role[])
  );

DROP POLICY IF EXISTS "Venue managers can manage stakes" ON public.venue_match_stakes;
DROP POLICY IF EXISTS "Venue managers can create stakes" ON public.venue_match_stakes;
CREATE POLICY "Venue managers can create stakes"
  ON public.venue_match_stakes FOR INSERT
  TO authenticated
  WITH CHECK (public.dinein_is_venue_member(venue_id, ARRAY['owner', 'manager']::public.venue_user_role[]));

DROP POLICY IF EXISTS "Venue managers can update stakes" ON public.venue_match_stakes;
CREATE POLICY "Venue managers can update stakes"
  ON public.venue_match_stakes FOR UPDATE
  TO authenticated
  USING (public.dinein_is_venue_member(venue_id, ARRAY['owner', 'manager']::public.venue_user_role[]))
  WITH CHECK (public.dinein_is_venue_member(venue_id, ARRAY['owner', 'manager']::public.venue_user_role[]));

DROP POLICY IF EXISTS "Venue managers can delete stakes" ON public.venue_match_stakes;
CREATE POLICY "Venue managers can delete stakes"
  ON public.venue_match_stakes FOR DELETE
  TO authenticated
  USING (public.dinein_is_venue_member(venue_id, ARRAY['owner', 'manager']::public.venue_user_role[]));

DROP POLICY IF EXISTS "Users can view their own stake entries" ON public.venue_match_stake_entries;
DROP POLICY IF EXISTS "Venue managers can view all entries for their venue" ON public.venue_match_stake_entries;
DROP POLICY IF EXISTS "Users and venue managers can view stake entries" ON public.venue_match_stake_entries;
CREATE POLICY "Users and venue managers can view stake entries"
  ON public.venue_match_stake_entries FOR SELECT
  TO authenticated
  USING (
    user_id = (select auth.uid())
    OR EXISTS (
      SELECT 1
      FROM public.venue_match_stakes s
      WHERE s.id = stake_id
        AND public.dinein_is_venue_member(s.venue_id)
    )
  );

CREATE INDEX IF NOT EXISTS venue_match_stakes_match_idx ON public.venue_match_stakes (match_id);
CREATE INDEX IF NOT EXISTS venue_match_stakes_venue_idx ON public.venue_match_stakes (venue_id);

GRANT SELECT ON public.venue_match_stakes TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.venue_match_stakes TO authenticated;
GRANT SELECT ON public.venue_match_stake_entries TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_venue_match_stake(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.settle_venue_match_stake(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.settle_all_finished_venue_stakes(int) TO authenticated, service_role;

-- Venue onboarding support.
ALTER TABLE public.venues
  ADD COLUMN IF NOT EXISTS momo_code text;

CREATE TABLE IF NOT EXISTS public.onboarding_requests (
  id              uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  venue_id        uuid NOT NULL REFERENCES public.venues (id) ON DELETE CASCADE,
  submitted_by    uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  email           text,
  phone           text,
  whatsapp        text,
  revolut_link    text,
  momo_code       text,
  menu_items_json jsonb,
  status          text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  admin_notes     text,
  reviewed_by     uuid REFERENCES auth.users (id) ON DELETE SET NULL,
  reviewed_at     timestamptz,
  created_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at      timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS onboarding_requests_status_created_idx
  ON public.onboarding_requests (status, created_at DESC);
CREATE INDEX IF NOT EXISTS onboarding_requests_venue_idx
  ON public.onboarding_requests (venue_id);

ALTER TABLE public.onboarding_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS onboarding_requests_select_submitter ON public.onboarding_requests;
CREATE POLICY onboarding_requests_select_submitter ON public.onboarding_requests
  FOR SELECT TO authenticated
  USING (
    submitted_by = (select auth.uid())
    OR EXISTS (
      SELECT 1
      FROM public.admin_users au
      WHERE au.user_id = (select auth.uid())
        AND au.is_active = true
        AND au.role IN ('super_admin', 'admin', 'moderator')
    )
  );

DROP POLICY IF EXISTS onboarding_requests_insert_submitter ON public.onboarding_requests;
CREATE POLICY onboarding_requests_insert_submitter ON public.onboarding_requests
  FOR INSERT TO authenticated
  WITH CHECK (submitted_by = (select auth.uid()));

DROP POLICY IF EXISTS onboarding_requests_update_admin ON public.onboarding_requests;
CREATE POLICY onboarding_requests_update_admin ON public.onboarding_requests
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.admin_users au
      WHERE au.user_id = (select auth.uid())
        AND au.is_active = true
        AND au.role IN ('super_admin', 'admin', 'moderator')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.admin_users au
      WHERE au.user_id = (select auth.uid())
        AND au.is_active = true
        AND au.role IN ('super_admin', 'admin', 'moderator')
    )
  );

GRANT SELECT, INSERT, UPDATE ON public.onboarding_requests TO authenticated;

-- Security hardening.
ALTER FUNCTION public.dinein_is_venue_member(uuid, public.venue_user_role[]) STABLE;

DROP POLICY IF EXISTS orders_update_venue_member ON public.orders;
DROP POLICY IF EXISTS orders_update_staff_status ON public.orders;
CREATE POLICY orders_update_staff_status ON public.orders
  FOR UPDATE
  TO authenticated
  USING (
    public.dinein_is_venue_member(venue_id, ARRAY['owner', 'manager', 'staff']::public.venue_user_role[])
  )
  WITH CHECK (
    public.dinein_is_venue_member(venue_id, ARRAY['owner', 'manager', 'staff']::public.venue_user_role[])
  );

COMMENT ON TABLE public.order_items IS 'RLS enforced: Accessible only by order owner or venue staff via orders JOIN.';

CREATE OR REPLACE FUNCTION public.is_order_owner(p_order_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.orders
    WHERE id = p_order_id
      AND user_id = auth.uid()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.is_order_owner(uuid) TO authenticated;

COMMIT;
