-- Pool eligibility and game content guardrails.
--
-- The raw sports catalog can contain every team, competition, and fixture.
-- Pool creation must remain explicitly admin-gated through curated_matches.

ALTER TABLE public.curated_matches
ADD COLUMN IF NOT EXISTS is_pool_eligible boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.curated_matches.is_pool_eligible
IS 'Admin-controlled flag that allows a curated match to be used for prediction pool creation.';

CREATE INDEX IF NOT EXISTS curated_matches_pool_eligible_idx
ON public.curated_matches (is_active, is_pool_eligible, match_id, venue_id, country_code, priority_score DESC)
WHERE is_pool_eligible = true;

UPDATE public.curated_matches cm
SET is_pool_eligible = true,
    metadata = coalesce(cm.metadata, '{}'::jsonb) || jsonb_build_object('pool_eligible', true),
    updated_at = timezone('utc', now())
FROM public.matches m
LEFT JOIN public.competitions c ON c.id = m.competition_id
WHERE cm.match_id = m.id
  AND cm.is_active = true
  AND NOT (coalesce(cm.metadata -> 'tags', '[]'::jsonb) ? 'hidden')
  AND coalesce(cm.metadata ->> 'uat_fixture', 'false') <> 'true'
  AND coalesce(m.id, '') NOT ILIKE 'uat-%'
  AND coalesce(m.notes, '') NOT ILIKE '%uat%'
  AND (
    coalesce(c.type, c.competition_type) = 'world_cup'
    OR c.id IN (
      'english_premier_league',
      'la_liga',
      'serie_a',
      'ligue_1',
      'bundesliga',
      'uefa_champions_league'
    )
  );

UPDATE public.game_questions
SET is_active = false,
    metadata = coalesce(metadata, '{}'::jsonb)
      || jsonb_build_object('disabled_reason', 'uat_fixture_not_for_production'),
    updated_at = timezone('utc', now())
WHERE coalesce(metadata ->> 'uat_fixture', 'false') = 'true';

UPDATE public.game_sessions
SET status = 'cancelled',
    ended_at = coalesce(ended_at, timezone('utc', now())),
    metadata = coalesce(metadata, '{}'::jsonb)
      || jsonb_build_object('disabled_reason', 'uat_fixture_not_for_production'),
    updated_at = timezone('utc', now())
WHERE coalesce(metadata ->> 'uat_fixture', 'false') = 'true'
  AND status IN ('scheduled', 'lobby', 'live', 'ended');

CREATE OR REPLACE VIEW public.curated_active_matches AS
SELECT
  m.id,
  m.competition_id,
  c.name AS competition_name,
  m.season_id,
  s.season_label,
  m.stage,
  m.matchday_or_round AS round,
  m.matchday_or_round,
  m.match_date,
  m.match_date AS date,
  to_char((m.match_date AT TIME ZONE 'UTC'), 'HH24:MI') AS kickoff_time,
  m.home_team_id,
  ht.name AS home_team,
  coalesce(ht.crest_url, ht.logo_url) AS home_logo_url,
  m.away_team_id,
  at.name AS away_team,
  coalesce(at.crest_url, at.logo_url) AS away_logo_url,
  coalesce(m.home_goals, m.home_score, m.live_home_score) AS ft_home,
  coalesce(m.away_goals, m.away_score, m.live_away_score) AS ft_away,
  m.home_goals,
  m.away_goals,
  m.result_code,
  CASE
    WHEN coalesce(m.status, m.match_status) = 'final' OR m.match_status = 'finished' THEN 'final'
    WHEN m.match_status IN ('live') OR m.status = 'live' THEN 'live'
    WHEN m.match_status IN ('cancelled', 'postponed') THEN m.match_status
    ELSE 'scheduled'
  END AS status,
  m.match_status,
  m.is_neutral,
  coalesce(m.source, m.source_name, 'manual') AS data_source,
  m.source_name,
  m.source_url,
  m.notes,
  m.created_at,
  m.updated_at,
  m.live_home_score,
  m.live_away_score,
  m.live_minute,
  m.live_phase,
  m.last_live_checked_at,
  m.last_live_sync_confidence,
  m.last_live_review_required,
  m.winner_camp,
  m.country_visibility,
  cm.id AS curation_id,
  cm.country_code AS curation_country_code,
  cm.venue_id AS curation_venue_id,
  cm.priority_score,
  cm.reason AS curation_reason,
  cm.metadata AS curation_metadata,
  coalesce(cm.metadata -> 'tags', '[]'::jsonb) AS curation_tags,
  coalesce((cm.metadata -> 'tags') ? 'global', cm.country_code IS NULL AND cm.venue_id IS NULL) AS is_global_featured,
  coalesce((cm.metadata -> 'tags') ? 'country', cm.country_code IS NOT NULL) AS is_country_featured,
  coalesce((cm.metadata -> 'tags') ? 'venue_relevant', cm.venue_id IS NOT NULL) AS is_venue_featured,
  public.sports_bar_is_default_competition(c.id, c.name, coalesce(c.type, c.competition_type)) AS is_default_competition,
  (coalesce(c.type, c.competition_type) = 'world_cup'
    OR public.sports_bar_is_default_competition(c.id, c.name, coalesce(c.type, c.competition_type))
       AND regexp_replace(lower(coalesce(c.id, '') || coalesce(c.name, '')), '[^a-z0-9]+', '', 'g') LIKE '%worldcup%') AS is_world_cup,
  cm.is_pool_eligible
