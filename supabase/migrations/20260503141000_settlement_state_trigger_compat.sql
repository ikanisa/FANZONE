-- Keep early-settlement protection while allowing explicit cancelled/postponed
-- settlement paths handled by settle_match_pool.

CREATE OR REPLACE FUNCTION public.sports_bar_prevent_early_settlement()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_match_status text;
BEGIN
  SELECT CASE
           WHEN lower(coalesce(m.status, '')) IN ('final', 'finished', 'complete', 'completed') THEN 'final'
           WHEN lower(coalesce(m.match_status, '')) = 'finished' THEN 'final'
           WHEN lower(coalesce(m.status, '')) IN ('cancelled', 'canceled') THEN 'cancelled'
           WHEN lower(coalesce(m.match_status, '')) IN ('cancelled', 'canceled') THEN 'cancelled'
           WHEN lower(coalesce(m.status, '')) = 'postponed' THEN 'postponed'
           WHEN lower(coalesce(m.match_status, '')) = 'postponed' THEN 'postponed'
           ELSE lower(coalesce(nullif(m.status, ''), nullif(m.match_status, ''), ''))
         END
  INTO v_match_status
  FROM public.match_pools p
  JOIN public.matches m ON m.id = p.match_id
  WHERE p.id = NEW.pool_id;

  IF NEW.status IN ('running', 'completed')
     AND coalesce(v_match_status, '') NOT IN ('final', 'cancelled', 'postponed') THEN
    RAISE EXCEPTION 'Pool cannot settle before final result';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON TABLE
  public.admin_platform_features,
  public.admin_platform_content_blocks
FROM anon;

GRANT SELECT ON TABLE
  public.admin_platform_features,
  public.admin_platform_content_blocks
TO authenticated, service_role;
