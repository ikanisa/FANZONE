-- ============================================================
-- 015_partner_marketplace.sql
-- Partner marketplace with FET-based redemptions
-- Phase 4: Social & Marketplace
-- ============================================================

BEGIN;

-- ======================
-- 1) Partners
-- ======================

CREATE TABLE IF NOT EXISTS public.marketplace_partners (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  logo_url TEXT,
  category TEXT NOT NULL, -- 'food_drink', 'merchandise', 'experience', 'digital', 'charity'
  country TEXT DEFAULT 'MT',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ======================
-- 2) Offers
-- ======================

CREATE TABLE IF NOT EXISTS public.marketplace_offers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id UUID NOT NULL REFERENCES public.marketplace_partners(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  image_url TEXT,
  category TEXT NOT NULL,
  cost_fet BIGINT NOT NULL CHECK (cost_fet > 0),
  original_value TEXT,       -- "€10 voucher", "Free pizza"
  delivery_type TEXT NOT NULL
    CHECK (delivery_type IN ('code', 'voucher', 'link', 'qr')),
  stock INT,                 -- NULL = unlimited
  is_active BOOLEAN DEFAULT true,
  terms TEXT,
  valid_until TIMESTAMPTZ,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ======================
-- 3) Redemptions
-- ======================

CREATE TABLE IF NOT EXISTS public.marketplace_redemptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_id UUID NOT NULL REFERENCES public.marketplace_offers(id),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  cost_fet BIGINT NOT NULL,
  delivery_type TEXT NOT NULL,
  delivery_value TEXT,       -- The actual code/voucher/link
  status TEXT DEFAULT 'pending'
    CHECK (status IN ('pending', 'fulfilled', 'used', 'expired', 'refunded')),
  redeemed_at TIMESTAMPTZ DEFAULT now(),
  used_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_marketplace_offers_partner
  ON public.marketplace_offers(partner_id);
CREATE INDEX IF NOT EXISTS idx_marketplace_offers_active
  ON public.marketplace_offers(is_active, category) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_marketplace_redemptions_user
  ON public.marketplace_redemptions(user_id, redeemed_at DESC);

-- ======================
-- 4) RPC: redeem_offer (atomic)
-- ======================

CREATE OR REPLACE FUNCTION redeem_offer(p_offer_id UUID)
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

  -- Lock and validate offer
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

  -- Check balance
  SELECT available_balance_fet INTO v_balance
  FROM public.fet_wallets WHERE user_id = v_user_id FOR UPDATE;

  IF v_balance IS NULL OR v_balance < v_offer.cost_fet THEN
    RAISE EXCEPTION 'Insufficient FET balance';
  END IF;

  -- Debit wallet
  UPDATE public.fet_wallets
  SET available_balance_fet = available_balance_fet - v_offer.cost_fet,
      updated_at = now()
  WHERE user_id = v_user_id;

  -- Decrement stock if limited
  IF v_offer.stock IS NOT NULL THEN
    UPDATE public.marketplace_offers SET stock = stock - 1 WHERE id = p_offer_id;
  END IF;

  -- Generate delivery value
  v_delivery_value := 'FZ-' || upper(substring(gen_random_uuid()::text FROM 1 FOR 8));

  -- Create redemption
  INSERT INTO public.marketplace_redemptions (
    offer_id, user_id, cost_fet, delivery_type, delivery_value, status
  ) VALUES (
    p_offer_id, v_user_id, v_offer.cost_fet, v_offer.delivery_type,
    v_delivery_value, 'fulfilled'
  ) RETURNING id INTO v_redemption_id;

  -- Record wallet transaction
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ======================
-- 5) RLS
-- ======================

ALTER TABLE public.marketplace_partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_redemptions ENABLE ROW LEVEL SECURITY;

-- Public read for partners and active offers
CREATE POLICY "Public read partners"
  ON public.marketplace_partners FOR SELECT USING (is_active = true);
CREATE POLICY "Public read active offers"
  ON public.marketplace_offers FOR SELECT USING (is_active = true);
-- Users see own redemptions only
CREATE POLICY "Users read own redemptions"
  ON public.marketplace_redemptions FOR SELECT USING (auth.uid() = user_id);

COMMIT;
