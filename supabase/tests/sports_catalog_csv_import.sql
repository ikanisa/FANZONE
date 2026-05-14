\pset tuples_only on
\pset pager off

\echo 'Verifying sports catalog CSV import...'

DO $$
DECLARE
  world_cup_match_count integer;
  world_cup_team_count integer;
  african_competition_count integer;
  african_club_count integer;
  matches_all_count integer;
  matches_all_world_cup_2026_count integer;
  superseded_curated_count integer;
BEGIN
  SELECT count(*)
  INTO world_cup_match_count
  FROM public.matches
  WHERE source_name = 'csv_world_cup_2026_schedule';

  IF world_cup_match_count <> 64 THEN
    RAISE EXCEPTION 'Expected 64 imported World Cup CSV fixtures, found %', world_cup_match_count;
  END IF;

  SELECT count(*)
  INTO world_cup_team_count
  FROM public.teams
  WHERE team_type = 'national'
    AND 'fifa_world_cup' = ANY(coalesce(competition_ids, ARRAY[]::text[]));

  IF world_cup_team_count < 48 THEN
    RAISE EXCEPTION 'Expected at least 48 World Cup national teams, found %', world_cup_team_count;
  END IF;

  SELECT count(*)
  INTO african_competition_count
  FROM public.competitions
  WHERE data_source = 'csv_african_premier_leagues'
    AND coalesce(type, competition_type) = 'local_curated';

  IF african_competition_count <> 27 THEN
    RAISE EXCEPTION 'Expected 27 African local competitions, found %', african_competition_count;
  END IF;

  SELECT count(*)
  INTO african_club_count
  FROM public.teams
  WHERE team_type = 'club'
    AND region = 'africa'
    AND id LIKE 'club_%';

  IF african_club_count < 445 THEN
    RAISE EXCEPTION 'Expected at least 445 African club teams, found %', african_club_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.seasons
    WHERE id = 'fifa_world_cup_2026'
      AND competition_id = 'fifa_world_cup'
      AND season_label = '2026'
  ) THEN
    RAISE EXCEPTION 'FIFA World Cup 2026 season import is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.teams
    WHERE id = 'club_rwanda_apr_fc'
      AND country = 'Rwanda'
      AND country_code = 'RW'
      AND 'local_rwanda_primus_national_league' = ANY(coalesce(competition_ids, ARRAY[]::text[]))
  ) THEN
    RAISE EXCEPTION 'Rwanda APR FC local club import is missing or not linked to Rwanda';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.matches
    WHERE id = 'wc2026-group-a-mexico-south-africa'
      AND source_name = 'csv_world_cup_2026_schedule'
      AND home_team_id = 'mexico'
      AND away_team_id = 'south_africa'
      AND season_id = 'fifa_world_cup_2026'
  ) THEN
    RAISE EXCEPTION 'Existing seeded Mexico v South Africa fixture was not updated through the CSV import';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.matches
    WHERE id = 'wc2026_group_a_mexico_south_africa'
  ) THEN
    RAISE EXCEPTION 'Underscore World Cup duplicate fixture ID exists; expected canonical hyphenated ID';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.fixture_sources
    WHERE id = 'csv_african_premier_leagues'
      AND config_json->>'imported_rows' = '445'
  ) THEN
    RAISE EXCEPTION 'African Premier Leagues fixture source metadata is missing';
  END IF;

  SELECT count(*)
  INTO matches_all_count
  FROM public.matches
  WHERE source_name = 'csv_matches_all';

  IF matches_all_count <> 12969 THEN
    RAISE EXCEPTION 'Expected 12969 imported Matches ALL catalog fixtures, found %', matches_all_count;
  END IF;

  SELECT count(*)
  INTO matches_all_world_cup_2026_count
  FROM public.matches
  WHERE source_name = 'csv_matches_all'
    AND competition_id = 'fifa_world_cup'
    AND season_id = 'fifa_world_cup_2026';

  IF matches_all_world_cup_2026_count <> 131 THEN
    RAISE EXCEPTION 'Expected 131 kept World Cup 2026 Matches ALL rows, found %', matches_all_world_cup_2026_count;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.matches
    WHERE source_name = 'csv_matches_all'
      AND (match_status NOT IN ('scheduled', 'live', 'finished', 'postponed', 'cancelled')
        OR status NOT IN ('scheduled', 'live', 'final', 'postponed', 'cancelled')
        OR hide_from_home IS DISTINCT FROM true
        OR is_curated IS DISTINCT FROM false)
  ) THEN
    RAISE EXCEPTION 'Matches ALL import must remain hidden raw catalog data with canonical statuses';
  END IF;

  IF (SELECT count(*) FROM public.competitions WHERE data_source = 'csv_matches_all') < 33 THEN
    RAISE EXCEPTION 'Matches ALL competition catalog import is incomplete';
  END IF;

  IF (SELECT count(*) FROM public.teams WHERE id LIKE 'clubfeed_%') < 291 THEN
    RAISE EXCEPTION 'Matches ALL club feed team import is incomplete';
  END IF;

  SELECT count(*)
  INTO superseded_curated_count
  FROM public.curated_matches cm
  JOIN public.matches m ON m.id = cm.match_id
  WHERE m.source_name = 'csv_world_cup_2026_schedule'
    AND (cm.is_active OR cm.is_pool_eligible);

  IF superseded_curated_count <> 0 THEN
    RAISE EXCEPTION 'Superseded 64-row World Cup CSV must not remain active or pool eligible';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.fixture_sources
    WHERE id = 'csv_matches_all'
      AND config_json->>'kept_match_rows' = '12969'
  ) THEN
    RAISE EXCEPTION 'Matches ALL fixture source metadata is missing';
  END IF;
END;
$$;

\echo 'Sports catalog CSV import verified'
