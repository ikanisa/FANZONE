\pset tuples_only on
\pset pager off

\echo 'Auditing RLS and client grants...'

DO $$
DECLARE
  exposed text[];
BEGIN
  SELECT array_agg(table_name ORDER BY table_name)
  INTO exposed
  FROM (
    VALUES
      ('fet_wallets'),
      ('fet_wallet_transactions'),
      ('match_pool_settlements'),
      ('pool_operation_audit_logs'),
      ('payment_events'),
      ('orders')
  ) AS sensitive(table_name)
  WHERE has_table_privilege('anon', format('public.%I', sensitive.table_name), 'INSERT')
     OR has_table_privilege('anon', format('public.%I', sensitive.table_name), 'UPDATE')
     OR has_table_privilege('anon', format('public.%I', sensitive.table_name), 'DELETE');

  IF exposed IS NOT NULL THEN
    RAISE EXCEPTION 'Anonymous role has write access to sensitive tables: %', array_to_string(exposed, ', ');
  END IF;
END;
$$;

DO $$
DECLARE
  exposed text[];
BEGIN
  SELECT array_agg(table_name ORDER BY table_name)
  INTO exposed
  FROM (
    VALUES
      ('platform_features'),
      ('platform_feature_rules'),
      ('platform_feature_channels'),
      ('platform_content_blocks'),
      ('curated_matches'),
      ('match_pool_settlements'),
      ('pool_operation_audit_logs')
  ) AS sensitive(table_name)
  WHERE has_table_privilege('authenticated', format('public.%I', sensitive.table_name), 'INSERT')
     OR has_table_privilege('authenticated', format('public.%I', sensitive.table_name), 'UPDATE')
     OR has_table_privilege('authenticated', format('public.%I', sensitive.table_name), 'DELETE');

  IF exposed IS NOT NULL THEN
    RAISE EXCEPTION 'Authenticated role has direct write access to managed tables: %', array_to_string(exposed, ', ');
  END IF;
END;
$$;

DO $$
DECLARE
  unsafe_functions text[];
BEGIN
  SELECT array_agg(signature ORDER BY signature)
  INTO unsafe_functions
  FROM (
    VALUES
      ('public.settle_match_pool(uuid)'),
      ('public.settle_finished_match_pools(integer)'),
      ('public.admin_run_pool_settlement(integer)'),
      ('public.set_match_pool_share_links()'),
      ('public.set_match_pool_social_card_url(uuid,text)')
  ) AS required(signature)
  WHERE has_function_privilege('anon', required.signature, 'EXECUTE');

  IF unsafe_functions IS NOT NULL THEN
    RAISE EXCEPTION 'Anonymous role can execute restricted functions: %', array_to_string(unsafe_functions, ', ');
  END IF;
END;
$$;

\echo 'RLS and client grants verified'
