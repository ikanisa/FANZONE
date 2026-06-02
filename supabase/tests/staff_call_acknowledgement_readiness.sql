-- Non-mutating deployment readiness check for audited staff-call
-- acknowledgement. This verifies schema/RPC/grant shape only.

DO $$
DECLARE
  v_rpc regprocedure;
  v_def text;
BEGIN
  IF to_regclass('public.bell_requests') IS NULL THEN
    RAISE EXCEPTION 'Missing public.bell_requests';
  END IF;

  IF has_table_privilege(
    'authenticated',
    'public.bell_requests',
    'UPDATE'
  ) THEN
    RAISE EXCEPTION 'Authenticated clients must acknowledge bell_requests through venue_acknowledge_bell_request, not direct table UPDATE grants';
  END IF;

  v_rpc := to_regprocedure(
    'public.venue_acknowledge_bell_request(uuid)'
  );
  IF v_rpc IS NULL THEN
    RAISE EXCEPTION 'Missing venue_acknowledge_bell_request RPC';
  END IF;

  IF has_function_privilege(
    'anon',
    v_rpc,
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'Anonymous users must not execute venue_acknowledge_bell_request';
  END IF;

  IF NOT has_function_privilege(
    'authenticated',
    v_rpc,
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'Authenticated venue operators must be able to execute venue_acknowledge_bell_request';
  END IF;

  v_def := pg_get_functiondef(v_rpc);

  IF v_def NOT ILIKE '%bell_requests%'
     OR v_def NOT ILIKE '%FOR UPDATE%'
     OR v_def NOT ILIKE '%acknowledged_at%'
     OR v_def NOT ILIKE '%acknowledged_by%'
     OR v_def NOT ILIKE '%is_active_admin_operator%'
     OR v_def NOT ILIKE '%venue_user_has_role%'
     OR v_def NOT ILIKE '%sports_bar_write_audit%'
     OR v_def NOT ILIKE '%Only venue operators can acknowledge staff calls%' THEN
    RAISE EXCEPTION 'venue_acknowledge_bell_request must be venue-scoped, locked, and audited';
  END IF;
END $$;

SELECT 'staff_call_acknowledgement_readiness_passed' AS result;
