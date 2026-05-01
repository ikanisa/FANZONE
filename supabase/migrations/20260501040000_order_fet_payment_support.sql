-- ============================================================================
-- Support for FET token payments in orders
-- Migration: 20260501040000_order_fet_payment_support.sql
-- Purpose: Add columns to track FET token usage in orders.
-- ============================================================================

BEGIN;

ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS payment_fet_amount bigint NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS payment_fet_converted_amount decimal(12,2) NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.orders.payment_fet_amount IS 'Amount of FET tokens applied to this order.';
COMMENT ON COLUMN public.orders.payment_fet_converted_amount IS 'Value of applied FET tokens in the order currency.';

CREATE OR REPLACE FUNCTION public.credit_fet_for_order(
  p_user_id uuid,
  p_order_id uuid,
  p_amount bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_balance_before bigint;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'User id is required';
  END IF;

  IF p_order_id IS NULL THEN
    RAISE EXCEPTION 'Order id is required';
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be positive';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.orders
    WHERE id = p_order_id
      AND user_id = p_user_id
      AND payment_status = 'paid'
  ) THEN
    RAISE EXCEPTION 'Paid order not found for user';
  END IF;

  SELECT available_balance_fet
  INTO v_balance_before
  FROM public.fet_wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
  VALUES (p_user_id, p_amount, 0)
  ON CONFLICT (user_id) DO UPDATE
  SET available_balance_fet = public.fet_wallets.available_balance_fet + p_amount,
      updated_at = now();

  INSERT INTO public.fet_wallet_transactions (
    user_id,
    tx_type,
    direction,
    amount_fet,
    balance_before_fet,
    balance_after_fet,
    reference_type,
    reference_id,
    title
  )
  VALUES (
    p_user_id,
    'order_reward',
    'credit',
    p_amount,
    COALESCE(v_balance_before, 0),
    COALESCE(v_balance_before, 0) + p_amount,
    'order',
    p_order_id::text,
    'FET earned from paid venue order'
  );

  RETURN jsonb_build_object(
    'status', 'credited',
    'user_id', p_user_id,
    'order_id', p_order_id,
    'amount_fet', p_amount
  );
END;
$$;

REVOKE ALL ON FUNCTION public.credit_fet_for_order(uuid, uuid, bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.credit_fet_for_order(uuid, uuid, bigint) TO service_role;

COMMIT;
