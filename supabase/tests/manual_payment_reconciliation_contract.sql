\pset tuples_only on
\pset pager off

\echo 'Verifying manual payment reconciliation contract...'

BEGIN;

DO $$
DECLARE
  v_manager uuid := '00000000-0000-4000-8000-000000000102'::uuid;
  v_guest uuid := '00000000-0000-4000-8000-000000000104'::uuid;
  v_venue uuid := '00000000-0000-4000-8000-000000000301'::uuid;
  v_table uuid := '00000000-0000-4000-8000-000000000302'::uuid;
  v_order uuid := '00000000-0000-4000-8000-000000009421'::uuid;
  v_event uuid := '00000000-0000-4000-8000-000000009422'::uuid;
  v_other_venue uuid := '00000000-0000-4000-8000-000000009431'::uuid;
  v_business_date date := timezone('utc'::text, now())::date;
  v_summary record;
BEGIN
  IF to_regprocedure('public.venue_manual_payment_reconciliation(uuid,date)') IS NULL THEN
    RAISE EXCEPTION 'Missing venue_manual_payment_reconciliation RPC';
  END IF;

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
    v_order,
    v_venue,
    v_table,
    v_guest,
    'RECON001',
    'served',
    'cash',
    'paid',
    'EUR',
    4.50,
    0,
    0,
    4.50
  );

  INSERT INTO public.payment_events (
    id,
    order_id,
    provider,
    status,
    external_reference,
    request_payload,
    response_payload,
    created_at
  )
  VALUES (
    v_event,
    v_order,
    'cash',
    'paid',
    'CONTRACT-RECON-CASH',
    jsonb_build_object(
      'marked_by', v_manager,
      'note', 'contract reconciliation cash confirmation',
      'amount_received', 4.50,
      'order_total_amount', 4.50
    ),
    jsonb_build_object(
      'source', 'venue_update_order_payment_status',
      'provider_api_used', false
    ),
    timezone('utc', now())
  );

  PERFORM set_config('request.jwt.claim.sub', v_manager::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_manager, 'role', 'authenticated')::text,
    true
  );

  SELECT *
  INTO v_summary
  FROM public.venue_manual_payment_reconciliation(v_venue, v_business_date)
  WHERE payment_method = 'cash'
    AND payment_status = 'paid'
    AND provider_api_used = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Manual reconciliation did not return the cash paid summary row';
  END IF;

  IF v_summary.business_date <> v_business_date THEN
    RAISE EXCEPTION 'Manual reconciliation returned wrong business date';
  END IF;

  IF v_summary.amount_received < 4.50 THEN
    RAISE EXCEPTION 'Manual reconciliation did not include amount_received evidence';
  END IF;

  IF v_summary.order_total_amount < 4.50 THEN
    RAISE EXCEPTION 'Manual reconciliation did not include order_total_amount evidence';
  END IF;

  IF v_summary.external_reference_count < 1 THEN
    RAISE EXCEPTION 'Manual reconciliation did not include external reference evidence';
  END IF;

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
    'Contract Reconciliation Isolation Bar',
    'contract-reconciliation-isolation-bar',
    'MT',
    'bar',
    'EUR',
    true,
    'active'
  );

  BEGIN
    PERFORM public.venue_manual_payment_reconciliation(
      v_other_venue,
      v_business_date
    );
    RAISE EXCEPTION 'Cross-venue reconciliation unexpectedly succeeded';
  EXCEPTION
    WHEN raise_exception THEN
      IF SQLERRM NOT LIKE 'Only venue operators can read payment reconciliation%' THEN
        RAISE;
      END IF;
  END;
END $$;

ROLLBACK;

\echo 'Manual payment reconciliation contract verified'
