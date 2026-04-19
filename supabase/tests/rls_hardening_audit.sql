\pset tuples_only on
\pset pager off

\echo 'Resolving dynamic ids for RLS audit...'
SELECT
  (SELECT user_id::text FROM public.fet_wallets ORDER BY created_at NULLS LAST, user_id LIMIT 1) AS user_a,
  coalesce(
    (SELECT user_id::text
     FROM public.fet_wallets
     WHERE user_id <> (SELECT user_id FROM public.fet_wallets ORDER BY created_at NULLS LAST, user_id LIMIT 1)
     ORDER BY created_at NULLS LAST, user_id
     LIMIT 1),
    gen_random_uuid()::text
  ) AS user_b,
  (SELECT id FROM public.teams ORDER BY id LIMIT 1) AS team_id,
  (SELECT id FROM public.competitions ORDER BY id LIMIT 1) AS competition_id,
  (SELECT count(*)::text FROM public.fet_wallet_transactions WHERE user_id = (SELECT user_id FROM public.fet_wallets ORDER BY created_at NULLS LAST, user_id LIMIT 1)) AS user_a_tx_count
\gset

\if :{?user_a}
\else
\echo 'No wallet rows found. Seed or point the audit at a populated environment first.'
\quit 1
\endif

\if :{?team_id}
\else
\echo 'No team rows found. Seed or point the audit at a populated environment first.'
\quit 1
\endif

\if :{?competition_id}
\else
\echo 'No competition rows found. Seed or point the audit at a populated environment first.'
\quit 1
\endif

\echo 'Auditing policy inventory...'
SELECT set_config('rls.audit.user_a', :'user_a', false);
SELECT set_config('rls.audit.user_b', :'user_b', false);
SELECT set_config('rls.audit.team_id', :'team_id', false);
SELECT set_config('rls.audit.competition_id', :'competition_id', false);
SELECT set_config('rls.audit.user_a_tx_count', :'user_a_tx_count', false);

DO $$
DECLARE
  missing_policies text[];
  stale_policies text[];
BEGIN
  SELECT array_agg(required_policy)
  INTO missing_policies
  FROM (
    VALUES
      ('fet_wallets', 'Users read own wallet'),
      ('fet_wallet_transactions', 'Users read own transactions'),
      ('prediction_challenges', 'Public read challenges'),
      ('prediction_challenge_entries', 'Users read own entries'),
      ('prediction_slips', 'Users read own slips'),
      ('prediction_slip_selections', 'Users read own slip selections'),
      ('user_followed_teams', 'Users manage own team follows'),
      ('user_followed_competitions', 'Users manage own competition follows'),
      ('team_supporters', 'Users read own team supporters'),
      ('team_contributions', 'Users read own contributions'),
      ('team_news', 'Public read published team news'),
      ('daily_challenges', 'Public read daily challenges'),
      ('daily_challenge_entries', 'Users read own daily entries'),
      ('device_tokens', 'Users manage own device tokens'),
      ('notification_preferences', 'Users manage own notification prefs'),
      ('notification_log', 'Users read own notifications'),
      ('user_status', 'Users read own status')
  ) AS expected(tablename, required_policy)
  WHERE EXISTS (
      SELECT 1
      FROM information_schema.tables t
      WHERE t.table_schema = 'public'
        AND t.table_name = expected.tablename
  )
    AND NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = expected.tablename
      AND policyname = expected.required_policy
  );

  IF missing_policies IS NOT NULL THEN
    RAISE EXCEPTION 'Missing required RLS policies: %', array_to_string(missing_policies, ', ');
  END IF;

  SELECT array_agg(policyname)
  INTO stale_policies
  FROM pg_policies
  WHERE schemaname = 'public'
    AND (
      (tablename = 'prediction_challenge_entries' AND policyname IN (
        'Authenticated can view entries',
        'Users can add own challenge entries'
      ))
      OR
      (tablename = 'prediction_challenges' AND policyname = 'Users can create own challenges')
      OR
      (tablename = 'prediction_slips' AND policyname = 'Users insert own slips')
      OR
      (tablename = 'prediction_slip_selections' AND policyname = 'Users insert own slip selections')
    );

  IF stale_policies IS NOT NULL THEN
    RAISE EXCEPTION 'Stale permissive policies still present: %', array_to_string(stale_policies, ', ');
  END IF;
END;
$$;

BEGIN;

\echo 'Testing anon access...'
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{"role":"anon"}', true);

DO $$
DECLARE
  wallet_rows integer;
  tx_rows integer;
BEGIN
  SELECT count(*) INTO wallet_rows FROM public.fet_wallets;
  IF wallet_rows <> 0 THEN
    RAISE EXCEPTION 'Anon role can read % wallet rows', wallet_rows;
  END IF;

  SELECT count(*) INTO tx_rows FROM public.fet_wallet_transactions;
  IF tx_rows <> 0 THEN
    RAISE EXCEPTION 'Anon role can read % wallet transaction rows', tx_rows;
  END IF;

  PERFORM 1 FROM public.matches LIMIT 1;
  PERFORM 1 FROM public.prediction_challenges LIMIT 1;
  PERFORM 1 FROM public.daily_challenges LIMIT 1;
