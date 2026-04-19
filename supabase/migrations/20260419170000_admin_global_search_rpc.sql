BEGIN;

CREATE OR REPLACE FUNCTION public.admin_global_search(
  p_query text,
  p_limit integer DEFAULT 12
)
RETURNS TABLE (
  result_id text,
  result_type text,
  title text,
  subtitle text,
  route text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_query text := nullif(trim(coalesce(p_query, '')), '');
  v_limit integer := greatest(1, least(coalesce(p_limit, 12), 24));
BEGIN
  PERFORM public.require_active_admin_user();

  IF v_query IS NULL OR char_length(v_query) < 2 THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH params AS (
    SELECT
      v_query AS raw_query,
      '%' || v_query || '%' AS ilike_query
  ),
  user_hits AS (
    SELECT
      upa.id::text AS result_id,
      'user'::text AS result_type,
      coalesce(
        nullif(trim(upa.display_name), ''),
        nullif(trim(upa.email), ''),
        nullif(trim(upa.phone), ''),
        upa.id::text
      ) AS title,
      coalesce(
        nullif(trim(upa.email), ''),
        nullif(trim(upa.phone), ''),
        'Platform user'
      ) AS subtitle,
      '/users?q=' || params.raw_query AS route,
      1 AS group_rank,
      row_number() OVER (
        ORDER BY
          upa.display_name NULLS LAST,
          upa.email NULLS LAST,
          upa.id
      ) AS item_rank
    FROM public.user_profiles_admin upa
    CROSS JOIN params
    WHERE
      upa.display_name ILIKE params.ilike_query
      OR upa.email ILIKE params.ilike_query
      OR upa.phone ILIKE params.ilike_query
    LIMIT 3
  ),
  fixture_hits AS (
    SELECT
      m.id::text AS result_id,
      'fixture'::text AS result_type,
      m.home_team || ' vs ' || m.away_team AS title,
      lower(coalesce(m.status, 'fixture')) || ' — ' || to_char(m.date, 'YYYY-MM-DD') AS subtitle,
      '/fixtures?q=' || params.raw_query AS route,
      2 AS group_rank,
      row_number() OVER (
        ORDER BY m.date DESC, m.id
      ) AS item_rank
    FROM public.matches m
    CROSS JOIN params
    WHERE
      m.home_team ILIKE params.ilike_query
      OR m.away_team ILIKE params.ilike_query
    LIMIT 3
  ),
  pool_hits AS (
    SELECT
      pc.id::text AS result_id,
      'pool'::text AS result_type,
      'Pool ' || pc.id::text AS title,
      lower(coalesce(pc.status, 'open')) || ' — ' || coalesce(pc.total_pool_fet, 0)::text || ' FET' AS subtitle,
      '/challenges?q=' || pc.id::text AS route,
      3 AS group_rank,
      row_number() OVER (
        ORDER BY pc.created_at DESC, pc.id
      ) AS item_rank
    FROM public.prediction_challenges pc
    CROSS JOIN params
    WHERE
      pc.id::text ILIKE params.ilike_query
      OR pc.match_id::text ILIKE params.ilike_query
    LIMIT 3
  ),
  partner_hits AS (
    SELECT
      p.id::text AS result_id,
      'partner'::text AS result_type,
      p.name AS title,
      coalesce(p.category, 'partner') || ' — ' || coalesce(p.status, 'unknown') AS subtitle,
      '/partners?q=' || params.raw_query AS route,
      4 AS group_rank,
      row_number() OVER (
        ORDER BY p.name, p.id
      ) AS item_rank
    FROM public.partners p
    CROSS JOIN params
    WHERE p.name ILIKE params.ilike_query
    LIMIT 3
  ),
  reward_hits AS (
    SELECT
      r.id::text AS result_id,
      'reward'::text AS result_type,
      r.title AS title,
      coalesce(r.category, 'reward') || ' — ' || r.fet_cost::text || ' FET' AS subtitle,
      '/rewards?q=' || params.raw_query AS route,
      5 AS group_rank,
      row_number() OVER (
        ORDER BY r.title, r.id
      ) AS item_rank
    FROM public.rewards r
    CROSS JOIN params
    WHERE
      r.title ILIKE params.ilike_query
      OR coalesce(r.category, '') ILIKE params.ilike_query
    LIMIT 3
  ),
  campaign_hits AS (
    SELECT
      c.id::text AS result_id,
      'campaign'::text AS result_type,
      c.title AS title,
      lower(coalesce(c.type, 'campaign')) || ' — ' || lower(coalesce(c.status, 'draft')) AS subtitle,
      '/notifications?q=' || params.raw_query AS route,
      6 AS group_rank,
      row_number() OVER (
        ORDER BY c.created_at DESC, c.id
      ) AS item_rank
    FROM public.campaigns c
    CROSS JOIN params
    WHERE
      c.title ILIKE params.ilike_query
      OR c.message ILIKE params.ilike_query
    LIMIT 3
  ),
  combined AS (
    SELECT * FROM user_hits
    UNION ALL
    SELECT * FROM fixture_hits
    UNION ALL
    SELECT * FROM pool_hits
    UNION ALL
    SELECT * FROM partner_hits
    UNION ALL
    SELECT * FROM reward_hits
    UNION ALL
    SELECT * FROM campaign_hits
  )
  SELECT
    combined.result_id,
    combined.result_type,
    combined.title,
    combined.subtitle,
    combined.route
  FROM combined
  ORDER BY combined.group_rank, combined.item_rank
  LIMIT v_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_global_search(text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_global_search(text, integer) TO authenticated;

COMMIT;
