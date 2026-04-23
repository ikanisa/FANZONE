BEGIN;

-- Runtime/admin fixes discovered by linked-schema lint after the lean refactor.

ALTER TABLE public.admin_users
  ADD COLUMN IF NOT EXISTS invited_by uuid,
  ADD COLUMN IF NOT EXISTS last_login_at timestamp with time zone;

UPDATE public.admin_users au
SET last_login_at = u.last_sign_in_at
FROM auth.users u
WHERE u.id = au.user_id
  AND au.last_login_at IS DISTINCT FROM u.last_sign_in_at;

CREATE OR REPLACE FUNCTION public.ensure_user_foundation(p_user_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  phone_value text;
  v_foundation_grant bigint := 50;
  v_current_supply bigint := 0;
  v_wallet_created boolean := false;
BEGIN
  SELECT public.resolve_auth_user_phone(p_user_id) INTO phone_value;

  INSERT INTO public.profiles (id, user_id, phone_number)
  VALUES (p_user_id, p_user_id, phone_value)
  ON CONFLICT (id) DO UPDATE
    SET user_id = EXCLUDED.user_id,
        phone_number = coalesce(EXCLUDED.phone_number, profiles.phone_number);

  PERFORM public.lock_fet_supply_cap();

  IF NOT EXISTS (
    SELECT 1
    FROM public.fet_wallets
    WHERE user_id = p_user_id
  ) THEN
    SELECT coalesce(sum(available_balance_fet + locked_balance_fet), 0)::bigint
    INTO v_current_supply
    FROM public.fet_wallets;

    IF v_current_supply + v_foundation_grant > public.fet_supply_cap() THEN
      RAISE EXCEPTION 'ensure_user_foundation would exceed FET supply cap (% + % > %)',
        v_current_supply,
        v_foundation_grant,
        public.fet_supply_cap();
    END IF;

    INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
    VALUES (p_user_id, v_foundation_grant, 0)
    ON CONFLICT (user_id) DO NOTHING
    RETURNING true INTO v_wallet_created;

    IF coalesce(v_wallet_created, false) THEN
      INSERT INTO public.fet_wallet_transactions (
        user_id,
        tx_type,
        direction,
        amount_fet,
        balance_before_fet,
        balance_after_fet,
        reference_type,
        reference_id,
        title
      )
      VALUES (
        p_user_id,
        'foundation_grant',
        'credit',
        v_foundation_grant,
        0,
        v_foundation_grant,
        'foundation_grant',
        p_user_id::text,
        'Foundation grant - welcome bonus'
      );
    END IF;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_global_search(p_query text, p_limit integer DEFAULT 12) RETURNS TABLE(result_id text, result_type text, title text, subtitle text, route text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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
    SELECT v_query AS raw_query, '%' || v_query || '%' AS ilike_query
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
      coalesce(nullif(trim(upa.email), ''), nullif(trim(upa.phone), ''), 'Platform user') AS subtitle,
      '/users?q=' || params.raw_query AS route,
      1 AS group_rank
    FROM public.user_profiles_admin upa
    CROSS JOIN params
    WHERE
      upa.display_name ILIKE params.ilike_query
      OR upa.email ILIKE params.ilike_query
      OR upa.phone ILIKE params.ilike_query
    ORDER BY upa.display_name NULLS LAST, upa.email NULLS LAST, upa.id
    LIMIT 3
  ),
  fixture_hits AS (
    SELECT
      m.id::text AS result_id,
      'fixture'::text AS result_type,
      coalesce(ht.name, m.home_team_id) || ' vs ' || coalesce(at.name, m.away_team_id) AS title,
      lower(coalesce(m.match_status, 'scheduled')) || ' - ' || to_char(m.match_date, 'YYYY-MM-DD') AS subtitle,
      '/fixtures?q=' || params.raw_query AS route,
      2 AS group_rank
    FROM public.matches m
    LEFT JOIN public.teams ht ON ht.id = m.home_team_id
    LEFT JOIN public.teams at ON at.id = m.away_team_id
    CROSS JOIN params
    WHERE
      coalesce(ht.name, m.home_team_id) ILIKE params.ilike_query
      OR coalesce(at.name, m.away_team_id) ILIKE params.ilike_query
      OR m.id ILIKE params.ilike_query
    ORDER BY m.match_date DESC, m.id
    LIMIT 3
  ),
  prediction_hits AS (
    SELECT
      up.id::text AS result_id,
      'prediction'::text AS result_type,
      coalesce(ht.name, m.home_team_id) || ' vs ' || coalesce(at.name, m.away_team_id) AS title,
      lower(coalesce(up.reward_status, 'pending')) || ' - ' || coalesce(up.predicted_result_code, 'pending') AS subtitle,
      '/predictions?q=' || params.raw_query AS route,
      3 AS group_rank
    FROM public.user_predictions up
    JOIN public.matches m ON m.id = up.match_id
    LEFT JOIN public.teams ht ON ht.id = m.home_team_id
    LEFT JOIN public.teams at ON at.id = m.away_team_id
    CROSS JOIN params
    WHERE
      up.id::text ILIKE params.ilike_query
      OR up.user_id::text ILIKE params.ilike_query
      OR coalesce(ht.name, m.home_team_id) ILIKE params.ilike_query
      OR coalesce(at.name, m.away_team_id) ILIKE params.ilike_query
    ORDER BY up.created_at DESC, up.id
    LIMIT 3
  ),
  competition_hits AS (
    SELECT
      c.id::text AS result_id,
      'competition'::text AS result_type,
      c.name AS title,
      coalesce(nullif(trim(c.short_name), ''), lower(c.country), 'competition') AS subtitle,
      '/competitions?q=' || params.raw_query AS route,
      4 AS group_rank
    FROM public.competitions c
    CROSS JOIN params
    WHERE
      c.name ILIKE params.ilike_query
      OR coalesce(c.short_name, '') ILIKE params.ilike_query
      OR c.id ILIKE params.ilike_query
    ORDER BY c.name, c.id
    LIMIT 3
  ),
  wallet_hits AS (
    SELECT
      fw.user_id::text AS result_id,
      'wallet'::text AS result_type,
      coalesce(
        nullif(trim(upa.display_name), ''),
        nullif(trim(upa.email), ''),
        fw.user_id::text
      ) AS title,
      'balance ' || fw.available_balance_fet::text || ' FET' AS subtitle,
      '/wallets?q=' || params.raw_query AS route,
      5 AS group_rank
    FROM public.fet_wallets fw
    LEFT JOIN public.user_profiles_admin upa ON upa.id = fw.user_id
    CROSS JOIN params
    WHERE
      fw.user_id::text ILIKE params.ilike_query
      OR coalesce(upa.display_name, '') ILIKE params.ilike_query
      OR coalesce(upa.email, '') ILIKE params.ilike_query
      OR coalesce(upa.phone, '') ILIKE params.ilike_query
    ORDER BY fw.available_balance_fet DESC, fw.user_id
    LIMIT 3
  )
  SELECT
    combined.result_id,
    combined.result_type,
    combined.title,
    combined.subtitle,
    combined.route
  FROM (
    SELECT * FROM user_hits
    UNION ALL
    SELECT * FROM fixture_hits
    UNION ALL
    SELECT * FROM prediction_hits
    UNION ALL
    SELECT * FROM competition_hits
    UNION ALL
    SELECT * FROM wallet_hits
  ) combined
  ORDER BY combined.group_rank, combined.title
  LIMIT v_limit;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_grant_access(p_phone text, p_role text) RETURNS public.admin_users
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
DECLARE
  v_actor_user_id uuid := public.require_super_admin_user();
  v_actor_admin_id uuid;
  v_target_user_id uuid;
  v_normalized_phone text := regexp_replace(trim(coalesce(p_phone, '')), '[^0-9+]', '', 'g');
  v_role text := lower(trim(coalesce(p_role, '')));
  v_existing public.admin_users%ROWTYPE;
  v_result public.admin_users%ROWTYPE;
  v_target_display_name text;
  v_target_email text;
BEGIN
  IF v_normalized_phone = '' THEN
    RAISE EXCEPTION 'WhatsApp number is required';
  END IF;

  IF v_role NOT IN ('super_admin', 'admin', 'moderator', 'viewer') THEN
    RAISE EXCEPTION 'Invalid admin role';
  END IF;

  SELECT id
  INTO v_actor_admin_id
  FROM public.admin_users
  WHERE user_id = v_actor_user_id
    AND is_active = true
  LIMIT 1;

  IF v_actor_admin_id IS NULL THEN
    RAISE EXCEPTION 'Admin operator record not found';
  END IF;

  SELECT
    id,
    coalesce(
      nullif(trim(raw_user_meta_data ->> 'display_name'), ''),
      nullif(trim(raw_user_meta_data ->> 'full_name'), ''),
      concat('Admin ', right(v_normalized_phone, 4))
    ),
    coalesce(
      nullif(trim(email::text), ''),
      concat('phone-', regexp_replace(v_normalized_phone, '[^0-9]', '', 'g'), '@phone.fanzone.invalid')
    )
  INTO v_target_user_id, v_target_display_name, v_target_email
  FROM auth.users
  WHERE phone = v_normalized_phone
  LIMIT 1;

  IF v_target_user_id IS NULL THEN
    RAISE EXCEPTION 'The target user must sign in with their WhatsApp number before admin access can be granted';
  END IF;

  SELECT *
  INTO v_existing
  FROM public.admin_users
  WHERE user_id = v_target_user_id
  LIMIT 1;

  IF FOUND THEN
    UPDATE public.admin_users
    SET
      email = coalesce(nullif(trim(email), ''), v_target_email),
      phone = v_normalized_phone,
      display_name = coalesce(nullif(trim(display_name), ''), v_target_display_name),
      role = v_role,
      is_active = true,
      invited_by = coalesce(invited_by, v_actor_admin_id),
      last_login_at = coalesce(last_login_at, (
        SELECT u.last_sign_in_at FROM auth.users u WHERE u.id = v_target_user_id
      )),
      updated_at = timezone('utc', now())
    WHERE id = v_existing.id
    RETURNING *
    INTO v_result;
  ELSE
    INSERT INTO public.admin_users (
      user_id,
      email,
      phone,
      display_name,
      role,
      is_active,
      invited_by,
      last_login_at
    )
    VALUES (
      v_target_user_id,
      v_target_email,
      v_normalized_phone,
      v_target_display_name,
      v_role,
      true,
      v_actor_admin_id,
      (SELECT u.last_sign_in_at FROM auth.users u WHERE u.id = v_target_user_id)
    )
    RETURNING *
    INTO v_result;
  END IF;

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
    v_actor_admin_id,
    'grant_admin_access',
    'admin_access',
    'admin_user',
    v_result.id::text,
    CASE WHEN v_existing.id IS NOT NULL THEN to_jsonb(v_existing) ELSE NULL END,
    to_jsonb(v_result),
    jsonb_build_object(
      'phone', v_normalized_phone,
      'role', v_role
    )
  );

  RETURN v_result;
