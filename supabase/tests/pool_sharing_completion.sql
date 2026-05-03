\pset tuples_only on
\pset pager off

\echo 'Verifying pool sharing completion...'

DO $$
DECLARE
  v_pool_id uuid := extensions.gen_random_uuid();
  v_venue_id uuid := extensions.gen_random_uuid();
  v_suffix text := replace(v_pool_id::text, '-', '');
  v_comp_id text := 'share_test_comp_' || left(v_suffix, 12);
  v_home_id text := 'share_home_' || left(v_suffix, 12);
  v_away_id text := 'share_away_' || left(v_suffix, 12);
  v_match_id text := 'share_test_match_' || left(v_suffix, 12);
  v_event_count bigint;
  v_share jsonb;
  v_join_def text;
  v_share_def text;
  v_card_def text;
BEGIN
  IF to_regclass('public.match_pool_share_events') IS NULL THEN
    RAISE EXCEPTION 'match_pool_share_events table is missing';
  END IF;

  IF to_regprocedure('public.get_public_pool_share(text,text,text)') IS NULL
     OR to_regprocedure('public.get_match_pool_social_card_payload(uuid)') IS NULL
     OR to_regprocedure('public.join_match_pool(uuid,uuid,bigint,text)') IS NULL THEN
    RAISE EXCEPTION 'Required pool sharing functions are missing';
  END IF;

  v_share_def := pg_get_functiondef('public.get_public_pool_share(text,text,text)'::regprocedure);
  IF v_share_def NOT ILIKE '%match_pool_share_events%'
     OR v_share_def NOT ILIKE '%curated_active_matches%'
     OR v_share_def NOT ILIKE '%deep_link_url%' THEN
    RAISE EXCEPTION 'get_public_pool_share must resolve curated match context, deep links, and safe tracking';
  END IF;

  v_card_def := pg_get_functiondef('public.get_match_pool_social_card_payload(uuid)'::regprocedure);
  IF v_card_def NOT ILIKE '%curated_active_matches%'
     OR v_card_def NOT ILIKE '%social_card%'
     OR v_card_def NOT ILIKE '%total_members%' THEN
    RAISE EXCEPTION 'social-card payload must use curated match context and key pool stats';
  END IF;

  v_join_def := pg_get_functiondef('public.join_match_pool(uuid,uuid,bigint,text)'::regprocedure);
  IF v_join_def NOT ILIKE '%min_qualified_stake%'
     OR v_join_def NOT ILIKE '%v_invite.inviter_user_id = v_pool.creator_user_id%'
     OR v_join_def NOT ILIKE '%creator_reward:%'
     OR v_join_def NOT ILIKE '%p_pool_id::text%'
     OR v_join_def NOT ILIKE '%v_user_id::text%'
     OR v_join_def NOT ILIKE '%self_invite%' THEN
    RAISE EXCEPTION 'join_match_pool must enforce qualified creator rewards and self-reward protection';
  END IF;

  INSERT INTO public.competitions (id, name, short_name, country, data_source, country_or_region, competition_type, is_active)
  VALUES (v_comp_id, 'Share Test League', 'STL', 'Global', 'test', 'Global', 'league', true)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.teams (id, name, short_name, country)
  VALUES
    (v_home_id, 'Share Home', 'HOME', 'Test'),
    (v_away_id, 'Share Away', 'AWAY', 'Test')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.venues (id, name, country_code, venue_type, currency_code)
  VALUES (v_venue_id, 'Share Test Bar', 'MT', 'bar', 'EUR');

  INSERT INTO public.matches (id, competition_id, match_date, match_status, home_team_id, away_team_id)
  VALUES (
    v_match_id,
    v_comp_id,
    timezone('utc', now()) + interval '1 day',
    'scheduled',
    v_home_id,
    v_away_id
  )
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.match_pools (id, match_id, venue_id, title, entry_fee_fet, stake_min_fet, stake_max_fet)
  VALUES (v_pool_id, v_match_id, v_venue_id, 'Share test pool', 10, 1, 100);

  v_share := public.get_public_pool_share(
    (SELECT share_slug FROM public.match_pools WHERE id = v_pool_id),
    NULL,
    'social_share'
  );

  IF v_share #>> '{pool,id}' IS DISTINCT FROM v_pool_id::text THEN
    RAISE EXCEPTION 'Share resolver returned the wrong pool: %', v_share;
  END IF;

  SELECT count(*)
  INTO v_event_count
  FROM public.match_pool_share_events
  WHERE pool_id = v_pool_id
    AND source = 'social_share';

  IF v_event_count <> 1 THEN
    RAISE EXCEPTION 'Expected one share tracking event, got %', v_event_count;
  END IF;
END;
$$;

\echo 'Pool sharing completion verified'
