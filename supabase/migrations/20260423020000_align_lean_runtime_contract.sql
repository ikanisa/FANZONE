BEGIN;

CREATE OR REPLACE VIEW public.app_matches AS
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
  to_char((m.match_date AT TIME ZONE 'UTC'::text), 'HH24:MI'::text) AS kickoff_time,
  m.home_team_id,
  ht.name AS home_team,
  COALESCE(ht.crest_url, ht.logo_url) AS home_logo_url,
  m.away_team_id,
  at.name AS away_team,
  COALESCE(at.crest_url, at.logo_url) AS away_logo_url,
  m.home_goals AS ft_home,
  m.away_goals AS ft_away,
  m.home_goals,
  m.away_goals,
  m.result_code,
  CASE
    WHEN m.match_status = ANY (ARRAY['scheduled'::text, 'not_started'::text, 'pending'::text]) THEN 'upcoming'::text
    WHEN m.match_status = ANY (ARRAY['live'::text, 'in_play'::text, 'in_progress'::text, 'playing'::text]) THEN 'live'::text
    WHEN m.match_status = ANY (ARRAY['finished'::text, 'complete'::text, 'completed'::text, 'full_time'::text, 'ft'::text]) THEN 'finished'::text
    ELSE COALESCE(NULLIF(lower(m.match_status), ''), 'upcoming'::text)
  END AS status,
  m.match_status,
  m.is_neutral,
  m.source_name AS data_source,
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
  m.last_live_review_required
FROM public.matches m
LEFT JOIN public.competitions c ON c.id = m.competition_id
LEFT JOIN public.seasons s ON s.id = m.season_id
LEFT JOIN public.teams ht ON ht.id = m.home_team_id
LEFT JOIN public.teams at ON at.id = m.away_team_id;

DROP FUNCTION IF EXISTS public.app_competition_teams(text);
DROP VIEW IF EXISTS public.team_catalog_entries;
DROP FUNCTION IF EXISTS public.get_live_matches();
DROP VIEW IF EXISTS public.matches_live_view;

COMMIT;
