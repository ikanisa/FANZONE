-- Restrict user-to-user FET transfer RPCs to authenticated users.
--
-- The functions already require auth.uid(), but wallet movement surfaces should
-- not be executable by anon. Clients transfer through the app wallet service,
-- which requires a WhatsApp-authenticated session and writes ledger rows via
-- wallet_post_transaction.

REVOKE ALL ON FUNCTION public.transfer_fet(text, bigint)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.transfer_fet(text, bigint)
TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.transfer_fet_by_fan_id(text, bigint)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.transfer_fet_by_fan_id(text, bigint)
TO authenticated, service_role;

COMMENT ON FUNCTION public.transfer_fet(text, bigint)
IS 'Authenticated wallet transfer wrapper. Requires auth.uid() and posts audited ledger rows.';

COMMENT ON FUNCTION public.transfer_fet_by_fan_id(text, bigint)
IS 'Authenticated Fan ID transfer RPC. Requires auth.uid() and posts audited debit/credit ledger rows.';
