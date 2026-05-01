-- Align active sports-bar API names and competition ranking without dropping
-- compatibility objects that older deployed projects may still reference.

CREATE OR REPLACE FUNCTION public.competition_catalog_rank(
  p_competition_id text,
  p_competition_name text DEFAULT NULL::text
) RETURNS integer
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
    WHEN combined_value LIKE '%fifa world cup%'
      OR combined_value LIKE '%world cup%'
      OR id_value IN ('fifa world cup', 'world cup')
      THEN 1
    WHEN combined_value LIKE '%champions league%'
      OR id_value IN ('ucl', 'uefa champions league', 'champions league')
      THEN 2
    WHEN combined_value LIKE '%europa league%'
      OR id_value IN ('uel', 'uefa europa league', 'europa league')
      THEN 3
    WHEN id_value IN ('epl', 'english premier league', 'premier league')
      OR name_value IN ('premier league', 'english premier league')
      THEN 10
    WHEN combined_value LIKE '%la liga%'
      THEN 20
    WHEN combined_value LIKE '%serie a%'
      THEN 30
    WHEN combined_value LIKE '%ligue 1%'
      THEN 40
    WHEN combined_value LIKE '%bundesliga%'
      THEN 50
    ELSE 1000
  END
  FROM normalized;
$$;

COMMENT ON FUNCTION public.competition_catalog_rank(text, text)
IS 'Ranks the supported sports-bar football catalog: World Cup, UEFA cups, EPL, La Liga, Serie A, Ligue 1, Bundesliga, then curated local/rest.';

CREATE OR REPLACE VIEW public.app_competitions_ranked AS
 SELECT ac.id,
    ac.name,
    ac.short_name,
    ac.country,
    ac.tier,
    ac.competition_type,
    ac.is_international,
    ac.is_active,
    ac.created_at,
    ac.updated_at,
    ac.current_season_id,
    ac.current_season_label,
    ac.future_match_count,
    public.competition_catalog_rank(ac.id, ac.name)::bigint AS catalog_rank
   FROM public.app_competitions ac;

CREATE OR REPLACE FUNCTION public.sports_bar_is_venue_member(
  p_venue_id uuid,
  p_allowed_roles public.venue_user_role[] DEFAULT ARRAY['owner'::public.venue_user_role, 'manager'::public.venue_user_role, 'staff'::public.venue_user_role]
) RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT public.venue_user_has_role(p_venue_id, p_allowed_roles);
$$;

CREATE OR REPLACE FUNCTION public.reconcile_wallet(
  p_user_id uuid DEFAULT NULL::uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
BEGIN
  RETURN public.get_wallet_balance(p_user_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.refund_pool_for_cancelled_match(
  p_pool_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  RETURN public.reverse_or_refund_pool_if_match_cancelled(p_pool_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_curate_match(
  p_match_id text,
  p_country_code text DEFAULT NULL::text,
  p_venue_id uuid DEFAULT NULL::uuid,
  p_priority_score integer DEFAULT 50,
  p_reason text DEFAULT ''::text,
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_starts_at timestamp with time zone DEFAULT NULL::timestamp with time zone,
  p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone,
  p_is_active boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  RETURN public.admin_curate_match_control(
    p_match_id,
    p_country_code,
    p_venue_id,
    p_priority_score,
    p_reason,
    p_metadata,
    p_starts_at,
    p_expires_at,
    p_is_active
  );
END;
$$;

COMMENT ON FUNCTION public.sports_bar_is_venue_member(uuid, public.venue_user_role[])
IS 'Canonical sports-bar venue membership helper. Keeps active code away from retired helper names.';
COMMENT ON FUNCTION public.reconcile_wallet(uuid)
IS 'Canonical wallet reconciliation alias backed by the ledger-safe get_wallet_balance/reconcile_fet_wallet path.';
COMMENT ON FUNCTION public.refund_pool_for_cancelled_match(uuid)
IS 'Canonical cancelled-match pool refund alias backed by the idempotent wallet-ledger refund routine.';
COMMENT ON FUNCTION public.admin_curate_match(text, text, uuid, integer, text, jsonb, timestamp with time zone, timestamp with time zone, boolean)
IS 'Canonical admin curation alias for sports-bar match discovery.';

GRANT EXECUTE ON FUNCTION public.competition_catalog_rank(text, text) TO anon, authenticated, service_role;
GRANT SELECT ON public.app_competitions_ranked TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sports_bar_is_venue_member(uuid, public.venue_user_role[]) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reconcile_wallet(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.refund_pool_for_cancelled_match(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_curate_match(text, text, uuid, integer, text, jsonb, timestamp with time zone, timestamp with time zone, boolean) TO authenticated, service_role;
