-- ============================================================
-- 20260418132000_fet_supply_cap_enforcement.sql
-- Enforce the documented FET supply cap across all minting paths.
-- ============================================================

BEGIN;

-- -----------------------------------------------------------------
-- Shared supply-cap helpers
-- -----------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fet_supply_cap()
RETURNS bigint
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT 100000000::bigint;
$$;

CREATE OR REPLACE FUNCTION public.lock_fet_supply_cap()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM pg_advisory_xact_lock(
    hashtextextended('public.fet_supply_cap', 0)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.assert_fet_mint_within_cap(
  p_amount bigint,
  p_context text DEFAULT 'FET mint'
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_supply bigint := 0;
  v_supply_cap bigint := public.fet_supply_cap();
  v_new_total bigint;
  v_context text := coalesce(nullif(trim(p_context), ''), 'FET mint');
BEGIN
  IF p_amount IS NULL OR p_amount < 0 THEN
    RAISE EXCEPTION 'Mint amount must be non-negative';
  END IF;

  PERFORM public.lock_fet_supply_cap();

  SELECT coalesce(sum(available_balance_fet + locked_balance_fet), 0)::bigint
  INTO v_current_supply
  FROM public.fet_wallets;

  v_new_total := v_current_supply + p_amount;

  IF v_new_total > v_supply_cap THEN
    RAISE EXCEPTION '% would exceed FET supply cap (% + % > %)',
      v_context,
      v_current_supply,
      p_amount,
      v_supply_cap;
  END IF;

  RETURN v_new_total;
END;
$$;

CREATE OR REPLACE VIEW public.fet_supply_overview AS
SELECT
  coalesce(sum(available_balance_fet), 0) AS total_available,
  coalesce(sum(locked_balance_fet), 0) AS total_locked,
  coalesce(sum(available_balance_fet + locked_balance_fet), 0) AS total_supply,
  count(*)::bigint AS total_wallets,
  count(*) FILTER (WHERE available_balance_fet > 0) AS active_wallets,
  coalesce(avg(available_balance_fet), 0)::bigint AS avg_balance,
  coalesce(max(available_balance_fet), 0)::bigint AS max_balance,
  public.fet_supply_cap()::numeric AS supply_cap,
  greatest(
    public.fet_supply_cap()::numeric - coalesce(sum(available_balance_fet + locked_balance_fet), 0),
    0::numeric
  ) AS remaining_mintable
FROM public.fet_wallets;

-- -----------------------------------------------------------------
-- Mint-path enforcement
-- -----------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.ensure_user_foundation(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  phone_value text;
  v_foundation_grant bigint := 5000;
  v_current_supply bigint := 0;
  v_wallet_created boolean := false;
BEGIN
  SELECT public.resolve_auth_user_phone(p_user_id) INTO phone_value;

  INSERT INTO public.profiles (id, user_id, phone_number)
  VALUES (p_user_id, p_user_id, phone_value)
  ON CONFLICT (id) DO UPDATE
    SET user_id = EXCLUDED.user_id,
        phone_number = coalesce(EXCLUDED.phone_number, profiles.phone_number);

  INSERT INTO public.app_preferences (user_id)
  VALUES (p_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  PERFORM public.lock_fet_supply_cap();

  IF NOT EXISTS (
    SELECT 1
    FROM public.fet_wallets
    WHERE user_id = p_user_id
  ) THEN
    SELECT coalesce(sum(available_balance_fet + locked_balance_fet), 0)::bigint
    INTO v_current_supply
    FROM public.fet_wallets;

    IF v_current_supply + v_foundation_grant > public.fet_supply_cap() THEN
      RAISE EXCEPTION 'ensure_user_foundation would exceed FET supply cap (% + % > %)',
        v_current_supply,
        v_foundation_grant,
        public.fet_supply_cap();
    END IF;

    INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
    VALUES (p_user_id, v_foundation_grant, 0)
    ON CONFLICT (user_id) DO NOTHING
    RETURNING true INTO v_wallet_created;

    IF coalesce(v_wallet_created, false) THEN
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
        p_user_id,
        'foundation_grant',
        'credit',
        v_foundation_grant,
        0,
        v_foundation_grant,
        'foundation_grant',
        p_user_id,
        'Foundation grant - welcome bonus'
      );
    END IF;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_credit_fet(
  p_target_user_id uuid,
  p_amount bigint,
  p_reason text DEFAULT 'Admin credit'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_user_id uuid;
  v_balance_before bigint;
BEGIN
  v_admin_user_id := public.require_active_admin_user();

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be positive';
  END IF;

  PERFORM public.assert_fet_mint_within_cap(p_amount, 'admin_credit_fet');

  SELECT available_balance_fet
  INTO v_balance_before
  FROM public.fet_wallets
  WHERE user_id = p_target_user_id
  FOR UPDATE;

  INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
  VALUES (p_target_user_id, p_amount, 0)
  ON CONFLICT (user_id) DO UPDATE
  SET available_balance_fet = fet_wallets.available_balance_fet + p_amount,
      updated_at = now();

  INSERT INTO public.fet_wallet_transactions (
    user_id,
    tx_type,
    direction,
    amount_fet,
    balance_before_fet,
    balance_after_fet,
    reference_type,
    title
  ) VALUES (
    p_target_user_id,
    'admin_credit',
    'credit',
    p_amount,
    coalesce(v_balance_before, 0),
    coalesce(v_balance_before, 0) + p_amount,
    'admin_action',
    'Admin credit: ' || coalesce(p_reason, '')
  );

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
    'credit_fet',
    'wallets',
    'user',
    p_target_user_id::text,
    jsonb_build_object('amount', p_amount, 'reason', p_reason)
  FROM public.admin_users au
  WHERE au.user_id = v_admin_user_id;

  RETURN jsonb_build_object(
    'status', 'credited',
    'user_id', p_target_user_id,
    'amount', p_amount,
    'new_balance', coalesce(v_balance_before, 0) + p_amount
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.settle_daily_challenge(
  p_challenge_id uuid,
  p_home_score integer,
  p_away_score integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_user_id uuid;
  v_challenge record;
  v_entry record;
  v_is_result boolean;
  v_is_exact boolean;
  v_payout bigint;
  v_total_mint bigint := 0;
  v_winner_count integer := 0;
BEGIN
  v_admin_user_id := public.require_active_admin_user();

  IF p_home_score IS NULL OR p_away_score IS NULL OR p_home_score < 0 OR p_away_score < 0 THEN
    RAISE EXCEPTION 'Scores must be non-negative integers';
  END IF;

  SELECT *
  INTO v_challenge
  FROM public.daily_challenges
  WHERE id = p_challenge_id
  FOR UPDATE;

  IF v_challenge IS NULL THEN
    RAISE EXCEPTION 'Challenge not found';
  END IF;

  IF v_challenge.status <> 'active' THEN
    RAISE EXCEPTION 'Challenge already settled';
  END IF;

  FOR v_entry IN
    SELECT *
    FROM public.daily_challenge_entries
    WHERE challenge_id = p_challenge_id
      AND result = 'pending'
    FOR UPDATE
  LOOP
    v_is_exact := (
      v_entry.predicted_home_score = p_home_score
      AND v_entry.predicted_away_score = p_away_score
    );

    v_is_result := v_is_exact OR (
      sign(v_entry.predicted_home_score - v_entry.predicted_away_score) =
      sign(p_home_score - p_away_score)
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
      v_total_mint := v_total_mint + v_payout;
    END IF;
  END LOOP;

  IF v_total_mint > 0 THEN
    PERFORM public.assert_fet_mint_within_cap(
      v_total_mint,
      'settle_daily_challenge'
    );

    INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
    SELECT DISTINCT e.user_id, 0, 0
    FROM public.daily_challenge_entries e
    WHERE e.challenge_id = p_challenge_id
      AND e.payout_fet > 0
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
      e.user_id,
      'daily_challenge',
      'credit',
      e.payout_fet,
      coalesce(w.available_balance_fet, 0),
      coalesce(w.available_balance_fet, 0) + e.payout_fet,
      'daily_challenge',
      p_challenge_id,
      CASE
        WHEN e.result = 'exact_score' THEN 'Daily challenge - exact score bonus'
        ELSE 'Daily challenge - correct result'
      END
    FROM public.daily_challenge_entries e
    JOIN public.fet_wallets w
      ON w.user_id = e.user_id
    WHERE e.challenge_id = p_challenge_id
      AND e.payout_fet > 0;

    UPDATE public.fet_wallets w
    SET available_balance_fet = w.available_balance_fet + e.payout_fet,
        updated_at = now()
    FROM public.daily_challenge_entries e
    WHERE w.user_id = e.user_id
      AND e.challenge_id = p_challenge_id
      AND e.payout_fet > 0;
  END IF;

  UPDATE public.daily_challenges
  SET status = 'settled',
      official_home_score = p_home_score,
      official_away_score = p_away_score,
      total_winners = v_winner_count,
      settled_at = now()
  WHERE id = p_challenge_id;

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
    'settle_daily_challenge',
    'predictions',
    'daily_challenge',
    p_challenge_id::text,
    jsonb_build_object(
      'official_home_score', p_home_score,
      'official_away_score', p_away_score,
      'winner_count', v_winner_count,
      'minted_fet', v_total_mint
    )
  FROM public.admin_users au
  WHERE au.user_id = v_admin_user_id;

  RETURN jsonb_build_object(
    'status', 'settled',
    'challenge_id', p_challenge_id,
    'total_winners', v_winner_count,
    'minted_fet', v_total_mint,
    'settled_by', v_admin_user_id
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
  v_total_mint bigint := 0;
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
      'minted_fet', 0,
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

  SELECT coalesce(sum(sl.projected_earn_fet), 0)::bigint
  INTO v_total_mint
  FROM public.prediction_slips sl
  WHERE sl.id = ANY(v_slip_ids)
    AND sl.status = 'settled_win'
    AND sl.projected_earn_fet > 0;

  IF v_total_mint > 0 THEN
    PERFORM public.assert_fet_mint_within_cap(
      v_total_mint,
      'settle_prediction_slips_for_match'
    );
  END IF;

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
    'Prediction win - earned ' || sl.projected_earn_fet || ' FET'
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
    'settle_prediction_slips',
    'predictions',
    'match',
    p_match_id,
    jsonb_build_object(
      'official_home_score', p_official_home_score,
      'official_away_score', p_official_away_score,
      'selections_settled', v_settled_count,
      'slips_affected', cardinality(ARRAY(SELECT DISTINCT unnest(v_slip_ids))),
      'minted_fet', v_total_mint
    )
  FROM public.admin_users au
  WHERE au.user_id = v_admin_id;

  RETURN jsonb_build_object(
    'match_id', p_match_id,
    'selections_settled', v_settled_count,
    'slips_affected', cardinality(ARRAY(SELECT DISTINCT unnest(v_slip_ids))),
    'minted_fet', v_total_mint,
    'settled_by', v_admin_id
  );
END;
$$;

-- -----------------------------------------------------------------
-- Helper execution hardening
-- -----------------------------------------------------------------

REVOKE ALL ON FUNCTION public.fet_supply_cap() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.lock_fet_supply_cap() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assert_fet_mint_within_cap(bigint, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.fet_supply_cap() TO authenticated;

COMMIT;
