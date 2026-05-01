\pset tuples_only on
\pset pager off

\echo 'Verifying required sports-bar platform objects...'

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
      ('public.curated_matches'),
      ('public.fet_supply_overview_admin'),
      ('public.fet_transactions_admin'),
      ('public.fet_wallet_transactions'),
      ('public.fet_wallets'),
      ('public.match_pool_camps'),
      ('public.match_pool_entries'),
      ('public.match_pool_invites'),
      ('public.match_pool_settlements'),
      ('public.match_pool_stats'),
      ('public.match_pools'),
      ('public.menu_categories'),
      ('public.menu_items'),
      ('public.orders'),
      ('public.payment_events'),
      ('public.platform_content_blocks'),
      ('public.platform_feature_channels'),
      ('public.platform_feature_rules'),
      ('public.platform_features'),
      ('public.pool_operation_audit_logs'),
      ('public.profiles'),
      ('public.seasons'),
      ('public.standings'),
      ('public.teams'),
      ('public.team_aliases'),
      ('public.team_form_features'),
      ('public.user_favorite_teams'),
      ('public.user_followed_competitions'),
      ('public.venues'),
      ('public.venue_users'),
      ('public.whatsapp_auth_sessions')
  ) AS expected(required_name)
  WHERE to_regclass(expected.required_name) IS NULL;

  IF missing_relations IS NOT NULL THEN
    RAISE EXCEPTION 'Missing required relations: %', array_to_string(missing_relations, ', ');
  END IF;

  SELECT array_agg(required_signature ORDER BY required_signature)
  INTO missing_functions
  FROM (
    VALUES
      ('public.create_pool(text,text,uuid,uuid,text,bigint,bigint,bigint,jsonb,boolean)'),
      ('public.create_match_pool(text,public.match_pool_scope,text,uuid,text,bigint,bigint,bigint,boolean)'),
      ('public.join_pool(uuid,uuid,bigint,text,text)'),
      ('public.join_match_pool(uuid,uuid,bigint,text)'),
      ('public.stake_fet(uuid,uuid,bigint,text,text)'),
      ('public.settle_match_pool(uuid)'),
      ('public.settle_finished_match_pools(integer)'),
      ('public.create_match_pool_invite(uuid,timestamp with time zone)'),
      ('public.get_public_pool_share(text,text,text)'),
      ('public.create_venue_official_match_pool(uuid,text,text,bigint,bigint,bigint,bigint)'),
      ('public.get_my_pools(integer)'),
      ('public.get_match_pool_social_card_payload(uuid)'),
      ('public.pool_state_transition_allowed(public.match_pool_status,public.match_pool_status)'),
      ('public.venue_endorse_pool(uuid,uuid)'),
      ('public.venue_reject_pool(uuid,uuid,text)'),
      ('public.get_wallet_balance(uuid)'),
      ('public.reconcile_fet_wallet(uuid)'),
      ('public.credit_welcome_fet(uuid,text)'),
      ('public.credit_fet_for_order(uuid,text)'),
      ('public.spend_fet_on_order(uuid,bigint,text)'),
      ('public.admin_adjust_fet(uuid,bigint,text,text,text)'),
      ('public.get_venue_fet_reward_config(uuid)'),
      ('public.get_venue_fet_reward_summary(uuid)'),
      ('public.update_venue_fet_reward_config(uuid,numeric,text,boolean,numeric)'),
      ('public.admin_pool_operations_kpis()'),
      ('public.admin_pool_operations_queue(integer)'),
      ('public.admin_run_pool_settlement(integer)'),
      ('public.get_app_bootstrap_config(text,text)'),
      ('public.assert_platform_feature_available(text,text)'),
      ('public.current_user_platform_roles()'),
      ('public.platform_feature_config_version()'),
      ('public.resolve_platform_feature(text,text,boolean,timestamp with time zone)'),
      ('public.require_active_admin_user()'),
      ('public.resolve_auth_user_phone(uuid)')
  ) AS expected(required_signature)
  WHERE to_regprocedure(expected.required_signature) IS NULL;

  IF missing_functions IS NOT NULL THEN
    RAISE EXCEPTION 'Missing required functions: %', array_to_string(missing_functions, ', ');
  END IF;
END;
$$;

\echo 'Required sports-bar platform objects verified'
