BEGIN;

ALTER TABLE public.admin_users
  ADD COLUMN IF NOT EXISTS phone text;

UPDATE public.admin_users au
SET phone = u.phone
FROM auth.users u
WHERE au.user_id = u.id
  AND coalesce(au.phone, '') = ''
  AND coalesce(u.phone, '') <> '';

DROP INDEX IF EXISTS public.idx_admin_users_email;
CREATE INDEX IF NOT EXISTS idx_admin_users_phone ON public.admin_users(phone);

CREATE OR REPLACE VIEW public.admin_audit_logs_enriched AS
SELECT
  al.*,
  au.display_name AS admin_name,
  au.phone AS admin_phone
FROM public.admin_audit_logs al
LEFT JOIN public.admin_users au
  ON au.id = al.admin_user_id
WHERE public.is_active_admin_operator(auth.uid());

CREATE OR REPLACE FUNCTION public.admin_grant_access(
  p_phone text,
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
  v_normalized_phone text := regexp_replace(trim(coalesce(p_phone, '')), '[^0-9+]', '', 'g');
  v_role text := lower(trim(coalesce(p_role, '')));
  v_existing public.admin_users%ROWTYPE;
  v_result public.admin_users%ROWTYPE;
  v_target_display_name text;
BEGIN
  IF v_normalized_phone = '' THEN
    RAISE EXCEPTION 'WhatsApp number is required';
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

  SELECT
    id,
    coalesce(
      nullif(trim(raw_user_meta_data ->> 'display_name'), ''),
      nullif(trim(raw_user_meta_data ->> 'full_name'), ''),
      concat('Admin ', right(v_normalized_phone, 4))
    )
  INTO v_target_user_id, v_target_display_name
  FROM auth.users
  WHERE phone = v_normalized_phone
  LIMIT 1;

  IF v_target_user_id IS NULL THEN
    RAISE EXCEPTION 'The target user must sign in with their WhatsApp number before admin access can be granted';
  END IF;

  SELECT *
  INTO v_existing
  FROM public.admin_users
  WHERE user_id = v_target_user_id
  LIMIT 1;

  IF FOUND THEN
    UPDATE public.admin_users
    SET
      phone = v_normalized_phone,
      display_name = coalesce(nullif(trim(display_name), ''), v_target_display_name),
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
      phone,
      display_name,
      role,
      is_active,
      invited_by
    )
    VALUES (
      v_target_user_id,
      v_normalized_phone,
      v_target_display_name,
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
      'phone', v_normalized_phone,
      'role', v_role
    )
  );

  RETURN v_result;
END;
$$;

COMMIT;
