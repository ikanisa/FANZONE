-- ============================================================================
-- Pool sharing
--
-- Public pool links use the secure share_slug, not editable raw ids. The app and
-- website resolve slugs through backend functions, while creator invite reward
-- attribution remains server-side and is finalized only by join/stake RPCs.
-- ============================================================================

ALTER TABLE public.match_pools
  ADD COLUMN IF NOT EXISTS deep_link_url text;

ALTER TABLE public.match_pools
  ALTER COLUMN creator_reward_fet SET DEFAULT 1;

CREATE OR REPLACE FUNCTION public.set_match_pool_share_links()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
DECLARE
  v_slug_changed boolean := false;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    v_slug_changed := OLD.share_slug IS DISTINCT FROM NEW.share_slug;
  END IF;

  IF NEW.share_slug IS NULL OR trim(NEW.share_slug) = '' THEN
    RAISE EXCEPTION 'Pool share slug is required';
  END IF;

  IF NEW.share_slug !~ '^[a-z0-9][a-z0-9_-]{7,63}$' THEN
    RAISE EXCEPTION 'Pool share slug must be a safe public token';
  END IF;

  IF NEW.share_url IS NULL
     OR trim(NEW.share_url) = ''
     OR v_slug_changed THEN
    NEW.share_url := '/pools/' || NEW.share_slug;
  END IF;

  IF NEW.deep_link_url IS NULL
     OR trim(NEW.deep_link_url) = ''
     OR v_slug_changed THEN
    NEW.deep_link_url := 'fanzone://pools/' || NEW.share_slug;
  END IF;

  NEW.metadata := COALESCE(NEW.metadata, '{}'::jsonb)
    || jsonb_build_object(
      'share', COALESCE(NEW.metadata -> 'share', '{}'::jsonb)
        || jsonb_build_object(
          'share_url', NEW.share_url,
          'deep_link_url', NEW.deep_link_url,
          'updated_at', timezone('utc', now())
        )
    );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_match_pools_share_links ON public.match_pools;
CREATE TRIGGER trg_match_pools_share_links
BEFORE INSERT OR UPDATE OF share_slug, share_url, deep_link_url ON public.match_pools
FOR EACH ROW
EXECUTE FUNCTION public.set_match_pool_share_links();

UPDATE public.match_pools
SET share_url = '/pools/' || share_slug,
    deep_link_url = 'fanzone://pools/' || share_slug,
    metadata = COALESCE(metadata, '{}'::jsonb)
      || jsonb_build_object(
        'share', COALESCE(metadata -> 'share', '{}'::jsonb)
          || jsonb_build_object(
            'share_url', '/pools/' || share_slug,
            'deep_link_url', 'fanzone://pools/' || share_slug,
            'updated_at', timezone('utc', now())
          )
      )
WHERE share_slug IS NOT NULL
  AND (
    NULLIF(trim(COALESCE(share_url, '')), '') IS NULL
    OR share_url !~ '^(/|https://[^/]+/)pools/[a-z0-9][a-z0-9_-]{7,63}($|[?])'
    OR NULLIF(trim(COALESCE(deep_link_url, '')), '') IS NULL
  );

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
  p.metadata,
  p.deep_link_url
FROM public.match_pools p
LEFT JOIN public.match_pool_camps c ON c.pool_id = p.id
GROUP BY p.id;

CREATE OR REPLACE VIEW public.pools WITH (security_invoker='true') AS
 SELECT match_pools.id,
    match_pools.match_id,
    (match_pools.scope)::text AS scope,
    match_pools.country_id,
    match_pools.venue_id,
    match_pools.creator_user_id,
    match_pools.title,
    (match_pools.status)::text AS status,
    match_pools.stake_min_fet AS stake_min,
    match_pools.stake_max_fet AS stake_max,
    match_pools.creator_reward_fet AS creator_reward_per_qualified_member,
    match_pools.share_url,
    match_pools.social_card_url,
    match_pools.rules_json,
    match_pools.created_at,
    match_pools.updated_at,
    match_pools.deep_link_url
   FROM public.match_pools;

