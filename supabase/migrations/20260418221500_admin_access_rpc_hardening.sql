-- ============================================================
-- 20260418221500_admin_access_rpc_hardening.sql
-- Move admin-access mutations behind audited RPCs instead of
-- direct browser writes against admin_users.
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.require_super_admin_user()
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF public.is_service_role_request() THEN
    RETURN NULL;
  END IF;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT public.is_super_admin_user(v_user_id) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN v_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_grant_access(
  p_email text,
  p_role text
)
RETURNS public.admin_users
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_actor_user_id uuid := public.require_super_admin_user();
  v_actor_admin_id uuid;
  v_target_user_id uuid;
  v_normalized_email text := lower(trim(coalesce(p_email, '')));
  v_role text := lower(trim(coalesce(p_role, '')));
  v_existing public.admin_users%ROWTYPE;
  v_result public.admin_users%ROWTYPE;
BEGIN
  IF v_normalized_email = '' THEN
    RAISE EXCEPTION 'Email is required';
  END IF;

  IF v_role NOT IN ('super_admin', 'admin', 'moderator', 'viewer') THEN
    RAISE EXCEPTION 'Invalid admin role';
  END IF;

  SELECT id
  INTO v_actor_admin_id
  FROM public.admin_users
  WHERE user_id = v_actor_user_id
    AND is_active = true
  LIMIT 1;

  IF v_actor_admin_id IS NULL THEN
    RAISE EXCEPTION 'Admin operator record not found';
  END IF;

  SELECT id
  INTO v_target_user_id
  FROM auth.users
  WHERE lower(email) = v_normalized_email
  LIMIT 1;

  IF v_target_user_id IS NULL THEN
    RAISE EXCEPTION 'The target user must sign in before admin access can be granted';
  END IF;

  SELECT *
  INTO v_existing
  FROM public.admin_users
  WHERE user_id = v_target_user_id
  LIMIT 1;

  IF FOUND THEN
    UPDATE public.admin_users
    SET
      email = v_normalized_email,
      display_name = coalesce(nullif(trim(display_name), ''), split_part(v_normalized_email, '@', 1)),
      role = v_role,
      is_active = true,
      invited_by = coalesce(invited_by, v_actor_admin_id),
      updated_at = timezone('utc', now())
    WHERE id = v_existing.id
    RETURNING *
    INTO v_result;
  ELSE
    INSERT INTO public.admin_users (
      user_id,
      email,
      display_name,
      role,
      is_active,
      invited_by
    )
    VALUES (
      v_target_user_id,
      v_normalized_email,
      split_part(v_normalized_email, '@', 1),
      v_role,
      true,
      v_actor_admin_id
    )
    RETURNING *
    INTO v_result;
  END IF;

  INSERT INTO public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    before_state,
    after_state,
    metadata
  )
  VALUES (
    v_actor_admin_id,
    'grant_admin_access',
    'admin_access',
    'admin_user',
    v_result.id::text,
    CASE WHEN v_existing.id IS NOT NULL THEN to_jsonb(v_existing) ELSE NULL END,
    to_jsonb(v_result),
    jsonb_build_object(
      'email', v_normalized_email,
      'role', v_role
    )
  );

  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_change_admin_role(
  p_admin_id uuid,
  p_role text
)
RETURNS public.admin_users
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_user_id uuid := public.require_super_admin_user();
  v_actor_admin_id uuid;
  v_role text := lower(trim(coalesce(p_role, '')));
  v_existing public.admin_users%ROWTYPE;
  v_result public.admin_users%ROWTYPE;
  v_active_super_admins bigint := 0;
BEGIN
  IF p_admin_id IS NULL THEN
    RAISE EXCEPTION 'Admin id is required';
  END IF;

  IF v_role NOT IN ('super_admin', 'admin', 'moderator', 'viewer') THEN
    RAISE EXCEPTION 'Invalid admin role';
  END IF;

  SELECT id
  INTO v_actor_admin_id
  FROM public.admin_users
  WHERE user_id = v_actor_user_id
    AND is_active = true
  LIMIT 1;

  IF v_actor_admin_id IS NULL THEN
    RAISE EXCEPTION 'Admin operator record not found';
  END IF;

  SELECT *
  INTO v_existing
  FROM public.admin_users
  WHERE id = p_admin_id
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Admin user not found';
  END IF;

  IF v_existing.user_id = v_actor_user_id THEN
    RAISE EXCEPTION 'You cannot change your own admin role';
  END IF;

  IF v_existing.role = 'super_admin' AND v_role <> 'super_admin' AND v_existing.is_active THEN
    SELECT count(*)::bigint
    INTO v_active_super_admins
    FROM public.admin_users
    WHERE is_active = true
      AND role = 'super_admin';

    IF v_active_super_admins <= 1 THEN
      RAISE EXCEPTION 'Cannot demote the last active super admin';
    END IF;
  END IF;

  UPDATE public.admin_users
  SET
    role = v_role,
    updated_at = timezone('utc', now())
  WHERE id = p_admin_id
  RETURNING *
  INTO v_result;

  INSERT INTO public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    before_state,
    after_state,
    metadata
  )
  VALUES (
    v_actor_admin_id,
    'change_admin_role',
    'admin_access',
    'admin_user',
    v_result.id::text,
    to_jsonb(v_existing),
    to_jsonb(v_result),
    jsonb_build_object('role', v_role)
  );

  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_revoke_access(
  p_admin_id uuid
)
RETURNS public.admin_users
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_user_id uuid := public.require_super_admin_user();
  v_actor_admin_id uuid;
  v_existing public.admin_users%ROWTYPE;
  v_result public.admin_users%ROWTYPE;
  v_active_super_admins bigint := 0;
BEGIN
  IF p_admin_id IS NULL THEN
    RAISE EXCEPTION 'Admin id is required';
  END IF;

  SELECT id
  INTO v_actor_admin_id
  FROM public.admin_users
  WHERE user_id = v_actor_user_id
    AND is_active = true
  LIMIT 1;

  IF v_actor_admin_id IS NULL THEN
    RAISE EXCEPTION 'Admin operator record not found';
  END IF;

  SELECT *
  INTO v_existing
  FROM public.admin_users
  WHERE id = p_admin_id
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Admin user not found';
  END IF;

  IF v_existing.user_id = v_actor_user_id THEN
    RAISE EXCEPTION 'You cannot revoke your own admin access';
  END IF;

  IF v_existing.role = 'super_admin' AND v_existing.is_active THEN
    SELECT count(*)::bigint
    INTO v_active_super_admins
    FROM public.admin_users
    WHERE is_active = true
      AND role = 'super_admin';

    IF v_active_super_admins <= 1 THEN
      RAISE EXCEPTION 'Cannot revoke the last active super admin';
    END IF;
  END IF;

  UPDATE public.admin_users
  SET
    is_active = false,
    updated_at = timezone('utc', now())
  WHERE id = p_admin_id
  RETURNING *
  INTO v_result;

  INSERT INTO public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    before_state,
    after_state
  )
  VALUES (
    v_actor_admin_id,
    'revoke_admin_access',
    'admin_access',
    'admin_user',
    v_result.id::text,
    to_jsonb(v_existing),
    to_jsonb(v_result)
  );

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.require_super_admin_user() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_grant_access(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_change_admin_role(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_revoke_access(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.require_super_admin_user() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_grant_access(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_change_admin_role(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_revoke_access(uuid) TO authenticated;

COMMIT;
