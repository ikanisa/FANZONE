-- ============================================================
-- 20260418143000_admin_console_data_plane.sql
-- Harden the admin console data plane while tolerating partial installs.
-- ============================================================

BEGIN;

-- -----------------------------------------------------------------
-- Admin role helpers
-- -----------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.is_active_admin_operator(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_user_id IS NULL OR to_regclass('public.admin_users') IS NULL THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.admin_users
    WHERE user_id = p_user_id
      AND is_active = true
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.is_admin_manager(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_user_id IS NULL OR to_regclass('public.admin_users') IS NULL THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.admin_users
    WHERE user_id = p_user_id
      AND is_active = true
      AND role IN ('super_admin', 'admin')
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.is_super_admin_user(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_user_id IS NULL OR to_regclass('public.admin_users') IS NULL THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.admin_users
    WHERE user_id = p_user_id
      AND is_active = true
      AND role = 'super_admin'
  );
END;
$$;

-- -----------------------------------------------------------------
-- Missing admin RLS policies
-- -----------------------------------------------------------------

DO $$
BEGIN
  IF to_regclass('public.admin_users') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS "Active admins read admin directory" ON public.admin_users';
    EXECUTE 'CREATE POLICY "Active admins read admin directory"
      ON public.admin_users FOR SELECT
      TO authenticated
      USING (public.is_active_admin_operator(auth.uid()))';

    EXECUTE 'DROP POLICY IF EXISTS "Super admins manage admin directory" ON public.admin_users';
    EXECUTE 'CREATE POLICY "Super admins manage admin directory"
      ON public.admin_users FOR ALL
      TO authenticated
      USING (public.is_super_admin_user(auth.uid()))
      WITH CHECK (public.is_super_admin_user(auth.uid()))';
  END IF;

  IF to_regclass('public.admin_feature_flags') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.admin_feature_flags ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS "Admins manage feature flags" ON public.admin_feature_flags';
    EXECUTE 'CREATE POLICY "Admins manage feature flags"
      ON public.admin_feature_flags FOR ALL
      TO authenticated
      USING (public.is_admin_manager(auth.uid()))
      WITH CHECK (public.is_admin_manager(auth.uid()))';
  END IF;

  IF to_regclass('public.admin_notes') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.admin_notes ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS "Admins manage notes" ON public.admin_notes';
    EXECUTE 'CREATE POLICY "Admins manage notes"
      ON public.admin_notes FOR ALL
      TO authenticated
      USING (public.is_admin_manager(auth.uid()))
      WITH CHECK (public.is_admin_manager(auth.uid()))';
  END IF;

  IF to_regclass('public.partners') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.partners ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS "Admins manage partners" ON public.partners';
    EXECUTE 'CREATE POLICY "Admins manage partners"
      ON public.partners FOR ALL
      TO authenticated
      USING (public.is_admin_manager(auth.uid()))
      WITH CHECK (public.is_admin_manager(auth.uid()))';
  END IF;

  IF to_regclass('public.rewards') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.rewards ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS "Admins manage rewards" ON public.rewards';
    EXECUTE 'CREATE POLICY "Admins manage rewards"
      ON public.rewards FOR ALL
      TO authenticated
      USING (public.is_admin_manager(auth.uid()))
      WITH CHECK (public.is_admin_manager(auth.uid()))';
  END IF;

  IF to_regclass('public.redemptions') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.redemptions ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS "Admins read redemptions" ON public.redemptions';
    EXECUTE 'CREATE POLICY "Admins read redemptions"
      ON public.redemptions FOR SELECT
      TO authenticated
      USING (public.is_active_admin_operator(auth.uid()))';

    EXECUTE 'DROP POLICY IF EXISTS "Admins update redemptions" ON public.redemptions';
    EXECUTE 'CREATE POLICY "Admins update redemptions"
      ON public.redemptions FOR UPDATE
      TO authenticated
      USING (public.is_admin_manager(auth.uid()))
      WITH CHECK (public.is_admin_manager(auth.uid()))';
  END IF;

  IF to_regclass('public.content_banners') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.content_banners ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS "Admins manage content banners" ON public.content_banners';
    EXECUTE 'CREATE POLICY "Admins manage content banners"
      ON public.content_banners FOR ALL
      TO authenticated
      USING (public.is_admin_manager(auth.uid()))
      WITH CHECK (public.is_admin_manager(auth.uid()))';
  END IF;

  IF to_regclass('public.campaigns') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.campaigns ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS "Admins read campaigns" ON public.campaigns';
    EXECUTE 'CREATE POLICY "Admins read campaigns"
      ON public.campaigns FOR SELECT
      TO authenticated
      USING (public.is_active_admin_operator(auth.uid()))';

    EXECUTE 'DROP POLICY IF EXISTS "Admins manage campaigns" ON public.campaigns';
    EXECUTE 'CREATE POLICY "Admins manage campaigns"
      ON public.campaigns FOR ALL
      TO authenticated
      USING (public.is_admin_manager(auth.uid()))
      WITH CHECK (public.is_admin_manager(auth.uid()))';
  END IF;

  IF to_regclass('public.moderation_reports') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.moderation_reports ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS "Admins read moderation reports" ON public.moderation_reports';
    EXECUTE 'CREATE POLICY "Admins read moderation reports"
      ON public.moderation_reports FOR SELECT
      TO authenticated
      USING (public.is_active_admin_operator(auth.uid()))';

    EXECUTE 'DROP POLICY IF EXISTS "Admins manage moderation reports" ON public.moderation_reports';
    EXECUTE 'CREATE POLICY "Admins manage moderation reports"
      ON public.moderation_reports FOR ALL
      TO authenticated
      USING (public.is_admin_manager(auth.uid()))
      WITH CHECK (public.is_admin_manager(auth.uid()))';
  END IF;
END;
$$;

-- -----------------------------------------------------------------
-- Admin-facing enriched views
-- -----------------------------------------------------------------

DO $$
BEGIN
  IF to_regclass('public.fet_wallets') IS NOT NULL
     AND to_regclass('public.user_status') IS NOT NULL THEN
    IF to_regclass('public.fan_profiles') IS NOT NULL THEN
      EXECUTE $view$
        CREATE OR REPLACE VIEW public.user_profiles_admin AS
        SELECT
          u.id,
          u.email,
          u.phone,
          (
            coalesce(u.raw_user_meta_data, '{}'::jsonb) ||
            jsonb_strip_nulls(
              jsonb_build_object(
                'display_name',
                coalesce(
                  nullif(trim(fp.display_name), ''),
                  nullif(trim(u.raw_user_meta_data->>'display_name'), ''),
                  nullif(trim(u.raw_user_meta_data->>'full_name'), ''),
                  nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
                  nullif(u.phone, '')
                ),
                'is_banned', coalesce(us.is_banned, false),
                'is_suspended', coalesce(us.is_suspended, false),
                'wallet_frozen', coalesce(us.wallet_frozen, false),
                'ban_reason', us.ban_reason,
                'suspend_reason', us.suspend_reason,
                'wallet_freeze_reason', us.wallet_freeze_reason
              )
            )
          ) AS raw_user_meta_data,
          u.created_at,
          u.last_sign_in_at,
          coalesce(fw.available_balance_fet, 0)::bigint AS available_balance_fet,
          coalesce(fw.locked_balance_fet, 0)::bigint AS locked_balance_fet,
          coalesce(
            nullif(trim(fp.display_name), ''),
            nullif(trim(u.raw_user_meta_data->>'display_name'), ''),
            nullif(trim(u.raw_user_meta_data->>'full_name'), ''),
            nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
            nullif(u.phone, ''),
            u.id::text
          ) AS display_name,
          CASE
            WHEN coalesce(us.wallet_frozen, false) THEN 'frozen'
            WHEN coalesce(us.is_banned, false)
              AND (us.banned_until IS NULL OR us.banned_until > timezone('utc', now()))
              THEN 'banned'
            WHEN coalesce(us.is_suspended, false)
              AND (us.suspended_until IS NULL OR us.suspended_until > timezone('utc', now()))
              THEN 'suspended'
            ELSE 'active'
          END AS status,
          us.ban_reason,
          us.suspend_reason,
          us.wallet_freeze_reason
        FROM auth.users u
        LEFT JOIN public.fan_profiles fp
          ON fp.user_id = u.id
        LEFT JOIN public.fet_wallets fw
          ON fw.user_id = u.id
        LEFT JOIN public.user_status us
          ON us.user_id = u.id
        WHERE public.is_active_admin_operator(auth.uid())
      $view$;

      EXECUTE $view$
        CREATE OR REPLACE VIEW public.wallet_overview_admin AS
        SELECT
          fw.user_id,
          coalesce(
            nullif(trim(fp.display_name), ''),
            nullif(trim(u.raw_user_meta_data->>'display_name'), ''),
            nullif(trim(u.raw_user_meta_data->>'full_name'), ''),
            nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
            nullif(u.phone, ''),
            fw.user_id::text
          ) AS display_name,
          u.email,
          u.phone,
          CASE
            WHEN coalesce(us.wallet_frozen, false) THEN 'frozen'
            WHEN coalesce(us.is_banned, false)
              AND (us.banned_until IS NULL OR us.banned_until > timezone('utc', now()))
              THEN 'banned'
            WHEN coalesce(us.is_suspended, false)
              AND (us.suspended_until IS NULL OR us.suspended_until > timezone('utc', now()))
              THEN 'suspended'
            ELSE 'active'
          END AS status,
          us.wallet_freeze_reason,
          fw.available_balance_fet,
          fw.locked_balance_fet,
          fw.updated_at,
          fw.created_at
        FROM public.fet_wallets fw
        LEFT JOIN auth.users u
          ON u.id = fw.user_id
        LEFT JOIN public.fan_profiles fp
          ON fp.user_id = fw.user_id
        LEFT JOIN public.user_status us
          ON us.user_id = fw.user_id
        WHERE public.is_active_admin_operator(auth.uid())
      $view$;

      EXECUTE $view$
        CREATE OR REPLACE VIEW public.fet_transactions_admin AS
        SELECT
          tx.*,
          coalesce(
            nullif(trim(fp.display_name), ''),
            nullif(trim(u.raw_user_meta_data->>'display_name'), ''),
            nullif(trim(u.raw_user_meta_data->>'full_name'), ''),
            nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
            nullif(u.phone, ''),
            tx.user_id::text
          ) AS display_name,
          coalesce((tx.metadata->>'flagged')::boolean, false) AS flagged
        FROM public.fet_wallet_transactions tx
        LEFT JOIN auth.users u
          ON u.id = tx.user_id
        LEFT JOIN public.fan_profiles fp
          ON fp.user_id = tx.user_id
        WHERE public.is_active_admin_operator(auth.uid())
      $view$;
    ELSE
      EXECUTE $view$
        CREATE OR REPLACE VIEW public.user_profiles_admin AS
        SELECT
          u.id,
          u.email,
          u.phone,
          (
            coalesce(u.raw_user_meta_data, '{}'::jsonb) ||
            jsonb_strip_nulls(
              jsonb_build_object(
                'display_name',
                coalesce(
                  nullif(trim(u.raw_user_meta_data->>'display_name'), ''),
                  nullif(trim(u.raw_user_meta_data->>'full_name'), ''),
                  nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
                  nullif(u.phone, '')
                ),
                'is_banned', coalesce(us.is_banned, false),
                'is_suspended', coalesce(us.is_suspended, false),
                'wallet_frozen', coalesce(us.wallet_frozen, false),
                'ban_reason', us.ban_reason,
                'suspend_reason', us.suspend_reason,
                'wallet_freeze_reason', us.wallet_freeze_reason
              )
            )
          ) AS raw_user_meta_data,
          u.created_at,
          u.last_sign_in_at,
          coalesce(fw.available_balance_fet, 0)::bigint AS available_balance_fet,
          coalesce(fw.locked_balance_fet, 0)::bigint AS locked_balance_fet,
          coalesce(
            nullif(trim(u.raw_user_meta_data->>'display_name'), ''),
            nullif(trim(u.raw_user_meta_data->>'full_name'), ''),
            nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
            nullif(u.phone, ''),
            u.id::text
          ) AS display_name,
          CASE
            WHEN coalesce(us.wallet_frozen, false) THEN 'frozen'
            WHEN coalesce(us.is_banned, false)
              AND (us.banned_until IS NULL OR us.banned_until > timezone('utc', now()))
              THEN 'banned'
            WHEN coalesce(us.is_suspended, false)
              AND (us.suspended_until IS NULL OR us.suspended_until > timezone('utc', now()))
              THEN 'suspended'
            ELSE 'active'
          END AS status,
          us.ban_reason,
          us.suspend_reason,
          us.wallet_freeze_reason
        FROM auth.users u
        LEFT JOIN public.fet_wallets fw
          ON fw.user_id = u.id
        LEFT JOIN public.user_status us
          ON us.user_id = u.id
        WHERE public.is_active_admin_operator(auth.uid())
      $view$;

      EXECUTE $view$
        CREATE OR REPLACE VIEW public.wallet_overview_admin AS
        SELECT
          fw.user_id,
          coalesce(
            nullif(trim(u.raw_user_meta_data->>'display_name'), ''),
            nullif(trim(u.raw_user_meta_data->>'full_name'), ''),
            nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
            nullif(u.phone, ''),
            fw.user_id::text
          ) AS display_name,
          u.email,
          u.phone,
          CASE
            WHEN coalesce(us.wallet_frozen, false) THEN 'frozen'
            WHEN coalesce(us.is_banned, false)
              AND (us.banned_until IS NULL OR us.banned_until > timezone('utc', now()))
              THEN 'banned'
            WHEN coalesce(us.is_suspended, false)
              AND (us.suspended_until IS NULL OR us.suspended_until > timezone('utc', now()))
              THEN 'suspended'
            ELSE 'active'
          END AS status,
          us.wallet_freeze_reason,
          fw.available_balance_fet,
          fw.locked_balance_fet,
          fw.updated_at,
          fw.created_at
        FROM public.fet_wallets fw
        LEFT JOIN auth.users u
          ON u.id = fw.user_id
        LEFT JOIN public.user_status us
          ON us.user_id = fw.user_id
        WHERE public.is_active_admin_operator(auth.uid())
      $view$;

      EXECUTE $view$
        CREATE OR REPLACE VIEW public.fet_transactions_admin AS
        SELECT
          tx.*,
          coalesce(
            nullif(trim(u.raw_user_meta_data->>'display_name'), ''),
            nullif(trim(u.raw_user_meta_data->>'full_name'), ''),
            nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
            nullif(u.phone, ''),
            tx.user_id::text
          ) AS display_name,
          coalesce((tx.metadata->>'flagged')::boolean, false) AS flagged
        FROM public.fet_wallet_transactions tx
        LEFT JOIN auth.users u
          ON u.id = tx.user_id
        WHERE public.is_active_admin_operator(auth.uid())
      $view$;
    END IF;
  END IF;

  IF to_regclass('public.admin_audit_logs') IS NOT NULL
     AND to_regclass('public.admin_users') IS NOT NULL THEN
    EXECUTE $view$
      CREATE OR REPLACE VIEW public.admin_audit_logs_enriched AS
      SELECT
        al.*,
        au.display_name AS admin_name,
        au.email AS admin_email
      FROM public.admin_audit_logs al
      LEFT JOIN public.admin_users au
        ON au.id = al.admin_user_id
      WHERE public.is_active_admin_operator(auth.uid())
    $view$;
  END IF;
END;
$$;

DO $$
BEGIN
  IF to_regclass('public.user_profiles_admin') IS NOT NULL THEN
    EXECUTE 'GRANT SELECT ON public.user_profiles_admin TO authenticated';
  END IF;

  IF to_regclass('public.wallet_overview_admin') IS NOT NULL THEN
    EXECUTE 'GRANT SELECT ON public.wallet_overview_admin TO authenticated';
  END IF;

  IF to_regclass('public.fet_transactions_admin') IS NOT NULL THEN
    EXECUTE 'GRANT SELECT ON public.fet_transactions_admin TO authenticated';
  END IF;

  IF to_regclass('public.admin_audit_logs_enriched') IS NOT NULL THEN
    EXECUTE 'GRANT SELECT ON public.admin_audit_logs_enriched TO authenticated';
  END IF;
END;
$$;

-- -----------------------------------------------------------------
-- Dashboard + analytics RPCs
-- -----------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.admin_dashboard_kpis()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_active_users bigint := 0;
  v_active_pools bigint := 0;
  v_total_fet_issued numeric := 0;
  v_fet_transferred_24h bigint := 0;
  v_pending_redemptions bigint := 0;
  v_moderation_alerts bigint := 0;
  v_competitions_count bigint := 0;
  v_upcoming_fixtures bigint := 0;
BEGIN
  PERFORM public.require_active_admin_user();

  EXECUTE $sql$
    SELECT count(*)::bigint
    FROM auth.users
    WHERE last_sign_in_at >= timezone('utc', now()) - interval '30 days'
  $sql$
  INTO v_active_users;

  IF to_regclass('public.prediction_challenges') IS NOT NULL THEN
    EXECUTE $sql$
      SELECT count(*)::bigint
      FROM public.prediction_challenges
      WHERE status IN ('open', 'locked')
    $sql$
    INTO v_active_pools;
  END IF;

  IF to_regclass('public.fet_supply_overview') IS NOT NULL THEN
    EXECUTE 'SELECT coalesce(total_supply, 0) FROM public.fet_supply_overview'
    INTO v_total_fet_issued;
  END IF;

  IF to_regclass('public.fet_wallet_transactions') IS NOT NULL THEN
    EXECUTE $sql$
      SELECT coalesce(sum(amount_fet)::bigint, 0)
      FROM public.fet_wallet_transactions
      WHERE direction = 'debit'
        AND tx_type IN ('transfer', 'transfer_fet')
        AND created_at >= timezone('utc', now()) - interval '24 hours'
    $sql$
    INTO v_fet_transferred_24h;
  END IF;

  IF to_regclass('public.redemptions') IS NOT NULL THEN
    EXECUTE $sql$
      SELECT coalesce(count(*)::bigint, 0)
      FROM public.redemptions
      WHERE status = 'pending'
    $sql$
    INTO v_pending_redemptions;
  END IF;

  IF to_regclass('public.marketplace_redemptions') IS NOT NULL THEN
    v_pending_redemptions := v_pending_redemptions + coalesce((
      SELECT count(*)::bigint
      FROM public.marketplace_redemptions
      WHERE status IN ('pending', 'approved')
    ), 0);
  END IF;

  IF to_regclass('public.moderation_reports') IS NOT NULL THEN
    EXECUTE $sql$
      SELECT coalesce(count(*)::bigint, 0)
      FROM public.moderation_reports
      WHERE status IN ('open', 'investigating', 'escalated')
    $sql$
    INTO v_moderation_alerts;
  END IF;

  IF to_regclass('public.competitions') IS NOT NULL THEN
    EXECUTE 'SELECT count(*)::bigint FROM public.competitions'
    INTO v_competitions_count;
  END IF;

  IF to_regclass('public.matches') IS NOT NULL THEN
    EXECUTE $sql$
      SELECT count(*)::bigint
      FROM public.matches
      WHERE status IN ('upcoming', 'scheduled')
         OR (status = 'live' AND date >= timezone('utc', now()))
    $sql$
    INTO v_upcoming_fixtures;
  END IF;

  RETURN jsonb_build_object(
    'activeUsers', coalesce(v_active_users, 0),
    'activePools', coalesce(v_active_pools, 0),
    'totalFetIssued', coalesce(v_total_fet_issued, 0),
    'fetTransferred24h', coalesce(v_fet_transferred_24h, 0),
    'pendingRedemptions', coalesce(v_pending_redemptions, 0),
    'moderationAlerts', coalesce(v_moderation_alerts, 0),
    'competitionsCount', coalesce(v_competitions_count, 0),
    'upcomingFixtures', coalesce(v_upcoming_fixtures, 0)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_engagement_kpis()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  WITH _auth AS (
    SELECT public.require_active_admin_user()
  ),
  activity AS (
    SELECT u.id AS user_id, timezone('utc', u.last_sign_in_at) AS activity_at
    FROM auth.users u
    WHERE u.last_sign_in_at IS NOT NULL

    UNION ALL

    SELECT user_id, timezone('utc', joined_at)
    FROM public.prediction_challenge_entries

    UNION ALL

    SELECT user_id, timezone('utc', submitted_at)
    FROM public.daily_challenge_entries

    UNION ALL

    SELECT user_id, timezone('utc', submitted_at)
    FROM public.prediction_slips

    UNION ALL

    SELECT user_id, timezone('utc', created_at)
    FROM public.fet_wallet_transactions
  )
  SELECT jsonb_build_object(
    'dau',
    coalesce((
      SELECT count(DISTINCT user_id)::bigint
      FROM activity
      WHERE activity_at >= timezone('utc', now()) - interval '1 day'
    ), 0),
    'wau',
    coalesce((
      SELECT count(DISTINCT user_id)::bigint
      FROM activity
      WHERE activity_at >= timezone('utc', now()) - interval '7 days'
    ), 0),
    'mau',
    coalesce((
      SELECT count(DISTINCT user_id)::bigint
      FROM activity
      WHERE activity_at >= timezone('utc', now()) - interval '30 days'
    ), 0),
    'predictions7d',
    coalesce((
      SELECT (
        coalesce((SELECT count(*)::bigint FROM public.prediction_slips WHERE submitted_at >= timezone('utc', now()) - interval '7 days'), 0) +
        coalesce((SELECT count(*)::bigint FROM public.prediction_challenge_entries WHERE joined_at >= timezone('utc', now()) - interval '7 days'), 0) +
        coalesce((SELECT count(*)::bigint FROM public.daily_challenge_entries WHERE submitted_at >= timezone('utc', now()) - interval '7 days'), 0)
      )
    ), 0),
    'fetVolume7d',
    coalesce((
      SELECT sum(amount_fet)::bigint
      FROM public.fet_wallet_transactions
      WHERE created_at >= timezone('utc', now()) - interval '7 days'
        AND direction = 'debit'
        AND tx_type IN (
          'transfer',
          'transfer_fet',
          'pool_stake',
          'challenge_stake',
          'contribution',
          'team_contribution',
          'redemption'
        )
    ), 0)
  );
$$;

CREATE OR REPLACE FUNCTION public.admin_engagement_daily(p_days integer DEFAULT 7)
RETURNS TABLE(day text, dau bigint, predictions bigint, pools bigint)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  WITH _auth AS (
    SELECT public.require_active_admin_user()
  ),
  bounds AS (
    SELECT greatest(coalesce(p_days, 7), 1) AS total_days
  ),
  days AS (
    SELECT gs::date AS bucket_date
    FROM bounds,
    generate_series(
      current_date - ((SELECT total_days FROM bounds) - 1),
      current_date,
      interval '1 day'
    ) AS gs
  ),
  activity AS (
    SELECT timezone('utc', last_sign_in_at)::date AS bucket_date, id AS user_id
    FROM auth.users
    WHERE last_sign_in_at IS NOT NULL

    UNION ALL

    SELECT timezone('utc', joined_at)::date AS bucket_date, user_id
    FROM public.prediction_challenge_entries

    UNION ALL

    SELECT timezone('utc', submitted_at)::date AS bucket_date, user_id
    FROM public.daily_challenge_entries

    UNION ALL

    SELECT timezone('utc', submitted_at)::date AS bucket_date, user_id
    FROM public.prediction_slips

    UNION ALL

    SELECT timezone('utc', created_at)::date AS bucket_date, user_id
    FROM public.fet_wallet_transactions
  ),
  prediction_counts AS (
    SELECT bucket_date, sum(total)::bigint AS total
    FROM (
      SELECT timezone('utc', submitted_at)::date AS bucket_date, count(*)::bigint AS total
      FROM public.prediction_slips
      GROUP BY 1

      UNION ALL

      SELECT timezone('utc', joined_at)::date AS bucket_date, count(*)::bigint AS total
      FROM public.prediction_challenge_entries
      GROUP BY 1

      UNION ALL

      SELECT timezone('utc', submitted_at)::date AS bucket_date, count(*)::bigint AS total
      FROM public.daily_challenge_entries
      GROUP BY 1
    ) source_counts
    GROUP BY 1
  ),
  pool_counts AS (
    SELECT timezone('utc', created_at)::date AS bucket_date, count(*)::bigint AS total
    FROM public.prediction_challenges
    GROUP BY 1
  )
  SELECT
    to_char(d.bucket_date, 'Dy') AS day,
    coalesce(count(DISTINCT a.user_id), 0)::bigint AS dau,
    coalesce(max(pc.total), 0)::bigint AS predictions,
    coalesce(max(pool.total), 0)::bigint AS pools
  FROM days d
  LEFT JOIN activity a
    ON a.bucket_date = d.bucket_date
  LEFT JOIN prediction_counts pc
    ON pc.bucket_date = d.bucket_date
  LEFT JOIN pool_counts pool
    ON pool.bucket_date = d.bucket_date
  GROUP BY d.bucket_date
  ORDER BY d.bucket_date;
$$;

CREATE OR REPLACE FUNCTION public.admin_fet_flow_weekly(p_weeks integer DEFAULT 4)
RETURNS TABLE(week text, issued bigint, transferred bigint, redeemed bigint, staked bigint)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  WITH _auth AS (
    SELECT public.require_active_admin_user()
  ),
  bounds AS (
    SELECT greatest(coalesce(p_weeks, 4), 1) AS total_weeks
  ),
  weeks AS (
    SELECT gs::date AS bucket_week
    FROM bounds,
    generate_series(
      date_trunc('week', timezone('utc', now()))::date - (((SELECT total_weeks FROM bounds) - 1) * 7),
      date_trunc('week', timezone('utc', now()))::date,
      interval '1 week'
    ) AS gs
  ),
  tx AS (
    SELECT
      date_trunc('week', timezone('utc', created_at))::date AS bucket_week,
      tx_type,
      direction,
      amount_fet,
      reference_type
    FROM public.fet_wallet_transactions
  )
  SELECT
    'W' || to_char(w.bucket_week, 'IW') AS week,
    coalesce(sum(
      CASE
        WHEN tx.direction = 'credit'
         AND tx.tx_type IN ('foundation_grant', 'admin_credit', 'prediction_earn', 'daily_challenge')
          THEN tx.amount_fet
        ELSE 0
      END
    ), 0)::bigint AS issued,
    coalesce(sum(
      CASE
        WHEN tx.direction = 'debit'
         AND tx.tx_type IN ('transfer', 'transfer_fet')
          THEN tx.amount_fet
        ELSE 0
      END
    ), 0)::bigint AS transferred,
    coalesce(sum(
      CASE
        WHEN tx.direction = 'debit'
         AND (tx.tx_type = 'redemption' OR tx.reference_type = 'marketplace_redemption')
          THEN tx.amount_fet
        ELSE 0
      END
    ), 0)::bigint AS redeemed,
    coalesce(sum(
      CASE
        WHEN tx.direction = 'debit'
         AND tx.tx_type IN ('pool_stake', 'challenge_stake')
          THEN tx.amount_fet
        ELSE 0
      END
    ), 0)::bigint AS staked
  FROM weeks w
  LEFT JOIN tx
    ON tx.bucket_week = w.bucket_week
  GROUP BY w.bucket_week
  ORDER BY w.bucket_week;
$$;

CREATE OR REPLACE FUNCTION public.admin_competition_distribution(p_days integer DEFAULT 30)
RETURNS TABLE(name text, value integer, color text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  WITH _auth AS (
    SELECT public.require_active_admin_user()
  ),
  cutoff AS (
    SELECT timezone('utc', now()) - make_interval(days => greatest(coalesce(p_days, 30), 1)) AS since_at
  ),
  engagement AS (
    SELECT m.competition_id
    FROM public.prediction_challenge_entries e
    JOIN public.prediction_challenges c
      ON c.id = e.challenge_id
    JOIN public.matches m
      ON m.id = c.match_id
    WHERE e.joined_at >= (SELECT since_at FROM cutoff)

    UNION ALL

    SELECT m.competition_id
    FROM public.prediction_slip_selections s
    JOIN public.matches m
      ON m.id = s.match_id
    WHERE s.created_at >= (SELECT since_at FROM cutoff)

    UNION ALL

    SELECT m.competition_id
    FROM public.daily_challenge_entries e
    JOIN public.daily_challenges dc
      ON dc.id = e.challenge_id
    JOIN public.matches m
      ON m.id = dc.match_id
    WHERE e.submitted_at >= (SELECT since_at FROM cutoff)
  ),
  comp_counts AS (
    SELECT
      coalesce(c.short_name, c.name, 'Other') AS comp_name,
      count(*)::bigint AS interactions
    FROM engagement e
    LEFT JOIN public.competitions c
      ON c.id = e.competition_id
    GROUP BY 1
  ),
  ranked AS (
    SELECT
      comp_name,
      interactions,
      row_number() OVER (ORDER BY interactions DESC, comp_name) AS rn,
      sum(interactions) OVER () AS grand_total
    FROM comp_counts
  ),
  compact AS (
    SELECT comp_name AS name, interactions, grand_total
    FROM ranked
    WHERE rn <= 4

    UNION ALL

    SELECT
      'Other' AS name,
      sum(interactions)::bigint AS interactions,
      max(grand_total)::bigint AS grand_total
    FROM ranked
    WHERE rn > 4
    HAVING sum(interactions) > 0
  )
  SELECT
    name,
    round(
      CASE
        WHEN grand_total > 0 THEN (interactions::numeric / grand_total::numeric) * 100
        ELSE 0
      END
    )::integer AS value,
    CASE
      WHEN lower(name) LIKE '%malta%' OR lower(name) = 'mpl' THEN '#EF4444'
      WHEN lower(name) LIKE '%champions%' OR lower(name) = 'ucl' THEN '#0EA5E9'
      WHEN lower(name) LIKE '%premier%' OR lower(name) = 'epl' THEN '#6366F1'
      WHEN lower(name) LIKE '%liga%' THEN '#F59E0B'
      ELSE '#44403C'
    END AS color
  FROM compact
  ORDER BY value DESC, name;
$$;

-- -----------------------------------------------------------------
-- Campaign dispatch RPC
-- -----------------------------------------------------------------

DO $$
BEGIN
  IF to_regclass('public.campaigns') IS NOT NULL THEN
    EXECUTE $fn$
      CREATE OR REPLACE FUNCTION public.admin_send_campaign(
        p_campaign_id uuid,
        p_force boolean DEFAULT false
      )
      RETURNS jsonb
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path = public, auth
      AS $body$
      DECLARE
        v_admin_user_id uuid;
        v_campaign public.campaigns%ROWTYPE;
        v_include_all boolean := false;
        v_requires_device_token boolean := false;
        v_min_balance bigint;
        v_inactive_days integer;
        v_recipient_ids uuid[] := ARRAY[]::uuid[];
        v_recipient_id uuid;
        v_recipient_count integer := 0;
      BEGIN
        v_admin_user_id := public.require_active_admin_user();

        SELECT *
        INTO v_campaign
        FROM public.campaigns
        WHERE id = p_campaign_id;

        IF NOT FOUND THEN
          RAISE EXCEPTION 'Campaign not found';
        END IF;

        IF v_campaign.status = 'sent' AND NOT p_force THEN
          RAISE EXCEPTION 'Campaign already sent';
        END IF;

        v_include_all := v_campaign.segment IS NULL
          OR v_campaign.segment = '{}'::jsonb
          OR coalesce((v_campaign.segment->>'all_users')::boolean, false);
        v_requires_device_token := v_campaign.type = 'push'
          OR coalesce((v_campaign.segment->>'has_device_token')::boolean, false);
        v_min_balance := nullif(v_campaign.segment->>'min_balance_fet', '')::bigint;
        v_inactive_days := nullif(v_campaign.segment->>'inactive_days', '')::integer;

        SELECT
          coalesce(array_agg(eligible.id ORDER BY eligible.id), ARRAY[]::uuid[]),
          count(*)::integer
        INTO v_recipient_ids, v_recipient_count
        FROM (
          SELECT DISTINCT u.id
          FROM auth.users u
          LEFT JOIN public.fet_wallets fw
            ON fw.user_id = u.id
          LEFT JOIN public.device_tokens dt
            ON dt.user_id = u.id
           AND dt.is_active = true
          WHERE (
            v_include_all
            OR v_min_balance IS NOT NULL
            OR v_inactive_days IS NOT NULL
            OR v_requires_device_token
          )
            AND (
              v_min_balance IS NULL
              OR coalesce(fw.available_balance_fet, 0) + coalesce(fw.locked_balance_fet, 0) >= v_min_balance
            )
            AND (
              v_inactive_days IS NULL
              OR u.last_sign_in_at IS NULL
              OR timezone('utc', u.last_sign_in_at) <= timezone('utc', now()) - make_interval(days => v_inactive_days)
            )
            AND (
              NOT v_requires_device_token
              OR dt.id IS NOT NULL
            )
        ) AS eligible;

        IF v_campaign.type = 'push' THEN
          FOREACH v_recipient_id IN ARRAY v_recipient_ids LOOP
            PERFORM public.send_push_to_user(
              v_recipient_id,
              'marketing',
              v_campaign.title,
              v_campaign.message,
              jsonb_build_object(
                'campaign_id', v_campaign.id,
                'screen', '/profile/notifications'
              )
            );
          END LOOP;
        ELSE
          INSERT INTO public.notification_log (
            user_id,
            type,
            title,
            body,
            data,
            sent_at
          )
          SELECT
            recipient_id,
            'marketing',
            v_campaign.title,
            v_campaign.message,
            jsonb_build_object(
              'campaign_id', v_campaign.id,
              'screen', '/profile/notifications'
            ),
            timezone('utc', now())
          FROM unnest(v_recipient_ids) AS recipient_id;
        END IF;

        UPDATE public.campaigns
        SET status = 'sent',
            sent_at = timezone('utc', now()),
            recipient_count = v_recipient_count,
            updated_at = timezone('utc', now())
        WHERE id = v_campaign.id;

        INSERT INTO public.admin_audit_logs (
          admin_user_id,
          action,
          module,
          target_type,
          target_id,
          after_state,
          metadata
        )
        SELECT
          au.id,
          'send_campaign',
          'notifications',
          'campaign',
          v_campaign.id::text,
          jsonb_build_object(
            'status', 'sent',
            'recipient_count', v_recipient_count,
            'type', v_campaign.type
          ),
          jsonb_build_object(
            'segment', coalesce(v_campaign.segment, '{}'::jsonb),
            'forced', p_force
          )
        FROM public.admin_users au
        WHERE au.user_id = v_admin_user_id;

        RETURN jsonb_build_object(
          'campaign_id', v_campaign.id,
          'status', 'sent',
          'recipient_count', v_recipient_count
        );
      END;
      $body$
    $fn$;
  ELSE
    EXECUTE $fn$
      CREATE OR REPLACE FUNCTION public.admin_send_campaign(
        p_campaign_id uuid,
        p_force boolean DEFAULT false
      )
      RETURNS jsonb
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path = public, auth
      AS $body$
      BEGIN
        PERFORM public.require_active_admin_user();
        RAISE EXCEPTION 'Campaign infrastructure is not available in this deployment';
      END;
      $body$
    $fn$;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_dashboard_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_engagement_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_engagement_daily(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_fet_flow_weekly(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_competition_distribution(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_send_campaign(uuid, boolean) TO authenticated;

COMMIT;
