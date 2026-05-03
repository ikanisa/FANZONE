-- Venue dashboard action wiring.
-- Adds narrow, venue-scoped RPCs for operational controls that the dashboard
-- must not implement by direct table mutation.

CREATE OR REPLACE FUNCTION public.venue_close_match_pool(
  p_pool_id uuid,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_before public.match_pools%ROWTYPE;
  v_after public.match_pools%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT *
  INTO v_before
  FROM public.match_pools
  WHERE id = p_pool_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Prediction pool not found';
  END IF;

  IF v_before.venue_id IS NULL THEN
    RAISE EXCEPTION 'Prediction pool is not linked to a venue';
  END IF;

  IF NOT public.venue_user_has_role(
    v_before.venue_id,
    ARRAY['owner', 'manager']::public.venue_user_role[]
  ) THEN
    RAISE EXCEPTION 'Only venue owners or managers can close pool joining';
  END IF;

  IF v_before.status::text IN ('settled', 'cancelled') THEN
    RAISE EXCEPTION 'Prediction pool is already %', v_before.status::text;
  END IF;

  UPDATE public.match_pools
  SET status = 'locked',
      locked_at = COALESCE(locked_at, timezone('utc', now())),
      metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
        'joining_closed_by', auth.uid(),
        'joining_closed_at', timezone('utc', now()),
        'joining_closed_note', nullif(trim(coalesce(p_note, '')), '')
      ),
      updated_at = timezone('utc', now())
  WHERE id = p_pool_id
  RETURNING * INTO v_after;

  PERFORM public.sports_bar_write_audit(
    'venue_close_match_pool',
    'match_pool',
    p_pool_id::text,
    to_jsonb(v_before),
    to_jsonb(v_after)
  );

  RETURN jsonb_build_object(
    'status', 'locked',
    'pool_id', v_after.id,
    'venue_id', v_after.venue_id,
    'locked_at', v_after.locked_at
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.update_game_session_lifecycle(
  p_session_id uuid,
  p_action text,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_session public.game_sessions%ROWTYPE;
  v_next_ordinal integer;
  v_action text := lower(trim(coalesce(p_action, '')));
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT *
  INTO v_session
  FROM public.game_sessions
  WHERE id = p_session_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Game session not found';
  END IF;

  IF NOT public.venue_user_has_role(
    v_session.venue_id,
    ARRAY['owner', 'manager', 'staff']::public.venue_user_role[]
  ) THEN
    RAISE EXCEPTION 'Only venue staff can control game sessions';
  END IF;

  IF v_action = 'start' THEN
    RETURN public.start_game_session(p_session_id);
  ELSIF v_action = 'pause' THEN
    IF v_session.status <> 'live' THEN
      RAISE EXCEPTION 'Only live game sessions can be paused';
    END IF;

    UPDATE public.game_sessions
    SET metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
          'paused', true,
          'paused_at', timezone('utc', now()),
          'lifecycle_note', nullif(trim(coalesce(p_note, '')), '')
        ),
        updated_at = timezone('utc', now())
    WHERE id = p_session_id
    RETURNING * INTO v_session;
  ELSIF v_action = 'resume' THEN
    IF v_session.status <> 'live' THEN
      RAISE EXCEPTION 'Only live game sessions can be resumed';
    END IF;

    UPDATE public.game_sessions
    SET metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
          'paused', false,
          'resumed_at', timezone('utc', now()),
          'lifecycle_note', nullif(trim(coalesce(p_note, '')), '')
        ),
        updated_at = timezone('utc', now())
    WHERE id = p_session_id
    RETURNING * INTO v_session;
  ELSIF v_action = 'next_round' THEN
    IF v_session.status <> 'live' THEN
      RAISE EXCEPTION 'Only live game sessions can advance rounds';
    END IF;

    IF COALESCE(v_session.selected_question_count, 0) <= 0 THEN
      RAISE EXCEPTION 'This game session does not use numbered question rounds';
    END IF;

    v_next_ordinal := COALESCE(v_session.current_question_ordinal, 0) + 1;

    IF v_next_ordinal > v_session.selected_question_count THEN
      RAISE EXCEPTION 'Game session is already on the final round';
    END IF;

    UPDATE public.game_sessions
    SET current_question_ordinal = v_next_ordinal,
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
          'last_round_advanced_by', auth.uid(),
          'last_round_advanced_at', timezone('utc', now()),
          'lifecycle_note', nullif(trim(coalesce(p_note, '')), '')
        ),
        updated_at = timezone('utc', now())
    WHERE id = p_session_id
    RETURNING * INTO v_session;
  ELSIF v_action = 'end' THEN
    IF v_session.status IN ('ended', 'settled', 'cancelled') THEN
      RAISE EXCEPTION 'Game session is already %', v_session.status;
    END IF;

    UPDATE public.game_sessions
    SET status = 'ended',
        ended_at = COALESCE(ended_at, timezone('utc', now())),
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
          'paused', false,
          'ended_by', auth.uid(),
          'lifecycle_note', nullif(trim(coalesce(p_note, '')), '')
        ),
        updated_at = timezone('utc', now())
    WHERE id = p_session_id
    RETURNING * INTO v_session;
  ELSE
    RAISE EXCEPTION 'Unsupported game lifecycle action: %', p_action;
  END IF;

  PERFORM public.sports_bar_write_audit(
    'update_game_session_lifecycle',
    'game_session',
    p_session_id::text,
    NULL,
    jsonb_build_object(
      'action', v_action,
      'session_id', v_session.id,
      'status', v_session.status,
      'current_question_ordinal', v_session.current_question_ordinal
    )
  );

  RETURN jsonb_build_object(
    'status', v_session.status,
    'action', v_action,
    'game_session_id', v_session.id,
    'current_question_ordinal', v_session.current_question_ordinal,
    'selected_question_count', v_session.selected_question_count
  );
END;
$$;

REVOKE ALL ON FUNCTION public.venue_close_match_pool(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.update_game_session_lifecycle(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.venue_close_match_pool(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_game_session_lifecycle(uuid, text, text) TO authenticated, service_role;
