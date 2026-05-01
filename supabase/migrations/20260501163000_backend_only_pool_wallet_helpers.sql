-- Keep pool locking and order-reward credit helpers backend-only.
-- Authenticated clients must use scoped, audited app RPCs such as stake_fet,
-- spend_fet_on_order, manual_mark_order_paid, and service-triggered order rewards.

REVOKE ALL ON FUNCTION public.lock_pool_for_match_start(text)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.lock_pool_for_match_start(text)
TO service_role;

REVOKE ALL ON FUNCTION public.credit_fet_for_order(uuid, text)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.credit_fet_for_order(uuid, text)
TO service_role;

REVOKE ALL ON FUNCTION public.credit_order_fet(uuid, bigint)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.credit_order_fet(uuid, bigint)
TO service_role;

COMMENT ON FUNCTION public.lock_pool_for_match_start(text)
IS 'Backend-only pool state helper called by audited match score updates and scheduled settlement flows.';

COMMENT ON FUNCTION public.credit_fet_for_order(uuid, text)
IS 'Backend-only order reward helper. Clients must not credit wallets directly.';

COMMENT ON FUNCTION public.credit_order_fet(uuid, bigint)
IS 'Backend-only compatibility wrapper for order reward crediting.';
