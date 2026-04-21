BEGIN;

-- Guarded hotfix for environments where 20260420030000 is recorded in
-- migration history but its objects are missing on the actual schema.

-- =====================================================================
-- 1. ADMIN POLICY DRIFT / LEGACY COLUMN CLEANUP
-- =====================================================================

DO $$
BEGIN
  IF to_regprocedure('public.is_admin_manager(uuid)') IS NOT NULL THEN
    IF to_regclass('public.competitions') IS NOT NULL THEN
      EXECUTE 'DROP POLICY IF EXISTS "Admin write competitions" ON public.competitions';
      EXECUTE 'CREATE POLICY "Admin write competitions"
        ON public.competitions
        FOR ALL
        TO authenticated
        USING (public.is_admin_manager(auth.uid()))
        WITH CHECK (public.is_admin_manager(auth.uid()))';
    END IF;

    IF to_regclass('public.teams') IS NOT NULL THEN
      EXECUTE 'DROP POLICY IF EXISTS "Admin write teams" ON public.teams';
      EXECUTE 'CREATE POLICY "Admin write teams"
        ON public.teams
        FOR ALL
        TO authenticated
        USING (public.is_admin_manager(auth.uid()))
        WITH CHECK (public.is_admin_manager(auth.uid()))';
    END IF;

    IF to_regclass('public.matches') IS NOT NULL THEN
      EXECUTE 'DROP POLICY IF EXISTS "Admin write matches" ON public.matches';
      EXECUTE 'CREATE POLICY "Admin write matches"
        ON public.matches
        FOR ALL
        TO authenticated
        USING (public.is_admin_manager(auth.uid()))
        WITH CHECK (public.is_admin_manager(auth.uid()))';
    END IF;

    IF to_regclass('public.live_match_events') IS NOT NULL THEN
      EXECUTE 'DROP POLICY IF EXISTS "Admin write live match events" ON public.live_match_events';
      EXECUTE 'CREATE POLICY "Admin write live match events"
        ON public.live_match_events
        FOR ALL
        TO authenticated
        USING (public.is_admin_manager(auth.uid()))
        WITH CHECK (public.is_admin_manager(auth.uid()))';
    END IF;

    IF to_regclass('public.news') IS NOT NULL THEN
      EXECUTE 'DROP POLICY IF EXISTS "Admin write news" ON public.news';
      EXECUTE 'CREATE POLICY "Admin write news"
        ON public.news
        FOR ALL
        TO authenticated
        USING (public.is_admin_manager(auth.uid()))
        WITH CHECK (public.is_admin_manager(auth.uid()))';
    END IF;

    IF to_regclass('public.feature_flags') IS NOT NULL THEN
      EXECUTE 'DROP POLICY IF EXISTS "Admin write feature flags" ON public.feature_flags';
      EXECUTE 'CREATE POLICY "Admin write feature flags"
        ON public.feature_flags
        FOR ALL
        TO authenticated
        USING (public.is_admin_manager(auth.uid()))
        WITH CHECK (public.is_admin_manager(auth.uid()))';
    END IF;

    IF to_regclass('public.app_config_remote') IS NOT NULL THEN
      EXECUTE 'DROP POLICY IF EXISTS "Admin write app config" ON public.app_config_remote';
      EXECUTE 'CREATE POLICY "Admin write app config"
        ON public.app_config_remote
        FOR ALL
        TO authenticated
        USING (public.is_admin_manager(auth.uid()))
        WITH CHECK (public.is_admin_manager(auth.uid()))';
    END IF;

    IF to_regclass('public.launch_moments') IS NOT NULL THEN
      EXECUTE 'DROP POLICY IF EXISTS "Admin write launch moments" ON public.launch_moments';
      EXECUTE 'CREATE POLICY "Admin write launch moments"
        ON public.launch_moments
        FOR ALL
        TO authenticated
        USING (public.is_admin_manager(auth.uid()))
        WITH CHECK (public.is_admin_manager(auth.uid()))';
    END IF;
  END IF;
END $$;

ALTER TABLE IF EXISTS public.profiles DROP COLUMN IF EXISTS is_admin;

-- =====================================================================
-- 2. MISSING FOREIGN KEYS / INTEGRITY HARDENING
-- =====================================================================

