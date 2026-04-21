-- ============================================================================
-- FANZONE — App Sports Contract Verification
-- ============================================================================
-- Smoke checks for the app-facing sports views/RPCs introduced to keep
-- Flutter aligned with the canonical Supabase sports schema.
--
-- Run in Supabase SQL editor or psql against an environment with sports data.
-- ============================================================================

-- 1) Objects exist
SELECT to_regclass('public.app_competitions') AS app_competitions_view;
SELECT to_regclass('public.app_competitions_ranked') AS app_competitions_ranked_view;
SELECT to_regprocedure('public.app_matches_by_date(date,text)') AS app_matches_by_date_fn;
SELECT to_regprocedure('public.app_competition_matches(text,integer)') AS app_competition_matches_fn;
SELECT to_regprocedure('public.app_team_matches(text,integer)') AS app_team_matches_fn;
SELECT to_regprocedure('public.app_competition_teams(text)') AS app_competition_teams_fn;
SELECT to_regprocedure('public.app_competition_standings(text,text)') AS app_competition_standings_fn;
SELECT to_regprocedure('public.competition_catalog_rank(text,text)') AS competition_catalog_rank_fn;

-- 2) App competition catalog hides unusable competitions
SELECT count(*) AS visible_competitions
FROM public.app_competitions;

SELECT id, name, current_season, future_match_count, team_count, standing_count
FROM public.app_competitions
ORDER BY future_match_count DESC, name ASC
LIMIT 15;

SELECT id, name, catalog_rank
FROM public.app_competitions_ranked
ORDER BY catalog_rank ASC, future_match_count DESC, name ASC
LIMIT 15;

-- 3) Fixtures-by-date projection works
SELECT count(*) AS fixtures_today
FROM public.app_matches_by_date(current_date, NULL);

-- 4) Competition matches are season-scoped
SELECT count(*) AS epl_current_matches
FROM public.app_competition_matches('epl', 500);

SELECT min(season) AS min_season, max(season) AS max_season
FROM public.app_competition_matches('epl', 500);
-- Expected: min_season = max_season for a healthy season-scoped result.

-- 5) Competition teams are server-side filtered
SELECT count(*) AS epl_current_teams
FROM public.app_competition_teams('epl');

-- 6) Standings return exactly one season by default
SELECT count(*) AS epl_standings_rows
FROM public.app_competition_standings('epl', NULL);

SELECT array_agg(DISTINCT season ORDER BY season) AS epl_standings_seasons
FROM public.app_competition_standings('epl', NULL);
-- Expected: one season only.

-- 7) Team match lookup resolves canonical aliases
SELECT count(*) AS canonical_team_matches
FROM public.app_team_matches('fc-internazionale-milano', 120);

SELECT count(*) AS alias_team_matches
FROM public.app_team_matches('inter', 120);
-- Expected: alias_team_matches should equal canonical_team_matches when alias exists.

-- 8) Team catalog excludes placeholder slot rows
SELECT count(*) AS placeholder_teams_in_catalog
FROM public.team_catalog_entries
WHERE public.is_team_slot_placeholder(name);
-- Expected: 0

SELECT id, name, country, league_name
FROM public.team_catalog_entries
ORDER BY name ASC
LIMIT 20;

-- 9) Match projection exposes cleaned placeholders, not raw bracket codes
SELECT count(*) AS future_raw_slot_names
FROM public.matches_live_view
WHERE date >= current_date
  AND (
    home_team ~ '^[12][A-L]$'
    OR away_team ~ '^[12][A-L]$'
    OR home_team ~ '^3[A-L](/[A-L])+$'
    OR away_team ~ '^3[A-L](/[A-L])+$'
    OR home_team ~ '^[WL][0-9]+$'
    OR away_team ~ '^[WL][0-9]+$'
  );
-- Expected: 0

SELECT id, competition_id, date, home_team, away_team
FROM public.matches_live_view
WHERE competition_id = 'wc-2026'
  AND date BETWEEN DATE '2026-06-28' AND DATE '2026-07-06'
ORDER BY date ASC, id ASC
LIMIT 20;
