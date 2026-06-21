\pset tuples_only on
\pset pager off

\echo 'Verifying venue chat contract...'

BEGIN;

DO $$
DECLARE
  v_manager uuid := '00000000-0000-4000-8000-000000000102'::uuid;
  v_staff uuid := '00000000-0000-4000-8000-000000000103'::uuid;
  v_guest uuid := '00000000-0000-4000-8000-000000000104'::uuid;
  v_other_guest uuid := '00000000-0000-4000-8000-000000000105'::uuid;
  v_venue uuid := '00000000-0000-4000-8000-000000000301'::uuid;
  v_order uuid := '00000000-0000-4000-8000-000000000306'::uuid;
  v_thread uuid;
  v_result jsonb;
BEGIN
  IF to_regprocedure('public.create_venue_chat_thread(uuid,text,text,text,uuid,uuid)') IS NULL THEN
    RAISE EXCEPTION 'Missing create_venue_chat_thread RPC';
  END IF;
  IF to_regprocedure('public.send_venue_chat_message(uuid,text)') IS NULL THEN
    RAISE EXCEPTION 'Missing send_venue_chat_message RPC';
  END IF;
  IF to_regprocedure('public.close_venue_chat_thread(uuid,text,text)') IS NULL THEN
    RAISE EXCEPTION 'Missing close_venue_chat_thread RPC';
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_guest::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_guest, 'role', 'authenticated')::text,
    true
  );

  v_result := public.create_venue_chat_thread(
    v_venue,
    'The table needs help with this order.',
    'order',
    'Order help',
    v_order,
    NULL
  );
  v_thread := (v_result -> 'thread' ->> 'id')::uuid;

  IF NOT EXISTS (
    SELECT 1
    FROM public.venue_chat_threads
    WHERE id = v_thread
      AND venue_id = v_venue
      AND customer_user_id = v_guest
      AND order_id = v_order
      AND status = 'open'
  ) THEN
    RAISE EXCEPTION 'Customer thread was not created correctly';
  END IF;

  IF (
    SELECT count(*)
    FROM public.venue_chat_messages
    WHERE thread_id = v_thread
      AND sender_user_id = v_guest
      AND sender_role = 'customer'
  ) <> 1 THEN
    RAISE EXCEPTION 'Initial customer message was not created';
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_staff::text, true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_staff, 'role', 'authenticated')::text,
    true
  );

  v_result := public.send_venue_chat_message(
    v_thread,
    'Staff received this. We are checking it now.'
  );

  IF (v_result -> 'message' ->> 'sender_role') <> 'venue_staff' THEN
    RAISE EXCEPTION 'Venue staff reply did not use venue_staff sender role';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.venue_chat_threads
    WHERE id = v_thread
      AND status = 'in_review'
  ) THEN
    RAISE EXCEPTION 'Staff reply did not move thread to in_review';
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_other_guest::text, true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_other_guest, 'role', 'authenticated')::text,
    true
  );

  BEGIN
    PERFORM public.send_venue_chat_message(
      v_thread,
      'This user should not be able to send here.'
    );
    RAISE EXCEPTION 'Unrelated user unexpectedly sent chat message';
  EXCEPTION
    WHEN raise_exception THEN
      IF SQLERRM NOT LIKE 'Only the customer or venue operators can send chat messages%' THEN
        RAISE;
      END IF;
  END;

  PERFORM set_config('request.jwt.claim.sub', v_manager::text, true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_manager, 'role', 'authenticated')::text,
    true
  );

  v_result := public.close_venue_chat_thread(
    v_thread,
    'resolved',
    'Staff verified the order support request.'
  );

  IF (v_result ->> 'status') <> 'resolved' THEN
    RAISE EXCEPTION 'Manager did not close chat as resolved';
  END IF;

  BEGIN
    PERFORM public.send_venue_chat_message(
      v_thread,
      'Closed thread should reject new replies.'
    );
    RAISE EXCEPTION 'Closed chat unexpectedly accepted a message';
  EXCEPTION
    WHEN raise_exception THEN
      IF SQLERRM NOT LIKE 'Chat thread is closed%' THEN
        RAISE;
      END IF;
  END;
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
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.venue_chat_threads
    WHERE customer_user_id = '00000000-0000-4000-8000-000000000104'::uuid
  ) THEN
    RAISE EXCEPTION 'RLS exposed another customer chat thread';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.venue_chat_messages
    WHERE sender_user_id = '00000000-0000-4000-8000-000000000104'::uuid
  ) THEN
    RAISE EXCEPTION 'RLS exposed another customer chat messages';
  END IF;
END $$;

RESET ROLE;

ROLLBACK;

\echo 'Venue chat contract verified'
