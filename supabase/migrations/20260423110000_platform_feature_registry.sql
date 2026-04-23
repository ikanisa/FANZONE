BEGIN;

CREATE TABLE IF NOT EXISTS public.platform_features (
  feature_key text PRIMARY KEY,
  display_name text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive', 'hidden', 'beta', 'scheduled')),
  is_enabled boolean NOT NULL DEFAULT true,
  navigation_group text,
  default_route_key text,
  admin_notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.platform_feature_rules (
  feature_key text PRIMARY KEY
    REFERENCES public.platform_features(feature_key) ON DELETE CASCADE,
  auth_required boolean NOT NULL DEFAULT false,
  role_restrictions jsonb NOT NULL DEFAULT '[]'::jsonb,
  dependency_config jsonb NOT NULL DEFAULT '{}'::jsonb,
  rollout_config jsonb NOT NULL DEFAULT '{}'::jsonb,
  schedule_start_at timestamptz,
  schedule_end_at timestamptz,
  geo_config jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.platform_feature_channels (
  feature_key text NOT NULL
    REFERENCES public.platform_features(feature_key) ON DELETE CASCADE,
  channel text NOT NULL CHECK (channel IN ('mobile', 'web')),
  is_visible boolean NOT NULL DEFAULT true,
  is_enabled boolean NOT NULL DEFAULT true,
  show_in_navigation boolean NOT NULL DEFAULT false,
  show_on_home boolean NOT NULL DEFAULT false,
  sort_order integer NOT NULL DEFAULT 100,
  route_key text,
  entry_key text,
  navigation_label text,
  placement_key text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (feature_key, channel)
);

CREATE TABLE IF NOT EXISTS public.platform_content_blocks (
  block_key text PRIMARY KEY,
  block_type text NOT NULL,
  title text NOT NULL,
  content jsonb NOT NULL DEFAULT '{}'::jsonb,
  target_channel text NOT NULL
    CHECK (target_channel IN ('mobile', 'web', 'both')),
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 100,
  feature_key text
    REFERENCES public.platform_features(feature_key) ON DELETE SET NULL,
  placement_key text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.platform_features OWNER TO postgres;
ALTER TABLE public.platform_feature_rules OWNER TO postgres;
ALTER TABLE public.platform_feature_channels OWNER TO postgres;
ALTER TABLE public.platform_content_blocks OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.platform_feature_status_is_live(
  p_status text,
  p_schedule_start_at timestamptz DEFAULT NULL,
  p_schedule_end_at timestamptz DEFAULT NULL,
  p_now timestamptz DEFAULT timezone('utc', now())
) RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO public
AS $$
  SELECT CASE
    WHEN coalesce(p_status, 'inactive') = 'inactive' THEN false
    WHEN coalesce(p_status, 'inactive') = 'scheduled' THEN
      coalesce(p_schedule_start_at, p_now) <= p_now
      AND (p_schedule_end_at IS NULL OR p_schedule_end_at > p_now)
    ELSE p_schedule_end_at IS NULL OR p_schedule_end_at > p_now
  END;
$$;

CREATE OR REPLACE FUNCTION public.request_platform_channel()
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_headers jsonb := coalesce(
    nullif(current_setting('request.headers', true), '')::jsonb,
    '{}'::jsonb
  );
  v_explicit text := lower(coalesce(v_headers ->> 'x-fanzone-channel', ''));
  v_client_info text := lower(coalesce(v_headers ->> 'x-client-info', ''));
BEGIN
  IF v_explicit IN ('mobile', 'android', 'ios') THEN
    RETURN 'mobile';
  END IF;

  IF v_explicit = 'web' THEN
    RETURN 'web';
  END IF;

  IF v_client_info LIKE '%website%' THEN
    RETURN 'web';
  END IF;

  IF v_client_info LIKE '%flutter%' OR v_client_info LIKE '%dart%' THEN
    RETURN 'mobile';
  END IF;

  RETURN 'web';
END;
$$;

CREATE OR REPLACE FUNCTION public.resolve_platform_feature(
  p_feature_key text,
  p_channel text,
  p_is_authenticated boolean DEFAULT (auth.uid() IS NOT NULL),
  p_now timestamptz DEFAULT timezone('utc', now())
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_feature public.platform_features%ROWTYPE;
  v_rules public.platform_feature_rules%ROWTYPE;
  v_channel public.platform_feature_channels%ROWTYPE;
  v_dependency_blocker text;
  v_is_live boolean := false;
  v_is_operational boolean := false;
  v_is_visible boolean := false;
  v_feature_channel text := CASE
    WHEN lower(coalesce(p_channel, 'web')) IN ('android', 'ios', 'mobile')
      THEN 'mobile'
    ELSE 'web'
  END;
BEGIN
  SELECT *
  INTO v_feature
  FROM public.platform_features
  WHERE feature_key = coalesce(trim(p_feature_key), '');

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'feature_key', p_feature_key,
      'exists', false,
      'is_operational', false,
      'is_visible', false,
      'is_available', false
    );
  END IF;

  SELECT *
  INTO v_rules
  FROM public.platform_feature_rules
  WHERE feature_key = v_feature.feature_key;

  SELECT *
  INTO v_channel
  FROM public.platform_feature_channels
  WHERE feature_key = v_feature.feature_key
    AND channel = v_feature_channel;

  v_is_live := public.platform_feature_status_is_live(
    v_feature.status,
    v_rules.schedule_start_at,
    v_rules.schedule_end_at,
    p_now
  );

  IF coalesce(v_rules.dependency_config, '{}'::jsonb) ? 'requires_all' THEN
    SELECT dependency.feature_key
    INTO v_dependency_blocker
    FROM (
      SELECT value::text AS feature_key
      FROM jsonb_array_elements_text(
        coalesce(v_rules.dependency_config -> 'requires_all', '[]'::jsonb)
      )
    ) AS dependency
    WHERE coalesce(
      (
        public.resolve_platform_feature(
          dependency.feature_key,
          v_feature_channel,
          p_is_authenticated,
          p_now
        ) ->> 'is_operational'
      )::boolean,
      false
    ) = false
    LIMIT 1;
  END IF;

  v_is_operational :=
    coalesce(v_feature.is_enabled, false)
    AND coalesce(v_channel.is_enabled, false)
    AND v_is_live
    AND v_dependency_blocker IS NULL;

  v_is_visible :=
    v_is_operational
    AND coalesce(v_channel.is_visible, false)
    AND coalesce(v_feature.status, 'inactive') <> 'hidden';

  RETURN jsonb_build_object(
    'feature_key', v_feature.feature_key,
    'display_name', v_feature.display_name,
    'description', v_feature.description,
    'status', v_feature.status,
    'exists', true,
    'is_enabled', v_feature.is_enabled,
    'is_operational', v_is_operational,
    'is_visible', v_is_visible,
    'is_available',
      v_is_operational
      AND (coalesce(v_rules.auth_required, false) = false OR p_is_authenticated),
    'auth_required', coalesce(v_rules.auth_required, false),
    'dependency_blocker', v_dependency_blocker,
    'channel', v_feature_channel,
    'show_in_navigation', coalesce(v_channel.show_in_navigation, false),
    'show_on_home', coalesce(v_channel.show_on_home, false),
    'route_key', v_channel.route_key,
    'entry_key', v_channel.entry_key,
    'sort_order', coalesce(v_channel.sort_order, 100),
    'role_restrictions', coalesce(v_rules.role_restrictions, '[]'::jsonb),
    'rollout_config', coalesce(v_rules.rollout_config, '{}'::jsonb),
    'schedule_start_at', v_rules.schedule_start_at,
    'schedule_end_at', v_rules.schedule_end_at,
    'metadata',
      coalesce(v_feature.metadata, '{}'::jsonb)
      || jsonb_build_object(
        'channel_metadata',
        coalesce(v_channel.metadata, '{}'::jsonb)
      )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.assert_platform_feature_available(
  p_feature_key text,
  p_channel text DEFAULT 'web'
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_state jsonb;
BEGIN
  v_state := public.resolve_platform_feature(
    p_feature_key,
    p_channel,
    auth.uid() IS NOT NULL
  );

  IF coalesce((v_state ->> 'exists')::boolean, false) = false THEN
    RAISE EXCEPTION 'Unknown feature %', p_feature_key;
  END IF;

  IF coalesce((v_state ->> 'is_operational')::boolean, false) = false THEN
    RAISE EXCEPTION 'Feature % is currently disabled', p_feature_key;
  END IF;

  IF coalesce((v_state ->> 'auth_required')::boolean, false) = true
    AND auth.uid() IS NULL
  THEN
    RAISE EXCEPTION 'Authentication required for feature %', p_feature_key;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_legacy_feature_flags_from_platform(
  p_feature_key text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_feature public.platform_features%ROWTYPE;
  v_rules public.platform_feature_rules%ROWTYPE;
  v_mobile public.platform_feature_channels%ROWTYPE;
  v_web public.platform_feature_channels%ROWTYPE;
  v_base_enabled boolean;
  v_mobile_enabled boolean;
  v_web_enabled boolean;
BEGIN
  SELECT *
  INTO v_feature
  FROM public.platform_features
  WHERE feature_key = p_feature_key;

  IF NOT FOUND THEN
    DELETE FROM public.feature_flags
    WHERE key = p_feature_key
      AND market = 'global'
      AND platform IN ('all', 'android', 'ios', 'web');
    RETURN;
  END IF;

  SELECT *
  INTO v_rules
  FROM public.platform_feature_rules
  WHERE feature_key = p_feature_key;

  SELECT *
  INTO v_mobile
  FROM public.platform_feature_channels
  WHERE feature_key = p_feature_key
    AND channel = 'mobile';

  SELECT *
  INTO v_web
  FROM public.platform_feature_channels
  WHERE feature_key = p_feature_key
    AND channel = 'web';

  v_base_enabled :=
    coalesce(v_feature.is_enabled, false)
    AND public.platform_feature_status_is_live(
      v_feature.status,
      v_rules.schedule_start_at,
      v_rules.schedule_end_at
    );

  v_mobile_enabled := v_base_enabled AND coalesce(v_mobile.is_enabled, false);
  v_web_enabled := v_base_enabled AND coalesce(v_web.is_enabled, false);

  INSERT INTO public.feature_flags (
    key,
    market,
    platform,
    enabled,
    description,
    updated_at
  )
  VALUES
    (
      p_feature_key,
      'global',
      'all',
      v_mobile_enabled OR v_web_enabled,
      coalesce(v_feature.description, v_feature.display_name),
      timezone('utc', now())
    ),
    (
      p_feature_key,
      'global',
      'android',
      v_mobile_enabled,
      coalesce(v_feature.description, v_feature.display_name),
      timezone('utc', now())
    ),
    (
      p_feature_key,
      'global',
      'ios',
      v_mobile_enabled,
      coalesce(v_feature.description, v_feature.display_name),
      timezone('utc', now())
    ),
    (
      p_feature_key,
      'global',
      'web',
      v_web_enabled,
      coalesce(v_feature.description, v_feature.display_name),
      timezone('utc', now())
    )
  ON CONFLICT (key, market, platform) DO UPDATE
  SET enabled = EXCLUDED.enabled,
      description = EXCLUDED.description,
      updated_at = EXCLUDED.updated_at;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_platform_control_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_admin_record_id uuid;
  v_target_id text;
  v_before jsonb;
  v_after jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_active_admin_operator(auth.uid()) THEN
    RETURN coalesce(NEW, OLD);
  END IF;

  v_admin_record_id := public.active_admin_record_id();
  v_before := CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END;
  v_after := CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END;

  v_target_id := CASE TG_TABLE_NAME
    WHEN 'platform_features' THEN coalesce(NEW.feature_key, OLD.feature_key)
    WHEN 'platform_feature_rules' THEN coalesce(NEW.feature_key, OLD.feature_key)
    WHEN 'platform_feature_channels' THEN
      coalesce(NEW.feature_key, OLD.feature_key) || ':' || coalesce(NEW.channel, OLD.channel)
    WHEN 'platform_content_blocks' THEN coalesce(NEW.block_key, OLD.block_key)
    ELSE coalesce(NEW.feature_key, OLD.feature_key, NEW.block_key, OLD.block_key)
  END;

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
    lower(TG_OP) || '_' || TG_TABLE_NAME,
    'platform-control',
    TG_TABLE_NAME,
    v_target_id,
    v_before,
    v_after,
    jsonb_build_object('table', TG_TABLE_NAME)
  );

  RETURN coalesce(NEW, OLD);
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_legacy_feature_flags_on_platform_write()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  PERFORM public.sync_legacy_feature_flags_from_platform(
    coalesce(NEW.feature_key, OLD.feature_key)
  );
  RETURN coalesce(NEW, OLD);
END;
$$;

DROP VIEW IF EXISTS public.admin_platform_features;
CREATE OR REPLACE VIEW public.admin_platform_features AS
SELECT
  pf.feature_key AS id,
  pf.feature_key,
  pf.display_name,
  pf.description,
  pf.status,
  pf.is_enabled,
  pf.navigation_group,
  pf.default_route_key,
  pf.admin_notes,
  pf.metadata,
  coalesce(pfr.auth_required, false) AS auth_required,
  coalesce(pfr.role_restrictions, '[]'::jsonb) AS role_restrictions,
  coalesce(pfr.dependency_config, '{}'::jsonb) AS dependency_config,
  coalesce(pfr.rollout_config, '{}'::jsonb) AS rollout_config,
  pfr.schedule_start_at,
  pfr.schedule_end_at,
  jsonb_build_object(
    'channel', 'mobile',
    'is_visible', coalesce(pfc_mobile.is_visible, false),
    'is_enabled', coalesce(pfc_mobile.is_enabled, false),
    'show_in_navigation', coalesce(pfc_mobile.show_in_navigation, false),
    'show_on_home', coalesce(pfc_mobile.show_on_home, false),
    'sort_order', coalesce(pfc_mobile.sort_order, 100),
    'route_key', pfc_mobile.route_key,
    'entry_key', pfc_mobile.entry_key,
    'navigation_label', pfc_mobile.navigation_label,
    'placement_key', pfc_mobile.placement_key,
    'metadata', coalesce(pfc_mobile.metadata, '{}'::jsonb)
  ) AS mobile_channel,
  jsonb_build_object(
    'channel', 'web',
    'is_visible', coalesce(pfc_web.is_visible, false),
    'is_enabled', coalesce(pfc_web.is_enabled, false),
    'show_in_navigation', coalesce(pfc_web.show_in_navigation, false),
    'show_on_home', coalesce(pfc_web.show_on_home, false),
    'sort_order', coalesce(pfc_web.sort_order, 100),
    'route_key', pfc_web.route_key,
    'entry_key', pfc_web.entry_key,
    'navigation_label', pfc_web.navigation_label,
    'placement_key', pfc_web.placement_key,
    'metadata', coalesce(pfc_web.metadata, '{}'::jsonb)
  ) AS web_channel,
  pf.created_at,
  greatest(
    pf.updated_at,
    coalesce(pfr.updated_at, pf.updated_at),
    coalesce(pfc_mobile.updated_at, pf.updated_at),
    coalesce(pfc_web.updated_at, pf.updated_at)
  ) AS updated_at
FROM public.platform_features pf
LEFT JOIN public.platform_feature_rules pfr
  ON pfr.feature_key = pf.feature_key
LEFT JOIN public.platform_feature_channels pfc_mobile
  ON pfc_mobile.feature_key = pf.feature_key
 AND pfc_mobile.channel = 'mobile'
LEFT JOIN public.platform_feature_channels pfc_web
  ON pfc_web.feature_key = pf.feature_key
 AND pfc_web.channel = 'web'
WHERE public.is_active_admin_operator(auth.uid());

DROP VIEW IF EXISTS public.admin_platform_content_blocks;
CREATE OR REPLACE VIEW public.admin_platform_content_blocks AS
SELECT
  pcb.block_key AS id,
  pcb.block_key,
  pcb.block_type,
  pcb.title,
  pcb.content,
  pcb.target_channel,
  pcb.is_active,
  pcb.sort_order,
  pcb.feature_key,
  pf.display_name AS feature_display_name,
  pcb.placement_key,
  pcb.metadata,
  pcb.created_at,
  pcb.updated_at
FROM public.platform_content_blocks pcb
LEFT JOIN public.platform_features pf
  ON pf.feature_key = pcb.feature_key
WHERE public.is_active_admin_operator(auth.uid());

DROP VIEW IF EXISTS public.platform_feature_audit_logs;
CREATE OR REPLACE VIEW public.platform_feature_audit_logs AS
SELECT
  aal.id,
  aal.admin_user_id,
  aal.action,
  aal.module,
  aal.target_type,
  aal.target_id,
  aal.before_state,
  aal.after_state,
  aal.metadata,
  aal.created_at,
  au.display_name AS admin_name,
  au.phone AS admin_phone
FROM public.admin_audit_logs aal
LEFT JOIN public.admin_users au
  ON au.id = aal.admin_user_id
WHERE aal.module = 'platform-control'
  AND public.is_active_admin_operator(auth.uid());

ALTER VIEW public.admin_platform_features OWNER TO postgres;
ALTER VIEW public.admin_platform_content_blocks OWNER TO postgres;
ALTER VIEW public.platform_feature_audit_logs OWNER TO postgres;

DROP TRIGGER IF EXISTS platform_features_audit_write ON public.platform_features;
CREATE TRIGGER platform_features_audit_write
AFTER INSERT OR UPDATE OR DELETE ON public.platform_features
FOR EACH ROW
EXECUTE FUNCTION public.log_platform_control_change();

DROP TRIGGER IF EXISTS platform_feature_rules_audit_write ON public.platform_feature_rules;
CREATE TRIGGER platform_feature_rules_audit_write
AFTER INSERT OR UPDATE OR DELETE ON public.platform_feature_rules
FOR EACH ROW
EXECUTE FUNCTION public.log_platform_control_change();

DROP TRIGGER IF EXISTS platform_feature_channels_audit_write ON public.platform_feature_channels;
CREATE TRIGGER platform_feature_channels_audit_write
AFTER INSERT OR UPDATE OR DELETE ON public.platform_feature_channels
FOR EACH ROW
EXECUTE FUNCTION public.log_platform_control_change();

DROP TRIGGER IF EXISTS platform_content_blocks_audit_write ON public.platform_content_blocks;
CREATE TRIGGER platform_content_blocks_audit_write
AFTER INSERT OR UPDATE OR DELETE ON public.platform_content_blocks
FOR EACH ROW
EXECUTE FUNCTION public.log_platform_control_change();

DROP TRIGGER IF EXISTS platform_features_sync_feature_flags_write ON public.platform_features;
CREATE TRIGGER platform_features_sync_feature_flags_write
AFTER INSERT OR UPDATE OR DELETE ON public.platform_features
FOR EACH ROW
EXECUTE FUNCTION public.sync_legacy_feature_flags_on_platform_write();

DROP TRIGGER IF EXISTS platform_feature_rules_sync_feature_flags_write ON public.platform_feature_rules;
CREATE TRIGGER platform_feature_rules_sync_feature_flags_write
AFTER INSERT OR UPDATE OR DELETE ON public.platform_feature_rules
FOR EACH ROW
EXECUTE FUNCTION public.sync_legacy_feature_flags_on_platform_write();

DROP TRIGGER IF EXISTS platform_feature_channels_sync_feature_flags_write ON public.platform_feature_channels;
CREATE TRIGGER platform_feature_channels_sync_feature_flags_write
AFTER INSERT OR UPDATE OR DELETE ON public.platform_feature_channels
FOR EACH ROW
EXECUTE FUNCTION public.sync_legacy_feature_flags_on_platform_write();

ALTER TABLE public.platform_features ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_feature_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_feature_channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_content_blocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins manage platform features"
ON public.platform_features
TO authenticated
USING (public.is_admin_manager(auth.uid()))
WITH CHECK (public.is_admin_manager(auth.uid()));

CREATE POLICY "Admins manage platform feature rules"
ON public.platform_feature_rules
TO authenticated
USING (public.is_admin_manager(auth.uid()))
WITH CHECK (public.is_admin_manager(auth.uid()));

CREATE POLICY "Admins manage platform feature channels"
ON public.platform_feature_channels
TO authenticated
USING (public.is_admin_manager(auth.uid()))
WITH CHECK (public.is_admin_manager(auth.uid()));

CREATE POLICY "Admins manage platform content blocks"
ON public.platform_content_blocks
TO authenticated
USING (public.is_admin_manager(auth.uid()))
WITH CHECK (public.is_admin_manager(auth.uid()));

GRANT ALL ON TABLE public.platform_features TO authenticated, service_role;
GRANT ALL ON TABLE public.platform_feature_rules TO authenticated, service_role;
GRANT ALL ON TABLE public.platform_feature_channels TO authenticated, service_role;
GRANT ALL ON TABLE public.platform_content_blocks TO authenticated, service_role;
GRANT SELECT ON TABLE public.admin_platform_features TO authenticated, service_role;
GRANT SELECT ON TABLE public.admin_platform_content_blocks TO authenticated, service_role;
GRANT SELECT ON TABLE public.platform_feature_audit_logs TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.platform_feature_status_is_live(text, timestamptz, timestamptz, timestamptz) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.request_platform_channel() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.resolve_platform_feature(text, text, boolean, timestamptz) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assert_platform_feature_available(text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sync_legacy_feature_flags_from_platform(text) TO service_role;

INSERT INTO public.platform_features (
  feature_key,
  display_name,
  description,
  status,
  is_enabled,
  navigation_group,
  default_route_key,
  admin_notes
) VALUES
  ('home_feed', 'Home Feed', 'Primary home and discovery surface for match activity.', 'active', true, 'primary', '/', 'Core home surface.'),
  ('fixtures', 'Fixtures', 'Match listings, schedules, and match discovery.', 'active', true, 'primary', '/fixtures', 'Backed by app_matches and fixture flows.'),
  ('predictions', 'Predictions', 'Lean prediction engine, entries, and consensus.', 'active', true, 'primary', '/predict', 'Operationally managed feature.'),
  ('leaderboard', 'Leaderboard', 'Ranking and competitive progression surfaces.', 'active', true, 'secondary', '/leaderboard', 'Can be hidden without disabling predictions.'),
  ('wallet', 'Wallet', 'FET balances, transfers, and wallet activity.', 'active', true, 'secondary', '/wallet', 'Operationally sensitive feature.'),
  ('profile', 'Profile', 'Identity, account shortcuts, and user hub.', 'active', true, 'secondary', '/profile', 'Core authenticated and guest profile surface.'),
  ('notifications', 'Notifications', 'Notification center and inbox surfaces.', 'active', true, 'secondary', '/notifications', 'Includes notification read state and pushes.'),
  ('settings', 'Settings', 'Preference and privacy management.', 'active', true, 'secondary', '/settings', 'Core utility surface.'),
  ('onboarding', 'Onboarding', 'Initial onboarding and favorite-team setup.', 'active', true, 'secondary', '/onboarding', 'Core first-session surface.'),
  ('match_center', 'Match Center', 'Match detail, insights, and team context surfaces.', 'active', true, 'secondary', '/match/:matchId', 'Driven by fixtures and prediction data.'),
  ('fan_portal', 'Fan Portal', 'Future fan portal experience.', 'inactive', false, 'future', NULL, 'Reserved registry entry for future rollout.'),
  ('membership', 'Membership', 'Future membership product surface.', 'inactive', false, 'future', NULL, 'Reserved registry entry for future rollout.'),
  ('challenge', 'Challenge', 'Future challenge experiences.', 'inactive', false, 'future', NULL, 'Reserved registry entry for future rollout.'),
  ('support_circles', 'Support Circles', 'Future support-circle communities.', 'inactive', false, 'future', NULL, 'Reserved registry entry for future rollout.'),
  ('fan_clubs', 'Fan Clubs', 'Future fan-club hubs.', 'inactive', false, 'future', NULL, 'Reserved registry entry for future rollout.'),
  ('community', 'Community', 'Future community experiences.', 'inactive', false, 'future', NULL, 'Reserved registry entry for future rollout.'),
  ('marketplace', 'Marketplace', 'Future marketplace and redemption surfaces.', 'inactive', false, 'future', NULL, 'Reserved registry entry for future rollout.'),
  ('club_news', 'Club News', 'Future club-news content surface.', 'inactive', false, 'future', NULL, 'Reserved registry entry for future rollout.'),
  ('squad', 'Squad', 'Future squad content surface.', 'inactive', false, 'future', NULL, 'Reserved registry entry for future rollout.'),
  ('shop', 'Shop', 'Future commerce storefront.', 'inactive', false, 'future', NULL, 'Reserved registry entry for future rollout.'),
  ('campaigns', 'Campaigns', 'Future campaigns and promotional journeys.', 'inactive', false, 'future', NULL, 'Reserved registry entry for future rollout.'),
  ('payments', 'Payments', 'Future payment and checkout infrastructure.', 'inactive', false, 'future', NULL, 'Reserved registry entry for future rollout.')
ON CONFLICT (feature_key) DO UPDATE
SET display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    status = EXCLUDED.status,
    is_enabled = EXCLUDED.is_enabled,
    navigation_group = EXCLUDED.navigation_group,
    default_route_key = EXCLUDED.default_route_key,
    admin_notes = EXCLUDED.admin_notes,
    updated_at = timezone('utc', now());

INSERT INTO public.platform_feature_rules (
  feature_key,
  auth_required,
  dependency_config,
  rollout_config,
  metadata
) VALUES
  ('home_feed', false, '{}'::jsonb, '{}'::jsonb, '{}'::jsonb),
  ('fixtures', false, '{}'::jsonb, '{}'::jsonb, '{}'::jsonb),
  ('predictions', true, jsonb_build_object('requires_all', jsonb_build_array('fixtures')), '{}'::jsonb, jsonb_build_object('guarded_actions', jsonb_build_array('submit_user_prediction'))),
  ('leaderboard', false, jsonb_build_object('requires_all', jsonb_build_array('predictions')), '{}'::jsonb, '{}'::jsonb),
  ('wallet', true, '{}'::jsonb, '{}'::jsonb, jsonb_build_object('guarded_actions', jsonb_build_array('transfer_fet_by_fan_id', 'transfer_fet'))),
  ('profile', false, '{}'::jsonb, '{}'::jsonb, '{}'::jsonb),
  ('notifications', true, '{}'::jsonb, '{}'::jsonb, jsonb_build_object('guarded_actions', jsonb_build_array('mark_notification_read', 'mark_all_notifications_read'))),
  ('settings', false, '{}'::jsonb, '{}'::jsonb, '{}'::jsonb),
  ('onboarding', false, '{}'::jsonb, '{}'::jsonb, '{}'::jsonb),
  ('match_center', false, jsonb_build_object('requires_all', jsonb_build_array('fixtures')), '{}'::jsonb, '{}'::jsonb)
ON CONFLICT (feature_key) DO UPDATE
SET auth_required = EXCLUDED.auth_required,
    dependency_config = EXCLUDED.dependency_config,
    rollout_config = EXCLUDED.rollout_config,
    metadata = EXCLUDED.metadata,
    updated_at = timezone('utc', now());

INSERT INTO public.platform_feature_channels (
  feature_key,
  channel,
  is_visible,
  is_enabled,
  show_in_navigation,
  show_on_home,
  sort_order,
  route_key,
  entry_key,
  navigation_label,
  placement_key
) VALUES
  ('home_feed', 'mobile', true, true, true, true, 10, '/', 'home.feed', 'Home', 'primary-nav'),
  ('home_feed', 'web', true, true, true, true, 10, '/', 'home.feed', 'Home', 'primary-nav'),
  ('fixtures', 'mobile', true, true, true, true, 20, '/fixtures', 'fixtures.index', 'Fixtures', 'primary-nav'),
  ('fixtures', 'web', true, true, true, true, 20, '/fixtures', 'fixtures.index', 'Fixtures', 'primary-nav'),
  ('predictions', 'mobile', true, true, true, true, 30, '/predict', 'predictions.index', 'Predict', 'primary-nav'),
  ('predictions', 'web', true, true, false, true, 30, '/match/:matchId', 'predictions.index', 'Predictions', 'home-secondary'),
  ('leaderboard', 'mobile', true, true, false, false, 40, '/leaderboard', 'leaderboard.index', 'Leaderboard', 'secondary-nav'),
  ('leaderboard', 'web', true, true, true, false, 40, '/leaderboard', 'leaderboard.index', 'Leaderboard', 'primary-nav'),
  ('wallet', 'mobile', true, true, false, false, 50, '/wallet', 'wallet.index', 'Wallet', 'secondary-nav'),
  ('wallet', 'web', true, true, true, false, 50, '/wallet', 'wallet.index', 'Wallet', 'primary-nav'),
  ('profile', 'mobile', true, true, true, false, 60, '/profile', 'profile.index', 'Profile', 'primary-nav'),
  ('profile', 'web', true, true, true, false, 60, '/profile', 'profile.index', 'Profile', 'primary-nav'),
  ('notifications', 'mobile', true, true, false, false, 70, '/notifications', 'notifications.index', 'Notifications', 'profile-links'),
  ('notifications', 'web', true, true, false, false, 70, '/notifications', 'notifications.index', 'Notifications', 'profile-links'),
  ('settings', 'mobile', true, true, false, false, 80, '/settings', 'settings.index', 'Settings', 'profile-links'),
  ('settings', 'web', true, true, false, false, 80, '/settings', 'settings.index', 'Settings', 'profile-links'),
  ('onboarding', 'mobile', true, true, false, false, 90, '/onboarding', 'onboarding.index', 'Onboarding', 'system'),
  ('onboarding', 'web', true, true, false, false, 90, '/onboarding', 'onboarding.index', 'Onboarding', 'system'),
  ('match_center', 'mobile', true, true, false, false, 100, '/match/:matchId', 'match.detail', 'Match Center', 'fixtures-detail'),
  ('match_center', 'web', true, true, false, false, 100, '/match/:matchId', 'match.detail', 'Match Center', 'fixtures-detail')
ON CONFLICT (feature_key, channel) DO UPDATE
SET is_visible = EXCLUDED.is_visible,
    is_enabled = EXCLUDED.is_enabled,
    show_in_navigation = EXCLUDED.show_in_navigation,
    show_on_home = EXCLUDED.show_on_home,
    sort_order = EXCLUDED.sort_order,
    route_key = EXCLUDED.route_key,
    entry_key = EXCLUDED.entry_key,
    navigation_label = EXCLUDED.navigation_label,
    placement_key = EXCLUDED.placement_key,
    updated_at = timezone('utc', now());

INSERT INTO public.platform_content_blocks (
  block_key,
  block_type,
  title,
  content,
  target_channel,
  is_active,
  sort_order,
  feature_key,
  placement_key
) VALUES
  (
    'home_promo_banner',
    'promo_banner',
    'Lean Matchday Window',
    jsonb_build_object(
      'badge', 'DERBY DAY',
      'kicker', 'Global',
      'subtitle', 'Live fixtures, free picks, and leaderboard movement are synced now.',
      'cta_label', 'Open Picks',
      'cta_route', '/predict'
    ),
    'both',
    true,
    10,
    'predictions',
    'home.primary'
  ),
  (
    'home_live_matches',
    'live_matches',
    'Live Action',
    jsonb_build_object(
      'empty_title', 'No Live Matches',
      'empty_description', 'Check upcoming.'
    ),
    'both',
    true,
    20,
    'fixtures',
    'home.primary'
  ),
  (
    'home_upcoming_matches',
    'upcoming_matches',
    'Upcoming',
    jsonb_build_object(
      'empty_title', 'No Upcoming',
      'empty_description', 'None left.',
      'cta_route', '/fixtures'
    ),
    'both',
    true,
    30,
    'fixtures',
    'home.primary'
  ),
  (
    'home_daily_insight',
    'daily_insight',
    'Daily Insight',
    jsonb_build_object(
      'subtitle', 'Track live fixtures, lock free picks, and follow the leaderboard from one place.'
    ),
    'both',
    true,
    15,
    'predictions',
    'home.primary'
  )
ON CONFLICT (block_key) DO UPDATE
SET block_type = EXCLUDED.block_type,
    title = EXCLUDED.title,
    content = EXCLUDED.content,
    target_channel = EXCLUDED.target_channel,
    is_active = EXCLUDED.is_active,
    sort_order = EXCLUDED.sort_order,
    feature_key = EXCLUDED.feature_key,
    placement_key = EXCLUDED.placement_key,
    updated_at = timezone('utc', now());

SELECT public.sync_legacy_feature_flags_from_platform(feature_key)
FROM public.platform_features;

CREATE OR REPLACE FUNCTION public.get_app_bootstrap_config(
  p_market text DEFAULT 'global'::text,
  p_platform text DEFAULT 'all'::text
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_channel text := CASE
    WHEN p_platform IN ('android', 'ios') THEN 'mobile'
    WHEN p_platform = 'web' THEN 'web'
    ELSE 'web'
  END;
  v_result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'regions', (
      SELECT coalesce(
        jsonb_agg(
          jsonb_build_object(
            'country_code', crm.country_code,
            'region', crm.region,
            'country_name', crm.country_name,
            'flag_emoji', crm.flag_emoji
          )
          ORDER BY crm.country_name
        ),
        '[]'::jsonb
      )
      FROM public.country_region_map crm
    ),
    'phone_presets', (
      SELECT coalesce(
        jsonb_agg(
          jsonb_build_object(
            'country_code', pp.country_code,
            'dial_code', pp.dial_code,
            'hint', pp.hint,
            'min_digits', pp.min_digits
          )
          ORDER BY pp.country_code
        ),
        '[]'::jsonb
      )
      FROM public.phone_presets pp
    ),
    'currency_display', (
      SELECT coalesce(
        jsonb_agg(
          jsonb_build_object(
            'currency_code', cdm.currency_code,
            'symbol', cdm.symbol,
            'decimals', cdm.decimals,
            'space_separated', cdm.space_separated
          )
          ORDER BY cdm.currency_code
        ),
        '[]'::jsonb
      )
      FROM public.currency_display_metadata cdm
    ),
    'country_currency_map', (
      SELECT coalesce(
        jsonb_agg(
          jsonb_build_object(
            'country_code', ccm.country_code,
            'currency_code', ccm.currency_code,
            'country_name', ccm.country_name
          )
          ORDER BY ccm.country_code
        ),
        '[]'::jsonb
      )
      FROM public.country_currency_map ccm
    ),
    'feature_flags', (
      SELECT coalesce(
        jsonb_object_agg(resolved.key, resolved.enabled),
        '{}'::jsonb
      )
      FROM (
        SELECT DISTINCT ON (ff.key)
          ff.key,
          ff.enabled
        FROM public.feature_flags ff
        WHERE (ff.market = p_market OR ff.market = 'global')
          AND (ff.platform = p_platform OR ff.platform = 'all')
        ORDER BY
          ff.key,
          CASE WHEN ff.market = p_market THEN 1 ELSE 0 END DESC,
          CASE WHEN ff.platform = p_platform THEN 1 ELSE 0 END DESC,
          ff.updated_at DESC
      ) AS resolved
    ),
    'app_config', (
      SELECT coalesce(
        jsonb_object_agg(acr.key, acr.value),
        '{}'::jsonb
      )
      FROM public.app_config_remote acr
    ),
    'launch_moments', (
      SELECT coalesce(
        jsonb_agg(
          jsonb_build_object(
            'tag', lm.tag,
            'title', lm.title,
            'subtitle', lm.subtitle,
            'kicker', lm.kicker,
            'region_key', lm.region_key
          )
          ORDER BY lm.sort_order
        ),
        '[]'::jsonb
      )
      FROM public.launch_moments lm
      WHERE lm.is_active = true
    ),
    'platform_features', (
      SELECT coalesce(
        jsonb_agg(feature_row.feature_json ORDER BY feature_row.sort_order, feature_row.display_name),
        '[]'::jsonb
      )
      FROM (
        SELECT
          pf.display_name,
          least(
            coalesce(pfc_mobile.sort_order, 999),
            coalesce(pfc_web.sort_order, 999)
          ) AS sort_order,
          jsonb_build_object(
            'feature_key', pf.feature_key,
            'display_name', pf.display_name,
            'description', pf.description,
            'status', pf.status,
            'is_enabled', pf.is_enabled,
            'navigation_group', pf.navigation_group,
            'default_route_key', pf.default_route_key,
            'admin_notes', pf.admin_notes,
            'metadata', coalesce(pf.metadata, '{}'::jsonb),
            'auth_required', coalesce(pfr.auth_required, false),
            'role_restrictions', coalesce(pfr.role_restrictions, '[]'::jsonb),
            'dependency_config', coalesce(pfr.dependency_config, '{}'::jsonb),
            'rollout_config', coalesce(pfr.rollout_config, '{}'::jsonb),
            'schedule_start_at', pfr.schedule_start_at,
            'schedule_end_at', pfr.schedule_end_at,
            'channels', jsonb_build_object(
              'mobile', jsonb_build_object(
                'channel', 'mobile',
                'is_visible', coalesce(pfc_mobile.is_visible, false),
                'is_enabled', coalesce(pfc_mobile.is_enabled, false),
                'show_in_navigation', coalesce(pfc_mobile.show_in_navigation, false),
                'show_on_home', coalesce(pfc_mobile.show_on_home, false),
                'sort_order', coalesce(pfc_mobile.sort_order, 100),
                'route_key', pfc_mobile.route_key,
                'entry_key', pfc_mobile.entry_key,
                'navigation_label', pfc_mobile.navigation_label,
                'placement_key', pfc_mobile.placement_key,
                'metadata', coalesce(pfc_mobile.metadata, '{}'::jsonb)
              ),
              'web', jsonb_build_object(
                'channel', 'web',
                'is_visible', coalesce(pfc_web.is_visible, false),
                'is_enabled', coalesce(pfc_web.is_enabled, false),
                'show_in_navigation', coalesce(pfc_web.show_in_navigation, false),
                'show_on_home', coalesce(pfc_web.show_on_home, false),
                'sort_order', coalesce(pfc_web.sort_order, 100),
                'route_key', pfc_web.route_key,
                'entry_key', pfc_web.entry_key,
                'navigation_label', pfc_web.navigation_label,
                'placement_key', pfc_web.placement_key,
                'metadata', coalesce(pfc_web.metadata, '{}'::jsonb)
              )
            ),
            'resolved_state', public.resolve_platform_feature(
              pf.feature_key,
              v_channel,
              auth.uid() IS NOT NULL
            )
          ) AS feature_json
        FROM public.platform_features pf
        LEFT JOIN public.platform_feature_rules pfr
          ON pfr.feature_key = pf.feature_key
        LEFT JOIN public.platform_feature_channels pfc_mobile
          ON pfc_mobile.feature_key = pf.feature_key
         AND pfc_mobile.channel = 'mobile'
        LEFT JOIN public.platform_feature_channels pfc_web
          ON pfc_web.feature_key = pf.feature_key
         AND pfc_web.channel = 'web'
      ) AS feature_row
    ),
    'platform_content_blocks', (
      SELECT coalesce(
        jsonb_agg(
          jsonb_build_object(
            'block_key', pcb.block_key,
            'block_type', pcb.block_type,
            'title', pcb.title,
            'content', pcb.content,
            'target_channel', pcb.target_channel,
            'is_active', pcb.is_active,
            'sort_order', pcb.sort_order,
            'feature_key', pcb.feature_key,
            'placement_key', pcb.placement_key,
            'metadata', pcb.metadata
          )
          ORDER BY pcb.sort_order, pcb.block_key
        ),
        '[]'::jsonb
      )
      FROM public.platform_content_blocks pcb
      WHERE pcb.is_active = true
        AND (pcb.target_channel = v_channel OR pcb.target_channel = 'both')
        AND (
          pcb.feature_key IS NULL
          OR coalesce(
            (
              public.resolve_platform_feature(
                pcb.feature_key,
                v_channel,
                auth.uid() IS NOT NULL
              ) ->> 'is_visible'
            )::boolean,
            false
          )
        )
    )
  )
  INTO v_result;

  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_all_notifications_read()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  PERFORM public.assert_platform_feature_available(
    'notifications',
    public.request_platform_channel()
  );

  UPDATE public.user_notifications
  SET read_at = coalesce(read_at, now())
  WHERE user_id = auth.uid()
    AND read_at IS NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_notification_read(
  p_notification_id uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  PERFORM public.assert_platform_feature_available(
    'notifications',
    public.request_platform_channel()
  );

  UPDATE public.user_notifications
  SET read_at = coalesce(read_at, now())
  WHERE id = p_notification_id
    AND user_id = auth.uid();
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_user_prediction(
  p_match_id text,
  p_predicted_result_code text DEFAULT NULL::text,
  p_predicted_over25 boolean DEFAULT NULL::boolean,
  p_predicted_btts boolean DEFAULT NULL::boolean,
  p_predicted_home_goals integer DEFAULT NULL::integer,
  p_predicted_away_goals integer DEFAULT NULL::integer
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_user_id uuid;
  v_match record;
  v_prediction_id uuid;
  v_result_code text;
  v_score_result_code text;
BEGIN
  PERFORM public.assert_platform_feature_available(
    'predictions',
    public.request_platform_channel()
  );

  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT id, match_date, match_status
  INTO v_match
  FROM public.matches
  WHERE id = p_match_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match % not found', p_match_id;
  END IF;

  IF v_match.match_date <= now() OR v_match.match_status <> 'scheduled' THEN
    RAISE EXCEPTION 'Predictions are closed for this match';
  END IF;

  v_result_code := CASE
    WHEN p_predicted_result_code IS NULL OR trim(p_predicted_result_code) = '' THEN NULL
    ELSE upper(trim(p_predicted_result_code))
  END;

  IF v_result_code IS NOT NULL AND v_result_code NOT IN ('H', 'D', 'A') THEN
    RAISE EXCEPTION 'predicted_result_code must be H, D, or A';
  END IF;

  IF (p_predicted_home_goals IS NULL) <> (p_predicted_away_goals IS NULL) THEN
    RAISE EXCEPTION 'predicted_home_goals and predicted_away_goals must be provided together';
  END IF;

  IF p_predicted_home_goals IS NOT NULL AND p_predicted_home_goals < 0 THEN
    RAISE EXCEPTION 'predicted_home_goals must be non-negative';
  END IF;

  IF p_predicted_away_goals IS NOT NULL AND p_predicted_away_goals < 0 THEN
    RAISE EXCEPTION 'predicted_away_goals must be non-negative';
  END IF;

  IF p_predicted_home_goals IS NOT NULL AND p_predicted_away_goals IS NOT NULL THEN
    v_score_result_code := public.compute_result_code(
      p_predicted_home_goals,
      p_predicted_away_goals
    );

    IF v_result_code IS NULL THEN
      v_result_code := v_score_result_code;
    ELSIF v_result_code <> v_score_result_code THEN
      RAISE EXCEPTION 'predicted_result_code must match the supplied exact score';
    END IF;
  END IF;

  IF v_result_code IS NULL
    AND p_predicted_over25 IS NULL
    AND p_predicted_btts IS NULL
    AND p_predicted_home_goals IS NULL
    AND p_predicted_away_goals IS NULL
  THEN
    RAISE EXCEPTION 'At least one prediction input is required';
  END IF;

  INSERT INTO public.user_predictions (
    user_id,
    match_id,
    predicted_result_code,
    predicted_over25,
    predicted_btts,
    predicted_home_goals,
    predicted_away_goals,
    points_awarded,
    reward_status,
    created_at,
    updated_at
  )
  VALUES (
    v_user_id,
    p_match_id,
    v_result_code,
    p_predicted_over25,
    p_predicted_btts,
    p_predicted_home_goals,
    p_predicted_away_goals,
    0,
    'pending',
    now(),
    now()
  )
  ON CONFLICT (user_id, match_id) DO UPDATE SET
    predicted_result_code = EXCLUDED.predicted_result_code,
    predicted_over25 = EXCLUDED.predicted_over25,
    predicted_btts = EXCLUDED.predicted_btts,
    predicted_home_goals = EXCLUDED.predicted_home_goals,
    predicted_away_goals = EXCLUDED.predicted_away_goals,
    points_awarded = 0,
    reward_status = 'pending',
    updated_at = now()
  RETURNING id INTO v_prediction_id;

  RETURN v_prediction_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.transfer_fet(
  p_recipient_identifier text,
  p_amount_fet bigint
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $_$
DECLARE
  v_clean_fan_id text := regexp_replace(coalesce(p_recipient_identifier, ''), '[^0-9]', '', 'g');
BEGIN
  PERFORM public.assert_platform_feature_available(
    'wallet',
    public.request_platform_channel()
  );

  IF v_clean_fan_id !~ '^\d{6}$' THEN
    RAISE EXCEPTION 'Recipient Fan ID must be exactly 6 digits';
  END IF;

  RETURN public.transfer_fet_by_fan_id(v_clean_fan_id, p_amount_fet);
END;
$_$;

CREATE OR REPLACE FUNCTION public.transfer_fet_by_fan_id(
  p_recipient_fan_id text,
  p_amount_fet bigint
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $_$
DECLARE
  v_sender_id uuid := auth.uid();
  v_sender_fan_id text;
  v_recipient_id uuid;
  v_sender_balance bigint;
  v_recipient_balance_before bigint := 0;
  v_daily_limit integer := greatest(
    least(
      coalesce(public.app_config_bigint('wallet_transfer_daily_limit', 10), 10),
      2147483647
    )::integer,
    1
  );
  v_clean_fan_id text := regexp_replace(coalesce(p_recipient_fan_id, ''), '[^0-9]', '', 'g');
BEGIN
  PERFORM public.assert_platform_feature_available(
    'wallet',
    public.request_platform_channel()
  );

  IF v_sender_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  PERFORM public.assert_wallet_available(v_sender_id);

  IF NOT public.check_rate_limit(v_sender_id, 'transfer_fet', v_daily_limit, interval '1 day') THEN
    RAISE EXCEPTION 'Rate limit exceeded — max % transfers per day', v_daily_limit;
  END IF;

  IF p_amount_fet IS NULL OR p_amount_fet <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than zero';
  END IF;

  IF v_clean_fan_id !~ '^\d{6}$' THEN
    RAISE EXCEPTION 'Recipient Fan ID must be exactly 6 digits';
  END IF;

  SELECT fan_id
  INTO v_sender_fan_id
  FROM public.profiles
  WHERE id = v_sender_id OR user_id = v_sender_id
  LIMIT 1;

  IF v_sender_fan_id IS NULL THEN
    UPDATE public.profiles
    SET fan_id = public.generate_profile_fan_id(v_sender_id::text, 0, id)
    WHERE id = v_sender_id OR user_id = v_sender_id;

    SELECT fan_id
    INTO v_sender_fan_id
    FROM public.profiles
    WHERE id = v_sender_id OR user_id = v_sender_id
    LIMIT 1;
  END IF;

  IF v_sender_fan_id = v_clean_fan_id THEN
    RAISE EXCEPTION 'You cannot transfer tokens to yourself.';
  END IF;

  SELECT coalesce(user_id, id)
  INTO v_recipient_id
  FROM public.profiles
  WHERE fan_id = v_clean_fan_id
  LIMIT 1;

  IF v_recipient_id IS NULL THEN
    RAISE EXCEPTION 'Fan ID not found. Please check the number and try again.';
  END IF;

  SELECT available_balance_fet
  INTO v_sender_balance
  FROM public.fet_wallets
  WHERE user_id = v_sender_id
  FOR UPDATE;

  IF v_sender_balance IS NULL OR v_sender_balance < p_amount_fet THEN
    RAISE EXCEPTION 'Insufficient balance';
  END IF;

  INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
  VALUES (v_recipient_id, 0, 0)
  ON CONFLICT (user_id) DO NOTHING;

  SELECT available_balance_fet
  INTO v_recipient_balance_before
  FROM public.fet_wallets
  WHERE user_id = v_recipient_id
  FOR UPDATE;

  UPDATE public.fet_wallets
  SET available_balance_fet = available_balance_fet - p_amount_fet,
      updated_at = now()
  WHERE user_id = v_sender_id;

  UPDATE public.fet_wallets
  SET available_balance_fet = available_balance_fet + p_amount_fet,
      updated_at = now()
  WHERE user_id = v_recipient_id;

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
  ) VALUES
    (
      v_sender_id,
      'transfer',
      'debit',
      p_amount_fet,
      v_sender_balance,
      v_sender_balance - p_amount_fet,
      'transfer',
      v_clean_fan_id,
      'Transfer to Fan #' || v_clean_fan_id
    ),
    (
      v_recipient_id,
      'transfer',
      'credit',
      p_amount_fet,
      coalesce(v_recipient_balance_before, 0),
      coalesce(v_recipient_balance_before, 0) + p_amount_fet,
      'transfer',
      v_sender_fan_id,
      'Transfer from Fan #' || coalesce(v_sender_fan_id, '000000')
    );

  RETURN jsonb_build_object(
    'success', true,
    'recipient_fan_id', v_clean_fan_id,
    'amount_fet', p_amount_fet
  );
END;
$_$;

COMMIT;
