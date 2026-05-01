-- Complete pool sharing: safe public resolution tracking, curated match payloads,
-- cached backend social cards, and creator reward abuse hardening.

CREATE TABLE IF NOT EXISTS public.match_pool_share_events (
  id uuid DEFAULT extensions.gen_random_uuid() PRIMARY KEY,
  pool_id uuid NOT NULL REFERENCES public.match_pools(id) ON DELETE CASCADE,
  invite_id uuid REFERENCES public.match_pool_invites(id) ON DELETE SET NULL,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  source text DEFAULT 'direct' NOT NULL,
  share_slug text,
  venue_id uuid REFERENCES public.venues(id) ON DELETE SET NULL,
  country_code text,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc', now()) NOT NULL,
  CONSTRAINT match_pool_share_events_source_check CHECK (
    source = ANY (ARRAY['direct', 'invite_link', 'venue_qr', 'social_share', 'web_fallback', 'deep_link'])
  ),
  CONSTRAINT match_pool_share_events_country_code_check CHECK (
    country_code IS NULL OR country_code ~ '^[A-Z]{2}$'
  )
);

CREATE INDEX IF NOT EXISTS match_pool_share_events_pool_idx
  ON public.match_pool_share_events (pool_id, created_at DESC);

CREATE INDEX IF NOT EXISTS match_pool_share_events_source_idx
  ON public.match_pool_share_events (source, created_at DESC);

ALTER TABLE public.match_pool_share_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS match_pool_share_events_admin_read ON public.match_pool_share_events;
CREATE POLICY match_pool_share_events_admin_read
ON public.match_pool_share_events
FOR SELECT
TO authenticated
USING (public.is_admin_manager((SELECT auth.uid())));

COMMENT ON TABLE public.match_pool_share_events IS
  'Privacy-safe pool share open tracking. Stores source, pool, optional signed-in user, and invite presence; no IP or raw user-agent is stored.';

