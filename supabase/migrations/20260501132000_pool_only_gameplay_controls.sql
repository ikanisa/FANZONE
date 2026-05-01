-- ============================================================================
-- Pool-only gameplay controls
--
-- Additive layer over the clean sports-bar baseline:
--   - pools are the only game mechanic;
--   - create_pool supports official admin pools and user shareable pools;
--   - venue-linked user pools wait for endorsement unless venue rules allow it;
--   - my-pools RPC gives clients a single wallet-backed participation surface.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.app_config_bool(
  p_key text,
  p_default boolean DEFAULT false
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_value jsonb;
  v_text text;
BEGIN
  SELECT value
  INTO v_value
  FROM public.app_config_remote
  WHERE key = p_key
  LIMIT 1;

  IF v_value IS NULL OR v_value = 'null'::jsonb THEN
    RETURN p_default;
  END IF;

  IF jsonb_typeof(v_value) = 'boolean' THEN
    RETURN (v_value::text)::boolean;
  END IF;

  v_text := lower(trim(both '"' from v_value::text));
  IF v_text IN ('true', '1', 'yes', 'on') THEN
    RETURN true;
  ELSIF v_text IN ('false', '0', 'no', 'off') THEN
    RETURN false;
  END IF;

  RETURN p_default;
END;
$$;

CREATE OR REPLACE FUNCTION public.pool_state_transition_allowed(
  p_from public.match_pool_status,
  p_to public.match_pool_status
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE p_from
    WHEN 'draft' THEN p_to IN ('open', 'cancelled')
    WHEN 'open' THEN p_to IN ('locked', 'live', 'cancelled')
    WHEN 'locked' THEN p_to IN ('live', 'settling', 'cancelled')
    WHEN 'live' THEN p_to IN ('settling', 'cancelled')
    WHEN 'settling' THEN p_to IN ('settled', 'cancelled')
    ELSE false
  END;
$$;

COMMENT ON FUNCTION public.pool_state_transition_allowed(public.match_pool_status, public.match_pool_status)
  IS 'Canonical pool state machine: draft -> open -> locked/live -> settling -> settled, with cancellation before settlement.';

CREATE OR REPLACE VIEW public.match_pool_stats AS
SELECT
  p.id,
  p.match_id,
  p.scope,
  p.country_code,
  p.venue_id,
  p.creator_user_id,
  p.title,
  p.status,
  p.is_official,
  p.entry_fee_fet,
  p.stake_min_fet,
  p.stake_max_fet,
  p.total_members,
  p.total_staked_fet,
  p.share_slug,
  p.share_url,
  p.social_card_url,
  p.result_camp_id,
  p.created_at,
  p.updated_at,
  COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', c.id,
        'code', c.code,
        'camp_key', COALESCE(c.camp_key, c.code),
        'label', c.label,
        'result_code', c.result_code,
        'team_id', c.team_id,
        'member_count', c.member_count,
        'total_staked_fet', c.total_staked_fet,
        'is_winning_camp', c.is_winning_camp,
        'display_order', c.display_order
      )
      ORDER BY c.display_order, c.created_at
    ) FILTER (WHERE c.id IS NOT NULL),
    '[]'::jsonb
  ) AS camps,
  p.country_id,
  p.creator_reward_fet,
  p.locked_at,
  p.settled_at,
  p.rules_json,
  p.metadata
FROM public.match_pools p
LEFT JOIN public.match_pool_camps c ON c.pool_id = p.id
GROUP BY p.id;

