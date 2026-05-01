\pset tuples_only on
\pset pager off

\echo 'Verifying admin platform control center...'

DO $$
DECLARE
  missing_functions text[];
  v_dashboard_def text;
  v_reward_def text;
  v_refund_def text;
  v_retry_def text;
BEGIN
  SELECT array_agg(required_signature ORDER BY required_signature)
  INTO missing_functions
  FROM (
    VALUES
      ('public.admin_dashboard_kpis()'),
      ('public.admin_control_center_audit(text,text,text,text,jsonb,jsonb,jsonb)'),
      ('public.admin_upsert_country(uuid,text,text,text,boolean,integer)'),
      ('public.admin_set_country_active(uuid,boolean)'),
      ('public.admin_update_venue_control(uuid,text,boolean,uuid,text,numeric,boolean)'),
      ('public.admin_update_competition_control(text,boolean,integer,text,text)'),
      ('public.admin_update_team_control(text,uuid,integer,boolean,text)'),
      ('public.admin_upsert_reward_rule(uuid,text,uuid,uuid,bigint,numeric,bigint,bigint,integer,boolean,timestamp with time zone,timestamp with time zone,text)'),
      ('public.admin_cancel_refund_pool(uuid,text)'),
      ('public.admin_retry_pool_settlement(uuid,text)'),
      ('public.admin_pool_operations_queue(integer)'),
      ('public.admin_risk_signals(integer)')
  ) AS expected(required_signature)
  WHERE to_regprocedure(expected.required_signature) IS NULL;

  IF missing_functions IS NOT NULL THEN
    RAISE EXCEPTION 'Missing admin control center functions: %', array_to_string(missing_functions, ', ');
  END IF;

  v_dashboard_def := pg_get_functiondef('public.admin_dashboard_kpis()'::regprocedure);
  IF v_dashboard_def NOT ILIKE '%activeCountries%'
     OR v_dashboard_def NOT ILIKE '%activeVenues%'
     OR v_dashboard_def NOT ILIKE '%totalFetStaked%'
     OR v_dashboard_def NOT ILIKE '%failedSettlements%'
     OR v_dashboard_def NOT ILIKE '%todaysOrders%' THEN
    RAISE EXCEPTION 'admin_dashboard_kpis must expose sports-bar control center KPIs';
  END IF;

  v_reward_def := pg_get_functiondef('public.admin_upsert_reward_rule(uuid,text,uuid,uuid,bigint,numeric,bigint,bigint,integer,boolean,timestamp with time zone,timestamp with time zone,text)'::regprocedure);
  IF v_reward_def NOT ILIKE '%require_admin_manager_user%'
     OR v_reward_def NOT ILIKE '%admin_control_center_audit%'
     OR v_reward_def NOT ILIKE '%audit reason%' THEN
    RAISE EXCEPTION 'admin_upsert_reward_rule must enforce admin role, reason, and audit logging';
  END IF;

  v_refund_def := pg_get_functiondef('public.admin_cancel_refund_pool(uuid,text)'::regprocedure);
  IF v_refund_def NOT ILIKE '%require_admin_manager_user%'
     OR v_refund_def NOT ILIKE '%reverse_or_refund_pool_if_match_cancelled%'
     OR v_refund_def NOT ILIKE '%admin_control_center_audit%' THEN
    RAISE EXCEPTION 'admin_cancel_refund_pool must be admin-only, refund through backend function, and audit';
  END IF;

  v_retry_def := pg_get_functiondef('public.admin_retry_pool_settlement(uuid,text)'::regprocedure);
  IF v_retry_def NOT ILIKE '%admin-settlement:%'
     OR v_retry_def NOT ILIKE '%idempotency_key%'
     OR v_retry_def NOT ILIKE '%admin_control_center_audit%' THEN
    RAISE EXCEPTION 'admin_retry_pool_settlement must use idempotency and audit logging';
  END IF;
END;
$$;

\echo 'Admin platform control center verified'
