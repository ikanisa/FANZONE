DROP FUNCTION IF EXISTS public.app_competition_matches(text, integer);

CREATE OR REPLACE FUNCTION public.app_competition_matches(
  p_competition_id text,
  p_limit integer DEFAULT 500
)
RETURNS SETOF public.matches_live_view
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  WITH chosen_season AS (
    SELECT public.get_competition_current_season(p_competition_id) AS season
  ),
  ranked_matches AS (
    SELECT
      m.id,
      m.date,
      m.kickoff_time,
      public.normalize_match_status_value(m.status) AS normalized_status
    FROM public.matches AS m
    CROSS JOIN chosen_season AS cs
    WHERE m.competition_id = p_competition_id
      AND (cs.season IS NULL OR m.season = cs.season)
    ORDER BY
      CASE public.normalize_match_status_value(m.status)
        WHEN 'live' THEN 0
        WHEN 'upcoming' THEN 1
        ELSE 2
      END,
      CASE
        WHEN public.normalize_match_status_value(m.status) = 'finished' THEN m.date
        ELSE NULL
      END DESC NULLS LAST,
      CASE
        WHEN public.normalize_match_status_value(m.status) <> 'finished' THEN m.date
        ELSE NULL
      END ASC NULLS LAST,
      m.kickoff_time ASC NULLS LAST,
      m.id ASC
    LIMIT greatest(coalesce(p_limit, 500), 1)
  )
  SELECT mv.*
  FROM ranked_matches AS rm
  JOIN public.matches_live_view AS mv
    ON mv.id = rm.id
  ORDER BY
    CASE rm.normalized_status
      WHEN 'live' THEN 0
      WHEN 'upcoming' THEN 1
      ELSE 2
    END,
    CASE
      WHEN rm.normalized_status = 'finished' THEN rm.date
      ELSE NULL
    END DESC NULLS LAST,
    CASE
      WHEN rm.normalized_status <> 'finished' THEN rm.date
      ELSE NULL
    END ASC NULLS LAST,
    rm.kickoff_time ASC NULLS LAST,
    rm.id ASC;
$$;

GRANT EXECUTE ON FUNCTION public.app_competition_matches(text, integer) TO anon, authenticated;
