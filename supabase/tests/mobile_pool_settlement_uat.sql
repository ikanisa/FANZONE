\pset tuples_only on
\pset pager off

\echo 'Verifying mobile pool settlement UAT contract...'

DO $$
DECLARE
  v_manager uuid := extensions.gen_random_uuid();
  v_eligible uuid := extensions.gen_random_uuid();
  v_ineligible uuid := extensions.gen_random_uuid();
  v_loser uuid := extensions.gen_random_uuid();
  v_venue uuid := extensions.gen_random_uuid();
  v_table uuid := extensions.gen_random_uuid();
  v_order uuid := extensions.gen_random_uuid();
  v_pool uuid := extensions.gen_random_uuid();
  v_home_camp uuid;
  v_away_camp uuid;
  v_suffix text := lower(substr(replace(v_pool::text, '-', ''), 1, 10));
  v_competition_id text := 'mob_settle_uat_comp_' || v_suffix;
  v_home_team_id text := 'mob_settle_home_' || v_suffix;
  v_away_team_id text := 'mob_settle_away_' || v_suffix;
  v_match_id text := 'mob-settle-uat-' || v_suffix;
  v_start_at timestamptz := timezone('utc', now()) + interval '1 hour';
  v_settlement jsonb;
  v_settlement_id uuid;
  v_eligible_entry_id uuid;
  v_ineligible_entry_id uuid;
  v_loser_entry_id uuid;
  v_eligible_entry public.match_pool_entries%ROWTYPE;
  v_ineligible_entry public.match_pool_entries%ROWTYPE;
  v_loser_entry public.match_pool_entries%ROWTYPE;
  v_eligible_before jsonb;
  v_eligible_after jsonb;
  v_ineligible_before jsonb;
  v_ineligible_after jsonb;
  v_loser_before jsonb;
  v_loser_after jsonb;
  v_eligible_available_before bigint;
  v_eligible_available_after bigint;
  v_ineligible_available_before bigint;
  v_ineligible_available_after bigint;
  v_eligible_win_tx uuid;
  v_ineligible_win_count bigint;
  v_stake_release_count bigint;
  v_order_code text := 'MOBSET' || upper(substr(replace(v_order::text, '-', ''), 1, 6));
