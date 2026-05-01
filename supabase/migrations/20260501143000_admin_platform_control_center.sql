-- ============================================================================
-- Admin platform control center
--
-- Additive admin API for the simplified sports-bar FET pool platform. These
-- functions keep control-center mutations behind admin role checks and write
-- both admin audit rows and canonical sports-bar audit rows where useful.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_control_center_audit(
  p_action text,
  p_module text,
  p_target_type text,
  p_target_id text DEFAULT NULL,
  p_before_state jsonb DEFAULT NULL,
  p_after_state jsonb DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_actor_user_id uuid;
  v_admin_record_id uuid;
BEGIN
  v_actor_user_id := public.require_active_admin_user();

  SELECT id
  INTO v_admin_record_id
  FROM public.admin_users
  WHERE user_id = v_actor_user_id
    AND is_active = true
  LIMIT 1;

  INSERT INTO public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    before_state,
    after_state,
    metadata
  )
  VALUES (
    v_admin_record_id,
    p_action,
    coalesce(nullif(trim(p_module), ''), 'platform_control'),
    coalesce(nullif(trim(p_target_type), ''), 'unknown'),
    coalesce(p_target_id, ''),
    coalesce(p_before_state, '{}'::jsonb),
    coalesce(p_after_state, '{}'::jsonb),
    coalesce(p_metadata, '{}'::jsonb)
  );

  PERFORM public.sports_bar_write_audit(
    p_action,
    coalesce(nullif(trim(p_target_type), ''), 'unknown'),
    p_target_id,
    p_before_state,
    p_after_state,
    v_actor_user_id
  );
END;
$$;

COMMENT ON FUNCTION public.admin_control_center_audit(text,text,text,text,jsonb,jsonb,jsonb)
  IS 'Shared admin-control audit helper. Requires an active admin session and mirrors important mutations into canonical audit_logs.';

CREATE OR REPLACE FUNCTION public.admin_dashboard_kpis()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_active_countries bigint := 0;
  v_active_venues bigint := 0;
  v_active_pools bigint := 0;
  v_total_fet_issued numeric := 0;
  v_total_fet_staked numeric := 0;
  v_pending_settlements bigint := 0;
  v_failed_settlements bigint := 0;
  v_todays_orders bigint := 0;
  v_risk_alerts bigint := 0;
  v_active_users bigint := 0;
  v_competitions_count bigint := 0;
  v_upcoming_fixtures bigint := 0;
