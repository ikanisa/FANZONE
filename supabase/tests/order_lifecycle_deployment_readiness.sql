-- Non-mutating deployment readiness check for Hospitality Core Phase 2.
-- This verifies schema/RPC/RLS shape only. Run the full
-- order_lifecycle_contract.sql after this passes.

DO $$
DECLARE
  v_missing_statuses text[];
  v_transition_rpc regprocedure;
  v_payment_rpc regprocedure;
  v_rls_enabled boolean;
  v_policy_count integer;
BEGIN
  SELECT array_agg(status)
  INTO v_missing_statuses
  FROM unnest(ARRAY[
    'draft',
    'placed',
    'received',
    'submitted',
    'accepted',
    'preparing',
    'ready',
    'served',
    'completed',
    'cancelled',
    'refunded',
    'disputed'
  ]) AS expected(status)
  WHERE NOT EXISTS (
    SELECT 1
    FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'order_status'
      AND e.enumlabel = expected.status
  );

  IF v_missing_statuses IS NOT NULL THEN
    RAISE EXCEPTION 'Missing order_status enum values: %', v_missing_statuses;
  END IF;

  IF to_regclass('public.order_state_events') IS NULL THEN
    RAISE EXCEPTION 'Missing public.order_state_events';
  END IF;

  SELECT c.relrowsecurity
  INTO v_rls_enabled
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname = 'order_state_events';

  IF v_rls_enabled IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'public.order_state_events must have RLS enabled';
  END IF;

  SELECT count(*)
  INTO v_policy_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'order_state_events'
    AND policyname = 'order_state_events_select_scoped';

  IF v_policy_count <> 1 THEN
    RAISE EXCEPTION 'Missing order_state_events_select_scoped policy';
  END IF;

  IF has_table_privilege(
    'anon',
    'public.order_state_events',
    'SELECT'
  ) THEN
    RAISE EXCEPTION 'Anonymous users must not read order_state_events';
  END IF;

  IF has_table_privilege(
    'authenticated',
    'public.order_state_events',
    'INSERT'
  )
     OR has_table_privilege(
       'authenticated',
       'public.order_state_events',
       'UPDATE'
     )
     OR has_table_privilege(
       'authenticated',
       'public.order_state_events',
       'DELETE'
     ) THEN
    RAISE EXCEPTION 'Authenticated clients must not mutate order_state_events directly';
  END IF;

  v_transition_rpc := to_regprocedure(
    'public.venue_transition_order_status(uuid,text,text,jsonb)'
  );
  IF v_transition_rpc IS NULL THEN
    RAISE EXCEPTION 'Missing venue_transition_order_status RPC';
  END IF;

  IF NOT has_function_privilege(
    'authenticated',
    v_transition_rpc,
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'authenticated must be able to execute venue_transition_order_status';
  END IF;

  IF pg_get_functiondef(v_transition_rpc) !~ 'Reason is required'
     OR pg_get_functiondef(v_transition_rpc) !~ 'cancelled'
     OR pg_get_functiondef(v_transition_rpc) !~ 'refunded'
     OR pg_get_functiondef(v_transition_rpc) !~ 'disputed' THEN
    RAISE EXCEPTION 'venue_transition_order_status must require reasons for cancellation, refund, and dispute transitions';
  END IF;

  v_payment_rpc := to_regprocedure(
    'public.venue_update_order_payment_status(uuid,text,text,text,numeric,text)'
  );
  IF v_payment_rpc IS NULL THEN
    RAISE EXCEPTION 'Missing venue_update_order_payment_status RPC';
  END IF;

  IF NOT has_function_privilege(
    'authenticated',
    v_payment_rpc,
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'authenticated must be able to execute venue_update_order_payment_status';
  END IF;

  IF pg_get_functiondef(v_payment_rpc) !~ 'Unsupported payment method'
     OR pg_get_functiondef(v_payment_rpc) !~ 'payment_events'
     OR pg_get_functiondef(v_payment_rpc) !~ 'amount_received'
     OR pg_get_functiondef(v_payment_rpc) !~ 'order_total_amount'
     OR pg_get_functiondef(v_payment_rpc) !~ 'external_reference'
     OR pg_get_functiondef(v_payment_rpc) !~ 'provider_api_used'
     OR pg_get_functiondef(v_payment_rpc) !~ 'false'
     OR pg_get_functiondef(v_payment_rpc) !~ 'sports_bar_write_audit'
     OR pg_get_functiondef(v_payment_rpc) !~ 'Actor note is required' THEN
    RAISE EXCEPTION 'venue_update_order_payment_status must reject unsupported methods and write payment/audit evidence';
  END IF;
END $$;

SELECT 'order_lifecycle_deployment_readiness_passed' AS result;
