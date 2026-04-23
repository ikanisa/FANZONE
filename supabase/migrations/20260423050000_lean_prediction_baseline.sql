


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE OR REPLACE FUNCTION "public"."active_admin_record_id"() RETURNS "uuid"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
DECLARE
  v_user_id uuid;
  v_admin_record_id uuid;
BEGIN
  v_user_id := public.require_active_admin_user();

  SELECT id
  INTO v_admin_record_id
  FROM public.admin_users
  WHERE user_id = v_user_id
    AND is_active = true
  LIMIT 1;

  IF v_admin_record_id IS NULL THEN
    RAISE EXCEPTION 'Active admin record not found';
  END IF;

  RETURN v_admin_record_id;
END;
$$;


ALTER FUNCTION "public"."active_admin_record_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_ban_user"("p_target_user_id" "uuid", "p_reason" "text" DEFAULT 'Policy violation'::"text", "p_until" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_admin_id UUID;
BEGIN
  v_admin_id := auth.uid();
  IF NOT EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE user_id = v_admin_id AND is_active = true
      AND role IN ('super_admin', 'admin')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  INSERT INTO public.user_status (user_id, is_banned, banned_until, ban_reason)
  VALUES (p_target_user_id, true, p_until, p_reason)
  ON CONFLICT (user_id) DO UPDATE
  SET is_banned = true,
      banned_until = p_until,
      ban_reason = p_reason,
      updated_at = now();

  INSERT INTO public.admin_audit_logs (
    admin_user_id, action, module, target_type, target_id,
    after_state, metadata
  )
  SELECT au.id, 'ban_user', 'users', 'user', p_target_user_id::text,
    jsonb_build_object('banned', true, 'reason', p_reason, 'until', p_until),
    '{}'::jsonb
  FROM public.admin_users au WHERE au.user_id = v_admin_id;

  RETURN jsonb_build_object('status', 'banned', 'user_id', p_target_user_id);
END;
$$;


ALTER FUNCTION "public"."admin_ban_user"("p_target_user_id" "uuid", "p_reason" "text", "p_until" timestamp with time zone) OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."admin_users" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "email" "text" NOT NULL,
    "display_name" "text" DEFAULT ''::"text" NOT NULL,
    "role" "text" DEFAULT 'admin'::"text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "whatsapp_number" "text",
    "otp_code" character varying(6),
    "otp_expires_at" timestamp with time zone,
    "otp_attempts" integer DEFAULT 0,
    "phone" "text",
    "invited_by" "uuid",
    "last_login_at" timestamp with time zone,
    CONSTRAINT "admin_users_role_check" CHECK (("role" = ANY (ARRAY['super_admin'::"text", 'admin'::"text", 'moderator'::"text", 'viewer'::"text"])))
);


ALTER TABLE "public"."admin_users" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_change_admin_role"("p_admin_id" "uuid", "p_role" "text") RETURNS "public"."admin_users"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_actor_user_id uuid := public.require_super_admin_user();
  v_actor_admin_id uuid;
  v_role text := lower(trim(coalesce(p_role, '')));
  v_existing public.admin_users%ROWTYPE;
  v_result public.admin_users%ROWTYPE;
  v_active_super_admins bigint := 0;
