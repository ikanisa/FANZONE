-- ============================================================
-- 20260418170000_fullstack_gap_closure.sql
-- Close the remaining Supabase bootstrap, policy, and machine-job gaps.
-- ============================================================

BEGIN;

-- -----------------------------------------------------------------
-- Service-role aware admin helper
-- -----------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.is_service_role_request()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role text := nullif(current_setting('request.jwt.claim.role', true), '');
  v_claims text := nullif(current_setting('request.jwt.claims', true), '');
BEGIN
  IF v_role = 'service_role' THEN
    RETURN true;
  END IF;

  IF v_claims IS NOT NULL THEN
    BEGIN
      IF (v_claims::jsonb ->> 'role') = 'service_role' THEN
        RETURN true;
      END IF;
    EXCEPTION
      WHEN others THEN
        RETURN false;
    END;
  END IF;

  RETURN false;
END;
$$;

CREATE OR REPLACE FUNCTION public.require_active_admin_user()
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF public.is_service_role_request() THEN
    RETURN NULL;
  END IF;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT public.is_active_admin_user(v_user_id) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN v_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.is_service_role_request() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_service_role_request() TO authenticated;

-- -----------------------------------------------------------------
-- Schema alignment for admin-managed sports tables
-- -----------------------------------------------------------------

ALTER TABLE public.competitions
  ADD COLUMN IF NOT EXISTS season text;
ALTER TABLE public.competitions
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active';
ALTER TABLE public.competitions
  ADD COLUMN IF NOT EXISTS is_featured boolean NOT NULL DEFAULT false;
ALTER TABLE public.competitions
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_competitions_status
  ON public.competitions (status, is_featured);

DO $$
BEGIN
  IF to_regclass('public.matches') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY';

    IF NOT EXISTS (
      SELECT 1
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'matches'
        AND policyname = 'Admins manage matches'
    ) THEN
      EXECUTE 'CREATE POLICY "Admins manage matches"
        ON public.matches
        FOR ALL
        TO authenticated
        USING (public.is_admin_manager(auth.uid()))
        WITH CHECK (public.is_admin_manager(auth.uid()))';
    END IF;
  END IF;

  IF to_regclass('public.competitions') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.competitions ENABLE ROW LEVEL SECURITY';

    IF NOT EXISTS (
      SELECT 1
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'competitions'
        AND policyname = 'Admins manage competitions'
    ) THEN
      EXECUTE 'CREATE POLICY "Admins manage competitions"
        ON public.competitions
        FOR ALL
        TO authenticated
        USING (public.is_admin_manager(auth.uid()))
        WITH CHECK (public.is_admin_manager(auth.uid()))';
    END IF;
  END IF;

  IF to_regclass('public.prediction_challenge_entries') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.prediction_challenge_entries ENABLE ROW LEVEL SECURITY';

    IF NOT EXISTS (
      SELECT 1
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'prediction_challenge_entries'
        AND policyname = 'Admins read challenge entries'
    ) THEN
      EXECUTE 'CREATE POLICY "Admins read challenge entries"
        ON public.prediction_challenge_entries
        FOR SELECT
        TO authenticated
        USING (public.is_active_admin_operator(auth.uid()))';
    END IF;
  END IF;

  IF to_regclass('public.fet_wallet_transactions') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.fet_wallet_transactions ENABLE ROW LEVEL SECURITY';

    IF NOT EXISTS (
      SELECT 1
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'fet_wallet_transactions'
        AND policyname = 'Admins read wallet transactions'
    ) THEN
      EXECUTE 'CREATE POLICY "Admins read wallet transactions"
        ON public.fet_wallet_transactions
        FOR SELECT
        TO authenticated
        USING (public.is_active_admin_operator(auth.uid()))';
    END IF;
  END IF;

  IF to_regclass('public.notification_log') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.notification_log ENABLE ROW LEVEL SECURITY';

    IF NOT EXISTS (
      SELECT 1
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'notification_log'
        AND policyname = 'Users update own notifications'
    ) THEN
      EXECUTE 'CREATE POLICY "Users update own notifications"
        ON public.notification_log
        FOR UPDATE
        TO authenticated
        USING (auth.uid() = user_id)
        WITH CHECK (auth.uid() = user_id)';
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'notification_log'
        AND policyname = 'Admins read notifications'
    ) THEN
      EXECUTE 'CREATE POLICY "Admins read notifications"
        ON public.notification_log
        FOR SELECT
        TO authenticated
        USING (public.is_active_admin_operator(auth.uid()))';
    END IF;
  END IF;
