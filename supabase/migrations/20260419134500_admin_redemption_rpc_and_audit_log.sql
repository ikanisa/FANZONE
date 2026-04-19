BEGIN;

CREATE OR REPLACE FUNCTION public.admin_log_action(
  p_action text,
  p_module text,
  p_target_type text DEFAULT NULL,
  p_target_id text DEFAULT NULL,
  p_before_state jsonb DEFAULT NULL,
  p_after_state jsonb DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_user_id uuid := public.require_active_admin_user();
  v_actor_admin_id uuid;
  v_audit_id uuid;
BEGIN
  SELECT id
  INTO v_actor_admin_id
  FROM public.admin_users
  WHERE user_id = v_actor_user_id
    AND is_active = true
  LIMIT 1;

  IF v_actor_admin_id IS NULL THEN
    RAISE EXCEPTION 'Admin operator record not found';
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
    lower(trim(coalesce(p_action, ''))),
    lower(trim(coalesce(p_module, ''))),
    nullif(trim(coalesce(p_target_type, '')), ''),
    nullif(trim(coalesce(p_target_id, '')), ''),
    p_before_state,
    p_after_state,
    coalesce(p_metadata, '{}'::jsonb)
  )
  RETURNING id INTO v_audit_id;

  RETURN v_audit_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_approve_redemption(
  p_redemption_id uuid,
  p_redemption_code text DEFAULT NULL,
  p_admin_notes text DEFAULT NULL
)
RETURNS public.redemptions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_user_id uuid := public.require_active_admin_user();
  v_actor_admin_id uuid;
  v_before public.redemptions%ROWTYPE;
  v_after public.redemptions%ROWTYPE;
  v_code text;
BEGIN
  IF p_redemption_id IS NULL THEN
    RAISE EXCEPTION 'Redemption id is required';
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
  INTO v_before
  FROM public.redemptions
  WHERE id = p_redemption_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Redemption not found';
  END IF;

  IF v_before.status NOT IN ('pending', 'disputed') THEN
    RAISE EXCEPTION 'Only pending or disputed redemptions can be approved';
  END IF;

  v_code := coalesce(
    nullif(trim(coalesce(p_redemption_code, '')), ''),
    nullif(trim(coalesce(v_before.redemption_code, '')), ''),
    'FZ-' || upper(substring(md5(gen_random_uuid()::text) from 1 for 8))
  );

  UPDATE public.redemptions
  SET
    status = 'approved',
    redemption_code = v_code,
    admin_notes = coalesce(
      nullif(trim(coalesce(p_admin_notes, '')), ''),
      v_before.admin_notes
    ),
    reviewed_by = v_actor_admin_id,
    updated_at = timezone('utc', now())
  WHERE id = p_redemption_id
  RETURNING * INTO v_after;

  PERFORM public.admin_log_action(
    'approve_redemption',
    'redemptions',
    'redemption',
    p_redemption_id::text,
    to_jsonb(v_before),
    to_jsonb(v_after),
    jsonb_build_object('status_transition', v_before.status || '->approved')
  );

  RETURN v_after;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_reject_redemption(
  p_redemption_id uuid,
  p_reason text
)
RETURNS public.redemptions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_user_id uuid := public.require_active_admin_user();
  v_actor_admin_id uuid;
  v_before public.redemptions%ROWTYPE;
  v_after public.redemptions%ROWTYPE;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
BEGIN
  IF p_redemption_id IS NULL THEN
    RAISE EXCEPTION 'Redemption id is required';
  END IF;

  IF v_reason IS NULL THEN
    RAISE EXCEPTION 'A rejection reason is required';
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
  INTO v_before
  FROM public.redemptions
  WHERE id = p_redemption_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Redemption not found';
  END IF;

  IF v_before.status = 'fulfilled' THEN
    RAISE EXCEPTION 'Fulfilled redemptions cannot be rejected';
  END IF;

  UPDATE public.redemptions
  SET
    status = 'rejected',
    admin_notes = v_reason,
    reviewed_by = v_actor_admin_id,
    updated_at = timezone('utc', now())
  WHERE id = p_redemption_id
  RETURNING * INTO v_after;

  PERFORM public.admin_log_action(
    'reject_redemption',
    'redemptions',
    'redemption',
    p_redemption_id::text,
    to_jsonb(v_before),
    to_jsonb(v_after),
    jsonb_build_object(
      'status_transition',
      v_before.status || '->rejected',
      'reason',
      v_reason
    )
  );

  RETURN v_after;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_fulfill_redemption(
  p_redemption_id uuid,
  p_admin_notes text DEFAULT NULL
)
RETURNS public.redemptions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_user_id uuid := public.require_active_admin_user();
  v_actor_admin_id uuid;
  v_before public.redemptions%ROWTYPE;
  v_after public.redemptions%ROWTYPE;
  v_code text;
BEGIN
  IF p_redemption_id IS NULL THEN
    RAISE EXCEPTION 'Redemption id is required';
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
  INTO v_before
  FROM public.redemptions
  WHERE id = p_redemption_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Redemption not found';
  END IF;

  IF v_before.status <> 'approved' THEN
    RAISE EXCEPTION 'Only approved redemptions can be fulfilled';
  END IF;

  v_code := coalesce(
    nullif(trim(coalesce(v_before.redemption_code, '')), ''),
    'FZ-' || upper(substring(md5(gen_random_uuid()::text) from 1 for 8))
  );

  UPDATE public.redemptions
  SET
    status = 'fulfilled',
    redemption_code = v_code,
    admin_notes = coalesce(
      nullif(trim(coalesce(p_admin_notes, '')), ''),
      v_before.admin_notes
    ),
    reviewed_by = v_actor_admin_id,
    updated_at = timezone('utc', now())
  WHERE id = p_redemption_id
  RETURNING * INTO v_after;

  PERFORM public.admin_log_action(
    'fulfill_redemption',
    'redemptions',
    'redemption',
    p_redemption_id::text,
    to_jsonb(v_before),
    to_jsonb(v_after),
    jsonb_build_object('status_transition', 'approved->fulfilled')
  );

  RETURN v_after;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_log_action(text, text, text, text, jsonb, jsonb, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_approve_redemption(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_reject_redemption(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_fulfill_redemption(uuid, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.admin_log_action(text, text, text, text, jsonb, jsonb, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_approve_redemption(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reject_redemption(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_fulfill_redemption(uuid, text) TO authenticated;

COMMIT;
