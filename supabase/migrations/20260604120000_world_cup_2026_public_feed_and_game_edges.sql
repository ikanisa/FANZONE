-- Promote LiveScore-sourced FIFA World Cup 2026 rows into the public curated
-- match feed used by the Flutter home and match-listing surfaces.
--
-- Raw imports remain in public.matches; public clients continue to read through
-- curated_active_matches/get_curated_matches. This migration does not make the
-- rows pool eligible.

UPDATE public.competitions
SET is_active = true,
    is_featured = true,
    status = 'active',
    updated_at = timezone('utc', now())
WHERE id = 'fifa_world_cup';

WITH ranked_world_cup AS (
  SELECT
    m.id,
    row_number() OVER (ORDER BY m.match_date ASC, m.id ASC)::integer AS display_rank
  FROM public.matches m
  WHERE m.competition_id = 'fifa_world_cup'
    AND m.season_id = 'fifa_world_cup_2026'
    AND (
      m.source = 'livescore'
      OR m.source_name = 'livescore_world_cup_2026'
      OR EXISTS (
        SELECT 1
        FROM public.football_official_fixture_staging fs
        WHERE fs.resource_id = 'livescore_world_cup_2026'
          AND fs.match_id = m.id
          AND fs.status = 'applied'
      )
    )
)
UPDATE public.matches m
SET hide_from_home = false,
    is_home_featured = true,
    home_feature_rank = 10000 - ranked_world_cup.display_rank,
    updated_at = timezone('utc', now())
FROM ranked_world_cup
WHERE m.id = ranked_world_cup.id;

WITH ranked_world_cup AS (
  SELECT
    m.id,
    m.match_date,
    row_number() OVER (ORDER BY m.match_date ASC, m.id ASC)::integer AS display_rank
  FROM public.matches m
  WHERE m.competition_id = 'fifa_world_cup'
    AND m.season_id = 'fifa_world_cup_2026'
    AND (
      m.source = 'livescore'
      OR m.source_name = 'livescore_world_cup_2026'
      OR EXISTS (
        SELECT 1
        FROM public.football_official_fixture_staging fs
        WHERE fs.resource_id = 'livescore_world_cup_2026'
          AND fs.match_id = m.id
          AND fs.status = 'applied'
      )
    )
)
UPDATE public.curated_matches cm
SET is_active = true,
    priority_score = greatest(cm.priority_score, 10000 - ranked_world_cup.display_rank),
    reason = CASE
      WHEN nullif(trim(cm.reason), '') IS NULL THEN 'fifa world cup 2026 public feed'
      ELSE cm.reason
    END,
    metadata = coalesce(cm.metadata, '{}'::jsonb)
      || jsonb_build_object(
        'source', 'world_cup_2026_public_feed',
        'pool_eligible', coalesce(cm.is_pool_eligible, false),
        'tags', (
          SELECT jsonb_agg(DISTINCT tag ORDER BY tag)
          FROM jsonb_array_elements_text(
            coalesce(cm.metadata -> 'tags', '[]'::jsonb)
            || '["global", "home", "fifa_world_cup", "world_cup_2026"]'::jsonb
          ) AS tags(tag)
        )
      ),
    expires_at = coalesce(cm.expires_at, ranked_world_cup.match_date + interval '48 hours'),
    updated_at = timezone('utc', now())
FROM ranked_world_cup
WHERE cm.match_id = ranked_world_cup.id
  AND cm.country_code IS NULL
  AND cm.venue_id IS NULL;

WITH ranked_world_cup AS (
  SELECT
    m.id,
    m.match_date,
    row_number() OVER (ORDER BY m.match_date ASC, m.id ASC)::integer AS display_rank
  FROM public.matches m
  WHERE m.competition_id = 'fifa_world_cup'
    AND m.season_id = 'fifa_world_cup_2026'
    AND (
      m.source = 'livescore'
      OR m.source_name = 'livescore_world_cup_2026'
      OR EXISTS (
        SELECT 1
        FROM public.football_official_fixture_staging fs
        WHERE fs.resource_id = 'livescore_world_cup_2026'
          AND fs.match_id = m.id
          AND fs.status = 'applied'
      )
    )
)
INSERT INTO public.curated_matches (
  match_id,
  country_code,
  venue_id,
  priority_score,
  is_active,
  reason,
  starts_at,
  expires_at,
  metadata,
  is_pool_eligible
)
SELECT
  ranked_world_cup.id,
  NULL,
  NULL,
  10000 - ranked_world_cup.display_rank,
  true,
  'fifa world cup 2026 public feed',
  NULL,
  ranked_world_cup.match_date + interval '48 hours',
  jsonb_build_object(
    'source', 'world_cup_2026_public_feed',
    'pool_eligible', false,
    'tags', jsonb_build_array('global', 'home', 'fifa_world_cup', 'world_cup_2026')
  ),
  false
FROM ranked_world_cup
WHERE NOT EXISTS (
  SELECT 1
  FROM public.curated_matches existing
  WHERE existing.match_id = ranked_world_cup.id
    AND existing.country_code IS NULL
    AND existing.venue_id IS NULL
);

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
IS 'Curated match feed ordered for the active venue/country, global featured matches, and FIFA World Cup 2026 relevance.';