BEGIN
  INSERT INTO auth.users (
    id,
    aud,
    role,
    email,
    email_confirmed_at,
    created_at,
    updated_at,
    raw_app_meta_data,
    raw_user_meta_data
  )
  VALUES
    (
      v_manager,
      'authenticated',
      'authenticated',
      'mob-settle-manager-' || v_suffix || '@fanzone.test',
      timezone('utc', now()),
      timezone('utc', now()),
      timezone('utc', now()),
      '{}'::jsonb,
      '{}'::jsonb
    ),
    (
      v_eligible,
      'authenticated',
      'authenticated',
      'mob-settle-eligible-' || v_suffix || '@fanzone.test',
      timezone('utc', now()),
      timezone('utc', now()),
      timezone('utc', now()),
      '{}'::jsonb,
      '{}'::jsonb
    ),
    (
      v_ineligible,
      'authenticated',
      'authenticated',
      'mob-settle-ineligible-' || v_suffix || '@fanzone.test',
      timezone('utc', now()),
      timezone('utc', now()),
      timezone('utc', now()),
      '{}'::jsonb,
      '{}'::jsonb
    ),
    (
      v_loser,
      'authenticated',
      'authenticated',
      'mob-settle-loser-' || v_suffix || '@fanzone.test',
      timezone('utc', now()),
      timezone('utc', now()),
      timezone('utc', now()),
      '{}'::jsonb,
      '{}'::jsonb
    );

  UPDATE public.profiles
  SET display_name = CASE
        WHEN id = v_manager THEN 'Settle Manager'
        WHEN id = v_eligible THEN 'Settle Eligible'
        WHEN id = v_ineligible THEN 'Settle Ineligible'
        ELSE 'Settle Loser'
      END,
      updated_at = timezone('utc', now())
  WHERE id IN (v_manager, v_eligible, v_ineligible, v_loser);

  INSERT INTO public.competitions (
    id,
    name,
    short_name,
    country,
    data_source,
    country_or_region,
    competition_type
  )
  VALUES (
    v_competition_id,
    'Mobile Settlement UAT Competition',
    'MSU',
    'MT',
    'uat',
    'MT',
    'league'
  );

  INSERT INTO public.teams (id, name, short_name, country, country_code)
  VALUES
    (v_home_team_id, 'Mobile Settlement Home', 'MSH', 'Malta', 'MT'),
    (v_away_team_id, 'Mobile Settlement Away', 'MSA', 'Malta', 'MT');

  INSERT INTO public.venues (
    id,
    owner_id,
    name,
    slug,
    country_code,
    venue_type,
    currency_code,
    is_active,
    status,
    features_json
  )
  VALUES (
    v_venue,
    v_manager,
    'Mobile Settlement UAT Bar',
    'mobile-settlement-uat-' || v_suffix,
    'MT',
    'bar',
    'EUR',
    true,
    'active',
    jsonb_build_object('pool_settlement_uat', true)
  );

  INSERT INTO public.venue_users (venue_id, user_id, role, is_active)
  VALUES (v_venue, v_manager, 'manager', true)
  ON CONFLICT (venue_id, user_id) DO UPDATE
  SET role = EXCLUDED.role,
      is_active = true,
      updated_at = timezone('utc', now());

  INSERT INTO public.tables (id, venue_id, table_number)
  VALUES (v_table, v_venue, 'UAT-SETTLE-1');

  INSERT INTO public.orders (
    id,
    venue_id,
    table_id,
    user_id,
    order_code,
    status,
    payment_method,
    payment_status,
    currency_code,
    subtotal_amount,
    tax_amount,
    tip_amount,
    total_amount,
    created_at
  )
  VALUES (
    v_order,
    v_venue,
    v_table,
    v_eligible,
    v_order_code,
    'served',
    'cash',
    'paid',
    'EUR',
    12,
    0,
    0,
    12,
    timezone('utc', now())
  );

  INSERT INTO public.matches (
    id,
    competition_id,
    match_date,
    starts_at,
    match_status,
    status,
    home_team_id,
    away_team_id,
    source_name,
    is_curated
  )
  VALUES (
    v_match_id,
    v_competition_id,
    v_start_at,
    v_start_at,
    'scheduled',
    'scheduled',
    v_home_team_id,
    v_away_team_id,
    'mobile_pool_settlement_uat',
    true
  );

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
    expires_at,
    curated_by
  )
  VALUES (
    v_match_id,
    'MT',
    v_venue,
    100,
    true,
    true,
    'Mobile settlement UAT',
    jsonb_build_object('uat_fixture', true, 'flow_id', 'MOB-SETTLEMENT-001'),
    timezone('utc', now()) - interval '1 minute',
    v_start_at + interval '4 hours',
    v_manager
  );

  INSERT INTO public.match_pools (
    id,
    match_id,
    scope,
    country_code,
    venue_id,
    creator_user_id,
    title,
    status,
    is_official,
    entry_fee_fet,
    stake_min_fet,
    stake_max_fet,
    min_participants,
    creator_reward_fet,
    share_slug,
    metadata,
    rules_json
  )
  VALUES (
    v_pool,
    v_match_id,
    'venue',
    'MT',
    v_venue,
    v_manager,
    'Mobile settlement UAT pool',
    'open',
    true,
    25,
    25,
    25,
    2,
    0,
    'mobsettle' || v_suffix,
    jsonb_build_object('uat_fixture', true, 'flow_id', 'MOB-SETTLEMENT-001'),
    jsonb_build_object('settlement_requires_paid_order', true, 'eligibility_window_minutes', 120)
  );

  INSERT INTO public.match_pool_camps (
    pool_id,
    code,
    camp_key,
    label,
    result_code,
    display_order,
    team_id
  )
  VALUES
    (v_pool, 'home', 'home', 'Home win', 'H', 1, v_home_team_id),
    (v_pool, 'away', 'away', 'Away win', 'A', 2, v_away_team_id);

  SELECT id
  INTO v_home_camp
  FROM public.match_pool_camps
  WHERE pool_id = v_pool
    AND result_code = 'H';

  SELECT id
  INTO v_away_camp
  FROM public.match_pool_camps
  WHERE pool_id = v_pool
    AND result_code = 'A';

  PERFORM public.wallet_post_transaction(
    p_user_id => v_eligible,
    p_transaction_type => 'admin_adjustment',
    p_direction => 'credit',
    p_amount_fet => 200,
    p_balance_bucket => 'available',
    p_idempotency_key => 'mob-settle-seed-eligible:' || v_pool::text,
    p_reference_type => 'mobile_pool_settlement_uat',
    p_reference_id => v_pool::text,
    p_title => 'Mobile settlement UAT seed'
  );

  PERFORM public.wallet_post_transaction(
    p_user_id => v_ineligible,
    p_transaction_type => 'admin_adjustment',
    p_direction => 'credit',
    p_amount_fet => 200,
    p_balance_bucket => 'available',
    p_idempotency_key => 'mob-settle-seed-ineligible:' || v_pool::text,
    p_reference_type => 'mobile_pool_settlement_uat',
    p_reference_id => v_pool::text,
    p_title => 'Mobile settlement UAT seed'
  );

  PERFORM public.wallet_post_transaction(
    p_user_id => v_loser,
    p_transaction_type => 'admin_adjustment',
    p_direction => 'credit',
    p_amount_fet => 200,
    p_balance_bucket => 'available',
    p_idempotency_key => 'mob-settle-seed-loser:' || v_pool::text,
    p_reference_type => 'mobile_pool_settlement_uat',
    p_reference_id => v_pool::text,
    p_title => 'Mobile settlement UAT seed'
  );

  IF NOT public.user_has_qualifying_order(v_eligible, v_venue, v_start_at) THEN
    RAISE EXCEPTION 'Eligible winner does not satisfy qualifying-order rule';
  END IF;

  IF public.user_has_qualifying_order(v_ineligible, v_venue, v_start_at) THEN
    RAISE EXCEPTION 'Ineligible winner unexpectedly satisfies qualifying-order rule';
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_eligible::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_eligible, 'role', 'authenticated')::text,
    true
  );
  PERFORM public.join_match_pool(v_pool, v_home_camp, 25, NULL);

  PERFORM set_config('request.jwt.claim.sub', v_ineligible::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_ineligible, 'role', 'authenticated')::text,
    true
  );
  PERFORM public.join_match_pool(v_pool, v_home_camp, 25, NULL);

  PERFORM set_config('request.jwt.claim.sub', v_loser::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_loser, 'role', 'authenticated')::text,
    true
  );
  PERFORM public.join_match_pool(v_pool, v_away_camp, 25, NULL);

  SELECT id INTO STRICT v_eligible_entry_id
  FROM public.match_pool_entries
  WHERE pool_id = v_pool
    AND user_id = v_eligible;

  SELECT id INTO STRICT v_ineligible_entry_id
  FROM public.match_pool_entries
  WHERE pool_id = v_pool
    AND user_id = v_ineligible;

  SELECT id INTO STRICT v_loser_entry_id
  FROM public.match_pool_entries
  WHERE pool_id = v_pool
    AND user_id = v_loser;

  PERFORM set_config('request.jwt.claim.sub', v_eligible::text, true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_eligible, 'role', 'authenticated')::text,
    true
  );
  v_eligible_before := public.get_wallet_balance(v_eligible);
  v_eligible_available_before := (v_eligible_before ->> 'available_fet')::bigint;

  PERFORM set_config('request.jwt.claim.sub', v_ineligible::text, true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_ineligible, 'role', 'authenticated')::text,
    true
  );
  v_ineligible_before := public.get_wallet_balance(v_ineligible);
  v_ineligible_available_before := (v_ineligible_before ->> 'available_fet')::bigint;

  PERFORM set_config('request.jwt.claim.sub', v_loser::text, true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_loser, 'role', 'authenticated')::text,
    true
  );
  v_loser_before := public.get_wallet_balance(v_loser);

  UPDATE public.matches
  SET match_status = 'finished',
      status = 'final',
      home_goals = 2,
      away_goals = 1,
      home_score = 2,
      away_score = 1,
      result_code = 'H',
      winner_camp = 'home',
      updated_at = timezone('utc', now())
  WHERE id = v_match_id;

  PERFORM set_config('request.jwt.claim.sub', v_manager::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_manager, 'role', 'authenticated')::text,
    true
  );

  v_settlement := public.settle_match_pool(v_pool);

  IF v_settlement ->> 'status' <> 'settled' THEN
    RAISE EXCEPTION 'Expected settled pool, got %', v_settlement;
  END IF;

  v_settlement_id := (v_settlement ->> 'settlement_id')::uuid;

  SELECT *
  INTO STRICT v_eligible_entry
  FROM public.match_pool_entries
  WHERE id = v_eligible_entry_id;

  SELECT *
  INTO STRICT v_ineligible_entry
  FROM public.match_pool_entries
  WHERE id = v_ineligible_entry_id;

  SELECT *
  INTO STRICT v_loser_entry
  FROM public.match_pool_entries
  WHERE id = v_loser_entry_id;

  IF v_eligible_entry.status::text <> 'won' OR v_eligible_entry.payout_fet <= 0 THEN
    RAISE EXCEPTION 'Eligible winner entry was not paid correctly: %', row_to_json(v_eligible_entry);
  END IF;

  IF v_ineligible_entry.status::text <> 'won'
     OR v_ineligible_entry.payout_fet <> 0
     OR v_ineligible_entry.metadata ->> 'eligibility_status' <> 'won_ineligible_no_qualifying_order' THEN
    RAISE EXCEPTION 'Ineligible winner entry was not marked no-payout correctly: %', row_to_json(v_ineligible_entry);
  END IF;

  IF v_loser_entry.status::text <> 'lost' OR v_loser_entry.payout_fet <> 0 THEN
    RAISE EXCEPTION 'Losing entry was not marked lost correctly: %', row_to_json(v_loser_entry);
  END IF;

  SELECT id
  INTO v_eligible_win_tx
  FROM public.fet_wallet_transactions
  WHERE user_id = v_eligible
    AND pool_id = v_pool
    AND entry_id = v_eligible_entry_id
    AND settlement_id = v_settlement_id
    AND transaction_type = 'pool_win'
    AND direction = 'credit'
    AND amount_fet = v_eligible_entry.payout_fet
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_eligible_win_tx IS NULL THEN
    RAISE EXCEPTION 'Missing eligible winner pool_win wallet transaction';
  END IF;

  SELECT count(*)
  INTO v_ineligible_win_count
  FROM public.fet_wallet_transactions
  WHERE user_id = v_ineligible
    AND pool_id = v_pool
    AND entry_id = v_ineligible_entry_id
    AND settlement_id = v_settlement_id
    AND transaction_type = 'pool_win';

  IF v_ineligible_win_count <> 0 THEN
    RAISE EXCEPTION 'Ineligible winner received % pool_win transactions', v_ineligible_win_count;
  END IF;

  SELECT count(*)
  INTO v_stake_release_count
  FROM public.fet_wallet_transactions
  WHERE pool_id = v_pool
    AND settlement_id = v_settlement_id
    AND transaction_type = 'pool_stake_release'
    AND direction = 'debit'
    AND balance_bucket = 'staked';

  IF v_stake_release_count <> 3 THEN
    RAISE EXCEPTION 'Expected three stake-release ledger rows, got %', v_stake_release_count;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_eligible::text, true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_eligible, 'role', 'authenticated')::text,
    true
  );
  v_eligible_after := public.get_wallet_balance(v_eligible);
  v_eligible_available_after := (v_eligible_after ->> 'available_fet')::bigint;

  PERFORM set_config('request.jwt.claim.sub', v_ineligible::text, true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_ineligible, 'role', 'authenticated')::text,
    true
  );
  v_ineligible_after := public.get_wallet_balance(v_ineligible);
  v_ineligible_available_after := (v_ineligible_after ->> 'available_fet')::bigint;

  PERFORM set_config('request.jwt.claim.sub', v_loser::text, true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_loser, 'role', 'authenticated')::text,
    true
  );
  v_loser_after := public.get_wallet_balance(v_loser);

  IF v_eligible_available_after <> v_eligible_available_before + v_eligible_entry.payout_fet THEN
    RAISE EXCEPTION 'Eligible wallet movement mismatch, before %, after %, payout %',
      v_eligible_before,
      v_eligible_after,
      v_eligible_entry.payout_fet;
  END IF;

  IF v_ineligible_available_after <> v_ineligible_available_before THEN
    RAISE EXCEPTION 'Ineligible wallet received an available payout, before %, after %',
      v_ineligible_before,
      v_ineligible_after;
  END IF;

  PERFORM set_config('fanzone_uat.pool_id', v_pool::text, false);
  PERFORM set_config('fanzone_uat.match_id', v_match_id, false);
  PERFORM set_config('fanzone_uat.settlement_id', v_settlement_id::text, false);
  PERFORM set_config('fanzone_uat.eligible_user_id', v_eligible::text, false);
  PERFORM set_config('fanzone_uat.ineligible_user_id', v_ineligible::text, false);
  PERFORM set_config('fanzone_uat.loser_user_id', v_loser::text, false);
  PERFORM set_config('fanzone_uat.eligible_entry_id', v_eligible_entry_id::text, false);
  PERFORM set_config('fanzone_uat.ineligible_entry_id', v_ineligible_entry_id::text, false);
  PERFORM set_config('fanzone_uat.loser_entry_id', v_loser_entry_id::text, false);
  PERFORM set_config('fanzone_uat.eligible_win_tx_id', v_eligible_win_tx::text, false);
  PERFORM set_config('fanzone_uat.eligible_payout_fet', v_eligible_entry.payout_fet::text, false);
  PERFORM set_config('fanzone_uat.ineligible_payout_fet', v_ineligible_entry.payout_fet::text, false);
  PERFORM set_config('fanzone_uat.stake_release_count', v_stake_release_count::text, false);
  PERFORM set_config('fanzone_uat.eligible_wallet_before', v_eligible_before::text, false);
  PERFORM set_config('fanzone_uat.eligible_wallet_after', v_eligible_after::text, false);
  PERFORM set_config('fanzone_uat.ineligible_wallet_before', v_ineligible_before::text, false);
  PERFORM set_config('fanzone_uat.ineligible_wallet_after', v_ineligible_after::text, false);
  PERFORM set_config('fanzone_uat.loser_wallet_before', v_loser_before::text, false);
  PERFORM set_config('fanzone_uat.loser_wallet_after', v_loser_after::text, false);