CREATE OR REPLACE FUNCTION public.create_pool(
  p_match_id text,
  p_scope text DEFAULT 'global',
  p_country_id uuid DEFAULT NULL,
  p_venue_id uuid DEFAULT NULL,
  p_title text DEFAULT NULL,
  p_stake_min bigint DEFAULT 1,
  p_stake_max bigint DEFAULT 100000,
  p_creator_reward_per_qualified_member bigint DEFAULT NULL,
  p_rules_json jsonb DEFAULT '{}'::jsonb,
  p_allow_multiple boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_match public.matches%ROWTYPE;
  v_pool public.match_pools%ROWTYPE;
  v_existing public.match_pools%ROWTYPE;
  v_home_team text := 'Home';
  v_away_team text := 'Away';
  v_country_code text;
  v_is_admin boolean := public.sports_bar_is_admin();
  v_is_venue_manager boolean := false;
  v_is_official boolean := v_is_admin;
  v_visibility text := lower(coalesce(nullif(p_rules_json ->> 'visibility', ''), 'shareable'));
  v_endorsement_status text := 'not_required';
  v_auto_endorse boolean := false;
  v_status public.match_pool_status := 'open';
  v_venue_features jsonb := '{}'::jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_scope NOT IN ('global', 'country', 'venue') THEN
    RAISE EXCEPTION 'Invalid pool scope';
  END IF;

  IF p_stake_min < 1 OR p_stake_max < p_stake_min THEN
    RAISE EXCEPTION 'Invalid stake rules';
  END IF;

  IF p_rules_json ? 'is_official' THEN
    v_is_official := lower(p_rules_json ->> 'is_official') IN ('true', '1', 'yes', 'on');
  END IF;

  IF v_is_official AND NOT v_is_admin THEN
    IF p_scope <> 'venue'
       OR p_venue_id IS NULL
       OR NOT public.venue_user_has_role(p_venue_id, ARRAY['owner', 'manager']::public.venue_user_role[]) THEN
      RAISE EXCEPTION 'Only admins or venue managers can create official pools';
    END IF;
  END IF;

  SELECT *
  INTO v_match
  FROM public.matches
  WHERE id = p_match_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match not found';
  END IF;

  IF COALESCE(v_match.status, CASE v_match.match_status WHEN 'finished' THEN 'final' ELSE v_match.match_status END) NOT IN ('scheduled', 'live') THEN
    RAISE EXCEPTION 'Pools can only be created for scheduled or live curated matches';
  END IF;

  IF COALESCE(v_match.starts_at, v_match.match_date) IS NOT NULL
     AND COALESCE(v_match.starts_at, v_match.match_date) <= timezone('utc', now()) THEN
    RAISE EXCEPTION 'Pool cannot be created after match start';
  END IF;

  SELECT home_team, away_team
  INTO v_home_team, v_away_team
  FROM public.app_matches
  WHERE id = p_match_id;

  IF p_country_id IS NOT NULL THEN
    SELECT iso_code
    INTO v_country_code
    FROM public.countries
    WHERE id = p_country_id
      AND is_active = true;

    IF v_country_code IS NULL THEN
      RAISE EXCEPTION 'Active country not found';
    END IF;
  END IF;

  IF p_scope = 'global' THEN
    IF v_is_official AND NOT v_is_admin THEN
      RAISE EXCEPTION 'Only admins can create official global pools';
    END IF;
    IF NOT v_is_official AND NOT public.app_config_bool('allow_shareable_user_pools', true) THEN
      RAISE EXCEPTION 'Shareable user pools are disabled';
    END IF;
    p_country_id := NULL;
    v_country_code := NULL;
    p_venue_id := NULL;
  ELSIF p_scope = 'country' THEN
    IF p_country_id IS NULL OR v_country_code IS NULL THEN
      RAISE EXCEPTION 'Country pool requires an active country';
    END IF;
    IF NOT v_is_admin AND NOT public.app_config_bool('allow_country_user_pools', false) THEN
      RAISE EXCEPTION 'Only admins can create country pools';
    END IF;
    p_venue_id := NULL;
  ELSIF p_scope = 'venue' THEN
    IF p_venue_id IS NULL THEN
      RAISE EXCEPTION 'Venue pool requires a venue';
    END IF;

    SELECT COALESCE(features_json, '{}'::jsonb)
    INTO v_venue_features
    FROM public.venues
    WHERE id = p_venue_id
      AND is_active = true;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Active venue not found';
    END IF;

    SELECT *
    INTO v_existing
    FROM public.match_pools
    WHERE match_id = p_match_id
      AND venue_id = p_venue_id
      AND scope = 'venue'
      AND status <> 'cancelled'
      AND allow_multiple = false
    ORDER BY is_official DESC, created_at
    LIMIT 1;

    IF FOUND THEN
      RETURN jsonb_build_object(
        'status', 'existing_pool',
        'pool_id', v_existing.id,
        'match_id', v_existing.match_id,
        'scope', v_existing.scope,
        'venue_id', v_existing.venue_id,
        'share_url', v_existing.share_url,
        'endorsement_status', COALESCE(v_existing.metadata ->> 'venue_endorsement_status', 'endorsed')
      );
    END IF;

    v_is_venue_manager := public.venue_user_has_role(
      p_venue_id,
      ARRAY['owner', 'manager']::public.venue_user_role[]
    );
    v_auto_endorse := v_is_admin
      OR v_is_venue_manager
      OR lower(COALESCE(v_venue_features ->> 'allow_user_pool_auto_endorse', 'false')) IN ('true', '1', 'yes', 'on');

    IF NOT v_auto_endorse AND NOT public.app_config_bool('allow_user_venue_pool_creation', true) THEN
      RAISE EXCEPTION 'Guest-created venue pools are disabled';
    END IF;

    v_status := CASE WHEN v_auto_endorse THEN 'open'::public.match_pool_status ELSE 'draft'::public.match_pool_status END;
    v_endorsement_status := CASE WHEN v_auto_endorse THEN 'endorsed' ELSE 'pending' END;
    v_is_official := v_is_official AND (v_is_admin OR v_is_venue_manager);
  END IF;

  INSERT INTO public.match_pools (
    match_id,
    scope,
    country_code,
    country_id,
    venue_id,
    creator_user_id,
    title,
    status,
    is_official,
    entry_fee_fet,
    stake_min_fet,
    stake_max_fet,
    creator_reward_fet,
    rules_json,
    allow_multiple,
    metadata
  )
  VALUES (
    p_match_id,
    p_scope::public.match_pool_scope,
    v_country_code,
    p_country_id,
    p_venue_id,
    v_user_id,
    COALESCE(NULLIF(trim(p_title), ''), COALESCE(v_home_team, 'Home') || ' vs ' || COALESCE(v_away_team, 'Away')),
    v_status,
    v_is_official,
    0,
    p_stake_min,
    p_stake_max,
    GREATEST(COALESCE(p_creator_reward_per_qualified_member, 0), 0),
    COALESCE(p_rules_json, '{}'::jsonb)
      || jsonb_build_object(
        'visibility', v_visibility,
        'allow_multiple', p_allow_multiple,
        'pool_only_gameplay', true
      ),
    p_allow_multiple,
    jsonb_build_object(
      'visibility', v_visibility,
      'venue_endorsement_status', v_endorsement_status,
      'created_via', 'create_pool',
      'pool_only_gameplay', true
    )
  )
  RETURNING * INTO v_pool;

  UPDATE public.match_pools
  SET share_url = '/pools/' || v_pool.share_slug
  WHERE id = v_pool.id
  RETURNING * INTO v_pool;

  INSERT INTO public.match_pool_camps (pool_id, code, camp_key, label, result_code, display_order)
  VALUES
    (v_pool.id, 'home', 'home', COALESCE(v_home_team, 'Home'), 'H', 10),
    (v_pool.id, 'draw', 'draw', 'Draw', 'D', 20),
    (v_pool.id, 'away', 'away', COALESCE(v_away_team, 'Away'), 'A', 30);

  PERFORM public.sports_bar_write_audit(
    'create_pool',
    'pool',
    v_pool.id::text,
    NULL,
    to_jsonb(v_pool)
  );

  RETURN jsonb_build_object(
    'status', 'created',
    'pool_id', v_pool.id,
    'match_id', v_pool.match_id,
    'scope', v_pool.scope,
    'venue_id', v_pool.venue_id,
    'share_url', v_pool.share_url,
    'endorsement_status', v_endorsement_status
  );
EXCEPTION
  WHEN unique_violation THEN
    IF p_scope = 'venue' AND p_venue_id IS NOT NULL THEN
      SELECT *
      INTO v_existing
      FROM public.match_pools
      WHERE match_id = p_match_id
        AND venue_id = p_venue_id
        AND scope = 'venue'
        AND status <> 'cancelled'
      ORDER BY is_official DESC, created_at
      LIMIT 1;

      IF FOUND THEN
        RETURN jsonb_build_object(
          'status', 'existing_pool',
          'pool_id', v_existing.id,
          'match_id', v_existing.match_id,
          'scope', v_existing.scope,
          'venue_id', v_existing.venue_id,
          'share_url', v_existing.share_url,
          'endorsement_status', COALESCE(v_existing.metadata ->> 'venue_endorsement_status', 'endorsed')
        );
      END IF;
    END IF;
    RAISE;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_pools(p_limit integer DEFAULT 50)
RETURNS TABLE(
  entry_id uuid,
  pool_id uuid,
  camp_id uuid,
  match_id text,
  match_label text,
  competition_name text,
  kickoff_at timestamptz,
  pool_title text,
  pool_scope text,
  pool_status text,
  camp_label text,
  stake_amount bigint,
  entry_status text,
  payout_fet bigint,
  total_members bigint,
  total_staked_fet bigint,
  result_camp_id uuid,
  share_url text,
  social_card_url text,
  created_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT
    e.id AS entry_id,
    p.id AS pool_id,
    e.camp_id,
    p.match_id,
    COALESCE(am.home_team, 'Home') || ' vs ' || COALESCE(am.away_team, 'Away') AS match_label,
    am.competition_name,
    am.match_date AS kickoff_at,
    p.title AS pool_title,
    p.scope::text AS pool_scope,
    p.status::text AS pool_status,
    c.label AS camp_label,
    e.amount_fet AS stake_amount,
    e.status::text AS entry_status,
    e.payout_fet,
    p.total_members,
    p.total_staked_fet,
    p.result_camp_id,
    p.share_url,
    p.social_card_url,
    e.created_at
  FROM public.match_pool_entries e
  JOIN public.match_pools p ON p.id = e.pool_id
  JOIN public.match_pool_camps c ON c.id = e.camp_id
  LEFT JOIN public.app_matches am ON am.id = p.match_id
  WHERE e.user_id = auth.uid()
  ORDER BY e.created_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
$$;

CREATE OR REPLACE FUNCTION public.venue_endorse_pool(
  p_pool_id uuid,
  p_venue_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_before jsonb;
  v_after jsonb;
BEGIN
  IF NOT public.venue_user_has_role(p_venue_id, ARRAY['owner', 'manager']::public.venue_user_role[]) THEN
    RAISE EXCEPTION 'Only venue managers can endorse pools';
  END IF;

  SELECT to_jsonb(p)
  INTO v_before
  FROM public.match_pools p
  WHERE p.id = p_pool_id
    AND p.venue_id = p_venue_id
  FOR UPDATE;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Venue pool not found';
  END IF;

  UPDATE public.match_pools
  SET scope = 'venue',
      status = CASE WHEN status = 'draft' THEN 'open'::public.match_pool_status ELSE status END,
      metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
        'venue_endorsement_status', 'endorsed',
        'endorsed_by_venue_id', p_venue_id,
        'endorsed_at', timezone('utc', now())
      ),
      updated_at = timezone('utc', now())
  WHERE id = p_pool_id
  RETURNING to_jsonb(match_pools.*) INTO v_after;

  PERFORM public.sports_bar_write_audit('venue_endorse_pool', 'pool', p_pool_id::text, v_before, v_after);

  RETURN jsonb_build_object('status', 'endorsed', 'pool_id', p_pool_id, 'venue_id', p_venue_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.venue_reject_pool(
  p_pool_id uuid,
  p_venue_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_before jsonb;
  v_after jsonb;
BEGIN
  IF NOT public.venue_user_has_role(p_venue_id, ARRAY['owner', 'manager']::public.venue_user_role[]) THEN
    RAISE EXCEPTION 'Only venue managers can reject pools';
  END IF;

  SELECT to_jsonb(p)
  INTO v_before
  FROM public.match_pools p
  WHERE p.id = p_pool_id
    AND p.venue_id = p_venue_id
  FOR UPDATE;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Venue pool not found';
  END IF;

  UPDATE public.match_pools
  SET status = 'cancelled',
      metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
        'venue_endorsement_status', 'rejected',
        'rejected_by_venue_id', p_venue_id,
        'rejected_at', timezone('utc', now()),
        'rejection_reason', COALESCE(p_reason, '')
      ),
      updated_at = timezone('utc', now())
  WHERE id = p_pool_id
  RETURNING to_jsonb(match_pools.*) INTO v_after;

  PERFORM public.sports_bar_write_audit('venue_reject_pool', 'pool', p_pool_id::text, v_before, v_after);

  RETURN jsonb_build_object('status', 'rejected', 'pool_id', p_pool_id, 'venue_id', p_venue_id);
END;
$$;

COMMENT ON FUNCTION public.create_pool(text, text, uuid, uuid, text, bigint, bigint, bigint, jsonb, boolean)
  IS 'Pool-only game creation. Creates official pools for admins/venue managers and shareable user pools.';
COMMENT ON FUNCTION public.get_my_pools(integer)
  IS 'Wallet-backed pool participation history for the current user.';
COMMENT ON FUNCTION public.venue_reject_pool(uuid, uuid, text)
  IS 'Venue manager control for rejecting pending venue-linked user pools.';

GRANT EXECUTE ON FUNCTION public.app_config_bool(text, boolean) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pool_state_transition_allowed(public.match_pool_status, public.match_pool_status) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_pool(text, text, uuid, uuid, text, bigint, bigint, bigint, jsonb, boolean) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_my_pools(integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.venue_endorse_pool(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.venue_reject_pool(uuid, uuid, text) TO authenticated, service_role;