REVOKE ALL ON FUNCTION public.get_curated_matches(text, uuid, timestamp with time zone, timestamp with time zone, text, text, text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_curated_matches(text, uuid, timestamp with time zone, timestamp with time zone, text, text, text, integer) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.football_catalog_json_int(
  p_payload jsonb,
  VARIADIC p_keys text[]
) RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO 'public', 'pg_catalog'
AS $$
DECLARE
  v_key text;
  v_value text;
BEGIN
  FOREACH v_key IN ARRAY p_keys LOOP
    v_value := nullif(trim(coalesce(p_payload #>> string_to_array(v_key, '.'), '')), '');
    IF v_value IS NOT NULL AND v_value ~ '^-?[0-9]+$' THEN
      RETURN v_value::integer;
    END IF;
  END LOOP;

  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_apply_official_fixture_live_state(
  p_resource_id text,
  p_limit integer DEFAULT 1000
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_catalog'
AS $$
DECLARE
  v_row record;
  v_home_score integer;
  v_away_score integer;
  v_live_minute integer;
  v_live_phase text;
  v_match_status text;
  v_result_code text;
  v_updated integer := 0;
BEGIN
  PERFORM public.football_catalog_require_admin();

  FOR v_row IN
    SELECT
      fs.id,
      fs.match_id,
      fs.match_status,
      fs.source_payload,
      r.provider,
      r.is_authoritative
    FROM public.football_official_fixture_staging fs
    JOIN public.football_official_resources r ON r.id = fs.resource_id
    WHERE fs.resource_id = p_resource_id
      AND fs.match_id IS NOT NULL
      AND fs.status = 'applied'
    ORDER BY fs.starts_at NULLS LAST, fs.source_match_id
    LIMIT greatest(1, least(coalesce(p_limit, 1000), 2000))
  LOOP
    v_home_score := public.football_catalog_json_int(
      v_row.source_payload,
      'home_score',
      'home_goals',
      'homeTeamScore',
      'source_payload.event.Tr1',
      'source_payload.event.Tr1OR',
      'source_payload.scoreboard.Tr1'
    );
    v_away_score := public.football_catalog_json_int(
      v_row.source_payload,
      'away_score',
      'away_goals',
      'awayTeamScore',
      'source_payload.event.Tr2',
      'source_payload.event.Tr2OR',
      'source_payload.scoreboard.Tr2'
    );
    v_live_minute := public.football_catalog_json_int(
      v_row.source_payload,
      'live_minute',
      'minute',
      'source_payload.event.Emin',
      'source_payload.event.Epr'
    );
    v_live_phase := coalesce(
      nullif(trim(v_row.source_payload ->> 'live_phase'), ''),
      nullif(trim(v_row.source_payload ->> 'event_status'), ''),
      nullif(trim(v_row.source_payload #>> '{source_payload,event,Eps}'), ''),
      v_row.match_status
    );
    v_match_status := public.football_catalog_normalize_match_status(
      coalesce(
        nullif(trim(v_row.source_payload ->> 'match_status'), ''),
        nullif(trim(v_row.source_payload ->> 'status'), ''),
        nullif(trim(v_row.source_payload ->> 'event_status'), ''),
        v_row.match_status
      )
    );
    v_result_code := CASE
      WHEN v_match_status = 'finished' AND v_home_score IS NOT NULL AND v_away_score IS NOT NULL
        THEN public.sports_bar_result_code(v_home_score, v_away_score)
      ELSE NULL
    END;

    UPDATE public.matches
    SET match_status = v_match_status,
        status = v_match_status,
        live_home_score = coalesce(v_home_score, live_home_score),
        live_away_score = coalesce(v_away_score, live_away_score),
        live_minute = CASE WHEN v_match_status = 'live' THEN coalesce(v_live_minute, live_minute) ELSE NULL END,
        live_phase = v_live_phase,
        last_live_checked_at = timezone('utc', now()),
        last_live_sync_confidence = CASE WHEN v_row.is_authoritative THEN 1.0 ELSE 0.8 END,
        last_live_review_required = false,
        home_goals = CASE WHEN v_match_status = 'finished' THEN coalesce(v_home_score, home_goals) ELSE home_goals END,
        away_goals = CASE WHEN v_match_status = 'finished' THEN coalesce(v_away_score, away_goals) ELSE away_goals END,
        home_score = CASE WHEN v_match_status = 'finished' THEN coalesce(v_home_score, home_score) ELSE home_score END,
        away_score = CASE WHEN v_match_status = 'finished' THEN coalesce(v_away_score, away_score) ELSE away_score END,
        result_code = coalesce(v_result_code, result_code),
        winner_camp = CASE
          WHEN v_result_code IS NOT NULL THEN public.sports_bar_winner_camp(v_result_code)
          WHEN v_match_status IN ('cancelled', 'postponed') THEN NULL
          ELSE winner_camp
        END,
        source = v_row.provider,
        source_name = p_resource_id,
        updated_at = timezone('utc', now())
    WHERE id = v_row.match_id;

    IF FOUND THEN
      v_updated := v_updated + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'status', 'completed',
    'resource_id', p_resource_id,
    'updated_rows', v_updated
  );
END;
$$;

COMMENT ON FUNCTION public.admin_apply_official_fixture_live_state(text, integer)
IS 'Applies LiveScore/provider status, scores, and live phase from staging payloads into raw matches without curating or pool-enabling fixtures.';

REVOKE ALL ON FUNCTION public.football_catalog_json_int(jsonb, text[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.football_catalog_json_int(jsonb, text[]) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_apply_official_fixture_live_state(text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_apply_official_fixture_live_state(text, integer) TO authenticated, service_role;
