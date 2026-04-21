BEGIN;

WITH mapped_countries AS (
  SELECT
    t.id,
    CASE substring(t.name FROM '\(([A-Z]{3})\)$')
      WHEN 'ARG' THEN 'Argentina'
      WHEN 'AUT' THEN 'Austria'
      WHEN 'BRA' THEN 'Brazil'
      WHEN 'EGY' THEN 'Egypt'
      WHEN 'ENG' THEN 'England'
      WHEN 'ESP' THEN 'Spain'
      WHEN 'FRA' THEN 'France'
      WHEN 'GER' THEN 'Germany'
      WHEN 'ITA' THEN 'Italy'
      WHEN 'JPN' THEN 'Japan'
      WHEN 'KOR' THEN 'South Korea'
      WHEN 'KSA' THEN 'Saudi Arabia'
      WHEN 'MAR' THEN 'Morocco'
      WHEN 'MEX' THEN 'Mexico'
      WHEN 'NZL' THEN 'New Zealand'
      WHEN 'POR' THEN 'Portugal'
      WHEN 'RSA' THEN 'South Africa'
      WHEN 'TUN' THEN 'Tunisia'
      WHEN 'UAE' THEN 'United Arab Emirates'
      WHEN 'USA' THEN 'United States'
      ELSE NULL
    END AS country
  FROM public.teams AS t
  WHERE nullif(btrim(t.country), '') IS NULL
    AND t.name ~ '\(([A-Z]{3})\)$'
    AND EXISTS (
      SELECT 1
      FROM unnest(coalesce(t.competition_ids, '{}'::text[])) AS competition_id
      WHERE competition_id = 'cwc-2025'
    )
)
UPDATE public.teams AS t
SET country = mapped.country
FROM mapped_countries AS mapped
WHERE t.id = mapped.id
  AND mapped.country IS NOT NULL;

COMMIT;
