BEGIN;

CREATE OR REPLACE FUNCTION public.competition_catalog_rank(
  p_competition_id text,
  p_competition_name text DEFAULT NULL
)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  WITH normalized AS (
    SELECT
      trim(
        regexp_replace(
          lower(coalesce(p_competition_id, '') || ' ' || coalesce(p_competition_name, '')),
          '[^a-z0-9]+',
          ' ',
          'g'
        )
      ) AS combined_value,
      trim(
        regexp_replace(lower(coalesce(p_competition_id, '')), '[^a-z0-9]+', ' ', 'g')
      ) AS id_value,
      trim(
        regexp_replace(lower(coalesce(p_competition_name, '')), '[^a-z0-9]+', ' ', 'g')
      ) AS name_value
  )
  SELECT CASE
    WHEN combined_value LIKE '%champions league%'
      OR id_value IN ('ucl', 'uefa champions league')
      THEN 1
    WHEN id_value = 'epl'
      OR name_value IN ('premier league', 'english premier league')
      THEN 2
    WHEN combined_value LIKE '%la liga%'
      THEN 3
    WHEN combined_value LIKE '%ligue 1%'
      THEN 4
    WHEN combined_value LIKE '%bundesliga%'
      THEN 5
    WHEN combined_value LIKE '%serie a%'
      THEN 6
    ELSE 1000
  END
  FROM normalized;
$$;

GRANT EXECUTE ON FUNCTION public.competition_catalog_rank(text, text) TO anon, authenticated;

DROP VIEW IF EXISTS public.app_competitions_ranked;

CREATE VIEW public.app_competitions_ranked AS
SELECT
  ac.*,
  public.competition_catalog_rank(ac.id, ac.name) AS catalog_rank
FROM public.app_competitions AS ac;

GRANT SELECT ON public.app_competitions_ranked TO anon, authenticated;

COMMIT;
