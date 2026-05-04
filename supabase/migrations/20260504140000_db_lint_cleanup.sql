-- Release-readiness lint cleanup for existing PL/pgSQL helpers.
-- Keeps prediction pools venue-linked while removing avoidable schema lint warnings.

CREATE OR REPLACE FUNCTION public.create_pool(
  p_match_id text,
  p_scope text DEFAULT 'venue'::text,
  p_country_id uuid DEFAULT NULL::uuid,
  p_venue_id uuid DEFAULT NULL::uuid,
  p_title text DEFAULT NULL::text,
  p_stake_min bigint DEFAULT 1,
  p_stake_max bigint DEFAULT 100000,
  p_creator_reward_per_qualified_member bigint DEFAULT NULL::bigint,
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
  v_status public.match_pool_status := 'open'::public.match_pool_status;
  v_venue_features jsonb := '{}'::jsonb;
  v_entry_fee bigint;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_venue_id IS NULL THEN
    RAISE EXCEPTION 'Every prediction pool must be linked to a venue';
  END IF;

  IF p_scope <> 'venue' THEN
    RAISE EXCEPTION 'Prediction pools are venue-linked. Use global/country filters for browsing only.';
  END IF;

  IF p_stake_min < 1 OR p_stake_max < p_stake_min THEN
    RAISE EXCEPTION 'Invalid stake rules';
  END IF;

  v_entry_fee := p_stake_min;

  IF p_rules_json ? 'is_official' THEN
    v_is_official := lower(p_rules_json ->> 'is_official') IN ('true', '1', 'yes', 'on');
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

  SELECT COALESCE(features_json, '{}'::jsonb), country_code, country_id
  INTO v_venue_features, v_country_code, p_country_id
  FROM public.venues
  WHERE id = p_venue_id
    AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active venue not found';
  END IF;

  v_is_venue_manager := public.venue_user_has_role(
    p_venue_id,
    ARRAY['owner', 'manager']::public.venue_user_role[]
  );

  IF v_is_official AND NOT (v_is_admin OR v_is_venue_manager) THEN
    RAISE EXCEPTION 'Only admins or venue managers can create official pools';
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

  v_auto_endorse := v_is_admin
    OR v_is_venue_manager
    OR lower(COALESCE(v_venue_features ->> 'allow_user_pool_auto_endorse', 'false')) IN ('true', '1', 'yes', 'on');

  IF NOT v_auto_endorse AND NOT public.app_config_bool('allow_user_venue_pool_creation', true) THEN
    RAISE EXCEPTION 'Guest-created venue pools are disabled';
  END IF;

  v_status := CASE WHEN v_auto_endorse THEN 'open'::public.match_pool_status ELSE 'draft'::public.match_pool_status END;
  v_endorsement_status := CASE WHEN v_auto_endorse THEN 'endorsed' ELSE 'pending' END;
  v_is_official := v_is_official AND (v_is_admin OR v_is_venue_manager);

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
    'venue'::public.match_pool_scope,
    v_country_code,
    p_country_id,
    p_venue_id,
    v_user_id,
    COALESCE(NULLIF(trim(p_title), ''), COALESCE(v_home_team, 'Home') || ' vs ' || COALESCE(v_away_team, 'Away')),
    v_status,
    v_is_official,
    v_entry_fee,
    p_stake_min,
    p_stake_max,
    GREATEST(COALESCE(p_creator_reward_per_qualified_member, 0), 0),
    COALESCE(p_rules_json, '{}'::jsonb)
      || jsonb_build_object(
        'visibility', v_visibility,
        'allow_multiple', p_allow_multiple,
        'pool_only_gameplay', true,
        'eligibility_window_minutes', 120
      ),
    p_allow_multiple,
    jsonb_build_object(
      'visibility', v_visibility,
      'venue_endorsement_status', v_endorsement_status,
      'created_via', 'create_pool',
      'pool_only_gameplay', true,
      'eligibility_window_minutes', 120
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
    RAISE;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_match_pool(
  p_match_id text,
  p_scope public.match_pool_scope DEFAULT 'venue'::public.match_pool_scope,
  p_country_code text DEFAULT NULL::text,
  p_venue_id uuid DEFAULT NULL::uuid,
  p_title text DEFAULT NULL::text,
  p_entry_fee_fet bigint DEFAULT 1,
  p_stake_min_fet bigint DEFAULT 1,
  p_stake_max_fet bigint DEFAULT 100000,
  p_is_official boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
BEGIN
  IF p_venue_id IS NULL THEN
    RAISE EXCEPTION 'Every prediction pool must be linked to a venue';
  END IF;

  IF p_scope <> 'venue'::public.match_pool_scope THEN
    RAISE EXCEPTION 'Prediction pools are venue-linked. Use global/country filters for browsing only.';
  END IF;

  RETURN public.create_pool(
    p_match_id => p_match_id,
    p_scope => 'venue',
    p_country_id => NULL,
    p_venue_id => p_venue_id,
    p_title => p_title,
    p_stake_min => GREATEST(COALESCE(NULLIF(p_entry_fee_fet, 0), p_stake_min_fet), 1),
    p_stake_max => GREATEST(COALESCE(p_stake_max_fet, 1), GREATEST(COALESCE(NULLIF(p_entry_fee_fet, 0), p_stake_min_fet), 1)),
    p_creator_reward_per_qualified_member => NULL,
    p_rules_json => jsonb_build_object(
      'is_official', p_is_official,
      'legacy_country_code', p_country_code,
      'legacy_entry_fee_fet', p_entry_fee_fet
    ),
    p_allow_multiple => false
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.join_match_pool(
  p_pool_id uuid,
  p_camp_id uuid,
  p_amount_fet bigint DEFAULT NULL::bigint,
  p_invite_code text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_pool public.match_pools%ROWTYPE;
  v_invite public.match_pool_invites%ROWTYPE;
  v_entry public.match_pool_entries%ROWTYPE;
  v_amount bigint;
  v_min_qualified_stake bigint;
  v_reward_amount bigint := 0;
  v_reward_result jsonb := '{}'::jsonb;
  v_reward_tx_id uuid;
  v_invite_valid boolean := false;
  v_reward_eligible boolean := false;
  v_start_at timestamptz;
  v_eligible_now boolean := false;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_pool
  FROM public.match_pools
  WHERE id = p_pool_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pool not found';
  END IF;

  IF v_pool.venue_id IS NULL THEN
    RAISE EXCEPTION 'Pool is missing linked venue';
  END IF;

  SELECT public.pool_scheduled_start(p_pool_id) INTO v_start_at;

  IF v_pool.status <> 'open' THEN
    RAISE EXCEPTION 'Pool is not open for entries';
  END IF;

  IF v_start_at IS NOT NULL AND timezone('utc', now()) >= v_start_at THEN
    RAISE EXCEPTION 'Pool joining deadline has passed';
  END IF;

  PERFORM 1
  FROM public.match_pool_camps
  WHERE id = p_camp_id
    AND pool_id = p_pool_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pool camp not found';
  END IF;

  v_amount := COALESCE(p_amount_fet, NULLIF(v_pool.entry_fee_fet, 0), v_pool.stake_min_fet, 1);
  IF v_amount < v_pool.stake_min_fet OR v_amount > v_pool.stake_max_fet THEN
    RAISE EXCEPTION 'Stake amount is outside pool limits';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.match_pool_entries
    WHERE pool_id = p_pool_id
      AND user_id = v_user_id
      AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'User has already joined this pool';
  END IF;

  v_eligible_now := public.user_has_qualifying_order(v_user_id, v_pool.venue_id, v_start_at);

  v_min_qualified_stake := COALESCE(
    CASE
      WHEN COALESCE(v_pool.creator_reward_rules ->> 'min_qualified_stake', '') ~ '^[0-9]+$'
        THEN (v_pool.creator_reward_rules ->> 'min_qualified_stake')::bigint
      ELSE NULL
    END,
    CASE
      WHEN COALESCE(v_pool.rules_json ->> 'min_qualified_stake', '') ~ '^[0-9]+$'
        THEN (v_pool.rules_json ->> 'min_qualified_stake')::bigint
      ELSE NULL
    END,
    public.app_config_bigint('pool_creator_reward_min_qualified_stake', v_pool.stake_min_fet),
    v_pool.stake_min_fet,
    1
  );

  IF p_invite_code IS NOT NULL THEN
    SELECT * INTO v_invite
    FROM public.match_pool_invites
    WHERE pool_id = p_pool_id
      AND invite_code = p_invite_code
    FOR UPDATE;

    v_invite_valid := FOUND
      AND v_invite.status = 'created'
      AND (v_invite.expires_at IS NULL OR v_invite.expires_at > timezone('utc', now()));
  END IF;

  PERFORM public.wallet_post_transaction(
    p_user_id => v_user_id,
    p_transaction_type => 'pool_stake',
    p_direction => 'debit',
    p_amount_fet => v_amount,
    p_balance_bucket => 'available',
    p_idempotency_key => 'pool_stake_available:' || p_pool_id::text || ':' || v_user_id::text,
    p_reference_type => 'match_pool_entry',
    p_reference_id => p_pool_id::text,
    p_title => 'Pool stake',
    p_match_id => v_pool.match_id,
    p_pool_id => p_pool_id,
    p_venue_id => v_pool.venue_id
  );

  INSERT INTO public.match_pool_entries (
    pool_id,
    camp_id,
    user_id,
    amount_fet,
    source,
    invited_by_user_id,
    metadata
  )
  VALUES (
    p_pool_id,
    p_camp_id,
    v_user_id,
    v_amount,
    CASE WHEN v_invite_valid THEN 'invite_link' ELSE 'direct' END,
    CASE WHEN v_invite_valid AND v_invite.inviter_user_id IS DISTINCT FROM v_user_id THEN v_invite.inviter_user_id ELSE NULL END,
    jsonb_build_object(
      'invite_code', p_invite_code,
      'invite_valid', v_invite_valid,
      'min_qualified_stake', v_min_qualified_stake,
      'eligibility_status', CASE WHEN v_eligible_now THEN 'order_placed_eligible' ELSE 'joined_order_required' END,
      'eligibility_checked_at', timezone('utc', now()),
      'eligibility_start_at', v_start_at
    )
  )
  RETURNING * INTO v_entry;

  PERFORM public.wallet_post_transaction(
    p_user_id => v_user_id,
    p_transaction_type => 'pool_stake',
    p_direction => 'credit',
    p_amount_fet => v_amount,
    p_balance_bucket => 'staked',
    p_idempotency_key => 'pool_stake_locked:' || v_entry.id::text,
    p_reference_type => 'match_pool_entry',
    p_reference_id => v_entry.id::text,
    p_title => 'Pool stake locked',
    p_match_id => v_pool.match_id,
    p_pool_id => p_pool_id,
    p_entry_id => v_entry.id,
    p_venue_id => v_pool.venue_id
  );

  UPDATE public.match_pool_camps
  SET member_count = member_count + 1,
      total_staked_fet = total_staked_fet + v_amount,
      updated_at = timezone('utc', now())
  WHERE id = p_camp_id;

  UPDATE public.match_pools
  SET total_members = total_members + 1,
      total_staked_fet = total_staked_fet + v_amount,
      metadata = COALESCE(metadata, '{}'::jsonb)
        || jsonb_build_object(
          'social_card',
          COALESCE(metadata -> 'social_card', '{}'::jsonb)
            || jsonb_build_object(
              'needs_regeneration', true,
              'stats_updated_at', timezone('utc', now())
            )
        ),
      updated_at = timezone('utc', now())
  WHERE id = p_pool_id;

  v_reward_eligible := v_invite_valid
    AND v_invite.inviter_user_id IS DISTINCT FROM v_user_id
    AND v_invite.inviter_user_id = v_pool.creator_user_id
    AND COALESCE(v_pool.creator_reward_fet, 0) > 0
    AND v_amount >= v_min_qualified_stake
    AND NOT EXISTS (
      SELECT 1
      FROM public.match_pool_invites existing
      WHERE existing.pool_id = p_pool_id
        AND existing.invitee_user_id = v_user_id
        AND existing.status = 'rewarded'
    )
    AND NOT EXISTS (
      SELECT 1
      FROM public.fet_wallet_transactions tx
      WHERE tx.pool_id = p_pool_id
        AND tx.user_id = v_invite.inviter_user_id
        AND tx.transaction_type = 'creator_reward'
        AND tx.metadata ->> 'invitee_user_id' = v_user_id::text
    );

  IF v_reward_eligible THEN
    v_reward_amount := GREATEST(
      COALESCE(v_pool.creator_reward_fet, public.app_config_bigint('pool_creator_reward_fet_default', 1), 1),
      0
    );

    IF v_reward_amount > 0 THEN
      v_reward_result := public.wallet_post_transaction(
        p_user_id => v_invite.inviter_user_id,
        p_transaction_type => 'creator_reward',
        p_direction => 'credit',
        p_amount_fet => v_reward_amount,
        p_balance_bucket => 'available',
        p_idempotency_key => 'creator_reward:' || p_pool_id::text || ':' || v_user_id::text,
        p_reference_type => 'match_pool_invite',
        p_reference_id => v_invite.id::text,
        p_title => 'Pool creator reward',
        p_metadata => jsonb_build_object(
          'invite_id', v_invite.id,
          'entry_id', v_entry.id,
          'invitee_user_id', v_user_id,
          'qualified', true,
          'min_qualified_stake', v_min_qualified_stake,
          'stake_amount_fet', v_amount
        ),
        p_match_id => v_pool.match_id,
        p_pool_id => p_pool_id,
        p_entry_id => v_entry.id,
        p_venue_id => v_pool.venue_id
      );
      v_reward_tx_id := (v_reward_result ->> 'transaction_id')::uuid;
    END IF;

    UPDATE public.match_pool_invites
    SET invitee_user_id = v_user_id,
        joined_entry_id = v_entry.id,
        status = 'rewarded',
        reward_tx_id = v_reward_tx_id,
        reward_amount_fet = v_reward_amount,
        joined_at = timezone('utc', now()),
        rewarded_at = timezone('utc', now()),
        updated_at = timezone('utc', now()),
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object('reward_qualified', true)
    WHERE id = v_invite.id;
  ELSIF v_invite_valid THEN
    UPDATE public.match_pool_invites
    SET invitee_user_id = v_user_id,
        joined_entry_id = v_entry.id,
        status = 'joined',
        reward_amount_fet = 0,
        joined_at = timezone('utc', now()),
        updated_at = timezone('utc', now()),
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
          'reward_qualified', false,
          'stake_amount_fet', v_amount,
          'min_qualified_stake', v_min_qualified_stake,
          'self_invite', v_invite.inviter_user_id = v_user_id
        )
    WHERE id = v_invite.id;
  END IF;

  RETURN jsonb_build_object(
    'status', 'joined',
    'entry_id', v_entry.id,
    'pool_id', p_pool_id,
    'creator_reward_tx_id', v_reward_tx_id,
    'creator_reward_amount_fet', v_reward_amount,
    'eligibility_status', CASE WHEN v_eligible_now THEN 'order_placed_eligible' ELSE 'joined_order_required' END
  );
END;
$$;

ALTER FUNCTION public.season_start_year(text) STABLE;
ALTER FUNCTION public.season_end_year(text) STABLE;

REVOKE ALL ON FUNCTION public.venue_settle_game_session(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.venue_settle_game_session(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.user_submit_order_payment(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.user_submit_order_payment(uuid, text, text, text) TO authenticated, service_role;
