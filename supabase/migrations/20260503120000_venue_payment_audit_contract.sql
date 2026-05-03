ALTER TYPE public.payment_method ADD VALUE IF NOT EXISTS 'card';
ALTER TYPE public.payment_method ADD VALUE IF NOT EXISTS 'other';
ALTER TYPE public.venue_payment_status ADD VALUE IF NOT EXISTS 'payment_submitted';
ALTER TYPE public.order_status ADD VALUE IF NOT EXISTS 'preparing';

DROP FUNCTION IF EXISTS public.venue_update_order_payment_status(uuid, text, text, text);

CREATE OR REPLACE FUNCTION public.venue_update_order_payment_status(
  p_order_id uuid,
  p_payment_status text,
  p_payment_method text DEFAULT NULL::text,
  p_actor_note text DEFAULT NULL::text,
  p_amount_received numeric DEFAULT NULL::numeric,
  p_external_reference text DEFAULT NULL::text
) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_order public.orders%ROWTYPE;
  v_before jsonb;
  v_after jsonb;
  v_next_status text := lower(trim(coalesce(p_payment_status, '')));
  v_method text;
  v_amount_received numeric := p_amount_received;
  v_external_reference text := nullif(trim(coalesce(p_external_reference, '')), '');
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF v_next_status NOT IN (
    'unpaid',
    'payment_submitted',
    'paid',
    'partially_paid',
    'refunded',
    'disputed'
  ) THEN
    RAISE EXCEPTION 'Unsupported payment status';
  END IF;

  SELECT *
  INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF NOT public.venue_user_has_role(v_order.venue_id, ARRAY['owner', 'manager', 'staff']::public.venue_user_role[]) THEN
    RAISE EXCEPTION 'Only venue operators can update this order payment';
  END IF;

  IF v_order.status = 'cancelled' AND v_next_status = 'paid' THEN
    RAISE EXCEPTION 'Cannot mark a cancelled order paid';
  END IF;

  v_method := coalesce(nullif(lower(trim(p_payment_method)), ''), v_order.payment_method::text);

  IF v_method NOT IN ('cash', 'momo', 'revolut', 'card', 'other') THEN
    RAISE EXCEPTION 'Unsupported payment method';
  END IF;

  IF v_amount_received IS NULL THEN
    v_amount_received := v_order.total_amount;
  END IF;

  IF v_amount_received < 0 THEN
    RAISE EXCEPTION 'Amount received cannot be negative';
  END IF;

  v_before := to_jsonb(v_order);

  UPDATE public.orders
  SET payment_status = v_next_status::public.venue_payment_status,
      payment_method = v_method::public.payment_method,
      payment_reference = coalesce(v_external_reference, payment_reference),
      updated_at = timezone('utc', now())
  WHERE id = p_order_id
  RETURNING to_jsonb(orders.*) INTO v_after;

  INSERT INTO public.payment_events (
    order_id,
    provider,
    status,
    external_reference,
    request_payload,
    response_payload
  )
  VALUES (
    p_order_id,
    v_method::public.payment_method,
    v_next_status::public.venue_payment_status,
    v_external_reference,
    jsonb_build_object(
      'marked_by', auth.uid(),
      'note', p_actor_note,
      'before_status', v_order.payment_status,
      'after_status', v_next_status,
      'amount_received', v_amount_received,
      'order_total_amount', v_order.total_amount,
      'reference', v_external_reference
    ),
    jsonb_build_object('source', 'venue_update_order_payment_status', 'provider_api_used', false)
  );

  PERFORM public.sports_bar_write_audit(
    'venue_update_order_payment_status',
    'order',
    p_order_id::text,
    v_before,
    v_after
  );

  RETURN jsonb_build_object(
    'order_id', p_order_id,
    'payment_status', v_next_status,
    'payment_method', v_method,
    'amount_received', v_amount_received,
    'external_reference', v_external_reference
  );
END;
$$;

REVOKE ALL ON FUNCTION public.venue_update_order_payment_status(uuid, text, text, text, numeric, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.venue_update_order_payment_status(uuid, text, text, text, numeric, text) TO authenticated, service_role;

COMMENT ON FUNCTION public.venue_update_order_payment_status(uuid, text, text, text, numeric, text)
IS 'Venue-scoped manual payment update with amount/reference capture, payment_events logging, and audit log write. No payment provider API is called.';

