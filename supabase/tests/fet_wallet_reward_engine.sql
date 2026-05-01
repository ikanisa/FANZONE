\pset tuples_only on
\pset pager off

\echo 'Verifying clean FET wallet and reward engine...'

BEGIN;

DO $$
DECLARE
  v_user_creator uuid := extensions.gen_random_uuid();
  v_user_winner uuid := extensions.gen_random_uuid();
  v_user_loser uuid := extensions.gen_random_uuid();
  v_venue_id uuid := extensions.gen_random_uuid();
  v_table_id uuid := extensions.gen_random_uuid();
  v_order_id uuid := extensions.gen_random_uuid();
  v_pool_id uuid := extensions.gen_random_uuid();
  v_camp_home uuid := extensions.gen_random_uuid();
  v_camp_away uuid := extensions.gen_random_uuid();
  v_invite_code text := 'fettestinvite';
  v_wallet jsonb;
  v_settlement jsonb;
  v_tx_count integer;
BEGIN
  INSERT INTO auth.users (id, aud, role, email, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  VALUES
    (v_user_creator, 'authenticated', 'authenticated', 'creator@example.test', now(), now(), '{}'::jsonb, '{}'::jsonb),
    (v_user_winner, 'authenticated', 'authenticated', 'winner@example.test', now(), now(), '{}'::jsonb, '{}'::jsonb),
    (v_user_loser, 'authenticated', 'authenticated', 'loser@example.test', now(), now(), '{}'::jsonb, '{}'::jsonb);

  INSERT INTO public.profiles (id, user_id, fan_id, display_name)
  VALUES
    (v_user_creator, v_user_creator, '910001', 'Creator'),
    (v_user_winner, v_user_winner, '910002', 'Winner'),
    (v_user_loser, v_user_loser, '910003', 'Loser');

  INSERT INTO public.app_config_remote (key, value, description)
  VALUES
    ('welcome_credit_fet', '25'::jsonb, 'test welcome credit'),
    ('fet_per_eur', '100'::jsonb, 'test FET peg'),
    ('order_reward_percent_default', '10'::jsonb, 'test reward percent'),
    ('pool_creator_reward_fet_default', '1'::jsonb, 'test creator reward'),
    ('min_qualified_stake_fet', '1'::jsonb, 'test qualified stake')
  ON CONFLICT (key) DO UPDATE
  SET value = EXCLUDED.value;

  PERFORM set_config('request.jwt.claim.sub', v_user_creator::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_user_creator, 'role', 'authenticated')::text, true);

  -- Welcome credit once only.
  PERFORM public.credit_welcome_fet(v_user_creator);
  PERFORM public.credit_welcome_fet(v_user_creator);

  SELECT count(*) INTO v_tx_count
  FROM public.fet_wallet_transactions
  WHERE user_id = v_user_creator
    AND transaction_type = 'welcome_credit';

  IF v_tx_count <> 1 THEN
    RAISE EXCEPTION 'Expected one welcome_credit row, got %', v_tx_count;
  END IF;

  v_wallet := public.get_wallet_balance(v_user_creator);
  IF (v_wallet ->> 'available_fet')::bigint <> 25 THEN
    RAISE EXCEPTION 'Expected 25 available welcome FET, got %', v_wallet;
  END IF;

  -- Order earning after a valid paid order.
  INSERT INTO public.venues (
    id,
    name,
    country_code,
    venue_type,
    currency_code,
    features_json
  )
  VALUES (
    v_venue_id,
    'Wallet Test Bar',
    'MT',
    'bar',
    'EUR',
    jsonb_build_object('fet_reward_percent', 10, 'fet_reward_trigger', 'paid')
  );

  INSERT INTO public.tables (id, venue_id, table_number)
  VALUES (v_table_id, v_venue_id, 'T1');

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
    total_amount
  )
  VALUES (
    v_order_id,
    v_venue_id,
    v_table_id,
    v_user_creator,
    'received',
    'cash',
    'paid',
    'EUR',
    20,
    20
  );

  PERFORM public.credit_fet_for_order(v_order_id);

  SELECT count(*) INTO v_tx_count
  FROM public.fet_wallet_transactions
  WHERE user_id = v_user_creator
    AND transaction_type = 'order_earn'
    AND order_id = v_order_id;

  IF v_tx_count <> 1 THEN
    RAISE EXCEPTION 'Expected one order_earn row, got %', v_tx_count;
  END IF;

  -- Insufficient balance reports a clear error.
  BEGIN
    PERFORM public.wallet_post_transaction(
      p_user_id => v_user_loser,
      p_transaction_type => 'pool_stake',
      p_direction => 'debit',
      p_amount_fet => 999,
      p_balance_bucket => 'available',
      p_idempotency_key => 'insufficient-test'
    );
    RAISE EXCEPTION 'Expected insufficient FET debit to fail';
  EXCEPTION
    WHEN others THEN
      IF position('Insufficient FET balance' IN SQLERRM) = 0 THEN
        RAISE;
      END IF;
  END;

  -- Pool stake debit, creator reward, settlement credit, and duplicate guard.
  PERFORM public.wallet_post_transaction(v_user_winner, 'admin_adjustment', 'credit', 50, 'available', 'seed-winner-fet');
  PERFORM public.wallet_post_transaction(v_user_loser, 'admin_adjustment', 'credit', 50, 'available', 'seed-loser-fet');

  INSERT INTO public.competitions (
    id,
    name,
    short_name,
    country,
    data_source,
    country_or_region,
    competition_type
  )
  VALUES ('fet_test_comp', 'FET Test Competition', 'FTC', 'MT', 'test', 'MT', 'league')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.teams (id, name, short_name, country, country_code)
  VALUES
    ('home', 'FET Test Home', 'HOME', 'Malta', 'MT'),
    ('away', 'FET Test Away', 'AWAY', 'Malta', 'MT')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.matches (
    id,
    competition_id,
    match_date,
    match_status,
    home_team_id,
    away_team_id
  )
  VALUES (
    'fet_test_match',
    'fet_test_comp',
    timezone('utc', now()) + interval '1 day',
    'scheduled',
    'home',
    'away'
  );

  INSERT INTO public.match_pools (
    id,
    match_id,
    title,
    creator_user_id,
    entry_fee_fet,
    stake_min_fet,
    stake_max_fet,
    creator_reward_fet
  )
  VALUES (
    v_pool_id,
    'fet_test_match',
    'FET test pool',
    v_user_creator,
    10,
    1,
    100,
    1
  );

  INSERT INTO public.match_pool_camps (id, pool_id, code, label, result_code, display_order)
  VALUES
    (v_camp_home, v_pool_id, 'home', 'Home', 'H', 1),
    (v_camp_away, v_pool_id, 'away', 'Away', 'A', 2);

  INSERT INTO public.match_pool_invites (pool_id, inviter_user_id, invite_code)
  VALUES (v_pool_id, v_user_creator, v_invite_code);

  PERFORM set_config('request.jwt.claim.sub', v_user_winner::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_user_winner, 'role', 'authenticated')::text, true);
  PERFORM public.join_match_pool(v_pool_id, v_camp_home, 10, v_invite_code);

  v_wallet := public.get_wallet_balance(v_user_winner);
  IF (v_wallet ->> 'available_fet')::bigint <> 40 OR (v_wallet ->> 'staked_fet')::bigint <> 10 THEN
    RAISE EXCEPTION 'Pool stake did not move available to staked as expected: %', v_wallet;
  END IF;

  SELECT count(*) INTO v_tx_count
  FROM public.fet_wallet_transactions
  WHERE user_id = v_user_creator
    AND transaction_type = 'creator_reward'
    AND pool_id = v_pool_id;

  IF v_tx_count <> 1 THEN
    RAISE EXCEPTION 'Expected one creator_reward row, got %', v_tx_count;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_user_loser::text, true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_user_loser, 'role', 'authenticated')::text, true);
  PERFORM public.join_match_pool(v_pool_id, v_camp_away, 10, NULL);

  UPDATE public.matches
  SET match_status = 'finished',
      status = 'final',
      home_goals = 1,
      away_goals = 0,
      home_score = 1,
      away_score = 0,
      result_code = 'H',
      winner_camp = 'home'
  WHERE id = 'fet_test_match';

  v_settlement := public.settle_match_pool(v_pool_id);
  IF v_settlement ->> 'status' <> 'settled' THEN
    RAISE EXCEPTION 'Expected settled pool, got %', v_settlement;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_user_winner::text, true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_user_winner, 'role', 'authenticated')::text, true);

  v_wallet := public.get_wallet_balance(v_user_winner);
  IF (v_wallet ->> 'available_fet')::bigint <> 60 OR (v_wallet ->> 'staked_fet')::bigint <> 0 THEN
    RAISE EXCEPTION 'Pool settlement did not credit winner as expected: %', v_wallet;
  END IF;

  SELECT count(*) INTO v_tx_count
  FROM public.fet_wallet_transactions
  WHERE user_id = v_user_winner
    AND transaction_type = 'pool_win'
    AND balance_bucket = 'available'
    AND pool_id = v_pool_id;

  IF v_tx_count <> 1 THEN
    RAISE EXCEPTION 'Expected one pool_win available credit, got %', v_tx_count;
  END IF;

  v_settlement := public.settle_match_pool(v_pool_id);
  IF v_settlement ->> 'status' <> 'already_settled' THEN
    RAISE EXCEPTION 'Duplicate settlement should be prevented, got %', v_settlement;
  END IF;

  SELECT count(*) INTO v_tx_count
  FROM public.fet_wallet_transactions
  WHERE user_id = v_user_winner
    AND transaction_type = 'pool_win'
    AND balance_bucket = 'available'
    AND pool_id = v_pool_id;

  IF v_tx_count <> 1 THEN
    RAISE EXCEPTION 'Duplicate settlement created extra pool_win rows: %', v_tx_count;
  END IF;
END;
$$;

ROLLBACK;

\echo 'FET wallet reward engine checks passed'
