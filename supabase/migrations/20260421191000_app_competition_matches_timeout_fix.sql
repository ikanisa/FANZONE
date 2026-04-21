DROP FUNCTION IF EXISTS public.app_competition_matches(text, integer);

CREATE OR REPLACE FUNCTION public.app_competition_matches(
  p_competition_id text,
  p_limit integer DEFAULT 500
)
RETURNS SETOF public.matches_live_view
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v_season text;
BEGIN
  v_season := public.get_competition_current_season(p_competition_id);

  IF v_season IS NULL THEN
    RETURN QUERY
    SELECT mv.*
    FROM public.matches_live_view AS mv
    WHERE mv.competition_id = p_competition_id
    ORDER BY mv.date ASC, mv.kickoff_time ASC NULLS LAST, mv.id ASC
    LIMIT greatest(coalesce(p_limit, 500), 1);
    RETURN;
  END IF;

  RETURN QUERY
  SELECT mv.*
  FROM public.matches_live_view AS mv
  WHERE mv.competition_id = p_competition_id
    AND mv.season = v_season
  ORDER BY mv.date ASC, mv.kickoff_time ASC NULLS LAST, mv.id ASC
  LIMIT greatest(coalesce(p_limit, 500), 1);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_competition_matches(text, integer) TO anon, authenticated;
