-- Non-mutating contract for runtime telemetry and product analytics hardening.

DO $$
DECLARE
  v_runtime_rpc regprocedure := to_regprocedure(
    'public.log_app_runtime_errors_batch(jsonb)'
  );
  v_analytics_rpc regprocedure := to_regprocedure(
    'public.log_product_events_batch(jsonb)'
  );
  v_single_analytics_rpc regprocedure := to_regprocedure(
    'public.log_product_event(text,jsonb,text)'
  );
  v_redact_rpc regprocedure := to_regprocedure(
    'public.observability_redact_text(text,integer)'
  );
  v_safe_timestamp_rpc regprocedure := to_regprocedure(
    'public.observability_safe_timestamptz(text)'
  );
  v_redact_jsonb_rpc regprocedure := to_regprocedure(
    'public.observability_redact_jsonb(jsonb,integer)'
  );
  v_missing_columns text[];
  v_direct_writers text[];
  v_redacted_sample jsonb;
BEGIN
  IF to_regclass('public.app_runtime_errors') IS NULL THEN
    RAISE EXCEPTION 'Missing public.app_runtime_errors';
  END IF;

  IF to_regclass('public.product_events') IS NULL THEN
    RAISE EXCEPTION 'Missing public.product_events';
  END IF;

  SELECT array_agg(column_name ORDER BY column_name)
  INTO v_missing_columns
  FROM (
    VALUES ('event_type'), ('metadata')
  ) AS required(column_name)
  WHERE NOT EXISTS (
    SELECT 1
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.table_name = 'app_runtime_errors'
      AND c.column_name = required.column_name
  );

  IF v_missing_columns IS NOT NULL THEN
    RAISE EXCEPTION 'Missing app_runtime_errors columns: %',
      array_to_string(v_missing_columns, ', ');
  END IF;

  SELECT array_agg(role_name || ':' || table_name || ':' || privilege)
  INTO v_direct_writers
  FROM (
    VALUES
      ('anon', 'app_runtime_errors', 'INSERT'),
      ('anon', 'app_runtime_errors', 'UPDATE'),
      ('anon', 'app_runtime_errors', 'DELETE'),
      ('authenticated', 'app_runtime_errors', 'INSERT'),
      ('authenticated', 'app_runtime_errors', 'UPDATE'),
      ('authenticated', 'app_runtime_errors', 'DELETE'),
      ('anon', 'product_events', 'INSERT'),
      ('anon', 'product_events', 'UPDATE'),
      ('anon', 'product_events', 'DELETE'),
      ('authenticated', 'product_events', 'INSERT'),
      ('authenticated', 'product_events', 'UPDATE'),
      ('authenticated', 'product_events', 'DELETE')
  ) AS checks(role_name, table_name, privilege)
  WHERE has_table_privilege(
    checks.role_name,
    format('public.%I', checks.table_name),
    checks.privilege
  );

  IF v_direct_writers IS NOT NULL THEN
    RAISE EXCEPTION 'Client roles must not write observability tables directly: %',
      array_to_string(v_direct_writers, ', ');
  END IF;

  IF v_runtime_rpc IS NULL THEN
    RAISE EXCEPTION 'Missing log_app_runtime_errors_batch(jsonb)';
  END IF;

  IF v_analytics_rpc IS NULL THEN
    RAISE EXCEPTION 'Missing log_product_events_batch(jsonb)';
  END IF;

  IF v_single_analytics_rpc IS NULL THEN
    RAISE EXCEPTION 'Missing log_product_event(text,jsonb,text)';
  END IF;

  IF v_redact_rpc IS NULL OR v_safe_timestamp_rpc IS NULL OR v_redact_jsonb_rpc IS NULL THEN
    RAISE EXCEPTION 'Missing observability redaction/timestamp helper RPCs';
  END IF;

  IF NOT has_function_privilege('anon', v_runtime_rpc, 'EXECUTE')
     OR NOT has_function_privilege('authenticated', v_runtime_rpc, 'EXECUTE') THEN
    RAISE EXCEPTION 'Runtime telemetry RPC must remain executable by anon and authenticated roles';
  END IF;

  IF has_function_privilege('anon', v_analytics_rpc, 'EXECUTE')
     OR has_function_privilege('anon', v_single_analytics_rpc, 'EXECUTE') THEN
    RAISE EXCEPTION 'Anonymous users must not execute product analytics RPCs';
  END IF;

  IF NOT has_function_privilege('authenticated', v_analytics_rpc, 'EXECUTE')
     OR NOT has_function_privilege('authenticated', v_single_analytics_rpc, 'EXECUTE') THEN
    RAISE EXCEPTION 'Authenticated users must be able to execute product analytics RPCs';
  END IF;

  IF has_function_privilege('anon', v_redact_rpc, 'EXECUTE')
     OR has_function_privilege('authenticated', v_redact_rpc, 'EXECUTE')
     OR has_function_privilege('anon', v_safe_timestamp_rpc, 'EXECUTE')
     OR has_function_privilege('authenticated', v_safe_timestamp_rpc, 'EXECUTE')
     OR has_function_privilege('anon', v_redact_jsonb_rpc, 'EXECUTE')
     OR has_function_privilege('authenticated', v_redact_jsonb_rpc, 'EXECUTE') THEN
    RAISE EXCEPTION 'Observability helper functions must not be client-executable';
  END IF;

  v_redacted_sample := public.observability_redact_jsonb(
    jsonb_build_object(
      'token', 'sbp_demo_only',
      'nested', jsonb_build_object(
        'authorization', 'Bearer eyJ.demo.token',
        'url', 'postgres://user:pass@db.example.test/postgres'
      ),
      'array', jsonb_build_array('api_key=demo', 7, true),
      'safe_count', 2
    ),
    4
  );

  IF v_redacted_sample::text ~ '(sbp_demo_only|eyJ\.demo\.token|user:pass|api_key=demo)'
     OR v_redacted_sample->>'token' <> '[redacted]'
     OR v_redacted_sample #>> '{nested,authorization}' <> '[redacted]'
     OR position('[redacted]' in v_redacted_sample #>> '{nested,url}') = 0
     OR position('[redacted]' in v_redacted_sample #>> '{array,0}') = 0
     OR (v_redacted_sample->>'safe_count')::integer <> 2 THEN
    RAISE EXCEPTION 'Observability JSONB redaction must remove token-like metadata while preserving safe scalar context';
  END IF;

  IF position('observability_redact_text' in pg_get_functiondef(v_runtime_rpc)) = 0
     OR position('observability_redact_jsonb' in pg_get_functiondef(v_runtime_rpc)) = 0
     OR position('jsonb_array_length(p_errors) > 20' in pg_get_functiondef(v_runtime_rpc)) = 0
     OR position('event_type' in pg_get_functiondef(v_runtime_rpc)) = 0
     OR position('metadata' in pg_get_functiondef(v_runtime_rpc)) = 0 THEN
    RAISE EXCEPTION 'Runtime telemetry RPC must redact, bound, and persist event metadata';
  END IF;

  IF position('Authentication is required for product analytics' in pg_get_functiondef(v_analytics_rpc)) = 0
     OR position('jsonb_array_length(p_events) > 50' in pg_get_functiondef(v_analytics_rpc)) = 0
     OR position('observability_redact_text' in pg_get_functiondef(v_analytics_rpc)) = 0
     OR position('observability_redact_jsonb' in pg_get_functiondef(v_analytics_rpc)) = 0
     OR position('event_name is required' in pg_get_functiondef(v_analytics_rpc)) = 0 THEN
    RAISE EXCEPTION 'Product analytics RPC must require auth, bounded batches, redaction, and event names';
  END IF;
END $$;

SELECT 'observability_telemetry_hardening_passed' AS result;
