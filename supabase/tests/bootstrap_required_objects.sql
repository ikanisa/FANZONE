\pset tuples_only on
\pset pager off

\echo 'Verifying required Supabase bootstrap objects...'

DO $$
DECLARE
  missing_relations text[];
  missing_functions text[];
BEGIN
  SELECT array_agg(required_name ORDER BY required_name)
  INTO missing_relations
  FROM (
    VALUES
      ('public.app_preferences'),
      ('public.challenge_feed'),
      ('public.competition_standings'),
      ('public.fan_clubs'),
      ('public.fet_supply_overview_admin'),
      ('public.fet_transactions_admin'),
      ('public.fet_wallet_transactions'),
      ('public.fet_wallets'),
      ('public.otp_verifications'),
      ('public.prediction_challenge_entries'),
      ('public.prediction_challenges'),
      ('public.profiles'),
      ('public.public_leaderboard'),
      ('public.team_news_ingestion_runs'),
      ('public.user_followed_competitions'),
      ('public.user_followed_teams')
  ) AS expected(required_name)
  WHERE to_regclass(expected.required_name) IS NULL;

  IF missing_relations IS NOT NULL THEN
    RAISE EXCEPTION 'Missing required relations: %', array_to_string(missing_relations, ', ');
  END IF;

  SELECT array_agg(required_signature ORDER BY required_signature)
  INTO missing_functions
  FROM (
    VALUES
      ('public.admin_publish_team_news(uuid)'),
      ('public.admin_trigger_currency_rate_refresh()'),
      ('public.admin_trigger_team_news_ingestion(text,text,text[],integer)'),
      ('public.find_auth_user_by_phone(text)'),
      ('public.is_service_role_request()'),
      ('public.require_active_admin_user()'),
      ('public.resolve_auth_user_phone(uuid)')
  ) AS expected(required_signature)
  WHERE to_regprocedure(expected.required_signature) IS NULL;

  IF missing_functions IS NOT NULL THEN
    RAISE EXCEPTION 'Missing required functions: %', array_to_string(missing_functions, ', ');
  END IF;
END;
$$;

\echo 'Required bootstrap objects verified'
