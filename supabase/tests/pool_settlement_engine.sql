\pset tuples_only on
\pset pager off

\echo 'Verifying automated pool settlement engine...'

BEGIN;

DO $$
DECLARE
  v_creator uuid := extensions.gen_random_uuid();
  v_winner uuid := extensions.gen_random_uuid();
  v_loser uuid := extensions.gen_random_uuid();
  v_extra uuid := extensions.gen_random_uuid();
  v_pool_final uuid := extensions.gen_random_uuid();
  v_pool_refund uuid := extensions.gen_random_uuid();
  v_pool_cancelled uuid := extensions.gen_random_uuid();
  v_pool_postponed uuid := extensions.gen_random_uuid();
  v_pool_retry uuid := extensions.gen_random_uuid();
  v_venue_id uuid := extensions.gen_random_uuid();
  v_table_id uuid := extensions.gen_random_uuid();
  v_winner_order_id uuid := extensions.gen_random_uuid();
  v_camp uuid;
  v_result jsonb;
  v_wallet jsonb;
  v_winner_before_final jsonb;
  v_loser_before_final jsonb;
  v_extra_before_refund jsonb;
  v_count integer;
  v_tx_count integer;
BEGIN
  INSERT INTO auth.users (id, aud, role, email, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  VALUES
    (v_creator, 'authenticated', 'authenticated', 'settle-creator@example.test', now(), now(), '{}'::jsonb, '{}'::jsonb),
    (v_winner, 'authenticated', 'authenticated', 'settle-winner@example.test', now(), now(), '{}'::jsonb, '{}'::jsonb),
    (v_loser, 'authenticated', 'authenticated', 'settle-loser@example.test', now(), now(), '{}'::jsonb, '{}'::jsonb),
    (v_extra, 'authenticated', 'authenticated', 'settle-extra@example.test', now(), now(), '{}'::jsonb, '{}'::jsonb);

  UPDATE public.profiles
  SET display_name = CASE
        WHEN id = v_creator THEN 'Settle Creator'
        WHEN id = v_winner THEN 'Settle Winner'
        WHEN id = v_loser THEN 'Settle Loser'
        ELSE 'Settle Extra'
      END,
      updated_at = timezone('utc', now())
  WHERE id IN (v_creator, v_winner, v_loser, v_extra);

  INSERT INTO public.app_config_remote (key, value, description)
  VALUES
    ('pool_settlement_no_winner_rule', '"refund_all"'::jsonb, 'test no-winner rule'),
    ('pool_settlement_postponed_rule', '"hold"'::jsonb, 'test postponed rule'),
    ('pool_settlement_payout_rule', '"proportional"'::jsonb, 'test payout rule')
  ON CONFLICT (key) DO UPDATE
  SET value = EXCLUDED.value;

  INSERT INTO public.competitions (
    id,
    name,
    short_name,
    country,
    data_source,
    country_or_region,
    competition_type
  )
  VALUES ('settlement_engine_comp', 'Settlement Engine Competition', 'SEC', 'MT', 'test', 'MT', 'league')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.teams (id, name, short_name, country, country_code)
  VALUES
    ('settle_home', 'Settlement Home', 'SH', 'Malta', 'MT'),
    ('settle_away', 'Settlement Away', 'SA', 'Malta', 'MT')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.venues (id, name, country_code, venue_type, currency_code)
  VALUES (v_venue_id, 'Settlement Test Bar', 'MT', 'bar', 'EUR');

  INSERT INTO public.tables (id, venue_id, table_number)
  VALUES (v_table_id, v_venue_id, 'S1');

  INSERT INTO public.orders (
    id,
    venue_id,
    table_id,
    user_id,
    status,
    payment_method,
    payment_status,
    currency_code,
    subtotal_amount,
    total_amount,
    created_at
  )
  VALUES (
    v_winner_order_id,
    v_venue_id,
    v_table_id,
    v_winner,
    'served',
    'cash',
    'paid',
    'EUR',
    10,
    10,
    timezone('utc', now()) + interval '30 minutes'
  );

  INSERT INTO public.matches (id, competition_id, match_date, match_status, home_team_id, away_team_id)
  VALUES
    ('settlement_final_match', 'settlement_engine_comp', timezone('utc', now()) + interval '1 hour', 'scheduled', 'settle_home', 'settle_away'),
    ('settlement_refund_match', 'settlement_engine_comp', timezone('utc', now()) + interval '1 hour', 'scheduled', 'settle_home', 'settle_away'),
    ('settlement_cancelled_match', 'settlement_engine_comp', timezone('utc', now()) + interval '1 hour', 'scheduled', 'settle_home', 'settle_away'),
    ('settlement_postponed_match', 'settlement_engine_comp', timezone('utc', now()) + interval '1 hour', 'scheduled', 'settle_home', 'settle_away'),
    ('settlement_retry_match', 'settlement_engine_comp', timezone('utc', now()) + interval '1 hour', 'scheduled', 'settle_home', 'settle_away');

  INSERT INTO public.curated_matches (
    match_id,
    country_code,
    venue_id,
    priority_score,
    is_active,
    is_pool_eligible,
    reason,
    metadata,
    starts_at,
    expires_at
  )
  VALUES
    ('settlement_final_match', 'MT', v_venue_id, 100, true, true, 'Settlement engine test', '{"test_fixture":true,"pool_eligible":true}'::jsonb, timezone('utc', now()) - interval '1 minute', timezone('utc', now()) + interval '4 hours'),
    ('settlement_refund_match', 'MT', v_venue_id, 100, true, true, 'Settlement engine test', '{"test_fixture":true,"pool_eligible":true}'::jsonb, timezone('utc', now()) - interval '1 minute', timezone('utc', now()) + interval '4 hours'),
    ('settlement_cancelled_match', 'MT', v_venue_id, 100, true, true, 'Settlement engine test', '{"test_fixture":true,"pool_eligible":true}'::jsonb, timezone('utc', now()) - interval '1 minute', timezone('utc', now()) + interval '4 hours'),
    ('settlement_postponed_match', 'MT', v_venue_id, 100, true, true, 'Settlement engine test', '{"test_fixture":true,"pool_eligible":true}'::jsonb, timezone('utc', now()) - interval '1 minute', timezone('utc', now()) + interval '4 hours'),
    ('settlement_retry_match', 'MT', v_venue_id, 100, true, true, 'Settlement engine test', '{"test_fixture":true,"pool_eligible":true}'::jsonb, timezone('utc', now()) - interval '1 minute', timezone('utc', now()) + interval '4 hours');

  PERFORM public.wallet_post_transaction(v_winner, 'admin_adjustment', 'credit', 200, 'available', 'settle-seed-winner');
  PERFORM public.wallet_post_transaction(v_loser, 'admin_adjustment', 'credit', 200, 'available', 'settle-seed-loser');
  PERFORM public.wallet_post_transaction(v_extra, 'admin_adjustment', 'credit', 200, 'available', 'settle-seed-extra');

  -- Final match: losing stake is distributed proportionally to winning entries.
  INSERT INTO public.match_pools (id, match_id, venue_id, title, creator_user_id, entry_fee_fet, stake_min_fet, stake_max_fet)
  VALUES (v_pool_final, 'settlement_final_match', v_venue_id, 'Final settlement pool', v_creator, 0, 1, 100);

  INSERT INTO public.match_pool_camps (pool_id, code, label, result_code, display_order)
  VALUES
    (v_pool_final, 'home', 'Home', 'H', 1),
    (v_pool_final, 'away', 'Away', 'A', 2);

  SELECT id INTO v_camp FROM public.match_pool_camps WHERE pool_id = v_pool_final AND result_code = 'H';
  PERFORM set_config('request.jwt.claim.sub', v_winner::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_winner, 'role', 'authenticated')::text, true);
  PERFORM public.join_match_pool(v_pool_final, v_camp, 10, NULL);

  SELECT id INTO v_camp FROM public.match_pool_camps WHERE pool_id = v_pool_final AND result_code = 'A';
  PERFORM set_config('request.jwt.claim.sub', v_loser::text, true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_loser, 'role', 'authenticated')::text, true);
  PERFORM public.join_match_pool(v_pool_final, v_camp, 30, NULL);

  PERFORM set_config('request.jwt.claim.sub', v_winner::text, true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_winner, 'role', 'authenticated')::text, true);
  v_winner_before_final := public.get_wallet_balance(v_winner);

  PERFORM set_config('request.jwt.claim.sub', v_loser::text, true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_loser, 'role', 'authenticated')::text, true);
  v_loser_before_final := public.get_wallet_balance(v_loser);

  UPDATE public.matches
  SET match_status = 'finished',
      status = 'final',
      home_goals = 2,
      away_goals = 1,
      home_score = 2,
      away_score = 1,
      result_code = 'H',
      winner_camp = 'home'
  WHERE id = 'settlement_final_match';

  PERFORM set_config('request.jwt.claim.role', 'service_role', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('role', 'service_role')::text, true);
  v_count := public.settle_finished_match_pools(25);
  IF v_count < 1 THEN
    RAISE EXCEPTION 'Expected automated settlement batch to process at least one pool';
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_winner::text, true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_winner, 'role', 'authenticated')::text, true);
  v_wallet := public.get_wallet_balance(v_winner);
  IF (v_wallet ->> 'available_fet')::bigint <> (v_winner_before_final ->> 'available_fet')::bigint + 40
     OR (v_wallet ->> 'staked_fet')::bigint <> 0 THEN
    RAISE EXCEPTION 'Winner wallet after settlement was %, expected before % plus 40 available and 0 staked', v_wallet, v_winner_before_final;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_loser::text, true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_loser, 'role', 'authenticated')::text, true);
  v_wallet := public.get_wallet_balance(v_loser);
  IF (v_wallet ->> 'available_fet')::bigint <> (v_loser_before_final ->> 'available_fet')::bigint
     OR (v_wallet ->> 'staked_fet')::bigint <> 0 THEN
    RAISE EXCEPTION 'Loser wallet after settlement was %, expected before % available and 0 staked', v_wallet, v_loser_before_final;
  END IF;

  SELECT count(*) INTO v_tx_count
  FROM public.fet_wallet_transactions
  WHERE pool_id = v_pool_final
    AND user_id = v_winner
    AND transaction_type = 'pool_win'
    AND balance_bucket = 'available';

  IF v_tx_count <> 1 THEN
    RAISE EXCEPTION 'Expected one available pool_win credit, got %', v_tx_count;
  END IF;

  PERFORM set_config('request.jwt.claim.role', 'service_role', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('role', 'service_role')::text, true);
  v_result := public.settle_match_pool(v_pool_final);
  IF v_result ->> 'status' <> 'already_settled' THEN
    RAISE EXCEPTION 'Duplicate settlement should be idempotent, got %', v_result;
  END IF;

  SELECT count(*) INTO v_tx_count
  FROM public.fet_wallet_transactions
  WHERE pool_id = v_pool_final
    AND user_id = v_winner
    AND transaction_type = 'pool_win'
    AND balance_bucket = 'available';

  IF v_tx_count <> 1 THEN
    RAISE EXCEPTION 'Duplicate settlement created extra win credits: %', v_tx_count;
  END IF;

  -- No winning entries: default safe behavior refunds all active entries.
  INSERT INTO public.match_pools (id, match_id, venue_id, title, creator_user_id, entry_fee_fet, stake_min_fet, stake_max_fet)
  VALUES (v_pool_refund, 'settlement_refund_match', v_venue_id, 'No winner refund pool', v_creator, 0, 1, 100);

  INSERT INTO public.match_pool_camps (pool_id, code, label, result_code, display_order)
  VALUES
    (v_pool_refund, 'home', 'Home', 'H', 1),
    (v_pool_refund, 'away', 'Away', 'A', 2);

  SELECT id INTO v_camp FROM public.match_pool_camps WHERE pool_id = v_pool_refund AND result_code = 'A';
  PERFORM set_config('request.jwt.claim.sub', v_extra::text, true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_extra, 'role', 'authenticated')::text, true);
  PERFORM public.join_match_pool(v_pool_refund, v_camp, 20, NULL);
  v_extra_before_refund := public.get_wallet_balance(v_extra);

  UPDATE public.matches
  SET match_status = 'finished',
      status = 'final',
      home_goals = 1,
      away_goals = 0,
      result_code = 'H',
      winner_camp = 'home'
  WHERE id = 'settlement_refund_match';

  PERFORM set_config('request.jwt.claim.role', 'service_role', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('role', 'service_role')::text, true);
  v_result := public.settle_match_pool(v_pool_refund);
  IF v_result ->> 'status' <> 'refunded' OR v_result ->> 'reason' <> 'no_winning_entries' THEN
    RAISE EXCEPTION 'Expected no-winner refund, got %', v_result;
  END IF;

  v_wallet := public.get_wallet_balance(v_extra);
  IF (v_wallet ->> 'available_fet')::bigint <> (v_extra_before_refund ->> 'available_fet')::bigint + 20
     OR (v_wallet ->> 'staked_fet')::bigint <> 0 THEN
    RAISE EXCEPTION 'No-winner refund wallet was %, expected before % plus full refund and 0 staked', v_wallet, v_extra_before_refund;
  END IF;

  -- Cancelled match: active entries are refunded and the pool is cancelled.
  INSERT INTO public.match_pools (id, match_id, venue_id, title, creator_user_id, entry_fee_fet, stake_min_fet, stake_max_fet)
  VALUES (v_pool_cancelled, 'settlement_cancelled_match', v_venue_id, 'Cancelled refund pool', v_creator, 0, 1, 100);

  INSERT INTO public.match_pool_camps (pool_id, code, label, result_code, display_order)
  VALUES
    (v_pool_cancelled, 'home', 'Home', 'H', 1),
    (v_pool_cancelled, 'away', 'Away', 'A', 2);

  SELECT id INTO v_camp FROM public.match_pool_camps WHERE pool_id = v_pool_cancelled AND result_code = 'H';
  PERFORM set_config('request.jwt.claim.sub', v_loser::text, true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_loser, 'role', 'authenticated')::text, true);
  PERFORM public.join_match_pool(v_pool_cancelled, v_camp, 15, NULL);

  UPDATE public.matches
  SET match_status = 'cancelled',
      status = 'cancelled',
      result_code = NULL
  WHERE id = 'settlement_cancelled_match';

  PERFORM set_config('request.jwt.claim.role', 'service_role', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('role', 'service_role')::text, true);
  v_result := public.settle_match_pool(v_pool_cancelled);
  IF v_result ->> 'status' <> 'refunded' OR v_result ->> 'reason' <> 'match_cancelled' THEN
    RAISE EXCEPTION 'Expected cancelled-match refund, got %', v_result;
  END IF;

  -- Postponed match: active entries are refunded and the pool is cancelled.
  INSERT INTO public.match_pools (id, match_id, venue_id, title, creator_user_id, entry_fee_fet, stake_min_fet, stake_max_fet)
  VALUES (v_pool_postponed, 'settlement_postponed_match', v_venue_id, 'Postponed hold pool', v_creator, 0, 1, 100);

  INSERT INTO public.match_pool_camps (pool_id, code, label, result_code, display_order)
  VALUES
    (v_pool_postponed, 'home', 'Home', 'H', 1),
    (v_pool_postponed, 'away', 'Away', 'A', 2);

  SELECT id INTO v_camp FROM public.match_pool_camps WHERE pool_id = v_pool_postponed AND result_code = 'H';
  PERFORM set_config('request.jwt.claim.sub', v_winner::text, true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_winner, 'role', 'authenticated')::text, true);
  PERFORM public.join_match_pool(v_pool_postponed, v_camp, 5, NULL);

  UPDATE public.matches
  SET match_status = 'postponed',
      status = 'postponed'
  WHERE id = 'settlement_postponed_match';

  PERFORM set_config('request.jwt.claim.role', 'service_role', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('role', 'service_role')::text, true);
  v_result := public.settle_match_pool(v_pool_postponed);
  IF v_result ->> 'status' <> 'refunded' OR v_result ->> 'reason' <> 'match_postponed' THEN
    RAISE EXCEPTION 'Expected postponed pool to be refunded, got %', v_result;
  END IF;

  SELECT count(*) INTO v_tx_count
  FROM public.match_pool_settlements
  WHERE pool_id = v_pool_postponed
    AND status = 'completed';

  IF v_tx_count <> 1 THEN
    RAISE EXCEPTION 'Expected one completed postponed settlement run, got %', v_tx_count;
  END IF;

  -- Failed run is recorded, then retry reuses the settlement row idempotently.
  INSERT INTO public.match_pools (id, match_id, venue_id, title, creator_user_id, entry_fee_fet, stake_min_fet, stake_max_fet)
  VALUES (v_pool_retry, 'settlement_retry_match', v_venue_id, 'Retry settlement pool', v_creator, 0, 1, 100);

  INSERT INTO public.match_pool_camps (pool_id, code, label, result_code, display_order)
  VALUES (v_pool_retry, 'home', 'Home', 'H', 1);

  SELECT id INTO v_camp FROM public.match_pool_camps WHERE pool_id = v_pool_retry AND result_code = 'H';
  PERFORM set_config('request.jwt.claim.sub', v_extra::text, true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_extra, 'role', 'authenticated')::text, true);
  PERFORM public.join_match_pool(v_pool_retry, v_camp, 10, NULL);

  UPDATE public.matches
  SET match_status = 'finished',
      status = 'final',
      home_goals = 0,
      away_goals = 1,
      result_code = 'A',
      winner_camp = 'away'
  WHERE id = 'settlement_retry_match';

  PERFORM set_config('request.jwt.claim.role', 'service_role', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('role', 'service_role')::text, true);
  BEGIN
    v_result := public.settle_match_pool(v_pool_retry);
    RAISE EXCEPTION 'Expected missing result camp settlement to fail, got %', v_result;
  EXCEPTION
    WHEN others THEN
      IF position('Result camp not found' IN SQLERRM) = 0 THEN
        RAISE;
      END IF;
  END;

  INSERT INTO public.match_pool_camps (pool_id, code, label, result_code, display_order)
  VALUES (v_pool_retry, 'away', 'Away', 'A', 2);

  PERFORM set_config('request.jwt.claim.role', 'service_role', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('role', 'service_role')::text, true);
  v_result := public.settle_match_pool(v_pool_retry);
  IF v_result ->> 'status' <> 'refunded' THEN
    RAISE EXCEPTION 'Expected retry to complete as no-winner refund, got %', v_result;
  END IF;

  SELECT count(*) INTO v_tx_count
  FROM public.match_pool_settlements
  WHERE pool_id = v_pool_retry;

  IF v_tx_count <> 1 THEN
    RAISE EXCEPTION 'Retry should reuse one settlement row, got %', v_tx_count;
  END IF;
END;
$$;

ROLLBACK;

\echo 'Automated pool settlement engine checks passed'
