CREATE OR REPLACE FUNCTION public.user_submit_order_payment(
  p_order_id uuid,
  p_payment_method text DEFAULT NULL::text,
  p_external_reference text DEFAULT NULL::text,
  p_actor_note text DEFAULT NULL::text
) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_order public.orders%ROWTYPE;
  v_before jsonb;
  v_after jsonb;
  v_method text;
  v_reference text := nullif(trim(coalesce(p_external_reference, '')), '');
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT *
  INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF v_order.user_id <> auth.uid() THEN
    RAISE EXCEPTION 'Users can only submit payment for their own orders';
  END IF;

  IF v_order.status = 'cancelled' THEN
    RAISE EXCEPTION 'Cannot submit payment for a cancelled order';
  END IF;

  IF v_order.payment_status::text IN ('paid', 'refunded', 'disputed') THEN
    RETURN jsonb_build_object(
      'order_id', p_order_id,
      'payment_status', v_order.payment_status::text,
      'payment_method', v_order.payment_method::text,
      'unchanged', true
    );
  END IF;

  v_method := coalesce(nullif(lower(trim(p_payment_method)), ''), v_order.payment_method::text);
  IF v_method NOT IN ('momo', 'revolut', 'cash', 'card', 'other') THEN
    RAISE EXCEPTION 'Unsupported payment method';
  END IF;

  v_before := to_jsonb(v_order);

  UPDATE public.orders
  SET payment_status = 'payment_submitted'::public.venue_payment_status,
      payment_method = v_method::public.payment_method,
      payment_reference = coalesce(v_reference, payment_reference),
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
    'payment_submitted'::public.venue_payment_status,
    v_reference,
    jsonb_build_object(
      'submitted_by', auth.uid(),
      'note', p_actor_note,
      'before_status', v_order.payment_status,
      'after_status', 'payment_submitted',
      'reference', v_reference,
      'source', 'customer_app'
    ),
    jsonb_build_object('source', 'user_submit_order_payment', 'provider_api_used', false)
  );

  PERFORM public.sports_bar_write_audit(
    'user_submit_order_payment',
    'order',
    p_order_id::text,
    v_before,
    v_after
  );

  RETURN jsonb_build_object(
    'order_id', p_order_id,
    'payment_status', 'payment_submitted',
    'payment_method', v_method,
    'external_reference', v_reference
  );
END;
$$;

REVOKE ALL ON FUNCTION public.user_submit_order_payment(uuid, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.user_submit_order_payment(uuid, text, text, text) TO authenticated, service_role;

COMMENT ON FUNCTION public.user_submit_order_payment(uuid, text, text, text)
IS 'Customer-owned external payment submission marker. It never marks an order paid; venue staff must confirm payment through audited staff payment flows.';
