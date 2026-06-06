-- Keep paid-order reward reconciliation visible on the order row.
-- The wallet ledger remains the source of truth; this denormalized field lets
-- mobile receipts and venue UAT evidence show the credited reward directly.

CREATE OR REPLACE FUNCTION public.credit_fet_for_order(
  p_order_id uuid,
  p_idempotency_key text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_order public.orders%ROWTYPE;
  v_venue public.venues%ROWTYPE;
  v_percent numeric := 0;
  v_amount bigint := 0;
  v_result jsonb;
  v_result_amount bigint := 0;
BEGIN
  SELECT *
  INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF v_order.status::text = 'cancelled'
     OR v_order.payment_status::text NOT IN ('paid', 'partially_paid') THEN
    RETURN jsonb_build_object(
      'status', 'skipped',
      'reason', 'order_not_paid',
      'order_id', p_order_id
    );
  END IF;

  SELECT *
  INTO v_venue
  FROM public.venues
  WHERE id = v_order.venue_id;

  v_percent := coalesce(
    nullif(v_venue.features_json ->> 'fet_reward_percent', '')::numeric,
    v_venue.fet_reward_percent,
    public.app_config_numeric('order_reward_percent_default', 0),
    0
  );
  v_amount := floor(coalesce(v_order.total_amount, 0) * greatest(v_percent, 0))::bigint;

  IF v_amount <= 0 THEN
    RETURN jsonb_build_object(
      'status', 'skipped',
      'reason', 'zero_reward',
      'order_id', p_order_id
    );
  END IF;

  v_result := public.wallet_post_transaction(
    p_user_id => v_order.user_id,
    p_transaction_type => 'order_earn',
    p_direction => 'credit',
    p_amount_fet => v_amount,
    p_balance_bucket => 'available',
    p_idempotency_key => coalesce(p_idempotency_key, 'order_earn:' || p_order_id::text),
    p_reference_type => 'order_reward',
    p_reference_id => p_order_id::text,
    p_title => 'Venue order reward',
    p_order_id => p_order_id,
    p_venue_id => v_order.venue_id,
    p_metadata => jsonb_build_object('reward_percent', v_percent)
  );

  v_result_amount := COALESCE((v_result ->> 'amount_fet')::bigint, v_amount);

  UPDATE public.orders
  SET fet_earned = GREATEST(coalesce(fet_earned, 0), v_result_amount),
      updated_at = timezone('utc', now())
  WHERE id = p_order_id;

  RETURN v_result || jsonb_build_object('order_fet_earned', v_result_amount);
END;
$$;

REVOKE ALL ON FUNCTION public.credit_fet_for_order(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.credit_fet_for_order(uuid, text) TO service_role;

COMMENT ON FUNCTION public.credit_fet_for_order(uuid, text) IS
  'Backend-only order reward helper. Credits the wallet ledger for paid orders and mirrors the credited FET amount onto orders.fet_earned for receipt/reconciliation evidence.';
