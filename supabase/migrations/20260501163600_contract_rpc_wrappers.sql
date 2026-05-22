-- Non-destructive compatibility layer for the simplified sports-bar contract.
-- These wrappers expose the product-facing RPC names while reusing the
-- existing match_pool, wallet, order payment, and table runtime tables.

CREATE OR REPLACE VIEW public.venue_tables
WITH (security_invoker = true) AS
SELECT
  t.id,
  t.venue_id,
  t.table_number,
  t.is_active,
  t.created_at,
  t.updated_at
FROM public.tables t;

COMMENT ON VIEW public.venue_tables IS
  'Canonical venue table contract view over public.tables.';

CREATE OR REPLACE FUNCTION public.stake_fet(
  p_pool_id uuid,
  p_camp_id uuid,
  p_stake_amount bigint,
  p_source text DEFAULT 'direct'::text,
  p_invite_code text DEFAULT NULL::text
) RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT public.join_pool(p_pool_id, p_camp_id, p_stake_amount, p_source, p_invite_code);
$$;

COMMENT ON FUNCTION public.stake_fet(uuid, uuid, bigint, text, text) IS
  'Product-facing wrapper for wallet-backed pool staking. Delegates to join_pool.';

CREATE OR REPLACE FUNCTION public.spend_fet_on_order(
  p_order_id uuid,
  p_amount_fet bigint,
  p_idempotency_key text DEFAULT NULL::text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_is_service_role boolean := coalesce(auth.role(), '') = 'service_role';
  v_order public.orders%ROWTYPE;
  v_config_accepts_fet boolean;
  v_key text;
  v_existing public.fet_wallet_transactions%ROWTYPE;
  v_result jsonb;
BEGIN
  IF p_amount_fet IS NULL OR p_amount_fet <= 0 THEN
    RAISE EXCEPTION 'FET amount must be greater than zero';
  END IF;

  SELECT *
  INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF v_user_id IS NULL AND NOT v_is_service_role THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT v_is_service_role AND v_order.user_id IS DISTINCT FROM v_user_id THEN
    RAISE EXCEPTION 'Users can only spend FET on their own orders';
  END IF;

  IF v_order.status::text = 'cancelled'
     OR v_order.payment_status::text IN ('cancelled', 'refunded') THEN
    RAISE EXCEPTION 'Cancelled or refunded orders cannot use FET';
  END IF;

  SELECT coalesce(v.accepts_fet_spend, false)
  INTO v_config_accepts_fet
  FROM public.venues v
  WHERE v.id = v_order.venue_id;

  IF NOT coalesce(v_config_accepts_fet, false) THEN
    RAISE EXCEPTION 'This venue does not accept FET spending';
  END IF;

  v_user_id := coalesce(v_user_id, v_order.user_id);
  v_key := coalesce(
    nullif(trim(p_idempotency_key), ''),
    'order_spend:' || p_order_id::text || ':' || v_user_id::text || ':' || p_amount_fet::text
  );

  SELECT *
  INTO v_existing
  FROM public.fet_wallet_transactions
  WHERE idempotency_key = v_key
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'status', 'already_spent',
      'transaction_id', v_existing.id,
      'order_id', p_order_id,
      'amount_fet', v_existing.amount_fet
    );
  END IF;

  v_result := public.wallet_post_transaction(
    p_user_id => v_user_id,
    p_transaction_type => 'order_spend',
    p_direction => 'debit',
    p_amount_fet => p_amount_fet,
    p_balance_bucket => 'available',
    p_idempotency_key => v_key,
    p_reference_type => 'order',
    p_reference_id => p_order_id::text,
    p_title => 'FET spent on bar order',
    p_metadata => jsonb_build_object(
      'currency_code', v_order.currency_code,
      'source', 'spend_fet_on_order'
    ),
    p_order_id => p_order_id,
    p_venue_id => v_order.venue_id
  );

  UPDATE public.orders
  SET payment_fet_amount = coalesce(payment_fet_amount, 0) + p_amount_fet,
      fet_spent = coalesce(fet_spent, 0) + p_amount_fet,
      payment_status = CASE
        WHEN payment_status::text = 'paid' THEN payment_status
        ELSE 'partially_paid'::public.venue_payment_status
      END,
      updated_at = timezone('utc', now())
  WHERE id = p_order_id;

  RETURN v_result || jsonb_build_object('order_id', p_order_id);
END;
$$;

COMMENT ON FUNCTION public.spend_fet_on_order(uuid, bigint, text) IS
  'Debits available FET through wallet_post_transaction and records FET spend on an order.';

CREATE OR REPLACE FUNCTION public.generate_pool_share_card(
  p_pool_id uuid,
  p_social_card_url text DEFAULT NULL::text,
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_payload jsonb;
BEGIN
  IF p_social_card_url IS NOT NULL AND length(trim(p_social_card_url)) > 0 THEN
    RETURN public.set_match_pool_social_card_url(p_pool_id, p_social_card_url, p_metadata);
  END IF;

  v_payload := public.get_match_pool_social_card_payload(p_pool_id);
  RETURN jsonb_build_object(
    'status', 'payload_ready',
    'pool_id', p_pool_id,
    'payload', v_payload
  );
END;
$$;

COMMENT ON FUNCTION public.generate_pool_share_card(uuid, text, jsonb) IS
  'Backend-controlled pool share-card RPC. Returns render payload or stores a generated card URL.';

CREATE OR REPLACE FUNCTION public.manual_mark_order_paid(
  p_order_id uuid,
  p_payment_method text DEFAULT 'cash'::text,
  p_actor_note text DEFAULT NULL::text
) RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT public.venue_update_order_payment_status(
    p_order_id,
    'paid',
    p_payment_method,
    p_actor_note
  ) || jsonb_build_object('status', 'paid');
$$;

COMMENT ON FUNCTION public.manual_mark_order_paid(uuid, text, text) IS
  'Product-facing wrapper for venue audited manual payment confirmation.';

REVOKE ALL ON FUNCTION public.generate_pool_share_card(uuid, text, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.spend_fet_on_order(uuid, bigint, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.manual_mark_order_paid(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.stake_fet(uuid, uuid, bigint, text, text) FROM PUBLIC;

GRANT SELECT ON TABLE public.venue_tables TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.stake_fet(uuid, uuid, bigint, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.spend_fet_on_order(uuid, bigint, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.generate_pool_share_card(uuid, text, jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.manual_mark_order_paid(uuid, text, text) TO authenticated, service_role;
