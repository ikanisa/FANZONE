\pset tuples_only on
\pset pager off

\echo 'Verifying staff-call acknowledgement contract...'

BEGIN;

DO $$
DECLARE
  v_manager uuid := '00000000-0000-4000-8000-000000000102'::uuid;
  v_staff uuid := '00000000-0000-4000-8000-000000000103'::uuid;
  v_guest uuid := '00000000-0000-4000-8000-000000000104'::uuid;
  v_venue uuid := '00000000-0000-4000-8000-000000000301'::uuid;
  v_table uuid := '00000000-0000-4000-8000-000000000302'::uuid;
  v_bell uuid := '00000000-0000-4000-8000-000000009401'::uuid;
  v_other_venue uuid := '00000000-0000-4000-8000-000000009411'::uuid;
  v_other_table uuid := '00000000-0000-4000-8000-000000009412'::uuid;
  v_other_bell uuid := '00000000-0000-4000-8000-000000009413'::uuid;
  v_before_audit integer;
  v_after_audit integer;
  v_result jsonb;
BEGIN
  IF to_regprocedure('public.venue_acknowledge_bell_request(uuid)') IS NULL THEN
    RAISE EXCEPTION 'Missing venue_acknowledge_bell_request RPC';
  END IF;

  INSERT INTO public.bell_requests (
    id,
    venue_id,
    table_id,
    user_id,
    message
  )
  VALUES (
    v_bell,
    v_venue,
    v_table,
    v_guest,
    'Contract test: order issue needs staff.'
  );

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
    'Contract Bell Isolation Bar',
    'contract-bell-isolation-bar',
    'MT',
    'bar',
    'EUR',
    true,
    'active'
  );

  INSERT INTO public.tables (id, venue_id, table_number, is_active)
  VALUES (v_other_table, v_other_venue, 'BELL-ISO-1', true);

  INSERT INTO public.bell_requests (
    id,
    venue_id,
    table_id,
    user_id,
    message
  )
  VALUES (
    v_other_bell,
    v_other_venue,
    v_other_table,
    v_guest,
    'Contract test: cross-venue staff should not acknowledge.'
  );

  PERFORM set_config('request.jwt.claim.sub', v_manager::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_manager, 'role', 'authenticated')::text,
    true
  );

  SELECT count(*)
  INTO v_before_audit
  FROM public.audit_logs
  WHERE action = 'venue_acknowledge_bell_request'
    AND (
      (
        to_jsonb(audit_logs) ? 'entity_type'
        AND to_jsonb(audit_logs) ->> 'entity_type' = 'bell_request'
        AND to_jsonb(audit_logs) ->> 'entity_id' = v_bell::text
      )
      OR (
        to_jsonb(audit_logs) ? 'details_json'
        AND to_jsonb(audit_logs) -> 'details_json' ->> 'entity_type' = 'bell_request'
        AND to_jsonb(audit_logs) -> 'details_json' ->> 'entity_id' = v_bell::text
      )
    );

  v_result := public.venue_acknowledge_bell_request(v_bell);

  IF (v_result ->> 'id')::uuid <> v_bell THEN
    RAISE EXCEPTION 'Acknowledgement RPC returned wrong bell id';
  END IF;

  IF coalesce((v_result ->> 'already_acknowledged')::boolean, true) IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'First acknowledgement should not be marked already acknowledged';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.bell_requests
    WHERE id = v_bell
      AND acknowledged_by = v_manager
      AND acknowledged_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'Staff-call acknowledgement did not update bell request';
  END IF;

  SELECT count(*)
  INTO v_after_audit
  FROM public.audit_logs
  WHERE action = 'venue_acknowledge_bell_request'
    AND (
      (
        to_jsonb(audit_logs) ? 'entity_type'
        AND to_jsonb(audit_logs) ->> 'entity_type' = 'bell_request'
        AND to_jsonb(audit_logs) ->> 'entity_id' = v_bell::text
      )
      OR (
        to_jsonb(audit_logs) ? 'details_json'
        AND to_jsonb(audit_logs) -> 'details_json' ->> 'entity_type' = 'bell_request'
        AND to_jsonb(audit_logs) -> 'details_json' ->> 'entity_id' = v_bell::text
      )
    );

  IF v_after_audit <> v_before_audit + 1 THEN
    RAISE EXCEPTION 'Expected one staff-call audit event, got % before and % after',
      v_before_audit,
      v_after_audit;
  END IF;

  v_result := public.venue_acknowledge_bell_request(v_bell);
  IF coalesce((v_result ->> 'already_acknowledged')::boolean, false) IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Second acknowledgement should be idempotent';
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_staff::text, true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_staff, 'role', 'authenticated')::text,
    true
  );

  BEGIN
    PERFORM public.venue_acknowledge_bell_request(v_other_bell);
    RAISE EXCEPTION 'Cross-venue staff acknowledgement unexpectedly succeeded';
  EXCEPTION
    WHEN raise_exception THEN
      IF SQLERRM NOT LIKE 'Only venue operators can acknowledge staff calls%' THEN
        RAISE;
      END IF;
  END;
END $$;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000102', true);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
SELECT set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub',
    '00000000-0000-4000-8000-000000000102',
    'role',
    'authenticated'
  )::text,
  true
);

DO $$
DECLARE
  v_bell uuid := '00000000-0000-4000-8000-000000009401'::uuid;
BEGIN
  BEGIN
    UPDATE public.bell_requests
    SET acknowledged_at = timezone('utc', now()),
        acknowledged_by = auth.uid()
    WHERE id = v_bell;
    RAISE EXCEPTION 'Direct authenticated bell_requests UPDATE unexpectedly succeeded';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
  END;
END $$;

RESET ROLE;

ROLLBACK;

\echo 'Staff-call acknowledgement contract verified'
