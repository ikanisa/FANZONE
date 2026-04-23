BEGIN;

DROP FUNCTION IF EXISTS public.app_competition_teams(text);
DROP VIEW IF EXISTS public.team_catalog_entries;

DROP FUNCTION IF EXISTS public.app_competition_matches(text, integer);
DROP FUNCTION IF EXISTS public.app_matches_by_date(date);
DROP FUNCTION IF EXISTS public.app_team_matches(text, integer);
DROP FUNCTION IF EXISTS public.get_live_matches();
DROP VIEW IF EXISTS public.matches_live_view;

COMMIT;
