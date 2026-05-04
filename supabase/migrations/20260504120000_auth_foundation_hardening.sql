-- Ensure WhatsApp/Supabase auth users receive a profile, Fan ID, and welcome
-- wallet foundation immediately, while preventing arbitrary client-side
-- foundation provisioning for other users.

CREATE OR REPLACE FUNCTION public.ensure_user_foundation(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  phone_value text;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN;
  END IF;

  IF coalesce(auth.role(), '') <> 'service_role'
     AND auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Users can only provision their own foundation';
  END IF;

  SELECT public.resolve_auth_user_phone(p_user_id) INTO phone_value;

  INSERT INTO public.profiles (id, user_id, phone_number)
  VALUES (p_user_id, p_user_id, phone_value)
  ON CONFLICT (id) DO UPDATE
    SET user_id = EXCLUDED.user_id,
        phone_number = coalesce(EXCLUDED.phone_number, profiles.phone_number);

  PERFORM public.credit_welcome_fet(p_user_id, 'welcome_credit:' || p_user_id::text);
END;
$$;

REVOKE ALL ON FUNCTION public.ensure_user_foundation(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ensure_user_foundation(uuid) TO authenticated, service_role;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_auth_user();

COMMENT ON FUNCTION public.ensure_user_foundation(uuid) IS
  'Creates the required profile/Fan ID and idempotent welcome wallet foundation. Callable by service role for any user, or by an authenticated user for self only.';