END;
$$;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.matches TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.competitions TO authenticated;
GRANT SELECT ON public.prediction_challenge_entries TO authenticated;
GRANT SELECT, UPDATE ON public.notification_log TO authenticated;

-- -----------------------------------------------------------------
-- Prediction pool schema alignment for older deployments
-- -----------------------------------------------------------------

ALTER TABLE IF EXISTS public.prediction_challenges
  ADD COLUMN IF NOT EXISTS match_name text NOT NULL DEFAULT '';
ALTER TABLE IF EXISTS public.prediction_challenges
  ADD COLUMN IF NOT EXISTS creator_user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE IF EXISTS public.prediction_challenges
  ADD COLUMN IF NOT EXISTS stake_fet bigint NOT NULL DEFAULT 0;
ALTER TABLE IF EXISTS public.prediction_challenges
  ADD COLUMN IF NOT EXISTS currency_code text NOT NULL DEFAULT 'FET';
ALTER TABLE IF EXISTS public.prediction_challenges
  ADD COLUMN IF NOT EXISTS lock_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE IF EXISTS public.prediction_challenges
  ADD COLUMN IF NOT EXISTS settled_at timestamptz;
ALTER TABLE IF EXISTS public.prediction_challenges
  ADD COLUMN IF NOT EXISTS cancelled_at timestamptz;
ALTER TABLE IF EXISTS public.prediction_challenges
  ADD COLUMN IF NOT EXISTS void_reason text;
ALTER TABLE IF EXISTS public.prediction_challenges
  ADD COLUMN IF NOT EXISTS total_participants integer NOT NULL DEFAULT 0;
ALTER TABLE IF EXISTS public.prediction_challenges
  ADD COLUMN IF NOT EXISTS total_pool_fet bigint NOT NULL DEFAULT 0;
ALTER TABLE IF EXISTS public.prediction_challenges
  ADD COLUMN IF NOT EXISTS winner_count integer;
ALTER TABLE IF EXISTS public.prediction_challenges
  ADD COLUMN IF NOT EXISTS loser_count integer;
ALTER TABLE IF EXISTS public.prediction_challenges
  ADD COLUMN IF NOT EXISTS payout_per_winner_fet bigint;
ALTER TABLE IF EXISTS public.prediction_challenges
  ADD COLUMN IF NOT EXISTS official_home_score integer;
ALTER TABLE IF EXISTS public.prediction_challenges
  ADD COLUMN IF NOT EXISTS official_away_score integer;
ALTER TABLE IF EXISTS public.prediction_challenges
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE IF EXISTS public.prediction_challenge_entries
  ADD COLUMN IF NOT EXISTS stake_fet bigint NOT NULL DEFAULT 0;
ALTER TABLE IF EXISTS public.prediction_challenge_entries
  ADD COLUMN IF NOT EXISTS payout_fet bigint NOT NULL DEFAULT 0;
ALTER TABLE IF EXISTS public.prediction_challenge_entries
  ADD COLUMN IF NOT EXISTS joined_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE IF EXISTS public.prediction_challenge_entries
  ADD COLUMN IF NOT EXISTS settled_at timestamptz;

-- -----------------------------------------------------------------
-- Public-facing derived views expected by the app
-- -----------------------------------------------------------------

