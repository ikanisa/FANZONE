-- ============================================================================
-- DineIn → FET Bridge
-- Migration: 20260501_dinein_fet_bridge.sql
-- Purpose: Auto-credit FET when order payment_status → 'paid'
-- Rate: 100 FET per 1 EUR spent
-- Depends on: 20260501_dinein_schema_merge.sql + existing fet_wallets
-- ============================================================================

BEGIN;

-- ── FET earn rate constant ───────────────────────────────────────────────────
-- 100 FET = 1 EUR. Earning rate = 100 FET per 1 EUR spent (1:1 with conversion)
-- This means a 10 EUR order earns 1000 FET.
-- For RWF orders: convert to EUR first using current rate, then apply 100 FET/EUR.

CREATE OR REPLACE FUNCTION public.dinein_credit_fet_from_order()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_total numeric;
  v_currency text;
  v_eur_amount numeric;
  v_fet_amount bigint;
  v_balance_before bigint;
  -- Fixed rate: 1 EUR = 1500 RWF (approximate, can be parameterized later)
  c_rwf_to_eur_rate constant numeric := 1500.0;
  -- Fixed rate: 100 FET = 1 EUR
  c_fet_per_eur constant bigint := 100;
BEGIN
  -- Only fire when payment_status transitions TO 'paid'
  IF NEW.payment_status != 'paid' THEN
    RETURN NEW;
  END IF;
  IF OLD IS NOT NULL AND OLD.payment_status = 'paid' THEN
    RETURN NEW; -- Already paid, no double-credit
  END IF;

  v_user_id := NEW.user_id;
  v_total := NEW.total_amount;
  v_currency := NEW.currency_code;

  -- Convert to EUR if needed
  IF v_currency = 'EUR' THEN
    v_eur_amount := v_total;
  ELSIF v_currency = 'RWF' THEN
    v_eur_amount := v_total / c_rwf_to_eur_rate;
  ELSE
    -- Unknown currency, skip credit
    RAISE WARNING 'Unknown currency % for order %, skipping FET credit', v_currency, NEW.id;
    RETURN NEW;
  END IF;

  -- Calculate FET: 100 FET per 1 EUR
  v_fet_amount := FLOOR(v_eur_amount * c_fet_per_eur);

  -- Minimum 1 FET (don't credit 0)
  IF v_fet_amount < 1 THEN
    v_fet_amount := 1;
  END IF;

  -- Get current balance (lock row)
  SELECT available_balance_fet INTO v_balance_before
  FROM public.fet_wallets
  WHERE user_id = v_user_id
  FOR UPDATE;

  -- Upsert wallet
  INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
  VALUES (v_user_id, v_fet_amount, 0)
  ON CONFLICT (user_id) DO UPDATE
  SET available_balance_fet = fet_wallets.available_balance_fet + v_fet_amount,
      updated_at = now();

  -- Record transaction
  INSERT INTO public.fet_wallet_transactions (
    user_id, tx_type, direction, amount_fet,
    balance_before_fet, balance_after_fet,
    reference_type, reference_id,
    title, metadata
  ) VALUES (
    v_user_id,
    'order_earn',
    'credit',
    v_fet_amount,
    COALESCE(v_balance_before, 0),
    COALESCE(v_balance_before, 0) + v_fet_amount,
    'dinein_order',
    NEW.id::text,
    'Earned from order ' || NEW.order_code,
    jsonb_build_object(
      'order_id', NEW.id,
      'order_code', NEW.order_code,
      'venue_id', NEW.venue_id,
      'total_amount', v_total,
      'currency_code', v_currency,
      'eur_equivalent', v_eur_amount,
      'fet_rate', c_fet_per_eur
    )
  );

  RETURN NEW;
END;
$$;

-- ── Trigger: fire on order payment_status change ─────────────────────────────

DROP TRIGGER IF EXISTS trg_credit_fet_on_order_paid ON public.orders;
CREATE TRIGGER trg_credit_fet_on_order_paid
  AFTER UPDATE OF payment_status ON public.orders
  FOR EACH ROW
  WHEN (NEW.payment_status = 'paid')
  EXECUTE FUNCTION public.dinein_credit_fet_from_order();

-- Also fire on insert if order is created directly as paid (edge case)
DROP TRIGGER IF EXISTS trg_credit_fet_on_order_insert_paid ON public.orders;
CREATE TRIGGER trg_credit_fet_on_order_insert_paid
  AFTER INSERT ON public.orders
  FOR EACH ROW
  WHEN (NEW.payment_status = 'paid')
  EXECUTE FUNCTION public.dinein_credit_fet_from_order();

COMMIT;