END;
$$;

DROP FUNCTION IF EXISTS public.admin_log_action(text, text, text, text, jsonb, jsonb, jsonb);
CREATE FUNCTION public.admin_log_action(p_action text, p_module text, p_target_type text DEFAULT NULL::text, p_target_id text DEFAULT NULL::text, p_before_state jsonb DEFAULT NULL::jsonb, p_after_state jsonb DEFAULT NULL::jsonb, p_metadata jsonb DEFAULT '{}'::jsonb) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_actor_user_id uuid := public.require_active_admin_user();
  v_actor_admin_id uuid;
  v_audit_id bigint;
BEGIN
  SELECT id
  INTO v_actor_admin_id
  FROM public.admin_users
  WHERE user_id = v_actor_user_id
    AND is_active = true
  LIMIT 1;

  IF v_actor_admin_id IS NULL THEN
    RAISE EXCEPTION 'Admin operator record not found';
  END IF;

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
    v_actor_admin_id,
    lower(trim(coalesce(p_action, ''))),
    lower(trim(coalesce(p_module, ''))),
    nullif(trim(coalesce(p_target_type, '')), ''),
    nullif(trim(coalesce(p_target_id, '')), ''),
    p_before_state,
    p_after_state,
    coalesce(p_metadata, '{}'::jsonb)
  )
  RETURNING id INTO v_audit_id;

  RETURN v_audit_id;
