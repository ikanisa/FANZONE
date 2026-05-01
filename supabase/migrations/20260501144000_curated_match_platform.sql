-- Curated sports-bar match platform.
-- Public match discovery must read curated matches only; raw imported fixtures remain
-- available for admin curation and future fixture-source ingestion.

CREATE OR REPLACE FUNCTION public.sports_bar_is_default_competition(
  p_id text,
  p_name text,
  p_type text DEFAULT NULL::text
) RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  WITH normalized AS (
    SELECT regexp_replace(lower(coalesce(p_id, '') || ' ' || coalesce(p_name, '') || ' ' || coalesce(p_type, '')), '[^a-z0-9]+', '', 'g') AS value
  )
  SELECT value LIKE '%englishpremierleague%'
      OR value LIKE '%englandpremierleague%'
      OR value LIKE '%epl%'
      OR value LIKE '%laliga%'
      OR value LIKE '%seriea%'
      OR value LIKE '%ligue1%'
      OR value LIKE '%bundesliga%'
      OR value LIKE '%uefachampionsleague%'
      OR value LIKE '%ucl%'
      OR value LIKE '%uefaeuropaleague%'
      OR value LIKE '%uel%'
      OR value LIKE '%fifaworldcup%'
      OR value LIKE '%worldcup%'
  FROM normalized;
$$;

COMMENT ON FUNCTION public.sports_bar_is_default_competition(text, text, text)
IS 'Identifies the small default competition catalog allowed for the sports-bar pool product.';

WITH approved_competitions (
  id,
  name,
  short_name,
  country,
  country_or_region,
  competition_type,
  type,
  region,
  priority,
  is_international
) AS (
  VALUES
    ('english_premier_league', 'English Premier League', 'EPL', 'England', 'Europe', 'league', 'league', 'europe', 10, false),
    ('la_liga', 'La Liga', 'La Liga', 'Spain', 'Europe', 'league', 'league', 'europe', 20, false),
    ('serie_a', 'Serie A', 'Serie A', 'Italy', 'Europe', 'league', 'league', 'europe', 30, false),
    ('ligue_1', 'Ligue 1', 'Ligue 1', 'France', 'Europe', 'league', 'league', 'europe', 40, false),
    ('bundesliga', 'Bundesliga', 'Bundesliga', 'Germany', 'Europe', 'league', 'league', 'europe', 50, false),
    ('uefa_champions_league', 'UEFA Champions League', 'UCL', 'International', 'Europe', 'cup', 'cup', 'europe', 5, true),
    ('uefa_europa_league', 'UEFA Europa League', 'UEL', 'International', 'Europe', 'cup', 'cup', 'europe', 60, true),
    ('fifa_world_cup', 'FIFA World Cup', 'World Cup', 'International', 'World Cup markets', 'world_cup', 'world_cup', 'global', 1, true)
)
INSERT INTO public.competitions (
  id,
  name,
  short_name,
  country,
  country_or_region,
  competition_type,
  type,
  region,
  priority,
  is_international,
  tier,
  data_source,
  is_active,
  is_featured,
  status,
  updated_at
)
SELECT
  id,
  name,
  short_name,
  country,
  country_or_region,
  competition_type,
  type,
  region,
  priority,
  is_international,
  1,
  'sports_bar_seed',
  true,
  true,
  'active',
  timezone('utc', now())
FROM approved_competitions
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    short_name = EXCLUDED.short_name,
    country = EXCLUDED.country,
    country_or_region = EXCLUDED.country_or_region,
    competition_type = EXCLUDED.competition_type,
    type = EXCLUDED.type,
    region = EXCLUDED.region,
    priority = EXCLUDED.priority,
    is_international = EXCLUDED.is_international,
    is_active = true,
    is_featured = true,
    status = 'active',
    updated_at = timezone('utc', now());

UPDATE public.competitions
SET is_active = false,
    is_featured = false,
    status = 'disabled',
    updated_at = timezone('utc', now())