DO $$
BEGIN
  IF to_regclass('public.daily_challenge_entries') IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM pg_constraint
       WHERE conname = 'daily_challenge_entries_user_id_auth_fkey'
     ) THEN
    ALTER TABLE public.daily_challenge_entries
      ADD CONSTRAINT daily_challenge_entries_user_id_auth_fkey
      FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE NOT VALID;
    ALTER TABLE public.daily_challenge_entries
      VALIDATE CONSTRAINT daily_challenge_entries_user_id_auth_fkey;
  END IF;

  IF to_regclass('public.notification_log') IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM pg_constraint
       WHERE conname = 'notification_log_user_id_auth_fkey'
     ) THEN
    ALTER TABLE public.notification_log
      ADD CONSTRAINT notification_log_user_id_auth_fkey
      FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE NOT VALID;
    ALTER TABLE public.notification_log
      VALIDATE CONSTRAINT notification_log_user_id_auth_fkey;
  END IF;

  IF to_regclass('public.redemptions') IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM pg_constraint
       WHERE conname = 'redemptions_user_id_auth_fkey'
     ) THEN
    ALTER TABLE public.redemptions
      ADD CONSTRAINT redemptions_user_id_auth_fkey
      FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE NOT VALID;
    ALTER TABLE public.redemptions
      VALIDATE CONSTRAINT redemptions_user_id_auth_fkey;
  END IF;

  IF to_regclass('public.moderation_reports') IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM pg_constraint
       WHERE conname = 'moderation_reports_reporter_auth_fkey'
     ) THEN
    ALTER TABLE public.moderation_reports
      ADD CONSTRAINT moderation_reports_reporter_auth_fkey
      FOREIGN KEY (reporter_user_id) REFERENCES auth.users(id) ON DELETE SET NULL NOT VALID;
    ALTER TABLE public.moderation_reports
      VALIDATE CONSTRAINT moderation_reports_reporter_auth_fkey;
  END IF;
END $$;

