-- ============================================================
-- 20260421100000_restore_marketplace_redemptions.sql
--
-- Restores marketplace_redemptions which was accidentally
-- cascade-dropped when the legacy 'rewards' table was dropped.
-- This table is referenced by wallet_gateway.dart and the
-- redeem_offer() RPC function.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.marketplace_redemptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_id UUID NOT NULL REFERENCES public.marketplace_offers(id),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  cost_fet BIGINT NOT NULL,
  delivery_type TEXT NOT NULL,
  delivery_value TEXT,
  status TEXT DEFAULT 'pending'
    CHECK (status IN ('pending', 'fulfilled', 'used', 'expired', 'refunded')),
  redeemed_at TIMESTAMPTZ DEFAULT now(),
  used_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_marketplace_redemptions_user
  ON public.marketplace_redemptions(user_id, redeemed_at DESC);

ALTER TABLE public.marketplace_redemptions ENABLE ROW LEVEL SECURITY;

-- Users see own redemptions only
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'marketplace_redemptions'
      AND policyname = 'Users read own redemptions'
  ) THEN
    CREATE POLICY "Users read own redemptions"
      ON public.marketplace_redemptions FOR SELECT
      USING (auth.uid() = user_id);
  END IF;
END $$;

GRANT SELECT ON public.marketplace_redemptions TO anon, authenticated;
GRANT ALL ON public.marketplace_redemptions TO service_role;

-- Restore the redeem_offer RPC (may have been cascade-dropped)
CREATE OR REPLACE FUNCTION public.redeem_offer(p_offer_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_offer RECORD;
  v_balance BIGINT;
  v_redemption_id UUID;
  v_delivery_value TEXT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  SELECT * INTO v_offer FROM public.marketplace_offers
  WHERE id = p_offer_id AND is_active = true
  FOR UPDATE;

  IF v_offer IS NULL THEN RAISE EXCEPTION 'Offer not found or inactive'; END IF;
  IF v_offer.stock IS NOT NULL AND v_offer.stock <= 0 THEN
    RAISE EXCEPTION 'Offer is out of stock';
  END IF;
  IF v_offer.valid_until IS NOT NULL AND v_offer.valid_until < now() THEN
    RAISE EXCEPTION 'Offer has expired';
  END IF;

  SELECT available_balance_fet INTO v_balance
  FROM public.fet_wallets WHERE user_id = v_user_id FOR UPDATE;

  IF v_balance IS NULL OR v_balance < v_offer.cost_fet THEN
    RAISE EXCEPTION 'Insufficient FET balance';
  END IF;

  UPDATE public.fet_wallets
  SET available_balance_fet = available_balance_fet - v_offer.cost_fet,
      updated_at = now()
  WHERE user_id = v_user_id;

  IF v_offer.stock IS NOT NULL THEN
    UPDATE public.marketplace_offers SET stock = stock - 1 WHERE id = p_offer_id;
  END IF;

  v_delivery_value := 'FZ-' || upper(substring(gen_random_uuid()::text FROM 1 FOR 8));

  INSERT INTO public.marketplace_redemptions (
    offer_id, user_id, cost_fet, delivery_type, delivery_value, status
  ) VALUES (
    p_offer_id, v_user_id, v_offer.cost_fet, v_offer.delivery_type,
    v_delivery_value, 'fulfilled'
  ) RETURNING id INTO v_redemption_id;

  INSERT INTO public.fet_wallet_transactions (
    user_id, tx_type, direction, amount_fet,
    balance_before_fet, balance_after_fet,
    reference_type, reference_id, title
  ) VALUES (
    v_user_id, 'redemption', 'debit', v_offer.cost_fet,
    v_balance, v_balance - v_offer.cost_fet,
    'marketplace_redemption', v_redemption_id,
    'Redeemed: ' || v_offer.title
  );

  RETURN jsonb_build_object(
    'status', 'fulfilled',
    'redemption_id', v_redemption_id,
    'delivery_type', v_offer.delivery_type,
    'delivery_value', v_delivery_value,
    'balance_after', v_balance - v_offer.cost_fet
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;

DO $$
BEGIN
  RAISE NOTICE 'marketplace_redemptions restored successfully';
END $$;
