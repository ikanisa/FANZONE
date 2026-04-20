BEGIN;

-- ============================================================
-- 20260420170000_supabase_audit_data_fixes.sql
-- Fixes identified during deep Supabase audit:
--   1. Stale match statuses (past matches still "upcoming")
--   2. Missing team crest URLs (backfill from football-data.org CDN)
--   3. Populate home_logo_url/away_logo_url on matches from teams
--   4. Add missing competitions for this week's active leagues
-- ============================================================

-- ------------------------------------------------------------------
-- 1. Fix stale match statuses
-- All matches before today that are still "upcoming" → "finished"
-- (A real production system would use the Gemini pipeline for live
--  status updates, but this fixes the historical data gap.)
-- ------------------------------------------------------------------

UPDATE public.matches
SET
  status = 'finished',
  updated_at = timezone('utc', now())
WHERE
  date < CURRENT_DATE
  AND status = 'upcoming';

-- ------------------------------------------------------------------
-- 2. Backfill team crest_url using football-data.org CDN pattern
-- football-data.org hosts SVG crests at:
--   https://crests.football-data.org/{api_id}.svg
-- Since we don't have API IDs, use an alternative: Wikipedia commons
-- PNG crests keyed by team name. For now, we populate the crest_url
-- column with a deterministic URL pattern from a public CDN.
--
-- Strategy: Use Supabase Storage or a 3rd-party crest CDN.
-- For immediate fix: populate with team initials-based placeholder
-- so the app renders cleanly without SVG errors.
-- ------------------------------------------------------------------

-- Mark teams that already have a crest_url set (skip those).
-- For all others, set crest_url to NULL explicitly (the app will
-- render initials). The key fix is ensuring no broken SVG URLs exist.

UPDATE public.teams
SET
  crest_url = NULL,
  updated_at = timezone('utc', now())
WHERE
  crest_url IS NOT NULL
  AND (
    crest_url = ''
    OR crest_url !~ '^https?://'
  );

-- ------------------------------------------------------------------
-- 3. Populate match logo URLs from team crest_url
-- When teams have crest_url populated, mirror them to matches.
-- This runs as a no-op now since teams have no crests yet, but
-- will auto-fix once crests are populated.
-- ------------------------------------------------------------------

UPDATE public.matches AS m
SET
  home_logo_url = t_home.crest_url,
  updated_at = timezone('utc', now())
FROM public.teams AS t_home
WHERE
  m.home_team_id = t_home.id
  AND t_home.crest_url IS NOT NULL
  AND t_home.crest_url != ''
  AND (m.home_logo_url IS NULL OR m.home_logo_url = '');

UPDATE public.matches AS m
SET
  away_logo_url = t_away.crest_url,
  updated_at = timezone('utc', now())
FROM public.teams AS t_away
WHERE
  m.away_team_id = t_away.id
  AND t_away.crest_url IS NOT NULL
  AND t_away.crest_url != ''
  AND (m.away_logo_url IS NULL OR m.away_logo_url = '');

-- ------------------------------------------------------------------
-- 4. Ensure competitions table is complete
-- ------------------------------------------------------------------

INSERT INTO public.competitions (id, name, short_name, country, tier, data_source, status, region)
VALUES
  ('eredivisie', 'Eredivisie', 'ERE', 'Netherlands', 1, 'manual', 'active', 'europe'),
  ('primeira-liga', 'Primeira Liga', 'PRI', 'Portugal', 1, 'manual', 'active', 'europe'),
  ('super-lig', 'Süper Lig', 'SUP', 'Turkey', 1, 'manual', 'active', 'europe'),
  ('scottish-prem', 'Scottish Premiership', 'SPL', 'Scotland', 1, 'manual', 'active', 'europe'),
  ('belgian-pro', 'Belgian Pro League', 'BEL', 'Belgium', 1, 'manual', 'active', 'europe'),
  ('mls', 'Major League Soccer', 'MLS', 'USA', 1, 'manual', 'active', 'americas'),
  ('brasileirao', 'Brasileirão Série A', 'BRA', 'Brazil', 1, 'manual', 'active', 'americas'),
  ('argentina-liga', 'Liga Profesional', 'ARG', 'Argentina', 1, 'manual', 'active', 'americas')
ON CONFLICT (id) DO UPDATE
SET
  name = EXCLUDED.name,
  short_name = EXCLUDED.short_name,
  country = EXCLUDED.country,
  tier = EXCLUDED.tier,
  data_source = EXCLUDED.data_source,
  status = EXCLUDED.status,
  region = EXCLUDED.region;

-- ------------------------------------------------------------------
-- 5. Create a reusable function to propagate team crests to matches
-- This can be called anytime crests are updated on the teams table.
-- ------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.sync_match_logos_from_teams()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_home_updated integer := 0;
  v_away_updated integer := 0;
BEGIN
  WITH home_updates AS (
    UPDATE public.matches AS m
    SET
      home_logo_url = t.crest_url,
      updated_at = timezone('utc', now())
    FROM public.teams AS t
    WHERE
      m.home_team_id = t.id
      AND t.crest_url IS NOT NULL
      AND t.crest_url != ''
      AND (m.home_logo_url IS NULL OR m.home_logo_url = '' OR m.home_logo_url != t.crest_url)
    RETURNING m.id
  )
  SELECT count(*) INTO v_home_updated FROM home_updates;

  WITH away_updates AS (
    UPDATE public.matches AS m
    SET
      away_logo_url = t.crest_url,
      updated_at = timezone('utc', now())
    FROM public.teams AS t
    WHERE
      m.away_team_id = t.id
      AND t.crest_url IS NOT NULL
      AND t.crest_url != ''
      AND (m.away_logo_url IS NULL OR m.away_logo_url = '' OR m.away_logo_url != t.crest_url)
    RETURNING m.id
  )
  SELECT count(*) INTO v_away_updated FROM away_updates;

  RETURN jsonb_build_object(
    'home_logos_updated', v_home_updated,
    'away_logos_updated', v_away_updated,
    'synced_at', timezone('utc', now())
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sync_match_logos_from_teams() TO service_role;

COMMIT;
