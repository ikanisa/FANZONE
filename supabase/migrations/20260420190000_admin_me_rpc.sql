BEGIN;

-- Centralize admin self-resolution behind a SECURITY DEFINER RPC so the
-- browser does not need to own raw admin_users access rules for sign-in.
CREATE OR REPLACE FUNCTION public.get_admin_me()
RETURNS public.admin_users
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id uuid;
  v_admin public.admin_users%ROWTYPE;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL OR to_regclass('public.admin_users') IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT *
  INTO v_admin
  FROM public.admin_users
  WHERE user_id = v_user_id
    AND is_active = true
  ORDER BY created_at DESC, id DESC
  LIMIT 1;

  RETURN v_admin;
END;
$$;

REVOKE ALL ON FUNCTION public.get_admin_me() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_admin_me() TO authenticated;

COMMIT;