END $$;

SELECT
  'MOB-SETTLEMENT-001' AS flow_id,
  current_setting('fanzone_uat.pool_id', true) AS pool_id,
  current_setting('fanzone_uat.match_id', true) AS match_id,
  current_setting('fanzone_uat.settlement_id', true) AS settlement_id,
  current_setting('fanzone_uat.eligible_user_id', true) AS eligible_user_id,
  current_setting('fanzone_uat.ineligible_user_id', true) AS ineligible_user_id,
  current_setting('fanzone_uat.loser_user_id', true) AS loser_user_id,
  current_setting('fanzone_uat.eligible_entry_id', true) AS eligible_entry_id,
  current_setting('fanzone_uat.ineligible_entry_id', true) AS ineligible_entry_id,
  current_setting('fanzone_uat.loser_entry_id', true) AS loser_entry_id,
  current_setting('fanzone_uat.eligible_win_tx_id', true) AS eligible_win_tx_id,
  current_setting('fanzone_uat.eligible_payout_fet', true) AS eligible_payout_fet,
  current_setting('fanzone_uat.ineligible_payout_fet', true) AS ineligible_payout_fet,
  current_setting('fanzone_uat.stake_release_count', true) AS stake_release_count,
  current_setting('fanzone_uat.eligible_wallet_before', true) AS eligible_wallet_before,
  current_setting('fanzone_uat.eligible_wallet_after', true) AS eligible_wallet_after,
  current_setting('fanzone_uat.ineligible_wallet_before', true) AS ineligible_wallet_before,
  current_setting('fanzone_uat.ineligible_wallet_after', true) AS ineligible_wallet_after,
  current_setting('fanzone_uat.loser_wallet_before', true) AS loser_wallet_before,
  current_setting('fanzone_uat.loser_wallet_after', true) AS loser_wallet_after;

\echo 'Mobile pool settlement UAT contract verified'