WHERE NOT public.sports_bar_is_default_competition(id, name, coalesce(type, competition_type))
  AND coalesce(type, competition_type, '') <> 'local_curated';

COMMENT ON TABLE public.competitions
IS 'Approved competition catalog. Default app display is limited to the sports-bar competition set; local competitions must be explicitly curated.';

COMMENT ON TABLE public.matches
IS 'Imported match catalog. Public app display must use curated_active_matches/get_curated_matches, not this raw catalog.';

COMMENT ON TABLE public.teams
IS 'Team catalog for curated matches, World Cup teams, and admin-managed team metadata.';

CREATE TABLE IF NOT EXISTS public.fixture_sources (
  id text PRIMARY KEY,
  name text NOT NULL,
  source_type text DEFAULT 'manual' NOT NULL,
  is_approved boolean DEFAULT false NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  config_json jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc', now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc', now()) NOT NULL,
  CONSTRAINT fixture_sources_type_check CHECK (source_type = ANY (ARRAY['manual', 'csv', 'api', 'admin_import']))
);

COMMENT ON TABLE public.fixture_sources
IS 'Fixture-source registry for future ingestion. Imported fixtures still require admin curation before public display.';

INSERT INTO public.fixture_sources (id, name, source_type, is_approved, is_active)
VALUES ('manual_admin', 'Manual admin curation/import', 'manual', true, true)
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    source_type = EXCLUDED.source_type,
    is_approved = EXCLUDED.is_approved,
    is_active = EXCLUDED.is_active,
    updated_at = timezone('utc', now());

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
       AND regexp_replace(lower(coalesce(c.id, '') || coalesce(c.name, '')), '[^a-z0-9]+', '', 'g') LIKE '%worldcup%') AS is_world_cup
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
IS 'Public curated match projection for app pool discovery. This intentionally excludes raw uncurated fixtures.';

CREATE OR REPLACE FUNCTION public.get_curated_matches(
  p_country_code text DEFAULT NULL::text,
  p_venue_id uuid DEFAULT NULL::uuid,
  p_date_from timestamp with time zone DEFAULT NULL::timestamp with time zone,
  p_date_to timestamp with time zone DEFAULT NULL::timestamp with time zone,
  p_status text DEFAULT NULL::text,
  p_competition_id text DEFAULT NULL::text,
  p_team_id text DEFAULT NULL::text,
  p_limit integer DEFAULT 100
) RETURNS SETOF public.curated_active_matches
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT cam.*
  FROM public.curated_active_matches cam
  LEFT JOIN public.venues active_venue ON active_venue.id = p_venue_id
  WHERE (p_date_from IS NULL OR cam.date >= p_date_from)
    AND (p_date_to IS NULL OR cam.date <= p_date_to)
    AND (
      p_status IS NULL
      OR p_status = ''
      OR lower(p_status) = cam.status
      OR (lower(p_status) = 'upcoming' AND cam.status = 'scheduled')
      OR (lower(p_status) = 'finished' AND cam.status = 'final')
    )
    AND (p_competition_id IS NULL OR p_competition_id = '' OR cam.competition_id = p_competition_id)
    AND (
      p_team_id IS NULL
      OR p_team_id = ''
      OR cam.home_team_id = p_team_id
      OR cam.away_team_id = p_team_id
    )
  ORDER BY
    CASE WHEN p_venue_id IS NOT NULL AND cam.curation_venue_id = p_venue_id THEN 0 ELSE 1 END,
    CASE WHEN active_venue.country_code IS NOT NULL AND cam.curation_country_code = active_venue.country_code THEN 0 ELSE 1 END,
    CASE WHEN nullif(upper(coalesce(p_country_code, '')), '') IS NOT NULL AND cam.curation_country_code = upper(p_country_code) THEN 0 ELSE 1 END,
    CASE WHEN cam.is_venue_featured THEN 0 ELSE 1 END,
    CASE WHEN cam.is_global_featured THEN 0 ELSE 1 END,
    CASE WHEN cam.is_world_cup THEN 0 ELSE 1 END,
    cam.priority_score DESC,
    cam.date ASC,
    cam.id ASC
  LIMIT greatest(1, least(coalesce(p_limit, 100), 500));
