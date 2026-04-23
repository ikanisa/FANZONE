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
      ('public.app_matches'),
      ('public.app_competitions'),
      ('public.app_config_remote'),
      ('public.competition_standings'),
      ('public.fet_supply_overview_admin'),
      ('public.fet_transactions_admin'),
      ('public.fet_wallet_transactions'),
      ('public.fet_wallets'),
      ('public.match_prediction_consensus'),
      ('public.otp_verifications'),
      ('public.predictions_engine_outputs'),
      ('public.profiles'),
      ('public.public_leaderboard'),
      ('public.seasons'),
      ('public.standings'),
      ('public.teams'),
      ('public.team_aliases'),
      ('public.team_form_features'),
      ('public.token_rewards'),
      ('public.user_favorite_teams'),
      ('public.user_predictions'),
      ('public.whatsapp_auth_sessions'),
      ('public.user_followed_competitions')
  ) AS expected(required_name)
  WHERE to_regclass(expected.required_name) IS NULL;

  IF missing_relations IS NOT NULL THEN
    RAISE EXCEPTION 'Missing required relations: %', array_to_string(missing_relations, ', ');
  END IF;

  SELECT array_agg(required_signature ORDER BY required_signature)
  INTO missing_functions
  FROM (
    VALUES
      ('public.admin_trigger_currency_rate_refresh()'),
      ('public.generate_predictions_for_upcoming_matches(integer)'),
      ('public.generate_predictions_for_matches(text[],integer,text,boolean)'),
      ('public.generate_team_form_features_for_matches(text[],integer)'),
      ('public.find_auth_user_by_phone(text)'),
      ('public.get_app_bootstrap_config(text,text)'),
      ('public.is_service_role_request()'),
      ('public.require_active_admin_user()'),
      ('public.score_finished_matches_with_pending_predictions(integer)'),
      ('public.submit_user_prediction(text,text,boolean,boolean,integer,integer)'),
      ('public.resolve_auth_user_phone(uuid)')
  ) AS expected(required_signature)
  WHERE to_regprocedure(expected.required_signature) IS NULL;

  IF missing_functions IS NOT NULL THEN
    RAISE EXCEPTION 'Missing required functions: %', array_to_string(missing_functions, ', ');
  END IF;
END;
$$;

\echo 'Required bootstrap objects verified'