FROM public.curated_matches cm
JOIN public.matches m ON m.id = cm.match_id
LEFT JOIN public.competitions c ON c.id = m.competition_id
LEFT JOIN public.seasons s ON s.id = m.season_id
LEFT JOIN public.teams ht ON ht.id = m.home_team_id
LEFT JOIN public.teams at ON at.id = m.away_team_id
WHERE cm.is_active = true
  AND (cm.starts_at IS NULL OR cm.starts_at <= timezone('utc', now()))
  AND (cm.expires_at IS NULL OR cm.expires_at > timezone('utc', now()))
  AND NOT (coalesce(cm.metadata -> 'tags', '[]'::jsonb) ? 'hidden')
  AND coalesce(c.is_active, true) = true
  AND coalesce(m.hide_from_home, false) = false
  AND m.match_status IN ('scheduled', 'live', 'finished', 'postponed', 'cancelled');

COMMENT ON VIEW public.curated_active_matches
IS 'Public curated match projection. is_pool_eligible marks the smaller admin-approved set allowed for prediction pools.';

CREATE OR REPLACE FUNCTION public.admin_curate_match_control(
  p_match_id text,
  p_country_code text DEFAULT NULL::text,
  p_venue_id uuid DEFAULT NULL::uuid,
  p_priority_score integer DEFAULT 50,
  p_reason text DEFAULT ''::text,
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_starts_at timestamp with time zone DEFAULT NULL::timestamp with time zone,
  p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone,
  p_is_active boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'extensions'
AS $$
DECLARE
  v_country_code text := nullif(upper(trim(coalesce(p_country_code, ''))), '');
  v_reason text := coalesce(nullif(trim(p_reason), ''), 'admin curated');
  v_metadata jsonb := coalesce(p_metadata, '{}'::jsonb);
  v_pool_eligible boolean := CASE
    WHEN coalesce(p_metadata, '{}'::jsonb) ? 'pool_eligible'
      THEN lower(coalesce(p_metadata ->> 'pool_eligible', 'false')) IN ('true', '1', 'yes', 'on')
    ELSE NULL
  END;
  v_before jsonb;
  v_curated public.curated_matches%ROWTYPE;
BEGIN
  IF NOT public.current_user_has_admin_role(ARRAY['moderator', 'admin', 'super_admin']) THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  IF v_country_code IS NOT NULL AND v_country_code !~ '^[A-Z]{2}$' THEN
    RAISE EXCEPTION 'country code must use ISO-3166 alpha-2 format';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.matches WHERE id = p_match_id) THEN
    RAISE EXCEPTION 'Match not found';
  END IF;

  SELECT to_jsonb(cm)
  INTO v_before
  FROM public.curated_matches cm
  WHERE cm.match_id = p_match_id
    AND coalesce(cm.country_code, '') = coalesce(v_country_code, '')
    AND coalesce(cm.venue_id, '00000000-0000-0000-0000-000000000000'::uuid) = coalesce(p_venue_id, '00000000-0000-0000-0000-000000000000'::uuid)
  LIMIT 1;

  UPDATE public.curated_matches
  SET country_code = v_country_code,
      venue_id = p_venue_id,
      priority_score = greatest(0, coalesce(p_priority_score, 0)),
      reason = v_reason,
      metadata = v_metadata || jsonb_build_object(
        'pool_eligible',
        coalesce(v_pool_eligible, curated_matches.is_pool_eligible)
      ),
      starts_at = p_starts_at,
      expires_at = p_expires_at,
      is_active = coalesce(p_is_active, true),
      is_pool_eligible = coalesce(v_pool_eligible, curated_matches.is_pool_eligible),
      curated_by = auth.uid(),
      updated_at = timezone('utc', now())
  WHERE match_id = p_match_id
    AND coalesce(country_code, '') = coalesce(v_country_code, '')
    AND coalesce(venue_id, '00000000-0000-0000-0000-000000000000'::uuid) = coalesce(p_venue_id, '00000000-0000-0000-0000-000000000000'::uuid)
  RETURNING * INTO v_curated;

  IF NOT FOUND THEN
    INSERT INTO public.curated_matches (
      match_id,
      country_code,
      venue_id,
      priority_score,
      reason,
      metadata,
      starts_at,
      expires_at,
      is_active,
      is_pool_eligible,
      curated_by
    )
    VALUES (
      p_match_id,
      v_country_code,
      p_venue_id,
      greatest(0, coalesce(p_priority_score, 0)),
      v_reason,
      v_metadata || jsonb_build_object('pool_eligible', coalesce(v_pool_eligible, false)),
      p_starts_at,
      p_expires_at,
      coalesce(p_is_active, true),
      coalesce(v_pool_eligible, false),
      auth.uid()
    )
    RETURNING * INTO v_curated;
  END IF;

  UPDATE public.matches
  SET is_curated = true,
      country_visibility = CASE
        WHEN v_country_code IS NULL THEN country_visibility
        WHEN v_country_code = ANY(country_visibility) THEN country_visibility
        ELSE array_append(country_visibility, v_country_code)
      END,
      updated_at = timezone('utc', now())
  WHERE id = p_match_id;

  PERFORM public.sports_bar_write_audit(
    'admin_curate_match_control',
    'curated_match',
    v_curated.id::text,
    v_before,
    to_jsonb(v_curated)
  );

  RETURN jsonb_build_object('status', 'curated', 'curation', to_jsonb(v_curated));
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_curated_match_pool_eligible(
  p_curated_match_id uuid,
  p_is_pool_eligible boolean
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_before jsonb;
  v_after jsonb;
BEGIN
  IF NOT public.current_user_has_admin_role(ARRAY['moderator', 'admin', 'super_admin']) THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  SELECT to_jsonb(cm)
  INTO v_before
  FROM public.curated_matches cm
  WHERE id = p_curated_match_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Curated match not found';
  END IF;

  UPDATE public.curated_matches
  SET is_pool_eligible = coalesce(p_is_pool_eligible, false),
      metadata = jsonb_set(
        coalesce(metadata, '{}'::jsonb),
        '{pool_eligible}',
        to_jsonb(coalesce(p_is_pool_eligible, false)),
        true
      ),
      updated_at = timezone('utc', now())
  WHERE id = p_curated_match_id
  RETURNING to_jsonb(curated_matches.*) INTO v_after;

  PERFORM public.sports_bar_write_audit(
    'admin_set_curated_match_pool_eligible',
    'curated_match',
    p_curated_match_id::text,
    v_before,
    v_after
  );

  RETURN jsonb_build_object('status', 'updated', 'curation', v_after);
END;
$$;

CREATE OR REPLACE FUNCTION public.venue_pool_match_options(
  p_venue_id uuid,
  p_limit integer DEFAULT 50
) RETURNS TABLE(
  match_id text,
  match_label text,
  competition_name text,
  kickoff_at timestamp with time zone,
  match_status text,
  country_code text,
  venue_id uuid,
  curation_reason text,
  priority_score integer,
  official_pool_id uuid
)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT
    cm.match_id,
    coalesce(m.home_team, 'Home') || ' vs ' || coalesce(m.away_team, 'Away') AS match_label,
    m.competition_name,
    m.match_date AS kickoff_at,
    coalesce(m.match_status, m.status) AS match_status,
    cm.country_code,
    cm.venue_id,
    cm.reason AS curation_reason,
    cm.priority_score,
    existing.id AS official_pool_id
  FROM public.curated_matches cm
  JOIN public.app_matches m ON m.id = cm.match_id
  LEFT JOIN public.match_pools existing
    ON existing.match_id = cm.match_id
   AND existing.venue_id = p_venue_id
   AND existing.scope = 'venue'
   AND existing.is_official = true
   AND existing.status <> 'cancelled'
  WHERE public.dinein_is_venue_member(p_venue_id)
    AND cm.is_active = true
    AND cm.is_pool_eligible = true
    AND (cm.starts_at IS NULL OR cm.starts_at <= timezone('utc', now()))
    AND (cm.expires_at IS NULL OR cm.expires_at > timezone('utc', now()))
    AND (cm.venue_id = p_venue_id OR cm.venue_id IS NULL)
    AND m.match_date > timezone('utc', now()) - interval '2 hours'
    AND coalesce(m.match_status, m.status) IN ('scheduled', 'upcoming', 'not_started', 'pending')
  ORDER BY
    CASE WHEN cm.venue_id = p_venue_id THEN 0 ELSE 1 END,
    cm.priority_score DESC,
    m.match_date ASC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 100));
