-- Lean app-facing sports contract verification

SELECT to_regclass('public.app_competitions') AS app_competitions_view;
SELECT to_regclass('public.app_matches') AS app_matches_view;
SELECT to_regclass('public.competition_standings') AS competition_standings_view;
SELECT to_regclass('public.teams') AS teams_table;

SELECT count(*) AS visible_competitions
FROM public.app_competitions;

SELECT count(*) AS fixtures_today
FROM public.app_matches
WHERE date = current_date;

WITH first_competition AS (
  SELECT id
  FROM public.competitions
  ORDER BY id
  LIMIT 1
)
SELECT count(*) AS teams_for_first_competition
FROM public.teams
WHERE is_active = true
  AND (SELECT id FROM first_competition) = ANY (competition_ids);

WITH first_competition AS (
  SELECT id
  FROM public.competitions
  ORDER BY id
  LIMIT 1
)
SELECT count(*) AS standings_rows_for_first_competition
FROM public.competition_standings
WHERE competition_id = (SELECT id FROM first_competition);

SELECT count(*) AS live_projection_rows
FROM public.app_matches
WHERE status = 'live';

SELECT count(*) AS placeholder_teams_in_catalog
FROM public.teams
WHERE is_active = true
  AND (
    name ~ '^[12][A-L]$'
    OR name ~ '^3[A-L](/[A-L])+$'
    OR name ~ '^[WL][0-9]+$'
  );

SELECT count(*) AS future_raw_slot_names
FROM public.app_matches
WHERE date >= current_date
  AND (
    home_team ~ '^[12][A-L]$'
    OR away_team ~ '^[12][A-L]$'
    OR home_team ~ '^3[A-L](/[A-L])+$'
    OR away_team ~ '^3[A-L](/[A-L])+$'
    OR home_team ~ '^[WL][0-9]+$'
    OR away_team ~ '^[WL][0-9]+$'
  );
