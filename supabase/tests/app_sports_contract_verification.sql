\pset tuples_only on
\pset pager off

\echo 'Verifying lean app-facing sports contract...'

DO $$
BEGIN
  IF to_regclass('public.app_competitions') IS NULL THEN
    RAISE EXCEPTION 'Missing required view: public.app_competitions';
  END IF;

  IF to_regclass('public.app_matches') IS NULL THEN
    RAISE EXCEPTION 'Missing required view: public.app_matches';
  END IF;

  IF to_regclass('public.competition_standings') IS NULL THEN
    RAISE EXCEPTION 'Missing required view: public.competition_standings';
  END IF;

  IF to_regclass('public.teams') IS NULL THEN
    RAISE EXCEPTION 'Missing required table: public.teams';
  END IF;

  INSERT INTO public.competitions (
    id,
    name,
    short_name,
    country,
    data_source,
    country_or_region,
    competition_type,
    is_active
  )
  VALUES (
    'contract_test_comp',
    'Contract Test League',
    'CTL',
    'Malta',
    'test',
    'MT',
    'league',
    true
  )
  ON CONFLICT (id) DO UPDATE
  SET is_active = true;

  INSERT INTO public.teams (
    id,
    name,
    short_name,
    country,
    country_code,
    competition_ids,
    is_active
  )
  VALUES
    ('contract_test_home', 'Contract Test Home', 'CTH', 'Malta', 'MT', ARRAY['contract_test_comp'], true),
    ('contract_test_away', 'Contract Test Away', 'CTA', 'Malta', 'MT', ARRAY['contract_test_comp'], true)
  ON CONFLICT (id) DO UPDATE
  SET is_active = true,
      competition_ids = EXCLUDED.competition_ids;
END;
$$;

DO $$
DECLARE
  visible_competitions integer;
  active_team_count integer;
  placeholder_team_count integer;
  future_raw_slot_name_count integer;
  representative_competition text;
  representative_team_count integer;
  representative_standings_count integer;
BEGIN
  SELECT count(*)
  INTO visible_competitions
  FROM public.app_competitions;

  IF visible_competitions = 0 THEN
    RAISE EXCEPTION 'app_competitions returned no visible competitions';
  END IF;

  SELECT count(*)
  INTO active_team_count
  FROM public.teams
  WHERE is_active = true;

  IF active_team_count = 0 THEN
    RAISE EXCEPTION 'teams returned no active teams';
  END IF;

  SELECT count(*)
  INTO placeholder_team_count
  FROM public.teams
  WHERE is_active = true
    AND (
      name ~ '^[12][A-L]$'
      OR name ~ '^3[A-L](/[A-L])+$'
      OR name ~ '^[WL][0-9]+$'
    );

  IF placeholder_team_count > 0 THEN
    RAISE EXCEPTION 'Active team catalog still contains % placeholder teams', placeholder_team_count;
  END IF;

  SELECT count(*)
  INTO future_raw_slot_name_count
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

  IF future_raw_slot_name_count > 0 THEN
    RAISE EXCEPTION 'Future app_matches rows still expose % raw slot-name teams', future_raw_slot_name_count;
  END IF;

  SELECT
    candidate.competition_id,
    candidate.team_count,
    candidate.standings_count
  INTO
    representative_competition,
    representative_team_count,
    representative_standings_count
  FROM (
    SELECT
      c.id AS competition_id,
      c.is_active,
      count(DISTINCT t.id) FILTER (WHERE t.is_active = true) AS team_count,
      count(DISTINCT cs.id) AS standings_count
    FROM public.competitions c
    LEFT JOIN public.teams t
      ON c.id = ANY(t.competition_ids)
    LEFT JOIN public.competition_standings cs
      ON cs.competition_id = c.id
    GROUP BY c.id, c.is_active
  ) AS candidate
  WHERE candidate.team_count > 0
     OR candidate.standings_count > 0
  ORDER BY
    candidate.is_active DESC,
    candidate.team_count DESC,
    candidate.standings_count DESC,
    candidate.competition_id
  LIMIT 1;

  IF representative_competition IS NULL THEN
    RAISE EXCEPTION 'Could not find a populated representative competition for contract validation';
  END IF;
END;
$$;

SELECT count(*) AS visible_competitions
FROM public.app_competitions;

SELECT count(*) AS fixtures_today
FROM public.app_matches
WHERE date = current_date;

WITH representative_competition AS (
  SELECT candidate.competition_id
  FROM (
    SELECT
      c.id AS competition_id,
      c.is_active,
      count(DISTINCT t.id) FILTER (WHERE t.is_active = true) AS team_count,
      count(DISTINCT cs.id) AS standings_count
    FROM public.competitions c
    LEFT JOIN public.teams t
      ON c.id = ANY(t.competition_ids)
    LEFT JOIN public.competition_standings cs
      ON cs.competition_id = c.id
    GROUP BY c.id, c.is_active
  ) AS candidate
  WHERE candidate.team_count > 0
     OR candidate.standings_count > 0
  ORDER BY
    candidate.is_active DESC,
    candidate.team_count DESC,
    candidate.standings_count DESC,
    candidate.competition_id
  LIMIT 1
)
SELECT
  (SELECT competition_id FROM representative_competition)
    AS representative_competition_id,
  (
    SELECT count(*)
    FROM public.teams
    WHERE is_active = true
      AND (SELECT competition_id FROM representative_competition) = ANY (competition_ids)
  ) AS teams_for_representative_competition,
  (
    SELECT count(*)
    FROM public.competition_standings
    WHERE competition_id = (SELECT competition_id FROM representative_competition)
  ) AS standings_rows_for_representative_competition;

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