CREATE OR REPLACE FUNCTION public.create_match_pool_invite(
  p_pool_id uuid,
  p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone
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
  v_share_url text;
  v_deep_link_url text;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_pool
  FROM public.match_pools
  WHERE id = p_pool_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pool not found';
  END IF;

  IF v_pool.status NOT IN ('open', 'locked') THEN
    RAISE EXCEPTION 'Invites can only be created for visible pools';
  END IF;

  IF COALESCE(v_pool.creator_reward_fet, 0) <= 0 THEN
    RAISE EXCEPTION 'Creator invite rewards are disabled for this pool';
  END IF;

  IF v_pool.creator_user_id IS DISTINCT FROM v_user_id
     AND NOT public.is_admin_manager(v_user_id)
     AND NOT (
       v_pool.venue_id IS NOT NULL
       AND public.venue_user_has_role(v_pool.venue_id)
     ) THEN
    RAISE EXCEPTION 'Only the pool creator or an operator can create creator reward invites';
  END IF;

  INSERT INTO public.match_pool_invites (
    pool_id,
    inviter_user_id,
    expires_at,
    metadata
  )
  VALUES (
    p_pool_id,
    COALESCE(v_pool.creator_user_id, v_user_id),
    p_expires_at,
    jsonb_build_object('created_by', v_user_id, 'source', 'creator_share_link')
  )
  RETURNING * INTO v_invite;

  v_share_url := COALESCE(v_pool.share_url, '/pools/' || v_pool.share_slug)
    || '?invite=' || v_invite.invite_code || '&source=invite_link';
  v_deep_link_url := COALESCE(v_pool.deep_link_url, 'fanzone://pools/' || v_pool.share_slug)
    || '?invite=' || v_invite.invite_code || '&source=invite_link';

  RETURN jsonb_build_object(
    'status', 'created',
    'invite_id', v_invite.id,
    'pool_id', v_invite.pool_id,
    'invite_code', v_invite.invite_code,
    'share_url', v_share_url,
    'deep_link_url', v_deep_link_url,
    'expires_at', v_invite.expires_at
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_public_pool_share(
  p_slug_or_pool_id text,
  p_invite_code text DEFAULT NULL,
  p_source text DEFAULT 'direct'
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
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
BEGIN
  IF v_lookup = '' THEN
    RAISE EXCEPTION 'Pool share slug is required';
  END IF;

  IF COALESCE(v_source, 'direct') NOT IN ('direct', 'invite_link', 'venue_qr', 'social_share') THEN
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
        'creator_reward_available', v_pool.creator_user_id = v_invite.inviter_user_id
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
  FROM public.app_matches m
  WHERE m.id = v_pool.match_id;

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
      'invite_code_present', v_invite_code IS NOT NULL
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
      'id', m.id,
      'home_team', m.home_team,
      'away_team', m.away_team,
      'competition', m.competition_name,
      'date', m.date,
      'status', m.status,
      'score', CASE
        WHEN m.ft_home IS NOT NULL AND m.ft_away IS NOT NULL
          THEN m.ft_home::text || '-' || m.ft_away::text
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
  LEFT JOIN public.app_matches m ON m.id = p.match_id
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

INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'pool-social-cards',
  'pool-social-cards',
  true,
  524288,
  ARRAY['image/svg+xml', 'image/png', 'image/jpeg']
)
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

COMMENT ON FUNCTION public.get_public_pool_share(text,text,text)
  IS 'Resolves public pool share slugs or ids into safe share, deep-link, venue, country, match, and invite context without exposing inviter identity.';
COMMENT ON FUNCTION public.get_match_pool_social_card_payload(uuid)
  IS 'Backend social-card payload for match pool share images. Returns only visible pool context.';

REVOKE ALL ON FUNCTION public.set_match_pool_share_links() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_match_pool_share_links() TO service_role;
GRANT EXECUTE ON FUNCTION public.create_match_pool_invite(uuid,timestamp with time zone) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_public_pool_share(text,text,text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_match_pool_social_card_payload(uuid) TO anon, authenticated, service_role;