END;
$$;

CREATE OR REPLACE VIEW public.admin_feature_flags AS
 SELECT
    (ff.key || ':' || ff.market || ':' || ff.platform) AS id,
    ff.key,
    initcap(replace(ff.key, '_', ' ')) AS label,
    ff.description,
    ff.enabled AS is_enabled,
    ff.market,
    split_part(ff.key, '_', 1) AS module,
    jsonb_build_object(
      'platform', ff.platform,
      'rollout_pct', ff.rollout_pct
    ) AS config,
    NULL::uuid AS updated_by,
    ff.updated_at AS created_at,
    ff.updated_at
   FROM public.feature_flags ff
  WHERE public.is_active_admin_operator(auth.uid());

DROP FUNCTION IF EXISTS public.admin_set_feature_flag(uuid, boolean);
CREATE FUNCTION public.admin_set_feature_flag(p_flag_id text, p_is_enabled boolean) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
DECLARE
  v_admin_record_id uuid;
  v_key text := split_part(coalesce(p_flag_id, ''), ':', 1);
  v_market text := coalesce(nullif(split_part(coalesce(p_flag_id, ''), ':', 2), ''), 'global');
  v_platform text := coalesce(nullif(split_part(coalesce(p_flag_id, ''), ':', 3), ''), 'all');
  v_before jsonb;
  v_after jsonb;
