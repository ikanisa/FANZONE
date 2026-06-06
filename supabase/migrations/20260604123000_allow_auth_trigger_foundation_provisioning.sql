-- Allow the auth.users trigger to provision the FANZONE user foundation.
-- Client callers are still constrained to their own auth.uid(); service-role
-- and internal trigger contexts may provision by explicit user id.

CREATE OR REPLACE FUNCTION public.ensure_user_foundation(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  phone_value text;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN;
  END IF;

  IF coalesce(auth.role(), '') <> 'service_role'
     AND auth.uid() IS NOT NULL
     AND auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Users can only provision their own foundation';
  END IF;

  SELECT public.resolve_auth_user_phone(p_user_id) INTO phone_value;

  INSERT INTO public.profiles (id, user_id, phone_number)
  VALUES (p_user_id, p_user_id, phone_value)
  ON CONFLICT (id) DO UPDATE
    SET user_id = EXCLUDED.user_id,
        phone_number = coalesce(EXCLUDED.phone_number, profiles.phone_number);

  PERFORM public.credit_welcome_fet(
    p_user_id,
    'welcome_credit:' || p_user_id::text
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.ensure_user_foundation(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ensure_user_foundation(uuid)
  TO authenticated, service_role;

COMMENT ON FUNCTION public.ensure_user_foundation(uuid) IS
  'Provision idempotent profile and welcome FET rows for auth users; callable by same authenticated user, service role, and auth trigger context.';
