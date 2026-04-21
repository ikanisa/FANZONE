BEGIN;

CREATE OR REPLACE FUNCTION public.is_team_slot_placeholder(p_name text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  WITH normalized AS (
    SELECT upper(btrim(coalesce(p_name, ''))) AS name
  )
  SELECT
    name ~ '^[12][A-L]$'
    OR name ~ '^3[A-L](/[A-L])+$'
    OR name ~ '^[A-L][123]$'
    OR name ~ '^[WL][0-9]+$'
    OR name ~ '^(WINNER|RUNNER-UP|RUNNER UP|LOSER|TBD|TO BE DETERMINED)\b'
  FROM normalized;
$$;

CREATE OR REPLACE FUNCTION public.normalize_team_display_name(p_name text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  WITH normalized AS (
    SELECT
      btrim(coalesce(p_name, '')) AS original_name,
      upper(btrim(coalesce(p_name, ''))) AS upper_name
  )
  SELECT CASE
    WHEN upper_name ~ '^[12][A-L]$' THEN
      CASE substring(upper_name FROM 1 FOR 1)
        WHEN '1' THEN 'Winner Group ' || substring(upper_name FROM 2 FOR 1)
        ELSE 'Runner-up Group ' || substring(upper_name FROM 2 FOR 1)
      END
    WHEN upper_name ~ '^3[A-L](/[A-L])+$' THEN
      'Best 3rd Place Groups ' || substring(upper_name FROM 2)
    WHEN upper_name ~ '^[A-L][123]$' THEN
      CASE substring(upper_name FROM 2 FOR 1)
        WHEN '1' THEN 'Winner Group ' || substring(upper_name FROM 1 FOR 1)
        WHEN '2' THEN 'Runner-up Group ' || substring(upper_name FROM 1 FOR 1)
        ELSE '3rd Place Group ' || substring(upper_name FROM 1 FOR 1)
      END
    WHEN upper_name ~ '^W[0-9]+$' THEN
      'Winner Match ' || substring(upper_name FROM 2)
    WHEN upper_name ~ '^L[0-9]+$' THEN
      'Loser Match ' || substring(upper_name FROM 2)
    WHEN upper_name = 'TBD' OR upper_name = 'TO BE DETERMINED' THEN 'TBD'
    ELSE original_name
  END
  FROM normalized;
$$;

GRANT EXECUTE ON FUNCTION public.is_team_slot_placeholder(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.normalize_team_display_name(text) TO anon, authenticated;

WITH team_primary_competition AS (
  SELECT DISTINCT ON (tc.team_id)
    tc.team_id,
    c.name AS competition_name,
    c.country AS competition_country
  FROM public.team_competitions AS tc
  JOIN public.competitions AS c
    ON c.id = tc.competition_id
  ORDER BY
    tc.team_id,
    tc.is_primary DESC,
    CASE
      WHEN lower(coalesce(c.country, '')) = 'international' THEN 1
      ELSE 0
    END,
    c.tier ASC,
    public.competition_catalog_rank(c.id, c.name) ASC,
    c.name ASC
)
UPDATE public.teams AS t
SET
  country = CASE
    WHEN nullif(btrim(t.country), '') IS NOT NULL THEN t.country
    WHEN nullif(btrim(pc.competition_country), '') IS NOT NULL
      AND lower(pc.competition_country) <> 'international'
      THEN pc.competition_country
    ELSE t.country
  END,
  league_name = coalesce(
    nullif(btrim(t.league_name), ''),
    nullif(btrim(pc.competition_name), ''),
    t.league_name
  )
FROM team_primary_competition AS pc
WHERE t.id = pc.team_id
  AND NOT public.is_team_slot_placeholder(t.name)
  AND (
    (
      nullif(btrim(t.country), '') IS NULL
      AND nullif(btrim(pc.competition_country), '') IS NOT NULL
      AND lower(pc.competition_country) <> 'international'
    )
    OR (
      nullif(btrim(t.league_name), '') IS NULL
      AND nullif(btrim(pc.competition_name), '') IS NOT NULL
    )
  );

UPDATE public.teams
SET
  is_active = false,
  is_featured = false
WHERE is_active = true
  AND public.is_team_slot_placeholder(name);

CREATE OR REPLACE VIEW public.team_catalog_entries AS
WITH team_competition_rollup AS (
  SELECT
    team_id,
    array_agg(competition_id ORDER BY is_primary DESC, competition_id) AS competition_ids
  FROM public.team_competitions
  GROUP BY team_id
),
team_primary_competition AS (
  SELECT DISTINCT ON (tc.team_id)
    tc.team_id,
    c.name AS competition_name,
    c.country AS competition_country
  FROM public.team_competitions AS tc
  JOIN public.competitions AS c
    ON c.id = tc.competition_id
  ORDER BY
    tc.team_id,
    tc.is_primary DESC,
    CASE
      WHEN lower(coalesce(c.country, '')) = 'international' THEN 1
      ELSE 0
    END,
    c.tier ASC,
    public.competition_catalog_rank(c.id, c.name) ASC,
    c.name ASC
)
SELECT
  t.id,
  public.normalize_team_display_name(t.name) AS name,
  CASE
    WHEN nullif(btrim(t.short_name), '') IS NOT NULL
      THEN public.normalize_team_display_name(t.short_name)
    ELSE public.normalize_team_display_name(t.name)
  END AS short_name,
  null::text AS slug,
  coalesce(
    nullif(btrim(t.country), ''),
    CASE
      WHEN lower(coalesce(tpc.competition_country, '')) = 'international' THEN NULL
      ELSE nullif(btrim(tpc.competition_country), '')
    END
  ) AS country,
  null::text AS description,
  coalesce(
    nullif(btrim(t.league_name), ''),
    nullif(btrim(tpc.competition_name), '')
  ) AS league_name,
  coalesce(tc.competition_ids, coalesce(t.competition_ids, '{}'::text[])) AS competition_ids,
  coalesce(t.search_terms, '{}'::text[]) AS aliases,
  t.logo_url,
  t.crest_url,
  null::text AS cover_image_url,
  t.is_active,
  t.is_featured,
  false AS fet_contributions_enabled,
  false AS fiat_contributions_enabled,
  null::text AS fiat_contribution_mode,
  null::text AS fiat_contribution_link,
  0::integer AS fan_count,
  nullif(btrim(t.country_code), '') AS country_code,
  nullif(btrim(t.region), '') AS region,
  coalesce(t.search_terms, '{}'::text[]) AS search_terms,
  coalesce(t.is_popular_pick, false) AS is_popular_pick,
  t.popular_pick_rank
FROM public.teams AS t
LEFT JOIN team_competition_rollup AS tc
  ON tc.team_id = t.id
LEFT JOIN team_primary_competition AS tpc
  ON tpc.team_id = t.id
WHERE t.is_active = true
  AND NOT public.is_team_slot_placeholder(t.name);

GRANT SELECT ON public.team_catalog_entries TO anon, authenticated;

CREATE OR REPLACE VIEW public.matches_live_view AS
SELECT
  m.id,
  m.competition_id,
  m.season,
  m.round,
  m.match_group,
  m.date,
  m.kickoff_time,
  m.home_team_id,
  m.away_team_id,
  coalesce(
    public.normalize_team_display_name(ht.name),
    public.normalize_team_display_name(m.home_team)
  ) AS home_team,
  coalesce(
    public.normalize_team_display_name(at.name),
    public.normalize_team_display_name(m.away_team)
  ) AS away_team,
  CASE
    WHEN public.normalize_match_status_value(m.status) = 'live'
      THEN coalesce(m.live_home_score, m.ft_home)
    ELSE m.ft_home
  END AS ft_home,
  CASE
    WHEN public.normalize_match_status_value(m.status) = 'live'
      THEN coalesce(m.live_away_score, m.ft_away)
    ELSE m.ft_away
  END AS ft_away,
  m.ht_home,
  m.ht_away,
  m.et_home,
  m.et_away,
  m.live_minute,
  m.status,
  m.venue,
  m.data_source,
  m.source_url,
  coalesce(m.home_logo_url, ht.crest_url, ht.logo_url) AS home_logo_url,
  coalesce(m.away_logo_url, at.crest_url, at.logo_url) AS away_logo_url
FROM public.matches AS m
LEFT JOIN public.teams AS ht
  ON ht.id = public.resolve_team_id(m.home_team_id)
LEFT JOIN public.teams AS at
  ON at.id = public.resolve_team_id(m.away_team_id);

GRANT SELECT ON public.matches_live_view TO anon, authenticated;

COMMIT;