BEGIN
  PERFORM public.require_admin_manager_user();
  v_admin_record_id := public.active_admin_record_id();

  SELECT to_jsonb(flag_row)
  INTO v_before
  FROM public.admin_feature_flags flag_row
  WHERE flag_row.id = p_flag_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Feature flag not found';
  END IF;

  UPDATE public.feature_flags
  SET
    enabled = p_is_enabled,
    updated_at = timezone('utc', now())
  WHERE key = v_key
    AND market = v_market
    AND platform = v_platform;

  SELECT to_jsonb(flag_row)
  INTO v_after
  FROM public.admin_feature_flags flag_row
  WHERE flag_row.id = p_flag_id;

  INSERT INTO public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    before_state,
    after_state,
    metadata
  ) VALUES (
    v_admin_record_id,
    'toggle_feature_flag',
    'settings',
    'feature_flag',
    p_flag_id,
    v_before,
    v_after,
    jsonb_build_object('is_enabled', p_is_enabled)
  );

  RETURN jsonb_build_object(
    'id', p_flag_id,
    'is_enabled', p_is_enabled
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.issue_anonymous_upgrade_claim() RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
DECLARE
  v_anon_id uuid := auth.uid();
  v_is_anonymous boolean := false;
  v_claim_token text;
BEGIN
  IF v_anon_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT coalesce(p.is_anonymous, false)
  INTO v_is_anonymous
  FROM public.profiles p
  WHERE p.user_id = v_anon_id;

  IF v_is_anonymous IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Anonymous session required';
  END IF;

  v_claim_token := replace(gen_random_uuid()::text, '-', '')
    || replace(gen_random_uuid()::text, '-', '');

  INSERT INTO public.anonymous_upgrade_claims (
    anon_user_id,
    claim_token,
    issued_at,
    expires_at,
    consumed_at,
    consumed_by_user_id
  ) VALUES (
    v_anon_id,
    v_claim_token,
    timezone('utc', now()),
    timezone('utc', now()) + interval '30 minutes',
    NULL,
    NULL
  )
  ON CONFLICT (anon_user_id) DO UPDATE
  SET claim_token = EXCLUDED.claim_token,
      issued_at = EXCLUDED.issued_at,
      expires_at = EXCLUDED.expires_at,
      consumed_at = NULL,
      consumed_by_user_id = NULL;

  RETURN v_claim_token;
END;
$$;

CREATE OR REPLACE FUNCTION public.merge_anonymous_to_authenticated(p_anon_id uuid, p_auth_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  IF p_anon_id IS NULL OR p_auth_id IS NULL THEN
    RAISE EXCEPTION 'Both anonymous and authenticated user IDs are required';
  END IF;

  IF p_anon_id = p_auth_id THEN
    RAISE EXCEPTION 'Anonymous and authenticated user IDs must be different';
  END IF;

  INSERT INTO public.user_favorite_teams (
    user_id,
    team_id,
    team_name,
    team_short_name,
    team_country,
    team_country_code,
    team_league,
    team_crest_url,
    source,
    sort_order,
    created_at,
    updated_at
  )
  SELECT
    p_auth_id,
    uft.team_id,
    uft.team_name,
    uft.team_short_name,
    uft.team_country,
    uft.team_country_code,
    uft.team_league,
    uft.team_crest_url,
    uft.source,
    uft.sort_order,
    uft.created_at,
    now()
  FROM public.user_favorite_teams uft
  WHERE uft.user_id = p_anon_id
    AND NOT EXISTS (
      SELECT 1
      FROM public.user_favorite_teams existing
      WHERE existing.user_id = p_auth_id
        AND existing.team_id = uft.team_id
    );

  INSERT INTO public.user_followed_competitions (user_id, competition_id, created_at)
  SELECT p_auth_id, ufc.competition_id, ufc.created_at
  FROM public.user_followed_competitions ufc
  WHERE ufc.user_id = p_anon_id
    AND NOT EXISTS (
      SELECT 1
      FROM public.user_followed_competitions existing
      WHERE existing.user_id = p_auth_id
        AND existing.competition_id = ufc.competition_id
    );

  UPDATE public.profiles auth_p
  SET
    favorite_team_id = COALESCE(auth_p.favorite_team_id, anon_p.favorite_team_id),
    favorite_team_name = COALESCE(auth_p.favorite_team_name, anon_p.favorite_team_name),
    active_country = COALESCE(auth_p.active_country, anon_p.active_country),
    country_code = COALESCE(auth_p.country_code, anon_p.country_code),
    onboarding_completed = true,
    upgraded_from_anonymous_id = p_anon_id,
    updated_at = now()
  FROM public.profiles anon_p
  WHERE auth_p.user_id = p_auth_id
    AND anon_p.user_id = p_anon_id;

  DELETE FROM public.user_favorite_teams WHERE user_id = p_anon_id;
  DELETE FROM public.user_followed_competitions WHERE user_id = p_anon_id;
  DELETE FROM public.profiles WHERE user_id = p_anon_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.merge_anonymous_to_authenticated_secure(p_anon_id uuid, p_claim_token text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
DECLARE
  v_auth_id uuid := auth.uid();
  v_claim public.anonymous_upgrade_claims%ROWTYPE;
  v_auth_is_anonymous boolean := false;
BEGIN
  IF v_auth_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_anon_id IS NULL OR nullif(btrim(p_claim_token), '') IS NULL THEN
    RAISE EXCEPTION 'Anonymous user ID and claim token are required';
  END IF;

  IF p_anon_id = v_auth_id THEN
    RAISE EXCEPTION 'Anonymous and authenticated user IDs must be different';
  END IF;

  SELECT *
  INTO v_claim
  FROM public.anonymous_upgrade_claims
  WHERE anon_user_id = p_anon_id
    AND claim_token = p_claim_token
    AND consumed_at IS NULL
    AND expires_at > timezone('utc', now());

  IF v_claim.anon_user_id IS NULL THEN
    RAISE EXCEPTION 'Invalid or expired upgrade claim';
  END IF;

  SELECT coalesce(p.is_anonymous, false)
  INTO v_auth_is_anonymous
  FROM public.profiles p
  WHERE p.user_id = v_auth_id;

  IF v_auth_is_anonymous = true THEN
    RAISE EXCEPTION 'Authenticated account required';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.user_id = p_anon_id
      AND coalesce(p.is_anonymous, false) = true
  ) THEN
    RAISE EXCEPTION 'Anonymous profile not found';
  END IF;

  INSERT INTO public.profiles (
    id,
    user_id,
    is_anonymous,
    auth_method,
    created_at,
    updated_at
  )
  SELECT
    v_auth_id,
    v_auth_id,
    false,
    'phone',
    timezone('utc', now()),
    timezone('utc', now())
  WHERE NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.user_id = v_auth_id
  );

  INSERT INTO public.user_favorite_teams (
    user_id,
    team_id,
    team_name,
    team_short_name,
    team_country,
    team_country_code,
    team_league,
    team_crest_url,
    source,
    sort_order,
    created_at,
    updated_at
  )
  SELECT
    v_auth_id,
    uft.team_id,
    uft.team_name,
    uft.team_short_name,
    uft.team_country,
    uft.team_country_code,
    uft.team_league,
    uft.team_crest_url,
    uft.source,
    uft.sort_order,
    uft.created_at,
    timezone('utc', now())
  FROM public.user_favorite_teams uft
  WHERE uft.user_id = p_anon_id
    AND NOT EXISTS (
      SELECT 1
      FROM public.user_favorite_teams existing
      WHERE existing.user_id = v_auth_id
        AND existing.team_id = uft.team_id
    );

  INSERT INTO public.user_followed_competitions (
    user_id,
    competition_id,
    created_at
  )
  SELECT
    v_auth_id,
    ufc.competition_id,
    ufc.created_at
  FROM public.user_followed_competitions ufc
  WHERE ufc.user_id = p_anon_id
    AND NOT EXISTS (
      SELECT 1
      FROM public.user_followed_competitions existing
      WHERE existing.user_id = v_auth_id
        AND existing.competition_id = ufc.competition_id
    );

  UPDATE public.profiles auth_p
  SET favorite_team_id = coalesce(auth_p.favorite_team_id, anon_p.favorite_team_id),
      favorite_team_name = coalesce(auth_p.favorite_team_name, anon_p.favorite_team_name),
      active_country = coalesce(auth_p.active_country, anon_p.active_country),
      country_code = coalesce(auth_p.country_code, anon_p.country_code),
      onboarding_completed = true,
      upgraded_from_anonymous_id = p_anon_id,
      is_anonymous = false,
      auth_method = coalesce(nullif(auth_p.auth_method, ''), 'phone'),
      updated_at = timezone('utc', now())
  FROM public.profiles anon_p
  WHERE auth_p.user_id = v_auth_id
    AND anon_p.user_id = p_anon_id;

  UPDATE public.anonymous_upgrade_claims
  SET consumed_at = timezone('utc', now()),
      consumed_by_user_id = v_auth_id
  WHERE anon_user_id = p_anon_id;

  DELETE FROM public.user_favorite_teams WHERE user_id = p_anon_id;
  DELETE FROM public.user_followed_competitions WHERE user_id = p_anon_id;
  DELETE FROM public.profiles WHERE user_id = p_anon_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.score_finished_matches_with_pending_predictions(p_limit integer DEFAULT 50) RETURNS integer
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
DECLARE
  rec record;
  v_count integer := 0;
BEGIN
  FOR rec IN
    SELECT
      m.id,
      max(m.match_date) AS match_date
    FROM public.matches m
    JOIN public.user_predictions up
      ON up.match_id = m.id
    WHERE m.match_status = 'finished'
      AND up.reward_status = 'pending'
    GROUP BY m.id
    ORDER BY max(m.match_date) DESC
    LIMIT greatest(1, coalesce(p_limit, 50))
  LOOP
    PERFORM public.score_user_predictions_for_match(rec.id);
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

DROP FUNCTION IF EXISTS public.admin_set_banner_active(uuid, boolean);
DROP FUNCTION IF EXISTS public.cleanup_old_live_update_runs(integer);

COMMIT;
