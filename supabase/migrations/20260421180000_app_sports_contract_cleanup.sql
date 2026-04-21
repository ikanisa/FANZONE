BEGIN;

-- =====================================================================
-- FANZONE app-facing sports contract
--
-- Goal:
--   1. Keep base tables canonical (`matches`, `competitions`, `teams`)
--   2. Expose season-aware app projections/RPCs
--   3. Hide competitions with no usable app data
--   4. Stop relying on incomplete historical client-side filtering
-- =====================================================================

CREATE INDEX IF NOT EXISTS idx_matches_competition_season_date_desc
  ON public.matches (competition_id, season, date DESC);

CREATE INDEX IF NOT EXISTS idx_matches_home_team_date_desc
  ON public.matches (home_team_id, date DESC);

CREATE INDEX IF NOT EXISTS idx_matches_away_team_date_desc
  ON public.matches (away_team_id, date DESC);

CREATE OR REPLACE FUNCTION public.season_sort_key(p_season text)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT coalesce(
    substring(coalesce(p_season, '') FROM '([0-9]{4})')::integer,
    0
  );
$$;

CREATE OR REPLACE FUNCTION public.get_competition_current_season(
  p_competition_id text
)
RETURNS text
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v_season text;
BEGIN
  IF p_competition_id IS NULL OR btrim(p_competition_id) = '' THEN
    RETURN NULL;
  END IF;

  SELECT m.season
  INTO v_season
  FROM public.matches AS m
  WHERE m.competition_id = p_competition_id
    AND m.season IS NOT NULL
    AND public.normalize_match_status_value(m.status) IN ('live', 'upcoming')
  ORDER BY
    CASE
      WHEN public.normalize_match_status_value(m.status) = 'live' THEN 0
      ELSE 1
    END,
    m.date ASC NULLS LAST
  LIMIT 1;

  IF v_season IS NOT NULL THEN
    RETURN v_season;
  END IF;

  SELECT m.season
  INTO v_season
  FROM public.matches AS m
  WHERE m.competition_id = p_competition_id
    AND m.season IS NOT NULL
  ORDER BY
    m.date DESC NULLS LAST,
    public.season_sort_key(m.season) DESC,
    m.season DESC
  LIMIT 1;

  IF v_season IS NOT NULL THEN
    RETURN v_season;
  END IF;

  SELECT s.season
  INTO v_season
  FROM public.competition_standings AS s
  WHERE s.competition_id = p_competition_id
    AND nullif(btrim(s.season), '') IS NOT NULL
  ORDER BY
    public.season_sort_key(s.season) DESC,
    s.season DESC
  LIMIT 1;

  RETURN v_season;
END;
$$;