$$;

COMMENT ON FUNCTION public.get_curated_matches(text, uuid, timestamp with time zone, timestamp with time zone, text, text, text, integer)
IS 'Curated match feed ordered for the active venue/country, global featured matches, and World Cup relevance.';

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
      metadata = coalesce(p_metadata, '{}'::jsonb),
      starts_at = p_starts_at,
      expires_at = p_expires_at,
      is_active = coalesce(p_is_active, true),
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
      curated_by
    )
    VALUES (
      p_match_id,
      v_country_code,
      p_venue_id,
      greatest(0, coalesce(p_priority_score, 0)),
      v_reason,
      coalesce(p_metadata, '{}'::jsonb),
      p_starts_at,
      p_expires_at,
      coalesce(p_is_active, true),
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

CREATE OR REPLACE FUNCTION public.admin_set_curated_match_active(
  p_curated_match_id uuid,
  p_is_active boolean
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
  SET is_active = coalesce(p_is_active, false),
      updated_at = timezone('utc', now())
  WHERE id = p_curated_match_id
  RETURNING to_jsonb(curated_matches.*) INTO v_after;

  PERFORM public.sports_bar_write_audit(
    'admin_set_curated_match_active',
    'curated_match',
    p_curated_match_id::text,
    v_before,
    v_after
  );

  RETURN jsonb_build_object('status', 'updated', 'curation', v_after);
END;
$$;

CREATE OR REPLACE FUNCTION public.settle_finished_match_pools(p_limit integer DEFAULT 50) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_pool_id uuid;
  v_count int := 0;
BEGIN
  FOR v_pool_id IN
    SELECT p.id
    FROM public.match_pools p
    JOIN public.matches m ON m.id = p.match_id
    WHERE p.status IN ('open', 'locked', 'live', 'settling')
      AND m.match_status = 'finished'
      AND m.result_code IS NOT NULL
    ORDER BY m.match_date, p.created_at
    LIMIT greatest(1, least(coalesce(p_limit, 50), 250))
  LOOP
    BEGIN
      PERFORM public.settle_match_pool(v_pool_id);
      v_count := v_count + 1;
    EXCEPTION
      WHEN OTHERS THEN
        INSERT INTO public.match_pool_settlements (
          pool_id,
          status,
          idempotency_key,
          match_id,
          metadata
        )
        SELECT
          v_pool_id,
          'failed',
          'match-pool-settlement-' || v_pool_id::text,
          match_id,
          jsonb_build_object('error', SQLERRM, 'failed_at', timezone('utc', now()))
        FROM public.match_pools
        WHERE id = v_pool_id
        ON CONFLICT (pool_id) DO UPDATE
        SET status = 'failed',
            metadata = public.match_pool_settlements.metadata
              || jsonb_build_object('error', SQLERRM, 'failed_at', timezone('utc', now()));
    END;
  END LOOP;

  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_match_live_score(
  p_match_id text,
  p_home_score integer,
  p_away_score integer,
  p_status text DEFAULT 'live'::text,
  p_source text DEFAULT 'manual'::text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_before jsonb;
  v_after jsonb;
  v_result_code text;
  v_pool_id uuid;
  v_refunded integer := 0;
  v_settled integer := 0;
  v_status text := lower(trim(coalesce(p_status, 'live')));
BEGIN
  IF NOT public.sports_bar_is_admin() THEN
    RAISE EXCEPTION 'Only admins can update match scores';
  END IF;

  IF v_status NOT IN ('scheduled', 'live', 'final', 'cancelled', 'postponed') THEN
    RAISE EXCEPTION 'Invalid match status';
  END IF;

  IF v_status = 'final' AND (p_home_score IS NULL OR p_away_score IS NULL) THEN
    RAISE EXCEPTION 'Final result requires home and away scores';
  END IF;

  SELECT to_jsonb(m) INTO v_before
  FROM public.matches m
  WHERE id = p_match_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Match not found';
  END IF;

  v_result_code := CASE
    WHEN v_status = 'final' THEN public.sports_bar_result_code(p_home_score, p_away_score)
    ELSE NULL
  END;

  UPDATE public.matches
  SET status = v_status,
      match_status = CASE WHEN v_status = 'final' THEN 'finished' ELSE v_status END,
      home_score = CASE WHEN v_status IN ('live', 'final') THEN p_home_score ELSE home_score END,
      away_score = CASE WHEN v_status IN ('live', 'final') THEN p_away_score ELSE away_score END,
      live_home_score = CASE WHEN v_status IN ('live', 'final') THEN p_home_score ELSE live_home_score END,
      live_away_score = CASE WHEN v_status IN ('live', 'final') THEN p_away_score ELSE live_away_score END,
      home_goals = CASE WHEN v_status = 'final' THEN p_home_score WHEN v_status IN ('cancelled', 'postponed') THEN NULL ELSE home_goals END,
      away_goals = CASE WHEN v_status = 'final' THEN p_away_score WHEN v_status IN ('cancelled', 'postponed') THEN NULL ELSE away_goals END,
      result_code = CASE WHEN v_status = 'final' THEN v_result_code WHEN v_status IN ('cancelled', 'postponed') THEN NULL ELSE result_code END,
      winner_camp = CASE WHEN v_status = 'final' THEN public.sports_bar_winner_camp(v_result_code) WHEN v_status IN ('cancelled', 'postponed') THEN NULL ELSE winner_camp END,
      source = coalesce(p_source, source),
      updated_at = timezone('utc', now())
  WHERE id = p_match_id
  RETURNING to_jsonb(matches.*) INTO v_after;

  PERFORM public.sports_bar_write_audit('update_match_live_score', 'match', p_match_id, v_before, v_after);

  IF v_status = 'live' THEN
    PERFORM public.lock_pool_for_match_start(p_match_id);
  ELSIF v_status = 'final' THEN
    PERFORM public.lock_pool_for_match_start(p_match_id);
    v_settled := public.settle_finished_match_pools(250);
  ELSIF v_status IN ('cancelled', 'postponed') THEN
    FOR v_pool_id IN
      SELECT id
      FROM public.match_pools
      WHERE match_id = p_match_id
        AND status IN ('open', 'locked', 'live', 'settling')
      ORDER BY created_at, id
    LOOP
      PERFORM public.reverse_or_refund_pool_if_match_cancelled(v_pool_id);
      v_refunded := v_refunded + 1;
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'status', 'updated',
    'match', v_after,
    'settled_pools', v_settled,
    'refunded_pools', v_refunded
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_update_match_result(
  p_match_id text,
  p_home_goals integer,
  p_away_goals integer
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF NOT public.current_user_has_admin_role(ARRAY['moderator', 'admin', 'super_admin']) THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  RETURN public.update_match_live_score(
    p_match_id,
    p_home_goals,
    p_away_goals,
    'final',
    'admin_result'
  );
END;
$$;

GRANT SELECT ON TABLE public.curated_active_matches TO anon, authenticated, service_role;
GRANT SELECT ON TABLE public.fixture_sources TO authenticated, service_role;
GRANT INSERT, UPDATE, DELETE ON TABLE public.fixture_sources TO service_role;

REVOKE ALL ON FUNCTION public.get_curated_matches(text, uuid, timestamp with time zone, timestamp with time zone, text, text, text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_curated_matches(text, uuid, timestamp with time zone, timestamp with time zone, text, text, text, integer) TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_curate_match_control(text, text, uuid, integer, text, jsonb, timestamp with time zone, timestamp with time zone, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_curate_match_control(text, text, uuid, integer, text, jsonb, timestamp with time zone, timestamp with time zone, boolean) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_set_curated_match_active(uuid, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_set_curated_match_active(uuid, boolean) TO authenticated, service_role;
