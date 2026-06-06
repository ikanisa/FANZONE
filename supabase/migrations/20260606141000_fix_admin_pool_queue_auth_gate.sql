-- Force admin auth execution for the pool operations queue.

CREATE OR REPLACE FUNCTION public.admin_pool_operations_queue(p_limit integer DEFAULT 50)
RETURNS TABLE(
  pool_id uuid,
  title text,
  scope text,
  country_code text,
  country_id uuid,
  venue_id uuid,
  venue_name text,
  match_id text,
  match_label text,
  competition_name text,
  kickoff_at timestamp with time zone,
  match_status text,
  result_code text,
  pool_status text,
  total_members bigint,
  total_staked_fet bigint,
  camps jsonb,
  settlement_status text,
  settlement_started_at timestamp with time zone,
  settlement_completed_at timestamp with time zone,
  settlement_error text,
  share_url text,
  social_card_url text,
  needs_settlement boolean,
  needs_social_card boolean,
  age_minutes bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
  WITH _auth AS (
    SELECT public.require_active_admin_user()
  ),
  pool_rows AS (
    SELECT
      p.*,
      v.name AS venue_name,
      coalesce(m.home_team, 'Home') || ' vs ' || coalesce(m.away_team, 'Away') AS match_label,
      m.competition_name,
      m.match_date AS kickoff_at,
      coalesce(m.match_status, m.status) AS match_status_label,
      m.result_code AS match_result_code,
      CASE
        WHEN lower(coalesce(m.status, '')) IN ('cancelled', 'canceled') THEN 'cancelled'
        WHEN lower(coalesce(m.match_status, '')) IN ('cancelled', 'canceled') THEN 'cancelled'
        WHEN lower(coalesce(m.status, '')) = 'postponed' THEN 'postponed'
        WHEN lower(coalesce(m.match_status, '')) = 'postponed' THEN 'postponed'
        WHEN lower(coalesce(m.status, '')) IN ('final', 'finished', 'complete', 'completed') THEN 'final'
        WHEN lower(coalesce(m.match_status, '')) = 'finished' THEN 'final'
        ELSE lower(coalesce(nullif(m.status, ''), nullif(m.match_status, ''), 'scheduled'))
      END AS normalized_match_status,
      coalesce(ps.camps, '[]'::jsonb) AS pool_camps,
      s.status::text AS settlement_status_text,
      s.started_at,
      s.completed_at,
      coalesce(s.error_message, s.metadata ->> 'error') AS settlement_error_text
    FROM public.match_pools p
    LEFT JOIN public.match_pool_stats ps ON ps.id = p.id
    LEFT JOIN public.app_matches m ON m.id = p.match_id
    LEFT JOIN public.venues v ON v.id = p.venue_id
    LEFT JOIN public.match_pool_settlements s ON s.pool_id = p.id
    WHERE
      p.status::text IN ('open', 'locked', 'live', 'settling')
      OR s.status::text IN ('failed', 'pending', 'running')
      OR p.created_at >= timezone('utc', now()) - interval '30 days'
  )
  SELECT
    r.id AS pool_id,
    r.title,
    r.scope::text,
    r.country_code,
    r.country_id,
    r.venue_id,
    r.venue_name,
    r.match_id,
    r.match_label,
    r.competition_name,
    r.kickoff_at,
    r.match_status_label AS match_status,
    r.match_result_code AS result_code,
    r.status::text AS pool_status,
    r.total_members,
    r.total_staked_fet,
    r.pool_camps AS camps,
    r.settlement_status_text AS settlement_status,
    r.started_at AS settlement_started_at,
    r.completed_at AS settlement_completed_at,
    r.settlement_error_text AS settlement_error,
    r.share_url,
    r.social_card_url,
    (
      r.status::text IN ('open', 'locked', 'live', 'settling')
      AND (
        r.normalized_match_status IN ('cancelled', 'postponed')
        OR (r.normalized_match_status = 'final' AND r.match_result_code IS NOT NULL)
      )
      AND coalesce(r.settlement_status_text, '') <> 'completed'
    ) AS needs_settlement,
    nullif(trim(coalesce(r.social_card_url, '')), '') IS NULL AS needs_social_card,
    floor(extract(epoch FROM (timezone('utc', now()) - r.created_at)) / 60)::bigint AS age_minutes
  FROM pool_rows r
  CROSS JOIN _auth
  ORDER BY
    CASE
      WHEN r.settlement_status_text = 'failed' THEN 0
      WHEN r.status::text = 'settling' THEN 1
      WHEN r.normalized_match_status IN ('cancelled', 'postponed') THEN 2
      WHEN r.status::text IN ('open', 'locked', 'live')
        AND r.normalized_match_status = 'final'
        AND r.match_result_code IS NOT NULL THEN 3
      WHEN nullif(trim(coalesce(r.social_card_url, '')), '') IS NULL THEN 4
      ELSE 5
    END,
    r.kickoff_at NULLS LAST,
    r.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 200));
$$;

REVOKE ALL ON FUNCTION public.admin_pool_operations_queue(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_pool_operations_queue(integer) TO authenticated, service_role;
