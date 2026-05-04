-- Foreground venue discovery by device location.
-- Uses a Haversine calculation so this works without PostGIS.

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
  SELECT v.*
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
  ORDER BY
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
    ),
    v.name
  LIMIT greatest(1, least(coalesce(p_limit, 40), 100));
$$;

COMMENT ON FUNCTION public.search_nearby_venues(
  double precision,
  double precision,
  text,
  integer
) IS 'Returns active open venues ordered by distance from a foreground device location.';

GRANT EXECUTE ON FUNCTION public.search_nearby_venues(
  double precision,
  double precision,
  text,
  integer
) TO anon, authenticated, service_role;