DO $$
DECLARE
  v_relkind "char";
BEGIN
  SELECT c.relkind
  INTO v_relkind
  FROM pg_class c
  JOIN pg_namespace n
    ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname = 'challenge_feed';

  IF (v_relkind IS NULL OR v_relkind IN ('v', 'm'))
     AND to_regclass('public.prediction_challenges') IS NOT NULL
     AND to_regclass('public.prediction_challenge_entries') IS NOT NULL
     AND to_regclass('public.matches') IS NOT NULL THEN
    EXECUTE $view$
      CREATE OR REPLACE VIEW public.challenge_feed AS
      SELECT
        pc.id,
        pc.match_id,
        m.home_team,
        m.away_team,
        coalesce(nullif(pc.match_name, ''), m.home_team || ' vs ' || m.away_team) AS match_name,
        pc.creator_user_id,
        coalesce(
          nullif(trim(p.display_name), ''),
          nullif(trim(u.raw_user_meta_data->>'display_name'), ''),
          nullif(trim(u.raw_user_meta_data->>'full_name'), ''),
          nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
          nullif(u.phone, ''),
          'Fan'
        ) AS creator_name,
        coalesce(
          creator_entry.predicted_home_score::text || '-' || creator_entry.predicted_away_score::text,
          ''
        ) AS creator_prediction,
        pc.stake_fet,
        pc.status,
        pc.lock_at,
        pc.settled_at,
        pc.total_participants,
        pc.total_pool_fet,
        pc.winner_count,
        pc.payout_per_winner_fet,
        pc.official_home_score,
        pc.official_away_score,
        m.date,
        m.kickoff_time
      FROM public.prediction_challenges pc
      LEFT JOIN public.matches m
        ON m.id = pc.match_id
      LEFT JOIN public.profiles p
        ON p.id = pc.creator_user_id OR p.user_id = pc.creator_user_id
      LEFT JOIN auth.users u
        ON u.id = pc.creator_user_id
      LEFT JOIN LATERAL (
        SELECT
          e.predicted_home_score,
          e.predicted_away_score
        FROM public.prediction_challenge_entries e
        WHERE e.challenge_id = pc.id
          AND e.user_id = pc.creator_user_id
        ORDER BY e.joined_at ASC, e.id ASC
        LIMIT 1
      ) creator_entry
        ON true
    $view$;
  END IF;
END;
$$;

DO $$
DECLARE
  v_relkind "char";
BEGIN
  SELECT c.relkind
  INTO v_relkind
  FROM pg_class c
  JOIN pg_namespace n
    ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname = 'fan_clubs';

  IF (v_relkind IS NULL OR v_relkind IN ('v', 'm'))
     AND to_regclass('public.teams') IS NOT NULL THEN
    IF to_regclass('public.team_contributions') IS NOT NULL THEN
      EXECUTE $view$
        CREATE OR REPLACE VIEW public.fan_clubs AS
        SELECT
          t.id,
          t.name,
          coalesce(t.fan_count, 0)::integer AS members,
          coalesce(tc.total_pool_fet, 0)::integer AS total_pool,
          coalesce(t.crest_url, t.logo_url, '') AS crest,
          coalesce(t.league_name, '') AS league,
          row_number() OVER (
            ORDER BY coalesce(tc.total_pool_fet, 0) DESC, coalesce(t.fan_count, 0) DESC, t.name
          )::integer AS rank
        FROM public.teams t
        LEFT JOIN (
          SELECT
            team_id,
            sum(amount_fet)::bigint AS total_pool_fet
          FROM public.team_contributions
          WHERE contribution_type = 'fet'
            AND status = 'completed'
          GROUP BY team_id
        ) tc
          ON tc.team_id = t.id
        WHERE coalesce(t.is_active, true)
      $view$;
    ELSE
      EXECUTE $view$
        CREATE OR REPLACE VIEW public.fan_clubs AS
        SELECT
          t.id,
          t.name,
          coalesce(t.fan_count, 0)::integer AS members,
          0::integer AS total_pool,
          coalesce(t.crest_url, t.logo_url, '') AS crest,
          coalesce(t.league_name, '') AS league,
          row_number() OVER (
            ORDER BY coalesce(t.fan_count, 0) DESC, t.name
          )::integer AS rank
        FROM public.teams t
        WHERE coalesce(t.is_active, true)
      $view$;
    END IF;
  END IF;
