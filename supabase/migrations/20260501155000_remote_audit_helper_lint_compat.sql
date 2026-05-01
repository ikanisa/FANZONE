-- Avoid static lint failures on projects whose audit_logs table still uses the
-- old details_json shape while keeping compatibility with the clean baseline.

CREATE OR REPLACE FUNCTION public.sports_bar_write_audit(
  p_action text,
  p_entity_type text,
  p_entity_id text DEFAULT NULL::text,
  p_before_json jsonb DEFAULT NULL::jsonb,
  p_after_json jsonb DEFAULT NULL::jsonb,
  p_actor_user_id uuid DEFAULT NULL::uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_id uuid;
  v_actor uuid := coalesce(p_actor_user_id, auth.uid());
  v_sql text;
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'audit_logs'
      AND column_name = 'actor_user_id'
  ) THEN
    v_sql := 'INSERT INTO public.audit_logs ('
      || 'actor_user_id, actor_role, action, entity_type, entity_id, before_json, after_json'
      || ') VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id';

    EXECUTE v_sql
    INTO v_id
    USING
      v_actor,
      coalesce(auth.role(), current_user),
      p_action,
      p_entity_type,
      p_entity_id,
      p_before_json,
      p_after_json;
  ELSE
    v_sql := 'INSERT INTO public.audit_logs ('
      || 'actor_type, actor_id, action, details_json'
      || ') VALUES ($1, $2, $3, $4) RETURNING id';

    EXECUTE v_sql
    INTO v_id
    USING
      CASE WHEN v_actor IS NULL THEN 'system' ELSE 'user' END,
      coalesce(v_actor::text, current_user),
      p_action,
      jsonb_build_object(
        'entity_type', p_entity_type,
        'entity_id', p_entity_id,
        'before_json', coalesce(p_before_json, '{}'::jsonb),
        'after_json', coalesce(p_after_json, '{}'::jsonb),
        'source', 'sports_bar_write_audit'
      );
  END IF;

  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sports_bar_write_audit(text, text, text, jsonb, jsonb, uuid) TO authenticated, service_role;