CREATE OR REPLACE FUNCTION public.get_public_pool_share(
  p_slug_or_pool_id text,
  p_invite_code text DEFAULT NULL,
  p_source text DEFAULT 'direct'
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_lookup text := trim(COALESCE(p_slug_or_pool_id, ''));
  v_invite_code text := NULLIF(trim(COALESCE(p_invite_code, '')), '');
  v_source text := lower(NULLIF(trim(COALESCE(p_source, 'direct')), ''));
  v_pool public.match_pools%ROWTYPE;
  v_invite public.match_pool_invites%ROWTYPE;
  v_match jsonb := '{}'::jsonb;
  v_venue jsonb := NULL;
  v_country jsonb := NULL;
  v_invite_payload jsonb := NULL;
  v_join_url text;
  v_deep_link_url text;
  v_event_id uuid;
BEGIN
  IF v_lookup = '' THEN
    RAISE EXCEPTION 'Pool share slug is required';
  END IF;

  IF COALESCE(v_source, 'direct') NOT IN ('direct', 'invite_link', 'venue_qr', 'social_share', 'web_fallback', 'deep_link') THEN
    RAISE EXCEPTION 'Invalid pool invite source';
  END IF;

  IF v_lookup ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    SELECT *
    INTO v_pool
    FROM public.match_pools
    WHERE id = v_lookup::uuid
      AND status IN ('open', 'locked', 'live', 'settling', 'settled')
    LIMIT 1;
  ELSE
    SELECT *
    INTO v_pool
    FROM public.match_pools
    WHERE share_slug = lower(v_lookup)
      AND status IN ('open', 'locked', 'live', 'settling', 'settled')
    LIMIT 1;
  END IF;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pool not found';
  END IF;

  IF v_invite_code IS NOT NULL THEN
    SELECT *
    INTO v_invite
    FROM public.match_pool_invites
    WHERE invite_code = v_invite_code
      AND pool_id = v_pool.id
    LIMIT 1;

    IF FOUND
       AND v_invite.status = 'created'
       AND (v_invite.expires_at IS NULL OR v_invite.expires_at > timezone('utc', now())) THEN
      v_source := 'invite_link';
      v_invite_payload := jsonb_build_object(
        'code', v_invite.invite_code,
        'valid', true,
        'creator_reward_available',
          v_pool.creator_user_id = v_invite.inviter_user_id
          AND v_invite.inviter_user_id IS DISTINCT FROM auth.uid()
          AND COALESCE(v_pool.creator_reward_fet, 0) > 0
      );
    ELSE
      v_invite_payload := jsonb_build_object('code', v_invite_code, 'valid', false);
    END IF;
  END IF;

  SELECT jsonb_build_object(
    'id', m.id,
    'home_team', m.home_team,
    'away_team', m.away_team,
    'competition', m.competition_name,
    'date', m.match_date,
    'status', m.status,
    'score', CASE
      WHEN m.ft_home IS NOT NULL AND m.ft_away IS NOT NULL
        THEN m.ft_home::text || '-' || m.ft_away::text
      ELSE NULL
    END
  )
  INTO v_match
  FROM public.curated_active_matches m
  WHERE m.id = v_pool.match_id
  ORDER BY m.priority_score DESC, m.curation_id
  LIMIT 1;

  IF v_match IS NULL OR v_match = '{}'::jsonb THEN
    SELECT jsonb_build_object(
      'id', m.id,
      'home_team', m.home_team,
      'away_team', m.away_team,
      'competition', m.competition_name,
      'date', m.match_date,
      'status', CASE WHEN m.status = 'finished' THEN 'final' ELSE m.status END,
      'score', CASE
        WHEN m.ft_home IS NOT NULL AND m.ft_away IS NOT NULL
          THEN m.ft_home::text || '-' || m.ft_away::text
        ELSE NULL
      END
    )
    INTO v_match
    FROM public.app_matches m
    WHERE m.id = v_pool.match_id
    LIMIT 1;
  END IF;

  IF v_pool.venue_id IS NOT NULL THEN
    SELECT jsonb_build_object(
      'id', v.id,
      'name', v.name,
      'slug', v.slug,
      'country_code', v.country_code
    )
    INTO v_venue
    FROM public.venues v
    WHERE v.id = v_pool.venue_id;
  END IF;

  IF v_pool.country_id IS NOT NULL OR v_pool.country_code IS NOT NULL THEN
    SELECT jsonb_build_object(
      'id', c.id,
      'name', c.name,
      'iso_code', c.iso_code
    )
    INTO v_country
    FROM public.countries c
    WHERE (v_pool.country_id IS NOT NULL AND c.id = v_pool.country_id)
       OR (v_pool.country_id IS NULL AND c.iso_code = v_pool.country_code)
    ORDER BY CASE WHEN v_pool.country_id IS NOT NULL AND c.id = v_pool.country_id THEN 0 ELSE 1 END
    LIMIT 1;
  END IF;

  v_join_url := COALESCE(v_pool.share_url, '/pools/' || v_pool.share_slug);
  v_deep_link_url := COALESCE(v_pool.deep_link_url, 'fanzone://pools/' || v_pool.share_slug);

  IF v_invite_code IS NOT NULL THEN
    v_join_url := v_join_url || '?invite=' || v_invite_code || '&source=' || v_source;
    v_deep_link_url := v_deep_link_url || '?invite=' || v_invite_code || '&source=' || v_source;
  ELSIF v_source IS NOT NULL AND v_source <> 'direct' THEN
    v_join_url := v_join_url || '?source=' || v_source;
    v_deep_link_url := v_deep_link_url || '?source=' || v_source;
  END IF;

  INSERT INTO public.match_pool_share_events (
    pool_id,
    invite_id,
    user_id,
    source,
    share_slug,
    venue_id,
    country_code,
    metadata
  )
  VALUES (
    v_pool.id,
    CASE WHEN v_invite.id IS NOT NULL THEN v_invite.id ELSE NULL END,
    auth.uid(),
    COALESCE(v_source, 'direct'),
    v_pool.share_slug,
    v_pool.venue_id,
    v_pool.country_code,
    jsonb_build_object(
      'invite_code_present', v_invite_code IS NOT NULL,
      'invite_valid', COALESCE((v_invite_payload ->> 'valid')::boolean, false),
      'has_session_user', auth.uid() IS NOT NULL
    )
  )
  RETURNING id INTO v_event_id;

  RETURN jsonb_build_object(
    'pool', jsonb_build_object(
      'id', v_pool.id,
      'match_id', v_pool.match_id,
      'title', v_pool.title,
      'scope', v_pool.scope,
      'country_id', v_pool.country_id,
      'country_code', v_pool.country_code,
      'venue_id', v_pool.venue_id,
      'status', v_pool.status,
      'share_slug', v_pool.share_slug,
      'share_url', COALESCE(v_pool.share_url, '/pools/' || v_pool.share_slug),
      'join_url', v_join_url,
      'deep_link_url', v_deep_link_url,
      'social_card_url', v_pool.social_card_url,
      'total_members', v_pool.total_members,
      'total_staked_fet', v_pool.total_staked_fet
    ),
    'match', COALESCE(v_match, '{}'::jsonb),
    'venue', v_venue,
    'country', v_country,
    'invite', v_invite_payload,
    'tracking', jsonb_build_object(
      'source', COALESCE(v_source, 'direct'),
      'invite_code_present', v_invite_code IS NOT NULL,
      'event_id', v_event_id
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_match_pool_social_card_payload(p_pool_id uuid) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_actor_user_id uuid := auth.uid();
  v_payload jsonb;
BEGIN
  SELECT jsonb_build_object(
    'pool_id', p.id,
    'title', p.title,
    'scope', p.scope,
    'scope_label', CASE
      WHEN p.scope = 'venue' THEN 'This Bar'
      WHEN p.scope = 'country' THEN COALESCE(p.country_code, 'Country')
      ELSE 'Global'
    END,
    'country_code', p.country_code,
    'country_id', p.country_id,
    'venue_id', p.venue_id,
    'venue_name', v.name,
    'share_slug', p.share_slug,
    'share_url', p.share_url,
    'deep_link_url', p.deep_link_url,
    'social_card_url', p.social_card_url,
    'social_card', COALESCE(p.metadata -> 'social_card', '{}'::jsonb),
    'match', jsonb_build_object(
      'id', COALESCE(cm.id, am.id),
      'home_team', COALESCE(cm.home_team, am.home_team),
      'away_team', COALESCE(cm.away_team, am.away_team),
      'competition', COALESCE(cm.competition_name, am.competition_name),
      'date', COALESCE(cm.date, am.date),
      'status', CASE
        WHEN COALESCE(cm.status, am.status) = 'finished' THEN 'final'
        ELSE COALESCE(cm.status, am.status)
      END,
      'score', CASE
        WHEN COALESCE(cm.ft_home, am.ft_home) IS NOT NULL
         AND COALESCE(cm.ft_away, am.ft_away) IS NOT NULL
          THEN COALESCE(cm.ft_home, am.ft_home)::text || '-' || COALESCE(cm.ft_away, am.ft_away)::text
        ELSE NULL
      END
    ),
    'stats', jsonb_build_object(
      'total_members', p.total_members,
      'total_staked_fet', p.total_staked_fet
    ),
    'camps', p.camps
  )
  INTO v_payload
  FROM public.match_pool_stats p
  LEFT JOIN LATERAL (
    SELECT *
    FROM public.curated_active_matches cam
    WHERE cam.id = p.match_id
    ORDER BY cam.priority_score DESC, cam.curation_id
    LIMIT 1
  ) cm ON true
  LEFT JOIN public.app_matches am ON am.id = p.match_id
  LEFT JOIN public.venues v ON v.id = p.venue_id
  WHERE p.id = p_pool_id
    AND (
      p.status IN ('open', 'locked', 'live', 'settling', 'settled')
      OR public.is_admin_manager(v_actor_user_id)
      OR (
        p.venue_id IS NOT NULL
        AND public.venue_user_has_role(p.venue_id)
      )
    );

  IF v_payload IS NULL THEN
    RAISE EXCEPTION 'Pool not found';
  END IF;

  RETURN v_payload;
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
  v_camp public.match_pool_camps%ROWTYPE;
  v_invite public.match_pool_invites%ROWTYPE;
  v_entry public.match_pool_entries%ROWTYPE;
  v_amount bigint;
  v_min_qualified_stake bigint;
  v_reward_amount bigint := 0;
  v_reward_result jsonb := '{}'::jsonb;
  v_reward_tx_id uuid;
  v_invite_valid boolean := false;
  v_reward_eligible boolean := false;
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

  IF v_pool.status NOT IN ('open', 'locked', 'live') THEN
    RAISE EXCEPTION 'Pool is not open for entries';
  END IF;

  SELECT * INTO v_camp
  FROM public.match_pool_camps
  WHERE id = p_camp_id
    AND pool_id = p_pool_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pool camp not found';
  END IF;

  v_amount := COALESCE(p_amount_fet, v_pool.entry_fee_fet, v_pool.stake_min_fet, 1);
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
      'min_qualified_stake', v_min_qualified_stake
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
    'creator_reward_amount_fet', v_reward_amount
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.join_pool(
  p_pool_id uuid,
  p_camp_id uuid,
  p_stake_amount bigint DEFAULT NULL::bigint,
  p_source text DEFAULT 'direct'::text,
  p_invite_code text DEFAULT NULL::text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_result jsonb;
  v_entry_id uuid;
  v_inviter uuid;
  v_source text := lower(COALESCE(NULLIF(trim(p_source), ''), 'direct'));
BEGIN
  IF v_source NOT IN ('direct', 'invite_link', 'venue_qr', 'social_share') THEN
    RAISE EXCEPTION 'Invalid pool entry source';
  END IF;

  v_result := public.join_match_pool(p_pool_id, p_camp_id, p_stake_amount, p_invite_code);
  v_entry_id := (v_result ->> 'entry_id')::uuid;

  IF p_invite_code IS NOT NULL THEN
    SELECT inviter_user_id INTO v_inviter
    FROM public.match_pool_invites
    WHERE invite_code = p_invite_code
      AND pool_id = p_pool_id
      AND joined_entry_id = v_entry_id
      AND status IN ('joined', 'rewarded');
  END IF;

  UPDATE public.match_pool_entries
  SET source = CASE WHEN v_inviter IS NOT NULL THEN 'invite_link' ELSE v_source END,
      invited_by_user_id = v_inviter,
      metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
        'source', CASE WHEN v_inviter IS NOT NULL THEN 'invite_link' ELSE v_source END,
        'invite_code_present', p_invite_code IS NOT NULL
      ),
      updated_at = timezone('utc', now())
  WHERE id = v_entry_id;

  UPDATE public.fet_wallet_transactions
  SET pool_entry_id = v_entry_id
  WHERE pool_id = p_pool_id
    AND user_id = auth.uid()
    AND tx_type IN ('match_pool_entry', 'pool_stake')
    AND pool_entry_id IS NULL;

  RETURN v_result || jsonb_build_object(
    'source', CASE WHEN v_inviter IS NOT NULL THEN 'invite_link' ELSE v_source END,
    'invited_by_user_id', v_inviter
  );
END;
$$;

COMMENT ON FUNCTION public.get_public_pool_share(text,text,text)
  IS 'Resolves public pool share slugs or ids into safe share, deep-link, venue, country, match, invite, and tracking context without exposing inviter identity.';
COMMENT ON FUNCTION public.join_match_pool(uuid,uuid,bigint,text)
  IS 'Wallet-backed pool join. Creator rewards require a valid creator invite, non-self participant, qualified stake, and one reward per participant per pool.';

REVOKE ALL ON TABLE public.match_pool_share_events FROM PUBLIC;
GRANT SELECT ON TABLE public.match_pool_share_events TO service_role;
GRANT EXECUTE ON FUNCTION public.get_public_pool_share(text,text,text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_match_pool_social_card_payload(uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.join_match_pool(uuid,uuid,bigint,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.join_pool(uuid,uuid,bigint,text,text) TO authenticated, service_role;
