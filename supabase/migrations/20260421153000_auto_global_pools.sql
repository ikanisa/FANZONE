BEGIN;

-- ============================================================
-- 20260421153000_auto_global_pools.sql
--
-- Automatically create global, system-seeded pools for upcoming
-- matches involving the top European teams. The system account
-- seeds each pool with 500 FET so the public pool is immediately
-- open and funded for authenticated users to join.
-- ============================================================

-- -----------------------------------------------------------------
-- 0. Ensure the machine system user exists for service automation
-- -----------------------------------------------------------------

INSERT INTO auth.users (id, email)
VALUES ('00000000-0000-0000-0000-000000000000', 'system@fanzone.machine')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.admin_users (user_id, email, phone, display_name, role, is_active)
VALUES (
  '00000000-0000-0000-0000-000000000000',
  'system@fanzone.machine',
  NULL,
  'System (Machine)',
  'super_admin',
  true
)
ON CONFLICT (user_id) DO NOTHING;

-- -----------------------------------------------------------------
-- 1. Pool metadata for system-generated global pools
-- -----------------------------------------------------------------

ALTER TABLE public.prediction_challenges
  ADD COLUMN IF NOT EXISTS pool_source text NOT NULL DEFAULT 'user';

ALTER TABLE public.prediction_challenges
  ADD COLUMN IF NOT EXISTS sponsor_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.prediction_challenges
  ADD COLUMN IF NOT EXISTS sponsor_stake_fet bigint NOT NULL DEFAULT 0;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'prediction_challenges_pool_source_check'
  ) THEN
    ALTER TABLE public.prediction_challenges
      ADD CONSTRAINT prediction_challenges_pool_source_check
      CHECK (pool_source IN ('user', 'system_auto_global'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'prediction_challenges_sponsor_stake_non_negative'
  ) THEN
    ALTER TABLE public.prediction_challenges
      ADD CONSTRAINT prediction_challenges_sponsor_stake_non_negative
      CHECK (sponsor_stake_fet >= 0);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_prediction_challenges_pool_source_status
  ON public.prediction_challenges (pool_source, status, lock_at DESC);

CREATE INDEX IF NOT EXISTS idx_prediction_challenges_sponsor_user
  ON public.prediction_challenges (sponsor_user_id, created_at DESC)
  WHERE sponsor_user_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_prediction_challenges_system_auto_global_match
  ON public.prediction_challenges (match_id)
  WHERE pool_source = 'system_auto_global';

-- -----------------------------------------------------------------
-- 2. Sponsor-aware settlement for seeded pools
-- -----------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.settle_pool(
  p_pool_id uuid,
  p_official_home_score integer,
  p_official_away_score integer
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_pool record;
  v_winner_count integer := 0;
  v_loser_count integer := 0;
  v_payout_per_winner bigint := 0;
  v_entry record;
  v_is_winner boolean;
  v_balance_before bigint;
  v_sponsor_balance_before bigint;
  v_sponsor_refunded boolean := false;
  v_sponsor_refund_amount bigint := 0;
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

  v_loser_count := GREATEST(coalesce(v_pool.total_participants, 0) - v_winner_count, 0);

  IF v_winner_count > 0 THEN
    v_payout_per_winner := v_pool.total_pool_fet / v_winner_count;
  END IF;

  FOR v_entry IN
    SELECT *
    FROM public.prediction_challenge_entries
    WHERE challenge_id = p_pool_id
      AND status = 'active'
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
      SELECT available_balance_fet
      INTO v_balance_before
      FROM public.fet_wallets
      WHERE user_id = v_entry.user_id
      FOR UPDATE;

      UPDATE public.fet_wallets
      SET available_balance_fet = available_balance_fet + v_payout_per_winner,
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
        v_payout_per_winner,
        coalesce(v_balance_before, 0),
        coalesce(v_balance_before, 0) + v_payout_per_winner,
        'prediction_challenge',
        p_pool_id::text,
        'Pool payout — won ' || v_payout_per_winner || ' FET'
      );
    END IF;
  END LOOP;

  IF v_winner_count = 0 THEN
    FOR v_entry IN
      SELECT *
      FROM public.prediction_challenge_entries
      WHERE challenge_id = p_pool_id
        AND status = 'lost'
      FOR UPDATE
    LOOP
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
      SET status = 'refunded',
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
        p_pool_id::text,
        'Pool refund — no winners'
      );
    END LOOP;

    IF coalesce(v_pool.sponsor_stake_fet, 0) > 0
       AND v_pool.sponsor_user_id IS NOT NULL THEN
      INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
      VALUES (v_pool.sponsor_user_id, 0, 0)
      ON CONFLICT (user_id) DO NOTHING;

      SELECT available_balance_fet
      INTO v_sponsor_balance_before
      FROM public.fet_wallets
      WHERE user_id = v_pool.sponsor_user_id
      FOR UPDATE;

      UPDATE public.fet_wallets
      SET available_balance_fet = available_balance_fet + v_pool.sponsor_stake_fet,
          updated_at = now()
      WHERE user_id = v_pool.sponsor_user_id;

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
        v_pool.sponsor_user_id,
        'pool_seed_refund',
        'credit',
        v_pool.sponsor_stake_fet,
        coalesce(v_sponsor_balance_before, 0),
        coalesce(v_sponsor_balance_before, 0) + v_pool.sponsor_stake_fet,
        'prediction_challenge',
        p_pool_id::text,
        'Pool seed refund — no winners'
      );

      v_sponsor_refunded := true;
      v_sponsor_refund_amount := v_pool.sponsor_stake_fet;
    END IF;
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
    'refunded', (v_winner_count = 0),
    'sponsor_refunded', v_sponsor_refunded,
    'sponsor_refund_amount', v_sponsor_refund_amount
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.void_pool(
  p_pool_id uuid,
  p_reason text DEFAULT 'Admin cancelled'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_pool record;
  v_entry record;
  v_balance_before bigint;
  v_refund_count integer := 0;
  v_sponsor_balance_before bigint;
  v_sponsor_refund_amount bigint := 0;
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
    SELECT *
    FROM public.prediction_challenge_entries
    WHERE challenge_id = p_pool_id
      AND status = 'active'
    FOR UPDATE
  LOOP
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
      p_pool_id::text,
      'Pool voided: ' || coalesce(p_reason, 'cancelled')
    );

    v_refund_count := v_refund_count + 1;
  END LOOP;

  IF coalesce(v_pool.sponsor_stake_fet, 0) > 0
     AND v_pool.sponsor_user_id IS NOT NULL THEN
    INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
    VALUES (v_pool.sponsor_user_id, 0, 0)
    ON CONFLICT (user_id) DO NOTHING;

    SELECT available_balance_fet
    INTO v_sponsor_balance_before
    FROM public.fet_wallets
    WHERE user_id = v_pool.sponsor_user_id
    FOR UPDATE;

    UPDATE public.fet_wallets
    SET available_balance_fet = available_balance_fet + v_pool.sponsor_stake_fet,
        updated_at = now()
    WHERE user_id = v_pool.sponsor_user_id;

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
      v_pool.sponsor_user_id,
      'pool_seed_refund',
      'credit',
      v_pool.sponsor_stake_fet,
      coalesce(v_sponsor_balance_before, 0),
      coalesce(v_sponsor_balance_before, 0) + v_pool.sponsor_stake_fet,
      'prediction_challenge',
      p_pool_id::text,
      'Pool seed refund: ' || coalesce(p_reason, 'cancelled')
    );

    v_sponsor_refund_amount := v_pool.sponsor_stake_fet;
  END IF;

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
    'sponsor_refund_amount', v_sponsor_refund_amount,
    'reason', p_reason
  );
