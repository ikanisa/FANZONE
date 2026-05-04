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
      LIMIT 25
    ) q
  ),
  tiles AS (
    SELECT n,
           CASE
             WHEN n = 13 THEN 'Free'
             ELSE COALESCE(s.prompt, 'Track ' || n::text)
           END AS label
    FROM generate_series(1, 25) AS n
    LEFT JOIN selected s ON s.rn = n
  )
  SELECT jsonb_build_object(
    'size', 5,
    'tiles', jsonb_agg(
      jsonb_build_object(
        'key', 'tile_' || n::text,
        'label', label
      )
      ORDER BY n
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

CREATE OR REPLACE FUNCTION public.mark_music_bingo_tile(
  p_card_id uuid,
  p_tile_key text,
  p_marked boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_card public.music_bingo_cards%ROWTYPE;
  v_tile_key text := nullif(trim(coalesce(p_tile_key, '')), '');
  v_marks jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF v_tile_key IS NULL THEN
    RAISE EXCEPTION 'Tile key is required';
  END IF;

  SELECT * INTO v_card
  FROM public.music_bingo_cards
  WHERE id = p_card_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bingo card not found';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.game_team_members m
    WHERE m.team_id = v_card.team_id
      AND m.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'User is not a member of this team';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM jsonb_array_elements(COALESCE(v_card.card -> 'tiles', '[]'::jsonb)) tile
    WHERE tile ->> 'key' = v_tile_key
  ) THEN
    RAISE EXCEPTION 'Tile is not part of this bingo card';
  END IF;

  IF COALESCE(p_marked, true) THEN
    SELECT COALESCE(jsonb_agg(value ORDER BY value), '[]'::jsonb)
    INTO v_marks
    FROM (
      SELECT DISTINCT value
      FROM jsonb_array_elements_text(v_card.marks)
      UNION
      SELECT v_tile_key AS value
    ) marks;
  ELSE
    SELECT COALESCE(jsonb_agg(value ORDER BY value), '[]'::jsonb)
    INTO v_marks
    FROM (
      SELECT DISTINCT value
      FROM jsonb_array_elements_text(v_card.marks)
      WHERE value <> v_tile_key
    ) marks;
  END IF;

  UPDATE public.music_bingo_cards
  SET marks = v_marks,
      updated_at = timezone('utc', now())
  WHERE id = p_card_id
  RETURNING * INTO v_card;

  RETURN jsonb_build_object(
    'status', 'marked',
    'card_id', v_card.id,
    'marks', v_card.marks
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.venue_settle_game_session(
  p_session_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_session public.game_sessions%ROWTYPE;
  v_max_score bigint;
  v_reward bigint;
  v_eligible_count integer;
  v_payout_each bigint;
  v_payout_total bigint;
  v_refund bigint;
  v_eligible jsonb := '[]'::jsonb;
  v_ineligible jsonb := '[]'::jsonb;
  v_member record;
BEGIN
  SELECT * INTO v_session
  FROM public.game_sessions
  WHERE id = p_session_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Game session not found';
  END IF;

  IF NOT public.venue_user_has_role(v_session.venue_id, ARRAY['owner', 'manager', 'staff']::public.venue_user_role[]) THEN
    RAISE EXCEPTION 'Only venue staff can settle game sessions';
  END IF;

  IF v_session.status = 'settled' THEN
    RETURN jsonb_build_object(
      'status', 'already_settled',
      'game_session_id', p_session_id,
      'settlement', COALESCE(v_session.metadata -> 'settlement', '{}'::jsonb)
    );
  END IF;

  IF v_session.status NOT IN ('live', 'ended') THEN
    RAISE EXCEPTION 'Only live or ended game sessions can be settled';
  END IF;

  SELECT max(score_fet) INTO v_max_score
  FROM public.game_teams
  WHERE session_id = p_session_id;

  IF v_max_score IS NULL THEN
    RAISE EXCEPTION 'Cannot settle a game without teams';
  END IF;

  WITH winning_members AS (
    SELECT t.id AS team_id,
           t.name AS team_name,
           t.score_fet,
           m.user_id,
           public.user_has_qualifying_order(m.user_id, v_session.venue_id, v_session.scheduled_start_at) AS eligible
    FROM public.game_teams t
    JOIN public.game_team_members m ON m.team_id = t.id
    WHERE t.session_id = p_session_id
      AND t.score_fet = v_max_score
  )
  SELECT
    COALESCE(jsonb_agg(
      jsonb_build_object(
        'user_id', user_id,
        'team_id', team_id,
        'team_name', team_name,
        'score_fet', score_fet
      )
    ) FILTER (WHERE eligible), '[]'::jsonb),
    COALESCE(jsonb_agg(
      jsonb_build_object(
        'user_id', user_id,
        'team_id', team_id,
        'team_name', team_name,
        'score_fet', score_fet,
        'reason', 'no_qualifying_order'
      )
    ) FILTER (WHERE NOT eligible), '[]'::jsonb),
    (count(*) FILTER (WHERE eligible))::integer
  INTO v_eligible, v_ineligible, v_eligible_count
  FROM winning_members;

  v_reward := GREATEST(COALESCE(v_session.reward_fet, 0), 0);
  v_payout_each := CASE
    WHEN v_reward > 0 AND v_eligible_count > 0 THEN floor(v_reward::numeric / v_eligible_count)::bigint
    ELSE 0
  END;
  v_payout_total := v_payout_each * v_eligible_count;
  v_refund := v_reward - v_payout_total;

  IF v_reward > 0 THEN
    PERFORM public.venue_wallet_post_transaction(
      p_venue_id => v_session.venue_id,
      p_transaction_type => 'game_reward_settlement',
      p_direction => 'debit',
      p_amount_fet => v_reward,
      p_balance_bucket => 'staked',
      p_idempotency_key => 'game_reward_settlement_staked:' || p_session_id::text,
      p_reference_type => 'game_session',
      p_reference_id => p_session_id::text,
      p_title => 'Game reward settlement',
      p_metadata => jsonb_build_object(
        'eligible_winner_count', v_eligible_count,
        'ineligible_winners', v_ineligible,
        'payout_each_fet', v_payout_each,
        'refund_fet', v_refund
      ),
      p_game_session_id => p_session_id,
      p_created_by => auth.uid()
    );
  END IF;

  IF v_payout_each > 0 THEN
    FOR v_member IN
      SELECT (value ->> 'user_id')::uuid AS user_id,
             value ->> 'team_id' AS team_id,
             value ->> 'team_name' AS team_name
      FROM jsonb_array_elements(v_eligible)
    LOOP
      PERFORM public.wallet_post_transaction(
        p_user_id => v_member.user_id,
        p_transaction_type => 'game_winner_settlement',
        p_direction => 'credit',
        p_amount_fet => v_payout_each,
        p_balance_bucket => 'available',
        p_idempotency_key => 'game_winner_settlement:' || p_session_id::text || ':' || v_member.user_id::text,
        p_reference_type => 'game_session',
        p_reference_id => p_session_id::text,
        p_title => 'Game winner settlement',
        p_metadata => jsonb_build_object(
          'team_id', v_member.team_id,
          'team_name', v_member.team_name,
          'eligibility', 'eligible_qualifying_order'
        ),
        p_venue_id => v_session.venue_id,
        p_created_by => auth.uid()
      );
    END LOOP;
  END IF;

  IF v_refund > 0 THEN
    PERFORM public.venue_wallet_post_transaction(
      p_venue_id => v_session.venue_id,
      p_transaction_type => 'game_reward_unpaid_return',
      p_direction => 'credit',
      p_amount_fet => v_refund,
      p_balance_bucket => 'available',
      p_idempotency_key => 'game_reward_return:' || p_session_id::text,
      p_reference_type => 'game_session',
      p_reference_id => p_session_id::text,
      p_title => 'Unpaid game reward returned',
      p_metadata => jsonb_build_object(
        'reason', CASE WHEN v_eligible_count = 0 THEN 'no_eligible_winners' ELSE 'rounding_remainder' END
      ),
      p_game_session_id => p_session_id,
      p_created_by => auth.uid()
    );
  END IF;

  UPDATE public.game_sessions
  SET status = 'settled',
      ended_at = COALESCE(ended_at, timezone('utc', now())),
      metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
        'settlement', jsonb_build_object(
          'settled_at', timezone('utc', now()),
          'settled_by', auth.uid(),
          'winning_score_fet', v_max_score,
          'eligible_winners', v_eligible,
          'ineligible_winners', v_ineligible,
          'eligible_winner_count', v_eligible_count,
          'reward_fet', v_reward,
          'payout_each_fet', v_payout_each,
          'payout_total_fet', v_payout_total,
          'refund_fet', v_refund
        )
      ),
      updated_at = timezone('utc', now())
  WHERE id = p_session_id
  RETURNING * INTO v_session;

  PERFORM public.sports_bar_write_audit(
    'venue_settle_game_session',
    'game_session',
    p_session_id::text,
    NULL,
    jsonb_build_object(
      'status', 'settled',
      'eligible_winners', v_eligible,
      'ineligible_winners', v_ineligible,
      'payout_total_fet', v_payout_total,
      'refund_fet', v_refund
    )
  );

  RETURN jsonb_build_object(
    'status', 'settled',
    'game_session_id', p_session_id,
    'eligible_winners', v_eligible,
    'ineligible_winners', v_ineligible,
    'payout_each_fet', v_payout_each,
    'payout_total_fet', v_payout_total,
    'refund_fet', v_refund
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_or_create_music_bingo_card(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mark_music_bingo_tile(uuid, text, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.venue_settle_game_session(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_or_create_music_bingo_card(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mark_music_bingo_tile(uuid, text, boolean) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.venue_settle_game_session(uuid) TO authenticated, service_role;

COMMENT ON FUNCTION public.venue_settle_game_session(uuid)
IS 'Venue-staff game settlement: pays only eligible winning users from the venue reward pool, records ineligible winners, refunds unpaid reward, and writes wallet ledgers.';