END;
$$;

RESET ROLE;
SELECT set_config('request.jwt.claims', '', true);

\echo 'Testing authenticated user isolation...'
SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  format('{"role":"authenticated","sub":"%s"}', :'user_a'),
  true
);

DO $$
DECLARE
  own_wallet_rows integer;
  other_wallet_rows integer;
  own_tx_rows integer;
  other_tx_rows integer;
BEGIN
  SELECT count(*)
  INTO own_wallet_rows
  FROM public.fet_wallets
  WHERE user_id = current_setting('rls.audit.user_a')::uuid;

  IF own_wallet_rows <> 1 THEN
    RAISE EXCEPTION 'Authenticated user cannot read exactly one own wallet row (saw %)', own_wallet_rows;
  END IF;

  SELECT count(*)
  INTO other_wallet_rows
  FROM public.fet_wallets
  WHERE user_id = current_setting('rls.audit.user_b')::uuid;

  IF other_wallet_rows <> 0 THEN
    RAISE EXCEPTION 'Authenticated user can read another user wallet row';
  END IF;

  SELECT count(*)
  INTO own_tx_rows
  FROM public.fet_wallet_transactions
  WHERE user_id = current_setting('rls.audit.user_a')::uuid;

  IF own_tx_rows <> current_setting('rls.audit.user_a_tx_count')::integer THEN
    RAISE EXCEPTION 'Authenticated user sees % own tx rows but expected %', own_tx_rows, current_setting('rls.audit.user_a_tx_count');
  END IF;

  SELECT count(*)
  INTO other_tx_rows
  FROM public.fet_wallet_transactions
  WHERE user_id = current_setting('rls.audit.user_b')::uuid;

  IF other_tx_rows <> 0 THEN
    RAISE EXCEPTION 'Authenticated user can read another user tx rows';
  END IF;
END;
$$;

\echo 'Testing own-row write policies...'
INSERT INTO public.user_followed_teams (user_id, team_id)
VALUES (:'user_a'::uuid, :'team_id')
ON CONFLICT (user_id, team_id) DO NOTHING;

DELETE FROM public.user_followed_teams
WHERE user_id = :'user_a'::uuid
  AND team_id = :'team_id';

DO $$
BEGIN
  BEGIN
    INSERT INTO public.user_followed_teams (user_id, team_id)
    VALUES (
      current_setting('rls.audit.user_b')::uuid,
      current_setting('rls.audit.team_id')
    );
    RAISE EXCEPTION 'Cross-user team follow insert unexpectedly succeeded';
  EXCEPTION
    WHEN insufficient_privilege THEN NULL;
    WHEN SQLSTATE '42501' THEN NULL;
  END;
END;
$$;

INSERT INTO public.user_followed_competitions (user_id, competition_id)
VALUES (:'user_a'::uuid, :'competition_id')
ON CONFLICT (user_id, competition_id) DO NOTHING;

DELETE FROM public.user_followed_competitions
WHERE user_id = :'user_a'::uuid
  AND competition_id = :'competition_id';

DO $$
BEGIN
  BEGIN
    INSERT INTO public.user_followed_competitions (user_id, competition_id)
    VALUES (
      current_setting('rls.audit.user_b')::uuid,
      current_setting('rls.audit.competition_id')
    );
    RAISE EXCEPTION 'Cross-user competition follow insert unexpectedly succeeded';
  EXCEPTION
    WHEN insufficient_privilege THEN NULL;
    WHEN SQLSTATE '42501' THEN NULL;
  END;
END;
$$;

INSERT INTO public.device_tokens (user_id, token, platform, is_active)
VALUES (
  :'user_a'::uuid,
  'rls-audit-' || replace(clock_timestamp()::text, ' ', '-'),
  'android',
  true
);

DO $$
BEGIN
  BEGIN
    INSERT INTO public.device_tokens (user_id, token, platform, is_active)
    VALUES (
      current_setting('rls.audit.user_b')::uuid,
      'rls-audit-cross-user',
      'android',
      true
    );
    RAISE EXCEPTION 'Cross-user device token insert unexpectedly succeeded';
  EXCEPTION
    WHEN insufficient_privilege THEN NULL;
    WHEN SQLSTATE '42501' THEN NULL;
  END;
END;
$$;

INSERT INTO public.notification_preferences (user_id, marketing)
VALUES (:'user_a'::uuid, false)
ON CONFLICT (user_id) DO UPDATE
SET marketing = excluded.marketing;

DO $$
BEGIN
  BEGIN
    INSERT INTO public.notification_preferences (user_id, marketing)
    VALUES (current_setting('rls.audit.user_b')::uuid, true)
    ON CONFLICT (user_id) DO UPDATE
    SET marketing = excluded.marketing;
    RAISE EXCEPTION 'Cross-user notification preference upsert unexpectedly succeeded';
  EXCEPTION
    WHEN insufficient_privilege THEN NULL;
    WHEN SQLSTATE '42501' THEN NULL;
  END;
END;
$$;

ROLLBACK;

\echo 'RLS hardening audit passed.'
