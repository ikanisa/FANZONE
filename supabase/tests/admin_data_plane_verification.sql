\pset tuples_only on
\pset pager off

\echo 'Verifying admin data-plane views, policies, and RPCs...'

DO $$
DECLARE
  missing_views text[];
  missing_policies text[];
  missing_rpcs text[];
BEGIN
  SELECT array_agg(required_name ORDER BY required_name)
  INTO missing_views
  FROM (
    VALUES
      ('public.fet_supply_overview_admin'),
      ('public.fet_transactions_admin')
  ) AS expected(required_name)
  WHERE to_regclass(expected.required_name) IS NULL;

  IF missing_views IS NOT NULL THEN
    RAISE EXCEPTION 'Missing admin views: %', array_to_string(missing_views, ', ');
  END IF;

  SELECT array_agg(required_policy ORDER BY required_policy)
  INTO missing_policies
  FROM (
    VALUES
      ('competitions', 'Admins manage competitions'),
      ('fet_wallet_transactions', 'Admins read wallet transactions'),
      ('matches', 'Admins manage matches'),
      ('notification_log', 'Admins read notifications'),
      ('notification_log', 'Users update own notifications'),
      ('prediction_challenge_entries', 'Admins read challenge entries')
  ) AS expected(tablename, required_policy)
  WHERE NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = expected.tablename
      AND policyname = expected.required_policy
  );

  IF missing_policies IS NOT NULL THEN
    RAISE EXCEPTION 'Missing admin policies: %', array_to_string(missing_policies, ', ');
  END IF;

  SELECT array_agg(required_signature ORDER BY required_signature)
  INTO missing_rpcs
  FROM (
    VALUES
      ('public.admin_change_admin_role(uuid,text)'),
      ('public.admin_grant_access(text,text)'),
      ('public.admin_publish_team_news(uuid)'),
      ('public.admin_revoke_access(uuid)'),
      ('public.admin_trigger_currency_rate_refresh()'),
      ('public.admin_trigger_team_news_ingestion(text,text,text[],integer)')
  ) AS expected(required_signature)
  WHERE to_regprocedure(expected.required_signature) IS NULL;

  IF missing_rpcs IS NOT NULL THEN
    RAISE EXCEPTION 'Missing admin RPCs: %', array_to_string(missing_rpcs, ', ');
  END IF;
END;
$$;

\echo 'Admin data-plane verification passed'
