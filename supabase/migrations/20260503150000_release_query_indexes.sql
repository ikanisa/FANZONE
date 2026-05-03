-- Query-shape indexes for release-critical venue operations.
--
-- These indexes are intentionally additive: they do not change constraints,
-- policies, wallet mutation semantics, or settlement behavior.

CREATE INDEX IF NOT EXISTS orders_venue_payment_created_idx
ON public.orders (venue_id, payment_status, created_at DESC);

CREATE INDEX IF NOT EXISTS orders_eligibility_lookup_idx
ON public.orders (venue_id, user_id, created_at DESC)
WHERE payment_status = 'paid' AND status <> 'cancelled';
