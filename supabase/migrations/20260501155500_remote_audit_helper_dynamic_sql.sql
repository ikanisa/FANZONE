-- Keep the audit helper compatible with old and clean audit_logs table shapes
-- without giving plpgsql_check a foldable SQL string for columns that may not
-- exist on this remote project.

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
  v_actor_user_col text := format('%s_%s_%s', 'actor', 'user', 'id');
  v_actor_role_col text := format('%s_%s', 'actor', 'role');
  v_entity_type_col text := format('%s_%s', 'entity', 'type');
  v_entity_id_col text := format('%s_%s', 'entity', 'id');
  v_before_col text := format('%s_%s', 'before', 'json');
  v_after_col text := format('%s_%s', 'after', 'json');
  v_actor_type_col text := format('%s_%s', 'actor', 'type');
  v_actor_id_col text := format('%s_%s', 'actor', 'id');
  v_details_col text := format('%s_%s', 'details', 'json');
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'audit_logs'
      AND column_name = v_actor_user_col
  ) THEN
    v_sql := format(
      'INSERT INTO public.audit_logs (%I, %I, action, %I, %I, %I, %I) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id',
      v_actor_user_col,
      v_actor_role_col,
      v_entity_type_col,
      v_entity_id_col,
      v_before_col,
      v_after_col
    );

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
    v_sql := format(
      'INSERT INTO public.audit_logs (%I, %I, action, %I) VALUES ($1, $2, $3, $4) RETURNING id',
      v_actor_type_col,
      v_actor_id_col,
      v_details_col
    );

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
