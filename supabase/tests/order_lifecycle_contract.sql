\pset tuples_only on
\pset pager off

\echo 'Verifying order lifecycle contract...'

BEGIN;

DO $$
DECLARE
  v_missing text[];
BEGIN
  SELECT array_agg(status)
  INTO v_missing
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
    WHERE t.typname = 'order_status'
      AND e.enumlabel = expected.status
  );

  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'Missing order_status enum values: %', v_missing;
  END IF;

  IF to_regclass('public.order_state_events') IS NULL THEN
    RAISE EXCEPTION 'Missing public.order_state_events';
  END IF;

  IF to_regprocedure('public.venue_transition_order_status(uuid,text,text,jsonb)') IS NULL THEN
    RAISE EXCEPTION 'Missing venue_transition_order_status RPC';
  END IF;
END $$;

DO $$
DECLARE
  v_manager uuid := '00000000-0000-4000-8000-000000000102'::uuid;
  v_guest uuid := '00000000-0000-4000-8000-000000000104'::uuid;
  v_order uuid := '00000000-0000-4000-8000-000000000307'::uuid;
  v_before_events integer;
  v_after_events integer;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', v_manager::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_manager, 'role', 'authenticated')::text,
    true
  );

  SELECT count(*)
  INTO v_before_events
  FROM public.order_state_events
  WHERE order_id = v_order;

  PERFORM public.venue_transition_order_status(
    v_order,
    'accepted',
    'contract test valid transition',
    '{"source":"order_lifecycle_contract"}'::jsonb
  );

  IF (SELECT status::text FROM public.orders WHERE id = v_order) <> 'accepted' THEN
    RAISE EXCEPTION 'Valid transition did not update order status';
  END IF;

  SELECT count(*)
  INTO v_after_events
  FROM public.order_state_events
  WHERE order_id = v_order;

  IF v_after_events <> v_before_events + 1 THEN
    RAISE EXCEPTION 'Expected exactly one order_state_events row, got % before and % after',
      v_before_events,
      v_after_events;
  END IF;

  BEGIN
    PERFORM public.venue_transition_order_status(
      v_order,
      'submitted',
      'contract test invalid transition',
      '{}'::jsonb
    );
    RAISE EXCEPTION 'Invalid status transition unexpectedly succeeded';
  EXCEPTION
    WHEN raise_exception THEN
      IF SQLERRM NOT LIKE 'Invalid order status transition:%' THEN
        RAISE;
      END IF;
  END;

  PERFORM set_config('request.jwt.claim.sub', v_guest::text, true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_guest, 'role', 'authenticated')::text,
    true
  );

  BEGIN
    PERFORM public.venue_transition_order_status(
      v_order,
      'preparing',
      'customer should not mutate',
      '{}'::jsonb
    );
    RAISE EXCEPTION 'Customer transition unexpectedly succeeded';
  EXCEPTION
    WHEN raise_exception THEN
      IF SQLERRM NOT LIKE 'Only venue operators can transition this order%' THEN
        RAISE;
      END IF;
  END;

  PERFORM set_config('request.jwt.claim.sub', v_manager::text, true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_manager, 'role', 'authenticated')::text,
    true
  );

  BEGIN
    PERFORM public.venue_update_order_payment_status(
      v_order,
      'paid',
      'card',
      'card should remain unsupported',
      4.50,
      'CARD-REJECT'
    );
    RAISE EXCEPTION 'Unsupported card payment unexpectedly succeeded';
  EXCEPTION
    WHEN raise_exception THEN
      IF SQLERRM NOT LIKE 'Unsupported payment method%' THEN
        RAISE;
      END IF;
  END;
END $$;

ROLLBACK;

\echo 'Order lifecycle contract verified.'
