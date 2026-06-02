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
  v_staff uuid := '00000000-0000-4000-8000-000000000103'::uuid;
  v_guest uuid := '00000000-0000-4000-8000-000000000104'::uuid;
  v_order uuid := '00000000-0000-4000-8000-000000000307'::uuid;
  v_other_venue uuid := '00000000-0000-4000-8000-000000009301'::uuid;
  v_other_table uuid := '00000000-0000-4000-8000-000000009302'::uuid;
  v_other_order uuid := '00000000-0000-4000-8000-000000009307'::uuid;
  v_before_events integer;
  v_after_events integer;
  v_before_payment_events integer;
  v_after_payment_events integer;
  v_matching_payment_events integer;
  v_before_audit_events integer;
  v_after_audit_events integer;
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

  BEGIN
    PERFORM public.venue_transition_order_status(
      v_order,
      'cancelled',
      NULL,
      '{}'::jsonb
    );
    RAISE EXCEPTION 'Reasonless cancellation unexpectedly succeeded';
  EXCEPTION
    WHEN raise_exception THEN
      IF SQLERRM NOT LIKE 'Reason is required for cancelled order transitions%' THEN
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

  INSERT INTO public.venues (
    id,
    name,
    slug,
    country_code,
    venue_type,
    currency_code,
    is_active,
    status
  )
  VALUES (
    v_other_venue,
    'Contract Isolation Bar',
    'contract-isolation-bar',
    'MT',
    'bar',
    'EUR',
    true,
    'active'
  );

  INSERT INTO public.tables (id, venue_id, table_number, is_active)
  VALUES (v_other_table, v_other_venue, 'ISO-1', true);

  INSERT INTO public.orders (
    id,
    venue_id,
    table_id,
    user_id,
    order_code,
    status,
    payment_method,
    payment_status,
    currency_code,
    subtotal_amount,
    tax_amount,
    tip_amount,
    total_amount
  )
  VALUES (
    v_other_order,
    v_other_venue,
    v_other_table,
    v_guest,
    'ISOORDER1',
    'submitted',
    'cash',
    'unpaid',
    'EUR',
    5.00,
    0,
    0,
    5.00
  );

  PERFORM set_config('request.jwt.claim.sub', v_staff::text, true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_staff, 'role', 'authenticated')::text,
    true
  );

  BEGIN
    PERFORM public.venue_transition_order_status(
      v_other_order,
      'accepted',
      'cross venue staff should not mutate',
      '{}'::jsonb
    );
    RAISE EXCEPTION 'Cross-venue staff transition unexpectedly succeeded';
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

  SELECT count(*)
  INTO v_before_payment_events
  FROM public.payment_events
  WHERE order_id = v_order;

  BEGIN
    PERFORM public.venue_update_order_payment_status(
      v_order,
      'paid',
      'cash',
      NULL,
      4.50,
      'CONTRACT-NOTE-REJECT'
    );
    RAISE EXCEPTION 'Manual payment without actor note unexpectedly succeeded';
  EXCEPTION
    WHEN raise_exception THEN
      IF SQLERRM NOT LIKE 'Actor note is required for manual payment status paid%' THEN
        RAISE;
      END IF;
  END;

  SELECT count(*)
  INTO v_before_audit_events
  FROM public.audit_logs
  WHERE action = 'venue_update_order_payment_status'
    AND entity_type = 'order'
    AND entity_id = v_order::text;

  PERFORM public.venue_update_order_payment_status(
    v_order,
    'paid',
    'cash',
    'contract test manual cash confirmation',
    4.50,
    'CONTRACT-CASH-PAID'
  );

  IF (
    SELECT payment_status::text
    FROM public.orders
    WHERE id = v_order
  ) <> 'paid' THEN
    RAISE EXCEPTION 'Manual payment confirmation did not update payment status';
  END IF;

  SELECT count(*)
  INTO v_after_payment_events
  FROM public.payment_events
  WHERE order_id = v_order;

  IF v_after_payment_events <> v_before_payment_events + 1 THEN
    RAISE EXCEPTION 'Expected one additional manual payment event, got % before and % after',
      v_before_payment_events,
      v_after_payment_events;
  END IF;

  SELECT count(*)
  INTO v_matching_payment_events
  FROM public.payment_events
  WHERE order_id = v_order
    AND external_reference = 'CONTRACT-CASH-PAID'
    AND request_payload ->> 'marked_by' = v_manager::text
    AND response_payload ->> 'provider_api_used' = 'false';

  IF v_matching_payment_events <> 1 THEN
    RAISE EXCEPTION 'Expected one matching manual payment event, got %',
      v_matching_payment_events;
  END IF;

  SELECT count(*)
  INTO v_after_audit_events
  FROM public.audit_logs
  WHERE action = 'venue_update_order_payment_status'
    AND entity_type = 'order'
    AND entity_id = v_order::text;

  IF v_after_audit_events <> v_before_audit_events + 1 THEN
    RAISE EXCEPTION 'Expected one manual payment audit event, got % before and % after',
      v_before_audit_events,
      v_after_audit_events;
  END IF;
END $$;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000105', true);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
SELECT set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub',
    '00000000-0000-4000-8000-000000000105',
    'role',
    'authenticated'
  )::text,
  true
);

DO $$
DECLARE
  v_order uuid := '00000000-0000-4000-8000-000000000307'::uuid;
  v_visible_events integer;
BEGIN
  SELECT count(*)
  INTO v_visible_events
  FROM public.order_state_events
  WHERE order_id = v_order;

  IF v_visible_events < 1 THEN
    RAISE EXCEPTION 'Customer cannot read their own order_state_events';
  END IF;

  BEGIN
    INSERT INTO public.order_state_events (
      order_id,
      venue_id,
      actor_user_id,
      previous_status,
      next_status,
      reason,
      source
    )
    VALUES (
      v_order,
      '00000000-0000-4000-8000-000000000301'::uuid,
      auth.uid(),
      'accepted',
      'preparing',
      'customer should not insert lifecycle event',
      'contract_test_customer_insert'
    );
    RAISE EXCEPTION 'Customer inserted order_state_events unexpectedly';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
  END;
END $$;

RESET ROLE;

ROLLBACK;

\echo 'Order lifecycle contract verified.'