BEGIN
  PERFORM public.require_active_admin_user();

  SELECT count(*)::bigint
  INTO v_active_countries
  FROM public.countries
  WHERE is_active = true;

  SELECT count(*)::bigint
  INTO v_active_venues
  FROM public.venues
  WHERE is_active = true
    AND coalesce(status, 'active') <> 'suspended';

  SELECT count(*)::bigint
  INTO v_active_pools
  FROM public.match_pools
  WHERE status::text IN ('open', 'locked', 'live', 'settling');

  IF to_regclass('public.fet_supply_overview') IS NOT NULL THEN
    EXECUTE 'SELECT coalesce(total_supply, 0) FROM public.fet_supply_overview'
    INTO v_total_fet_issued;
  ELSE
    SELECT coalesce(sum(amount_fet) FILTER (WHERE direction = 'credit' AND status = 'posted'), 0)
    INTO v_total_fet_issued
    FROM public.fet_wallet_transactions;
  END IF;

  SELECT coalesce(sum(staked_balance_fet + pending_balance_fet), 0)
  INTO v_total_fet_staked
  FROM public.fet_wallets;

  SELECT count(*)::bigint
  INTO v_pending_settlements
  FROM public.match_pools p
  JOIN public.matches m ON m.id = p.match_id
  WHERE p.status::text IN ('open', 'locked', 'live', 'settling')
    AND coalesce(m.status, CASE m.match_status WHEN 'finished' THEN 'final' ELSE m.match_status END) = 'final';

  SELECT count(*)::bigint
  INTO v_failed_settlements
  FROM public.match_pool_settlements
  WHERE status::text = 'failed';

  SELECT count(*)::bigint
  INTO v_todays_orders
  FROM public.orders
  WHERE created_at >= date_trunc('day', timezone('utc', now()));

  IF to_regclass('public.moderation_reports') IS NOT NULL THEN
    SELECT count(*)::bigint
    INTO v_risk_alerts
    FROM public.moderation_reports
    WHERE status IN ('open', 'investigating', 'escalated');
  END IF;

  SELECT count(*)::bigint
  INTO v_active_users
  FROM auth.users
  WHERE last_sign_in_at >= timezone('utc', now()) - interval '30 days';

  SELECT count(*)::bigint
  INTO v_competitions_count
  FROM public.competitions
  WHERE coalesce(is_active, true) = true;

  SELECT count(*)::bigint
  INTO v_upcoming_fixtures
  FROM public.matches
  WHERE coalesce(status, match_status, 'scheduled') IN ('scheduled', 'upcoming', 'not_started', 'live')
    AND coalesce(starts_at, match_date, timezone('utc', now())) >= timezone('utc', now()) - interval '2 hours';

  RETURN jsonb_build_object(
    'activeCountries', coalesce(v_active_countries, 0),
    'activeVenues', coalesce(v_active_venues, 0),
    'activePools', coalesce(v_active_pools, 0),
    'totalFetIssued', coalesce(v_total_fet_issued, 0),
    'totalFetStaked', coalesce(v_total_fet_staked, 0),
    'pendingSettlements', coalesce(v_pending_settlements, 0),
    'failedSettlements', coalesce(v_failed_settlements, 0),
    'todaysOrders', coalesce(v_todays_orders, 0),
    'riskAlerts', coalesce(v_risk_alerts, 0),
    -- Backward-compatible keys while the admin PWA migrates views.
    'activeUsers', coalesce(v_active_users, 0),
    'openPools', coalesce(v_active_pools, 0),
    'fetTransferred24h', 0,
    'moderationAlerts', coalesce(v_risk_alerts, 0),
    'competitionsCount', coalesce(v_competitions_count, 0),
    'upcomingFixtures', coalesce(v_upcoming_fixtures, 0)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_upsert_country(
  p_id uuid DEFAULT NULL,
  p_name text DEFAULT NULL,
  p_iso_code text DEFAULT NULL,
  p_region text DEFAULT 'africa',
  p_is_active boolean DEFAULT true,
  p_rollout_priority integer DEFAULT 100
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_before jsonb;
  v_country public.countries%ROWTYPE;
  v_iso text := upper(trim(coalesce(p_iso_code, '')));
  v_region text := lower(trim(coalesce(p_region, '')));
BEGIN
  PERFORM public.require_admin_manager_user();

  IF v_iso !~ '^[A-Z]{2}$' THEN
    RAISE EXCEPTION 'Country ISO code must be two uppercase letters';
  END IF;

  IF v_region NOT IN ('africa', 'europe', 'uk', 'north_america', 'world_cup_markets') THEN
    RAISE EXCEPTION 'Unsupported rollout region';
  END IF;

  SELECT to_jsonb(c)
  INTO v_before
  FROM public.countries c
  WHERE (p_id IS NOT NULL AND c.id = p_id)
     OR c.iso_code = v_iso
  ORDER BY CASE WHEN p_id IS NOT NULL AND c.id = p_id THEN 0 ELSE 1 END
  LIMIT 1;

  INSERT INTO public.countries (
    id,
    name,
    iso_code,
    region,
    is_active,
    rollout_priority
  )
  VALUES (
    coalesce(p_id, extensions.gen_random_uuid()),
    trim(coalesce(p_name, '')),
    v_iso,
    v_region,
    coalesce(p_is_active, true),
    greatest(coalesce(p_rollout_priority, 100), 0)
  )
  ON CONFLICT (iso_code) DO UPDATE
  SET name = EXCLUDED.name,
      region = EXCLUDED.region,
      is_active = EXCLUDED.is_active,
      rollout_priority = EXCLUDED.rollout_priority,
      updated_at = timezone('utc', now())
  RETURNING *
  INTO v_country;

  PERFORM public.admin_control_center_audit(
    'upsert_country',
    'countries',
    'country',
    v_country.id::text,
    v_before,
    to_jsonb(v_country),
    jsonb_build_object('iso_code', v_country.iso_code)
  );

  RETURN to_jsonb(v_country);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_country_active(
  p_country_id uuid,
  p_is_active boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_before jsonb;
  v_country public.countries%ROWTYPE;
BEGIN
  PERFORM public.require_admin_manager_user();

  SELECT to_jsonb(c)
  INTO v_before
  FROM public.countries c
  WHERE c.id = p_country_id;

  UPDATE public.countries
  SET is_active = coalesce(p_is_active, false),
      updated_at = timezone('utc', now())
  WHERE id = p_country_id
  RETURNING *
  INTO v_country;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Country not found';
  END IF;

  PERFORM public.admin_control_center_audit(
    'set_country_active',
    'countries',
    'country',
    v_country.id::text,
    v_before,
    to_jsonb(v_country),
    jsonb_build_object('is_active', v_country.is_active)
  );

  RETURN to_jsonb(v_country);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_update_venue_control(
  p_venue_id uuid,
  p_status text DEFAULT NULL,
  p_is_active boolean DEFAULT NULL,
  p_country_id uuid DEFAULT NULL,
  p_city text DEFAULT NULL,
  p_fet_reward_percent numeric DEFAULT NULL,
  p_accepts_fet_spend boolean DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_before jsonb;
  v_venue public.venues%ROWTYPE;
  v_country_code text;
  v_status text := lower(trim(coalesce(p_status, '')));
BEGIN
  PERFORM public.require_admin_manager_user();

  IF p_venue_id IS NULL THEN
    RAISE EXCEPTION 'Venue id is required';
  END IF;

  IF v_status <> '' AND v_status NOT IN ('draft', 'pending', 'approved', 'active', 'suspended', 'rejected') THEN
    RAISE EXCEPTION 'Unsupported venue status';
  END IF;

  IF p_country_id IS NOT NULL THEN
    SELECT iso_code
    INTO v_country_code
    FROM public.countries
    WHERE id = p_country_id;

    IF v_country_code IS NULL THEN
      RAISE EXCEPTION 'Country not found';
    END IF;
  END IF;

  SELECT to_jsonb(v)
  INTO v_before
  FROM public.venues v
  WHERE v.id = p_venue_id;

  UPDATE public.venues
  SET status = coalesce(nullif(v_status, ''), status),
      is_active = coalesce(p_is_active, is_active),
      country_id = coalesce(p_country_id, country_id),
      country_code = coalesce(v_country_code, country_code),
      city = coalesce(nullif(trim(coalesce(p_city, '')), ''), city),
      fet_reward_percent = coalesce(p_fet_reward_percent, fet_reward_percent),
      accepts_fet_spend = coalesce(p_accepts_fet_spend, accepts_fet_spend),
      updated_at = timezone('utc', now())
  WHERE id = p_venue_id
  RETURNING *
  INTO v_venue;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Venue not found';
  END IF;

  PERFORM public.admin_control_center_audit(
    'update_venue_control',
    'venues',
    'venue',
    v_venue.id::text,
    v_before,
    to_jsonb(v_venue),
    jsonb_build_object('status', v_venue.status, 'fet_reward_percent', v_venue.fet_reward_percent)
  );

  RETURN to_jsonb(v_venue);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_update_competition_control(
  p_competition_id text,
  p_is_active boolean DEFAULT NULL,
  p_priority integer DEFAULT NULL,
  p_type text DEFAULT NULL,
  p_region text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_before jsonb;
  v_competition public.competitions%ROWTYPE;
  v_type text := lower(trim(coalesce(p_type, '')));
BEGIN
  PERFORM public.require_admin_manager_user();

  IF p_competition_id IS NULL OR trim(p_competition_id) = '' THEN
    RAISE EXCEPTION 'Competition id is required';
  END IF;

  IF v_type <> '' AND v_type NOT IN ('league', 'cup', 'world_cup', 'local_curated') THEN
    RAISE EXCEPTION 'Unsupported competition type';
  END IF;

  SELECT to_jsonb(c)
  INTO v_before
  FROM public.competitions c
  WHERE c.id = p_competition_id;

  UPDATE public.competitions
  SET is_active = coalesce(p_is_active, is_active),
      status = CASE
        WHEN p_is_active IS NULL THEN status
        WHEN p_is_active THEN 'active'
        ELSE 'disabled'
      END,
      priority = greatest(coalesce(p_priority, priority, 100), 0),
      type = coalesce(nullif(v_type, ''), type),
      competition_type = coalesce(nullif(v_type, ''), competition_type),
      region = coalesce(nullif(lower(trim(coalesce(p_region, ''))), ''), region),
      updated_at = timezone('utc', now())
  WHERE id = p_competition_id
  RETURNING *
  INTO v_competition;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Competition not found';
  END IF;

  PERFORM public.admin_control_center_audit(
    'update_competition_control',
    'competitions',
    'competition',
    v_competition.id,
    v_before,
    to_jsonb(v_competition),
    jsonb_build_object('is_active', v_competition.is_active, 'priority', v_competition.priority)
  );

  RETURN to_jsonb(v_competition);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_update_team_control(
  p_team_id text,
  p_country_id uuid DEFAULT NULL,
  p_popularity_score integer DEFAULT NULL,
  p_is_active boolean DEFAULT NULL,
  p_logo_url text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_before jsonb;
  v_team public.teams%ROWTYPE;
  v_country public.countries%ROWTYPE;
BEGIN
  PERFORM public.require_admin_manager_user();

  IF p_country_id IS NOT NULL THEN
    SELECT *
    INTO v_country
    FROM public.countries
    WHERE id = p_country_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Country not found';
    END IF;
  END IF;

  SELECT to_jsonb(t)
  INTO v_before
  FROM public.teams t
  WHERE t.id = p_team_id;

  UPDATE public.teams
  SET country_id = coalesce(p_country_id, country_id),
      country = coalesce(v_country.name, country),
      country_code = coalesce(v_country.iso_code, country_code),
      popularity_score = greatest(coalesce(p_popularity_score, popularity_score, 0), 0),
      is_active = coalesce(p_is_active, is_active),
      logo_url = coalesce(nullif(trim(coalesce(p_logo_url, '')), ''), logo_url),
      updated_at = timezone('utc', now())
  WHERE id = p_team_id
  RETURNING *
  INTO v_team;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Team not found';
  END IF;

  PERFORM public.admin_control_center_audit(
    'update_team_control',
    'teams',
    'team',
    v_team.id,
    v_before,
    to_jsonb(v_team),
    jsonb_build_object('is_active', v_team.is_active, 'popularity_score', v_team.popularity_score)
  );

  RETURN to_jsonb(v_team);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_upsert_reward_rule(
  p_id uuid DEFAULT NULL,
  p_scope text DEFAULT 'platform',
  p_country_id uuid DEFAULT NULL,
  p_venue_id uuid DEFAULT NULL,
  p_welcome_fet_amount bigint DEFAULT 0,
  p_order_fet_default_percent numeric DEFAULT 0,
  p_pool_creator_reward_per_member bigint DEFAULT 0,
  p_min_qualified_stake bigint DEFAULT 0,
  p_min_qualified_members integer DEFAULT 0,
  p_is_active boolean DEFAULT true,
  p_starts_at timestamp with time zone DEFAULT NULL,
  p_ends_at timestamp with time zone DEFAULT NULL,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_before jsonb;
  v_rule public.reward_rules%ROWTYPE;
  v_scope text := lower(trim(coalesce(p_scope, '')));
BEGIN
  PERFORM public.require_admin_manager_user();

  IF char_length(trim(coalesce(p_reason, ''))) < 8 THEN
    RAISE EXCEPTION 'Reward rule changes require an audit reason';
  END IF;

  IF v_scope NOT IN ('platform', 'country', 'venue') THEN
    RAISE EXCEPTION 'Unsupported reward rule scope';
  END IF;

  IF (v_scope = 'platform' AND (p_country_id IS NOT NULL OR p_venue_id IS NOT NULL))
     OR (v_scope = 'country' AND (p_country_id IS NULL OR p_venue_id IS NOT NULL))
     OR (v_scope = 'venue' AND p_venue_id IS NULL) THEN
    RAISE EXCEPTION 'Reward rule scope target mismatch';
  END IF;

  IF p_ends_at IS NOT NULL AND p_starts_at IS NOT NULL AND p_ends_at <= p_starts_at THEN
    RAISE EXCEPTION 'Reward rule end must be after start';
  END IF;

  IF p_id IS NOT NULL THEN
    SELECT to_jsonb(rr)
    INTO v_before
    FROM public.reward_rules rr
    WHERE rr.id = p_id;

    UPDATE public.reward_rules
    SET scope = v_scope,
        country_id = CASE WHEN v_scope = 'country' THEN p_country_id ELSE NULL END,
        venue_id = CASE WHEN v_scope = 'venue' THEN p_venue_id ELSE NULL END,
        welcome_fet_amount = greatest(coalesce(p_welcome_fet_amount, 0), 0),
        order_fet_default_percent = greatest(coalesce(p_order_fet_default_percent, 0), 0),
        pool_creator_reward_per_member = greatest(coalesce(p_pool_creator_reward_per_member, 0), 0),
        min_qualified_stake = greatest(coalesce(p_min_qualified_stake, 0), 0),
        min_qualified_members = greatest(coalesce(p_min_qualified_members, 0), 0),
        is_active = coalesce(p_is_active, true),
        starts_at = p_starts_at,
        ends_at = p_ends_at,
        updated_at = timezone('utc', now())
    WHERE id = p_id
    RETURNING *
    INTO v_rule;
  ELSE
    INSERT INTO public.reward_rules (
      id,
      scope,
      country_id,
      venue_id,
      welcome_fet_amount,
      order_fet_default_percent,
      pool_creator_reward_per_member,
      min_qualified_stake,
      min_qualified_members,
      is_active,
      starts_at,
      ends_at
    )
    VALUES (
      extensions.gen_random_uuid(),
      v_scope,
      CASE WHEN v_scope = 'country' THEN p_country_id ELSE NULL END,
      CASE WHEN v_scope = 'venue' THEN p_venue_id ELSE NULL END,
      greatest(coalesce(p_welcome_fet_amount, 0), 0),
      greatest(coalesce(p_order_fet_default_percent, 0), 0),
      greatest(coalesce(p_pool_creator_reward_per_member, 0), 0),
      greatest(coalesce(p_min_qualified_stake, 0), 0),
      greatest(coalesce(p_min_qualified_members, 0), 0),
      coalesce(p_is_active, true),
      p_starts_at,
      p_ends_at
    )
    RETURNING *
    INTO v_rule;
  END IF;

  IF v_rule.id IS NULL THEN
    RAISE EXCEPTION 'Reward rule not found';
  END IF;

  PERFORM public.admin_control_center_audit(
    'upsert_reward_rule',
    'reward_rules',
    'reward_rule',
    v_rule.id::text,
    v_before,
    to_jsonb(v_rule),
    jsonb_build_object('reason', p_reason, 'scope', v_rule.scope)
  );

  RETURN to_jsonb(v_rule);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_cancel_refund_pool(
  p_pool_id uuid,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_before jsonb;
  v_pool public.match_pools%ROWTYPE;
  v_result jsonb;
BEGIN
  PERFORM public.require_admin_manager_user();

  IF char_length(trim(coalesce(p_reason, ''))) < 8 THEN
    RAISE EXCEPTION 'Pool cancellation requires an audit reason';
  END IF;

  SELECT *
  INTO v_pool
  FROM public.match_pools
  WHERE id = p_pool_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pool not found';
  END IF;

  IF v_pool.status::text = 'settled' THEN
    RAISE EXCEPTION 'Settled pools must be reversed through settlement controls';
  END IF;

  v_before := to_jsonb(v_pool);

  UPDATE public.match_pools
  SET status = 'cancelled',
      metadata = metadata || jsonb_build_object('admin_cancel_reason', p_reason),
      updated_at = timezone('utc', now())
  WHERE id = p_pool_id;

  v_result := public.reverse_or_refund_pool_if_match_cancelled(p_pool_id);

  PERFORM public.admin_control_center_audit(
    'cancel_refund_pool',
    'pools',
    'pool',
    p_pool_id::text,
    v_before,
    v_result,
    jsonb_build_object('reason', p_reason)
  );

  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_retry_pool_settlement(
  p_pool_id uuid,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_result jsonb;
BEGIN
  PERFORM public.require_admin_manager_user();

  IF char_length(trim(coalesce(p_reason, ''))) < 8 THEN
    RAISE EXCEPTION 'Settlement retry requires an audit reason';
  END IF;

  v_result := public.settle_pool(
    p_pool_id,
    'admin-settlement:' || p_pool_id::text
  );

  PERFORM public.admin_control_center_audit(
    'retry_pool_settlement',
    'settlements',
    'pool',
    p_pool_id::text,
    NULL,
    v_result,
    jsonb_build_object('reason', p_reason, 'idempotency_key', 'admin-settlement:' || p_pool_id::text)
  );

  RETURN v_result;
END;
$$;

DROP FUNCTION IF EXISTS public.admin_pool_operations_queue(integer);

CREATE FUNCTION public.admin_pool_operations_queue(p_limit integer DEFAULT 50)
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
  )
  SELECT
    p.id AS pool_id,
    p.title,
    p.scope::text,
    p.country_code,
    p.country_id,
    p.venue_id,
    v.name AS venue_name,
    p.match_id,
    coalesce(m.home_team, 'Home') || ' vs ' || coalesce(m.away_team, 'Away') AS match_label,
    m.competition_name,
    m.match_date AS kickoff_at,
    coalesce(m.match_status, m.status) AS match_status,
    m.result_code,
    p.status::text AS pool_status,
    p.total_members,
    p.total_staked_fet,
    coalesce(ps.camps, '[]'::jsonb) AS camps,
    s.status::text AS settlement_status,
    s.started_at AS settlement_started_at,
    s.completed_at AS settlement_completed_at,
    coalesce(s.error_message, s.metadata ->> 'error') AS settlement_error,
    p.share_url,
    p.social_card_url,
    (
      p.status::text IN ('open', 'locked', 'live', 'settling')
      AND coalesce(m.status, CASE m.match_status WHEN 'finished' THEN 'final' ELSE m.match_status END) = 'final'
      AND m.result_code IS NOT NULL
    ) AS needs_settlement,
    nullif(trim(coalesce(p.social_card_url, '')), '') IS NULL AS needs_social_card,
    floor(extract(epoch FROM (timezone('utc', now()) - p.created_at)) / 60)::bigint AS age_minutes
  FROM public.match_pools p
  LEFT JOIN public.match_pool_stats ps ON ps.id = p.id
  LEFT JOIN public.app_matches m ON m.id = p.match_id
  LEFT JOIN public.venues v ON v.id = p.venue_id
  LEFT JOIN public.match_pool_settlements s ON s.pool_id = p.id
  WHERE
    p.status::text IN ('open', 'locked', 'live', 'settling')
    OR s.status::text = 'failed'
    OR p.created_at >= timezone('utc', now()) - interval '30 days'
  ORDER BY
    CASE
      WHEN s.status::text = 'failed' THEN 0
      WHEN p.status::text = 'settling' THEN 1
      WHEN p.status::text IN ('open', 'locked', 'live') AND coalesce(m.status, CASE m.match_status WHEN 'finished' THEN 'final' ELSE m.match_status END) = 'final' AND m.result_code IS NOT NULL THEN 2
      WHEN nullif(trim(coalesce(p.social_card_url, '')), '') IS NULL THEN 3
      ELSE 4
    END,
    m.match_date NULLS LAST,
    p.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 200));
$$;

CREATE OR REPLACE FUNCTION public.admin_risk_signals(p_limit integer DEFAULT 100)
RETURNS TABLE(
  signal_type text,
  severity text,
  entity_type text,
  entity_id text,
  message text,
  created_at timestamp with time zone,
  metadata jsonb
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
BEGIN
  PERFORM public.require_active_admin_user();

  RETURN QUERY
  SELECT *
  FROM (
    SELECT
      'suspicious_pool_creation'::text AS signal_type,
      'warning'::text AS severity,
      'pool'::text AS entity_type,
      p.id::text AS entity_id,
      'User-created or pending endorsement pool requires review.'::text AS message,
      p.created_at,
      jsonb_build_object(
        'scope', p.scope::text,
        'venue_id', p.venue_id,
        'creator_user_id', p.creator_user_id,
        'endorsement_status', p.metadata ->> 'endorsement_status'
      ) AS metadata
    FROM public.match_pools p
    WHERE p.is_official = false
       OR p.metadata ->> 'endorsement_status' IN ('pending', 'rejected')

    UNION ALL

    SELECT
      'repeated_self_invite'::text,
      'critical'::text,
      'pool_invite'::text,
      i.id::text,
      'Invite creator and invitee are the same user.'::text,
      i.created_at,
      jsonb_build_object('pool_id', i.pool_id, 'user_id', i.inviter_user_id)
    FROM public.match_pool_invites i
    WHERE i.invitee_user_id IS NOT NULL
      AND i.inviter_user_id = i.invitee_user_id

    UNION ALL

    SELECT
      'abnormal_creator_reward'::text,
      'warning'::text,
      'pool'::text,
      p.id::text,
      'Creator reward is unusually high relative to pool stake limits.'::text,
      p.created_at,
      jsonb_build_object(
        'creator_reward_fet', p.creator_reward_fet,
        'stake_max_fet', p.stake_max_fet,
        'total_members', p.total_members
      )
    FROM public.match_pools p
    WHERE p.creator_reward_fet > greatest(p.stake_max_fet, 1000)

    UNION ALL

    SELECT
      'duplicate_account_signal'::text,
      'info'::text,
      'user_cluster'::text,
      md5(coalesce(nullif(trim(u.phone), ''), nullif(lower(trim(u.email)), '')))::text,
      'Multiple auth accounts share the same phone or email fingerprint.'::text,
      max(u.created_at),
      jsonb_build_object('account_count', count(*))
    FROM auth.users u
    WHERE coalesce(nullif(trim(u.phone), ''), nullif(lower(trim(u.email)), '')) IS NOT NULL
    GROUP BY coalesce(nullif(trim(u.phone), ''), nullif(lower(trim(u.email)), ''))
    HAVING count(*) > 1
  ) signals
  ORDER BY
    CASE severity WHEN 'critical' THEN 0 WHEN 'warning' THEN 1 ELSE 2 END,
    created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 100), 500));
END;
$$;

COMMENT ON FUNCTION public.admin_risk_signals(integer)
  IS 'Admin-only generated risk queue for suspicious pool creation, self-invites, abnormal creator rewards, and available duplicate-account signals.';

REVOKE ALL ON FUNCTION public.admin_control_center_audit(text,text,text,text,jsonb,jsonb,jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_upsert_country(uuid,text,text,text,boolean,integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_set_country_active(uuid,boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_update_venue_control(uuid,text,boolean,uuid,text,numeric,boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_update_competition_control(text,boolean,integer,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_update_team_control(text,uuid,integer,boolean,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_upsert_reward_rule(uuid,text,uuid,uuid,bigint,numeric,bigint,bigint,integer,boolean,timestamp with time zone,timestamp with time zone,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_cancel_refund_pool(uuid,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_retry_pool_settlement(uuid,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_pool_operations_queue(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_risk_signals(integer) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.admin_control_center_audit(text,text,text,text,jsonb,jsonb,jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_upsert_country(uuid,text,text,text,boolean,integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_set_country_active(uuid,boolean) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_update_venue_control(uuid,text,boolean,uuid,text,numeric,boolean) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_update_competition_control(text,boolean,integer,text,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_update_team_control(text,uuid,integer,boolean,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_upsert_reward_rule(uuid,text,uuid,uuid,bigint,numeric,bigint,bigint,integer,boolean,timestamp with time zone,timestamp with time zone,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_cancel_refund_pool(uuid,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_retry_pool_settlement(uuid,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_pool_operations_queue(integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_risk_signals(integer) TO authenticated, service_role;