BEGIN
  IF p_admin_id IS NULL THEN
    RAISE EXCEPTION 'Admin id is required';
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

  SELECT *
  INTO v_existing
  FROM public.admin_users
  WHERE id = p_admin_id
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Admin user not found';
  END IF;

  IF v_existing.user_id = v_actor_user_id THEN
    RAISE EXCEPTION 'You cannot change your own admin role';
  END IF;

  IF v_existing.role = 'super_admin' AND v_role <> 'super_admin' AND v_existing.is_active THEN
    SELECT count(*)::bigint
    INTO v_active_super_admins
    FROM public.admin_users
    WHERE is_active = true
      AND role = 'super_admin';

    IF v_active_super_admins <= 1 THEN
      RAISE EXCEPTION 'Cannot demote the last active super admin';
    END IF;
  END IF;

  UPDATE public.admin_users
  SET
    role = v_role,
    updated_at = timezone('utc', now())
  WHERE id = p_admin_id
  RETURNING *
  INTO v_result;

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
    'change_admin_role',
    'admin_access',
    'admin_user',
    v_result.id::text,
    to_jsonb(v_existing),
    to_jsonb(v_result),
    jsonb_build_object('role', v_role)
  );

  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."admin_change_admin_role"("p_admin_id" "uuid", "p_role" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_competition_distribution"("p_days" integer DEFAULT 30) RETURNS TABLE("name" "text", "value" integer, "color" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
  WITH _auth AS (
    SELECT public.require_active_admin_user()
  ),
  cutoff AS (
    SELECT timezone('utc', now()) - make_interval(days => greatest(coalesce(p_days, 30), 1)) AS since_at
  ),
  competition_counts AS (
    SELECT
      coalesce(c.short_name, c.name, 'Other') AS competition_name,
      count(*)::bigint AS prediction_count
    FROM public.user_predictions up
    JOIN public.matches m
      ON m.id = up.match_id
    LEFT JOIN public.competitions c
      ON c.id = m.competition_id
    WHERE up.created_at >= (SELECT since_at FROM cutoff)
    GROUP BY 1
  ),
  ranked AS (
    SELECT
      competition_name,
      prediction_count,
      row_number() OVER (
        ORDER BY prediction_count DESC, competition_name
      ) AS rn,
      sum(prediction_count) OVER () AS grand_total
    FROM competition_counts
  ),
  compact AS (
    SELECT
      competition_name AS name,
      prediction_count,
      grand_total
    FROM ranked
    WHERE rn <= 4

    UNION ALL

    SELECT
      'Other' AS name,
      sum(prediction_count)::bigint AS prediction_count,
      max(grand_total)::bigint AS grand_total
    FROM ranked
    WHERE rn > 4
    HAVING sum(prediction_count) > 0
  )
  SELECT
    name,
    round(
      CASE
        WHEN grand_total > 0
          THEN (prediction_count::numeric / grand_total::numeric) * 100
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


ALTER FUNCTION "public"."admin_competition_distribution"("p_days" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_credit_fet"("p_target_user_id" "uuid", "p_amount" bigint, "p_reason" "text" DEFAULT 'Admin credit'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_admin_id UUID;
  v_balance_before BIGINT;
BEGIN
  v_admin_id := auth.uid();
  IF NOT EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE user_id = v_admin_id AND is_active = true
      AND role IN ('super_admin', 'admin')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be positive';
  END IF;

  SELECT available_balance_fet INTO v_balance_before
  FROM public.fet_wallets
  WHERE user_id = p_target_user_id
  FOR UPDATE;

  INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
  VALUES (p_target_user_id, p_amount, 0)
  ON CONFLICT (user_id) DO UPDATE
  SET available_balance_fet = fet_wallets.available_balance_fet + p_amount,
      updated_at = now();

  INSERT INTO public.fet_wallet_transactions (
    user_id, tx_type, direction, amount_fet,
    balance_before_fet, balance_after_fet,
    reference_type, title
  ) VALUES (
    p_target_user_id, 'admin_credit', 'credit', p_amount,
    COALESCE(v_balance_before, 0),
    COALESCE(v_balance_before, 0) + p_amount,
    'admin_action',
    'Admin credit: ' || COALESCE(p_reason, '')
  );

  INSERT INTO public.admin_audit_logs (
    admin_user_id, action, module, target_type, target_id,
    after_state
  )
  SELECT au.id, 'credit_fet', 'wallets', 'user', p_target_user_id::text,
    jsonb_build_object('amount', p_amount, 'reason', p_reason)
  FROM public.admin_users au WHERE au.user_id = v_admin_id;

  RETURN jsonb_build_object(
    'status', 'credited',
    'user_id', p_target_user_id,
    'amount', p_amount,
    'new_balance', COALESCE(v_balance_before, 0) + p_amount
  );
END;
$$;


ALTER FUNCTION "public"."admin_credit_fet"("p_target_user_id" "uuid", "p_amount" bigint, "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_dashboard_kpis"() RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
DECLARE
  v_active_users bigint := 0;
  v_open_prediction_matches bigint := 0;
  v_total_fet_issued numeric := 0;
  v_fet_transferred_24h bigint := 0;
  v_pending_rewards bigint := 0;
  v_moderation_alerts bigint := 0;
  v_competitions_count bigint := 0;
  v_upcoming_fixtures bigint := 0;
BEGIN
  PERFORM public.require_active_admin_user();

  SELECT count(*)::bigint
  INTO v_active_users
  FROM auth.users
  WHERE last_sign_in_at >= timezone('utc', now()) - interval '30 days';

  SELECT count(*)::bigint
  INTO v_open_prediction_matches
  FROM public.matches
  WHERE coalesce(match_status, 'scheduled') IN ('scheduled', 'upcoming', 'not_started', 'live');

  IF to_regclass('public.fet_supply_overview') IS NOT NULL THEN
    EXECUTE 'SELECT coalesce(total_supply, 0) FROM public.fet_supply_overview'
    INTO v_total_fet_issued;
  END IF;

  SELECT coalesce(sum(amount_fet)::bigint, 0)
  INTO v_fet_transferred_24h
  FROM public.fet_wallet_transactions
  WHERE direction = 'debit'
    AND tx_type IN ('transfer', 'transfer_fet')
    AND created_at >= timezone('utc', now()) - interval '24 hours';

  SELECT count(*)::bigint
  INTO v_pending_rewards
  FROM public.user_predictions
  WHERE reward_status = 'pending';

  IF to_regclass('public.moderation_reports') IS NOT NULL THEN
    SELECT coalesce(count(*)::bigint, 0)
    INTO v_moderation_alerts
    FROM public.moderation_reports
    WHERE status IN ('open', 'investigating', 'escalated');
  END IF;

  SELECT count(*)::bigint
  INTO v_competitions_count
  FROM public.competitions
  WHERE coalesce(is_active, true) = true;

  SELECT count(*)::bigint
  INTO v_upcoming_fixtures
  FROM public.matches
  WHERE coalesce(match_status, 'scheduled') IN ('scheduled', 'upcoming', 'not_started')
     OR (match_status = 'live' AND match_date >= timezone('utc', now())::date);

  RETURN jsonb_build_object(
    'activeUsers', coalesce(v_active_users, 0),
    'openPredictionMatches', coalesce(v_open_prediction_matches, 0),
    'totalFetIssued', coalesce(v_total_fet_issued, 0),
    'fetTransferred24h', coalesce(v_fet_transferred_24h, 0),
    'pendingRewards', coalesce(v_pending_rewards, 0),
    'moderationAlerts', coalesce(v_moderation_alerts, 0),
    'competitionsCount', coalesce(v_competitions_count, 0),
    'upcomingFixtures', coalesce(v_upcoming_fixtures, 0)
  );
END;
$$;


ALTER FUNCTION "public"."admin_dashboard_kpis"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_debit_fet"("p_target_user_id" "uuid", "p_amount" bigint, "p_reason" "text" DEFAULT 'Admin debit'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_admin_id UUID;
  v_balance_before BIGINT;
BEGIN
  v_admin_id := auth.uid();
  IF NOT EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE user_id = v_admin_id AND is_active = true
      AND role IN ('super_admin', 'admin')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be positive';
  END IF;

  SELECT available_balance_fet INTO v_balance_before
  FROM public.fet_wallets
  WHERE user_id = p_target_user_id
  FOR UPDATE;

  IF v_balance_before IS NULL OR v_balance_before < p_amount THEN
    RAISE EXCEPTION 'Insufficient balance (has % FET, requested %)', COALESCE(v_balance_before, 0), p_amount;
  END IF;

  UPDATE public.fet_wallets
  SET available_balance_fet = available_balance_fet - p_amount,
      updated_at = now()
  WHERE user_id = p_target_user_id;

  INSERT INTO public.fet_wallet_transactions (
    user_id, tx_type, direction, amount_fet,
    balance_before_fet, balance_after_fet,
    reference_type, title
  ) VALUES (
    p_target_user_id, 'admin_debit', 'debit', p_amount,
    v_balance_before,
    v_balance_before - p_amount,
    'admin_action',
    'Admin debit: ' || COALESCE(p_reason, '')
  );

  INSERT INTO public.admin_audit_logs (
    admin_user_id, action, module, target_type, target_id,
    after_state
  )
  SELECT au.id, 'debit_fet', 'wallets', 'user', p_target_user_id::text,
    jsonb_build_object('amount', p_amount, 'reason', p_reason)
  FROM public.admin_users au WHERE au.user_id = v_admin_id;

  RETURN jsonb_build_object(
    'status', 'debited',
    'user_id', p_target_user_id,
    'amount', p_amount,
    'new_balance', v_balance_before - p_amount
  );
END;
$$;


ALTER FUNCTION "public"."admin_debit_fet"("p_target_user_id" "uuid", "p_amount" bigint, "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_engagement_daily"("p_days" integer DEFAULT 7) RETURNS TABLE("day" "text", "dau" bigint, "predictions" bigint)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
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
    SELECT timezone('utc', u.last_sign_in_at)::date AS bucket_date, u.id AS user_id
    FROM auth.users u
    WHERE u.last_sign_in_at IS NOT NULL

    UNION ALL

    SELECT timezone('utc', up.created_at)::date AS bucket_date, up.user_id
    FROM public.user_predictions up

    UNION ALL

    SELECT timezone('utc', tr.awarded_at)::date AS bucket_date, tr.user_id
    FROM public.token_rewards tr
    WHERE tr.status = 'awarded'

    UNION ALL

    SELECT timezone('utc', tx.created_at)::date AS bucket_date, tx.user_id
    FROM public.fet_wallet_transactions tx
  ),
  prediction_counts AS (
    SELECT timezone('utc', created_at)::date AS bucket_date, count(*)::bigint AS total
    FROM public.user_predictions
    GROUP BY 1
  )
  SELECT
    to_char(d.bucket_date, 'Dy') AS day,
    coalesce(count(DISTINCT a.user_id), 0)::bigint AS dau,
    coalesce(max(pc.total), 0)::bigint AS predictions
  FROM days d
  LEFT JOIN activity a
    ON a.bucket_date = d.bucket_date
  LEFT JOIN prediction_counts pc
    ON pc.bucket_date = d.bucket_date
  GROUP BY d.bucket_date
  ORDER BY d.bucket_date;
$$;


ALTER FUNCTION "public"."admin_engagement_daily"("p_days" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_engagement_kpis"() RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
  WITH _auth AS (
    SELECT public.require_active_admin_user()
  ),
  activity AS (
    SELECT id AS user_id, created_at AS activity_at
    FROM auth.users
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
      SELECT count(*)::bigint
      FROM public.user_predictions
      WHERE created_at >= timezone('utc', now()) - interval '7 days'
    ), 0),
    'fetVolume7d',
    coalesce((
      SELECT sum(amount_fet)::bigint
      FROM public.fet_wallet_transactions
      WHERE created_at >= timezone('utc', now()) - interval '7 days'
        AND (
          tx_type IN ('transfer', 'transfer_fet', 'admin_debit')
          OR reference_type = 'prediction_reward'
        )
    ), 0)
  );
$$;


ALTER FUNCTION "public"."admin_engagement_kpis"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_fet_flow_weekly"("p_weeks" integer DEFAULT 4) RETURNS TABLE("week" "text", "issued" bigint, "transferred" bigint, "adjusted" bigint, "rewarded" bigint)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
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
      amount_fet
    FROM public.fet_wallet_transactions
  ),
  rewards AS (
    SELECT
      date_trunc('week', timezone('utc', coalesce(awarded_at, created_at)))::date AS bucket_week,
      sum(token_amount)::bigint AS rewarded_total
    FROM public.token_rewards
    WHERE status = 'awarded'
    GROUP BY 1
  )
  SELECT
    'W' || to_char(w.bucket_week, 'IW') AS week,
    coalesce(sum(
      CASE
        WHEN tx.direction = 'credit'
         AND tx.tx_type IN ('foundation_grant', 'admin_credit', 'wallet_welcome_bonus')
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
         AND tx.tx_type = 'admin_debit'
          THEN tx.amount_fet
        ELSE 0
      END
    ), 0)::bigint AS adjusted,
    coalesce(max(r.rewarded_total), 0)::bigint AS rewarded
  FROM weeks w
  LEFT JOIN tx
    ON tx.bucket_week = w.bucket_week
  LEFT JOIN rewards r
    ON r.bucket_week = w.bucket_week
  GROUP BY w.bucket_week
  ORDER BY w.bucket_week;
$$;


ALTER FUNCTION "public"."admin_fet_flow_weekly"("p_weeks" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_freeze_wallet"("p_target_user_id" "uuid", "p_reason" "text" DEFAULT 'Suspicious activity'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_admin_id UUID;
BEGIN
  v_admin_id := auth.uid();
  IF NOT EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE user_id = v_admin_id AND is_active = true
      AND role IN ('super_admin', 'admin')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  INSERT INTO public.user_status (user_id, wallet_frozen, wallet_freeze_reason)
  VALUES (p_target_user_id, true, p_reason)
  ON CONFLICT (user_id) DO UPDATE
  SET wallet_frozen = true,
      wallet_freeze_reason = p_reason,
      updated_at = now();

  INSERT INTO public.admin_audit_logs (
    admin_user_id, action, module, target_type, target_id,
    after_state
  )
  SELECT au.id, 'freeze_wallet', 'wallets', 'user', p_target_user_id::text,
    jsonb_build_object('frozen', true, 'reason', p_reason)
  FROM public.admin_users au WHERE au.user_id = v_admin_id;

  RETURN jsonb_build_object('status', 'frozen', 'user_id', p_target_user_id);
END;
$$;


ALTER FUNCTION "public"."admin_freeze_wallet"("p_target_user_id" "uuid", "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_global_search"("p_query" "text", "p_limit" integer DEFAULT 12) RETURNS TABLE("result_id" "text", "result_type" "text", "title" "text", "subtitle" "text", "route" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."admin_global_search"("p_query" "text", "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_grant_access"("p_phone" "text", "p_role" "text") RETURNS "public"."admin_users"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
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


ALTER FUNCTION "public"."admin_grant_access"("p_phone" "text", "p_role" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_log_action"("p_action" "text", "p_module" "text", "p_target_type" "text" DEFAULT NULL::"text", "p_target_id" "text" DEFAULT NULL::"text", "p_before_state" "jsonb" DEFAULT NULL::"jsonb", "p_after_state" "jsonb" DEFAULT NULL::"jsonb", "p_metadata" "jsonb" DEFAULT '{}'::"jsonb") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."admin_log_action"("p_action" "text", "p_module" "text", "p_target_type" "text", "p_target_id" "text", "p_before_state" "jsonb", "p_after_state" "jsonb", "p_metadata" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_query_daily_active_users"("p_since" timestamp with time zone DEFAULT ("now"() - '30 days'::interval), "p_until" timestamp with time zone DEFAULT "now"()) RETURNS TABLE("day" "date", "unique_users" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  PERFORM public.require_active_admin_user();

  RETURN QUERY
    SELECT
      pe.created_at::date AS day,
      count(DISTINCT pe.user_id)::bigint AS unique_users
    FROM public.product_events pe
    WHERE pe.created_at >= p_since
      AND pe.created_at <= p_until
      AND pe.user_id IS NOT NULL
    GROUP BY pe.created_at::date
    ORDER BY day DESC;
END;
$$;


ALTER FUNCTION "public"."admin_query_daily_active_users"("p_since" timestamp with time zone, "p_until" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_query_event_counts"("p_since" timestamp with time zone DEFAULT ("now"() - '7 days'::interval), "p_until" timestamp with time zone DEFAULT "now"()) RETURNS TABLE("event_name" "text", "event_count" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  PERFORM public.require_active_admin_user();

  RETURN QUERY
    SELECT pe.event_name, count(*)::bigint AS event_count
    FROM public.product_events pe
    WHERE pe.created_at >= p_since
      AND pe.created_at <= p_until
    GROUP BY pe.event_name
    ORDER BY event_count DESC;
END;
$$;


ALTER FUNCTION "public"."admin_query_event_counts"("p_since" timestamp with time zone, "p_until" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_query_screen_views"("p_since" timestamp with time zone DEFAULT ("now"() - '7 days'::interval), "p_until" timestamp with time zone DEFAULT "now"()) RETURNS TABLE("screen_name" "text", "view_count" bigint, "unique_viewers" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  PERFORM public.require_active_admin_user();

  RETURN QUERY
    SELECT
      pe.properties->>'screen' AS screen_name,
      count(*)::bigint AS view_count,
      count(DISTINCT pe.user_id)::bigint AS unique_viewers
    FROM public.product_events pe
    WHERE pe.event_name = 'screen_view'
      AND pe.created_at >= p_since
      AND pe.created_at <= p_until
    GROUP BY pe.properties->>'screen'
    ORDER BY view_count DESC;
END;
$$;


ALTER FUNCTION "public"."admin_query_screen_views"("p_since" timestamp with time zone, "p_until" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_revoke_access"("p_admin_id" "uuid") RETURNS "public"."admin_users"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_actor_user_id uuid := public.require_super_admin_user();
  v_actor_admin_id uuid;
  v_existing public.admin_users%ROWTYPE;
  v_result public.admin_users%ROWTYPE;
  v_active_super_admins bigint := 0;
BEGIN
  IF p_admin_id IS NULL THEN
    RAISE EXCEPTION 'Admin id is required';
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

  SELECT *
  INTO v_existing
  FROM public.admin_users
  WHERE id = p_admin_id
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Admin user not found';
  END IF;

  IF v_existing.user_id = v_actor_user_id THEN
    RAISE EXCEPTION 'You cannot revoke your own admin access';
  END IF;

  IF v_existing.role = 'super_admin' AND v_existing.is_active THEN
    SELECT count(*)::bigint
    INTO v_active_super_admins
    FROM public.admin_users
    WHERE is_active = true
      AND role = 'super_admin';

    IF v_active_super_admins <= 1 THEN
      RAISE EXCEPTION 'Cannot revoke the last active super admin';
    END IF;
  END IF;

  UPDATE public.admin_users
  SET
    is_active = false,
    updated_at = timezone('utc', now())
  WHERE id = p_admin_id
  RETURNING *
  INTO v_result;

  INSERT INTO public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    before_state,
    after_state
  )
  VALUES (
    v_actor_admin_id,
    'revoke_admin_access',
    'admin_access',
    'admin_user',
    v_result.id::text,
    to_jsonb(v_existing),
    to_jsonb(v_result)
  );

  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."admin_revoke_access"("p_admin_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_set_competition_featured"("p_competition_id" "text", "p_is_featured" boolean) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
DECLARE
  v_admin_record_id uuid;
  v_before jsonb;
  v_after jsonb;
BEGIN
  PERFORM public.require_admin_manager_user();
  v_admin_record_id := public.active_admin_record_id();

  SELECT to_jsonb(competition)
  INTO v_before
  FROM public.competitions competition
  WHERE competition.id = p_competition_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Competition not found';
  END IF;

  UPDATE public.competitions
  SET is_featured = p_is_featured,
      updated_at = timezone('utc', now())
  WHERE id = p_competition_id;

  SELECT to_jsonb(competition)
  INTO v_after
  FROM public.competitions competition
  WHERE competition.id = p_competition_id;

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
    'toggle_competition_featured',
    'competitions',
    'competition',
    p_competition_id,
    v_before,
    v_after,
    jsonb_build_object('is_featured', p_is_featured)
  );

  RETURN jsonb_build_object(
    'id', p_competition_id,
    'is_featured', p_is_featured
  );
END;
$$;


ALTER FUNCTION "public"."admin_set_competition_featured"("p_competition_id" "text", "p_is_featured" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_set_feature_flag"("p_flag_id" "text", "p_is_enabled" boolean) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
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


ALTER FUNCTION "public"."admin_set_feature_flag"("p_flag_id" "text", "p_is_enabled" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_set_featured_event_active"("p_event_id" "uuid", "p_is_active" boolean) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
DECLARE
  v_admin_record_id uuid;
  v_before jsonb;
  v_after jsonb;
BEGIN
  PERFORM public.require_admin_manager_user();
  v_admin_record_id := public.active_admin_record_id();

  SELECT to_jsonb(event_row)
  INTO v_before
  FROM public.featured_events event_row
  WHERE event_row.id = p_event_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Featured event not found';
  END IF;

  UPDATE public.featured_events
  SET is_active = p_is_active,
      updated_at = timezone('utc', now())
  WHERE id = p_event_id;

  SELECT to_jsonb(event_row)
  INTO v_after
  FROM public.featured_events event_row
  WHERE event_row.id = p_event_id;

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
    'toggle_featured_event_active',
    'events',
    'featured_event',
    p_event_id::text,
    v_before,
    v_after,
    jsonb_build_object('is_active', p_is_active)
  );

  RETURN jsonb_build_object(
    'id', p_event_id,
    'is_active', p_is_active
  );
END;
$$;


ALTER FUNCTION "public"."admin_set_featured_event_active"("p_event_id" "uuid", "p_is_active" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_trigger_currency_rate_refresh"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  PERFORM public.require_active_admin_user();

  RETURN jsonb_build_object(
    'dispatched', false,
    'mode', 'manual_only',
    'message', 'Currency rates are now managed directly in the database. No external refresh job is configured.'
  );
END;
$$;


ALTER FUNCTION "public"."admin_trigger_currency_rate_refresh"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_unban_user"("p_target_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_admin_id UUID;
BEGIN
  v_admin_id := auth.uid();
  IF NOT EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE user_id = v_admin_id AND is_active = true
      AND role IN ('super_admin', 'admin')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  UPDATE public.user_status
  SET is_banned = false, banned_until = NULL, ban_reason = NULL, updated_at = now()
  WHERE user_id = p_target_user_id;

  INSERT INTO public.admin_audit_logs (
    admin_user_id, action, module, target_type, target_id,
    after_state
  )
  SELECT au.id, 'unban_user', 'users', 'user', p_target_user_id::text,
    jsonb_build_object('banned', false)
  FROM public.admin_users au WHERE au.user_id = v_admin_id;

  RETURN jsonb_build_object('status', 'unbanned', 'user_id', p_target_user_id);
END;
$$;


ALTER FUNCTION "public"."admin_unban_user"("p_target_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_unfreeze_wallet"("p_target_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_admin_id UUID;
BEGIN
  v_admin_id := auth.uid();
  IF NOT EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE user_id = v_admin_id AND is_active = true
      AND role IN ('super_admin', 'admin')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  UPDATE public.user_status
  SET wallet_frozen = false, wallet_freeze_reason = NULL, updated_at = now()
  WHERE user_id = p_target_user_id;

  INSERT INTO public.admin_audit_logs (
    admin_user_id, action, module, target_type, target_id,
    after_state
  )
  SELECT au.id, 'unfreeze_wallet', 'wallets', 'user', p_target_user_id::text,
    jsonb_build_object('frozen', false)
  FROM public.admin_users au WHERE au.user_id = v_admin_id;

  RETURN jsonb_build_object('status', 'unfrozen', 'user_id', p_target_user_id);
END;
$$;


ALTER FUNCTION "public"."admin_unfreeze_wallet"("p_target_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_update_account_deletion_request"("p_request_id" "uuid", "p_status" "text", "p_resolution_notes" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
DECLARE
  v_admin_user_id uuid;
  v_admin_record_id uuid;
  v_before jsonb;
  v_after jsonb;
  v_resolution_notes text := nullif(trim(p_resolution_notes), '');
BEGIN
  v_admin_user_id := public.require_admin_manager_user();
  v_admin_record_id := public.active_admin_record_id();

  SELECT to_jsonb(request_row)
  INTO v_before
  FROM public.account_deletion_requests request_row
  WHERE request_row.id = p_request_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Account deletion request not found';
  END IF;

  UPDATE public.account_deletion_requests
  SET status = p_status,
      resolution_notes = v_resolution_notes,
      processed_at = CASE
        WHEN p_status = 'pending' THEN NULL
        ELSE timezone('utc', now())
      END,
      processed_by = CASE
        WHEN p_status = 'pending' THEN NULL
        ELSE v_admin_user_id
      END,
      updated_at = timezone('utc', now())
  WHERE id = p_request_id;

  SELECT to_jsonb(request_row)
  INTO v_after
  FROM public.account_deletion_requests request_row
  WHERE request_row.id = p_request_id;

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
    'update_account_deletion_request',
    'account_deletions',
    'account_deletion_request',
    p_request_id::text,
    v_before,
    v_after,
    jsonb_build_object('status', p_status)
  );

  RETURN jsonb_build_object(
    'id', p_request_id,
    'status', p_status
  );
END;
$$;


ALTER FUNCTION "public"."admin_update_account_deletion_request"("p_request_id" "uuid", "p_status" "text", "p_resolution_notes" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_update_match_result"("p_match_id" "text", "p_home_goals" integer, "p_away_goals" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_requires_reward_review boolean := false;
  v_scoring_result jsonb := '{}'::jsonb;
BEGIN
  IF NOT public.current_user_has_admin_role(ARRAY['moderator', 'admin', 'super_admin']) THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  UPDATE public.matches
  SET
    home_goals = p_home_goals,
    away_goals = p_away_goals,
    match_status = 'finished',
    updated_at = now()
  WHERE id = p_match_id;

  PERFORM public.refresh_team_form_features_for_match(p_match_id);
  PERFORM public.generate_prediction_engine_output(p_match_id);

  SELECT EXISTS (
    SELECT 1
    FROM public.user_predictions up
    WHERE up.match_id = p_match_id
      AND up.reward_status <> 'pending'
  )
  INTO v_requires_reward_review;

  IF v_requires_reward_review THEN
    v_scoring_result := jsonb_build_object(
      'match_id', p_match_id,
      'processed_predictions', 0,
      'awarded_rewards', 0,
      'reward_reconciliation_required', true
    );
  ELSE
    v_scoring_result := public.score_user_predictions_for_match(p_match_id);
  END IF;

  RETURN jsonb_build_object(
    'match_id', p_match_id,
    'home_goals', p_home_goals,
    'away_goals', p_away_goals,
    'reward_reconciliation_required', v_requires_reward_review,
    'scoring', v_scoring_result
  );
END;
$$;


ALTER FUNCTION "public"."admin_update_match_result"("p_match_id" "text", "p_home_goals" integer, "p_away_goals" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_update_moderation_report_status"("p_report_id" "uuid", "p_status" "text", "p_resolution_notes" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
DECLARE
  v_admin_record_id uuid;
  v_before jsonb;
  v_after jsonb;
BEGIN
  v_admin_record_id := public.active_admin_record_id();

  SELECT to_jsonb(report)
  INTO v_before
  FROM public.moderation_reports report
  WHERE report.id = p_report_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Moderation report not found';
  END IF;

  UPDATE public.moderation_reports
  SET status = p_status,
      resolution_notes = COALESCE(NULLIF(trim(p_resolution_notes), ''), resolution_notes),
      assigned_to = COALESCE(assigned_to, v_admin_record_id),
      updated_at = timezone('utc', now())
  WHERE id = p_report_id;

  SELECT to_jsonb(report)
  INTO v_after
  FROM public.moderation_reports report
  WHERE report.id = p_report_id;

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
    'update_report_status',
    'moderation',
    'report',
    p_report_id::text,
    v_before,
    v_after,
    jsonb_build_object('status', p_status)
  );

  RETURN jsonb_build_object('id', p_report_id, 'status', p_status);
END;
$$;


ALTER FUNCTION "public"."admin_update_moderation_report_status"("p_report_id" "uuid", "p_status" "text", "p_resolution_notes" "text") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."seasons" (
    "id" "text" NOT NULL,
    "competition_id" "text" NOT NULL,
    "season_label" "text" NOT NULL,
    "start_year" integer NOT NULL,
    "end_year" integer NOT NULL,
    "is_current" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "seasons_year_range" CHECK (("end_year" >= "start_year"))
);


ALTER TABLE "public"."seasons" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."standings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "competition_id" "text" NOT NULL,
    "season_id" "text" NOT NULL,
    "snapshot_type" "text" DEFAULT 'current'::"text" NOT NULL,
    "snapshot_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "team_id" "text" NOT NULL,
    "position" integer NOT NULL,
    "played" integer DEFAULT 0 NOT NULL,
    "wins" integer DEFAULT 0 NOT NULL,
    "draws" integer DEFAULT 0 NOT NULL,
    "losses" integer DEFAULT 0 NOT NULL,
    "goals_for" integer DEFAULT 0 NOT NULL,
    "goals_against" integer DEFAULT 0 NOT NULL,
    "goal_difference" integer DEFAULT 0 NOT NULL,
    "points" integer DEFAULT 0 NOT NULL,
    "source_name" "text" DEFAULT 'manual'::"text" NOT NULL,
    "source_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "standings_draws_check" CHECK (("draws" >= 0)),
    CONSTRAINT "standings_losses_check" CHECK (("losses" >= 0)),
    CONSTRAINT "standings_played_check" CHECK (("played" >= 0)),
    CONSTRAINT "standings_position_check" CHECK (("position" > 0)),
    CONSTRAINT "standings_snapshot_type_check" CHECK (("snapshot_type" = ANY (ARRAY['current'::"text", 'matchday'::"text", 'final'::"text", 'historical'::"text"]))),
    CONSTRAINT "standings_wins_check" CHECK (("wins" >= 0))
);


ALTER TABLE "public"."standings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."teams" (
    "id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "short_name" "text",
    "country" "text",
    "competition_ids" "text"[] DEFAULT '{}'::"text"[],
    "aliases" "text"[] DEFAULT '{}'::"text"[],
    "created_at" timestamp with time zone DEFAULT "now"(),
    "country_code" "text",
    "league_name" "text",
    "logo_url" "text",
    "crest_url" "text",
    "search_terms" "text"[] DEFAULT '{}'::"text"[],
    "is_active" boolean DEFAULT true,
    "is_featured" boolean DEFAULT false,
    "is_popular_pick" boolean DEFAULT false,
    "popular_pick_rank" integer,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "region" "text",
    "description" "text",
    "cover_image_url" "text",
    "fan_count" integer DEFAULT 0 NOT NULL,
    "team_type" "text" DEFAULT 'club'::"text" NOT NULL
);


ALTER TABLE "public"."teams" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."competition_standings" AS
 SELECT "st"."id",
    "st"."competition_id",
    "st"."season_id",
    "s"."season_label" AS "season",
    "st"."snapshot_type",
    "st"."snapshot_date",
    "st"."team_id",
    "t"."name" AS "team_name",
    "st"."position",
    "st"."played",
    "st"."wins" AS "won",
    "st"."draws" AS "drawn",
    "st"."losses" AS "lost",
    "st"."goals_for",
    "st"."goals_against",
    "st"."goal_difference",
    "st"."points",
    "st"."source_name",
    "st"."source_url",
    "st"."created_at",
    "st"."updated_at"
   FROM (("public"."standings" "st"
     JOIN "public"."teams" "t" ON (("t"."id" = "st"."team_id")))
     JOIN "public"."seasons" "s" ON (("s"."id" = "st"."season_id")));


ALTER VIEW "public"."competition_standings" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."app_competition_standings"("p_competition_id" "text", "p_season" "text" DEFAULT NULL::"text") RETURNS SETOF "public"."competition_standings"
    LANGUAGE "sql" STABLE
    AS $$
  SELECT *
  FROM public.competition_standings
  WHERE competition_id = p_competition_id
    AND (
      p_season IS NULL
      OR p_season = ''
      OR season = p_season
      OR season_id = p_season
    )
  ORDER BY snapshot_date DESC, position ASC;
$$;


ALTER FUNCTION "public"."app_competition_standings"("p_competition_id" "text", "p_season" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."app_config_bigint"("p_key" "text", "p_default" bigint DEFAULT NULL::bigint) RETURNS bigint
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
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

  v_text := trim(both '"' from v_value::text);
  IF v_text = '' THEN
    RETURN p_default;
  END IF;

  RETURN v_text::bigint;
EXCEPTION
  WHEN invalid_text_representation OR numeric_value_out_of_range THEN
    RETURN p_default;
END;
$$;


ALTER FUNCTION "public"."app_config_bigint"("p_key" "text", "p_default" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."apply_match_result_code"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.match_status = public.normalize_match_status(NEW.match_status);
  NEW.result_code = public.compute_result_code(NEW.home_goals, NEW.away_goals);

  IF NEW.home_goals IS NOT NULL
    AND NEW.away_goals IS NOT NULL
    AND NEW.match_status NOT IN ('cancelled', 'postponed', 'live')
  THEN
    NEW.match_status = 'finished';
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."apply_match_result_code"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."assert_fet_mint_within_cap"("p_amount" bigint, "p_context" "text" DEFAULT 'FET mint'::"text") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_current_supply bigint := 0;
  v_supply_cap bigint := public.fet_supply_cap();
  v_new_total bigint;
  v_context text := coalesce(nullif(trim(p_context), ''), 'FET mint');
BEGIN
  IF p_amount IS NULL OR p_amount < 0 THEN
    RAISE EXCEPTION 'Mint amount must be non-negative';
  END IF;

  PERFORM public.lock_fet_supply_cap();

  SELECT coalesce(sum(available_balance_fet + locked_balance_fet), 0)::bigint
  INTO v_current_supply
  FROM public.fet_wallets;

  v_new_total := v_current_supply + p_amount;

  IF v_new_total > v_supply_cap THEN
    RAISE EXCEPTION '% would exceed FET supply cap (% + % > %)',
      v_context,
      v_current_supply,
      p_amount,
      v_supply_cap;
  END IF;

  RETURN v_new_total;
END;
$$;


ALTER FUNCTION "public"."assert_fet_mint_within_cap"("p_amount" bigint, "p_context" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."assert_wallet_available"("p_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_is_banned boolean := false;
  v_banned_until timestamptz;
  v_wallet_frozen boolean := false;
BEGIN
  SELECT
    is_banned,
    banned_until,
    wallet_frozen
  INTO v_is_banned, v_banned_until, v_wallet_frozen
  FROM public.user_status
  WHERE user_id = p_user_id;

  IF coalesce(v_wallet_frozen, false) THEN
    RAISE EXCEPTION 'Wallet is frozen';
  END IF;

  IF coalesce(v_is_banned, false)
     AND (
       v_banned_until IS NULL
       OR v_banned_until > timezone('utc', now())
     ) THEN
    RAISE EXCEPTION 'Account is banned';
  END IF;
END;
$$;


ALTER FUNCTION "public"."assert_wallet_available"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."assign_profile_fan_id"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
DECLARE
  v_seed TEXT;
BEGIN
  v_seed := COALESCE(NEW.user_id::text, NEW.id::text, gen_random_uuid()::text);

  IF NEW.fan_id IS NULL OR NEW.fan_id !~ '^\d{6}$' THEN
    NEW.fan_id := public.generate_profile_fan_id(
      v_seed,
      0,
      COALESCE(NEW.id, NEW.user_id)
    );
  END IF;

  RETURN NEW;
END;
$_$;


ALTER FUNCTION "public"."assign_profile_fan_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."audit_wallet_bootstrap_gaps"() RETURNS TABLE("user_id" "uuid", "available_balance_fet" bigint, "locked_balance_fet" bigint, "welcome_bonus_amount" bigint, "non_bonus_transaction_count" bigint, "expected_bootstrap_balance" bigint)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  WITH foundation_config AS (
    SELECT coalesce(public.app_config_bigint('foundation_grant_fet', 50), 50)::bigint AS foundation_grant
  ),
  wallet_stats AS (
    SELECT
      w.user_id,
      w.available_balance_fet,
      w.locked_balance_fet,
      coalesce((
        SELECT sum(t.amount_fet)
        FROM public.fet_wallet_transactions t
        WHERE t.user_id = w.user_id
          AND t.tx_type = 'foundation_grant'
      ), 0)::bigint AS welcome_bonus_amount,
      (
        SELECT count(*)
        FROM public.fet_wallet_transactions t
        WHERE t.user_id = w.user_id
          AND t.tx_type NOT IN ('foundation_grant', 'wallet_balance_correction')
      )::bigint AS non_bonus_transaction_count,
      foundation_config.foundation_grant AS expected_bootstrap_balance
    FROM public.fet_wallets w
    CROSS JOIN foundation_config
  )
  SELECT *
  FROM wallet_stats ws
  WHERE ws.welcome_bonus_amount <> ws.expected_bootstrap_balance
     OR (
       ws.available_balance_fet + ws.locked_balance_fet < ws.expected_bootstrap_balance
       AND ws.non_bonus_transaction_count = 0
     );
$$;


ALTER FUNCTION "public"."audit_wallet_bootstrap_gaps"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_rate_limit"("p_user_id" "uuid", "p_action" "text", "p_max_count" integer, "p_window_hours" integer DEFAULT 1) RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_count INT;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM public.rate_limits
  WHERE user_id = p_user_id
    AND action = p_action
    AND created_at > now() - (p_window_hours || ' hours')::interval;

  IF v_count >= p_max_count THEN
    RETURN FALSE;
  END IF;

  INSERT INTO public.rate_limits (user_id, action)
  VALUES (p_user_id, p_action);

  RETURN TRUE;
END;
$$;


ALTER FUNCTION "public"."check_rate_limit"("p_user_id" "uuid", "p_action" "text", "p_max_count" integer, "p_window_hours" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_rate_limit"("p_user_id" "uuid", "p_action" "text", "p_max_count" integer, "p_window" interval) RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_count integer;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'Rate limit requires a user id';
  END IF;

  IF coalesce(trim(p_action), '') = '' THEN
    RAISE EXCEPTION 'Rate limit requires an action name';
  END IF;

  IF p_max_count IS NULL OR p_max_count <= 0 THEN
    RAISE EXCEPTION 'Rate limit max_count must be positive';
  END IF;

  IF p_window IS NULL OR p_window <= interval '0 seconds' THEN
    RAISE EXCEPTION 'Rate limit window must be positive';
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended(p_user_id::text || ':' || p_action, 0)
  );

  DELETE FROM public.rate_limits
  WHERE user_id = p_user_id
    AND action = p_action
    AND created_at <= now() - p_window;

  SELECT count(*)
  INTO v_count
  FROM public.rate_limits
  WHERE user_id = p_user_id
    AND action = p_action
    AND created_at > now() - p_window;

  IF v_count >= p_max_count THEN
    RETURN false;
  END IF;

  INSERT INTO public.rate_limits (user_id, action)
  VALUES (p_user_id, p_action);

  RETURN true;
END;
$$;


ALTER FUNCTION "public"."check_rate_limit"("p_user_id" "uuid", "p_action" "text", "p_max_count" integer, "p_window" interval) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cleanup_expired_otps"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_deleted integer;
BEGIN
  DELETE FROM public.otp_verifications
  WHERE (verified = true OR expires_at < now())
    AND created_at < now() - interval '24 hours';

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;


ALTER FUNCTION "public"."cleanup_expired_otps"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cleanup_rate_limits"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  DELETE FROM public.rate_limits
  WHERE created_at < now() - interval '24 hours';
END;
$$;


ALTER FUNCTION "public"."cleanup_rate_limits"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."competition_catalog_rank"("p_competition_id" "text", "p_competition_name" "text" DEFAULT NULL::"text") RETURNS integer
    LANGUAGE "sql" IMMUTABLE
    AS $$
  WITH normalized AS (
    SELECT
      trim(
        regexp_replace(
          lower(coalesce(p_competition_id, '') || ' ' || coalesce(p_competition_name, '')),
          '[^a-z0-9]+',
          ' ',
          'g'
        )
      ) AS combined_value,
      trim(
        regexp_replace(lower(coalesce(p_competition_id, '')), '[^a-z0-9]+', ' ', 'g')
      ) AS id_value,
      trim(
        regexp_replace(lower(coalesce(p_competition_name, '')), '[^a-z0-9]+', ' ', 'g')
      ) AS name_value
  )
  SELECT CASE
    WHEN combined_value LIKE '%champions league%'
      OR id_value IN ('ucl', 'uefa champions league')
      THEN 1
    WHEN id_value = 'epl'
      OR name_value IN ('premier league', 'english premier league')
      THEN 2
    WHEN combined_value LIKE '%la liga%'
      THEN 3
    WHEN combined_value LIKE '%ligue 1%'
      THEN 4
    WHEN combined_value LIKE '%bundesliga%'
      THEN 5
    WHEN combined_value LIKE '%serie a%'
      THEN 6
    ELSE 1000
  END
  FROM normalized;
$$;


ALTER FUNCTION "public"."competition_catalog_rank"("p_competition_id" "text", "p_competition_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_fan_id"() RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN public.generate_profile_fan_id(gen_random_uuid()::text);
END;
$$;


ALTER FUNCTION "public"."generate_fan_id"() OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "username" "text",
    "full_name" "text",
    "avatar_url" "text",
    "favorite_malta_team" "text",
    "favorite_euro_team" "text",
    "fan_level" integer DEFAULT 1,
    "fan_tier" "text" DEFAULT 'Bronze'::"text",
    "active_country" "text" DEFAULT 'MT'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "user_id" "uuid" NOT NULL,
    "fan_id" "text" DEFAULT "public"."generate_fan_id"() NOT NULL,
    "display_name" "text",
    "favorite_team_id" "text",
    "favorite_team_name" "text",
    "country_code" "text" DEFAULT '+356'::"text",
    "phone_number" "text",
    "onboarding_completed" boolean DEFAULT false NOT NULL,
    "currency_code" "text",
    "region" "text",
    "show_name_on_leaderboards" boolean DEFAULT false NOT NULL,
    "allow_fan_discovery" boolean DEFAULT false NOT NULL,
    "is_anonymous" boolean DEFAULT false NOT NULL,
    "auth_method" "text" DEFAULT 'phone'::"text" NOT NULL,
    "upgraded_from_anonymous_id" "uuid",
    CONSTRAINT "profiles_display_name_length" CHECK ((("display_name" IS NULL) OR (("char_length"(TRIM(BOTH FROM "display_name")) >= 3) AND ("char_length"(TRIM(BOTH FROM "display_name")) <= 24)))),
    CONSTRAINT "profiles_fan_id_six_digits" CHECK (("fan_id" ~ '^\d{6}$'::"text"))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


COMMENT ON COLUMN "public"."profiles"."region" IS 'Inferred user region: global, africa, europe, americas';



COMMENT ON COLUMN "public"."profiles"."show_name_on_leaderboards" IS 'When true, public leaderboard surfaces may show the user display name instead of the Fan ID.';



COMMENT ON COLUMN "public"."profiles"."allow_fan_discovery" IS 'Reserved preference for privacy-safe fan discovery if that feature is enabled later.';



CREATE OR REPLACE FUNCTION "public"."complete_user_onboarding"("p_display_name" "text", "p_favorite_team_id" "text", "p_favorite_team_name" "text", "p_country_code" "text" DEFAULT '+356'::"text") RETURNS "public"."profiles"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_profile public.profiles;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  PERFORM public.ensure_user_foundation(v_user_id);

  IF p_display_name IS NOT NULL AND char_length(trim(p_display_name)) > 0 THEN
    IF char_length(trim(p_display_name)) < 3 OR char_length(trim(p_display_name)) > 24 THEN
      RAISE EXCEPTION 'Display name must be between 3 and 24 characters';
    END IF;
  END IF;

  UPDATE public.profiles
  SET display_name = NULLIF(trim(p_display_name), ''),
      favorite_team_id = NULLIF(trim(p_favorite_team_id), ''),
      favorite_team_name = NULLIF(trim(p_favorite_team_name), ''),
      country_code = COALESCE(NULLIF(trim(p_country_code), ''), country_code),
      onboarding_completed = true,
      phone_number = COALESCE(public.resolve_auth_user_phone(v_user_id), phone_number)
  WHERE user_id = v_user_id
  RETURNING * INTO v_profile;

  RETURN v_profile;
END;
$$;


ALTER FUNCTION "public"."complete_user_onboarding"("p_display_name" "text", "p_favorite_team_id" "text", "p_favorite_team_name" "text", "p_country_code" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."compute_result_code"("p_home_goals" integer, "p_away_goals" integer) RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    AS $$
  SELECT CASE
    WHEN p_home_goals IS NULL OR p_away_goals IS NULL THEN NULL
    WHEN p_home_goals > p_away_goals THEN 'H'
    WHEN p_home_goals < p_away_goals THEN 'A'
    ELSE 'D'
  END;
$$;


ALTER FUNCTION "public"."compute_result_code"("p_home_goals" integer, "p_away_goals" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_user_has_admin_role"("p_roles" "text"[] DEFAULT ARRAY['moderator'::"text", 'admin'::"text", 'super_admin'::"text"]) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.admin_users
    WHERE user_id = auth.uid()
      AND is_active = true
      AND role = ANY (p_roles)
  );
$$;


ALTER FUNCTION "public"."current_user_has_admin_role"("p_roles" "text"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ensure_user_foundation"("p_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  phone_value text;
  v_foundation_grant bigint := greatest(
    coalesce(public.app_config_bigint('foundation_grant_fet', 50), 50),
    0
  );
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
        'Foundation grant - welcome balance'
      );
    END IF;
  END IF;
END;
$$;


ALTER FUNCTION "public"."ensure_user_foundation"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fet_supply_cap"() RETURNS bigint
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO 'public'
    AS $$
  SELECT 100000000::bigint;
$$;


ALTER FUNCTION "public"."fet_supply_cap"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_auth_user_by_phone"("p_phone" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'auth', 'public'
    AS $$
DECLARE
  v_id uuid;
BEGIN
  SELECT id INTO v_id
  FROM auth.users
  WHERE phone = p_phone
  LIMIT 1;

  RETURN v_id;
END;
$$;


ALTER FUNCTION "public"."find_auth_user_by_phone"("p_phone" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_prediction_engine_output"("p_match_id" "text", "p_model_version" "text" DEFAULT 'simple_form_v1'::"text") RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_match record;
  v_home_form record;
  v_away_form record;
  v_home_position integer;
  v_away_position integer;
  v_form_edge numeric := 0;
  v_goal_edge numeric := 0;
  v_table_edge numeric := 0;
  v_home_specific_edge numeric := 0;
  v_home_raw numeric;
  v_draw_raw numeric;
  v_away_raw numeric;
  v_total_raw numeric;
  v_home_score numeric;
  v_draw_score numeric;
  v_away_score numeric;
  v_pred_home numeric;
  v_pred_away numeric;
  v_over25 numeric;
  v_btts numeric;
  v_confidence text;
  v_output_id uuid;
BEGIN
  SELECT *
  INTO v_match
  FROM public.matches
  WHERE id = p_match_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match % not found', p_match_id;
  END IF;

  PERFORM public.refresh_team_form_features_for_match(p_match_id);

  SELECT *
  INTO v_home_form
  FROM public.team_form_features
  WHERE match_id = p_match_id
    AND team_id = v_match.home_team_id;

  SELECT *
  INTO v_away_form
  FROM public.team_form_features
  WHERE match_id = p_match_id
    AND team_id = v_match.away_team_id;

  SELECT position
  INTO v_home_position
  FROM public.standings
  WHERE competition_id = v_match.competition_id
    AND team_id = v_match.home_team_id
    AND (season_id = v_match.season_id OR v_match.season_id IS NULL)
  ORDER BY snapshot_date DESC, created_at DESC
  LIMIT 1;

  SELECT position
  INTO v_away_position
  FROM public.standings
  WHERE competition_id = v_match.competition_id
    AND team_id = v_match.away_team_id
    AND (season_id = v_match.season_id OR v_match.season_id IS NULL)
  ORDER BY snapshot_date DESC, created_at DESC
  LIMIT 1;

  v_form_edge := (
    COALESCE(v_home_form.last5_points, 0) - COALESCE(v_away_form.last5_points, 0)
  ) / 15.0;

  v_goal_edge := (
    (COALESCE(v_home_form.last5_goals_for, 0) - COALESCE(v_home_form.last5_goals_against, 0))
    -
    (COALESCE(v_away_form.last5_goals_for, 0) - COALESCE(v_away_form.last5_goals_against, 0))
  ) / 10.0;

  v_table_edge := CASE
    WHEN v_home_position IS NULL OR v_away_position IS NULL THEN 0
    ELSE (v_away_position - v_home_position) / 20.0
  END;

  v_home_specific_edge := (
    COALESCE(v_home_form.home_form_last5, 0) - COALESCE(v_away_form.away_form_last5, 0)
  ) / 15.0;

  v_home_raw :=
    0.42
    + (v_form_edge * 0.22)
    + (v_goal_edge * 0.16)
    + (v_table_edge * 0.10)
    + (v_home_specific_edge * 0.10)
    + 0.08;

  v_draw_raw :=
    0.28
    - abs(v_form_edge) * 0.08
    - abs(v_goal_edge) * 0.06
    - abs(v_table_edge) * 0.04;

  v_away_raw :=
    0.30
    - (v_form_edge * 0.20)
    - (v_goal_edge * 0.14)
    - (v_table_edge * 0.08)
    - (v_home_specific_edge * 0.08);

  v_home_raw := greatest(0.05, v_home_raw);
  v_draw_raw := greatest(0.05, v_draw_raw);
  v_away_raw := greatest(0.05, v_away_raw);
  v_total_raw := v_home_raw + v_draw_raw + v_away_raw;

  v_home_score := round((v_home_raw / v_total_raw)::numeric, 4);
  v_draw_score := round((v_draw_raw / v_total_raw)::numeric, 4);
  v_away_score := round((v_away_raw / v_total_raw)::numeric, 4);

  v_pred_home := greatest(
    0.2,
    least(
      4.0,
      1.15
      + (COALESCE(v_home_form.last5_goals_for, 0) / 5.0) * 0.35
      - (COALESCE(v_away_form.last5_goals_against, 0) / 5.0) * 0.18
      + (COALESCE(v_home_form.home_form_last5, 0) / 15.0) * 0.45
      + (v_table_edge * 0.25)
    )
  );

  v_pred_away := greatest(
    0.1,
    least(
      4.0,
      0.85
      + (COALESCE(v_away_form.last5_goals_for, 0) / 5.0) * 0.30
      - (COALESCE(v_home_form.last5_goals_against, 0) / 5.0) * 0.15
      + (COALESCE(v_away_form.away_form_last5, 0) / 15.0) * 0.35
      - (v_table_edge * 0.20)
    )
  );

  v_over25 := greatest(
    0.05,
    least(
      0.95,
      0.35
      + ((v_pred_home + v_pred_away - 2.5) * 0.18)
      + ((COALESCE(v_home_form.over25_last5, 0) + COALESCE(v_away_form.over25_last5, 0)) / 10.0) * 0.28
    )
  );

  v_btts := greatest(
    0.05,
    least(
      0.95,
      0.30
      + ((COALESCE(v_home_form.btts_last5, 0) + COALESCE(v_away_form.btts_last5, 0)) / 10.0) * 0.32
      + least(v_pred_home, v_pred_away) * 0.16
      - abs(v_pred_home - v_pred_away) * 0.07
    )
  );

  v_confidence := CASE
    WHEN greatest(v_home_score, v_draw_score, v_away_score) >= 0.62 THEN 'high'
    WHEN greatest(v_home_score, v_draw_score, v_away_score) >= 0.48 THEN 'medium'
    ELSE 'low'
  END;

  INSERT INTO public.predictions_engine_outputs (
    match_id,
    model_version,
    home_win_score,
    draw_score,
    away_win_score,
    over25_score,
    btts_score,
    predicted_home_goals,
    predicted_away_goals,
    confidence_label,
    generated_at
  )
  VALUES (
    p_match_id,
    p_model_version,
    v_home_score,
    v_draw_score,
    v_away_score,
    round(v_over25::numeric, 4),
    round(v_btts::numeric, 4),
    round(v_pred_home)::integer,
    round(v_pred_away)::integer,
    v_confidence,
    now()
  )
  ON CONFLICT (match_id) DO UPDATE SET
    model_version = EXCLUDED.model_version,
    home_win_score = EXCLUDED.home_win_score,
    draw_score = EXCLUDED.draw_score,
    away_win_score = EXCLUDED.away_win_score,
    over25_score = EXCLUDED.over25_score,
    btts_score = EXCLUDED.btts_score,
    predicted_home_goals = EXCLUDED.predicted_home_goals,
    predicted_away_goals = EXCLUDED.predicted_away_goals,
    confidence_label = EXCLUDED.confidence_label,
    generated_at = EXCLUDED.generated_at
  RETURNING id INTO v_output_id;

  RETURN v_output_id;
END;
$$;


ALTER FUNCTION "public"."generate_prediction_engine_output"("p_match_id" "text", "p_model_version" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_predictions_for_matches"("p_match_ids" "text"[] DEFAULT NULL::"text"[], "p_limit" integer DEFAULT 250, "p_model_version" "text" DEFAULT 'simple_form_v1'::"text", "p_include_finished" boolean DEFAULT false) RETURNS integer
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
DECLARE
  rec record;
  v_count integer := 0;
BEGIN
  IF coalesce(array_length(p_match_ids, 1), 0) > 0 THEN
    FOR rec IN
      SELECT m.id
      FROM public.matches m
      WHERE m.id = ANY (p_match_ids)
        AND (
          p_include_finished
          OR m.match_status IN ('scheduled', 'live')
        )
      ORDER BY m.match_date ASC, m.id ASC
    LOOP
      PERFORM public.generate_prediction_engine_output(rec.id, p_model_version);
      v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
  END IF;

  FOR rec IN
    SELECT m.id
    FROM public.matches m
    WHERE m.match_status IN ('scheduled', 'live')
      AND m.match_date >= now() - interval '6 hours'
    ORDER BY m.match_date ASC, m.id ASC
    LIMIT greatest(1, coalesce(p_limit, 250))
  LOOP
    PERFORM public.generate_prediction_engine_output(rec.id, p_model_version);
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;


ALTER FUNCTION "public"."generate_predictions_for_matches"("p_match_ids" "text"[], "p_limit" integer, "p_model_version" "text", "p_include_finished" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_predictions_for_upcoming_matches"("p_limit" integer DEFAULT 50) RETURNS integer
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN public.generate_predictions_for_matches(
    NULL::text[],
    greatest(1, coalesce(p_limit, 50)),
    'simple_form_v1',
    false
  );
END;
$$;


ALTER FUNCTION "public"."generate_predictions_for_upcoming_matches"("p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_profile_fan_id"("p_seed" "text", "p_attempt" integer DEFAULT 0, "p_profile_id" "uuid" DEFAULT NULL::"uuid") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_seed TEXT := COALESCE(NULLIF(trim(p_seed), ''), gen_random_uuid()::text);
  v_attempt INTEGER := GREATEST(COALESCE(p_attempt, 0), 0);
  v_candidate TEXT;
BEGIN
  LOOP
    v_candidate := LPAD(
      (
        ABS(
          ('x' || substr(md5(v_seed || ':' || v_attempt::text), 1, 8))::bit(32)::int
        ) % 1000000
      )::text,
      6,
      '0'
    );

    EXIT WHEN NOT EXISTS (
      SELECT 1
      FROM public.profiles
      WHERE fan_id = v_candidate
        AND (p_profile_id IS NULL OR id <> p_profile_id)
    );

    v_attempt := v_attempt + 1;
  END LOOP;

  RETURN v_candidate;
END;
$$;


ALTER FUNCTION "public"."generate_profile_fan_id"("p_seed" "text", "p_attempt" integer, "p_profile_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_team_form_features_for_matches"("p_match_ids" "text"[] DEFAULT NULL::"text"[], "p_limit" integer DEFAULT 250) RETURNS integer
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
DECLARE
  rec record;
  v_count integer := 0;
BEGIN
  IF coalesce(array_length(p_match_ids, 1), 0) > 0 THEN
    FOR rec IN
      SELECT m.id
      FROM public.matches m
      WHERE m.id = ANY (p_match_ids)
      ORDER BY m.match_date ASC, m.id ASC
    LOOP
      PERFORM public.refresh_team_form_features_for_match(rec.id);
      v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
  END IF;

  FOR rec IN
    SELECT m.id
    FROM public.matches m
    WHERE m.match_status IN ('scheduled', 'live', 'finished')
    ORDER BY m.match_date ASC, m.id ASC
    LIMIT greatest(1, coalesce(p_limit, 250))
  LOOP
    PERFORM public.refresh_team_form_features_for_match(rec.id);
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;


ALTER FUNCTION "public"."generate_team_form_features_for_matches"("p_match_ids" "text"[], "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_admin_me"() RETURNS "public"."admin_users"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
DECLARE
  v_user_id uuid;
  v_phone text;
  v_admin public.admin_users%ROWTYPE;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL OR to_regclass('public.admin_users') IS NULL THEN
    RETURN NULL;
  END IF;

  -- Resolve phone from auth.users (set by whatsapp-otp function)
  SELECT u.phone INTO v_phone FROM auth.users u WHERE u.id = v_user_id;

  -- Match by user_id first, then by phone (for first-time login bootstrap)
  SELECT *
  INTO v_admin
  FROM public.admin_users
  WHERE (
    user_id = v_user_id
    OR (v_phone IS NOT NULL AND (phone = v_phone OR whatsapp_number = v_phone))
  )
  AND is_active = true
  ORDER BY
    (user_id = v_user_id) DESC,
    created_at DESC,
    id DESC
  LIMIT 1;

  -- Auto-link user_id on first phone-based match
  IF v_admin.id IS NOT NULL AND (v_admin.user_id IS NULL OR v_admin.user_id <> v_user_id) THEN
    UPDATE public.admin_users SET user_id = v_user_id, updated_at = now()
    WHERE id = v_admin.id;
  END IF;

  RETURN v_admin;
END;
$$;


ALTER FUNCTION "public"."get_admin_me"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_app_bootstrap_config"("p_market" "text" DEFAULT 'global'::"text", "p_platform" "text" DEFAULT 'all'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'regions', (
      SELECT COALESCE(
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
      SELECT COALESCE(
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
      SELECT COALESCE(
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
      SELECT COALESCE(
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
      SELECT COALESCE(
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
      SELECT COALESCE(
        jsonb_object_agg(acr.key, acr.value),
        '{}'::jsonb
      )
      FROM public.app_config_remote acr
    ),
    'launch_moments', (
      SELECT COALESCE(
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
    )
  )
  INTO v_result;

  RETURN COALESCE(v_result, '{}'::jsonb);
END;
$$;


ALTER FUNCTION "public"."get_app_bootstrap_config"("p_market" "text", "p_platform" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_competition_current_season"("p_competition_id" "text") RETURNS "text"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_season_label text;
BEGIN
  IF p_competition_id IS NULL OR btrim(p_competition_id) = '' THEN
    RETURN NULL;
  END IF;

  SELECT s.season_label
  INTO v_season_label
  FROM public.seasons s
  WHERE s.competition_id = p_competition_id
  ORDER BY s.is_current DESC, s.end_year DESC, s.start_year DESC, s.season_label DESC
  LIMIT 1;

  IF v_season_label IS NOT NULL THEN
    RETURN v_season_label;
  END IF;

  SELECT s.season_label
  INTO v_season_label
  FROM public.matches m
  JOIN public.seasons s
    ON s.id = m.season_id
  WHERE m.competition_id = p_competition_id
  ORDER BY
    CASE m.match_status
      WHEN 'live' THEN 0
      WHEN 'scheduled' THEN 1
      WHEN 'finished' THEN 2
      ELSE 3
    END,
    m.match_date DESC
  LIMIT 1;

  RETURN v_season_label;
END;
$$;


ALTER FUNCTION "public"."get_competition_current_season"("p_competition_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_country_region"("p_country_code" "text") RETURNS "text"
    LANGUAGE "sql" STABLE
    AS $$
  SELECT COALESCE(
    (SELECT region FROM public.country_region_map WHERE country_code = UPPER(p_country_code) LIMIT 1),
    'global'
  );
$$;


ALTER FUNCTION "public"."get_country_region"("p_country_code" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."guess_user_currency"("p_user_id" "uuid" DEFAULT "auth"."uid"()) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
DECLARE
  v_user_id UUID := COALESCE(p_user_id, auth.uid());
  v_country_code TEXT;
  v_currency_code TEXT := 'EUR';
  v_source TEXT := 'fallback';
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT upper(team_country_code), source
  INTO v_country_code, v_source
  FROM public.user_favorite_teams
  WHERE user_id = v_user_id
    AND source = 'local'
    AND NULLIF(team_country_code, '') IS NOT NULL
  ORDER BY sort_order ASC, created_at ASC
  LIMIT 1;

  IF v_country_code IS NULL THEN
    SELECT upper(team_country_code), source
    INTO v_country_code, v_source
    FROM public.user_favorite_teams
    WHERE user_id = v_user_id
      AND NULLIF(team_country_code, '') IS NOT NULL
      AND upper(team_country_code) <> ALL (ARRAY['GB', 'ES', 'DE', 'FR', 'IT', 'NL', 'PT'])
    ORDER BY
      CASE source
        WHEN 'settings' THEN 0
        WHEN 'popular' THEN 1
        ELSE 2
      END,
      sort_order ASC,
      created_at ASC
    LIMIT 1;
  END IF;

  IF v_country_code IS NULL THEN
    SELECT upper(team_country_code), source
    INTO v_country_code, v_source
    FROM public.user_favorite_teams
    WHERE user_id = v_user_id
      AND NULLIF(team_country_code, '') IS NOT NULL
    ORDER BY
      CASE source
        WHEN 'local' THEN 0
        WHEN 'settings' THEN 1
        WHEN 'popular' THEN 2
        ELSE 3
      END,
      sort_order ASC,
      created_at ASC
    LIMIT 1;
  END IF;

  IF v_country_code IS NULL THEN
    SELECT
      upper(
        CASE
          WHEN COALESCE(active_country, '') ~ '^[A-Za-z]{2}$' THEN active_country
          WHEN COALESCE(country_code, '') ~ '^[A-Za-z]{2}$' THEN country_code
          ELSE NULL
        END
      ),
      'profile'
    INTO v_country_code, v_source
    FROM public.profiles
    WHERE id = v_user_id OR user_id = v_user_id
    LIMIT 1;
  END IF;

  IF v_country_code IS NOT NULL THEN
    SELECT c.currency_code
    INTO v_currency_code
    FROM public.country_currency_map AS c
    WHERE c.country_code = upper(v_country_code)
    LIMIT 1;
  END IF;

  v_currency_code := COALESCE(v_currency_code, 'EUR');

  UPDATE public.profiles
  SET currency_code = v_currency_code,
      active_country = COALESCE(v_country_code, active_country),
      updated_at = now()
  WHERE id = v_user_id OR user_id = v_user_id;

  RETURN jsonb_build_object(
    'currency_code', v_currency_code,
    'country_code', COALESCE(v_country_code, 'MT'),
    'source', v_source
  );
END;
$_$;


ALTER FUNCTION "public"."guess_user_currency"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_auth_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  PERFORM public.ensure_user_foundation(NEW.id);
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_auth_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."install_openfootball_sync_schedule"("p_project_url" "text", "p_anon_key" "text", "p_admin_secret" "text", "p_schedule" "text" DEFAULT '17 */6 * * *'::"text", "p_payload" "jsonb" DEFAULT NULL::"jsonb", "p_job_name" "text" DEFAULT 'market-sync-openfootball'::"text") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'cron', 'vault'
    AS $_$
DECLARE
    v_existing_job_id bigint;
    v_command text;
    v_payload jsonb := COALESCE(
        p_payload,
        '{
          "competitions": ["premier-league", "la-liga", "bundesliga", "serie-a", "ligue-1"],
          "include_previous_seasons": 1,
          "hydrate_markets": true,
          "hydrate_limit": 40
        }'::jsonb
    );
BEGIN
    PERFORM public.upsert_vault_secret(
        'openfootball_sync_project_url',
        p_project_url,
        'Supabase project URL for the openfootball sync cron job'
    );
    PERFORM public.upsert_vault_secret(
        'openfootball_sync_anon_key',
        p_anon_key,
        'Supabase anon key for invoking sync-openfootball-fixtures'
    );
    PERFORM public.upsert_vault_secret(
        'openfootball_sync_admin_secret',
        p_admin_secret,
        'Internal market admin secret for sync-openfootball-fixtures'
    );

    SELECT jobid
    INTO v_existing_job_id
    FROM cron.job
    WHERE jobname = p_job_name
    LIMIT 1;

    IF v_existing_job_id IS NOT NULL THEN
        PERFORM cron.unschedule(v_existing_job_id);
    END IF;

    v_command := format(
        $sql$
        select
          net.http_post(
            url := (select decrypted_secret from vault.decrypted_secrets where name = 'openfootball_sync_project_url')
              || '/functions/v1/sync-openfootball-fixtures',
            headers := jsonb_build_object(
              'Content-Type', 'application/json',
              'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'openfootball_sync_anon_key'),
              'x-market-admin-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'openfootball_sync_admin_secret')
            ),
            body := %L::jsonb
          ) as request_id;
        $sql$,
        v_payload::text
    );

    RETURN cron.schedule(p_job_name, p_schedule, v_command);
END;
$_$;


ALTER FUNCTION "public"."install_openfootball_sync_schedule"("p_project_url" "text", "p_anon_key" "text", "p_admin_secret" "text", "p_schedule" "text", "p_payload" "jsonb", "p_job_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_active_admin_operator"("p_user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."is_active_admin_operator"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_active_admin_user"("p_user_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.admin_users
    WHERE user_id = p_user_id
      AND is_active = true
      AND role IN ('super_admin', 'admin')
  );
$$;


ALTER FUNCTION "public"."is_active_admin_user"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_admin_manager"("p_user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."is_admin_manager"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_service_role_request"() RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."is_service_role_request"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_super_admin_user"("p_user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."is_super_admin_user"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."issue_anonymous_upgrade_claim"() RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
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


ALTER FUNCTION "public"."issue_anonymous_upgrade_claim"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."lock_fet_supply_cap"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  PERFORM pg_advisory_xact_lock(
    hashtextextended('public.fet_supply_cap', 0)
  );
END;
$$;


ALTER FUNCTION "public"."lock_fet_supply_cap"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."log_app_runtime_errors_batch"("p_errors" "jsonb") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_count integer := 0;
  v_error jsonb;
BEGIN
  IF p_errors IS NULL OR jsonb_array_length(p_errors) = 0 THEN
    RETURN 0;
  END IF;

  IF jsonb_array_length(p_errors) > 20 THEN
    RAISE EXCEPTION 'Batch size limit is 20 runtime errors';
  END IF;

  FOR v_error IN SELECT * FROM jsonb_array_elements(p_errors)
  LOOP
    INSERT INTO public.app_runtime_errors (
      user_id,
      session_id,
      reason,
      error_message,
      stack_trace,
      platform,
      app_version,
      created_at
    ) VALUES (
      v_user_id,
      left(nullif(trim(coalesce(v_error->>'session_id', '')), ''), 120),
      left(coalesce(nullif(trim(v_error->>'reason'), ''), 'app_exception'), 120),
      left(coalesce(nullif(trim(v_error->>'error_message'), ''), 'Unknown runtime error'), 2000),
      left(nullif(trim(coalesce(v_error->>'stack_trace', '')), ''), 8000),
      left(nullif(trim(coalesce(v_error->>'platform', '')), ''), 40),
      left(nullif(trim(coalesce(v_error->>'app_version', '')), ''), 40),
      coalesce(
        (v_error->>'captured_at')::timestamptz,
        timezone('utc', now())
      )
    );

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;


ALTER FUNCTION "public"."log_app_runtime_errors_batch"("p_errors" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."log_product_event"("p_event_name" "text", "p_properties" "jsonb" DEFAULT '{}'::"jsonb", "p_session_id" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_event_id uuid;
BEGIN
  IF p_event_name IS NULL OR trim(p_event_name) = '' THEN
    RAISE EXCEPTION 'event_name is required';
  END IF;

  INSERT INTO public.product_events (
    user_id,
    event_name,
    properties,
    session_id
  ) VALUES (
    v_user_id,
    trim(p_event_name),
    coalesce(p_properties, '{}'::jsonb),
    nullif(trim(coalesce(p_session_id, '')), '')
  )
  RETURNING id INTO v_event_id;

  RETURN v_event_id;
END;
$$;


ALTER FUNCTION "public"."log_product_event"("p_event_name" "text", "p_properties" "jsonb", "p_session_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."log_product_events_batch"("p_events" "jsonb") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_count integer := 0;
  v_event jsonb;
BEGIN
  IF p_events IS NULL OR jsonb_array_length(p_events) = 0 THEN
    RETURN 0;
  END IF;

  -- Cap at 50 events per batch to prevent abuse
  IF jsonb_array_length(p_events) > 50 THEN
    RAISE EXCEPTION 'Batch size limit is 50 events';
  END IF;

  FOR v_event IN SELECT * FROM jsonb_array_elements(p_events)
  LOOP
    INSERT INTO public.product_events (
      user_id,
      event_name,
      properties,
      session_id,
      created_at
    ) VALUES (
      v_user_id,
      trim(v_event->>'event_name'),
      coalesce(v_event->'properties', '{}'::jsonb),
      nullif(trim(coalesce(v_event->>'session_id', '')), ''),
      coalesce(
        (v_event->>'created_at')::timestamptz,
        timezone('utc', now())
      )
    );
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;


ALTER FUNCTION "public"."log_product_events_batch"("p_events" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_all_notifications_read"() RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  UPDATE public.user_notifications
  SET read_at = COALESCE(read_at, now())
  WHERE user_id = auth.uid()
    AND read_at IS NULL;
$$;


ALTER FUNCTION "public"."mark_all_notifications_read"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_notification_read"("p_notification_id" "uuid") RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  UPDATE public.user_notifications
  SET read_at = COALESCE(read_at, now())
  WHERE id = p_notification_id
    AND user_id = auth.uid();
$$;


ALTER FUNCTION "public"."mark_notification_read"("p_notification_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."merge_anonymous_to_authenticated"("p_anon_id" "uuid", "p_auth_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."merge_anonymous_to_authenticated"("p_anon_id" "uuid", "p_auth_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."merge_anonymous_to_authenticated_secure"("p_anon_id" "uuid", "p_claim_token" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
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


ALTER FUNCTION "public"."merge_anonymous_to_authenticated_secure"("p_anon_id" "uuid", "p_claim_token" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."normalize_match_status"("p_status" "text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    AS $$
  SELECT CASE
    WHEN p_status IS NULL OR trim(p_status) = '' THEN 'scheduled'
    WHEN lower(trim(p_status)) IN ('scheduled', 'upcoming', 'not_started', 'pending') THEN 'scheduled'
    WHEN lower(trim(p_status)) IN ('live', 'in_play', 'inprogress', 'in_progress', 'playing') THEN 'live'
    WHEN lower(trim(p_status)) IN ('finished', 'complete', 'completed', 'ft', 'full_time') THEN 'finished'
    WHEN lower(trim(p_status)) IN ('postponed') THEN 'postponed'
    WHEN lower(trim(p_status)) IN ('cancelled', 'canceled', 'voided') THEN 'cancelled'
    ELSE public.safe_catalog_key(p_status)
  END;
$$;


ALTER FUNCTION "public"."normalize_match_status"("p_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_wallet_credit"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  IF NEW.direction = 'credit' AND NEW.amount_fet >= 10 THEN
    PERFORM send_push_to_user(
      NEW.user_id,
      'wallet_credit',
      '💰 FET Received',
      NEW.title || ' — +' || NEW.amount_fet || ' FET',
      jsonb_build_object('screen', '/profile/wallet')
    );
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."notify_wallet_credit"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."phone_auth_email"("p_phone" "text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    AS $$
  SELECT CASE
    WHEN p_phone IS NULL OR regexp_replace(p_phone, '\D', '', 'g') = '' THEN NULL
    ELSE 'phone-' || regexp_replace(p_phone, '\D', '', 'g') || '@phone.fanzone.invalid'
  END;
$$;


ALTER FUNCTION "public"."phone_auth_email"("p_phone" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_competition_derived_fields"("p_competition_ids" "text"[] DEFAULT NULL::"text"[]) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_updated integer := 0;
BEGIN
  WITH target_competitions AS (
    SELECT c.id
    FROM public.competitions c
    WHERE p_competition_ids IS NULL
       OR c.id = ANY (p_competition_ids)
  ),
  season_catalog AS (
    SELECT
      ranked.competition_id,
      array_agg(ranked.season_label ORDER BY ranked.sort_rank) AS season_labels,
      (array_agg(ranked.season_label ORDER BY ranked.sort_rank))[1] AS current_season_label
    FROM (
      SELECT
        s.competition_id,
        s.season_label,
        row_number() OVER (
          PARTITION BY s.competition_id
          ORDER BY s.is_current DESC, s.start_year DESC, s.end_year DESC, s.season_label DESC
        ) AS sort_rank
      FROM public.seasons s
      JOIN target_competitions tc
        ON tc.id = s.competition_id
    ) ranked
    GROUP BY ranked.competition_id
  ),
  team_counts AS (
    SELECT
      match_rows.competition_id,
      count(DISTINCT match_rows.team_id)::integer AS team_count
    FROM (
      SELECT m.competition_id, m.home_team_id AS team_id
      FROM public.matches m
      JOIN target_competitions tc
        ON tc.id = m.competition_id
      WHERE m.home_team_id IS NOT NULL

      UNION ALL

      SELECT m.competition_id, m.away_team_id AS team_id
      FROM public.matches m
      JOIN target_competitions tc
        ON tc.id = m.competition_id
      WHERE m.away_team_id IS NOT NULL
    ) match_rows
    GROUP BY match_rows.competition_id
  )
  UPDATE public.competitions c
  SET
    seasons = coalesce(sc.season_labels, '{}'::text[]),
    season = sc.current_season_label,
    team_count = coalesce(team_counts.team_count, 0),
    country_or_region = coalesce(
      nullif(btrim(c.country_or_region), ''),
      nullif(btrim(c.country), ''),
      nullif(btrim(c.region), ''),
      'Global'
    ),
    updated_at = timezone('utc', now())
  FROM target_competitions target
  LEFT JOIN season_catalog sc
    ON sc.competition_id = target.id
  LEFT JOIN team_counts
    ON team_counts.competition_id = target.id
  WHERE c.id = target.id;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN coalesce(v_updated, 0);
END;
$$;


ALTER FUNCTION "public"."refresh_competition_derived_fields"("p_competition_ids" "text"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_global_leaderboard"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_job_id uuid;
BEGIN
  INSERT INTO public.cron_job_log (job_name, status)
  VALUES ('refresh_global_leaderboard', 'running')
  RETURNING id INTO v_job_id;

  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_global_leaderboard;

    UPDATE public.cron_job_log
    SET status = 'completed',
        completed_at = now(),
        duration_ms = EXTRACT(EPOCH FROM (now() - started_at))::integer * 1000
    WHERE id = v_job_id;
  EXCEPTION WHEN OTHERS THEN
    UPDATE public.cron_job_log
    SET status = 'failed',
        completed_at = now(),
        error_message = SQLERRM,
        duration_ms = EXTRACT(EPOCH FROM (now() - started_at))::integer * 1000
    WHERE id = v_job_id;
    RAISE;
  END;
END;
$$;


ALTER FUNCTION "public"."refresh_global_leaderboard"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_materialized_views"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_refreshed text[] := '{}';
  v_view_name text;
BEGIN
  FOR v_view_name IN
    SELECT matviewname
    FROM pg_matviews
    WHERE schemaname = 'public'
    ORDER BY matviewname
  LOOP
    BEGIN
      EXECUTE format('REFRESH MATERIALIZED VIEW CONCURRENTLY public.%I', v_view_name);
      v_refreshed := v_refreshed || v_view_name;
    EXCEPTION WHEN others THEN
      -- Fallback to non-concurrent refresh if unique index is missing
      BEGIN
        EXECUTE format('REFRESH MATERIALIZED VIEW public.%I', v_view_name);
        v_refreshed := v_refreshed || v_view_name;
      EXCEPTION WHEN others THEN
        NULL; -- skip views that can't be refreshed
      END;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'refreshed', to_jsonb(v_refreshed),
    'refreshed_at', timezone('utc', now())
  );
END;
$$;


ALTER FUNCTION "public"."refresh_materialized_views"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_season_leaderboard"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  IF to_regclass('public.mv_season_leaderboard') IS NOT NULL THEN
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_season_leaderboard;
  END IF;
END;
$$;


ALTER FUNCTION "public"."refresh_season_leaderboard"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_team_derived_fields"("p_team_ids" "text"[] DEFAULT NULL::"text"[]) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_updated integer := 0;
BEGIN
  WITH target_teams AS (
    SELECT t.id
    FROM public.teams t
    WHERE p_team_ids IS NULL
       OR t.id = ANY (p_team_ids)
  ),
  alias_rows AS (
    SELECT
      deduped.team_id,
      array_agg(deduped.alias_name ORDER BY lower(deduped.alias_name), deduped.alias_name) AS aliases
    FROM (
      SELECT DISTINCT
        ta.team_id,
        btrim(ta.alias_name) AS alias_name
      FROM public.team_aliases ta
      JOIN target_teams tt
        ON tt.id = ta.team_id
      WHERE btrim(coalesce(ta.alias_name, '')) <> ''
    ) deduped
    GROUP BY deduped.team_id
  ),
  team_match_competitions AS (
    SELECT
      rows.team_id,
      rows.competition_id,
      count(*)::integer AS match_count,
      max(rows.match_date) AS last_match_date
    FROM (
      SELECT m.home_team_id AS team_id, m.competition_id, m.match_date
      FROM public.matches m
      JOIN target_teams tt
        ON tt.id = m.home_team_id
      WHERE m.home_team_id IS NOT NULL

      UNION ALL

      SELECT m.away_team_id AS team_id, m.competition_id, m.match_date
      FROM public.matches m
      JOIN target_teams tt
        ON tt.id = m.away_team_id
      WHERE m.away_team_id IS NOT NULL
    ) rows
    GROUP BY rows.team_id, rows.competition_id
  ),
  competition_rows AS (
    SELECT
      tmc.team_id,
      array_agg(tmc.competition_id ORDER BY tmc.last_match_date DESC, tmc.competition_id) AS competition_ids
    FROM team_match_competitions tmc
    GROUP BY tmc.team_id
  ),
  league_rows AS (
    SELECT DISTINCT ON (tmc.team_id)
      tmc.team_id,
      c.name AS league_name
    FROM team_match_competitions tmc
    JOIN public.competitions c
      ON c.id = tmc.competition_id
    WHERE coalesce(c.competition_type, 'league') = 'league'
    ORDER BY tmc.team_id, tmc.match_count DESC, tmc.last_match_date DESC, c.name
  )
  UPDATE public.teams t
  SET
    aliases = coalesce(alias_rows.aliases, '{}'::text[]),
    competition_ids = coalesce(competition_rows.competition_ids, '{}'::text[]),
    league_name = coalesce(league_rows.league_name, t.league_name),
    updated_at = timezone('utc', now())
  FROM target_teams target
  LEFT JOIN alias_rows
    ON alias_rows.team_id = target.id
  LEFT JOIN competition_rows
    ON competition_rows.team_id = target.id
  LEFT JOIN league_rows
    ON league_rows.team_id = target.id
  WHERE t.id = target.id;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN coalesce(v_updated, 0);
END;
$$;


ALTER FUNCTION "public"."refresh_team_derived_fields"("p_team_ids" "text"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_team_form_features_for_match"("p_match_id" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_match record;
BEGIN
  SELECT id, home_team_id, away_team_id
  INTO v_match
  FROM public.matches
  WHERE id = p_match_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match % not found', p_match_id;
  END IF;

  PERFORM public.upsert_team_form_feature(v_match.id, v_match.home_team_id);
  PERFORM public.upsert_team_form_feature(v_match.id, v_match.away_team_id);
END;
$$;


ALTER FUNCTION "public"."refresh_team_form_features_for_match"("p_match_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."remove_openfootball_sync_schedule"("p_job_name" "text" DEFAULT 'market-sync-openfootball'::"text") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'cron'
    AS $$
DECLARE
    v_existing_job_id bigint;
BEGIN
    SELECT jobid
    INTO v_existing_job_id
    FROM cron.job
    WHERE jobname = p_job_name
    LIMIT 1;

    IF v_existing_job_id IS NOT NULL THEN
        PERFORM cron.unschedule(v_existing_job_id);
    END IF;

    RETURN COALESCE(v_existing_job_id, 0);
END;
$$;


ALTER FUNCTION "public"."remove_openfootball_sync_schedule"("p_job_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."repair_wallet_bootstrap_gaps"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_repaired_count integer := 0;
  v_expected_bootstrap_balance bigint := coalesce(
    public.app_config_bigint('foundation_grant_fet', 50),
    50
  );
BEGIN
  WITH candidate_wallets AS (
    SELECT
      audit.user_id,
      audit.available_balance_fet,
      audit.locked_balance_fet
    FROM public.audit_wallet_bootstrap_gaps() audit
    WHERE audit.non_bonus_transaction_count = 0
      AND NOT EXISTS (
        SELECT 1
        FROM public.fet_wallet_transactions t
        WHERE t.user_id = audit.user_id
          AND t.tx_type = 'wallet_balance_correction'
      )
    FOR UPDATE
  ),
  updated_wallets AS (
    UPDATE public.fet_wallets wallet
    SET available_balance_fet = v_expected_bootstrap_balance,
        updated_at = now()
    FROM candidate_wallets candidate
    WHERE wallet.user_id = candidate.user_id
    RETURNING
      wallet.user_id,
      candidate.available_balance_fet AS balance_before_fet,
      v_expected_bootstrap_balance AS balance_after_fet
  ),
  inserted_transactions AS (
    INSERT INTO public.fet_wallet_transactions (
      user_id,
      tx_type,
      direction,
      amount_fet,
      balance_before_fet,
      balance_after_fet,
      reference_type,
      metadata
    )
    SELECT
      updated.user_id,
      'wallet_balance_correction',
      'credit',
      updated.balance_after_fet - updated.balance_before_fet,
      updated.balance_before_fet,
      updated.balance_after_fet,
      'wallet_repair',
      jsonb_build_object(
        'reason', 'corrected wallet bootstrap balance',
        'expected_bootstrap_balance', v_expected_bootstrap_balance
      )
    FROM updated_wallets updated
    RETURNING 1
  )
  SELECT count(*) INTO v_repaired_count
  FROM inserted_transactions;

  RETURN coalesce(v_repaired_count, 0);
END;
$$;


ALTER FUNCTION "public"."repair_wallet_bootstrap_gaps"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."require_active_admin_user"() RETURNS "uuid"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_role text := current_setting('request.jwt.claims', true)::jsonb->>'role';
BEGIN
  -- If invoked via service_role client (e.g. edge function), use the machine UUID
  IF coalesce(v_role, '') = 'service_role' THEN
    RETURN '00000000-0000-0000-0000-000000000000'::uuid;
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


ALTER FUNCTION "public"."require_active_admin_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."require_admin_manager_user"() RETURNS "uuid"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
DECLARE
  v_user_id uuid;
BEGIN
  v_user_id := public.require_active_admin_user();

  IF NOT public.is_admin_manager(v_user_id) THEN
    RAISE EXCEPTION 'Admin manager role required';
  END IF;

  RETURN v_user_id;
END;
$$;


ALTER FUNCTION "public"."require_admin_manager_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."require_super_admin_user"() RETURNS "uuid"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
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

  IF NOT public.is_super_admin_user(v_user_id) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN v_user_id;
END;
$$;


ALTER FUNCTION "public"."require_super_admin_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."resolve_auth_user_phone"("p_user_id" "uuid") RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
  SELECT COALESCE(
    NULLIF(u.phone, ''),
    NULLIF(u.raw_user_meta_data ->> 'phone_number', ''),
    CASE
      WHEN u.email ~* '^phone-[0-9]+@phone\.fanzone\.invalid$'
      THEN '+' || substring(u.email FROM '^phone-([0-9]+)@phone\.fanzone\.invalid$')
      ELSE NULL
    END
  )
  FROM auth.users AS u
  WHERE u.id = p_user_id;
$_$;


ALTER FUNCTION "public"."resolve_auth_user_phone"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rls_auto_enable"() RETURNS "event_trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."rls_auto_enable"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."safe_catalog_key"("p_value" "text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    AS $$
  SELECT trim(both '-' FROM regexp_replace(lower(coalesce(p_value, '')), '[^a-z0-9]+', '-', 'g'));
$$;


ALTER FUNCTION "public"."safe_catalog_key"("p_value" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."score_finished_matches_with_pending_predictions"("p_limit" integer DEFAULT 50) RETURNS integer
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."score_finished_matches_with_pending_predictions"("p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."score_user_predictions_for_match"("p_match_id" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_match record;
  v_processed integer := 0;
  v_rewards integer := 0;
  rec record;
  v_points integer;
  v_reward bigint;
  v_inserted_reward_id uuid;
BEGIN
  SELECT *
  INTO v_match
  FROM public.matches
  WHERE id = p_match_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match % not found', p_match_id;
  END IF;

  IF v_match.match_status <> 'finished'
    OR v_match.home_goals IS NULL
    OR v_match.away_goals IS NULL
  THEN
    RAISE EXCEPTION 'Match % is not finished', p_match_id;
  END IF;

  FOR rec IN
    SELECT *
    FROM public.user_predictions
    WHERE match_id = p_match_id
      AND reward_status = 'pending'
  LOOP
    v_points := 0;

    IF rec.predicted_result_code IS NOT NULL
      AND rec.predicted_result_code = v_match.result_code
    THEN
      v_points := v_points + 3;
    END IF;

    IF rec.predicted_over25 IS NOT NULL
      AND rec.predicted_over25 = ((v_match.home_goals + v_match.away_goals) > 2)
    THEN
      v_points := v_points + 1;
    END IF;

    IF rec.predicted_btts IS NOT NULL
      AND rec.predicted_btts = (v_match.home_goals > 0 AND v_match.away_goals > 0)
    THEN
      v_points := v_points + 1;
    END IF;

    IF rec.predicted_home_goals IS NOT NULL
      AND rec.predicted_away_goals IS NOT NULL
      AND rec.predicted_home_goals = v_match.home_goals
      AND rec.predicted_away_goals = v_match.away_goals
    THEN
      v_points := v_points + 2;
    END IF;

    v_reward := CASE
      WHEN v_points >= 7 THEN 40
      WHEN v_points >= 5 THEN 20
      WHEN v_points >= 3 THEN 10
      ELSE 0
    END;

    UPDATE public.user_predictions
    SET
      points_awarded = v_points,
      reward_status = CASE WHEN v_reward > 0 THEN 'awarded' ELSE 'no_reward' END,
      updated_at = now()
    WHERE id = rec.id;

    IF v_reward > 0 THEN
      INSERT INTO public.token_rewards (
        user_id,
        user_prediction_id,
        match_id,
        reward_type,
        token_amount,
        status,
        awarded_at,
        created_at
      )
      VALUES (
        rec.user_id,
        rec.id,
        p_match_id,
        'prediction_reward',
        v_reward,
        'awarded',
        now(),
        now()
      )
      ON CONFLICT (user_prediction_id, reward_type) DO NOTHING
      RETURNING id INTO v_inserted_reward_id;

      IF v_inserted_reward_id IS NOT NULL THEN
        INSERT INTO public.fet_wallets (
          user_id,
          available_balance_fet,
          locked_balance_fet,
          created_at,
          updated_at
        )
        VALUES (rec.user_id, 0, 0, now(), now())
        ON CONFLICT (user_id) DO NOTHING;

        UPDATE public.fet_wallets
        SET
          available_balance_fet = available_balance_fet + v_reward,
          updated_at = now()
        WHERE user_id = rec.user_id;

        INSERT INTO public.fet_wallet_transactions (
          user_id,
          tx_type,
          direction,
          amount_fet,
          balance_before_fet,
          balance_after_fet,
          reference_type,
          reference_id,
          metadata,
          title,
          created_at
        )
        SELECT
          w.user_id,
          'prediction_reward',
          'credit',
          v_reward,
          greatest(w.available_balance_fet - v_reward, 0),
          w.available_balance_fet,
          'user_prediction',
          rec.id::text,
          jsonb_build_object(
            'match_id', p_match_id,
            'points_awarded', v_points
          ),
          'Prediction reward',
          now()
        FROM public.fet_wallets w
        WHERE w.user_id = rec.user_id;

        v_rewards := v_rewards + 1;
      END IF;
    END IF;

    v_processed := v_processed + 1;
    v_inserted_reward_id := NULL;
  END LOOP;

  RETURN jsonb_build_object(
    'match_id', p_match_id,
    'processed_predictions', v_processed,
    'awarded_rewards', v_rewards
  );
END;
$$;


ALTER FUNCTION "public"."score_user_predictions_for_match"("p_match_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."season_end_year"("p_label" "text") RETURNS integer
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
DECLARE
  parts text[];
  start_year integer;
  end_part text;
BEGIN
  IF p_label IS NULL OR trim(p_label) = '' THEN
    RETURN extract(year FROM now())::integer;
  END IF;

  parts := regexp_match(trim(p_label), '(\d{4})(?:\D+(\d{2,4}))?');
  IF parts IS NULL THEN
    RETURN extract(year FROM now())::integer;
  END IF;

  start_year := parts[1]::integer;
  end_part := parts[2];

  IF end_part IS NULL OR trim(end_part) = '' THEN
    RETURN start_year + 1;
  END IF;

  IF length(end_part) = 2 THEN
    RETURN ((start_year / 100) * 100) + end_part::integer;
  END IF;

  RETURN end_part::integer;
END;
$$;


ALTER FUNCTION "public"."season_end_year"("p_label" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."season_sort_key"("p_season" "text") RETURNS integer
    LANGUAGE "sql" IMMUTABLE
    AS $$
  SELECT coalesce(
    substring(coalesce(p_season, '') FROM '([0-9]{4})')::integer,
    0
  );
$$;


ALTER FUNCTION "public"."season_sort_key"("p_season" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."season_start_year"("p_label" "text") RETURNS integer
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
DECLARE
  parts text[];
  start_year integer;
BEGIN
  IF p_label IS NULL OR trim(p_label) = '' THEN
    RETURN extract(year FROM now())::integer;
  END IF;

  parts := regexp_match(trim(p_label), '(\d{4})(?:\D+(\d{2,4}))?');
  IF parts IS NULL THEN
    RETURN extract(year FROM now())::integer;
  END IF;

  start_year := parts[1]::integer;
  RETURN start_year;
END;
$$;


ALTER FUNCTION "public"."season_start_year"("p_label" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."send_push_to_user"("p_user_id" "uuid", "p_type" "text", "p_title" "text", "p_body" "text", "p_data" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_supabase_url text;
  v_service_key text;
  v_push_notify_secret text;
  v_payload jsonb;
BEGIN
  v_supabase_url := current_setting('app.settings.supabase_url', true);
  v_service_key := current_setting('app.settings.service_role_key', true);
  v_push_notify_secret := nullif(current_setting('app.settings.push_notify_secret', true), '');

  IF v_supabase_url IS NULL OR v_service_key IS NULL THEN
    RAISE NOTICE 'Push notification config not set — skipping';
    RETURN;
  END IF;

  v_payload := jsonb_build_object(
    'user_id', p_user_id,
    'type', p_type,
    'title', p_title,
    'body', p_body,
    'data', p_data
  );

  PERFORM net.http_post(
    url := v_supabase_url || '/functions/v1/push-notify',
    headers := jsonb_strip_nulls(
      jsonb_build_object(
        'Authorization', 'Bearer ' || v_service_key,
        'Content-Type', 'application/json',
        'x-push-notify-secret', v_push_notify_secret
      )
    ),
    body := v_payload
  );
END;
$$;


ALTER FUNCTION "public"."send_push_to_user"("p_user_id" "uuid", "p_type" "text", "p_title" "text", "p_body" "text", "p_data" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_row_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_row_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."submit_user_prediction"("p_match_id" "text", "p_predicted_result_code" "text" DEFAULT NULL::"text", "p_predicted_over25" boolean DEFAULT NULL::boolean, "p_predicted_btts" boolean DEFAULT NULL::boolean, "p_predicted_home_goals" integer DEFAULT NULL::integer, "p_predicted_away_goals" integer DEFAULT NULL::integer) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_match record;
  v_prediction_id uuid;
  v_result_code text;
  v_score_result_code text;
BEGIN
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


ALTER FUNCTION "public"."submit_user_prediction"("p_match_id" "text", "p_predicted_result_code" "text", "p_predicted_over25" boolean, "p_predicted_btts" boolean, "p_predicted_home_goals" integer, "p_predicted_away_goals" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_public_feature_flags_from_admin"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."sync_public_feature_flags_from_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."transfer_fet"("p_recipient_identifier" "text", "p_amount_fet" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
DECLARE
  v_clean_fan_id TEXT := regexp_replace(COALESCE(p_recipient_identifier, ''), '[^0-9]', '', 'g');
BEGIN
  IF v_clean_fan_id !~ '^\d{6}$' THEN
    RAISE EXCEPTION 'Recipient Fan ID must be exactly 6 digits';
  END IF;

  RETURN public.transfer_fet_by_fan_id(v_clean_fan_id, p_amount_fet);
END;
$_$;


ALTER FUNCTION "public"."transfer_fet"("p_recipient_identifier" "text", "p_amount_fet" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."transfer_fet_by_fan_id"("p_recipient_fan_id" "text", "p_amount_fet" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."transfer_fet_by_fan_id"("p_recipient_fan_id" "text", "p_amount_fet" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_team_form_feature"("p_match_id" "text", "p_team_id" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_match_date timestamptz;
BEGIN
  SELECT match_date
  INTO v_match_date
  FROM public.matches
  WHERE id = p_match_id;

  IF v_match_date IS NULL THEN
    RAISE EXCEPTION 'Match % not found', p_match_id;
  END IF;

  WITH recent_matches AS (
    SELECT *
    FROM public.matches
    WHERE match_status = 'finished'
      AND match_date < v_match_date
      AND (home_team_id = p_team_id OR away_team_id = p_team_id)
    ORDER BY match_date DESC
    LIMIT 5
  ),
  recent_home AS (
    SELECT *
    FROM public.matches
    WHERE match_status = 'finished'
      AND match_date < v_match_date
      AND home_team_id = p_team_id
    ORDER BY match_date DESC
    LIMIT 5
  ),
  recent_away AS (
    SELECT *
    FROM public.matches
    WHERE match_status = 'finished'
      AND match_date < v_match_date
      AND away_team_id = p_team_id
    ORDER BY match_date DESC
    LIMIT 5
  ),
  aggregates AS (
    SELECT
      COALESCE(sum(
        CASE
          WHEN home_team_id = p_team_id AND home_goals > away_goals THEN 3
          WHEN away_team_id = p_team_id AND away_goals > home_goals THEN 3
          WHEN home_goals = away_goals THEN 1
          ELSE 0
        END
      ), 0) AS last5_points,
      COALESCE(sum(
        CASE
          WHEN home_team_id = p_team_id AND home_goals > away_goals THEN 1
          WHEN away_team_id = p_team_id AND away_goals > home_goals THEN 1
          ELSE 0
        END
      ), 0) AS last5_wins,
      COALESCE(sum(CASE WHEN home_goals = away_goals THEN 1 ELSE 0 END), 0) AS last5_draws,
      COALESCE(sum(
        CASE
          WHEN home_team_id = p_team_id AND home_goals < away_goals THEN 1
          WHEN away_team_id = p_team_id AND away_goals < home_goals THEN 1
          ELSE 0
        END
      ), 0) AS last5_losses,
      COALESCE(sum(
        CASE
          WHEN home_team_id = p_team_id THEN COALESCE(home_goals, 0)
          ELSE COALESCE(away_goals, 0)
        END
      ), 0) AS last5_goals_for,
      COALESCE(sum(
        CASE
          WHEN home_team_id = p_team_id THEN COALESCE(away_goals, 0)
          ELSE COALESCE(home_goals, 0)
        END
      ), 0) AS last5_goals_against,
      COALESCE(sum(
        CASE
          WHEN home_team_id = p_team_id AND COALESCE(away_goals, 0) = 0 THEN 1
          WHEN away_team_id = p_team_id AND COALESCE(home_goals, 0) = 0 THEN 1
          ELSE 0
        END
      ), 0) AS last5_clean_sheets,
      COALESCE(sum(
        CASE
          WHEN home_team_id = p_team_id AND COALESCE(home_goals, 0) = 0 THEN 1
          WHEN away_team_id = p_team_id AND COALESCE(away_goals, 0) = 0 THEN 1
          ELSE 0
        END
      ), 0) AS last5_failed_to_score,
      COALESCE(sum(
        CASE
          WHEN COALESCE(home_goals, 0) + COALESCE(away_goals, 0) > 2 THEN 1
          ELSE 0
        END
      ), 0) AS over25_last5,
      COALESCE(sum(
        CASE
          WHEN COALESCE(home_goals, 0) > 0
           AND COALESCE(away_goals, 0) > 0 THEN 1
          ELSE 0
        END
      ), 0) AS btts_last5
    FROM recent_matches
  ),
  home_points AS (
    SELECT
      COALESCE(sum(
        CASE
          WHEN COALESCE(home_goals, 0) > COALESCE(away_goals, 0) THEN 3
          WHEN COALESCE(home_goals, 0) = COALESCE(away_goals, 0) THEN 1
          ELSE 0
        END
      ), 0) AS home_form_last5
    FROM recent_home
  ),
  away_points AS (
    SELECT
      COALESCE(sum(
        CASE
          WHEN COALESCE(away_goals, 0) > COALESCE(home_goals, 0) THEN 3
          WHEN COALESCE(home_goals, 0) = COALESCE(away_goals, 0) THEN 1
          ELSE 0
        END
      ), 0) AS away_form_last5
    FROM recent_away
  )
  INSERT INTO public.team_form_features (
    match_id,
    team_id,
    last5_points,
    last5_wins,
    last5_draws,
    last5_losses,
    last5_goals_for,
    last5_goals_against,
    last5_clean_sheets,
    last5_failed_to_score,
    home_form_last5,
    away_form_last5,
    over25_last5,
    btts_last5,
    created_at,
    updated_at
  )
  SELECT
    p_match_id,
    p_team_id,
    a.last5_points,
    a.last5_wins,
    a.last5_draws,
    a.last5_losses,
    a.last5_goals_for,
    a.last5_goals_against,
    a.last5_clean_sheets,
    a.last5_failed_to_score,
    hp.home_form_last5,
    ap.away_form_last5,
    a.over25_last5,
    a.btts_last5,
    now(),
    now()
  FROM aggregates a
  CROSS JOIN home_points hp
  CROSS JOIN away_points ap
  ON CONFLICT (match_id, team_id) DO UPDATE SET
    last5_points = EXCLUDED.last5_points,
    last5_wins = EXCLUDED.last5_wins,
    last5_draws = EXCLUDED.last5_draws,
    last5_losses = EXCLUDED.last5_losses,
    last5_goals_for = EXCLUDED.last5_goals_for,
    last5_goals_against = EXCLUDED.last5_goals_against,
    last5_clean_sheets = EXCLUDED.last5_clean_sheets,
    last5_failed_to_score = EXCLUDED.last5_failed_to_score,
    home_form_last5 = EXCLUDED.home_form_last5,
    away_form_last5 = EXCLUDED.away_form_last5,
    over25_last5 = EXCLUDED.over25_last5,
    btts_last5 = EXCLUDED.btts_last5,
    updated_at = now();
END;
$$;


ALTER FUNCTION "public"."upsert_team_form_feature"("p_match_id" "text", "p_team_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_vault_secret"("p_name" "text", "p_secret" "text", "p_description" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'vault'
    AS $$
DECLARE
    v_secret_id uuid;
BEGIN
    IF p_name IS NULL OR btrim(p_name) = '' THEN
        RAISE EXCEPTION 'Secret name is required';
    END IF;

    IF p_secret IS NULL OR btrim(p_secret) = '' THEN
        RAISE EXCEPTION 'Secret value is required';
    END IF;

    SELECT id
    INTO v_secret_id
    FROM vault.decrypted_secrets
    WHERE name = p_name
    LIMIT 1;

    IF v_secret_id IS NULL THEN
        RETURN vault.create_secret(
            p_secret,
            p_name,
            COALESCE(p_description, 'Managed by market refresh scheduler')
        );
    END IF;

    PERFORM vault.update_secret(
        v_secret_id,
        p_secret,
        p_name,
        COALESCE(p_description, 'Managed by market refresh scheduler')
    );

    RETURN v_secret_id;
END;
$$;


ALTER FUNCTION "public"."upsert_vault_secret"("p_name" "text", "p_secret" "text", "p_description" "text") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."account_deletion_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "reason" "text" NOT NULL,
    "contact_email" "text",
    "resolution_notes" "text",
    "requested_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "processed_at" timestamp with time zone,
    "processed_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "account_deletion_requests_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'in_review'::"text", 'completed'::"text", 'rejected'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."account_deletion_requests" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."admin_audit_logs" (
    "id" bigint NOT NULL,
    "admin_user_id" "uuid",
    "action" "text" NOT NULL,
    "module" "text" DEFAULT ''::"text" NOT NULL,
    "target_type" "text" DEFAULT ''::"text" NOT NULL,
    "target_id" "text" DEFAULT ''::"text" NOT NULL,
    "before_state" "jsonb" DEFAULT '{}'::"jsonb",
    "after_state" "jsonb" DEFAULT '{}'::"jsonb",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."admin_audit_logs" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."admin_audit_logs_enriched" AS
 SELECT "al"."id",
    "al"."admin_user_id",
    "al"."action",
    "al"."module",
    "al"."target_type",
    "al"."target_id",
    "al"."before_state",
    "al"."after_state",
    "al"."metadata",
    "al"."created_at",
    "au"."display_name" AS "admin_name",
    "au"."phone" AS "admin_phone"
   FROM ("public"."admin_audit_logs" "al"
     LEFT JOIN "public"."admin_users" "au" ON (("au"."id" = "al"."admin_user_id")))
  WHERE "public"."is_active_admin_operator"("auth"."uid"());


ALTER VIEW "public"."admin_audit_logs_enriched" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."admin_audit_logs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."admin_audit_logs_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."admin_audit_logs_id_seq" OWNED BY "public"."admin_audit_logs"."id";



CREATE TABLE IF NOT EXISTS "public"."feature_flags" (
    "key" "text" NOT NULL,
    "market" "text" DEFAULT 'global'::"text" NOT NULL,
    "platform" "text" DEFAULT 'all'::"text" NOT NULL,
    "enabled" boolean DEFAULT false NOT NULL,
    "rollout_pct" integer DEFAULT 100 NOT NULL,
    "description" "text",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "feature_flags_market_check" CHECK (("market" ~ '^[a-z_]+$'::"text")),
    CONSTRAINT "feature_flags_platform_check" CHECK (("platform" = ANY (ARRAY['all'::"text", 'android'::"text", 'ios'::"text", 'web'::"text"]))),
    CONSTRAINT "feature_flags_rollout_check" CHECK ((("rollout_pct" >= 0) AND ("rollout_pct" <= 100)))
);


ALTER TABLE "public"."feature_flags" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."admin_feature_flags" AS
 SELECT (((("key" || ':'::"text") || "market") || ':'::"text") || "platform") AS "id",
    "key",
    "initcap"("replace"("key", '_'::"text", ' '::"text")) AS "label",
    "description",
    "enabled" AS "is_enabled",
    "market",
    "split_part"("key", '_'::"text", 1) AS "module",
    "jsonb_build_object"('platform', "platform", 'rollout_pct', "rollout_pct") AS "config",
    NULL::"uuid" AS "updated_by",
    "updated_at" AS "created_at",
    "updated_at"
   FROM "public"."feature_flags" "ff"
  WHERE "public"."is_active_admin_operator"("auth"."uid"());


ALTER VIEW "public"."admin_feature_flags" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."anonymous_upgrade_claims" (
    "anon_user_id" "uuid" NOT NULL,
    "claim_token" "text" NOT NULL,
    "issued_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "expires_at" timestamp with time zone NOT NULL,
    "consumed_at" timestamp with time zone,
    "consumed_by_user_id" "uuid"
);


ALTER TABLE "public"."anonymous_upgrade_claims" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."competitions" (
    "id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "short_name" "text" NOT NULL,
    "country" "text" NOT NULL,
    "tier" integer DEFAULT 1,
    "data_source" "text" NOT NULL,
    "source_file" "text",
    "seasons" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "team_count" integer,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "season" "text",
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "is_featured" boolean DEFAULT false NOT NULL,
    "region" "text",
    "competition_type" "text",
    "event_tag" "text",
    "start_date" "date",
    "end_date" "date",
    "country_or_region" "text",
    "is_international" boolean DEFAULT false NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    CONSTRAINT "competitions_tier_top_flight_only" CHECK (("tier" = 1))
);


ALTER TABLE "public"."competitions" OWNER TO "postgres";


COMMENT ON COLUMN "public"."competitions"."region" IS 'global, africa, europe, americas';



COMMENT ON COLUMN "public"."competitions"."competition_type" IS 'league, cup, tournament, friendly, qualifier';



COMMENT ON COLUMN "public"."competitions"."event_tag" IS 'Links to featured_events.event_tag (e.g. worldcup2026, ucl-final-2026)';



CREATE TABLE IF NOT EXISTS "public"."matches" (
    "id" "text" NOT NULL,
    "competition_id" "text" NOT NULL,
    "home_team_id" "text",
    "away_team_id" "text",
    "venue" "text",
    "source_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "live_home_score" integer,
    "live_away_score" integer,
    "live_minute" integer,
    "live_phase" "text",
    "last_live_checked_at" timestamp with time zone,
    "last_live_sync_confidence" numeric(5,4),
    "last_live_review_required" boolean DEFAULT false NOT NULL,
    "is_home_featured" boolean DEFAULT false NOT NULL,
    "hide_from_home" boolean DEFAULT false NOT NULL,
    "home_feature_rank" integer DEFAULT 0 NOT NULL,
    "season_id" "text",
    "stage" "text",
    "matchday_or_round" "text",
    "match_date" timestamp with time zone NOT NULL,
    "home_goals" integer,
    "away_goals" integer,
    "result_code" "text",
    "match_status" "text" DEFAULT 'scheduled'::"text" NOT NULL,
    "is_neutral" boolean DEFAULT false NOT NULL,
    "source_name" "text",
    "notes" "text",
    CONSTRAINT "matches_distinct_teams" CHECK ((("home_team_id" IS NULL) OR ("away_team_id" IS NULL) OR ("home_team_id" <> "away_team_id"))),
    CONSTRAINT "matches_last_live_sync_confidence_check" CHECK ((("last_live_sync_confidence" IS NULL) OR (("last_live_sync_confidence" >= (0)::numeric) AND ("last_live_sync_confidence" <= (1)::numeric)))),
    CONSTRAINT "matches_live_away_score_check" CHECK ((("live_away_score" IS NULL) OR ("live_away_score" >= 0))),
    CONSTRAINT "matches_live_home_score_check" CHECK ((("live_home_score" IS NULL) OR ("live_home_score" >= 0))),
    CONSTRAINT "matches_live_minute_check" CHECK ((("live_minute" IS NULL) OR (("live_minute" >= 0) AND ("live_minute" <= 200)))),
    CONSTRAINT "matches_match_status_canonical" CHECK (("match_status" = ANY (ARRAY['scheduled'::"text", 'live'::"text", 'finished'::"text", 'postponed'::"text", 'cancelled'::"text"]))),
    CONSTRAINT "matches_result_code_check" CHECK ((("result_code" IS NULL) OR ("result_code" = ANY (ARRAY['H'::"text", 'D'::"text", 'A'::"text"]))))
);


ALTER TABLE "public"."matches" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."app_competitions" AS
 SELECT "c"."id",
    "c"."name",
    COALESCE(NULLIF(TRIM(BOTH FROM "c"."short_name"), ''::"text"), "c"."name") AS "short_name",
    "c"."country_or_region" AS "country",
    COALESCE("c"."tier",
        CASE
            WHEN ("c"."competition_type" = 'league'::"text") THEN 1
            ELSE 2
        END) AS "tier",
    "c"."competition_type",
    "c"."is_international",
    "c"."is_active",
    "c"."created_at",
    "c"."updated_at",
    "current_season"."id" AS "current_season_id",
    "current_season"."season_label" AS "current_season_label",
    "count"("m"."id") FILTER (WHERE ("m"."match_date" >= "now"())) AS "future_match_count"
   FROM (("public"."competitions" "c"
     LEFT JOIN LATERAL ( SELECT "s"."id",
            "s"."season_label"
           FROM "public"."seasons" "s"
          WHERE (("s"."competition_id" = "c"."id") AND ("s"."is_current" = true))
          ORDER BY "s"."start_year" DESC
         LIMIT 1) "current_season" ON (true))
     LEFT JOIN "public"."matches" "m" ON (("m"."competition_id" = "c"."id")))
  GROUP BY "c"."id", "c"."name", "c"."short_name", "c"."country_or_region", "c"."tier", "c"."competition_type", "c"."is_international", "c"."is_active", "c"."created_at", "c"."updated_at", "current_season"."id", "current_season"."season_label";


ALTER VIEW "public"."app_competitions" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."app_competitions_ranked" AS
 SELECT "id",
    "name",
    "short_name",
    "country",
    "tier",
    "competition_type",
    "is_international",
    "is_active",
    "created_at",
    "updated_at",
    "current_season_id",
    "current_season_label",
    "future_match_count",
        CASE
            WHEN ("lower"("name") ~~ '%premier league%'::"text") THEN (1)::bigint
            WHEN ("lower"("name") ~~ '%champions league%'::"text") THEN (2)::bigint
            WHEN ("lower"("name") ~~ '%la liga%'::"text") THEN (3)::bigint
            WHEN ("lower"("name") ~~ '%serie a%'::"text") THEN (4)::bigint
            WHEN ("lower"("name") ~~ '%bundesliga%'::"text") THEN (5)::bigint
            WHEN ("lower"("name") ~~ '%ligue 1%'::"text") THEN (6)::bigint
            WHEN "is_international" THEN (20)::bigint
            ELSE (100 + "row_number"() OVER (ORDER BY "name"))
        END AS "catalog_rank"
   FROM "public"."app_competitions" "ac";


ALTER VIEW "public"."app_competitions_ranked" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."app_config_remote" (
    "key" "text" NOT NULL,
    "value" "jsonb" DEFAULT 'null'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."app_config_remote" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."app_matches" AS
 SELECT "m"."id",
    "m"."competition_id",
    "c"."name" AS "competition_name",
    "m"."season_id",
    "s"."season_label",
    "m"."stage",
    "m"."matchday_or_round" AS "round",
    "m"."matchday_or_round",
    "m"."match_date",
    "m"."match_date" AS "date",
    "to_char"(("m"."match_date" AT TIME ZONE 'UTC'::"text"), 'HH24:MI'::"text") AS "kickoff_time",
    "m"."home_team_id",
    "ht"."name" AS "home_team",
    COALESCE("ht"."crest_url", "ht"."logo_url") AS "home_logo_url",
    "m"."away_team_id",
    "at"."name" AS "away_team",
    COALESCE("at"."crest_url", "at"."logo_url") AS "away_logo_url",
    "m"."home_goals" AS "ft_home",
    "m"."away_goals" AS "ft_away",
    "m"."home_goals",
    "m"."away_goals",
    "m"."result_code",
        CASE
            WHEN ("m"."match_status" = ANY (ARRAY['scheduled'::"text", 'not_started'::"text", 'pending'::"text"])) THEN 'upcoming'::"text"
            WHEN ("m"."match_status" = ANY (ARRAY['live'::"text", 'in_play'::"text", 'in_progress'::"text", 'playing'::"text"])) THEN 'live'::"text"
            WHEN ("m"."match_status" = ANY (ARRAY['finished'::"text", 'complete'::"text", 'completed'::"text", 'full_time'::"text", 'ft'::"text"])) THEN 'finished'::"text"
            ELSE COALESCE(NULLIF("lower"("m"."match_status"), ''::"text"), 'upcoming'::"text")
        END AS "status",
    "m"."match_status",
    "m"."is_neutral",
    "m"."source_name" AS "data_source",
    "m"."source_name",
    "m"."source_url",
    "m"."notes",
    "m"."created_at",
    "m"."updated_at",
    "m"."live_home_score",
    "m"."live_away_score",
    "m"."live_minute",
    "m"."live_phase",
    "m"."last_live_checked_at",
    "m"."last_live_sync_confidence",
    "m"."last_live_review_required"
   FROM (((("public"."matches" "m"
     LEFT JOIN "public"."competitions" "c" ON (("c"."id" = "m"."competition_id")))
     LEFT JOIN "public"."seasons" "s" ON (("s"."id" = "m"."season_id")))
     LEFT JOIN "public"."teams" "ht" ON (("ht"."id" = "m"."home_team_id")))
     LEFT JOIN "public"."teams" "at" ON (("at"."id" = "m"."away_team_id")));


ALTER VIEW "public"."app_matches" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."app_runtime_errors" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "session_id" "text",
    "reason" "text" NOT NULL,
    "error_message" "text" NOT NULL,
    "stack_trace" "text",
    "platform" "text",
    "app_version" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."app_runtime_errors" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."country_currency_map" (
    "country_code" "text" NOT NULL,
    "currency_code" "text" NOT NULL,
    "country_name" "text",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "country_currency_map_country_code_format" CHECK (("country_code" ~ '^[A-Z]{2}$'::"text")),
    CONSTRAINT "country_currency_map_currency_code_format" CHECK (("currency_code" ~ '^[A-Z]{3}$'::"text"))
);


ALTER TABLE "public"."country_currency_map" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."country_region_map" (
    "country_code" "text" NOT NULL,
    "region" "text" DEFAULT 'global'::"text" NOT NULL,
    "country_name" "text" NOT NULL,
    "flag_emoji" "text" DEFAULT '🌍'::"text" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "country_region_map_code_format" CHECK (("country_code" ~ '^[A-Z]{2}$'::"text")),
    CONSTRAINT "country_region_map_region_check" CHECK (("region" = ANY (ARRAY['africa'::"text", 'europe'::"text", 'americas'::"text", 'north_america'::"text", 'global'::"text"])))
);


ALTER TABLE "public"."country_region_map" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."cron_job_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "job_name" "text" NOT NULL,
    "status" "text" DEFAULT 'running'::"text" NOT NULL,
    "started_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "completed_at" timestamp with time zone,
    "duration_ms" integer,
    "result" "jsonb" DEFAULT '{}'::"jsonb",
    "error_message" "text",
    CONSTRAINT "cron_job_log_status_check" CHECK (("status" = ANY (ARRAY['running'::"text", 'completed'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."cron_job_log" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."currency_display_metadata" (
    "currency_code" "text" NOT NULL,
    "symbol" "text" NOT NULL,
    "decimals" integer DEFAULT 2 NOT NULL,
    "space_separated" boolean DEFAULT false NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "currency_display_code_format" CHECK (("currency_code" ~ '^[A-Z]{3}$'::"text")),
    CONSTRAINT "currency_display_decimals" CHECK ((("decimals" >= 0) AND ("decimals" <= 4)))
);


ALTER TABLE "public"."currency_display_metadata" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."currency_rates" (
    "base_currency" "text" DEFAULT 'EUR'::"text" NOT NULL,
    "target_currency" "text" NOT NULL,
    "rate" numeric NOT NULL,
    "source" "text" DEFAULT 'manual'::"text" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "raw_payload" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    CONSTRAINT "currency_rates_base_format" CHECK (("base_currency" ~ '^[A-Z]{3}$'::"text")),
    CONSTRAINT "currency_rates_rate_check" CHECK (("rate" > (0)::numeric)),
    CONSTRAINT "currency_rates_target_format" CHECK (("target_currency" ~ '^[A-Z]{3}$'::"text"))
);


ALTER TABLE "public"."currency_rates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."device_tokens" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "token" "text" NOT NULL,
    "platform" "text" NOT NULL,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "device_tokens_platform_check" CHECK (("platform" = ANY (ARRAY['ios'::"text", 'android'::"text", 'web'::"text"])))
);


ALTER TABLE "public"."device_tokens" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."fan_badges" (
    "id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text" DEFAULT ''::"text",
    "category" "text" DEFAULT 'milestone'::"text",
    "icon_name" "text" DEFAULT 'award'::"text",
    "color_hex" "text" DEFAULT '#22C55E'::"text",
    "criteria_type" "text" DEFAULT 'manual'::"text",
    "criteria_value" integer DEFAULT 0
);


ALTER TABLE "public"."fan_badges" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."fan_earned_badges" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "badge_id" "text",
    "earned_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."fan_earned_badges" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."fan_id_seq"
    START WITH 100000
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."fan_id_seq" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."fan_levels" (
    "level" integer NOT NULL,
    "name" "text" NOT NULL,
    "title" "text" DEFAULT ''::"text" NOT NULL,
    "min_xp" integer DEFAULT 0 NOT NULL,
    "icon_name" "text" DEFAULT 'user'::"text",
    "color_hex" "text" DEFAULT '#A8A29E'::"text"
);


ALTER TABLE "public"."fan_levels" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."featured_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "short_name" "text" NOT NULL,
    "event_tag" "text" NOT NULL,
    "region" "text" DEFAULT 'global'::"text" NOT NULL,
    "competition_id" "text",
    "start_date" timestamp with time zone NOT NULL,
    "end_date" timestamp with time zone NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "banner_color" "text",
    "description" "text",
    "logo_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "headline" "text",
    "cta_label" "text",
    "cta_route" "text",
    "priority_score" integer DEFAULT 0 NOT NULL,
    "audience_regions" "text"[] DEFAULT ARRAY['global'::"text"] NOT NULL,
    CONSTRAINT "featured_events_date_range" CHECK (("end_date" > "start_date")),
    CONSTRAINT "featured_events_region_check" CHECK (("region" = ANY (ARRAY['global'::"text", 'africa'::"text", 'europe'::"text", 'americas'::"text", 'north_america'::"text"])))
);


ALTER TABLE "public"."featured_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."fet_wallets" (
    "user_id" "uuid" NOT NULL,
    "available_balance_fet" bigint DEFAULT 0 NOT NULL,
    "locked_balance_fet" bigint DEFAULT 0 NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."fet_wallets" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."fet_supply_overview" AS
 SELECT COALESCE("sum"("available_balance_fet"), (0)::numeric) AS "total_available",
    COALESCE("sum"("locked_balance_fet"), (0)::numeric) AS "total_locked",
    COALESCE("sum"(("available_balance_fet" + "locked_balance_fet")), (0)::numeric) AS "total_supply",
    "count"(*) AS "total_wallets",
    "count"(*) FILTER (WHERE ("available_balance_fet" > 0)) AS "active_wallets",
    (COALESCE("avg"("available_balance_fet"), (0)::numeric))::bigint AS "avg_balance",
    COALESCE("max"("available_balance_fet"), (0)::bigint) AS "max_balance",
    ("public"."fet_supply_cap"())::numeric AS "supply_cap",
    GREATEST((("public"."fet_supply_cap"())::numeric - COALESCE("sum"(("available_balance_fet" + "locked_balance_fet")), (0)::numeric)), (0)::numeric) AS "remaining_mintable"
   FROM "public"."fet_wallets";


ALTER VIEW "public"."fet_supply_overview" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."fet_supply_overview_admin" AS
 SELECT "total_available",
    "total_locked",
    "total_supply",
    "total_wallets",
    "active_wallets",
    "avg_balance",
    "max_balance",
    "supply_cap",
    "remaining_mintable"
   FROM "public"."fet_supply_overview"
  WHERE "public"."is_active_admin_operator"("auth"."uid"());


ALTER VIEW "public"."fet_supply_overview_admin" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."fet_wallet_transactions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "tx_type" "text" NOT NULL,
    "direction" "text" NOT NULL,
    "amount_fet" bigint NOT NULL,
    "balance_before_fet" bigint,
    "balance_after_fet" bigint,
    "reference_type" "text",
    "reference_id" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "title" "text",
    CONSTRAINT "fet_wallet_transactions_direction_check" CHECK (("direction" = ANY (ARRAY['credit'::"text", 'debit'::"text"])))
);


ALTER TABLE "public"."fet_wallet_transactions" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."fet_transactions_admin" AS
 SELECT "tx"."id",
    "tx"."user_id",
    "tx"."tx_type",
    "tx"."direction",
    "tx"."amount_fet",
    "tx"."balance_before_fet",
    "tx"."balance_after_fet",
    "tx"."reference_type",
    "tx"."reference_id",
    "tx"."metadata",
    "tx"."created_at",
    "tx"."title",
    COALESCE(NULLIF(TRIM(BOTH FROM ("u"."raw_user_meta_data" ->> 'display_name'::"text")), ''::"text"), NULLIF(TRIM(BOTH FROM ("u"."raw_user_meta_data" ->> 'full_name'::"text")), ''::"text"), NULLIF("split_part"((COALESCE("u"."email", ''::character varying))::"text", '@'::"text", 1), ''::"text"), NULLIF("u"."phone", ''::"text"), ("tx"."user_id")::"text") AS "display_name",
    COALESCE((("tx"."metadata" ->> 'flagged'::"text"))::boolean, false) AS "flagged"
   FROM ("public"."fet_wallet_transactions" "tx"
     LEFT JOIN "auth"."users" "u" ON (("u"."id" = "tx"."user_id")))
  WHERE "public"."is_active_admin_operator"("auth"."uid"());


ALTER VIEW "public"."fet_transactions_admin" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."launch_moments" (
    "tag" "text" NOT NULL,
    "title" "text" NOT NULL,
    "subtitle" "text" NOT NULL,
    "kicker" "text" NOT NULL,
    "region_key" "text" DEFAULT 'global'::"text" NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "launch_moments_region_check" CHECK (("region_key" = ANY (ARRAY['africa'::"text", 'europe'::"text", 'americas'::"text", 'north_america'::"text", 'global'::"text"])))
);


ALTER TABLE "public"."launch_moments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."leaderboard_seasons" (
    "id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "start_date" "date" NOT NULL,
    "end_date" "date" NOT NULL,
    "status" "text" DEFAULT 'active'::"text"
);


ALTER TABLE "public"."leaderboard_seasons" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."match_alert_dispatch_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "match_id" "text" NOT NULL,
    "alert_type" "text" NOT NULL,
    "dispatch_key" "text" NOT NULL,
    "live_event_id" "text",
    "payload" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "dispatched_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."match_alert_dispatch_log" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."match_alert_subscriptions" (
    "user_id" "uuid" NOT NULL,
    "match_id" "text" NOT NULL,
    "alert_kickoff" boolean DEFAULT true NOT NULL,
    "alert_goals" boolean DEFAULT true NOT NULL,
    "alert_result" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."match_alert_subscriptions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_predictions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "match_id" "text" NOT NULL,
    "predicted_result_code" "text",
    "predicted_over25" boolean,
    "predicted_btts" boolean,
    "predicted_home_goals" integer,
    "predicted_away_goals" integer,
    "points_awarded" integer DEFAULT 0 NOT NULL,
    "reward_status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "user_predictions_predicted_away_goals_check" CHECK ((("predicted_away_goals" IS NULL) OR ("predicted_away_goals" >= 0))),
    CONSTRAINT "user_predictions_predicted_home_goals_check" CHECK ((("predicted_home_goals" IS NULL) OR ("predicted_home_goals" >= 0))),
    CONSTRAINT "user_predictions_predicted_result_code_check" CHECK (("predicted_result_code" = ANY (ARRAY['H'::"text", 'D'::"text", 'A'::"text"]))),
    CONSTRAINT "user_predictions_reward_status_check" CHECK (("reward_status" = ANY (ARRAY['pending'::"text", 'awarded'::"text", 'no_reward'::"text", 'reversed'::"text"])))
);


ALTER TABLE "public"."user_predictions" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."match_prediction_consensus" AS
 SELECT "match_id",
    "count"(*) AS "total_predictions",
    "count"(*) FILTER (WHERE ("predicted_result_code" = 'H'::"text")) AS "home_pick_count",
    "count"(*) FILTER (WHERE ("predicted_result_code" = 'D'::"text")) AS "draw_pick_count",
    "count"(*) FILTER (WHERE ("predicted_result_code" = 'A'::"text")) AS "away_pick_count",
    ("round"(((100.0 * ("count"(*) FILTER (WHERE ("predicted_result_code" = 'H'::"text")))::numeric) / (NULLIF("count"(*), 0))::numeric), 0))::integer AS "home_pct",
    ("round"(((100.0 * ("count"(*) FILTER (WHERE ("predicted_result_code" = 'D'::"text")))::numeric) / (NULLIF("count"(*), 0))::numeric), 0))::integer AS "draw_pct",
    ("round"(((100.0 * ("count"(*) FILTER (WHERE ("predicted_result_code" = 'A'::"text")))::numeric) / (NULLIF("count"(*), 0))::numeric), 0))::integer AS "away_pct"
   FROM "public"."user_predictions" "up"
  GROUP BY "match_id";


ALTER VIEW "public"."match_prediction_consensus" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."moderation_reports" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "reporter_user_id" "uuid",
    "target_type" "text" NOT NULL,
    "target_id" "text" NOT NULL,
    "reason" "text" NOT NULL,
    "description" "text",
    "status" "text" DEFAULT 'open'::"text",
    "severity" "text" DEFAULT 'low'::"text",
    "assigned_to" "uuid",
    "resolution_notes" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    CONSTRAINT "moderation_reports_severity_check" CHECK (("severity" = ANY (ARRAY['low'::"text", 'medium'::"text", 'high'::"text", 'critical'::"text"]))),
    CONSTRAINT "moderation_reports_status_check" CHECK (("status" = ANY (ARRAY['open'::"text", 'investigating'::"text", 'resolved'::"text", 'dismissed'::"text", 'escalated'::"text"])))
);


ALTER TABLE "public"."moderation_reports" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notification_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "type" "text" NOT NULL,
    "title" "text" NOT NULL,
    "body" "text",
    "data" "jsonb" DEFAULT '{}'::"jsonb",
    "sent_at" timestamp with time zone DEFAULT "now"(),
    "read_at" timestamp with time zone
);


ALTER TABLE "public"."notification_log" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notification_preferences" (
    "user_id" "uuid" NOT NULL,
    "goal_alerts" boolean DEFAULT true,
    "community_news" boolean DEFAULT true,
    "marketing" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "prediction_updates" boolean DEFAULT true NOT NULL,
    "reward_updates" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."notification_preferences" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."otp_verifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "phone" "text" NOT NULL,
    "otp_hash" "text" NOT NULL,
    "expires_at" timestamp with time zone NOT NULL,
    "verified" boolean DEFAULT false NOT NULL,
    "attempts" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "request_ip" "text",
    "user_agent" "text"
);


ALTER TABLE "public"."otp_verifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."phone_presets" (
    "country_code" "text" NOT NULL,
    "dial_code" "text" NOT NULL,
    "hint" "text" NOT NULL,
    "min_digits" integer DEFAULT 9 NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "phone_presets_code_format" CHECK (("country_code" ~ '^[A-Z]{2}$'::"text")),
    CONSTRAINT "phone_presets_dial_format" CHECK (("dial_code" ~ '^\+\d+$'::"text")),
    CONSTRAINT "phone_presets_min_digits" CHECK ((("min_digits" >= 5) AND ("min_digits" <= 15)))
);


ALTER TABLE "public"."phone_presets" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."token_rewards" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "user_prediction_id" "uuid" NOT NULL,
    "match_id" "text" NOT NULL,
    "reward_type" "text" DEFAULT 'prediction_reward'::"text" NOT NULL,
    "token_amount" bigint DEFAULT 0 NOT NULL,
    "status" "text" DEFAULT 'awarded'::"text" NOT NULL,
    "awarded_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "token_rewards_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'awarded'::"text", 'reversed'::"text"]))),
    CONSTRAINT "token_rewards_token_amount_check" CHECK (("token_amount" >= 0))
);


ALTER TABLE "public"."token_rewards" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."prediction_leaderboard" AS
 SELECT "up"."user_id",
    COALESCE(NULLIF(TRIM(BOTH FROM "p"."display_name"), ''::"text"), NULLIF(TRIM(BOTH FROM "p"."fan_id"), ''::"text"), 'Fan'::"text") AS "display_name",
    "count"(*) AS "prediction_count",
    COALESCE("sum"("up"."points_awarded"), (0)::bigint) AS "total_points",
    COALESCE("sum"("tr"."token_amount") FILTER (WHERE ("tr"."status" = 'awarded'::"text")), (0)::numeric) AS "total_fet",
    "count"(*) FILTER (WHERE (("up"."predicted_result_code" IS NOT NULL) AND ("up"."predicted_result_code" = "m"."result_code"))) AS "correct_results",
    "count"(*) FILTER (WHERE (("up"."predicted_home_goals" IS NOT NULL) AND ("up"."predicted_away_goals" IS NOT NULL) AND ("up"."predicted_home_goals" = "m"."home_goals") AND ("up"."predicted_away_goals" = "m"."away_goals"))) AS "exact_scores"
   FROM ((("public"."user_predictions" "up"
     LEFT JOIN "public"."profiles" "p" ON (("p"."user_id" = "up"."user_id")))
     LEFT JOIN "public"."matches" "m" ON (("m"."id" = "up"."match_id")))
     LEFT JOIN "public"."token_rewards" "tr" ON (("tr"."user_prediction_id" = "up"."id")))
  GROUP BY "up"."user_id", COALESCE(NULLIF(TRIM(BOTH FROM "p"."display_name"), ''::"text"), NULLIF(TRIM(BOTH FROM "p"."fan_id"), ''::"text"), 'Fan'::"text");


ALTER VIEW "public"."prediction_leaderboard" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."predictions_engine_outputs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "match_id" "text" NOT NULL,
    "model_version" "text" DEFAULT 'simple_form_v1'::"text" NOT NULL,
    "home_win_score" numeric(6,4) DEFAULT 0.3333 NOT NULL,
    "draw_score" numeric(6,4) DEFAULT 0.3333 NOT NULL,
    "away_win_score" numeric(6,4) DEFAULT 0.3333 NOT NULL,
    "over25_score" numeric(6,4) DEFAULT 0.5000 NOT NULL,
    "btts_score" numeric(6,4) DEFAULT 0.5000 NOT NULL,
    "predicted_home_goals" integer,
    "predicted_away_goals" integer,
    "confidence_label" "text" DEFAULT 'low'::"text" NOT NULL,
    "generated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "predictions_engine_outputs_confidence_label_check" CHECK (("confidence_label" = ANY (ARRAY['low'::"text", 'medium'::"text", 'high'::"text"]))),
    CONSTRAINT "predictions_engine_outputs_score_range_check" CHECK (((("home_win_score" >= (0)::numeric) AND ("home_win_score" <= (1)::numeric)) AND (("draw_score" >= (0)::numeric) AND ("draw_score" <= (1)::numeric)) AND (("away_win_score" >= (0)::numeric) AND ("away_win_score" <= (1)::numeric)) AND (("over25_score" >= (0)::numeric) AND ("over25_score" <= (1)::numeric)) AND (("btts_score" >= (0)::numeric) AND ("btts_score" <= (1)::numeric))))
);


ALTER TABLE "public"."predictions_engine_outputs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "event_name" "text" NOT NULL,
    "properties" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "session_id" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."product_events" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."public_leaderboard" AS
 SELECT "user_id",
    "display_name",
    "prediction_count",
    "total_points",
    "total_fet",
    "correct_results",
    "exact_scores"
   FROM "public"."prediction_leaderboard";


ALTER VIEW "public"."public_leaderboard" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."rate_limits" (
    "id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "action" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."rate_limits" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."rate_limits_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."rate_limits_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."rate_limits_id_seq" OWNED BY "public"."rate_limits"."id";



CREATE TABLE IF NOT EXISTS "public"."team_aliases" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "team_id" "text" NOT NULL,
    "alias_name" "text" NOT NULL,
    "source_name" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "team_aliases_alias_name_not_blank" CHECK (("btrim"("alias_name") <> ''::"text"))
);


ALTER TABLE "public"."team_aliases" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."team_form_features" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "match_id" "text" NOT NULL,
    "team_id" "text" NOT NULL,
    "last5_points" integer DEFAULT 0 NOT NULL,
    "last5_wins" integer DEFAULT 0 NOT NULL,
    "last5_draws" integer DEFAULT 0 NOT NULL,
    "last5_losses" integer DEFAULT 0 NOT NULL,
    "last5_goals_for" integer DEFAULT 0 NOT NULL,
    "last5_goals_against" integer DEFAULT 0 NOT NULL,
    "last5_clean_sheets" integer DEFAULT 0 NOT NULL,
    "last5_failed_to_score" integer DEFAULT 0 NOT NULL,
    "home_form_last5" integer DEFAULT 0 NOT NULL,
    "away_form_last5" integer DEFAULT 0 NOT NULL,
    "over25_last5" integer DEFAULT 0 NOT NULL,
    "btts_last5" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."team_form_features" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_favorite_teams" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "team_id" "text" NOT NULL,
    "team_name" "text" NOT NULL,
    "team_short_name" "text",
    "team_country" "text",
    "team_country_code" "text",
    "team_league" "text",
    "team_crest_url" "text",
    "source" "text" DEFAULT 'popular'::"text" NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "user_favorite_teams_country_code_format" CHECK ((("team_country_code" IS NULL) OR ("team_country_code" = ''::"text") OR ("team_country_code" ~ '^[A-Z]{2}$'::"text"))),
    CONSTRAINT "user_favorite_teams_source_check" CHECK (("source" = ANY (ARRAY['local'::"text", 'popular'::"text", 'settings'::"text", 'synced'::"text"])))
);


ALTER TABLE "public"."user_favorite_teams" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_followed_competitions" (
    "user_id" "uuid" NOT NULL,
    "competition_id" "text" NOT NULL,
    "notify_matchday" boolean DEFAULT false NOT NULL,
    "notify_live" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."user_followed_competitions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_market_preferences" (
    "user_id" "uuid" NOT NULL,
    "primary_region" "text" DEFAULT 'global'::"text" NOT NULL,
    "selected_regions" "text"[] DEFAULT ARRAY['global'::"text"] NOT NULL,
    "focus_event_tags" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "favorite_competition_ids" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "follow_world_cup" boolean DEFAULT true NOT NULL,
    "follow_champions_league" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "user_market_preferences_primary_region_check" CHECK (("primary_region" = ANY (ARRAY['global'::"text", 'africa'::"text", 'europe'::"text", 'north_america'::"text"])))
);


ALTER TABLE "public"."user_market_preferences" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_status" (
    "user_id" "uuid" NOT NULL,
    "is_banned" boolean DEFAULT false,
    "banned_until" timestamp with time zone,
    "ban_reason" "text",
    "is_suspended" boolean DEFAULT false,
    "suspended_until" timestamp with time zone,
    "suspend_reason" "text",
    "wallet_frozen" boolean DEFAULT false,
    "wallet_freeze_reason" "text",
    "prediction_streak" integer DEFAULT 0,
    "longest_streak" integer DEFAULT 0,
    "total_predictions" integer DEFAULT 0,
    "total_prediction_entries" integer DEFAULT 0,
    "correct_predictions" integer DEFAULT 0,
    "total_fet_earned" bigint DEFAULT 0,
    "total_fet_spent" bigint DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."user_status" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."user_profiles_admin" AS
 SELECT "u"."id",
    "u"."email",
    "u"."phone",
    (COALESCE("u"."raw_user_meta_data", '{}'::"jsonb") || "jsonb_strip_nulls"("jsonb_build_object"('display_name', COALESCE(NULLIF(TRIM(BOTH FROM ("u"."raw_user_meta_data" ->> 'display_name'::"text")), ''::"text"), NULLIF(TRIM(BOTH FROM ("u"."raw_user_meta_data" ->> 'full_name'::"text")), ''::"text"), NULLIF("split_part"((COALESCE("u"."email", ''::character varying))::"text", '@'::"text", 1), ''::"text"), NULLIF("u"."phone", ''::"text")), 'is_banned', COALESCE("us"."is_banned", false), 'is_suspended', COALESCE("us"."is_suspended", false), 'wallet_frozen', COALESCE("us"."wallet_frozen", false), 'ban_reason', "us"."ban_reason", 'suspend_reason', "us"."suspend_reason", 'wallet_freeze_reason', "us"."wallet_freeze_reason"))) AS "raw_user_meta_data",
    "u"."created_at",
    "u"."last_sign_in_at",
    COALESCE("fw"."available_balance_fet", (0)::bigint) AS "available_balance_fet",
    COALESCE("fw"."locked_balance_fet", (0)::bigint) AS "locked_balance_fet",
    COALESCE(NULLIF(TRIM(BOTH FROM ("u"."raw_user_meta_data" ->> 'display_name'::"text")), ''::"text"), NULLIF(TRIM(BOTH FROM ("u"."raw_user_meta_data" ->> 'full_name'::"text")), ''::"text"), NULLIF("split_part"((COALESCE("u"."email", ''::character varying))::"text", '@'::"text", 1), ''::"text"), NULLIF("u"."phone", ''::"text"), ("u"."id")::"text") AS "display_name",
        CASE
            WHEN COALESCE("us"."wallet_frozen", false) THEN 'frozen'::"text"
            WHEN (COALESCE("us"."is_banned", false) AND (("us"."banned_until" IS NULL) OR ("us"."banned_until" > "timezone"('utc'::"text", "now"())))) THEN 'banned'::"text"
            WHEN (COALESCE("us"."is_suspended", false) AND (("us"."suspended_until" IS NULL) OR ("us"."suspended_until" > "timezone"('utc'::"text", "now"())))) THEN 'suspended'::"text"
            ELSE 'active'::"text"
        END AS "status",
    "us"."ban_reason",
    "us"."suspend_reason",
    "us"."wallet_freeze_reason"
   FROM (("auth"."users" "u"
     LEFT JOIN "public"."fet_wallets" "fw" ON (("fw"."user_id" = "u"."id")))
     LEFT JOIN "public"."user_status" "us" ON (("us"."user_id" = "u"."id")))
  WHERE "public"."is_active_admin_operator"("auth"."uid"());


ALTER VIEW "public"."user_profiles_admin" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."wallet_overview" AS
 SELECT "w"."user_id",
    "w"."available_balance_fet",
    "w"."locked_balance_fet",
    "p"."fan_id",
    "p"."display_name"
   FROM ("public"."fet_wallets" "w"
     JOIN "public"."profiles" "p" ON (("p"."user_id" = "w"."user_id")))
  WHERE ("w"."user_id" = "auth"."uid"());


ALTER VIEW "public"."wallet_overview" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."wallet_overview_admin" AS
 SELECT "fw"."user_id",
    COALESCE(NULLIF(TRIM(BOTH FROM ("u"."raw_user_meta_data" ->> 'display_name'::"text")), ''::"text"), NULLIF(TRIM(BOTH FROM ("u"."raw_user_meta_data" ->> 'full_name'::"text")), ''::"text"), NULLIF("split_part"((COALESCE("u"."email", ''::character varying))::"text", '@'::"text", 1), ''::"text"), NULLIF("u"."phone", ''::"text"), ("fw"."user_id")::"text") AS "display_name",
    "u"."email",
    "u"."phone",
        CASE
            WHEN COALESCE("us"."wallet_frozen", false) THEN 'frozen'::"text"
            WHEN (COALESCE("us"."is_banned", false) AND (("us"."banned_until" IS NULL) OR ("us"."banned_until" > "timezone"('utc'::"text", "now"())))) THEN 'banned'::"text"
            WHEN (COALESCE("us"."is_suspended", false) AND (("us"."suspended_until" IS NULL) OR ("us"."suspended_until" > "timezone"('utc'::"text", "now"())))) THEN 'suspended'::"text"
            ELSE 'active'::"text"
        END AS "status",
    "us"."wallet_freeze_reason",
    "fw"."available_balance_fet",
    "fw"."locked_balance_fet",
    "fw"."updated_at",
    "fw"."created_at"
   FROM (("public"."fet_wallets" "fw"
     LEFT JOIN "auth"."users" "u" ON (("u"."id" = "fw"."user_id")))
     LEFT JOIN "public"."user_status" "us" ON (("us"."user_id" = "fw"."user_id")))
  WHERE "public"."is_active_admin_operator"("auth"."uid"());


ALTER VIEW "public"."wallet_overview_admin" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."whatsapp_auth_sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "phone" "text" NOT NULL,
    "refresh_token_hash" "text" NOT NULL,
    "access_expires_at" timestamp with time zone NOT NULL,
    "refresh_expires_at" timestamp with time zone NOT NULL,
    "refreshed_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "revoked_at" timestamp with time zone,
    "revoke_reason" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."whatsapp_auth_sessions" OWNER TO "postgres";


ALTER TABLE ONLY "public"."admin_audit_logs" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."admin_audit_logs_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."rate_limits" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."rate_limits_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."account_deletion_requests"
    ADD CONSTRAINT "account_deletion_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."admin_audit_logs"
    ADD CONSTRAINT "admin_audit_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."admin_users"
    ADD CONSTRAINT "admin_users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."admin_users"
    ADD CONSTRAINT "admin_users_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."admin_users"
    ADD CONSTRAINT "admin_users_whatsapp_number_key" UNIQUE ("whatsapp_number");



ALTER TABLE ONLY "public"."anonymous_upgrade_claims"
    ADD CONSTRAINT "anonymous_upgrade_claims_claim_token_key" UNIQUE ("claim_token");



ALTER TABLE ONLY "public"."anonymous_upgrade_claims"
    ADD CONSTRAINT "anonymous_upgrade_claims_pkey" PRIMARY KEY ("anon_user_id");



ALTER TABLE ONLY "public"."app_config_remote"
    ADD CONSTRAINT "app_config_remote_pkey" PRIMARY KEY ("key");



ALTER TABLE ONLY "public"."app_runtime_errors"
    ADD CONSTRAINT "app_runtime_errors_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."competitions"
    ADD CONSTRAINT "competitions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."country_currency_map"
    ADD CONSTRAINT "country_currency_map_pkey" PRIMARY KEY ("country_code");



ALTER TABLE ONLY "public"."country_region_map"
    ADD CONSTRAINT "country_region_map_pkey" PRIMARY KEY ("country_code");



ALTER TABLE ONLY "public"."cron_job_log"
    ADD CONSTRAINT "cron_job_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."currency_display_metadata"
    ADD CONSTRAINT "currency_display_metadata_pkey" PRIMARY KEY ("currency_code");



ALTER TABLE ONLY "public"."currency_rates"
    ADD CONSTRAINT "currency_rates_pkey" PRIMARY KEY ("base_currency", "target_currency");



ALTER TABLE ONLY "public"."device_tokens"
    ADD CONSTRAINT "device_tokens_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_tokens"
    ADD CONSTRAINT "device_tokens_user_id_token_key" UNIQUE ("user_id", "token");



ALTER TABLE ONLY "public"."fan_badges"
    ADD CONSTRAINT "fan_badges_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."fan_earned_badges"
    ADD CONSTRAINT "fan_earned_badges_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."fan_earned_badges"
    ADD CONSTRAINT "fan_earned_badges_user_id_badge_id_key" UNIQUE ("user_id", "badge_id");



ALTER TABLE ONLY "public"."fan_levels"
    ADD CONSTRAINT "fan_levels_pkey" PRIMARY KEY ("level");



ALTER TABLE ONLY "public"."feature_flags"
    ADD CONSTRAINT "feature_flags_pkey" PRIMARY KEY ("key", "market", "platform");



ALTER TABLE ONLY "public"."featured_events"
    ADD CONSTRAINT "featured_events_event_tag_key" UNIQUE ("event_tag");



ALTER TABLE ONLY "public"."featured_events"
    ADD CONSTRAINT "featured_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."fet_wallet_transactions"
    ADD CONSTRAINT "fet_wallet_transactions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."fet_wallets"
    ADD CONSTRAINT "fet_wallets_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."launch_moments"
    ADD CONSTRAINT "launch_moments_pkey" PRIMARY KEY ("tag");



ALTER TABLE ONLY "public"."leaderboard_seasons"
    ADD CONSTRAINT "leaderboard_seasons_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."match_alert_dispatch_log"
    ADD CONSTRAINT "match_alert_dispatch_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."match_alert_dispatch_log"
    ADD CONSTRAINT "match_alert_dispatch_log_user_id_match_id_alert_type_dispat_key" UNIQUE ("user_id", "match_id", "alert_type", "dispatch_key");



ALTER TABLE ONLY "public"."match_alert_subscriptions"
    ADD CONSTRAINT "match_alert_subscriptions_pkey" PRIMARY KEY ("user_id", "match_id");



ALTER TABLE ONLY "public"."matches"
    ADD CONSTRAINT "matches_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."moderation_reports"
    ADD CONSTRAINT "moderation_reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notification_log"
    ADD CONSTRAINT "notification_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notification_preferences"
    ADD CONSTRAINT "notification_preferences_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."otp_verifications"
    ADD CONSTRAINT "otp_verifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."phone_presets"
    ADD CONSTRAINT "phone_presets_pkey" PRIMARY KEY ("country_code");



ALTER TABLE ONLY "public"."predictions_engine_outputs"
    ADD CONSTRAINT "predictions_engine_outputs_match_id_key" UNIQUE ("match_id");



ALTER TABLE ONLY "public"."predictions_engine_outputs"
    ADD CONSTRAINT "predictions_engine_outputs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_events"
    ADD CONSTRAINT "product_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_fan_id_key" UNIQUE ("fan_id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_username_key" UNIQUE ("username");



ALTER TABLE ONLY "public"."rate_limits"
    ADD CONSTRAINT "rate_limits_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."seasons"
    ADD CONSTRAINT "seasons_label_unique" UNIQUE ("competition_id", "season_label");



ALTER TABLE ONLY "public"."seasons"
    ADD CONSTRAINT "seasons_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."standings"
    ADD CONSTRAINT "standings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."standings"
    ADD CONSTRAINT "standings_unique_snapshot" UNIQUE ("competition_id", "season_id", "snapshot_type", "snapshot_date", "team_id");



ALTER TABLE ONLY "public"."team_aliases"
    ADD CONSTRAINT "team_aliases_unique_team_alias" UNIQUE ("team_id", "alias_name");



ALTER TABLE ONLY "public"."team_aliases"
    ADD CONSTRAINT "team_aliases_v2_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."team_form_features"
    ADD CONSTRAINT "team_form_features_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."team_form_features"
    ADD CONSTRAINT "team_form_features_unique" UNIQUE ("match_id", "team_id");



ALTER TABLE ONLY "public"."teams"
    ADD CONSTRAINT "teams_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."token_rewards"
    ADD CONSTRAINT "token_rewards_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."token_rewards"
    ADD CONSTRAINT "token_rewards_unique_prediction" UNIQUE ("user_prediction_id", "reward_type");



ALTER TABLE ONLY "public"."user_favorite_teams"
    ADD CONSTRAINT "user_favorite_teams_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_favorite_teams"
    ADD CONSTRAINT "user_favorite_teams_user_id_team_id_key" UNIQUE ("user_id", "team_id");



ALTER TABLE ONLY "public"."user_followed_competitions"
    ADD CONSTRAINT "user_followed_competitions_pkey" PRIMARY KEY ("user_id", "competition_id");



ALTER TABLE ONLY "public"."user_market_preferences"
    ADD CONSTRAINT "user_market_preferences_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."user_predictions"
    ADD CONSTRAINT "user_predictions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_predictions"
    ADD CONSTRAINT "user_predictions_unique_match" UNIQUE ("user_id", "match_id");



ALTER TABLE ONLY "public"."user_status"
    ADD CONSTRAINT "user_status_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."whatsapp_auth_sessions"
    ADD CONSTRAINT "whatsapp_auth_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."whatsapp_auth_sessions"
    ADD CONSTRAINT "whatsapp_auth_sessions_refresh_token_hash_key" UNIQUE ("refresh_token_hash");



CREATE UNIQUE INDEX "idx_account_deletion_requests_pending_unique" ON "public"."account_deletion_requests" USING "btree" ("user_id") WHERE ("status" = ANY (ARRAY['pending'::"text", 'in_review'::"text"]));



CREATE INDEX "idx_account_deletion_requests_status" ON "public"."account_deletion_requests" USING "btree" ("status", "requested_at" DESC);



CREATE INDEX "idx_account_deletion_requests_user" ON "public"."account_deletion_requests" USING "btree" ("user_id", "requested_at" DESC);



CREATE INDEX "idx_admin_users_phone" ON "public"."admin_users" USING "btree" ("phone");



CREATE INDEX "idx_anonymous_upgrade_claims_expires" ON "public"."anonymous_upgrade_claims" USING "btree" ("expires_at") WHERE ("consumed_at" IS NULL);



CREATE INDEX "idx_app_runtime_errors_created_at" ON "public"."app_runtime_errors" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_app_runtime_errors_reason" ON "public"."app_runtime_errors" USING "btree" ("reason");



CREATE INDEX "idx_app_runtime_errors_user_id" ON "public"."app_runtime_errors" USING "btree" ("user_id") WHERE ("user_id" IS NOT NULL);



CREATE INDEX "idx_competitions_active_name" ON "public"."competitions" USING "btree" ("is_active", "name");



CREATE INDEX "idx_competitions_country_tier" ON "public"."competitions" USING "btree" ("country", "tier");



CREATE INDEX "idx_competitions_status" ON "public"."competitions" USING "btree" ("status", "is_featured");



CREATE INDEX "idx_cron_job_log_name_started" ON "public"."cron_job_log" USING "btree" ("job_name", "started_at" DESC);



CREATE INDEX "idx_device_tokens_user" ON "public"."device_tokens" USING "btree" ("user_id") WHERE ("is_active" = true);



CREATE INDEX "idx_engine_outputs_generated" ON "public"."predictions_engine_outputs" USING "btree" ("generated_at" DESC);



CREATE INDEX "idx_featured_events_active" ON "public"."featured_events" USING "btree" ("is_active", "start_date", "end_date");



CREATE INDEX "idx_featured_events_priority" ON "public"."featured_events" USING "btree" ("priority_score" DESC, "start_date");



CREATE INDEX "idx_featured_events_tag" ON "public"."featured_events" USING "btree" ("event_tag");



CREATE INDEX "idx_match_alert_dispatch_log_match_type" ON "public"."match_alert_dispatch_log" USING "btree" ("match_id", "alert_type", "dispatched_at" DESC);



CREATE INDEX "idx_match_alert_dispatch_log_user" ON "public"."match_alert_dispatch_log" USING "btree" ("user_id", "dispatched_at" DESC);



CREATE INDEX "idx_match_alert_subscriptions_match" ON "public"."match_alert_subscriptions" USING "btree" ("match_id");



CREATE INDEX "idx_matches_away_team" ON "public"."matches" USING "btree" ("away_team_id");



CREATE INDEX "idx_matches_competition_date" ON "public"."matches" USING "btree" ("competition_id", "match_date" DESC);



CREATE INDEX "idx_matches_competition_season_date" ON "public"."matches" USING "btree" ("competition_id", "season_id", "match_date" DESC);



CREATE INDEX "idx_matches_home_team" ON "public"."matches" USING "btree" ("home_team_id");



CREATE INDEX "idx_matches_match_date" ON "public"."matches" USING "btree" ("match_date");



CREATE INDEX "idx_matches_season_status" ON "public"."matches" USING "btree" ("season_id", "match_status", "match_date" DESC);



CREATE INDEX "idx_matches_status_date" ON "public"."matches" USING "btree" ("match_status", "match_date" DESC);



CREATE INDEX "idx_notification_log_user" ON "public"."notification_log" USING "btree" ("user_id", "sent_at" DESC);



CREATE INDEX "idx_otp_verifications_cleanup" ON "public"."otp_verifications" USING "btree" ("verified", "expires_at", "created_at");



CREATE INDEX "idx_otp_verifications_phone_active" ON "public"."otp_verifications" USING "btree" ("phone", "expires_at" DESC) WHERE ("verified" = false);



CREATE INDEX "idx_otp_verifications_phone_created" ON "public"."otp_verifications" USING "btree" ("phone", "created_at" DESC);



CREATE INDEX "idx_otp_verifications_phone_verified" ON "public"."otp_verifications" USING "btree" ("phone", "verified", "expires_at" DESC);



CREATE INDEX "idx_otp_verifications_request_ip_created" ON "public"."otp_verifications" USING "btree" ("request_ip", "created_at" DESC) WHERE ("request_ip" IS NOT NULL);



CREATE INDEX "idx_product_events_created_at" ON "public"."product_events" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_product_events_event_name" ON "public"."product_events" USING "btree" ("event_name");



CREATE INDEX "idx_product_events_session" ON "public"."product_events" USING "btree" ("session_id") WHERE ("session_id" IS NOT NULL);



CREATE INDEX "idx_product_events_user_id" ON "public"."product_events" USING "btree" ("user_id") WHERE ("user_id" IS NOT NULL);



CREATE INDEX "idx_profiles_is_anonymous" ON "public"."profiles" USING "btree" ("is_anonymous") WHERE ("is_anonymous" = true);



CREATE INDEX "idx_profiles_phone_number" ON "public"."profiles" USING "btree" ("phone_number") WHERE ("phone_number" IS NOT NULL);



CREATE INDEX "idx_rate_limits_lookup" ON "public"."rate_limits" USING "btree" ("user_id", "action", "created_at" DESC);



CREATE INDEX "idx_reports_status" ON "public"."moderation_reports" USING "btree" ("status");



CREATE INDEX "idx_reports_target" ON "public"."moderation_reports" USING "btree" ("target_type", "target_id");



CREATE INDEX "idx_seasons_competition_current" ON "public"."seasons" USING "btree" ("competition_id", "is_current" DESC, "start_year" DESC);



CREATE INDEX "idx_standings_competition_snapshot" ON "public"."standings" USING "btree" ("competition_id", "season_id", "snapshot_type", "snapshot_date" DESC, "position");



CREATE INDEX "idx_team_aliases_lookup" ON "public"."team_aliases" USING "btree" ("lower"("alias_name"));



CREATE UNIQUE INDEX "idx_team_aliases_team_alias_unique" ON "public"."team_aliases" USING "btree" ("team_id", "lower"("alias_name"));



CREATE INDEX "idx_team_form_features_match" ON "public"."team_form_features" USING "btree" ("match_id", "team_id");



CREATE INDEX "idx_team_form_features_team_match" ON "public"."team_form_features" USING "btree" ("team_id", "match_id");



CREATE INDEX "idx_teams_active_name" ON "public"."teams" USING "btree" ("is_active", "name");



CREATE INDEX "idx_teams_country" ON "public"."teams" USING "btree" ("country");



CREATE INDEX "idx_teams_country_code" ON "public"."teams" USING "btree" ("country_code");



CREATE INDEX "idx_teams_popular_pick" ON "public"."teams" USING "btree" ("is_popular_pick", "popular_pick_rank") WHERE ("is_popular_pick" = true);



CREATE INDEX "idx_teams_region" ON "public"."teams" USING "btree" ("region");



CREATE INDEX "idx_token_rewards_match_awarded" ON "public"."token_rewards" USING "btree" ("match_id", "awarded_at" DESC);



CREATE INDEX "idx_token_rewards_user_awarded" ON "public"."token_rewards" USING "btree" ("user_id", "awarded_at" DESC);



CREATE INDEX "idx_user_favorite_teams_country" ON "public"."user_favorite_teams" USING "btree" ("team_country_code");



CREATE INDEX "idx_user_favorite_teams_user" ON "public"."user_favorite_teams" USING "btree" ("user_id", "source", "sort_order", "created_at");



CREATE INDEX "idx_user_predictions_match" ON "public"."user_predictions" USING "btree" ("match_id", "reward_status");



CREATE INDEX "idx_user_predictions_reward_status_updated" ON "public"."user_predictions" USING "btree" ("reward_status", "updated_at" DESC);



CREATE INDEX "idx_user_predictions_user_created" ON "public"."user_predictions" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "idx_user_status_banned" ON "public"."user_status" USING "btree" ("is_banned") WHERE ("is_banned" = true);



CREATE INDEX "idx_whatsapp_auth_sessions_cleanup" ON "public"."whatsapp_auth_sessions" USING "btree" ("revoked_at", "refresh_expires_at", "updated_at");



CREATE INDEX "idx_whatsapp_auth_sessions_phone_active" ON "public"."whatsapp_auth_sessions" USING "btree" ("phone", "refresh_expires_at" DESC) WHERE ("revoked_at" IS NULL);



CREATE INDEX "idx_whatsapp_auth_sessions_user_active" ON "public"."whatsapp_auth_sessions" USING "btree" ("user_id", "refresh_expires_at" DESC) WHERE ("revoked_at" IS NULL);



CREATE OR REPLACE TRIGGER "set_profiles_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_wallet_updated_at" BEFORE UPDATE ON "public"."fet_wallets" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_apply_match_result_code" BEFORE INSERT OR UPDATE OF "home_goals", "away_goals", "match_status" ON "public"."matches" FOR EACH ROW EXECUTE FUNCTION "public"."apply_match_result_code"();



CREATE OR REPLACE TRIGGER "trg_competitions_updated_at" BEFORE UPDATE ON "public"."competitions" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_matches_set_updated_at" BEFORE UPDATE ON "public"."matches" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_matches_updated_at" BEFORE UPDATE ON "public"."matches" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_notify_wallet_credit" AFTER INSERT ON "public"."fet_wallet_transactions" FOR EACH ROW WHEN ((("new"."direction" = 'credit'::"text") AND ("new"."amount_fet" >= 10))) EXECUTE FUNCTION "public"."notify_wallet_credit"();



CREATE OR REPLACE TRIGGER "trg_profiles_assign_fan_id" BEFORE INSERT OR UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."assign_profile_fan_id"();



CREATE OR REPLACE TRIGGER "trg_seasons_updated_at" BEFORE UPDATE ON "public"."seasons" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_standings_updated_at" BEFORE UPDATE ON "public"."standings" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_team_form_features_updated_at" BEFORE UPDATE ON "public"."team_form_features" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_teams_updated_at" BEFORE UPDATE ON "public"."teams" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_user_predictions_updated_at" BEFORE UPDATE ON "public"."user_predictions" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



ALTER TABLE ONLY "public"."account_deletion_requests"
    ADD CONSTRAINT "account_deletion_requests_processed_by_fkey" FOREIGN KEY ("processed_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."account_deletion_requests"
    ADD CONSTRAINT "account_deletion_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."admin_audit_logs"
    ADD CONSTRAINT "admin_audit_logs_admin_user_id_fkey" FOREIGN KEY ("admin_user_id") REFERENCES "public"."admin_users"("id");



ALTER TABLE ONLY "public"."admin_users"
    ADD CONSTRAINT "admin_users_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."anonymous_upgrade_claims"
    ADD CONSTRAINT "anonymous_upgrade_claims_anon_user_id_fkey" FOREIGN KEY ("anon_user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."anonymous_upgrade_claims"
    ADD CONSTRAINT "anonymous_upgrade_claims_consumed_by_user_id_fkey" FOREIGN KEY ("consumed_by_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."app_runtime_errors"
    ADD CONSTRAINT "app_runtime_errors_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."device_tokens"
    ADD CONSTRAINT "device_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."fan_earned_badges"
    ADD CONSTRAINT "fan_earned_badges_badge_id_fkey" FOREIGN KEY ("badge_id") REFERENCES "public"."fan_badges"("id");



ALTER TABLE ONLY "public"."fan_earned_badges"
    ADD CONSTRAINT "fan_earned_badges_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."featured_events"
    ADD CONSTRAINT "featured_events_competition_id_fkey" FOREIGN KEY ("competition_id") REFERENCES "public"."competitions"("id");



ALTER TABLE ONLY "public"."fet_wallet_transactions"
    ADD CONSTRAINT "fet_wallet_transactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."fet_wallets"
    ADD CONSTRAINT "fet_wallets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."match_alert_dispatch_log"
    ADD CONSTRAINT "match_alert_dispatch_log_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "public"."matches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."match_alert_dispatch_log"
    ADD CONSTRAINT "match_alert_dispatch_log_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."match_alert_subscriptions"
    ADD CONSTRAINT "match_alert_subscriptions_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "public"."matches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."match_alert_subscriptions"
    ADD CONSTRAINT "match_alert_subscriptions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."matches"
    ADD CONSTRAINT "matches_away_team_id_fkey" FOREIGN KEY ("away_team_id") REFERENCES "public"."teams"("id");



ALTER TABLE ONLY "public"."matches"
    ADD CONSTRAINT "matches_competition_id_fkey" FOREIGN KEY ("competition_id") REFERENCES "public"."competitions"("id");



ALTER TABLE ONLY "public"."matches"
    ADD CONSTRAINT "matches_home_team_id_fkey" FOREIGN KEY ("home_team_id") REFERENCES "public"."teams"("id");



ALTER TABLE ONLY "public"."moderation_reports"
    ADD CONSTRAINT "moderation_reports_assigned_to_fkey" FOREIGN KEY ("assigned_to") REFERENCES "public"."admin_users"("id");



ALTER TABLE ONLY "public"."moderation_reports"
    ADD CONSTRAINT "moderation_reports_reporter_auth_fkey" FOREIGN KEY ("reporter_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."notification_log"
    ADD CONSTRAINT "notification_log_user_id_auth_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notification_preferences"
    ADD CONSTRAINT "notification_preferences_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."predictions_engine_outputs"
    ADD CONSTRAINT "predictions_engine_outputs_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "public"."matches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."product_events"
    ADD CONSTRAINT "product_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."seasons"
    ADD CONSTRAINT "seasons_competition_id_fkey" FOREIGN KEY ("competition_id") REFERENCES "public"."competitions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."standings"
    ADD CONSTRAINT "standings_competition_id_fkey" FOREIGN KEY ("competition_id") REFERENCES "public"."competitions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."standings"
    ADD CONSTRAINT "standings_season_id_fkey" FOREIGN KEY ("season_id") REFERENCES "public"."seasons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."standings"
    ADD CONSTRAINT "standings_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."team_aliases"
    ADD CONSTRAINT "team_aliases_v2_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."team_form_features"
    ADD CONSTRAINT "team_form_features_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "public"."matches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."team_form_features"
    ADD CONSTRAINT "team_form_features_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."token_rewards"
    ADD CONSTRAINT "token_rewards_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "public"."matches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."token_rewards"
    ADD CONSTRAINT "token_rewards_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."token_rewards"
    ADD CONSTRAINT "token_rewards_user_prediction_id_fkey" FOREIGN KEY ("user_prediction_id") REFERENCES "public"."user_predictions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_favorite_teams"
    ADD CONSTRAINT "user_favorite_teams_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_followed_competitions"
    ADD CONSTRAINT "user_followed_competitions_competition_id_fkey" FOREIGN KEY ("competition_id") REFERENCES "public"."competitions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_followed_competitions"
    ADD CONSTRAINT "user_followed_competitions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_market_preferences"
    ADD CONSTRAINT "user_market_preferences_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_predictions"
    ADD CONSTRAINT "user_predictions_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "public"."matches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_predictions"
    ADD CONSTRAINT "user_predictions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_status"
    ADD CONSTRAINT "user_status_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."whatsapp_auth_sessions"
    ADD CONSTRAINT "whatsapp_auth_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Active admins read admin directory" ON "public"."admin_users" FOR SELECT TO "authenticated" USING ("public"."is_active_admin_operator"("auth"."uid"()));



CREATE POLICY "Admin write app config remote" ON "public"."app_config_remote" TO "authenticated" USING ("public"."is_admin_manager"("auth"."uid"())) WITH CHECK ("public"."is_admin_manager"("auth"."uid"()));



CREATE POLICY "Admin write competitions" ON "public"."competitions" TO "authenticated" USING ("public"."is_admin_manager"("auth"."uid"())) WITH CHECK ("public"."is_admin_manager"("auth"."uid"()));



CREATE POLICY "Admin write country currency map" ON "public"."country_currency_map" TO "authenticated" USING ("public"."is_admin_manager"("auth"."uid"())) WITH CHECK ("public"."is_admin_manager"("auth"."uid"()));



CREATE POLICY "Admin write country region map" ON "public"."country_region_map" TO "authenticated" USING ("public"."is_admin_manager"("auth"."uid"())) WITH CHECK ("public"."is_admin_manager"("auth"."uid"()));



CREATE POLICY "Admin write currency display metadata" ON "public"."currency_display_metadata" TO "authenticated" USING ("public"."is_admin_manager"("auth"."uid"())) WITH CHECK ("public"."is_admin_manager"("auth"."uid"()));



CREATE POLICY "Admin write feature flags" ON "public"."feature_flags" TO "authenticated" USING ("public"."is_admin_manager"("auth"."uid"())) WITH CHECK ("public"."is_admin_manager"("auth"."uid"()));



CREATE POLICY "Admin write launch moments" ON "public"."launch_moments" TO "authenticated" USING ("public"."is_admin_manager"("auth"."uid"())) WITH CHECK ("public"."is_admin_manager"("auth"."uid"()));



CREATE POLICY "Admin write matches" ON "public"."matches" TO "authenticated" USING ("public"."is_admin_manager"("auth"."uid"())) WITH CHECK ("public"."is_admin_manager"("auth"."uid"()));



CREATE POLICY "Admin write phone presets" ON "public"."phone_presets" TO "authenticated" USING ("public"."is_admin_manager"("auth"."uid"())) WITH CHECK ("public"."is_admin_manager"("auth"."uid"()));



CREATE POLICY "Admin write teams" ON "public"."teams" TO "authenticated" USING ("public"."is_admin_manager"("auth"."uid"())) WITH CHECK ("public"."is_admin_manager"("auth"."uid"()));



CREATE POLICY "Admins manage account deletion requests" ON "public"."account_deletion_requests" TO "authenticated" USING ("public"."is_admin_manager"("auth"."uid"())) WITH CHECK ("public"."is_admin_manager"("auth"."uid"()));



CREATE POLICY "Admins manage competitions" ON "public"."competitions" TO "authenticated" USING ("public"."is_admin_manager"("auth"."uid"())) WITH CHECK ("public"."is_admin_manager"("auth"."uid"()));



CREATE POLICY "Admins manage matches" ON "public"."matches" TO "authenticated" USING ("public"."is_admin_manager"("auth"."uid"())) WITH CHECK ("public"."is_admin_manager"("auth"."uid"()));



CREATE POLICY "Admins manage moderation reports" ON "public"."moderation_reports" TO "authenticated" USING ("public"."is_admin_manager"("auth"."uid"())) WITH CHECK ("public"."is_admin_manager"("auth"."uid"()));



CREATE POLICY "Admins manage prediction engine outputs" ON "public"."predictions_engine_outputs" TO "authenticated" USING ("public"."current_user_has_admin_role"(ARRAY['moderator'::"text", 'admin'::"text", 'super_admin'::"text"])) WITH CHECK ("public"."current_user_has_admin_role"(ARRAY['moderator'::"text", 'admin'::"text", 'super_admin'::"text"]));



CREATE POLICY "Admins manage standings" ON "public"."standings" TO "authenticated" USING ("public"."current_user_has_admin_role"(ARRAY['moderator'::"text", 'admin'::"text", 'super_admin'::"text"])) WITH CHECK ("public"."current_user_has_admin_role"(ARRAY['moderator'::"text", 'admin'::"text", 'super_admin'::"text"]));



CREATE POLICY "Admins manage team aliases" ON "public"."team_aliases" TO "authenticated" USING ("public"."current_user_has_admin_role"(ARRAY['moderator'::"text", 'admin'::"text", 'super_admin'::"text"])) WITH CHECK ("public"."current_user_has_admin_role"(ARRAY['moderator'::"text", 'admin'::"text", 'super_admin'::"text"]));



CREATE POLICY "Admins manage team form features" ON "public"."team_form_features" TO "authenticated" USING ("public"."current_user_has_admin_role"(ARRAY['moderator'::"text", 'admin'::"text", 'super_admin'::"text"])) WITH CHECK ("public"."current_user_has_admin_role"(ARRAY['moderator'::"text", 'admin'::"text", 'super_admin'::"text"]));



CREATE POLICY "Admins manage token rewards" ON "public"."token_rewards" TO "authenticated" USING ("public"."current_user_has_admin_role"(ARRAY['moderator'::"text", 'admin'::"text", 'super_admin'::"text"])) WITH CHECK ("public"."current_user_has_admin_role"(ARRAY['moderator'::"text", 'admin'::"text", 'super_admin'::"text"]));



CREATE POLICY "Admins read moderation reports" ON "public"."moderation_reports" FOR SELECT TO "authenticated" USING ("public"."is_active_admin_operator"("auth"."uid"()));



CREATE POLICY "Admins read notifications" ON "public"."notification_log" FOR SELECT TO "authenticated" USING ("public"."is_active_admin_operator"("auth"."uid"()));



CREATE POLICY "Admins read user predictions" ON "public"."user_predictions" FOR SELECT TO "authenticated" USING ("public"."current_user_has_admin_role"(ARRAY['moderator'::"text", 'admin'::"text", 'super_admin'::"text"]));



CREATE POLICY "Admins read wallet transactions" ON "public"."fet_wallet_transactions" FOR SELECT TO "authenticated" USING ("public"."is_active_admin_operator"("auth"."uid"()));



CREATE POLICY "Public read access for competitions" ON "public"."competitions" FOR SELECT USING (true);



CREATE POLICY "Public read access for matches" ON "public"."matches" FOR SELECT USING (true);



CREATE POLICY "Public read access for teams" ON "public"."teams" FOR SELECT USING (true);



CREATE POLICY "Public read app config remote" ON "public"."app_config_remote" FOR SELECT USING (true);



CREATE POLICY "Public read competitions" ON "public"."competitions" FOR SELECT USING (true);



CREATE POLICY "Public read country currency map" ON "public"."country_currency_map" FOR SELECT USING (true);



CREATE POLICY "Public read country region map" ON "public"."country_region_map" FOR SELECT USING (true);



CREATE POLICY "Public read currency display" ON "public"."currency_display_metadata" FOR SELECT USING (true);



CREATE POLICY "Public read currency rates" ON "public"."currency_rates" FOR SELECT USING (true);



CREATE POLICY "Public read feature flags" ON "public"."feature_flags" FOR SELECT USING (true);



CREATE POLICY "Public read featured events" ON "public"."featured_events" FOR SELECT USING (true);



CREATE POLICY "Public read launch moments" ON "public"."launch_moments" FOR SELECT USING (true);



CREATE POLICY "Public read matches" ON "public"."matches" FOR SELECT USING (true);



CREATE POLICY "Public read phone presets" ON "public"."phone_presets" FOR SELECT USING (true);



CREATE POLICY "Public read teams" ON "public"."teams" FOR SELECT USING (true);



CREATE POLICY "Super admins manage admin directory" ON "public"."admin_users" TO "authenticated" USING ("public"."is_super_admin_user"("auth"."uid"())) WITH CHECK ("public"."is_super_admin_user"("auth"."uid"()));



CREATE POLICY "Users can delete own favorite teams" ON "public"."user_favorite_teams" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own events" ON "public"."product_events" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can insert own favorite teams" ON "public"."user_favorite_teams" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own market preferences" ON "public"."user_market_preferences" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own profile" ON "public"."profiles" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can manage followed competitions" ON "public"."user_followed_competitions" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can read own favorite teams" ON "public"."user_favorite_teams" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can read own market preferences" ON "public"."user_market_preferences" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own favorite teams" ON "public"."user_favorite_teams" FOR UPDATE USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own market preferences" ON "public"."user_market_preferences" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own profile" ON "public"."profiles" FOR UPDATE USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own profile" ON "public"."profiles" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own transactions" ON "public"."fet_wallet_transactions" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own wallet" ON "public"."fet_wallets" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users cancel own pending deletion requests" ON "public"."account_deletion_requests" FOR UPDATE TO "authenticated" USING ((("auth"."uid"() = "user_id") AND ("status" = 'pending'::"text"))) WITH CHECK ((("auth"."uid"() = "user_id") AND ("status" = ANY (ARRAY['pending'::"text", 'cancelled'::"text"]))));



CREATE POLICY "Users create own account deletion requests" ON "public"."account_deletion_requests" FOR INSERT TO "authenticated" WITH CHECK ((("auth"."uid"() = "user_id") AND ("status" = 'pending'::"text") AND ("processed_at" IS NULL) AND ("processed_by" IS NULL)));



CREATE POLICY "Users insert own predictions" ON "public"."user_predictions" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users manage own competition follows" ON "public"."user_followed_competitions" TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users manage own device tokens" ON "public"."device_tokens" TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users manage own match alerts" ON "public"."match_alert_subscriptions" TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users manage own notification prefs" ON "public"."notification_preferences" TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users read own account deletion requests" ON "public"."account_deletion_requests" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users read own notifications" ON "public"."notification_log" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users read own predictions" ON "public"."user_predictions" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users read own status" ON "public"."user_status" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users read own token rewards" ON "public"."token_rewards" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users read own transactions" ON "public"."fet_wallet_transactions" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users read own wallet" ON "public"."fet_wallets" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users update own notifications" ON "public"."notification_log" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users update own predictions" ON "public"."user_predictions" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."account_deletion_requests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."admin_audit_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."admin_users" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."anonymous_upgrade_claims" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."app_config_remote" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."app_runtime_errors" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."competitions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."country_currency_map" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."country_region_map" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."cron_job_log" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."currency_display_metadata" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."currency_rates" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "currency_rates_public_read" ON "public"."currency_rates" FOR SELECT USING (true);



ALTER TABLE "public"."device_tokens" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "engine_outputs_public_read" ON "public"."predictions_engine_outputs" FOR SELECT USING (true);



ALTER TABLE "public"."fan_badges" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "fan_badges_public_read" ON "public"."fan_badges" FOR SELECT USING (true);



ALTER TABLE "public"."fan_earned_badges" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."fan_levels" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "fan_levels_public_read" ON "public"."fan_levels" FOR SELECT USING (true);



ALTER TABLE "public"."feature_flags" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."featured_events" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "featured_events_public_read" ON "public"."featured_events" FOR SELECT USING (true);



ALTER TABLE "public"."fet_wallet_transactions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."fet_wallets" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."launch_moments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."leaderboard_seasons" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "leaderboard_seasons_public_read" ON "public"."leaderboard_seasons" FOR SELECT USING (true);



ALTER TABLE "public"."match_alert_dispatch_log" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."match_alert_subscriptions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."matches" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."moderation_reports" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notification_log" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notification_preferences" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."otp_verifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."phone_presets" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."predictions_engine_outputs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."rate_limits" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."seasons" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "seasons_public_read" ON "public"."seasons" FOR SELECT USING (true);



ALTER TABLE "public"."standings" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "standings_public_read" ON "public"."standings" FOR SELECT USING (true);



ALTER TABLE "public"."team_aliases" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "team_aliases_public_read" ON "public"."team_aliases" FOR SELECT USING (true);



ALTER TABLE "public"."team_form_features" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "team_form_features_public_read" ON "public"."team_form_features" FOR SELECT USING (true);



ALTER TABLE "public"."teams" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."token_rewards" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_favorite_teams" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_followed_competitions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_market_preferences" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_predictions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_status" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."whatsapp_auth_sessions" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."active_admin_record_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."active_admin_record_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."active_admin_record_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_ban_user"("p_target_user_id" "uuid", "p_reason" "text", "p_until" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."admin_ban_user"("p_target_user_id" "uuid", "p_reason" "text", "p_until" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_ban_user"("p_target_user_id" "uuid", "p_reason" "text", "p_until" timestamp with time zone) TO "service_role";



GRANT ALL ON TABLE "public"."admin_users" TO "anon";
GRANT ALL ON TABLE "public"."admin_users" TO "authenticated";
GRANT ALL ON TABLE "public"."admin_users" TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_change_admin_role"("p_admin_id" "uuid", "p_role" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_change_admin_role"("p_admin_id" "uuid", "p_role" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_change_admin_role"("p_admin_id" "uuid", "p_role" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_change_admin_role"("p_admin_id" "uuid", "p_role" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_competition_distribution"("p_days" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."admin_competition_distribution"("p_days" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_competition_distribution"("p_days" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_credit_fet"("p_target_user_id" "uuid", "p_amount" bigint, "p_reason" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_credit_fet"("p_target_user_id" "uuid", "p_amount" bigint, "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_credit_fet"("p_target_user_id" "uuid", "p_amount" bigint, "p_reason" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_dashboard_kpis"() TO "anon";
GRANT ALL ON FUNCTION "public"."admin_dashboard_kpis"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_dashboard_kpis"() TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_debit_fet"("p_target_user_id" "uuid", "p_amount" bigint, "p_reason" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_debit_fet"("p_target_user_id" "uuid", "p_amount" bigint, "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_debit_fet"("p_target_user_id" "uuid", "p_amount" bigint, "p_reason" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_engagement_daily"("p_days" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."admin_engagement_daily"("p_days" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_engagement_daily"("p_days" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_engagement_kpis"() TO "anon";
GRANT ALL ON FUNCTION "public"."admin_engagement_kpis"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_engagement_kpis"() TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_fet_flow_weekly"("p_weeks" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."admin_fet_flow_weekly"("p_weeks" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_fet_flow_weekly"("p_weeks" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_freeze_wallet"("p_target_user_id" "uuid", "p_reason" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_freeze_wallet"("p_target_user_id" "uuid", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_freeze_wallet"("p_target_user_id" "uuid", "p_reason" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_global_search"("p_query" "text", "p_limit" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_global_search"("p_query" "text", "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."admin_global_search"("p_query" "text", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_global_search"("p_query" "text", "p_limit" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_grant_access"("p_phone" "text", "p_role" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_grant_access"("p_phone" "text", "p_role" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_grant_access"("p_phone" "text", "p_role" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_grant_access"("p_phone" "text", "p_role" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_log_action"("p_action" "text", "p_module" "text", "p_target_type" "text", "p_target_id" "text", "p_before_state" "jsonb", "p_after_state" "jsonb", "p_metadata" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_log_action"("p_action" "text", "p_module" "text", "p_target_type" "text", "p_target_id" "text", "p_before_state" "jsonb", "p_after_state" "jsonb", "p_metadata" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_log_action"("p_action" "text", "p_module" "text", "p_target_type" "text", "p_target_id" "text", "p_before_state" "jsonb", "p_after_state" "jsonb", "p_metadata" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_query_daily_active_users"("p_since" timestamp with time zone, "p_until" timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_query_daily_active_users"("p_since" timestamp with time zone, "p_until" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."admin_query_daily_active_users"("p_since" timestamp with time zone, "p_until" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_query_daily_active_users"("p_since" timestamp with time zone, "p_until" timestamp with time zone) TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_query_event_counts"("p_since" timestamp with time zone, "p_until" timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_query_event_counts"("p_since" timestamp with time zone, "p_until" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."admin_query_event_counts"("p_since" timestamp with time zone, "p_until" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_query_event_counts"("p_since" timestamp with time zone, "p_until" timestamp with time zone) TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_query_screen_views"("p_since" timestamp with time zone, "p_until" timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_query_screen_views"("p_since" timestamp with time zone, "p_until" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."admin_query_screen_views"("p_since" timestamp with time zone, "p_until" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_query_screen_views"("p_since" timestamp with time zone, "p_until" timestamp with time zone) TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_revoke_access"("p_admin_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_revoke_access"("p_admin_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_revoke_access"("p_admin_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_revoke_access"("p_admin_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_set_competition_featured"("p_competition_id" "text", "p_is_featured" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."admin_set_competition_featured"("p_competition_id" "text", "p_is_featured" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_set_competition_featured"("p_competition_id" "text", "p_is_featured" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_set_feature_flag"("p_flag_id" "text", "p_is_enabled" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."admin_set_feature_flag"("p_flag_id" "text", "p_is_enabled" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_set_feature_flag"("p_flag_id" "text", "p_is_enabled" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_set_featured_event_active"("p_event_id" "uuid", "p_is_active" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."admin_set_featured_event_active"("p_event_id" "uuid", "p_is_active" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_set_featured_event_active"("p_event_id" "uuid", "p_is_active" boolean) TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_trigger_currency_rate_refresh"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_trigger_currency_rate_refresh"() TO "anon";
GRANT ALL ON FUNCTION "public"."admin_trigger_currency_rate_refresh"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_trigger_currency_rate_refresh"() TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_unban_user"("p_target_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_unban_user"("p_target_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_unban_user"("p_target_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_unfreeze_wallet"("p_target_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_unfreeze_wallet"("p_target_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_unfreeze_wallet"("p_target_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_update_account_deletion_request"("p_request_id" "uuid", "p_status" "text", "p_resolution_notes" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_update_account_deletion_request"("p_request_id" "uuid", "p_status" "text", "p_resolution_notes" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_update_account_deletion_request"("p_request_id" "uuid", "p_status" "text", "p_resolution_notes" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_update_match_result"("p_match_id" "text", "p_home_goals" integer, "p_away_goals" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."admin_update_match_result"("p_match_id" "text", "p_home_goals" integer, "p_away_goals" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_update_match_result"("p_match_id" "text", "p_home_goals" integer, "p_away_goals" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_update_moderation_report_status"("p_report_id" "uuid", "p_status" "text", "p_resolution_notes" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_update_moderation_report_status"("p_report_id" "uuid", "p_status" "text", "p_resolution_notes" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_update_moderation_report_status"("p_report_id" "uuid", "p_status" "text", "p_resolution_notes" "text") TO "service_role";



GRANT ALL ON TABLE "public"."seasons" TO "anon";
GRANT ALL ON TABLE "public"."seasons" TO "authenticated";
GRANT ALL ON TABLE "public"."seasons" TO "service_role";



GRANT ALL ON TABLE "public"."standings" TO "anon";
GRANT ALL ON TABLE "public"."standings" TO "authenticated";
GRANT ALL ON TABLE "public"."standings" TO "service_role";



GRANT ALL ON TABLE "public"."teams" TO "anon";
GRANT ALL ON TABLE "public"."teams" TO "authenticated";
GRANT ALL ON TABLE "public"."teams" TO "service_role";



GRANT ALL ON TABLE "public"."competition_standings" TO "anon";
GRANT ALL ON TABLE "public"."competition_standings" TO "authenticated";
GRANT ALL ON TABLE "public"."competition_standings" TO "service_role";



GRANT ALL ON FUNCTION "public"."app_competition_standings"("p_competition_id" "text", "p_season" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."app_competition_standings"("p_competition_id" "text", "p_season" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."app_competition_standings"("p_competition_id" "text", "p_season" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."app_config_bigint"("p_key" "text", "p_default" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."app_config_bigint"("p_key" "text", "p_default" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."app_config_bigint"("p_key" "text", "p_default" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."apply_match_result_code"() TO "anon";
GRANT ALL ON FUNCTION "public"."apply_match_result_code"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."apply_match_result_code"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."assert_fet_mint_within_cap"("p_amount" bigint, "p_context" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."assert_fet_mint_within_cap"("p_amount" bigint, "p_context" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."assert_fet_mint_within_cap"("p_amount" bigint, "p_context" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."assert_fet_mint_within_cap"("p_amount" bigint, "p_context" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."assert_wallet_available"("p_user_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."assert_wallet_available"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."assert_wallet_available"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."assert_wallet_available"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."assign_profile_fan_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."assign_profile_fan_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."assign_profile_fan_id"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."audit_wallet_bootstrap_gaps"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."audit_wallet_bootstrap_gaps"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."check_rate_limit"("p_user_id" "uuid", "p_action" "text", "p_max_count" integer, "p_window_hours" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."check_rate_limit"("p_user_id" "uuid", "p_action" "text", "p_max_count" integer, "p_window_hours" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."check_rate_limit"("p_user_id" "uuid", "p_action" "text", "p_max_count" integer, "p_window_hours" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_rate_limit"("p_user_id" "uuid", "p_action" "text", "p_max_count" integer, "p_window_hours" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."check_rate_limit"("p_user_id" "uuid", "p_action" "text", "p_max_count" integer, "p_window" interval) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."check_rate_limit"("p_user_id" "uuid", "p_action" "text", "p_max_count" integer, "p_window" interval) TO "anon";
GRANT ALL ON FUNCTION "public"."check_rate_limit"("p_user_id" "uuid", "p_action" "text", "p_max_count" integer, "p_window" interval) TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_rate_limit"("p_user_id" "uuid", "p_action" "text", "p_max_count" integer, "p_window" interval) TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_expired_otps"() TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_expired_otps"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_expired_otps"() TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_rate_limits"() TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_rate_limits"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_rate_limits"() TO "service_role";



GRANT ALL ON FUNCTION "public"."competition_catalog_rank"("p_competition_id" "text", "p_competition_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."competition_catalog_rank"("p_competition_id" "text", "p_competition_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."competition_catalog_rank"("p_competition_id" "text", "p_competition_name" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_fan_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."generate_fan_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_fan_id"() TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON FUNCTION "public"."complete_user_onboarding"("p_display_name" "text", "p_favorite_team_id" "text", "p_favorite_team_name" "text", "p_country_code" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."complete_user_onboarding"("p_display_name" "text", "p_favorite_team_id" "text", "p_favorite_team_name" "text", "p_country_code" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."complete_user_onboarding"("p_display_name" "text", "p_favorite_team_id" "text", "p_favorite_team_name" "text", "p_country_code" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."compute_result_code"("p_home_goals" integer, "p_away_goals" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."compute_result_code"("p_home_goals" integer, "p_away_goals" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."compute_result_code"("p_home_goals" integer, "p_away_goals" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."current_user_has_admin_role"("p_roles" "text"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."current_user_has_admin_role"("p_roles" "text"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."current_user_has_admin_role"("p_roles" "text"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_user_has_admin_role"("p_roles" "text"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."ensure_user_foundation"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."ensure_user_foundation"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ensure_user_foundation"("p_user_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."fet_supply_cap"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."fet_supply_cap"() TO "anon";
GRANT ALL ON FUNCTION "public"."fet_supply_cap"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fet_supply_cap"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."find_auth_user_by_phone"("p_phone" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."find_auth_user_by_phone"("p_phone" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."find_auth_user_by_phone"("p_phone" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_auth_user_by_phone"("p_phone" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_prediction_engine_output"("p_match_id" "text", "p_model_version" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_prediction_engine_output"("p_match_id" "text", "p_model_version" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_prediction_engine_output"("p_match_id" "text", "p_model_version" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_predictions_for_matches"("p_match_ids" "text"[], "p_limit" integer, "p_model_version" "text", "p_include_finished" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."generate_predictions_for_matches"("p_match_ids" "text"[], "p_limit" integer, "p_model_version" "text", "p_include_finished" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_predictions_for_matches"("p_match_ids" "text"[], "p_limit" integer, "p_model_version" "text", "p_include_finished" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_predictions_for_upcoming_matches"("p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."generate_predictions_for_upcoming_matches"("p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_predictions_for_upcoming_matches"("p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_profile_fan_id"("p_seed" "text", "p_attempt" integer, "p_profile_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_profile_fan_id"("p_seed" "text", "p_attempt" integer, "p_profile_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_profile_fan_id"("p_seed" "text", "p_attempt" integer, "p_profile_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_team_form_features_for_matches"("p_match_ids" "text"[], "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."generate_team_form_features_for_matches"("p_match_ids" "text"[], "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_team_form_features_for_matches"("p_match_ids" "text"[], "p_limit" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_admin_me"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_admin_me"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_admin_me"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_admin_me"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_app_bootstrap_config"("p_market" "text", "p_platform" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_app_bootstrap_config"("p_market" "text", "p_platform" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_app_bootstrap_config"("p_market" "text", "p_platform" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_competition_current_season"("p_competition_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_competition_current_season"("p_competition_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_competition_current_season"("p_competition_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_country_region"("p_country_code" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_country_region"("p_country_code" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_country_region"("p_country_code" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."guess_user_currency"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."guess_user_currency"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."guess_user_currency"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."install_openfootball_sync_schedule"("p_project_url" "text", "p_anon_key" "text", "p_admin_secret" "text", "p_schedule" "text", "p_payload" "jsonb", "p_job_name" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."install_openfootball_sync_schedule"("p_project_url" "text", "p_anon_key" "text", "p_admin_secret" "text", "p_schedule" "text", "p_payload" "jsonb", "p_job_name" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_active_admin_operator"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_active_admin_operator"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_active_admin_operator"("p_user_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_active_admin_user"("p_user_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_active_admin_user"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_active_admin_user"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_active_admin_user"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_admin_manager"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_admin_manager"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_admin_manager"("p_user_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_service_role_request"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_service_role_request"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_service_role_request"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_service_role_request"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_super_admin_user"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_super_admin_user"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_super_admin_user"("p_user_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."issue_anonymous_upgrade_claim"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."issue_anonymous_upgrade_claim"() TO "anon";
GRANT ALL ON FUNCTION "public"."issue_anonymous_upgrade_claim"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."issue_anonymous_upgrade_claim"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."lock_fet_supply_cap"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."lock_fet_supply_cap"() TO "anon";
GRANT ALL ON FUNCTION "public"."lock_fet_supply_cap"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."lock_fet_supply_cap"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."log_app_runtime_errors_batch"("p_errors" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."log_app_runtime_errors_batch"("p_errors" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."log_app_runtime_errors_batch"("p_errors" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."log_app_runtime_errors_batch"("p_errors" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."log_product_event"("p_event_name" "text", "p_properties" "jsonb", "p_session_id" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."log_product_event"("p_event_name" "text", "p_properties" "jsonb", "p_session_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."log_product_event"("p_event_name" "text", "p_properties" "jsonb", "p_session_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."log_product_event"("p_event_name" "text", "p_properties" "jsonb", "p_session_id" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."log_product_events_batch"("p_events" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."log_product_events_batch"("p_events" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."log_product_events_batch"("p_events" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."log_product_events_batch"("p_events" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."mark_all_notifications_read"() TO "anon";
GRANT ALL ON FUNCTION "public"."mark_all_notifications_read"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_all_notifications_read"() TO "service_role";



GRANT ALL ON FUNCTION "public"."mark_notification_read"("p_notification_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."mark_notification_read"("p_notification_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_notification_read"("p_notification_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."merge_anonymous_to_authenticated"("p_anon_id" "uuid", "p_auth_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."merge_anonymous_to_authenticated"("p_anon_id" "uuid", "p_auth_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."merge_anonymous_to_authenticated_secure"("p_anon_id" "uuid", "p_claim_token" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."merge_anonymous_to_authenticated_secure"("p_anon_id" "uuid", "p_claim_token" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."merge_anonymous_to_authenticated_secure"("p_anon_id" "uuid", "p_claim_token" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."merge_anonymous_to_authenticated_secure"("p_anon_id" "uuid", "p_claim_token" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."normalize_match_status"("p_status" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."normalize_match_status"("p_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."normalize_match_status"("p_status" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_wallet_credit"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_wallet_credit"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_wallet_credit"() TO "service_role";



GRANT ALL ON FUNCTION "public"."phone_auth_email"("p_phone" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."phone_auth_email"("p_phone" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."phone_auth_email"("p_phone" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."refresh_competition_derived_fields"("p_competition_ids" "text"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."refresh_competition_derived_fields"("p_competition_ids" "text"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."refresh_competition_derived_fields"("p_competition_ids" "text"[]) TO "service_role";



REVOKE ALL ON FUNCTION "public"."refresh_global_leaderboard"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."refresh_global_leaderboard"() TO "anon";
GRANT ALL ON FUNCTION "public"."refresh_global_leaderboard"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."refresh_global_leaderboard"() TO "service_role";



GRANT ALL ON FUNCTION "public"."refresh_materialized_views"() TO "anon";
GRANT ALL ON FUNCTION "public"."refresh_materialized_views"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."refresh_materialized_views"() TO "service_role";



GRANT ALL ON FUNCTION "public"."refresh_season_leaderboard"() TO "anon";
GRANT ALL ON FUNCTION "public"."refresh_season_leaderboard"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."refresh_season_leaderboard"() TO "service_role";



GRANT ALL ON FUNCTION "public"."refresh_team_derived_fields"("p_team_ids" "text"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."refresh_team_derived_fields"("p_team_ids" "text"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."refresh_team_derived_fields"("p_team_ids" "text"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."refresh_team_form_features_for_match"("p_match_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."refresh_team_form_features_for_match"("p_match_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."refresh_team_form_features_for_match"("p_match_id" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."remove_openfootball_sync_schedule"("p_job_name" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."remove_openfootball_sync_schedule"("p_job_name" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."repair_wallet_bootstrap_gaps"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."repair_wallet_bootstrap_gaps"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."require_active_admin_user"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."require_active_admin_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."require_active_admin_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."require_active_admin_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."require_admin_manager_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."require_admin_manager_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."require_admin_manager_user"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."require_super_admin_user"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."require_super_admin_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."require_super_admin_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."require_super_admin_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."resolve_auth_user_phone"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."resolve_auth_user_phone"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."resolve_auth_user_phone"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "anon";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "service_role";



GRANT ALL ON FUNCTION "public"."safe_catalog_key"("p_value" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."safe_catalog_key"("p_value" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."safe_catalog_key"("p_value" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."score_finished_matches_with_pending_predictions"("p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."score_finished_matches_with_pending_predictions"("p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."score_finished_matches_with_pending_predictions"("p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."score_user_predictions_for_match"("p_match_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."score_user_predictions_for_match"("p_match_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."score_user_predictions_for_match"("p_match_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."season_end_year"("p_label" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."season_end_year"("p_label" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."season_end_year"("p_label" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."season_sort_key"("p_season" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."season_sort_key"("p_season" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."season_sort_key"("p_season" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."season_start_year"("p_label" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."season_start_year"("p_label" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."season_start_year"("p_label" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."send_push_to_user"("p_user_id" "uuid", "p_type" "text", "p_title" "text", "p_body" "text", "p_data" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."send_push_to_user"("p_user_id" "uuid", "p_type" "text", "p_title" "text", "p_body" "text", "p_data" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_row_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_row_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_row_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."submit_user_prediction"("p_match_id" "text", "p_predicted_result_code" "text", "p_predicted_over25" boolean, "p_predicted_btts" boolean, "p_predicted_home_goals" integer, "p_predicted_away_goals" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."submit_user_prediction"("p_match_id" "text", "p_predicted_result_code" "text", "p_predicted_over25" boolean, "p_predicted_btts" boolean, "p_predicted_home_goals" integer, "p_predicted_away_goals" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."submit_user_prediction"("p_match_id" "text", "p_predicted_result_code" "text", "p_predicted_over25" boolean, "p_predicted_btts" boolean, "p_predicted_home_goals" integer, "p_predicted_away_goals" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_public_feature_flags_from_admin"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_public_feature_flags_from_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_public_feature_flags_from_admin"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."transfer_fet"("p_recipient_identifier" "text", "p_amount_fet" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."transfer_fet"("p_recipient_identifier" "text", "p_amount_fet" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."transfer_fet"("p_recipient_identifier" "text", "p_amount_fet" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."transfer_fet"("p_recipient_identifier" "text", "p_amount_fet" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."transfer_fet_by_fan_id"("p_recipient_fan_id" "text", "p_amount_fet" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."transfer_fet_by_fan_id"("p_recipient_fan_id" "text", "p_amount_fet" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."transfer_fet_by_fan_id"("p_recipient_fan_id" "text", "p_amount_fet" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."upsert_team_form_feature"("p_match_id" "text", "p_team_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."upsert_team_form_feature"("p_match_id" "text", "p_team_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."upsert_team_form_feature"("p_match_id" "text", "p_team_id" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."upsert_vault_secret"("p_name" "text", "p_secret" "text", "p_description" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."upsert_vault_secret"("p_name" "text", "p_secret" "text", "p_description" "text") TO "service_role";



GRANT ALL ON TABLE "public"."account_deletion_requests" TO "anon";
GRANT ALL ON TABLE "public"."account_deletion_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."account_deletion_requests" TO "service_role";



GRANT ALL ON TABLE "public"."admin_audit_logs" TO "anon";
GRANT ALL ON TABLE "public"."admin_audit_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."admin_audit_logs" TO "service_role";



GRANT ALL ON TABLE "public"."admin_audit_logs_enriched" TO "anon";
GRANT ALL ON TABLE "public"."admin_audit_logs_enriched" TO "authenticated";
GRANT ALL ON TABLE "public"."admin_audit_logs_enriched" TO "service_role";



GRANT ALL ON SEQUENCE "public"."admin_audit_logs_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."admin_audit_logs_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."admin_audit_logs_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."feature_flags" TO "anon";
GRANT ALL ON TABLE "public"."feature_flags" TO "authenticated";
GRANT ALL ON TABLE "public"."feature_flags" TO "service_role";



GRANT ALL ON TABLE "public"."admin_feature_flags" TO "anon";
GRANT ALL ON TABLE "public"."admin_feature_flags" TO "authenticated";
GRANT ALL ON TABLE "public"."admin_feature_flags" TO "service_role";



GRANT ALL ON TABLE "public"."anonymous_upgrade_claims" TO "anon";
GRANT ALL ON TABLE "public"."anonymous_upgrade_claims" TO "authenticated";
GRANT ALL ON TABLE "public"."anonymous_upgrade_claims" TO "service_role";



GRANT ALL ON TABLE "public"."competitions" TO "anon";
GRANT ALL ON TABLE "public"."competitions" TO "authenticated";
GRANT ALL ON TABLE "public"."competitions" TO "service_role";



GRANT ALL ON TABLE "public"."matches" TO "anon";
GRANT ALL ON TABLE "public"."matches" TO "authenticated";
GRANT ALL ON TABLE "public"."matches" TO "service_role";



GRANT ALL ON TABLE "public"."app_competitions" TO "anon";
GRANT ALL ON TABLE "public"."app_competitions" TO "authenticated";
GRANT ALL ON TABLE "public"."app_competitions" TO "service_role";



GRANT ALL ON TABLE "public"."app_competitions_ranked" TO "anon";
GRANT ALL ON TABLE "public"."app_competitions_ranked" TO "authenticated";
GRANT ALL ON TABLE "public"."app_competitions_ranked" TO "service_role";



GRANT ALL ON TABLE "public"."app_config_remote" TO "anon";
GRANT ALL ON TABLE "public"."app_config_remote" TO "authenticated";
GRANT ALL ON TABLE "public"."app_config_remote" TO "service_role";



GRANT ALL ON TABLE "public"."app_matches" TO "anon";
GRANT ALL ON TABLE "public"."app_matches" TO "authenticated";
GRANT ALL ON TABLE "public"."app_matches" TO "service_role";



GRANT ALL ON TABLE "public"."app_runtime_errors" TO "anon";
GRANT ALL ON TABLE "public"."app_runtime_errors" TO "authenticated";
GRANT ALL ON TABLE "public"."app_runtime_errors" TO "service_role";



GRANT ALL ON TABLE "public"."country_currency_map" TO "anon";
GRANT ALL ON TABLE "public"."country_currency_map" TO "authenticated";
GRANT ALL ON TABLE "public"."country_currency_map" TO "service_role";



GRANT ALL ON TABLE "public"."country_region_map" TO "anon";
GRANT ALL ON TABLE "public"."country_region_map" TO "authenticated";
GRANT ALL ON TABLE "public"."country_region_map" TO "service_role";



GRANT ALL ON TABLE "public"."cron_job_log" TO "anon";
GRANT ALL ON TABLE "public"."cron_job_log" TO "authenticated";
GRANT ALL ON TABLE "public"."cron_job_log" TO "service_role";



GRANT ALL ON TABLE "public"."currency_display_metadata" TO "anon";
GRANT ALL ON TABLE "public"."currency_display_metadata" TO "authenticated";
GRANT ALL ON TABLE "public"."currency_display_metadata" TO "service_role";



GRANT ALL ON TABLE "public"."currency_rates" TO "anon";
GRANT ALL ON TABLE "public"."currency_rates" TO "authenticated";
GRANT ALL ON TABLE "public"."currency_rates" TO "service_role";



GRANT ALL ON TABLE "public"."device_tokens" TO "anon";
GRANT ALL ON TABLE "public"."device_tokens" TO "authenticated";
GRANT ALL ON TABLE "public"."device_tokens" TO "service_role";



GRANT ALL ON TABLE "public"."fan_badges" TO "anon";
GRANT ALL ON TABLE "public"."fan_badges" TO "authenticated";
GRANT ALL ON TABLE "public"."fan_badges" TO "service_role";



GRANT ALL ON TABLE "public"."fan_earned_badges" TO "anon";
GRANT ALL ON TABLE "public"."fan_earned_badges" TO "authenticated";
GRANT ALL ON TABLE "public"."fan_earned_badges" TO "service_role";



GRANT ALL ON SEQUENCE "public"."fan_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."fan_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."fan_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."fan_levels" TO "anon";
GRANT ALL ON TABLE "public"."fan_levels" TO "authenticated";
GRANT ALL ON TABLE "public"."fan_levels" TO "service_role";



GRANT ALL ON TABLE "public"."featured_events" TO "anon";
GRANT ALL ON TABLE "public"."featured_events" TO "authenticated";
GRANT ALL ON TABLE "public"."featured_events" TO "service_role";



GRANT ALL ON TABLE "public"."fet_wallets" TO "anon";
GRANT ALL ON TABLE "public"."fet_wallets" TO "authenticated";
GRANT ALL ON TABLE "public"."fet_wallets" TO "service_role";



GRANT ALL ON TABLE "public"."fet_supply_overview" TO "anon";
GRANT ALL ON TABLE "public"."fet_supply_overview" TO "authenticated";
GRANT ALL ON TABLE "public"."fet_supply_overview" TO "service_role";



GRANT ALL ON TABLE "public"."fet_supply_overview_admin" TO "anon";
GRANT ALL ON TABLE "public"."fet_supply_overview_admin" TO "authenticated";
GRANT ALL ON TABLE "public"."fet_supply_overview_admin" TO "service_role";



GRANT ALL ON TABLE "public"."fet_wallet_transactions" TO "anon";
GRANT ALL ON TABLE "public"."fet_wallet_transactions" TO "authenticated";
GRANT ALL ON TABLE "public"."fet_wallet_transactions" TO "service_role";



GRANT ALL ON TABLE "public"."fet_transactions_admin" TO "anon";
GRANT ALL ON TABLE "public"."fet_transactions_admin" TO "authenticated";
GRANT ALL ON TABLE "public"."fet_transactions_admin" TO "service_role";



GRANT ALL ON TABLE "public"."launch_moments" TO "anon";
GRANT ALL ON TABLE "public"."launch_moments" TO "authenticated";
GRANT ALL ON TABLE "public"."launch_moments" TO "service_role";



GRANT ALL ON TABLE "public"."leaderboard_seasons" TO "anon";
GRANT ALL ON TABLE "public"."leaderboard_seasons" TO "authenticated";
GRANT ALL ON TABLE "public"."leaderboard_seasons" TO "service_role";



GRANT ALL ON TABLE "public"."match_alert_dispatch_log" TO "anon";
GRANT ALL ON TABLE "public"."match_alert_dispatch_log" TO "authenticated";
GRANT ALL ON TABLE "public"."match_alert_dispatch_log" TO "service_role";



GRANT ALL ON TABLE "public"."match_alert_subscriptions" TO "anon";
GRANT ALL ON TABLE "public"."match_alert_subscriptions" TO "authenticated";
GRANT ALL ON TABLE "public"."match_alert_subscriptions" TO "service_role";



GRANT ALL ON TABLE "public"."user_predictions" TO "anon";
GRANT ALL ON TABLE "public"."user_predictions" TO "authenticated";
GRANT ALL ON TABLE "public"."user_predictions" TO "service_role";



GRANT ALL ON TABLE "public"."match_prediction_consensus" TO "anon";
GRANT ALL ON TABLE "public"."match_prediction_consensus" TO "authenticated";
GRANT ALL ON TABLE "public"."match_prediction_consensus" TO "service_role";



GRANT ALL ON TABLE "public"."moderation_reports" TO "anon";
GRANT ALL ON TABLE "public"."moderation_reports" TO "authenticated";
GRANT ALL ON TABLE "public"."moderation_reports" TO "service_role";



GRANT ALL ON TABLE "public"."notification_log" TO "anon";
GRANT ALL ON TABLE "public"."notification_log" TO "authenticated";
GRANT ALL ON TABLE "public"."notification_log" TO "service_role";



GRANT ALL ON TABLE "public"."notification_preferences" TO "anon";
GRANT ALL ON TABLE "public"."notification_preferences" TO "authenticated";
GRANT ALL ON TABLE "public"."notification_preferences" TO "service_role";



GRANT ALL ON TABLE "public"."otp_verifications" TO "service_role";



GRANT ALL ON TABLE "public"."phone_presets" TO "anon";
GRANT ALL ON TABLE "public"."phone_presets" TO "authenticated";
GRANT ALL ON TABLE "public"."phone_presets" TO "service_role";



GRANT ALL ON TABLE "public"."token_rewards" TO "anon";
GRANT ALL ON TABLE "public"."token_rewards" TO "authenticated";
GRANT ALL ON TABLE "public"."token_rewards" TO "service_role";



GRANT ALL ON TABLE "public"."prediction_leaderboard" TO "anon";
GRANT ALL ON TABLE "public"."prediction_leaderboard" TO "authenticated";
GRANT ALL ON TABLE "public"."prediction_leaderboard" TO "service_role";



GRANT ALL ON TABLE "public"."predictions_engine_outputs" TO "anon";
GRANT ALL ON TABLE "public"."predictions_engine_outputs" TO "authenticated";
GRANT ALL ON TABLE "public"."predictions_engine_outputs" TO "service_role";



GRANT ALL ON TABLE "public"."product_events" TO "anon";
GRANT ALL ON TABLE "public"."product_events" TO "authenticated";
GRANT ALL ON TABLE "public"."product_events" TO "service_role";



GRANT ALL ON TABLE "public"."public_leaderboard" TO "anon";
GRANT ALL ON TABLE "public"."public_leaderboard" TO "authenticated";
GRANT ALL ON TABLE "public"."public_leaderboard" TO "service_role";



GRANT ALL ON TABLE "public"."rate_limits" TO "service_role";



GRANT ALL ON SEQUENCE "public"."rate_limits_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."rate_limits_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."rate_limits_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."team_aliases" TO "anon";
GRANT ALL ON TABLE "public"."team_aliases" TO "authenticated";
GRANT ALL ON TABLE "public"."team_aliases" TO "service_role";



GRANT ALL ON TABLE "public"."team_form_features" TO "anon";
GRANT ALL ON TABLE "public"."team_form_features" TO "authenticated";
GRANT ALL ON TABLE "public"."team_form_features" TO "service_role";



GRANT ALL ON TABLE "public"."user_favorite_teams" TO "anon";
GRANT ALL ON TABLE "public"."user_favorite_teams" TO "authenticated";
GRANT ALL ON TABLE "public"."user_favorite_teams" TO "service_role";



GRANT ALL ON TABLE "public"."user_followed_competitions" TO "anon";
GRANT ALL ON TABLE "public"."user_followed_competitions" TO "authenticated";
GRANT ALL ON TABLE "public"."user_followed_competitions" TO "service_role";



GRANT ALL ON TABLE "public"."user_market_preferences" TO "anon";
GRANT ALL ON TABLE "public"."user_market_preferences" TO "authenticated";
GRANT ALL ON TABLE "public"."user_market_preferences" TO "service_role";



GRANT ALL ON TABLE "public"."user_status" TO "anon";
GRANT ALL ON TABLE "public"."user_status" TO "authenticated";
GRANT ALL ON TABLE "public"."user_status" TO "service_role";



GRANT ALL ON TABLE "public"."user_profiles_admin" TO "anon";
GRANT ALL ON TABLE "public"."user_profiles_admin" TO "authenticated";
GRANT ALL ON TABLE "public"."user_profiles_admin" TO "service_role";



GRANT ALL ON TABLE "public"."wallet_overview" TO "anon";
GRANT ALL ON TABLE "public"."wallet_overview" TO "authenticated";
GRANT ALL ON TABLE "public"."wallet_overview" TO "service_role";



GRANT ALL ON TABLE "public"."wallet_overview_admin" TO "anon";
GRANT ALL ON TABLE "public"."wallet_overview_admin" TO "authenticated";
GRANT ALL ON TABLE "public"."wallet_overview_admin" TO "service_role";



GRANT ALL ON TABLE "public"."whatsapp_auth_sessions" TO "anon";
GRANT ALL ON TABLE "public"."whatsapp_auth_sessions" TO "authenticated";
GRANT ALL ON TABLE "public"."whatsapp_auth_sessions" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";







