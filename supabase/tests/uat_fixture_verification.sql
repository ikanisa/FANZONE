SELECT 'Verifying authenticated UAT fixtures...' AS status;

DO $$
DECLARE
  v_count integer;
  v_start_at timestamptz;
  v_balance bigint;
BEGIN
  SELECT count(*) INTO v_count
  FROM auth.users
  WHERE id IN (
    '00000000-0000-4000-8000-000000000101',
    '00000000-0000-4000-8000-000000000102',
    '00000000-0000-4000-8000-000000000103',
    '00000000-0000-4000-8000-000000000104',
    '00000000-0000-4000-8000-000000000105'
  )
    AND phone_confirmed_at IS NOT NULL;

  IF v_count <> 5 THEN
    RAISE EXCEPTION 'Expected 5 confirmed auth users, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.admin_users
  WHERE user_id = '00000000-0000-4000-8000-000000000101'
    AND is_active = true;

  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Missing active UAT admin user';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.venue_users
  WHERE venue_id = '00000000-0000-4000-8000-000000000301'
    AND is_active = true;

  IF v_count <> 3 THEN
    RAISE EXCEPTION 'Expected 3 active venue staff memberships, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.game_questions
  WHERE template_id = 'fan_trivia'
    AND is_active = true
    AND approved_at IS NOT NULL
    AND metadata->>'uat_fixture' = 'true';

  IF v_count < 100 THEN
    RAISE EXCEPTION 'Expected at least 100 approved Fan Trivia UAT questions, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.game_session_questions
  WHERE session_id = '00000000-0000-4000-8000-000000000501';

  IF v_count <> 20 THEN
    RAISE EXCEPTION 'Expected exactly 20 selected questions for UAT game session, found %', v_count;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.game_session_questions
    WHERE session_id = '00000000-0000-4000-8000-000000000501'
    GROUP BY ordinal
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'Duplicate selected question ordinal found for UAT game session';
  END IF;

  SELECT public.pool_scheduled_start('00000000-0000-4000-8000-000000000401')
  INTO v_start_at;

  IF NOT public.user_has_qualifying_order(
    '00000000-0000-4000-8000-000000000104',
    '00000000-0000-4000-8000-000000000301',
    v_start_at
  ) THEN
    RAISE EXCEPTION 'Eligible UAT guest does not satisfy qualifying-order rule';
  END IF;

  IF public.user_has_qualifying_order(
    '00000000-0000-4000-8000-000000000105',
    '00000000-0000-4000-8000-000000000301',
    v_start_at
  ) THEN
    RAISE EXCEPTION 'Ineligible UAT guest incorrectly satisfies qualifying-order rule';
  END IF;

  SELECT available_balance_fet INTO v_balance
  FROM public.venue_fet_wallets
  WHERE venue_id = '00000000-0000-4000-8000-000000000301';

  IF v_balance <> 12000 THEN
    RAISE EXCEPTION 'Expected UAT venue wallet balance 12000, found %', v_balance;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.venue_fet_wallet_transactions
  WHERE venue_id = '00000000-0000-4000-8000-000000000301'
    AND metadata->>'uat_fixture' = 'true';

  IF v_count < 3 THEN
    RAISE EXCEPTION 'Expected venue wallet ledger rows for UAT fixture';
  END IF;

  IF NOT has_function_privilege('anon', 'public.get_game_session_question(uuid, integer)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Anon TV role cannot execute get_game_session_question';
  END IF;

  IF NOT has_table_privilege('anon', 'public.game_team_members', 'SELECT') THEN
    RAISE EXCEPTION 'Anon TV role lacks SELECT grant needed for embedded team-member counts';
  END IF;
END;
$$;

BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000101', true);

DO $$
DECLARE
  v_admin_user_id uuid;
  v_venue_count integer;
  v_game_count integer;
BEGIN
  SELECT user_id INTO v_admin_user_id
  FROM public.get_admin_me();

  IF v_admin_user_id <> '00000000-0000-4000-8000-000000000101' THEN
    RAISE EXCEPTION 'Authenticated UAT reviewer cannot resolve admin profile';
  END IF;

  SELECT count(*) INTO v_venue_count
  FROM public.venue_users vu
  JOIN public.venues v ON v.id = vu.venue_id
  WHERE vu.user_id = '00000000-0000-4000-8000-000000000101'
    AND vu.is_active = true
    AND v.slug = 'uat-live-sports-bar';

  IF v_venue_count <> 1 THEN
    RAISE EXCEPTION 'Authenticated UAT reviewer cannot resolve venue membership';
  END IF;

  SELECT count(*) INTO v_game_count
  FROM public.game_sessions
  WHERE venue_id = '00000000-0000-4000-8000-000000000301'
    AND id = '00000000-0000-4000-8000-000000000501';

  IF v_game_count <> 1 THEN
    RAISE EXCEPTION 'Authenticated venue role cannot read live game session';
  END IF;
END;
$$;

ROLLBACK;

BEGIN;
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claim.sub', '', true);

DO $$
DECLARE
  v_venue_count integer;
  v_screen_count integer;
  v_question_count integer;
BEGIN
  SELECT count(*) INTO v_venue_count
  FROM public.venues
  WHERE slug = 'uat-live-sports-bar'
    AND is_active = true;

  IF v_venue_count <> 1 THEN
    RAISE EXCEPTION 'Anon TV role cannot resolve UAT venue';
  END IF;

  SELECT count(*) INTO v_screen_count
  FROM public.venue_screen_states
  WHERE venue_id = '00000000-0000-4000-8000-000000000301'
    AND mode = 'game_question'
    AND active_game_session_id = '00000000-0000-4000-8000-000000000501';

  IF v_screen_count <> 1 THEN
    RAISE EXCEPTION 'Anon TV role cannot read UAT screen state';
  END IF;

  SELECT count(*) INTO v_question_count
  FROM public.get_game_session_question(
    '00000000-0000-4000-8000-000000000501',
    1
  );

  IF v_question_count <> 1 THEN
    RAISE EXCEPTION 'Anon TV role cannot read live question prompt/options';
  END IF;
END;
$$;

ROLLBACK;

SELECT 'Authenticated UAT fixtures verified.' AS status;