$$;

CREATE OR REPLACE FUNCTION public.create_venue_official_match_pool(
  p_venue_id uuid,
  p_match_id text,
  p_title text DEFAULT NULL::text,
  p_entry_fee_fet bigint DEFAULT 1,
  p_stake_min_fet bigint DEFAULT 1,
  p_stake_max_fet bigint DEFAULT 100000,
  p_creator_reward_fet bigint DEFAULT 1,
  p_bar_stake_fet bigint DEFAULT 0
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_result jsonb;
  v_pool_id uuid;
  v_bar_stake bigint := GREATEST(COALESCE(p_bar_stake_fet, 0), 0);
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT public.venue_user_has_role(
    p_venue_id,
    ARRAY['owner', 'manager']::public.venue_user_role[]
  ) THEN
    RAISE EXCEPTION 'Only venue owners or managers can create official pools';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.curated_matches cm
    JOIN public.venues v ON v.id = p_venue_id
    WHERE cm.match_id = p_match_id
      AND cm.is_active = true
      AND cm.is_pool_eligible = true
      AND (cm.starts_at IS NULL OR cm.starts_at <= timezone('utc', now()))
      AND (cm.expires_at IS NULL OR cm.expires_at > timezone('utc', now()))
      AND (cm.venue_id = p_venue_id OR cm.venue_id IS NULL)
      AND (cm.country_code IS NULL OR cm.country_code = v.country_code)
  ) THEN
    RAISE EXCEPTION 'This match is not admin-approved for venue pool creation';
  END IF;

  v_result := public.create_pool(
    p_match_id => p_match_id,
    p_scope => 'venue',
    p_country_id => NULL,
    p_venue_id => p_venue_id,
    p_title => p_title,
    p_stake_min => GREATEST(COALESCE(NULLIF(p_entry_fee_fet, 0), p_stake_min_fet), 1),
    p_stake_max => GREATEST(COALESCE(p_stake_max_fet, 1), GREATEST(COALESCE(NULLIF(p_entry_fee_fet, 0), p_stake_min_fet), 1)),
    p_creator_reward_per_qualified_member => GREATEST(COALESCE(p_creator_reward_fet, 0), 0),
    p_rules_json => jsonb_build_object('is_official', true, 'created_by_venue_dashboard', true),
    p_allow_multiple => false
  );

  v_pool_id := (v_result ->> 'pool_id')::uuid;

  UPDATE public.match_pools
  SET creator_reward_fet = GREATEST(COALESCE(p_creator_reward_fet, 1), 0),
      creator_reward_rules = creator_reward_rules
        || jsonb_build_object(
          'status', 'active',
          'requires_invite', true,
          'requires_paid_entry', true,
          'reward_source', 'match_pool_invites'
        ),
      updated_at = timezone('utc', now())
  WHERE id = v_pool_id;

  IF (v_result ->> 'status') = 'created' AND v_bar_stake > 0 THEN
    PERFORM public.venue_wallet_post_transaction(
      p_venue_id => p_venue_id,
      p_transaction_type => 'venue_pool_stake',
      p_direction => 'debit',
      p_amount_fet => v_bar_stake,
      p_balance_bucket => 'available',
      p_idempotency_key => 'venue_pool_stake_available:' || v_pool_id::text,
      p_reference_type => 'match_pool',
      p_reference_id => v_pool_id::text,
      p_title => 'Venue pool stake',
      p_metadata => jsonb_build_object('match_id', p_match_id),
      p_pool_id => v_pool_id,
      p_created_by => auth.uid()
    );

    PERFORM public.venue_wallet_post_transaction(
      p_venue_id => p_venue_id,
      p_transaction_type => 'venue_pool_stake',
      p_direction => 'credit',
      p_amount_fet => v_bar_stake,
      p_balance_bucket => 'staked',
      p_idempotency_key => 'venue_pool_stake_locked:' || v_pool_id::text,
      p_reference_type => 'match_pool',
      p_reference_id => v_pool_id::text,
      p_title => 'Venue pool stake locked',
      p_metadata => jsonb_build_object('match_id', p_match_id),
      p_pool_id => v_pool_id,
      p_created_by => auth.uid()
    );

    UPDATE public.match_pools
    SET total_staked_fet = total_staked_fet + v_bar_stake,
        metadata = COALESCE(metadata, '{}'::jsonb)
          || jsonb_build_object(
            'bar_stake_fet', v_bar_stake,
            'bar_stake_status', 'locked',
            'bar_stake_venue_id', p_venue_id
          ),
        updated_at = timezone('utc', now())
    WHERE id = v_pool_id;
  END IF;

  RETURN v_result || jsonb_build_object(
    'creator_reward_fet', GREATEST(COALESCE(p_creator_reward_fet, 1), 0),
    'bar_stake_fet', v_bar_stake
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.match_pool_requires_pool_eligible_match()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_country_code text;
BEGIN
  SELECT v.country_code
  INTO v_country_code
  FROM public.venues v
  WHERE v.id = NEW.venue_id
    AND v.is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active venue not found';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.curated_matches cm
    WHERE cm.match_id = NEW.match_id
      AND cm.is_active = true
      AND cm.is_pool_eligible = true
      AND (cm.starts_at IS NULL OR cm.starts_at <= timezone('utc', now()))
      AND (cm.expires_at IS NULL OR cm.expires_at > timezone('utc', now()))
      AND NOT (coalesce(cm.metadata -> 'tags', '[]'::jsonb) ? 'hidden')
      AND (cm.venue_id = NEW.venue_id OR cm.venue_id IS NULL)
      AND (cm.country_code IS NULL OR cm.country_code = v_country_code)
  ) THEN
    RAISE EXCEPTION 'Match is not pool eligible. An admin must activate pool eligibility before pool creation.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS match_pool_requires_pool_eligible_match_trigger ON public.match_pools;
