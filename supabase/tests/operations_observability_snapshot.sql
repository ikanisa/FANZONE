-- Non-mutating contract for the admin operations observability snapshot.

DO $$
DECLARE
  v_snapshot_rpc regprocedure := to_regprocedure(
    'public.admin_operations_observability_snapshot()'
  );
  v_function_def text;
  v_required_fragment text;
  v_required_fragments text[] := ARRAY[
    'public.is_admin_manager',
    'app_runtime_errors',
    'product_events',
    'orders',
    'payment_events',
    'fet_wallet_transactions',
    'match_pools',
    'bell_requests',
    'notification_log',
    'device_tokens',
    'matches',
    'runtime_errors_24h',
    'manual_payments',
    'fet_ledger',
    'push_notifications',
    'latest_livescore_sync_at'
  ];
BEGIN
  IF v_snapshot_rpc IS NULL THEN
    RAISE EXCEPTION 'Missing admin_operations_observability_snapshot()';
  END IF;

  IF has_function_privilege(
    'anon',
    v_snapshot_rpc,
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'Anonymous users must not execute admin_operations_observability_snapshot';
  END IF;

  IF NOT has_function_privilege(
    'authenticated',
    v_snapshot_rpc,
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'Authenticated admins must be able to execute admin_operations_observability_snapshot';
  END IF;

  IF NOT has_function_privilege(
    'service_role',
    v_snapshot_rpc,
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'Service role must be able to execute admin_operations_observability_snapshot for backend dashboards';
  END IF;

  v_function_def := pg_get_functiondef(v_snapshot_rpc);

  FOREACH v_required_fragment IN ARRAY v_required_fragments
  LOOP
    IF position(v_required_fragment in v_function_def) = 0 THEN
      RAISE EXCEPTION 'admin_operations_observability_snapshot must include %', v_required_fragment;
    END IF;
  END LOOP;

  IF position('Admin operations observability snapshot requires a platform admin' in v_function_def) = 0 THEN
    RAISE EXCEPTION 'admin_operations_observability_snapshot must fail closed for non-admin callers';
  END IF;
END $$;

SELECT 'operations_observability_snapshot_passed' AS result;
