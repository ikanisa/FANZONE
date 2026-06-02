-- Non-mutating deployment readiness check for manual/off-platform payment
-- reconciliation. This verifies schema/RPC/grant shape only.

DO $$
DECLARE
  v_rpc regprocedure;
  v_def text;
BEGIN
  IF to_regclass('public.payment_events') IS NULL THEN
    RAISE EXCEPTION 'Missing public.payment_events';
  END IF;

  IF to_regclass('public.orders') IS NULL THEN
    RAISE EXCEPTION 'Missing public.orders';
  END IF;

  IF to_regclass('public.payment_events_created_at_idx') IS NULL THEN
    RAISE EXCEPTION 'Missing payment_events_created_at_idx';
  END IF;

  v_rpc := to_regprocedure(
    'public.venue_manual_payment_reconciliation(uuid,date)'
  );
  IF v_rpc IS NULL THEN
    RAISE EXCEPTION 'Missing venue_manual_payment_reconciliation RPC';
  END IF;

  IF has_function_privilege(
    'anon',
    v_rpc,
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'Anonymous users must not execute venue_manual_payment_reconciliation';
  END IF;

  IF NOT has_function_privilege(
    'authenticated',
    v_rpc,
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'Authenticated venue operators must be able to execute venue_manual_payment_reconciliation';
  END IF;

  v_def := pg_get_functiondef(v_rpc);

  IF v_def NOT ILIKE '%payment_events%'
     OR v_def NOT ILIKE '%orders%'
     OR v_def NOT ILIKE '%provider_api_used%'
     OR v_def NOT ILIKE '%amount_received%'
     OR v_def NOT ILIKE '%order_total_amount%'
     OR v_def NOT ILIKE '%external_reference%'
     OR v_def NOT ILIKE '%is_active_admin_operator%'
     OR v_def NOT ILIKE '%venue_user_has_role%'
     OR v_def NOT ILIKE '%Only venue operators can read payment reconciliation%' THEN
    RAISE EXCEPTION 'venue_manual_payment_reconciliation must be venue-scoped and based on payment event audit evidence';
  END IF;
END $$;

SELECT 'manual_payment_reconciliation_readiness_passed' AS result;
