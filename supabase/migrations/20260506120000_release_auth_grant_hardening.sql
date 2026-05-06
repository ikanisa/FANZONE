-- Harden direct client access to auth and wallet helper functions.
-- Clients must use scoped RPCs/Edge Functions that enforce caller identity,
-- ownership, idempotency, and audit requirements.

REVOKE ALL ON FUNCTION public.credit_welcome_fet(uuid, text)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.credit_welcome_fet(uuid, text)
TO service_role;

REVOKE ALL ON FUNCTION public.reconcile_fet_wallet(uuid)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reconcile_fet_wallet(uuid)
TO service_role;

REVOKE ALL ON FUNCTION public.find_auth_user_by_phone(text)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.find_auth_user_by_phone(text)
TO service_role;

REVOKE ALL ON FUNCTION public.resolve_auth_user_phone(uuid)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_auth_user_phone(uuid)
TO service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON FUNCTIONS FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON SEQUENCES FROM PUBLIC, anon, authenticated;

COMMENT ON FUNCTION public.credit_welcome_fet(uuid, text) IS
  'Service-only welcome credit helper. User-callable foundation provisioning must go through ensure_user_foundation(uuid).';
COMMENT ON FUNCTION public.reconcile_fet_wallet(uuid) IS
  'Service-only reconciliation primitive. Client reads must use get_wallet_balance(uuid), which enforces caller ownership/admin access.';
