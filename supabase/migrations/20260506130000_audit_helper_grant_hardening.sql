-- Keep audit writes behind audited RPCs, triggers, and trusted Edge Functions.
-- Direct client execution can forge action/entity payloads and is not part of
-- the product contract.

REVOKE ALL ON FUNCTION public.sports_bar_write_audit(text, text, text, jsonb, jsonb, uuid)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.sports_bar_write_audit(text, text, text, jsonb, jsonb, uuid)
TO service_role;

COMMENT ON FUNCTION public.sports_bar_write_audit(text, text, text, jsonb, jsonb, uuid) IS
  'Service/internal audit helper. Clients must use product RPCs or Edge Functions that perform authorization and write audit rows internally.';