GRANT EXECUTE ON FUNCTION public.season_sort_key(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_competition_current_season(text) TO anon, authenticated;

-- Backfill competition seasons from authoritative match/standings data.
WITH derived_seasons AS (
  SELECT
    src.competition_id,
    array_agg(src.season ORDER BY public.season_sort_key(src.season), src.season) AS seasons
  FROM (
    SELECT DISTINCT competition_id, season
    FROM public.matches
    WHERE nullif(btrim(season), '') IS NOT NULL

    UNION

    SELECT DISTINCT competition_id, season
    FROM public.competition_standings
    WHERE nullif(btrim(season), '') IS NOT NULL
  ) AS src
  GROUP BY src.competition_id
)
UPDATE public.competitions AS c
SET seasons = ds.seasons
FROM derived_seasons AS ds
WHERE c.id = ds.competition_id
  AND c.seasons IS DISTINCT FROM ds.seasons;

-- Backfill incomplete team/competition links from matches + standings.
INSERT INTO public.team_competitions (team_id, competition_id, is_primary)
SELECT DISTINCT
  public.resolve_team_id(src.team_id) AS team_id,
  src.competition_id,
  coalesce(t.competition_ids[1] = src.competition_id, false) AS is_primary
FROM (
  SELECT competition_id, home_team_id AS team_id
  FROM public.matches
  WHERE competition_id IS NOT NULL
    AND home_team_id IS NOT NULL

  UNION

  SELECT competition_id, away_team_id AS team_id
  FROM public.matches
  WHERE competition_id IS NOT NULL
    AND away_team_id IS NOT NULL

  UNION

  SELECT competition_id, team_id
  FROM public.competition_standings
  WHERE competition_id IS NOT NULL
    AND team_id IS NOT NULL
) AS src
JOIN public.teams AS t
  ON t.id = public.resolve_team_id(src.team_id)
JOIN public.competitions AS c
  ON c.id = src.competition_id
ON CONFLICT (team_id, competition_id) DO NOTHING;

DROP VIEW IF EXISTS public.app_competitions;

CREATE VIEW public.app_competitions AS
WITH current_seasons AS (
  SELECT
    c.id AS competition_id,
    public.get_competition_current_season(c.id) AS current_season
  FROM public.competitions AS c
),
current_match_counts AS (
  SELECT
    cs.competition_id,
    count(m.id) AS match_count,
    count(m.id) FILTER (
      WHERE public.normalize_match_status_value(m.status) IN ('live', 'upcoming')
        AND m.date >= timezone('utc', now()) - interval '6 hours'
    ) AS future_match_count,
    count(m.id) FILTER (
      WHERE public.normalize_match_status_value(m.status) = 'finished'
    ) AS finished_match_count
  FROM current_seasons AS cs
  LEFT JOIN public.matches AS m
    ON m.competition_id = cs.competition_id
   AND (cs.current_season IS NULL OR m.season = cs.current_season)
  GROUP BY cs.competition_id
),
current_standing_counts AS (
  SELECT
    cs.competition_id,
    count(s.competition_id) AS standing_count
  FROM current_seasons AS cs
  LEFT JOIN public.competition_standings AS s
    ON s.competition_id = cs.competition_id
   AND cs.current_season IS NOT NULL
   AND s.season = cs.current_season
  GROUP BY cs.competition_id
),
current_team_counts AS (
  SELECT
    src.competition_id,
    count(DISTINCT src.team_id) AS team_count
  FROM (
    SELECT
      cs.competition_id,
      public.resolve_team_id(s.team_id) AS team_id
    FROM current_seasons AS cs
    JOIN public.competition_standings AS s
      ON s.competition_id = cs.competition_id
     AND cs.current_season IS NOT NULL
     AND s.season = cs.current_season
    WHERE nullif(btrim(s.team_id), '') IS NOT NULL

    UNION

    SELECT
      cs.competition_id,
      public.resolve_team_id(m.home_team_id) AS team_id
    FROM current_seasons AS cs
    JOIN public.matches AS m
      ON m.competition_id = cs.competition_id
     AND (cs.current_season IS NULL OR m.season = cs.current_season)
    WHERE nullif(btrim(m.home_team_id), '') IS NOT NULL

    UNION

    SELECT
      cs.competition_id,
      public.resolve_team_id(m.away_team_id) AS team_id
    FROM current_seasons AS cs
    JOIN public.matches AS m
      ON m.competition_id = cs.competition_id
     AND (cs.current_season IS NULL OR m.season = cs.current_season)
    WHERE nullif(btrim(m.away_team_id), '') IS NOT NULL
  ) AS src
  GROUP BY src.competition_id
)
SELECT
  c.id,
  c.name,
  c.short_name,
  c.country,
  c.tier,
  c.data_source,
  c.source_file,
  CASE
    WHEN coalesce(array_length(c.seasons, 1), 0) = 0 AND cs.current_season IS NOT NULL
      THEN ARRAY[cs.current_season]
    ELSE coalesce(c.seasons, '{}'::text[])
  END AS seasons,
  coalesce(tc.team_count, c.team_count) AS team_count,
  NULL::text AS logo_url,
  c.region,
  c.competition_type,
  c.is_featured,
  c.event_tag,
  c.start_date,
  c.end_date,
  c.status,
  cs.current_season,
  coalesce(mc.match_count, 0) AS match_count,
  coalesce(mc.future_match_count, 0) AS future_match_count,
  coalesce(sc.standing_count, 0) AS standing_count
FROM public.competitions AS c
JOIN current_seasons AS cs
  ON cs.competition_id = c.id
LEFT JOIN current_match_counts AS mc
  ON mc.competition_id = c.id
LEFT JOIN current_standing_counts AS sc
  ON sc.competition_id = c.id
LEFT JOIN current_team_counts AS tc
  ON tc.competition_id = c.id
WHERE (
    coalesce(mc.match_count, 0) > 0
    OR coalesce(tc.team_count, 0) > 0
    OR coalesce(sc.standing_count, 0) > 0
  )
  AND (
    coalesce(mc.future_match_count, 0) > 0
    OR public.season_sort_key(cs.current_season) >= extract(year FROM timezone('utc', now()))::integer - 1
    OR c.is_featured = true
  );

GRANT SELECT ON public.app_competitions TO anon, authenticated;

DROP FUNCTION IF EXISTS public.app_matches_by_date(date, text);
CREATE OR REPLACE FUNCTION public.app_matches_by_date(
  p_date date,
  p_competition_id text DEFAULT NULL
)
RETURNS SETOF public.matches_live_view
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT mv.*
  FROM public.matches_live_view AS mv
  WHERE p_date IS NOT NULL
    AND mv.date::date = p_date
    AND (p_competition_id IS NULL OR mv.competition_id = p_competition_id)
  ORDER BY mv.date ASC, mv.kickoff_time ASC NULLS LAST, mv.id ASC;
$$;

DROP FUNCTION IF EXISTS public.app_competition_matches(text, integer);
CREATE OR REPLACE FUNCTION public.app_competition_matches(
  p_competition_id text,
  p_limit integer DEFAULT 500
)
RETURNS SETOF public.matches_live_view
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  WITH chosen_season AS (
    SELECT public.get_competition_current_season(p_competition_id) AS season
  )
  SELECT mv.*
  FROM public.matches_live_view AS mv
  CROSS JOIN chosen_season AS cs
  WHERE mv.competition_id = p_competition_id
    AND (cs.season IS NULL OR mv.season = cs.season)
  ORDER BY mv.date ASC, mv.kickoff_time ASC NULLS LAST, mv.id ASC
  LIMIT greatest(coalesce(p_limit, 500), 1);
$$;

DROP FUNCTION IF EXISTS public.app_team_matches(text, integer);
CREATE OR REPLACE FUNCTION public.app_team_matches(
  p_team_id text,
  p_limit integer DEFAULT 120
)
RETURNS SETOF public.matches_live_view
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  WITH resolved_team AS (
    SELECT public.resolve_team_id(p_team_id) AS team_id
  ),
  current_competitions AS (
    SELECT DISTINCT
      m.competition_id,
      public.get_competition_current_season(m.competition_id) AS current_season
    FROM public.matches AS m
    JOIN resolved_team AS rt
      ON rt.team_id IS NOT NULL
    WHERE m.home_team_id = rt.team_id
       OR m.away_team_id = rt.team_id
  ),
  candidate_matches AS (
    SELECT
      mv.*,
      public.normalize_match_status_value(mv.status) AS normalized_status
    FROM public.matches_live_view AS mv
    JOIN resolved_team AS rt
      ON mv.home_team_id = rt.team_id
      OR mv.away_team_id = rt.team_id
    LEFT JOIN current_competitions AS cc
      ON cc.competition_id = mv.competition_id
    WHERE cc.competition_id IS NULL
       OR cc.current_season IS NULL
       OR mv.season = cc.current_season
  )
  SELECT
    cm.id,
    cm.competition_id,
    cm.season,
    cm.round,
    cm.match_group,
    cm.date,
    cm.kickoff_time,
    cm.home_team_id,
    cm.away_team_id,
    cm.home_team,
    cm.away_team,
    cm.ft_home,
    cm.ft_away,
    cm.ht_home,
    cm.ht_away,
    cm.et_home,
    cm.et_away,
    cm.live_minute,
    cm.status,
    cm.venue,
    cm.data_source,
    cm.source_url,
    cm.home_logo_url,
    cm.away_logo_url
  FROM candidate_matches AS cm
  ORDER BY
    CASE cm.normalized_status
      WHEN 'live' THEN 0
      WHEN 'upcoming' THEN 1
      ELSE 2
    END,
    CASE
      WHEN cm.normalized_status = 'finished' THEN cm.date
      ELSE NULL
    END DESC NULLS LAST,
    CASE
      WHEN cm.normalized_status <> 'finished' THEN cm.date
      ELSE NULL
    END ASC NULLS LAST,
    cm.kickoff_time ASC NULLS LAST,
    cm.id ASC
  LIMIT greatest(coalesce(p_limit, 120), 1);
$$;

DROP FUNCTION IF EXISTS public.app_competition_teams(text);
CREATE OR REPLACE FUNCTION public.app_competition_teams(
  p_competition_id text
)
RETURNS SETOF public.team_catalog_entries
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  WITH chosen_season AS (
    SELECT public.get_competition_current_season(p_competition_id) AS season
  ),
  season_team_ids AS (
    SELECT DISTINCT public.resolve_team_id(s.team_id) AS team_id
    FROM public.competition_standings AS s
    CROSS JOIN chosen_season AS cs
    WHERE s.competition_id = p_competition_id
      AND cs.season IS NOT NULL
      AND s.season = cs.season
      AND nullif(btrim(s.team_id), '') IS NOT NULL

    UNION

    SELECT DISTINCT public.resolve_team_id(m.home_team_id) AS team_id
    FROM public.matches AS m
    CROSS JOIN chosen_season AS cs
    WHERE m.competition_id = p_competition_id
      AND (cs.season IS NULL OR m.season = cs.season)
      AND nullif(btrim(m.home_team_id), '') IS NOT NULL

    UNION

    SELECT DISTINCT public.resolve_team_id(m.away_team_id) AS team_id
    FROM public.matches AS m
    CROSS JOIN chosen_season AS cs
    WHERE m.competition_id = p_competition_id
      AND (cs.season IS NULL OR m.season = cs.season)
      AND nullif(btrim(m.away_team_id), '') IS NOT NULL
  ),
  fallback_team_ids AS (
    SELECT DISTINCT tc.team_id
    FROM public.team_competitions AS tc
    WHERE tc.competition_id = p_competition_id

    UNION

    SELECT DISTINCT t.id AS team_id
    FROM public.teams AS t
    WHERE p_competition_id = ANY(coalesce(t.competition_ids, '{}'::text[]))
  ),
  effective_team_ids AS (
    SELECT team_id
    FROM season_team_ids
    WHERE nullif(btrim(team_id), '') IS NOT NULL

    UNION

    SELECT team_id
    FROM fallback_team_ids
    WHERE NOT EXISTS (SELECT 1 FROM season_team_ids)
      AND nullif(btrim(team_id), '') IS NOT NULL
  )
  SELECT tce.*
  FROM public.team_catalog_entries AS tce
  JOIN effective_team_ids AS ids
    ON ids.team_id = tce.id
  WHERE tce.is_active = true
  ORDER BY tce.name ASC;
$$;

DROP FUNCTION IF EXISTS public.app_competition_standings(text, text);
CREATE OR REPLACE FUNCTION public.app_competition_standings(
  p_competition_id text,
  p_season text DEFAULT NULL
)
RETURNS SETOF public.competition_standings
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  WITH preferred_season AS (
    SELECT coalesce(
      nullif(btrim(p_season), ''),
      public.get_competition_current_season(p_competition_id),
      (
        SELECT s2.season
        FROM public.competition_standings AS s2
        WHERE s2.competition_id = p_competition_id
          AND nullif(btrim(s2.season), '') IS NOT NULL
        ORDER BY public.season_sort_key(s2.season) DESC, s2.season DESC
        LIMIT 1
      )
    ) AS season
  )
  SELECT s.*
  FROM public.competition_standings AS s
  CROSS JOIN preferred_season AS ps
  WHERE ps.season IS NOT NULL
    AND s.competition_id = p_competition_id
    AND s.season = ps.season
  ORDER BY s.position ASC, s.team_name ASC;
$$;

GRANT EXECUTE ON FUNCTION public.app_matches_by_date(date, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_competition_matches(text, integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_team_matches(text, integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_competition_teams(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_competition_standings(text, text) TO anon, authenticated;

COMMIT;