-- =====================================================================
-- 3. SECURE ANONYMOUS-UPGRADE CLAIM FLOW
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.anonymous_upgrade_claims (
  anon_user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  claim_token text NOT NULL UNIQUE,
  issued_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  consumed_by_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_anonymous_upgrade_claims_expires
  ON public.anonymous_upgrade_claims (expires_at)
  WHERE consumed_at IS NULL;

ALTER TABLE public.anonymous_upgrade_claims ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.issue_anonymous_upgrade_claim()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
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

  v_claim_token := encode(gen_random_bytes(24), 'hex');

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

REVOKE ALL ON FUNCTION public.issue_anonymous_upgrade_claim() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.issue_anonymous_upgrade_claim() TO authenticated;

CREATE OR REPLACE FUNCTION public.merge_anonymous_to_authenticated_secure(
  p_anon_id uuid,
  p_claim_token text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
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

  IF to_regclass('public.user_favorite_teams') IS NOT NULL THEN
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
  END IF;

  IF to_regclass('public.user_followed_teams') IS NOT NULL THEN
    INSERT INTO public.user_followed_teams (user_id, team_id, created_at)
    SELECT
      v_auth_id,
      uft.team_id,
      uft.created_at
    FROM public.user_followed_teams uft
    WHERE uft.user_id = p_anon_id
      AND NOT EXISTS (
        SELECT 1
        FROM public.user_followed_teams existing
        WHERE existing.user_id = v_auth_id
          AND existing.team_id = uft.team_id
      );
  END IF;

  IF to_regclass('public.user_followed_competitions') IS NOT NULL THEN
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
  END IF;

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

  IF to_regclass('public.user_favorite_teams') IS NOT NULL THEN
    DELETE FROM public.user_favorite_teams WHERE user_id = p_anon_id;
  END IF;
  IF to_regclass('public.user_followed_teams') IS NOT NULL THEN
    DELETE FROM public.user_followed_teams WHERE user_id = p_anon_id;
  END IF;
  IF to_regclass('public.user_followed_competitions') IS NOT NULL THEN
    DELETE FROM public.user_followed_competitions WHERE user_id = p_anon_id;
  END IF;

  DELETE FROM public.profiles WHERE user_id = p_anon_id;
END;
$$;

DO $$
BEGIN
  IF to_regprocedure('public.merge_anonymous_to_authenticated(uuid,uuid)') IS NOT NULL THEN
    EXECUTE 'REVOKE ALL ON FUNCTION public.merge_anonymous_to_authenticated(uuid, uuid) FROM PUBLIC';
    EXECUTE 'REVOKE ALL ON FUNCTION public.merge_anonymous_to_authenticated(uuid, uuid) FROM authenticated';
    EXECUTE 'REVOKE ALL ON FUNCTION public.merge_anonymous_to_authenticated(uuid, uuid) FROM anon';
  END IF;
END $$;

REVOKE ALL ON FUNCTION public.merge_anonymous_to_authenticated_secure(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.merge_anonymous_to_authenticated_secure(uuid, text) TO authenticated;

-- =====================================================================
-- 4. TEAM / COMPETITION NORMALIZATION
-- =====================================================================

DO $$
BEGIN
  IF to_regclass('public.teams') IS NOT NULL AND to_regclass('public.competitions') IS NOT NULL THEN
    CREATE TABLE IF NOT EXISTS public.team_competitions (
      team_id text NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
      competition_id text NOT NULL REFERENCES public.competitions(id) ON DELETE CASCADE,
      is_primary boolean NOT NULL DEFAULT false,
      created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
      PRIMARY KEY (team_id, competition_id)
    );

    CREATE INDEX IF NOT EXISTS idx_team_competitions_competition
      ON public.team_competitions (competition_id, team_id);

    ALTER TABLE public.team_competitions ENABLE ROW LEVEL SECURITY;

    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'team_competitions'
        AND policyname = 'Public read team competitions'
    ) THEN
      CREATE POLICY "Public read team competitions"
        ON public.team_competitions
        FOR SELECT
        USING (true);
    END IF;

    GRANT SELECT ON public.team_competitions TO anon, authenticated;

    INSERT INTO public.team_competitions (team_id, competition_id, is_primary)
    SELECT
      t.id,
      c.id,
      ordinality = 1
    FROM public.teams t,
    LATERAL unnest(coalesce(t.competition_ids, '{}'::text[])) WITH ORDINALITY AS competition_ids(competition_id, ordinality)
    JOIN public.competitions c ON c.id = competition_ids.competition_id
    ON CONFLICT (team_id, competition_id) DO NOTHING;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.sync_team_competitions_from_team_array()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF pg_trigger_depth() > 1 THEN
    RETURN NEW;
  END IF;

  DELETE FROM public.team_competitions WHERE team_id = NEW.id;

  INSERT INTO public.team_competitions (team_id, competition_id, is_primary)
  SELECT
    NEW.id,
    c.id,
    ordinality = 1
  FROM unnest(coalesce(NEW.competition_ids, '{}'::text[])) WITH ORDINALITY AS competition_ids(competition_id, ordinality)
  JOIN public.competitions c ON c.id = competition_ids.competition_id
  ON CONFLICT (team_id, competition_id) DO UPDATE
  SET is_primary = EXCLUDED.is_primary;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_team_array_from_team_competitions()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_team_id text := coalesce(NEW.team_id, OLD.team_id);
BEGIN
  IF pg_trigger_depth() > 1 THEN
    RETURN NULL;
  END IF;

  UPDATE public.teams t
  SET competition_ids = coalesce((
        SELECT array_agg(tc.competition_id ORDER BY tc.is_primary DESC, tc.competition_id)
        FROM public.team_competitions tc
        WHERE tc.team_id = v_team_id
      ), '{}'::text[]),
      updated_at = timezone('utc', now())
  WHERE t.id = v_team_id;

  RETURN NULL;
END;
$$;

DO $$
BEGIN
  IF to_regclass('public.teams') IS NOT NULL AND to_regclass('public.team_competitions') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS sync_team_competitions_from_team_array ON public.teams;
    CREATE TRIGGER sync_team_competitions_from_team_array
    AFTER INSERT OR UPDATE OF competition_ids
    ON public.teams
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_team_competitions_from_team_array();

    DROP TRIGGER IF EXISTS sync_team_array_from_team_competitions ON public.team_competitions;
    CREATE TRIGGER sync_team_array_from_team_competitions
    AFTER INSERT OR UPDATE OR DELETE
    ON public.team_competitions
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_team_array_from_team_competitions();

    DROP VIEW IF EXISTS public.team_catalog_entries;

    CREATE VIEW public.team_catalog_entries AS
    SELECT
      t.id,
      t.name,
      t.short_name,
      null::text AS slug,
      t.country,
      null::text AS description,
      t.league_name,
      coalesce(tc.competition_ids, coalesce(t.competition_ids, '{}'::text[])) AS competition_ids,
      coalesce(t.search_terms, '{}'::text[]) AS aliases,
      t.logo_url,
      t.crest_url,
      null::text AS cover_image_url,
      t.is_active,
      t.is_featured,
      false AS fet_contributions_enabled,
      false AS fiat_contributions_enabled,
      null::text AS fiat_contribution_mode,
      null::text AS fiat_contribution_link,
      0::integer AS fan_count
    FROM public.teams t
    LEFT JOIN (
      SELECT
        team_id,
        array_agg(competition_id ORDER BY is_primary DESC, competition_id) AS competition_ids
      FROM public.team_competitions
      GROUP BY team_id
    ) tc ON tc.team_id = t.id;

    GRANT SELECT ON public.team_catalog_entries TO anon, authenticated;
  END IF;
END $$;

-- =====================================================================
-- 5. GLOBAL CHALLENGE / MATCH NORMALIZATION
-- =====================================================================

DO $$
BEGIN
  IF to_regclass('public.global_challenges') IS NOT NULL AND to_regclass('public.matches') IS NOT NULL THEN
    CREATE TABLE IF NOT EXISTS public.global_challenge_matches (
      challenge_id uuid NOT NULL REFERENCES public.global_challenges(id) ON DELETE CASCADE,
      match_id text NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
      sort_order integer NOT NULL DEFAULT 0,
      created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
      PRIMARY KEY (challenge_id, match_id)
    );

    CREATE INDEX IF NOT EXISTS idx_global_challenge_matches_match
      ON public.global_challenge_matches (match_id, challenge_id);

    ALTER TABLE public.global_challenge_matches ENABLE ROW LEVEL SECURITY;

    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'global_challenge_matches'
        AND policyname = 'Public read global challenge matches'
    ) THEN
      CREATE POLICY "Public read global challenge matches"
        ON public.global_challenge_matches
        FOR SELECT
        USING (true);
    END IF;

    GRANT SELECT ON public.global_challenge_matches TO anon, authenticated;

    INSERT INTO public.global_challenge_matches (challenge_id, match_id, sort_order)
    SELECT
      gc.id,
      match_id,
      ordinality - 1
    FROM public.global_challenges gc,
    LATERAL unnest(coalesce(gc.match_ids, '{}'::text[])) WITH ORDINALITY AS match_ids(match_id, ordinality)
    ON CONFLICT (challenge_id, match_id) DO UPDATE
    SET sort_order = EXCLUDED.sort_order;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.sync_global_challenge_matches_from_array()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF pg_trigger_depth() > 1 THEN
    RETURN NEW;
  END IF;

  DELETE FROM public.global_challenge_matches
  WHERE challenge_id = NEW.id;

  INSERT INTO public.global_challenge_matches (challenge_id, match_id, sort_order)
  SELECT
    NEW.id,
    match_id,
    ordinality - 1
  FROM unnest(coalesce(NEW.match_ids, '{}'::text[])) WITH ORDINALITY AS match_ids(match_id, ordinality)
  ON CONFLICT (challenge_id, match_id) DO UPDATE
  SET sort_order = EXCLUDED.sort_order;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_global_challenge_array_from_matches()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_challenge_id uuid := coalesce(NEW.challenge_id, OLD.challenge_id);
BEGIN
  IF pg_trigger_depth() > 1 THEN
    RETURN NULL;
  END IF;

  UPDATE public.global_challenges gc
  SET match_ids = coalesce((
        SELECT array_agg(gcm.match_id ORDER BY gcm.sort_order, gcm.match_id)
        FROM public.global_challenge_matches gcm
        WHERE gcm.challenge_id = v_challenge_id
      ), '{}'::text[]),
      updated_at = timezone('utc', now())
  WHERE gc.id = v_challenge_id;

  RETURN NULL;
END;
$$;

DO $$
BEGIN
  IF to_regclass('public.global_challenges') IS NOT NULL
     AND to_regclass('public.global_challenge_matches') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS sync_global_challenge_matches_from_array ON public.global_challenges;
    CREATE TRIGGER sync_global_challenge_matches_from_array
    AFTER INSERT OR UPDATE OF match_ids
    ON public.global_challenges
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_global_challenge_matches_from_array();

    DROP TRIGGER IF EXISTS sync_global_challenge_array_from_matches ON public.global_challenge_matches;
    CREATE TRIGGER sync_global_challenge_array_from_matches
    AFTER INSERT OR UPDATE OR DELETE
    ON public.global_challenge_matches
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_global_challenge_array_from_matches();

    CREATE OR REPLACE VIEW public.global_challenge_catalog_entries AS
    SELECT
      gc.id,
      gc.event_tag,
      gc.name,
      gc.description,
      coalesce(gcm.match_ids, coalesce(gc.match_ids, '{}'::text[])) AS match_ids,
      gc.entry_fee_fet,
      gc.prize_pool_fet,
      gc.max_participants,
      gc.current_participants,
      gc.region,
      gc.status,
      gc.start_at,
      gc.end_at,
      gc.created_at,
      gc.slug,
      gc.priority_score,
      gc.audience_regions,
      gc.updated_at
    FROM public.global_challenges gc
    LEFT JOIN (
      SELECT
        challenge_id,
        array_agg(match_id ORDER BY sort_order, match_id) AS match_ids
      FROM public.global_challenge_matches
      GROUP BY challenge_id
    ) gcm ON gcm.challenge_id = gc.id;

    GRANT SELECT ON public.global_challenge_catalog_entries TO anon, authenticated;
  END IF;
END $$;

-- =====================================================================
-- 6. ADMIN FLAG -> PUBLIC FLAG SYNC
-- =====================================================================

CREATE OR REPLACE FUNCTION public.sync_public_feature_flags_from_admin()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_market text;
BEGIN
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  v_market := lower(coalesce(nullif(NEW.market, ''), 'global'));

  INSERT INTO public.feature_flags (
    key,
    market,
    platform,
    enabled,
    description,
    updated_at
  ) VALUES (
    NEW.key,
    v_market,
    'all',
    coalesce(NEW.is_enabled, false),
    coalesce(NEW.description, NEW.label),
    timezone('utc', now())
  )
  ON CONFLICT (key, market, platform) DO UPDATE
  SET enabled = EXCLUDED.enabled,
      description = EXCLUDED.description,
      updated_at = EXCLUDED.updated_at;

  RETURN NEW;
END;
$$;

DO $$
BEGIN
  IF to_regclass('public.admin_feature_flags') IS NOT NULL
     AND to_regclass('public.feature_flags') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS sync_public_feature_flags_from_admin ON public.admin_feature_flags;
    CREATE TRIGGER sync_public_feature_flags_from_admin
    AFTER INSERT OR UPDATE OF is_enabled, market, description, label, key
    ON public.admin_feature_flags
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_public_feature_flags_from_admin();

    INSERT INTO public.feature_flags (
      key,
      market,
      platform,
      enabled,
      description,
      updated_at
    )
    SELECT
      aff.key,
      lower(coalesce(nullif(aff.market, ''), 'global')),
      'all',
      coalesce(aff.is_enabled, false),
      coalesce(aff.description, aff.label),
      timezone('utc', now())
    FROM public.admin_feature_flags aff
    ON CONFLICT (key, market, platform) DO UPDATE
    SET enabled = EXCLUDED.enabled,
        description = EXCLUDED.description,
        updated_at = EXCLUDED.updated_at;
  END IF;
END $$;

-- =====================================================================
-- 7. MATCH ALERT DISPATCH LOG
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.match_alert_dispatch_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  match_id text NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  alert_type text NOT NULL,
  dispatch_key text NOT NULL,
  live_event_id text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  dispatched_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (user_id, match_id, alert_type, dispatch_key)
);

CREATE INDEX IF NOT EXISTS idx_match_alert_dispatch_log_match_type
  ON public.match_alert_dispatch_log (match_id, alert_type, dispatched_at DESC);

CREATE INDEX IF NOT EXISTS idx_match_alert_dispatch_log_user
  ON public.match_alert_dispatch_log (user_id, dispatched_at DESC);

ALTER TABLE public.match_alert_dispatch_log ENABLE ROW LEVEL SECURITY;

COMMIT;
