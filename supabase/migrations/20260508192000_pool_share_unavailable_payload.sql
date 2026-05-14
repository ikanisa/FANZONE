-- Return a graceful payload for expired, cancelled, or missing public pool
-- share links so the guest app can show its normal unavailable-link screen
-- without surfacing a backend 400 in browser UAT.

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
    RETURN jsonb_build_object(
      'pool', NULL,
      'match', '{}'::jsonb,
      'venue', NULL,
      'country', NULL,
      'invite', CASE
        WHEN v_invite_code IS NULL THEN NULL
        ELSE jsonb_build_object('code', v_invite_code, 'valid', false)
      END,
      'tracking', jsonb_build_object(
        'source', COALESCE(v_source, 'direct'),
        'invite_code_present', v_invite_code IS NOT NULL,
        'event_id', NULL
      ),
      'error', jsonb_build_object(
        'code', 'pool_unavailable',
        'message', 'Pool link expired or unavailable'
      )
    );
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

COMMENT ON FUNCTION public.get_public_pool_share(text,text,text)
  IS 'Resolves public pool share slugs or ids into safe share, deep-link, venue, country, match, invite, and tracking context without exposing inviter identity. Missing, expired, or cancelled shares return a null pool payload for graceful app fallback.';

GRANT EXECUTE ON FUNCTION public.get_public_pool_share(text,text,text) TO anon, authenticated, service_role;
