\pset tuples_only on
\pset pager off

\echo 'Verifying admin data plane...'

DO $$
DECLARE
  missing_relations text[];
  missing_functions text[];
BEGIN
  SELECT array_agg(required_name ORDER BY required_name)
  INTO missing_relations
  FROM (
    VALUES
      ('public.admin_platform_features'),
      ('public.admin_platform_content_blocks'),
      ('public.curated_matches'),
      ('public.fet_transactions_admin'),
      ('public.match_pool_stats'),
      ('public.match_pools'),
      ('public.pool_operation_audit_logs'),
      ('public.venues')
  ) AS expected(required_name)
  WHERE to_regclass(expected.required_name) IS NULL;

  IF missing_relations IS NOT NULL THEN
    RAISE EXCEPTION 'Missing admin relations: %', array_to_string(missing_relations, ', ');
  END IF;

  SELECT array_agg(required_signature ORDER BY required_signature)
  INTO missing_functions
  FROM (
    VALUES
      ('public.admin_dashboard_kpis()'),
      ('public.admin_pool_engagement_daily(integer)'),
      ('public.admin_pool_engagement_kpis()'),
      ('public.admin_fet_flow_weekly(integer)'),
      ('public.admin_global_search(text,integer)'),
      ('public.admin_pool_operations_kpis()'),
      ('public.admin_pool_operations_queue(integer)'),
      ('public.admin_run_pool_settlement(integer)'),
      ('public.admin_upsert_platform_feature(jsonb)'),
      ('public.admin_upsert_platform_content_block(jsonb)')
  ) AS expected(required_signature)
  WHERE to_regprocedure(expected.required_signature) IS NULL;

  IF missing_functions IS NOT NULL THEN
    RAISE EXCEPTION 'Missing admin functions: %', array_to_string(missing_functions, ', ');
  END IF;
END;
$$;

DO $$
BEGIN
  IF has_table_privilege('anon', 'public.pool_operation_audit_logs', 'SELECT')
     OR has_table_privilege('anon', 'public.fet_transactions_admin', 'SELECT')
     OR has_table_privilege('anon', 'public.admin_platform_features', 'SELECT')
  THEN
    RAISE EXCEPTION 'Anonymous role can read admin-only data plane objects';
  END IF;
END;
$$;

\echo 'Admin data plane verified'
