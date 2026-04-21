BEGIN;

CREATE OR REPLACE FUNCTION public.normalize_team_display_name(p_name text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  WITH normalized AS (
    SELECT
      btrim(coalesce(p_name, '')) AS original_name,
      upper(btrim(coalesce(p_name, ''))) AS upper_name
  )
  SELECT CASE
    WHEN upper_name ~ '^[12][A-L]$' THEN
      CASE substring(upper_name FROM 1 FOR 1)
        WHEN '1' THEN 'Winner Group ' || substring(upper_name FROM 2 FOR 1)
        ELSE 'Runner-up Group ' || substring(upper_name FROM 2 FOR 1)
      END
    WHEN upper_name ~ '^3[A-L](/[A-L])+$' THEN
      'Best 3rd Place Groups ' || substring(upper_name FROM 2)
    WHEN upper_name ~ '^[A-L][123]$' THEN
      CASE substring(upper_name FROM 2 FOR 1)
        WHEN '1' THEN 'Winner Group ' || substring(upper_name FROM 1 FOR 1)
        WHEN '2' THEN 'Runner-up Group ' || substring(upper_name FROM 1 FOR 1)
        ELSE '3rd Place Group ' || substring(upper_name FROM 1 FOR 1)
      END
    WHEN upper_name ~ '^W[0-9]+$' THEN
      'Winner Match ' || substring(upper_name FROM 2)
    WHEN upper_name ~ '^L[0-9]+$' THEN
      'Loser Match ' || substring(upper_name FROM 2)
    WHEN upper_name = 'TBD' OR upper_name = 'TO BE DETERMINED' THEN 'TBD'
    WHEN original_name ~ '^1\.\s+' THEN regexp_replace(original_name, '^1\.\s+', '')
    ELSE original_name
  END
  FROM normalized;
$$;

GRANT EXECUTE ON FUNCTION public.normalize_team_display_name(text) TO anon, authenticated;

COMMIT;
