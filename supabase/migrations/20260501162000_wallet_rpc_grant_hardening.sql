-- Keep the ledger mutation primitive backend-only. Authenticated clients must use
-- scoped wallet/order/pool RPCs that perform ownership, balance, and idempotency checks.
REVOKE ALL ON FUNCTION public.wallet_post_transaction(
  uuid,
  text,
  text,
  bigint,
  text,
  text,
  text,
  text,
  text,
  jsonb,
  uuid,
  text,
  uuid,
  uuid,
  uuid,
  uuid,
  text,
  uuid
) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.wallet_post_transaction(
  uuid,
  text,
  text,
  bigint,
  text,
  text,
  text,
  text,
  text,
  jsonb,
  uuid,
  text,
  uuid,
  uuid,
  uuid,
  uuid,
  text,
  uuid
) TO service_role;
