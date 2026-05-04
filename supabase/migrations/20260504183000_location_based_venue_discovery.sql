-- Enforce location-based venue discovery for the mobile app.
-- Imported CSV venues did not include coordinates; use city-center coordinates
-- for the imported Malta and Rwanda launch markets until venue-level geocoding
-- is available.

UPDATE public.venues
SET
  latitude = 35.8989,
  longitude = 14.5146,
  city = COALESCE(NULLIF(trim(city), ''), 'Valletta'),
  timezone = 'Europe/Malta',
  updated_at = timezone('utc', now())
WHERE country_code = 'MT'
  AND is_active = true
  AND (latitude IS NULL OR longitude IS NULL);

UPDATE public.venues
SET
  latitude = -1.9441,
  longitude = 30.0619,
  city = COALESCE(NULLIF(trim(city), ''), 'Kigali'),
  timezone = 'Africa/Kigali',
  updated_at = timezone('utc', now())
WHERE country_code = 'RW'
  AND is_active = true
  AND (latitude IS NULL OR longitude IS NULL);

CREATE OR REPLACE FUNCTION public.search_nearby_venues(
  p_latitude double precision,
  p_longitude double precision,
  p_country_code text DEFAULT NULL,
  p_limit integer DEFAULT 40
)
RETURNS SETOF public.venues
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  WITH scored AS (
    SELECT
      v,
      6371.0 * acos(
        least(
          1.0,
          greatest(
            -1.0,
            cos(radians(p_latitude))
              * cos(radians(v.latitude))
              * cos(radians(v.longitude) - radians(p_longitude))
              + sin(radians(p_latitude)) * sin(radians(v.latitude))
          )
        )
      ) AS distance_km
    FROM public.venues v
    WHERE v.is_active = true
      AND v.is_open = true
      AND v.latitude IS NOT NULL
      AND v.longitude IS NOT NULL
      AND (
        p_country_code IS NULL
        OR trim(p_country_code) = ''
        OR v.country_code = upper(trim(p_country_code))
      )
  )
  SELECT (scored.v).*
  FROM scored
  WHERE scored.distance_km <= 20
  ORDER BY scored.distance_km, (scored.v).name
  LIMIT greatest(1, least(coalesce(p_limit, 40), 100));
$$;

COMMENT ON FUNCTION public.search_nearby_venues(
  double precision,
  double precision,
  text,
  integer
) IS 'Returns active open venues within 20 km of a foreground device location, ordered by distance.';
