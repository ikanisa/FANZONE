BEGIN;

UPDATE public.teams AS t
SET country = btrim(t.name)
WHERE nullif(btrim(t.country), '') IS NULL
  AND nullif(btrim(t.name), '') IS NOT NULL
  AND NOT public.is_team_slot_placeholder(t.name)
  AND t.name !~ '\([A-Z]{3}\)$'
  AND EXISTS (
    SELECT 1
    FROM unnest(coalesce(t.competition_ids, '{}'::text[])) AS competition_id
    WHERE competition_id LIKE 'wc-%'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM unnest(coalesce(t.competition_ids, '{}'::text[])) AS competition_id
    WHERE competition_id NOT LIKE 'wc-%'
  );

COMMIT;