END;
$$;

GRANT SELECT ON public.challenge_feed TO anon, authenticated;
GRANT SELECT ON public.fan_clubs TO anon, authenticated;

-- -----------------------------------------------------------------
-- Admin-facing aggregate views
-- -----------------------------------------------------------------

DO $$
BEGIN
  IF to_regclass('public.fet_supply_overview') IS NOT NULL THEN
    EXECUTE $view$
      CREATE OR REPLACE VIEW public.fet_supply_overview_admin AS
      SELECT *
      FROM public.fet_supply_overview
      WHERE public.is_active_admin_operator(auth.uid())
    $view$;
  END IF;
END;
$$;

DO $$
BEGIN
  IF to_regclass('public.fet_supply_overview_admin') IS NOT NULL THEN
    EXECUTE 'GRANT SELECT ON public.fet_supply_overview_admin TO authenticated';
  END IF;
END;
$$;

-- -----------------------------------------------------------------
-- Explicit admin workflows for team news + currency refresh
-- -----------------------------------------------------------------

DO $$
BEGIN
  IF to_regclass('public.team_news') IS NOT NULL THEN
    EXECUTE $fn$
      CREATE OR REPLACE FUNCTION public.admin_publish_team_news(p_news_id uuid)
      RETURNS jsonb
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path = public
      AS $body$
      DECLARE
        v_admin_id uuid;
        v_news public.team_news%ROWTYPE;
      BEGIN
        v_admin_id := public.require_active_admin_user();

        IF v_admin_id IS NULL THEN
          RAISE EXCEPTION 'Admin user required';
        END IF;

        UPDATE public.team_news
        SET status = 'published',
            published_at = coalesce(published_at, now()),
            updated_at = now()
        WHERE id = p_news_id
        RETURNING *
        INTO v_news;

        IF v_news.id IS NULL THEN
          RAISE EXCEPTION 'Team news item not found';
        END IF;

        INSERT INTO public.admin_audit_logs (
          admin_user_id,
          action,
          module,
          target_type,
          target_id,
          after_state
        )
        SELECT
          au.id,
          'publish_team_news',
          'team_news',
          'team_news',
          p_news_id::text,
          jsonb_build_object(
            'status', v_news.status,
            'published_at', v_news.published_at,
            'team_id', v_news.team_id
          )
        FROM public.admin_users au
        WHERE au.user_id = v_admin_id;

        RETURN jsonb_build_object(
          'status', v_news.status,
          'id', v_news.id,
          'published_at', v_news.published_at,
          'team_id', v_news.team_id
        );
      END;
      $body$;
    $fn$;
  ELSE
    EXECUTE $fn$
      CREATE OR REPLACE FUNCTION public.admin_publish_team_news(p_news_id uuid)
      RETURNS jsonb
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path = public
      AS $body$
      BEGIN
        RAISE EXCEPTION 'team_news table is not available in this project';
      END;
      $body$;
    $fn$;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_trigger_currency_rate_refresh()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid;
  v_supabase_url text;
  v_service_key text;
  v_sync_secret text;
  v_request_id bigint;
