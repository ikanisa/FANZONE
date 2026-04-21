BEGIN;

CREATE OR REPLACE VIEW public.team_catalog_entries AS
WITH team_competition_rollup AS (
  SELECT
    team_id,
    array_agg(competition_id ORDER BY is_primary DESC, competition_id) AS competition_ids
  FROM public.team_competitions
  GROUP BY team_id
),
team_competition_candidates AS (
  SELECT
    tc.team_id,
    tc.competition_id,
    tc.is_primary,
    0 AS source_rank
  FROM public.team_competitions AS tc

  UNION ALL

  SELECT
    t.id AS team_id,
    competition_id,
    false AS is_primary,
    1 AS source_rank
  FROM public.teams AS t
  CROSS JOIN LATERAL unnest(coalesce(t.competition_ids, '{}'::text[])) AS competition_id
),
team_primary_competition AS (
  SELECT DISTINCT ON (candidate.team_id)
    candidate.team_id,
    c.name AS competition_name,
    c.country AS competition_country
  FROM team_competition_candidates AS candidate
  JOIN public.competitions AS c
    ON c.id = candidate.competition_id
  ORDER BY
    candidate.team_id,
    candidate.is_primary DESC,
    candidate.source_rank ASC,
    CASE
      WHEN lower(coalesce(c.country, '')) = 'international' THEN 1
      ELSE 0
    END,
    c.tier ASC,
    public.competition_catalog_rank(c.id, c.name) ASC,
    c.name ASC
),
team_catalog_base AS (
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
    AND NOT public.is_team_slot_placeholder(t.name)
)
SELECT *
FROM team_catalog_base
WHERE country IS NOT NULL
   OR league_name IS NOT NULL
   OR is_featured = true
   OR is_popular_pick = true;

GRANT SELECT ON public.team_catalog_entries TO anon, authenticated;

COMMIT;
