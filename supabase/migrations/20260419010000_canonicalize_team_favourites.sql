-- Canonicalize app-owned team favourites onto user_favorite_teams.
--
-- The Flutter app now reads and writes team preferences through
-- public.user_favorite_teams. We keep public.user_followed_teams for
-- backward compatibility, but existing rows need to be backfilled into the
-- richer canonical table so user state stays consistent after the app refactor.

WITH existing_counts AS (
  SELECT user_id, COUNT(*)::integer AS existing_count
  FROM public.user_favorite_teams
  GROUP BY user_id
),
legacy_rows AS (
  SELECT
    legacy.user_id,
    legacy.team_id,
    COALESCE(
      teams.name,
      INITCAP(REPLACE(legacy.team_id, '-', ' ')),
      legacy.team_id
    ) AS team_name,
    teams.short_name AS team_short_name,
    teams.country AS team_country,
    NULLIF(UPPER(COALESCE(teams.country, '')), '') AS team_country_code,
    teams.league_name AS team_league,
    COALESCE(teams.crest_url, teams.logo_url) AS team_crest_url,
    ROW_NUMBER() OVER (
      PARTITION BY legacy.user_id
      ORDER BY legacy.created_at, legacy.team_id
    ) - 1 AS row_index
  FROM public.user_followed_teams AS legacy
  LEFT JOIN public.teams
    ON teams.id = legacy.team_id
  LEFT JOIN public.user_favorite_teams AS existing
    ON existing.user_id = legacy.user_id
   AND existing.team_id = legacy.team_id
  WHERE existing.user_id IS NULL
)
INSERT INTO public.user_favorite_teams (
  user_id,
  team_id,
  team_name,
  team_short_name,
  team_country,
  team_country_code,
  team_league,
  team_crest_url,
  source,
  sort_order
)
SELECT
  legacy_rows.user_id,
  legacy_rows.team_id,
  legacy_rows.team_name,
  legacy_rows.team_short_name,
  legacy_rows.team_country,
  CASE
    WHEN legacy_rows.team_country_code ~ '^[A-Z]{2}$'
      THEN legacy_rows.team_country_code
    ELSE NULL
  END AS team_country_code,
  legacy_rows.team_league,
  legacy_rows.team_crest_url,
  'synced' AS source,
  COALESCE(existing_counts.existing_count, 0) + legacy_rows.row_index AS sort_order
FROM legacy_rows
LEFT JOIN existing_counts
  ON existing_counts.user_id = legacy_rows.user_id;

COMMENT ON TABLE public.user_followed_teams IS
  'Legacy team-follow storage retained for backward compatibility. FANZONE app canonical team preferences live in public.user_favorite_teams.';
