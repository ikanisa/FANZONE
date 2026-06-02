-- Additive staff-call acknowledgement hardening.
-- Venue operators acknowledge bell/staff-call requests through this audited RPC
-- instead of direct client updates to public.bell_requests.

REVOKE UPDATE ON TABLE public.bell_requests FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.venue_acknowledge_bell_request(
  p_bell_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_bell record;
  v_before jsonb;
  v_after jsonb;
  v_already_acknowledged boolean;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_bell_id IS NULL THEN
    RAISE EXCEPTION 'Bell request id is required';
  END IF;

  SELECT *
  INTO v_bell
  FROM public.bell_requests
  WHERE id = p_bell_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bell request not found';
  END IF;

  IF NOT (
    public.is_active_admin_operator(v_actor)
    OR public.venue_user_has_role(
      v_bell.venue_id,
      ARRAY['owner', 'manager', 'staff']::public.venue_user_role[]
    )
  ) THEN
    RAISE EXCEPTION 'Only venue operators can acknowledge staff calls';
  END IF;

  v_before := to_jsonb(v_bell);
  v_already_acknowledged := v_bell.acknowledged_at IS NOT NULL;

  IF NOT v_already_acknowledged THEN
    UPDATE public.bell_requests
    SET
      acknowledged_at = now(),
      acknowledged_by = v_actor
    WHERE id = p_bell_id
    RETURNING * INTO v_bell;

    v_after := to_jsonb(v_bell);

    PERFORM public.sports_bar_write_audit(
      'venue_acknowledge_bell_request',
      'bell_request',
      p_bell_id::text,
      v_before,
      v_after,
      v_actor
    );
  ELSE
    v_after := v_before;
  END IF;

  RETURN jsonb_build_object(
    'id', v_bell.id,
    'venue_id', v_bell.venue_id,
    'table_id', v_bell.table_id,
    'acknowledged_at', v_bell.acknowledged_at,
    'acknowledged_by', v_bell.acknowledged_by,
    'already_acknowledged', v_already_acknowledged
  );
END;
$$;

REVOKE ALL ON FUNCTION public.venue_acknowledge_bell_request(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.venue_acknowledge_bell_request(uuid) TO authenticated, service_role;

COMMENT ON FUNCTION public.venue_acknowledge_bell_request(uuid)
IS 'Venue-scoped audited staff-call acknowledgement RPC. Operators can acknowledge bell_requests without direct client table updates.';