BEGIN
  v_admin_id := public.require_active_admin_user();

  IF v_admin_id IS NULL THEN
    RAISE EXCEPTION 'Admin user required';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_extension
    WHERE extname = 'pg_net'
  ) THEN
    RAISE EXCEPTION 'pg_net is not available';
  END IF;

  v_supabase_url := current_setting('app.settings.supabase_url', true);
  v_service_key := current_setting('app.settings.service_role_key', true);
  v_sync_secret := current_setting('app.settings.currency_sync_secret', true);

  IF v_supabase_url IS NULL OR v_service_key IS NULL THEN
    RAISE EXCEPTION 'Currency refresh settings are not configured';
  END IF;

  SELECT net.http_post(
    url := v_supabase_url || '/functions/v1/gemini-currency-rates',
    headers := jsonb_strip_nulls(
      jsonb_build_object(
        'Authorization', 'Bearer ' || v_service_key,
        'Content-Type', 'application/json',
        'x-currency-sync-secret', v_sync_secret
      )
    ),
    body := '{}'::jsonb
  )
  INTO v_request_id;

  INSERT INTO public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    metadata
  )
  SELECT
    au.id,
    'trigger_currency_rate_refresh',
    'currency_rates',
    'edge_function',
    'gemini-currency-rates',
    jsonb_build_object('request_id', v_request_id)
  FROM public.admin_users au
  WHERE au.user_id = v_admin_id;

  RETURN jsonb_build_object(
    'dispatched', true,
    'request_id', v_request_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_trigger_team_news_ingestion(
  p_team_id text,
  p_team_name text,
  p_categories text[] DEFAULT ARRAY['general'],
  p_max_articles integer DEFAULT 6
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid;
  v_supabase_url text;
  v_service_key text;
  v_sync_secret text;
  v_request_id bigint;
BEGIN
  v_admin_id := public.require_active_admin_user();

  IF v_admin_id IS NULL THEN
    RAISE EXCEPTION 'Admin user required';
  END IF;

  IF coalesce(trim(p_team_id), '') = '' OR coalesce(trim(p_team_name), '') = '' THEN
    RAISE EXCEPTION 'team_id and team_name are required';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_extension
    WHERE extname = 'pg_net'
  ) THEN
    RAISE EXCEPTION 'pg_net is not available';
  END IF;

  v_supabase_url := current_setting('app.settings.supabase_url', true);
  v_service_key := current_setting('app.settings.service_role_key', true);
  v_sync_secret := current_setting('app.settings.team_news_sync_secret', true);

  IF v_supabase_url IS NULL OR v_service_key IS NULL THEN
    RAISE EXCEPTION 'Team news settings are not configured';
  END IF;

  SELECT net.http_post(
    url := v_supabase_url || '/functions/v1/gemini-team-news',
    headers := jsonb_strip_nulls(
      jsonb_build_object(
        'Authorization', 'Bearer ' || v_service_key,
        'Content-Type', 'application/json',
        'x-team-news-sync-secret', v_sync_secret
      )
    ),
    body := jsonb_build_object(
      'teamId', p_team_id,
      'teamName', p_team_name,
      'categories', coalesce(to_jsonb(p_categories), '[]'::jsonb),
      'maxArticles', greatest(coalesce(p_max_articles, 6), 1)
    )
  )
  INTO v_request_id;

  INSERT INTO public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    metadata
  )
  SELECT
    au.id,
    'trigger_team_news_ingestion',
    'team_news',
    'team',
    p_team_id,
    jsonb_build_object(
      'request_id', v_request_id,
      'team_name', p_team_name,
      'max_articles', greatest(coalesce(p_max_articles, 6), 1)
    )
  FROM public.admin_users au
  WHERE au.user_id = v_admin_id;

  RETURN jsonb_build_object(
    'dispatched', true,
    'request_id', v_request_id,
    'team_id', p_team_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_publish_team_news(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_trigger_currency_rate_refresh() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_trigger_team_news_ingestion(text, text, text[], integer) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.admin_publish_team_news(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_trigger_currency_rate_refresh() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_trigger_team_news_ingestion(text, text, text[], integer) TO authenticated;

COMMIT;