END;
$$;

-- -----------------------------------------------------------------
-- 3. System wallet funding + pool creation helpers
-- -----------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.ensure_system_pool_budget(
  p_required_amount bigint,
  p_context text DEFAULT 'system global pool budget'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_system_user constant uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_balance_before bigint := 0;
  v_top_up_amount bigint := 0;
BEGIN
  IF p_required_amount IS NULL OR p_required_amount < 0 THEN
    RAISE EXCEPTION 'Required amount must be non-negative';
  END IF;

  PERFORM public.ensure_user_foundation(v_system_user);

  SELECT coalesce(available_balance_fet, 0)
  INTO v_balance_before
  FROM public.fet_wallets
  WHERE user_id = v_system_user
  FOR UPDATE;

  IF v_balance_before < p_required_amount THEN
    v_top_up_amount := p_required_amount - v_balance_before;

    PERFORM public.assert_fet_mint_within_cap(
      v_top_up_amount,
      coalesce(nullif(trim(p_context), ''), 'system global pool budget')
    );

    UPDATE public.fet_wallets
    SET available_balance_fet = available_balance_fet + v_top_up_amount,
        updated_at = now()
    WHERE user_id = v_system_user;

    INSERT INTO public.fet_wallet_transactions (
      user_id,
      tx_type,
      direction,
      amount_fet,
      balance_before_fet,
      balance_after_fet,
      reference_type,
      reference_id,
      title,
      metadata
    ) VALUES (
      v_system_user,
      'system_pool_budget',
      'credit',
      v_top_up_amount,
      v_balance_before,
      v_balance_before + v_top_up_amount,
      'system_auto_global_pool',
      v_system_user::text,
      'System pool budget top-up',
      jsonb_build_object('context', p_context)
    );

    v_balance_before := v_balance_before + v_top_up_amount;
  END IF;

  RETURN jsonb_build_object(
    'user_id', v_system_user,
    'available_balance', v_balance_before,
    'top_up_amount', v_top_up_amount
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.create_system_global_pool(
  p_match_id text,
  p_stake bigint DEFAULT 500,
  p_lock_buffer_minutes integer DEFAULT 30
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_system_user constant uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_match record;
  v_pool_id uuid;
  v_existing_pool_id uuid;
  v_balance_before bigint := 0;
  v_lock_buffer_minutes integer := GREATEST(coalesce(p_lock_buffer_minutes, 30), 1);
  v_lock_at timestamptz;
BEGIN
  IF p_match_id IS NULL OR btrim(p_match_id) = '' THEN
    RAISE EXCEPTION 'Match id is required';
  END IF;

  IF p_stake IS NULL OR p_stake < 10 THEN
    RAISE EXCEPTION 'Minimum stake is 10 FET';
  END IF;

  SELECT id
  INTO v_existing_pool_id
  FROM public.prediction_challenges
  WHERE match_id = p_match_id
    AND pool_source = 'system_auto_global'
  LIMIT 1;

  IF v_existing_pool_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'status', 'existing',
      'pool_id', v_existing_pool_id,
      'match_id', p_match_id
    );
  END IF;

  SELECT
    m.id,
    m.home_team,
    m.away_team,
    m.status,
    public.match_kickoff_at_utc(m.date, m.kickoff_time) AS kickoff_at
  INTO v_match
  FROM public.matches m
  WHERE m.id = p_match_id;

  IF v_match IS NULL THEN
    RAISE EXCEPTION 'Match not found';
  END IF;

  IF v_match.status <> 'upcoming' THEN
    RAISE EXCEPTION 'Can only create automatic pools for upcoming matches';
  END IF;

  IF v_match.kickoff_at <= now() + make_interval(mins => v_lock_buffer_minutes) THEN
    RAISE EXCEPTION 'Match kickoff is too close to create a new global pool';
  END IF;

  v_lock_at := v_match.kickoff_at - make_interval(mins => v_lock_buffer_minutes);

  PERFORM public.ensure_system_pool_budget(
    p_stake,
    'system global pool seed for ' || p_match_id
  );

  SELECT available_balance_fet
  INTO v_balance_before
  FROM public.fet_wallets
  WHERE user_id = v_system_user
  FOR UPDATE;

  IF coalesce(v_balance_before, 0) < p_stake THEN
    RAISE EXCEPTION 'System wallet has insufficient FET to seed the pool';
  END IF;

  UPDATE public.fet_wallets
  SET available_balance_fet = available_balance_fet - p_stake,
      updated_at = now()
  WHERE user_id = v_system_user;

  INSERT INTO public.prediction_challenges (
    match_id,
    match_name,
    creator_user_id,
    stake_fet,
    currency_code,
    status,
    lock_at,
    total_participants,
    total_pool_fet,
    pool_source,
    sponsor_user_id,
    sponsor_stake_fet
  ) VALUES (
    p_match_id,
    v_match.home_team || ' vs ' || v_match.away_team,
    v_system_user,
    p_stake,
    'FET',
    'open',
    v_lock_at,
    0,
    p_stake,
    'system_auto_global',
    v_system_user,
    p_stake
  )
  RETURNING id INTO v_pool_id;

  INSERT INTO public.fet_wallet_transactions (
    user_id,
    tx_type,
    direction,
    amount_fet,
    balance_before_fet,
    balance_after_fet,
    reference_type,
    reference_id,
    title,
    metadata
  ) VALUES (
    v_system_user,
    'pool_seed_stake',
    'debit',
    p_stake,
    v_balance_before,
    v_balance_before - p_stake,
    'prediction_challenge',
    v_pool_id::text,
    'Global pool seed: ' || v_match.home_team || ' vs ' || v_match.away_team,
    jsonb_build_object(
      'pool_source', 'system_auto_global',
      'match_id', p_match_id,
      'seed_stake_fet', p_stake
    )
  );

  RETURN jsonb_build_object(
    'status', 'created',
    'pool_id', v_pool_id,
    'match_id', p_match_id,
    'match_name', v_match.home_team || ' vs ' || v_match.away_team,
    'stake_fet', p_stake,
    'lock_at', v_lock_at
  );
EXCEPTION
  WHEN unique_violation THEN
    SELECT id
    INTO v_existing_pool_id
    FROM public.prediction_challenges
    WHERE match_id = p_match_id
      AND pool_source = 'system_auto_global'
    LIMIT 1;

    RETURN jsonb_build_object(
      'status', 'existing',
      'pool_id', v_existing_pool_id,
      'match_id', p_match_id
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.auto_create_global_pools(
  p_hours_ahead integer DEFAULT 72,
  p_limit integer DEFAULT 20,
  p_stake bigint DEFAULT 500,
  p_top_rank integer DEFAULT 20,
  p_lock_buffer_minutes integer DEFAULT 30
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_job_id uuid;
  v_match record;
  v_result jsonb;
  v_hours_ahead integer := GREATEST(coalesce(p_hours_ahead, 72), 1);
  v_limit integer := GREATEST(coalesce(p_limit, 20), 1);
  v_top_rank integer := GREATEST(coalesce(p_top_rank, 20), 1);
  v_lock_buffer_minutes integer := GREATEST(coalesce(p_lock_buffer_minutes, 30), 1);
  v_created_count integer := 0;
  v_existing_count integer := 0;
  v_considered_count integer := 0;
  v_created jsonb := '[]'::jsonb;
  v_errors jsonb := '[]'::jsonb;
  v_summary jsonb;
BEGIN
  INSERT INTO public.cron_job_log (job_name, status, result)
  VALUES (
    'auto_create_global_pools',
    'running',
    jsonb_build_object(
      'hours_ahead', v_hours_ahead,
      'limit', v_limit,
      'stake_fet', p_stake,
      'top_rank', v_top_rank,
      'lock_buffer_minutes', v_lock_buffer_minutes
    )
  )
  RETURNING id INTO v_job_id;

  FOR v_match IN
    WITH top_teams AS (
      SELECT opt.id
      FROM public.onboarding_popular_teams opt
      WHERE opt.is_active = true
        AND opt.region = 'europe'
        AND opt.popular_pick_rank <= v_top_rank
    )
    SELECT
      m.id,
      m.home_team,
      m.away_team,
      public.match_kickoff_at_utc(m.date, m.kickoff_time) AS kickoff_at
    FROM public.matches m
    WHERE m.status = 'upcoming'
      AND public.match_kickoff_at_utc(m.date, m.kickoff_time)
        > now() + make_interval(mins => v_lock_buffer_minutes)
      AND public.match_kickoff_at_utc(m.date, m.kickoff_time)
        <= now() + make_interval(hours => v_hours_ahead)
      AND (
        m.home_team_id IN (SELECT id FROM top_teams)
        OR m.away_team_id IN (SELECT id FROM top_teams)
      )
      AND NOT EXISTS (
        SELECT 1
        FROM public.prediction_challenges pc
        WHERE pc.match_id = m.id
          AND pc.pool_source = 'system_auto_global'
      )
    ORDER BY kickoff_at ASC, m.id ASC
    LIMIT v_limit
  LOOP
    v_considered_count := v_considered_count + 1;

    BEGIN
      v_result := public.create_system_global_pool(
        v_match.id,
        p_stake,
        v_lock_buffer_minutes
      );

      IF coalesce(v_result->>'status', '') = 'created' THEN
        v_created_count := v_created_count + 1;
        v_created := v_created || jsonb_build_array(v_result);
      ELSE
        v_existing_count := v_existing_count + 1;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        v_errors := v_errors || jsonb_build_array(
          jsonb_build_object(
            'match_id', v_match.id,
            'match_name', v_match.home_team || ' vs ' || v_match.away_team,
            'error', SQLERRM
          )
        );
    END;
  END LOOP;

  v_summary := jsonb_build_object(
    'job_name', 'auto_create_global_pools',
    'hours_ahead', v_hours_ahead,
    'considered', v_considered_count,
    'created_count', v_created_count,
    'existing_count', v_existing_count,
    'errors_count', jsonb_array_length(v_errors),
    'created', v_created,
    'errors', v_errors
  );

  UPDATE public.cron_job_log
  SET status = 'completed',
      completed_at = now(),
      duration_ms = EXTRACT(EPOCH FROM (now() - started_at))::integer * 1000,
      result = v_summary
  WHERE id = v_job_id;

  RETURN v_summary;
EXCEPTION
  WHEN OTHERS THEN
    IF v_job_id IS NOT NULL THEN
      UPDATE public.cron_job_log
      SET status = 'failed',
          completed_at = now(),
          duration_ms = EXTRACT(EPOCH FROM (now() - started_at))::integer * 1000,
          error_message = SQLERRM
      WHERE id = v_job_id;
    END IF;
    RAISE;
END;
$$;

REVOKE ALL ON FUNCTION public.ensure_system_pool_budget(bigint, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.ensure_system_pool_budget(bigint, text) FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.create_system_global_pool(text, bigint, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_system_global_pool(text, bigint, integer) FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.auto_create_global_pools(integer, integer, bigint, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.auto_create_global_pools(integer, integer, bigint, integer, integer) FROM anon, authenticated;

GRANT EXECUTE ON FUNCTION public.ensure_system_pool_budget(bigint, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.create_system_global_pool(text, bigint, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.auto_create_global_pools(integer, integer, bigint, integer, integer) TO service_role;

-- -----------------------------------------------------------------
-- 4. Cron schedule for the Edge Function
-- -----------------------------------------------------------------

DO $$
DECLARE
  v_auto_global_pools_job_id bigint;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron')
     AND EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
    SELECT jobid
    INTO v_auto_global_pools_job_id
    FROM cron.job
    WHERE jobname = 'fanzone-auto-create-global-pools'
    ORDER BY jobid DESC
    LIMIT 1;

    IF v_auto_global_pools_job_id IS NOT NULL THEN
      PERFORM cron.unschedule(v_auto_global_pools_job_id);
    END IF;

    PERFORM cron.schedule(
      'fanzone-auto-create-global-pools',
      '*/30 * * * *',
      $job$
      SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'fanzone_project_url')
          || '/functions/v1/auto-create-global-pools',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'fanzone_cron_secret')
        ),
        body := jsonb_build_object(
          'hoursAhead', 72,
          'maxPools', 20,
          'stakeFet', 500,
          'topRank', 20,
          'lockBufferMinutes', 30
        )
      );
      $job$
    );
  END IF;
END $$;

COMMIT;
