-- Fix Supabase lint ambiguity in the Music Bingo card generator.
--
-- Supabase db lint resolves unqualified `n` references in the nested
-- generate_series CTEs as ambiguous. Keep the production behavior while
-- qualifying each generated position.

CREATE OR REPLACE FUNCTION public.get_or_create_music_bingo_card(
  p_session_id uuid,
  p_team_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_session public.game_sessions%ROWTYPE;
  v_card public.music_bingo_cards%ROWTYPE;
  v_card_payload jsonb;
  v_track_count integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_session
  FROM public.game_sessions
  WHERE id = p_session_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Game session not found';
  END IF;

  IF v_session.template_id <> 'music_bingo' THEN
    RAISE EXCEPTION 'Music Bingo cards are only available for Music Bingo sessions';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.game_team_members m
    WHERE m.session_id = p_session_id
      AND m.team_id = p_team_id
      AND m.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'User is not a member of this team';
  END IF;

  SELECT * INTO v_card
  FROM public.music_bingo_cards
  WHERE session_id = p_session_id
    AND team_id = p_team_id;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'status', 'existing',
      'card_id', v_card.id,
      'session_id', v_card.session_id,
      'team_id', v_card.team_id,
      'card', v_card.card,
      'marks', v_card.marks
    );
  END IF;

  SELECT count(*)
  INTO v_track_count
  FROM public.game_questions
  WHERE template_id = 'music_bingo'
    AND is_active = true
    AND approved_at IS NOT NULL;

  IF v_track_count < 24 THEN
    RAISE EXCEPTION 'Music Bingo requires at least 24 approved active tracks before cards can be created';
  END IF;

  WITH selected AS (
    SELECT row_number() OVER ()::integer AS rn,
           q.prompt
    FROM (
      SELECT prompt
      FROM public.game_questions
      WHERE template_id = 'music_bingo'
        AND is_active = true
        AND approved_at IS NOT NULL
      ORDER BY random()
      LIMIT 24
    ) q
  ),
  positions AS (
    SELECT pos.n,
           CASE WHEN pos.n < 13 THEN pos.n ELSE pos.n - 1 END AS rn
    FROM generate_series(1, 25) AS pos(n)
    WHERE pos.n <> 13
  ),
  tiles AS (
    SELECT tile_pos.n,
           CASE
             WHEN tile_pos.n = 13 THEN 'Free'
             ELSE s.prompt
           END AS label
    FROM generate_series(1, 25) AS tile_pos(n)
    LEFT JOIN positions p ON p.n = tile_pos.n
    LEFT JOIN selected s ON s.rn = p.rn
  )
  SELECT jsonb_build_object(
    'size', 5,
    'tiles', jsonb_agg(
      jsonb_build_object(
        'key', 'tile_' || tiles.n::text,
        'label', tiles.label
      )
      ORDER BY tiles.n
    )
  )
  INTO v_card_payload
  FROM tiles;

  INSERT INTO public.music_bingo_cards (session_id, team_id, card, marks)
  VALUES (p_session_id, p_team_id, v_card_payload, '["tile_13"]'::jsonb)
  RETURNING * INTO v_card;

  RETURN jsonb_build_object(
    'status', 'created',
    'card_id', v_card.id,
    'session_id', v_card.session_id,
    'team_id', v_card.team_id,
    'card', v_card.card,
    'marks', v_card.marks
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_or_create_music_bingo_card(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_or_create_music_bingo_card(uuid, uuid) TO authenticated, service_role;