CREATE TRIGGER match_pool_requires_pool_eligible_match_trigger
BEFORE INSERT OR UPDATE OF match_id, venue_id
ON public.match_pools
FOR EACH ROW
EXECUTE FUNCTION public.match_pool_requires_pool_eligible_match();

CREATE OR REPLACE FUNCTION public.create_game_session(
  p_venue_id uuid,
  p_template_id text,
  p_scheduled_start_at timestamp with time zone,
  p_reward_fet bigint DEFAULT 0
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_template public.game_templates%ROWTYPE;
  v_session public.game_sessions%ROWTYPE;
  v_required_questions integer := 0;
  v_selected_count integer := 0;
  v_reward bigint := GREATEST(COALESCE(p_reward_fet, 0), 0);
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT public.venue_user_has_role(p_venue_id, ARRAY['owner', 'manager']::public.venue_user_role[]) THEN
    RAISE EXCEPTION 'Only venue owners or managers can create game sessions';
  END IF;

  SELECT * INTO v_template
  FROM public.game_templates
  WHERE id = p_template_id
    AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active game template not found';
  END IF;

  IF v_template.category IN ('trivia', 'song_guess') THEN
    v_required_questions := 20;
  END IF;

  IF v_required_questions > 0 THEN
    SELECT count(*)::integer
    INTO v_selected_count
    FROM public.game_questions q
    WHERE q.template_id = p_template_id
      AND q.is_active = true
      AND q.approved_at IS NOT NULL
      AND coalesce(q.metadata ->> 'uat_fixture', 'false') <> 'true';

    IF v_selected_count < v_required_questions THEN
      RAISE EXCEPTION 'Not enough production-approved questions for this game template';
    END IF;
  END IF;

  INSERT INTO public.game_sessions (
    venue_id,
    template_id,
    status,
    scheduled_start_at,
    reward_fet,
    selected_question_count,
    created_by,
    metadata
  )
  VALUES (
    p_venue_id,
    p_template_id,
    'scheduled',
    p_scheduled_start_at,
    v_reward,
    0,
    auth.uid(),
    jsonb_build_object('template_category', v_template.category, 'eligibility_window_minutes', 120)
  )
  RETURNING * INTO v_session;

  IF v_required_questions > 0 THEN
    WITH selected AS (
      SELECT q.*
      FROM public.game_questions q
      WHERE q.template_id = p_template_id
        AND q.is_active = true
        AND q.approved_at IS NOT NULL
        AND coalesce(q.metadata ->> 'uat_fixture', 'false') <> 'true'
      ORDER BY random()
      LIMIT v_required_questions
    ),
    chosen AS (
      SELECT selected.*,
             (row_number() OVER ())::integer AS ordinal
      FROM selected
    )
    INSERT INTO public.game_session_questions (session_id, question_id, ordinal, snapshot)
    SELECT v_session.id,
           c.id,
           c.ordinal,
           jsonb_build_object(
             'prompt', c.prompt,
             'options', c.options,
             'correct_answer', c.correct_answer,
             'template_id', c.template_id,
             'question_created_at', c.created_at
           )
    FROM chosen c;

    UPDATE public.game_sessions
    SET selected_question_count = v_required_questions,
        updated_at = timezone('utc', now())
    WHERE id = v_session.id
    RETURNING * INTO v_session;
  END IF;

  IF v_reward > 0 THEN
    PERFORM public.venue_wallet_post_transaction(
      p_venue_id => p_venue_id,
      p_transaction_type => 'game_reward_pool',
      p_direction => 'debit',
      p_amount_fet => v_reward,
      p_balance_bucket => 'available',
      p_idempotency_key => 'game_reward_available:' || v_session.id::text,
      p_reference_type => 'game_session',
      p_reference_id => v_session.id::text,
      p_title => 'Game reward pool',
      p_game_session_id => v_session.id,
      p_created_by => auth.uid()
    );

    PERFORM public.venue_wallet_post_transaction(
      p_venue_id => p_venue_id,
      p_transaction_type => 'game_reward_pool',
      p_direction => 'credit',
      p_amount_fet => v_reward,
      p_balance_bucket => 'staked',
      p_idempotency_key => 'game_reward_locked:' || v_session.id::text,
      p_reference_type => 'game_session',
      p_reference_id => v_session.id::text,
      p_title => 'Game reward pool locked',
      p_game_session_id => v_session.id,
      p_created_by => auth.uid()
    );
  END IF;

  RETURN jsonb_build_object(
    'status', 'created',
    'game_session_id', v_session.id,
    'venue_id', v_session.venue_id,
    'template_id', v_session.template_id,
    'selected_question_count', v_session.selected_question_count,
    'reward_fet', v_session.reward_fet
  );
END;
$$;

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
    SELECT n,
           CASE WHEN n < 13 THEN n ELSE n - 1 END AS rn
    FROM generate_series(1, 25) AS n
    WHERE n <> 13
  ),
  tiles AS (
    SELECT n,
           CASE
             WHEN n = 13 THEN 'Free'
             ELSE s.prompt
           END AS label
    FROM generate_series(1, 25) AS n
    LEFT JOIN positions p ON p.n = n
    LEFT JOIN selected s ON s.rn = p.rn
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

REVOKE ALL ON FUNCTION public.admin_set_curated_match_pool_eligible(uuid, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_set_curated_match_pool_eligible(uuid, boolean) TO authenticated, service_role;

GRANT SELECT ON TABLE public.curated_active_matches TO anon, authenticated, service_role;
