\pset tuples_only on
\pset pager off

\echo 'Verifying mobile wallet payment-confirmation UAT contract...'

DO $$
DECLARE
  v_manager uuid := extensions.gen_random_uuid();
  v_guest uuid := extensions.gen_random_uuid();
  v_venue uuid := extensions.gen_random_uuid();
  v_table uuid := extensions.gen_random_uuid();
  v_order uuid := extensions.gen_random_uuid();
  v_order_code text;
  v_payment_reference text;
  v_before jsonb;
  v_after jsonb;
  v_payment_event_id uuid;
  v_audit_id uuid;
  v_wallet_tx_id uuid;
  v_fet_earned bigint;
  v_before_available bigint;
  v_after_available bigint;
BEGIN
  v_order_code := 'MOBWAL' || upper(substr(replace(v_order::text, '-', ''), 1, 6));
  v_payment_reference := 'MOB-WALLET-UAT-' || v_order_code;

  INSERT INTO auth.users (
    id,
    aud,
    role,
    phone,
    phone_confirmed_at,
    created_at,
    updated_at,
    raw_app_meta_data,
    raw_user_meta_data
  )
  VALUES
    (
      v_manager,
      'authenticated',
      'authenticated',
      '+356' || substr(replace(v_manager::text, '-', ''), 1, 8),
      timezone('utc', now()),
      timezone('utc', now()),
      timezone('utc', now()),
      '{}'::jsonb,
      '{}'::jsonb
    ),
    (
      v_guest,
      'authenticated',
      'authenticated',
      '+356' || substr(replace(v_guest::text, '-', ''), 1, 8),
      timezone('utc', now()),
      timezone('utc', now()),
      timezone('utc', now()),
      '{}'::jsonb,
      '{}'::jsonb
    );

  UPDATE public.profiles
  SET display_name = CASE
        WHEN id = v_manager THEN 'Wallet Manager'
        ELSE 'Wallet Guest'
      END,
      updated_at = timezone('utc', now())
  WHERE id IN (v_manager, v_guest);

  INSERT INTO public.venues (
    id,
    owner_id,
    name,
    slug,
    country_code,
    venue_type,
    currency_code,
    is_active,
    status,
    features_json
  )
  VALUES (
    v_venue,
    v_manager,
    'Mobile Wallet UAT Bar',
    'mobile-wallet-uat-' || lower(substr(replace(v_venue::text, '-', ''), 1, 8)),
    'MT',
    'bar',
    'EUR',
    true,
    'active',
    jsonb_build_object('fet_reward_percent', 4, 'fet_reward_trigger', 'paid')
  );

  INSERT INTO public.venue_users (venue_id, user_id, role, is_active)
  VALUES (v_venue, v_manager, 'manager', true)
  ON CONFLICT (venue_id, user_id) DO UPDATE
  SET role = EXCLUDED.role,
      is_active = true,
      updated_at = timezone('utc', now());

  INSERT INTO public.tables (id, venue_id, table_number)
  VALUES (v_table, v_venue, 'UAT-WALLET-1');

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
    v_order_code,
    'received',
    'cash',
    'unpaid',
    'EUR',
    10,
    0,
    0,
    10
  );

  PERFORM set_config('request.jwt.claim.sub', v_manager::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_manager, 'role', 'authenticated')::text,
    true
  );

  PERFORM set_config('request.jwt.claim.sub', v_guest::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_guest, 'role', 'authenticated')::text,
    true
  );

  v_before := public.get_wallet_balance(v_guest);
  v_before_available := (v_before ->> 'available_fet')::bigint;

  IF v_before_available < 0 THEN
    RAISE EXCEPTION 'Expected non-negative initial available FET, got %', v_before;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_manager::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_manager, 'role', 'authenticated')::text,
    true
  );

  PERFORM public.venue_update_order_payment_status(
    v_order,
    'paid',
    'cash',
    'Mobile wallet UAT manual cash confirmation',
    10,
    v_payment_reference
  );

  SELECT payment_status::text, fet_earned
  INTO STRICT v_payment_reference, v_fet_earned
  FROM public.orders
  WHERE id = v_order;

  IF v_payment_reference <> 'paid' THEN
    RAISE EXCEPTION 'Order % was not marked paid', v_order_code;
  END IF;

  IF v_fet_earned <> 40 THEN
    RAISE EXCEPTION 'Expected order fet_earned 40, got %', v_fet_earned;
  END IF;

  SELECT id
  INTO v_payment_event_id
  FROM public.payment_events
  WHERE order_id = v_order
    AND status = 'paid'
    AND provider = 'cash'
    AND request_payload ->> 'note' = 'Mobile wallet UAT manual cash confirmation'
    AND response_payload ->> 'provider_api_used' = 'false'
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_payment_event_id IS NULL THEN
    RAISE EXCEPTION 'Missing manual payment event evidence for %', v_order_code;
  END IF;

  SELECT id
  INTO v_audit_id
  FROM public.audit_logs
  WHERE action = 'venue_update_order_payment_status'
    AND (
      (
        to_jsonb(audit_logs) ? 'entity_type'
        AND to_jsonb(audit_logs) ->> 'entity_type' = 'order'
        AND to_jsonb(audit_logs) ->> 'entity_id' = v_order::text
        AND to_jsonb(audit_logs) ->> 'actor_user_id' = v_manager::text
      )
      OR (
        to_jsonb(audit_logs) ? 'details_json'
        AND to_jsonb(audit_logs) -> 'details_json' ->> 'entity_type' = 'order'
        AND to_jsonb(audit_logs) -> 'details_json' ->> 'entity_id' = v_order::text
        AND to_jsonb(audit_logs) ->> 'actor_id' = v_manager::text
      )
    )
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_audit_id IS NULL THEN
    RAISE EXCEPTION 'Missing audit evidence for %', v_order_code;
  END IF;

  SELECT id
  INTO v_wallet_tx_id
  FROM public.fet_wallet_transactions
  WHERE user_id = v_guest
    AND order_id = v_order
    AND venue_id = v_venue
    AND transaction_type = 'order_earn'
    AND direction = 'credit'
    AND amount_fet = 40
    AND idempotency_key = 'order_earn:' || v_order::text
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_wallet_tx_id IS NULL THEN
    RAISE EXCEPTION 'Missing order_earn wallet ledger row for %', v_order_code;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_guest::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_guest, 'role', 'authenticated')::text,
    true
  );

  v_after := public.get_wallet_balance(v_guest);
  v_after_available := (v_after ->> 'available_fet')::bigint;

  IF v_after_available <> v_before_available + 40 THEN
    RAISE EXCEPTION 'Expected available FET to increase by 40 after paid confirmation, before %, after %', v_before, v_after;
  END IF;

  RAISE NOTICE 'MOB-WALLET-001 order_code=% payment_event_id=% audit_id=% wallet_tx_id=% wallet_before=% wallet_after=%',
    v_order_code,
    v_payment_event_id,
    v_audit_id,
    v_wallet_tx_id,
    v_before,
    v_after;

  PERFORM set_config('fanzone_uat.order_code', v_order_code, false);
  PERFORM set_config('fanzone_uat.payment_event_id', v_payment_event_id::text, false);
  PERFORM set_config('fanzone_uat.audit_id', v_audit_id::text, false);
  PERFORM set_config('fanzone_uat.wallet_tx_id', v_wallet_tx_id::text, false);
  PERFORM set_config('fanzone_uat.wallet_before', v_before::text, false);
  PERFORM set_config('fanzone_uat.wallet_after', v_after::text, false);
END $$;

SELECT
  'MOB-WALLET-001' AS flow_id,
  current_setting('fanzone_uat.order_code', true) AS order_code,
  current_setting('fanzone_uat.payment_event_id', true) AS payment_event_id,
  current_setting('fanzone_uat.audit_id', true) AS audit_id,
  current_setting('fanzone_uat.wallet_tx_id', true) AS wallet_tx_id,
  current_setting('fanzone_uat.wallet_before', true) AS wallet_before,
  current_setting('fanzone_uat.wallet_after', true) AS wallet_after;

\echo 'Mobile wallet payment-confirmation UAT contract verified'
