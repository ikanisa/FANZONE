-- Sports-bar platform clean baseline.
-- Generated from a local replay of the repository schema on 2026-05-01.

CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA extensions;

--
-- PostgreSQL database dump
--

-- Dumped from database version 15.3
-- Dumped by pg_dump version 15.3

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

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA IF NOT EXISTS public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: country_code; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.country_code AS ENUM (
    'RW',
    'MT'
);


--
-- Name: match_pool_entry_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.match_pool_entry_status AS ENUM (
    'active',
    'won',
    'lost',
    'refunded',
    'cancelled'
);


--
-- Name: match_pool_scope; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.match_pool_scope AS ENUM (
    'global',
    'country',
    'venue'
);


--
-- Name: match_pool_settlement_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.match_pool_settlement_status AS ENUM (
    'pending',
    'running',
    'completed',
    'failed',
    'reversed'
);


--
-- Name: match_pool_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.match_pool_status AS ENUM (
    'draft',
    'open',
    'locked',
    'live',
    'settling',
    'settled',
    'cancelled'
);


--
-- Name: menu_import_source; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.menu_import_source AS ENUM (
    'manual',
    'ocr_image',
    'ocr_pdf',
    'file_import'
);


--
-- Name: menu_import_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.menu_import_status AS ENUM (
    'pending',
    'processing',
    'review',
    'approved',
    'rejected',
    'failed'
);


--
-- Name: onboarding_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.onboarding_status AS ENUM (
    'draft',
    'profile_complete',
    'location_complete',
    'menu_pending',
    'live'
);


--
-- Name: order_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.order_status AS ENUM (
    'placed',
    'received',
    'served',
    'cancelled'
);


--
-- Name: payment_method; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.payment_method AS ENUM (
    'momo',
    'revolut',
    'cash'
);


--
-- Name: venue_payment_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.venue_payment_status AS ENUM (
    'pending',
    'paid',
    'failed',
    'cancelled',
    'refunded',
    'unpaid',
    'partially_paid',
    'disputed'
);


--
-- Name: venue_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.venue_type AS ENUM (
    'bar',
    'restaurant',
    'hotel',
    'event'
);


--
-- Name: venue_user_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.venue_user_role AS ENUM (
    'owner',
    'manager',
    'staff'
);


--
-- Name: active_admin_record_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.active_admin_record_id() RETURNS uuid
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
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


--
-- Name: admin_adjust_fet(uuid, bigint, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_adjust_fet(p_target_user_id uuid, p_amount_fet bigint, p_direction text, p_reason text, p_idempotency_key text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_admin_user_id uuid := auth.uid();
  v_admin_record_id uuid;
  v_direction text := lower(trim(coalesce(p_direction, '')));
  v_before jsonb;
  v_after jsonb;
  v_result jsonb;
BEGIN
  v_admin_user_id := public.require_admin_manager_user();

  SELECT id
  INTO v_admin_record_id
  FROM public.admin_users
  WHERE user_id = v_admin_user_id
    AND is_active = true
  LIMIT 1;

  IF p_target_user_id IS NULL THEN
    RAISE EXCEPTION 'Target user id is required';
  END IF;

  IF p_amount_fet IS NULL OR p_amount_fet <= 0 THEN
    RAISE EXCEPTION 'Adjustment amount must be greater than zero';
  END IF;

  IF v_direction NOT IN ('credit', 'debit') THEN
    RAISE EXCEPTION 'Adjustment direction must be credit or debit';
  END IF;

  IF nullif(trim(coalesce(p_reason, '')), '') IS NULL THEN
    RAISE EXCEPTION 'Adjustment reason is required';
  END IF;

  v_before := public.reconcile_fet_wallet(p_target_user_id);

  v_result := public.wallet_post_transaction(
    p_user_id => p_target_user_id,
    p_transaction_type => 'admin_adjustment',
    p_direction => v_direction,
    p_amount_fet => p_amount_fet,
    p_balance_bucket => 'available',
    p_idempotency_key => coalesce(
      p_idempotency_key,
      'admin_adjustment:' || p_target_user_id::text || ':' || extensions.gen_random_uuid()::text
    ),
    p_reference_type => 'admin_adjustment',
    p_reference_id => v_admin_user_id::text,
    p_title => CASE WHEN v_direction = 'credit' THEN 'Admin FET credit' ELSE 'Admin FET debit' END,
    p_metadata => jsonb_build_object('reason', p_reason),
    p_created_by => v_admin_user_id
  );

  v_after := public.reconcile_fet_wallet(p_target_user_id);

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
    v_admin_record_id,
    'adjust_fet_wallet',
    'wallets',
    'user',
    p_target_user_id::text,
    v_before,
    v_after,
    jsonb_build_object(
      'direction', v_direction,
      'amount_fet', p_amount_fet,
      'reason', p_reason,
      'ledger_result', v_result
    )
  );

  RETURN v_result || jsonb_build_object('before', v_before, 'after', v_after);
END;
$$;


--
-- Name: admin_ban_user(uuid, text, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_ban_user(p_target_user_id uuid, p_reason text DEFAULT 'Policy violation'::text, p_until timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admin_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    email text NOT NULL,
    display_name text DEFAULT ''::text NOT NULL,
    role text DEFAULT 'admin'::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    whatsapp_number text,
    otp_code character varying(6),
    otp_expires_at timestamp with time zone,
    otp_attempts integer DEFAULT 0,
    phone text,
    invited_by uuid,
    last_login_at timestamp with time zone,
    CONSTRAINT admin_users_role_check CHECK ((role = ANY (ARRAY['super_admin'::text, 'admin'::text, 'moderator'::text, 'viewer'::text])))
);


--
-- Name: admin_change_admin_role(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_change_admin_role(p_admin_id uuid, p_role text) RETURNS public.admin_users
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: admin_competition_distribution(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_competition_distribution(p_days integer DEFAULT 30) RETURNS TABLE(name text, value integer, color text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
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
      count(e.id)::bigint AS pool_entry_count
    FROM public.match_pool_entries e
    JOIN public.match_pools p ON p.id = e.pool_id
    JOIN public.matches m ON m.id = p.match_id
    LEFT JOIN public.competitions c ON c.id = m.competition_id
    WHERE e.created_at >= (SELECT since_at FROM cutoff)
      AND e.status <> 'cancelled'
    GROUP BY 1
  ),
  ranked AS (
    SELECT
      competition_name,
      pool_entry_count,
      row_number() OVER (ORDER BY pool_entry_count DESC, competition_name) AS rn,
      sum(pool_entry_count) OVER () AS grand_total
    FROM competition_counts
  ),
  compact AS (
    SELECT competition_name AS name, pool_entry_count, grand_total
    FROM ranked
    WHERE rn <= 4
    UNION ALL
    SELECT 'Other' AS name, sum(pool_entry_count)::bigint, max(grand_total)::bigint
    FROM ranked
    WHERE rn > 4
    HAVING sum(pool_entry_count) > 0
  )
  SELECT
    name,
    round(CASE WHEN grand_total > 0 THEN (pool_entry_count::numeric / grand_total::numeric) * 100 ELSE 0 END)::integer AS value,
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


--
-- Name: admin_credit_fet(uuid, bigint, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_credit_fet(p_target_user_id uuid, p_amount bigint, p_reason text DEFAULT 'Admin credit'::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN public.admin_adjust_fet(
    p_target_user_id => p_target_user_id,
    p_amount_fet => p_amount,
    p_direction => 'credit',
    p_reason => p_reason
  );
END;
$$;


--
-- Name: admin_curate_match(text, uuid, uuid, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_curate_match(p_match_id text, p_country_id uuid DEFAULT NULL::uuid, p_venue_id uuid DEFAULT NULL::uuid, p_priority integer DEFAULT 100, p_reason text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
  v_country_code text;
  v_curated public.curated_matches%ROWTYPE;
BEGIN
  IF NOT public.sports_bar_is_admin() THEN
    RAISE EXCEPTION 'Only admins can curate matches';
  END IF;

  IF p_country_id IS NOT NULL THEN
    SELECT iso_code INTO v_country_code
    FROM public.countries
    WHERE id = p_country_id;
  END IF;

  UPDATE public.curated_matches
  SET priority_score = p_priority,
      is_active = true,
      reason = coalesce(p_reason, ''),
      curated_by = auth.uid(),
      starts_at = coalesce(starts_at, timezone('utc', now())),
      updated_at = timezone('utc', now())
  WHERE match_id = p_match_id
    AND coalesce(country_code, '') = coalesce(v_country_code, '')
    AND coalesce(venue_id, '00000000-0000-0000-0000-000000000000'::uuid)
      = coalesce(p_venue_id, '00000000-0000-0000-0000-000000000000'::uuid)
  RETURNING * INTO v_curated;

  IF NOT FOUND THEN
    INSERT INTO public.curated_matches (
      match_id,
      country_code,
      venue_id,
      priority_score,
      is_active,
      reason,
      curated_by,
      starts_at
    )
    VALUES (
      p_match_id,
      v_country_code,
      p_venue_id,
      p_priority,
      true,
      coalesce(p_reason, ''),
      auth.uid(),
      timezone('utc', now())
    )
    RETURNING * INTO v_curated;
  END IF;

  UPDATE public.matches
  SET is_curated = true,
      country_visibility = CASE
        WHEN v_country_code IS NULL THEN country_visibility
        WHEN v_country_code = ANY(country_visibility) THEN country_visibility
        ELSE array_append(country_visibility, v_country_code)
      END,
      updated_at = timezone('utc', now())
  WHERE id = p_match_id;

  PERFORM public.sports_bar_write_audit('admin_curate_match', 'match', p_match_id, NULL, to_jsonb(v_curated));

  RETURN jsonb_build_object('status', 'curated', 'curation_id', v_curated.id, 'match_id', p_match_id);
END;
$$;


--
-- Name: admin_dashboard_kpis(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_dashboard_kpis() RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
DECLARE
  v_active_users bigint := 0;
  v_open_pools bigint := 0;
  v_total_fet_issued numeric := 0;
  v_fet_transferred_24h bigint := 0;
  v_pending_settlements bigint := 0;
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
  INTO v_open_pools
  FROM public.match_pools
  WHERE status = 'open';

  IF to_regclass('public.fet_supply_overview') IS NOT NULL THEN
    EXECUTE 'SELECT coalesce(total_supply, 0) FROM public.fet_supply_overview'
    INTO v_total_fet_issued;
  END IF;

  SELECT coalesce(sum(amount_fet)::bigint, 0)
  INTO v_fet_transferred_24h
  FROM public.fet_wallet_transactions
  WHERE direction = 'debit'
    AND tx_type IN ('transfer', 'transfer_fet', 'match_pool_entry')
    AND created_at >= timezone('utc', now()) - interval '24 hours';

  SELECT count(*)::bigint
  INTO v_pending_settlements
  FROM public.match_pools p
  JOIN public.matches m ON m.id = p.match_id
  WHERE p.status IN ('open', 'locked', 'settling')
    AND m.match_status = 'finished'
    AND m.result_code IS NOT NULL;

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
    'openPools', coalesce(v_open_pools, 0),
    'totalFetIssued', coalesce(v_total_fet_issued, 0),
    'fetTransferred24h', coalesce(v_fet_transferred_24h, 0),
    'pendingSettlements', coalesce(v_pending_settlements, 0),
    'moderationAlerts', coalesce(v_moderation_alerts, 0),
    'competitionsCount', coalesce(v_competitions_count, 0),
    'upcomingFixtures', coalesce(v_upcoming_fixtures, 0)
  );
END;
$$;


--
-- Name: admin_debit_fet(uuid, bigint, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_debit_fet(p_target_user_id uuid, p_amount bigint, p_reason text DEFAULT 'Admin debit'::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN public.admin_adjust_fet(
    p_target_user_id => p_target_user_id,
    p_amount_fet => p_amount,
    p_direction => 'debit',
    p_reason => p_reason
  );
END;
$$;


--
-- Name: admin_fet_flow_weekly(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_fet_flow_weekly(p_weeks integer DEFAULT 4) RETURNS TABLE(week text, issued bigint, transferred bigint, adjusted bigint, rewarded bigint)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
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
         AND tx.tx_type IN ('transfer', 'transfer_fet', 'match_pool_entry')
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
    coalesce(sum(
      CASE
        WHEN tx.direction = 'credit'
         AND tx.tx_type IN ('match_pool_settlement', 'match_pool_refund', 'order_reward')
          THEN tx.amount_fet
        ELSE 0
      END
    ), 0)::bigint AS rewarded
  FROM weeks w
  LEFT JOIN tx ON tx.bucket_week = w.bucket_week
  GROUP BY w.bucket_week
  ORDER BY w.bucket_week;
$$;


--
-- Name: admin_freeze_wallet(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_freeze_wallet(p_target_user_id uuid, p_reason text DEFAULT 'Suspicious activity'::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: admin_global_search(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_global_search(p_query text, p_limit integer DEFAULT 12) RETURNS TABLE(result_id text, result_type text, title text, subtitle text, route text)
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
  pool_hits AS (
    SELECT
      p.id::text AS result_id,
      'pool'::text AS result_type,
      p.title AS title,
      lower(p.status::text) || ' - ' || p.total_members::text || ' members - ' || p.total_staked_fet::text || ' FET' AS subtitle,
      '/fixtures?q=' || params.raw_query AS route,
      3 AS group_rank
    FROM public.match_pools p
    JOIN public.matches m ON m.id = p.match_id
    LEFT JOIN public.teams ht ON ht.id = m.home_team_id
    LEFT JOIN public.teams at ON at.id = m.away_team_id
    CROSS JOIN params
    WHERE
      p.id::text ILIKE params.ilike_query
      OR p.title ILIKE params.ilike_query
      OR coalesce(ht.name, m.home_team_id) ILIKE params.ilike_query
      OR coalesce(at.name, m.away_team_id) ILIKE params.ilike_query
    ORDER BY p.created_at DESC, p.id
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
    SELECT * FROM pool_hits
    UNION ALL
    SELECT * FROM competition_hits
    UNION ALL
    SELECT * FROM wallet_hits
  ) combined
  ORDER BY combined.group_rank, combined.title
  LIMIT v_limit;
END;
$$;


--
-- Name: admin_grant_access(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_grant_access(p_phone text, p_role text) RETURNS public.admin_users
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


--
-- Name: admin_log_action(text, text, text, text, jsonb, jsonb, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

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


--
-- Name: admin_pool_engagement_daily(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_pool_engagement_daily(p_days integer DEFAULT 7) RETURNS TABLE(day text, dau bigint, pool_entries bigint)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
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

    SELECT timezone('utc', e.created_at)::date AS bucket_date, e.user_id
    FROM public.match_pool_entries e

    UNION ALL

    SELECT timezone('utc', tx.created_at)::date AS bucket_date, tx.user_id
    FROM public.fet_wallet_transactions tx
  ),
  pool_counts AS (
    SELECT timezone('utc', created_at)::date AS bucket_date, count(*)::bigint AS total
    FROM public.match_pool_entries
    GROUP BY 1
  )
  SELECT
    to_char(d.bucket_date, 'Dy') AS day,
    coalesce(count(DISTINCT a.user_id), 0)::bigint AS dau,
    coalesce(max(pc.total), 0)::bigint AS pool_entries
  FROM days d
  LEFT JOIN activity a ON a.bucket_date = d.bucket_date
  LEFT JOIN pool_counts pc ON pc.bucket_date = d.bucket_date
  GROUP BY d.bucket_date
  ORDER BY d.bucket_date;
$$;


--
-- Name: admin_pool_engagement_kpis(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_pool_engagement_kpis() RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
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
    'poolEntries7d',
    coalesce((
      SELECT count(*)::bigint
      FROM public.match_pool_entries
      WHERE created_at >= timezone('utc', now()) - interval '7 days'
    ), 0),
    'fetVolume7d',
    coalesce((
      SELECT sum(amount_fet)::bigint
      FROM public.fet_wallet_transactions
      WHERE created_at >= timezone('utc', now()) - interval '7 days'
        AND tx_type IN (
          'transfer',
          'transfer_fet',
          'admin_debit',
          'match_pool_entry',
          'match_pool_settlement',
          'match_pool_refund',
          'order_reward'
        )
    ), 0)
  );
$$;


--
-- Name: admin_pool_operations_kpis(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_pool_operations_kpis() RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
DECLARE
  v_open_pools bigint := 0;
  v_locked_pools bigint := 0;
  v_settling_pools bigint := 0;
  v_settled_24h bigint := 0;
  v_failed_settlements bigint := 0;
  v_pending_final_pools bigint := 0;
  v_stale_settling_pools bigint := 0;
  v_total_open_stake bigint := 0;
  v_social_cards_missing bigint := 0;
  v_invites_7d bigint := 0;
  v_invite_rewards_7d bigint := 0;
BEGIN
  PERFORM public.require_active_admin_user();

  SELECT count(*)::bigint, coalesce(sum(total_staked_fet)::bigint, 0)
  INTO v_open_pools, v_total_open_stake
  FROM public.match_pools
  WHERE status = 'open';

  SELECT count(*)::bigint INTO v_locked_pools
  FROM public.match_pools
  WHERE status = 'locked';

  SELECT count(*)::bigint INTO v_settling_pools
  FROM public.match_pools
  WHERE status = 'settling';

  SELECT count(*)::bigint INTO v_settled_24h
  FROM public.match_pools
  WHERE status = 'settled'
    AND settled_at >= timezone('utc', now()) - interval '24 hours';

  SELECT count(*)::bigint INTO v_failed_settlements
  FROM public.match_pool_settlements
  WHERE status = 'failed';

  SELECT count(*)::bigint INTO v_pending_final_pools
  FROM public.match_pools p
  JOIN public.matches m ON m.id = p.match_id
  WHERE p.status IN ('open', 'locked', 'settling')
    AND m.match_status = 'finished'
    AND m.result_code IS NOT NULL;

  SELECT count(*)::bigint INTO v_stale_settling_pools
  FROM public.match_pools
  WHERE status = 'settling'
    AND updated_at < timezone('utc', now()) - interval '15 minutes';

  SELECT count(*)::bigint INTO v_social_cards_missing
  FROM public.match_pools
  WHERE status IN ('open', 'locked', 'settled')
    AND nullif(trim(coalesce(social_card_url, '')), '') IS NULL;

  SELECT count(*)::bigint INTO v_invites_7d
  FROM public.match_pool_invites
  WHERE created_at >= timezone('utc', now()) - interval '7 days';

  SELECT coalesce(sum(reward_amount_fet)::bigint, 0) INTO v_invite_rewards_7d
  FROM public.match_pool_invites
  WHERE status = 'rewarded'
    AND rewarded_at >= timezone('utc', now()) - interval '7 days';

  RETURN jsonb_build_object(
    'openPools', coalesce(v_open_pools, 0),
    'lockedPools', coalesce(v_locked_pools, 0),
    'settlingPools', coalesce(v_settling_pools, 0),
    'settled24h', coalesce(v_settled_24h, 0),
    'failedSettlements', coalesce(v_failed_settlements, 0),
    'pendingFinalPools', coalesce(v_pending_final_pools, 0),
    'staleSettlingPools', coalesce(v_stale_settling_pools, 0),
    'totalOpenStakeFet', coalesce(v_total_open_stake, 0),
    'socialCardsMissing', coalesce(v_social_cards_missing, 0),
    'invites7d', coalesce(v_invites_7d, 0),
    'inviteRewards7d', coalesce(v_invite_rewards_7d, 0)
  );
END;
$$;


--
-- Name: admin_pool_operations_queue(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_pool_operations_queue(p_limit integer DEFAULT 50) RETURNS TABLE(pool_id uuid, title text, scope text, venue_id uuid, venue_name text, match_id text, match_label text, competition_name text, kickoff_at timestamp with time zone, match_status text, result_code text, pool_status text, total_members bigint, total_staked_fet bigint, settlement_status text, settlement_started_at timestamp with time zone, settlement_completed_at timestamp with time zone, settlement_error text, share_url text, social_card_url text, needs_settlement boolean, needs_social_card boolean, age_minutes bigint)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
  WITH _auth AS (
    SELECT public.require_active_admin_user()
  )
  SELECT
    p.id AS pool_id,
    p.title,
    p.scope::text,
    p.venue_id,
    v.name AS venue_name,
    p.match_id,
    coalesce(m.home_team, 'Home') || ' vs ' || coalesce(m.away_team, 'Away') AS match_label,
    m.competition_name,
    m.match_date AS kickoff_at,
    coalesce(m.match_status, m.status) AS match_status,
    m.result_code,
    p.status::text AS pool_status,
    p.total_members,
    p.total_staked_fet,
    s.status::text AS settlement_status,
    s.started_at AS settlement_started_at,
    s.completed_at AS settlement_completed_at,
    s.metadata ->> 'error' AS settlement_error,
    p.share_url,
    p.social_card_url,
    (
      p.status IN ('open', 'locked', 'settling')
      AND m.match_status = 'finished'
      AND m.result_code IS NOT NULL
    ) AS needs_settlement,
    nullif(trim(coalesce(p.social_card_url, '')), '') IS NULL AS needs_social_card,
    floor(extract(epoch FROM (timezone('utc', now()) - p.created_at)) / 60)::bigint AS age_minutes
  FROM public.match_pools p
  LEFT JOIN public.app_matches m ON m.id = p.match_id
  LEFT JOIN public.venues v ON v.id = p.venue_id
  LEFT JOIN public.match_pool_settlements s ON s.pool_id = p.id
  WHERE
    p.status IN ('open', 'locked', 'settling')
    OR s.status = 'failed'
    OR p.created_at >= timezone('utc', now()) - interval '30 days'
  ORDER BY
    CASE
      WHEN s.status = 'failed' THEN 0
      WHEN p.status = 'settling' THEN 1
      WHEN p.status IN ('open', 'locked') AND m.match_status = 'finished' AND m.result_code IS NOT NULL THEN 2
      WHEN nullif(trim(coalesce(p.social_card_url, '')), '') IS NULL THEN 3
      ELSE 4
    END,
    m.match_date NULLS LAST,
    p.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 200));
$$;


--
-- Name: admin_query_daily_active_users(timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_query_daily_active_users(p_since timestamp with time zone DEFAULT (now() - '30 days'::interval), p_until timestamp with time zone DEFAULT now()) RETURNS TABLE(day date, unique_users bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: admin_query_event_counts(timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_query_event_counts(p_since timestamp with time zone DEFAULT (now() - '7 days'::interval), p_until timestamp with time zone DEFAULT now()) RETURNS TABLE(event_name text, event_count bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: admin_query_screen_views(timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_query_screen_views(p_since timestamp with time zone DEFAULT (now() - '7 days'::interval), p_until timestamp with time zone DEFAULT now()) RETURNS TABLE(screen_name text, view_count bigint, unique_viewers bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: admin_revoke_access(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_revoke_access(p_admin_id uuid) RETURNS public.admin_users
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: admin_run_pool_settlement(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_run_pool_settlement(p_limit integer DEFAULT 50) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
DECLARE
  v_user_id uuid := public.require_active_admin_user();
  v_count integer := 0;
BEGIN
  v_count := public.settle_finished_match_pools(greatest(1, least(coalesce(p_limit, 50), 250)));

  INSERT INTO public.pool_operation_audit_logs (
    actor_user_id,
    action,
    metadata
  )
  VALUES (
    v_user_id,
    'admin_run_pool_settlement',
    jsonb_build_object('limit', p_limit, 'settled_pools', v_count)
  );

  PERFORM public.admin_log_action(
    'run_pool_settlement',
    'pools',
    'match_pool_settlement_batch',
    NULL,
    NULL,
    jsonb_build_object('settled_pools', v_count),
    jsonb_build_object('limit', p_limit)
  );

  RETURN jsonb_build_object(
    'status', 'completed',
    'settled_pools', v_count,
    'limit', greatest(1, least(coalesce(p_limit, 50), 250))
  );
END;
$$;


--
-- Name: admin_set_competition_featured(text, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_set_competition_featured(p_competition_id text, p_is_featured boolean) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
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


--
-- Name: admin_set_feature_flag(text, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_set_feature_flag(p_flag_id text, p_is_enabled boolean) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
declare
  v_admin_record_id uuid;
  v_key text := split_part(coalesce(p_flag_id, ''), ':', 1);
  v_market text := coalesce(
    nullif(split_part(coalesce(p_flag_id, ''), ':', 2), ''),
    'global'
  );
  v_platform text := coalesce(
    nullif(split_part(coalesce(p_flag_id, ''), ':', 3), ''),
    'all'
  );
  v_before jsonb;
  v_after jsonb;
begin
  perform public.require_admin_manager_user();
  v_admin_record_id := public.active_admin_record_id();

  if exists (
    select 1
    from public.platform_features
    where feature_key = v_key
  ) then
    select to_jsonb(feature_row)
    into v_before
    from public.admin_platform_features feature_row
    where feature_row.feature_key = v_key;

    if v_before is null then
      raise exception 'Platform feature not found';
    end if;

    if v_platform in ('android', 'ios') then
      update public.platform_feature_channels
      set
        is_enabled = p_is_enabled,
        updated_at = timezone('utc', now())
      where feature_key = v_key
        and channel = 'mobile';
    elsif v_platform = 'web' then
      update public.platform_feature_channels
      set
        is_enabled = p_is_enabled,
        updated_at = timezone('utc', now())
      where feature_key = v_key
        and channel = 'web';
    else
      update public.platform_features
      set
        is_enabled = p_is_enabled,
        updated_at = timezone('utc', now())
      where feature_key = v_key;
    end if;

    if not found then
      raise exception 'Platform feature flag target not found';
    end if;

    select to_jsonb(feature_row)
    into v_after
    from public.admin_platform_features feature_row
    where feature_row.feature_key = v_key;

    insert into public.admin_audit_logs (
      admin_user_id,
      action,
      module,
      target_type,
      target_id,
      before_state,
      after_state,
      metadata
    ) values (
      v_admin_record_id,
      'toggle_platform_feature_flag',
      'platform-control',
      'platform_feature',
      p_flag_id,
      v_before,
      v_after,
      jsonb_build_object(
        'feature_key',
        v_key,
        'market',
        v_market,
        'platform',
        v_platform,
        'is_enabled',
        p_is_enabled
      )
    );

    return jsonb_build_object(
      'id',
      p_flag_id,
      'feature_key',
      v_key,
      'market',
      v_market,
      'platform',
      v_platform,
      'is_enabled',
      p_is_enabled,
      'source',
      'platform_features'
    );
  end if;

  select to_jsonb(flag_row)
  into v_before
  from public.admin_feature_flags flag_row
  where flag_row.id = p_flag_id;

  if v_before is null then
    raise exception 'Feature flag not found';
  end if;

  update public.feature_flags
  set
    enabled = p_is_enabled,
    updated_at = timezone('utc', now())
  where key = v_key
    and market = v_market
    and platform = v_platform;

  select to_jsonb(flag_row)
  into v_after
  from public.admin_feature_flags flag_row
  where flag_row.id = p_flag_id;

  insert into public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    before_state,
    after_state,
    metadata
  ) values (
    v_admin_record_id,
    'toggle_feature_flag',
    'settings',
    'feature_flag',
    p_flag_id,
    v_before,
    v_after,
    jsonb_build_object(
      'feature_key',
      v_key,
      'market',
      v_market,
      'platform',
      v_platform,
      'is_enabled',
      p_is_enabled
    )
  );

  return jsonb_build_object(
    'id',
    p_flag_id,
    'feature_key',
    v_key,
    'market',
    v_market,
    'platform',
    v_platform,
    'is_enabled',
    p_is_enabled,
    'source',
    'feature_flags'
  );
end;
$$;


--
-- Name: admin_set_featured_event_active(uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_set_featured_event_active(p_event_id uuid, p_is_active boolean) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
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


--
-- Name: admin_trigger_currency_rate_refresh(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_trigger_currency_rate_refresh() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: admin_unban_user(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_unban_user(p_target_user_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: admin_unfreeze_wallet(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_unfreeze_wallet(p_target_user_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: admin_update_account_deletion_request(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_update_account_deletion_request(p_request_id uuid, p_status text, p_resolution_notes text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
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


--
-- Name: admin_update_match_result(text, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_update_match_result(p_match_id text, p_home_goals integer, p_away_goals integer) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_settlement jsonb := '{}'::jsonb;
BEGIN
  IF NOT public.current_user_has_admin_role(ARRAY['moderator', 'admin', 'super_admin']) THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  UPDATE public.matches
  SET
    home_goals = p_home_goals,
    away_goals = p_away_goals,
    home_score = p_home_goals,
    away_score = p_away_goals,
    result_code = public.sports_bar_result_code(p_home_goals, p_away_goals),
    winner_camp = public.sports_bar_winner_camp(public.sports_bar_result_code(p_home_goals, p_away_goals)),
    match_status = 'finished',
    status = 'finished',
    updated_at = timezone('utc', now())
  WHERE id = p_match_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match not found';
  END IF;

  IF to_regprocedure('public.refresh_team_form_features_for_match(text)') IS NOT NULL THEN
    PERFORM public.refresh_team_form_features_for_match(p_match_id);
  END IF;

  IF to_regprocedure('public.settle_finished_match_pools(integer)') IS NOT NULL THEN
    v_settlement := public.settle_finished_match_pools(50);
  END IF;

  RETURN jsonb_build_object(
    'match_id', p_match_id,
    'home_goals', p_home_goals,
    'away_goals', p_away_goals,
    'result_code', public.sports_bar_result_code(p_home_goals, p_away_goals),
    'winner_camp', public.sports_bar_winner_camp(public.sports_bar_result_code(p_home_goals, p_away_goals)),
    'settlement', v_settlement
  );
END;
$$;


--
-- Name: admin_update_moderation_report_status(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_update_moderation_report_status(p_report_id uuid, p_status text, p_resolution_notes text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
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


--
-- Name: admin_upsert_feature_flag(text, text, text, boolean, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_upsert_feature_flag(p_key text, p_market text DEFAULT 'global'::text, p_platform text DEFAULT 'all'::text, p_enabled boolean DEFAULT true, p_description text DEFAULT NULL::text, p_rollout_pct integer DEFAULT 100) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $_$
declare
  v_admin_record_id uuid;
  v_key text := lower(trim(coalesce(p_key, '')));
  v_market text := coalesce(nullif(lower(trim(coalesce(p_market, 'global'))), ''), 'global');
  v_platform text := coalesce(nullif(lower(trim(coalesce(p_platform, 'all'))), ''), 'all');
  v_rollout_pct integer := greatest(0, least(coalesce(p_rollout_pct, 100), 100));
  v_flag_id text;
  v_before jsonb;
  v_after jsonb;
begin
  perform public.require_admin_manager_user();
  v_admin_record_id := public.active_admin_record_id();

  if v_key = '' or v_key !~ '^[a-z0-9_]+$' then
    raise exception 'Feature flag key must use lowercase snake_case';
  end if;

  if v_market = '' or v_market !~ '^[a-z_]+$' then
    raise exception 'Feature flag market must use lowercase snake_case';
  end if;

  if v_platform not in ('all', 'android', 'ios', 'web') then
    raise exception 'Invalid feature flag platform';
  end if;

  if exists (
    select 1
    from public.platform_features
    where feature_key = v_key
  ) then
    raise exception 'Feature % is managed through Platform Control', v_key;
  end if;

  v_flag_id := ((v_key || ':'::text) || v_market) || ':'::text || v_platform;

  select to_jsonb(flag_row)
  into v_before
  from public.admin_feature_flags flag_row
  where flag_row.id = v_flag_id;

  insert into public.feature_flags (
    key,
    market,
    platform,
    enabled,
    description,
    rollout_pct,
    updated_at
  ) values (
    v_key,
    v_market,
    v_platform,
    coalesce(p_enabled, true),
    nullif(trim(coalesce(p_description, '')), ''),
    v_rollout_pct,
    timezone('utc', now())
  )
  on conflict (key, market, platform) do update
  set
    enabled = excluded.enabled,
    description = excluded.description,
    rollout_pct = excluded.rollout_pct,
    updated_at = excluded.updated_at;

  select to_jsonb(flag_row)
  into v_after
  from public.admin_feature_flags flag_row
  where flag_row.id = v_flag_id;

  insert into public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    before_state,
    after_state,
    metadata
  ) values (
    v_admin_record_id,
    'upsert_feature_flag',
    'settings',
    'feature_flag',
    v_flag_id,
    v_before,
    v_after,
    jsonb_build_object(
      'feature_key',
      v_key,
      'market',
      v_market,
      'platform',
      v_platform,
      'is_enabled',
      coalesce(p_enabled, true),
      'rollout_pct',
      v_rollout_pct
    )
  );

  return coalesce(
    v_after,
    jsonb_build_object(
      'id',
      v_flag_id,
      'key',
      v_key,
      'market',
      v_market,
      'platform',
      v_platform,
      'is_enabled',
      coalesce(p_enabled, true)
    )
  );
end;
$_$;


--
-- Name: admin_upsert_platform_content_block(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_upsert_platform_content_block(p_payload jsonb) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_block_key text := lower(trim(coalesce(p_payload ->> 'block_key', '')));
  v_now timestamptz := timezone('utc', now());
begin
  if not public.is_admin_manager(auth.uid()) then
    raise exception 'Admin privileges required';
  end if;

  if v_block_key = '' then
    raise exception 'block_key is required';
  end if;

  if nullif(trim(coalesce(p_payload ->> 'title', '')), '') is null then
    raise exception 'title is required';
  end if;

  if nullif(trim(coalesce(p_payload ->> 'placement_key', '')), '') is null then
    raise exception 'placement_key is required';
  end if;

  insert into public.platform_content_blocks (
    block_key,
    block_type,
    title,
    content,
    target_channel,
    is_active,
    sort_order,
    feature_key,
    placement_key,
    metadata,
    updated_at
  )
  values (
    v_block_key,
    lower(trim(coalesce(p_payload ->> 'block_type', 'content'))),
    trim(p_payload ->> 'title'),
    coalesce(p_payload -> 'content', '{}'::jsonb),
    case lower(trim(coalesce(p_payload ->> 'target_channel', 'both')))
      when 'mobile' then 'mobile'
      when 'web' then 'web'
      else 'both'
    end,
    coalesce((p_payload ->> 'is_active')::boolean, true),
    coalesce((p_payload ->> 'sort_order')::integer, 100),
    nullif(trim(coalesce(p_payload ->> 'feature_key', '')), ''),
    lower(trim(p_payload ->> 'placement_key')),
    coalesce(p_payload -> 'metadata', '{}'::jsonb),
    v_now
  )
  on conflict (block_key) do update
  set block_type = excluded.block_type,
      title = excluded.title,
      content = excluded.content,
      target_channel = excluded.target_channel,
      is_active = excluded.is_active,
      sort_order = excluded.sort_order,
      feature_key = excluded.feature_key,
      placement_key = excluded.placement_key,
      metadata = excluded.metadata,
      updated_at = excluded.updated_at;

  return v_block_key;
end;
$$;


--
-- Name: admin_upsert_platform_feature(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_upsert_platform_feature(p_payload jsonb) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_feature_key text := lower(trim(coalesce(p_payload ->> 'feature_key', '')));
  v_now timestamptz := timezone('utc', now());
  v_mobile jsonb := coalesce(p_payload -> 'mobile_channel', '{}'::jsonb);
  v_web jsonb := coalesce(p_payload -> 'web_channel', '{}'::jsonb);
begin
  if not public.is_admin_manager(auth.uid()) then
    raise exception 'Admin privileges required';
  end if;

  if v_feature_key = '' then
    raise exception 'feature_key is required';
  end if;

  if nullif(trim(coalesce(p_payload ->> 'display_name', '')), '') is null then
    raise exception 'display_name is required';
  end if;

  if (p_payload ->> 'schedule_start_at') is not null
    and trim(p_payload ->> 'schedule_start_at') <> ''
    and (p_payload ->> 'schedule_end_at') is not null
    and trim(p_payload ->> 'schedule_end_at') <> ''
    and (p_payload ->> 'schedule_end_at')::timestamptz <= (p_payload ->> 'schedule_start_at')::timestamptz
  then
    raise exception 'schedule_end_at must be later than schedule_start_at';
  end if;

  insert into public.platform_features (
    feature_key,
    display_name,
    description,
    status,
    is_enabled,
    navigation_group,
    default_route_key,
    admin_notes,
    metadata,
    updated_at
  )
  values (
    v_feature_key,
    trim(p_payload ->> 'display_name'),
    nullif(trim(coalesce(p_payload ->> 'description', '')), ''),
    lower(trim(coalesce(p_payload ->> 'status', 'active'))),
    coalesce((p_payload ->> 'is_enabled')::boolean, true),
    nullif(trim(coalesce(p_payload ->> 'navigation_group', '')), ''),
    nullif(trim(coalesce(p_payload ->> 'default_route_key', '')), ''),
    nullif(trim(coalesce(p_payload ->> 'admin_notes', '')), ''),
    coalesce(p_payload -> 'metadata', '{}'::jsonb),
    v_now
  )
  on conflict (feature_key) do update
  set display_name = excluded.display_name,
      description = excluded.description,
      status = excluded.status,
      is_enabled = excluded.is_enabled,
      navigation_group = excluded.navigation_group,
      default_route_key = excluded.default_route_key,
      admin_notes = excluded.admin_notes,
      metadata = excluded.metadata,
      updated_at = excluded.updated_at;

  insert into public.platform_feature_rules (
    feature_key,
    auth_required,
    role_restrictions,
    dependency_config,
    rollout_config,
    schedule_start_at,
    schedule_end_at,
    metadata,
    updated_at
  )
  values (
    v_feature_key,
    coalesce((p_payload ->> 'auth_required')::boolean, false),
    coalesce(p_payload -> 'role_restrictions', '[]'::jsonb),
    coalesce(p_payload -> 'dependency_config', '{}'::jsonb),
    coalesce(p_payload -> 'rollout_config', '{}'::jsonb),
    nullif(trim(coalesce(p_payload ->> 'schedule_start_at', '')), '')::timestamptz,
    nullif(trim(coalesce(p_payload ->> 'schedule_end_at', '')), '')::timestamptz,
    coalesce(p_payload -> 'rules_metadata', '{}'::jsonb),
    v_now
  )
  on conflict (feature_key) do update
  set auth_required = excluded.auth_required,
      role_restrictions = excluded.role_restrictions,
      dependency_config = excluded.dependency_config,
      rollout_config = excluded.rollout_config,
      schedule_start_at = excluded.schedule_start_at,
      schedule_end_at = excluded.schedule_end_at,
      metadata = excluded.metadata,
      updated_at = excluded.updated_at;

  insert into public.platform_feature_channels (
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
    placement_key,
    metadata,
    updated_at
  )
  values
    (
      v_feature_key,
      'mobile',
      coalesce((v_mobile ->> 'is_visible')::boolean, true),
      coalesce((v_mobile ->> 'is_enabled')::boolean, true),
      coalesce((v_mobile ->> 'show_in_navigation')::boolean, false),
      coalesce((v_mobile ->> 'show_on_home')::boolean, false),
      coalesce((v_mobile ->> 'sort_order')::integer, 100),
      nullif(trim(coalesce(v_mobile ->> 'route_key', '')), ''),
      nullif(trim(coalesce(v_mobile ->> 'entry_key', '')), ''),
      nullif(trim(coalesce(v_mobile ->> 'navigation_label', '')), ''),
      nullif(trim(coalesce(v_mobile ->> 'placement_key', '')), ''),
      coalesce(v_mobile -> 'metadata', '{}'::jsonb),
      v_now
    ),
    (
      v_feature_key,
      'web',
      coalesce((v_web ->> 'is_visible')::boolean, true),
      coalesce((v_web ->> 'is_enabled')::boolean, true),
      coalesce((v_web ->> 'show_in_navigation')::boolean, false),
      coalesce((v_web ->> 'show_on_home')::boolean, false),
      coalesce((v_web ->> 'sort_order')::integer, 100),
      nullif(trim(coalesce(v_web ->> 'route_key', '')), ''),
      nullif(trim(coalesce(v_web ->> 'entry_key', '')), ''),
      nullif(trim(coalesce(v_web ->> 'navigation_label', '')), ''),
      nullif(trim(coalesce(v_web ->> 'placement_key', '')), ''),
      coalesce(v_web -> 'metadata', '{}'::jsonb),
      v_now
    )
  on conflict (feature_key, channel) do update
  set is_visible = excluded.is_visible,
      is_enabled = excluded.is_enabled,
      show_in_navigation = excluded.show_in_navigation,
      show_on_home = excluded.show_on_home,
      sort_order = excluded.sort_order,
      route_key = excluded.route_key,
      entry_key = excluded.entry_key,
      navigation_label = excluded.navigation_label,
      placement_key = excluded.placement_key,
      metadata = excluded.metadata,
      updated_at = excluded.updated_at;

  return v_feature_key;
end;
$$;


--
-- Name: seasons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.seasons (
    id text NOT NULL,
    competition_id text NOT NULL,
    season_label text NOT NULL,
    start_year integer NOT NULL,
    end_year integer NOT NULL,
    is_current boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT seasons_year_range CHECK ((end_year >= start_year))
);


--
-- Name: standings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.standings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    competition_id text NOT NULL,
    season_id text NOT NULL,
    snapshot_type text DEFAULT 'current'::text NOT NULL,
    snapshot_date date DEFAULT CURRENT_DATE NOT NULL,
    team_id text NOT NULL,
    "position" integer NOT NULL,
    played integer DEFAULT 0 NOT NULL,
    wins integer DEFAULT 0 NOT NULL,
    draws integer DEFAULT 0 NOT NULL,
    losses integer DEFAULT 0 NOT NULL,
    goals_for integer DEFAULT 0 NOT NULL,
    goals_against integer DEFAULT 0 NOT NULL,
    goal_difference integer DEFAULT 0 NOT NULL,
    points integer DEFAULT 0 NOT NULL,
    source_name text DEFAULT 'manual'::text NOT NULL,
    source_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT standings_draws_check CHECK ((draws >= 0)),
    CONSTRAINT standings_losses_check CHECK ((losses >= 0)),
    CONSTRAINT standings_played_check CHECK ((played >= 0)),
    CONSTRAINT standings_position_check CHECK (("position" > 0)),
    CONSTRAINT standings_snapshot_type_check CHECK ((snapshot_type = ANY (ARRAY['current'::text, 'matchday'::text, 'final'::text, 'historical'::text]))),
    CONSTRAINT standings_wins_check CHECK ((wins >= 0))
);


--
-- Name: teams; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.teams (
    id text NOT NULL,
    name text NOT NULL,
    short_name text,
    country text,
    competition_ids text[] DEFAULT '{}'::text[],
    aliases text[] DEFAULT '{}'::text[],
    created_at timestamp with time zone DEFAULT now(),
    country_code text,
    league_name text,
    logo_url text,
    crest_url text,
    search_terms text[] DEFAULT '{}'::text[],
    is_active boolean DEFAULT true,
    is_featured boolean DEFAULT false,
    is_popular_pick boolean DEFAULT false,
    popular_pick_rank integer,
    updated_at timestamp with time zone DEFAULT now(),
    region text,
    description text,
    cover_image_url text,
    fan_count integer DEFAULT 0 NOT NULL,
    team_type text DEFAULT 'club'::text NOT NULL,
    country_id uuid,
    popularity_score integer DEFAULT 0 NOT NULL,
    CONSTRAINT teams_popularity_score_check CHECK ((popularity_score >= 0))
);


--
-- Name: competition_standings; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.competition_standings AS
 SELECT st.id,
    st.competition_id,
    st.season_id,
    s.season_label AS season,
    st.snapshot_type,
    st.snapshot_date,
    st.team_id,
    t.name AS team_name,
    st."position",
    st.played,
    st.wins AS won,
    st.draws AS drawn,
    st.losses AS lost,
    st.goals_for,
    st.goals_against,
    st.goal_difference,
    st.points,
    st.source_name,
    st.source_url,
    st.created_at,
    st.updated_at
   FROM ((public.standings st
     JOIN public.teams t ON ((t.id = st.team_id)))
     JOIN public.seasons s ON ((s.id = st.season_id)));


--
-- Name: app_competition_standings(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.app_competition_standings(p_competition_id text, p_season text DEFAULT NULL::text) RETURNS SETOF public.competition_standings
    LANGUAGE sql STABLE
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


--
-- Name: app_config_bigint(text, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.app_config_bigint(p_key text, p_default bigint DEFAULT NULL::bigint) RETURNS bigint
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: app_config_numeric(text, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.app_config_numeric(p_key text, p_default numeric DEFAULT NULL::numeric) RETURNS numeric
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
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

  RETURN v_text::numeric;
EXCEPTION
  WHEN invalid_text_representation OR numeric_value_out_of_range THEN
    RETURN p_default;
END;
$$;


--
-- Name: apply_match_result_code(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.apply_match_result_code() RETURNS trigger
    LANGUAGE plpgsql
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


--
-- Name: assert_fet_mint_within_cap(bigint, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.assert_fet_mint_within_cap(p_amount bigint, p_context text DEFAULT 'FET mint'::text) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: assert_platform_feature_available(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.assert_platform_feature_available(p_feature_key text, p_channel text DEFAULT 'web'::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_state jsonb;
begin
  v_state := public.resolve_platform_feature(
    p_feature_key,
    p_channel,
    auth.uid() is not null
  );

  if coalesce((v_state ->> 'exists')::boolean, false) = false then
    raise exception 'Unknown feature %', p_feature_key;
  end if;

  if coalesce((v_state ->> 'is_operational')::boolean, false) = false then
    raise exception 'Feature % is currently disabled', p_feature_key;
  end if;

  if coalesce((v_state ->> 'roles_allowed')::boolean, true) = false then
    raise exception 'Feature % is not allowed for the current role', p_feature_key;
  end if;

  if coalesce((v_state ->> 'auth_required')::boolean, false) = true
    and auth.uid() is null
  then
    raise exception 'Authentication required for feature %', p_feature_key;
  end if;
end;
$$;


--
-- Name: assert_verified_account_required(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.assert_verified_account_required(p_message text DEFAULT 'Phone verification required'::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_message text := coalesce(
    nullif(btrim(p_message), ''),
    'Phone verification required'
  );
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if public.current_session_is_anonymous() then
    raise exception '%', v_message;
  end if;
end;
$$;


--
-- Name: assert_wallet_available(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.assert_wallet_available(p_user_id uuid) RETURNS void
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: assign_profile_fan_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.assign_profile_fan_id() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: audit_wallet_bootstrap_gaps(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.audit_wallet_bootstrap_gaps() RETURNS TABLE(user_id uuid, available_balance_fet bigint, locked_balance_fet bigint, welcome_bonus_amount bigint, non_bonus_transaction_count bigint, expected_bootstrap_balance bigint)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: auth_user_auth_method(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.auth_user_auth_method(p_user_id uuid) RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
  select coalesce(
    (
      select case
        when nullif(u.raw_app_meta_data ->> 'provider', '') = 'anonymous'
          then 'anonymous'
        when nullif(u.phone, '') is not null
          then 'phone'
        when nullif(u.email, '') is not null
          then coalesce(nullif(u.raw_app_meta_data ->> 'provider', ''), 'email')
        else nullif(u.raw_app_meta_data ->> 'provider', '')
      end
      from auth.users u
      where u.id = p_user_id
    ),
    'phone'
  );
$$;


--
-- Name: auth_user_is_anonymous(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.auth_user_is_anonymous(p_user_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
  select coalesce(
    (
      select case
        when nullif(u.raw_app_meta_data ->> 'provider', '') = 'anonymous'
          then true
        else false
      end
      from auth.users u
      where u.id = p_user_id
    ),
    false
  );
$$;


--
-- Name: check_rate_limit(uuid, text, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_rate_limit(p_user_id uuid, p_action text, p_max_count integer, p_window_hours integer DEFAULT 1) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: check_rate_limit(uuid, text, integer, interval); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_rate_limit(p_user_id uuid, p_action text, p_max_count integer, p_window interval) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: cleanup_expired_otps(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cleanup_expired_otps() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: cleanup_rate_limits(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cleanup_rate_limits() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  DELETE FROM public.rate_limits
  WHERE created_at < now() - interval '24 hours';
END;
$$;


--
-- Name: competition_catalog_rank(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.competition_catalog_rank(p_competition_id text, p_competition_name text DEFAULT NULL::text) RETURNS integer
    LANGUAGE sql IMMUTABLE
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


--
-- Name: generate_fan_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_fan_id() RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN public.generate_profile_fan_id(gen_random_uuid()::text);
END;
$$;


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    username text,
    full_name text,
    avatar_url text,
    favorite_malta_team text,
    favorite_euro_team text,
    fan_level integer DEFAULT 1,
    fan_tier text DEFAULT 'Bronze'::text,
    active_country text DEFAULT 'MT'::text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    user_id uuid NOT NULL,
    fan_id text DEFAULT public.generate_fan_id() NOT NULL,
    display_name text,
    favorite_team_id text,
    favorite_team_name text,
    country_code text DEFAULT '+356'::text,
    phone_number text,
    onboarding_completed boolean DEFAULT false NOT NULL,
    currency_code text,
    region text,
    allow_fan_discovery boolean DEFAULT false NOT NULL,
    is_anonymous boolean DEFAULT false NOT NULL,
    auth_method text DEFAULT 'phone'::text NOT NULL,
    upgraded_from_anonymous_id uuid,
    show_name_in_pool_activity boolean DEFAULT false,
    CONSTRAINT profiles_display_name_length CHECK (((display_name IS NULL) OR ((char_length(TRIM(BOTH FROM display_name)) >= 3) AND (char_length(TRIM(BOTH FROM display_name)) <= 24)))),
    CONSTRAINT profiles_fan_id_six_digits CHECK ((fan_id ~ '^\d{6}$'::text))
);


--
-- Name: COLUMN profiles.region; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.profiles.region IS 'Inferred user region: global, africa, europe, americas';


--
-- Name: COLUMN profiles.allow_fan_discovery; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.profiles.allow_fan_discovery IS 'Reserved preference for privacy-safe fan discovery if that feature is enabled later.';


--
-- Name: complete_user_onboarding(text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.complete_user_onboarding(p_display_name text, p_favorite_team_id text, p_favorite_team_name text, p_country_code text DEFAULT '+356'::text) RETURNS public.profiles
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: compute_result_code(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.compute_result_code(p_home_goals integer, p_away_goals integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE
    WHEN p_home_goals IS NULL OR p_away_goals IS NULL THEN NULL
    WHEN p_home_goals > p_away_goals THEN 'H'
    WHEN p_home_goals < p_away_goals THEN 'A'
    ELSE 'D'
  END;
$$;


--
-- Name: create_match_pool(text, public.match_pool_scope, text, uuid, text, bigint, bigint, bigint, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_match_pool(p_match_id text, p_scope public.match_pool_scope DEFAULT 'global'::public.match_pool_scope, p_country_code text DEFAULT NULL::text, p_venue_id uuid DEFAULT NULL::uuid, p_title text DEFAULT NULL::text, p_entry_fee_fet bigint DEFAULT 1, p_stake_min_fet bigint DEFAULT 1, p_stake_max_fet bigint DEFAULT 100000, p_is_official boolean DEFAULT true) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $_$
DECLARE
  v_user_id uuid := auth.uid();
  v_match public.matches%ROWTYPE;
  v_pool public.match_pools%ROWTYPE;
  v_home_team text := 'Home';
  v_away_team text := 'Away';
  v_is_admin boolean := false;
  v_is_venue_manager boolean := false;
  v_venue_features jsonb := '{}'::jsonb;
  v_allow_user_pool boolean := false;
  v_allow_user_official_pool boolean := false;
  v_country_code text := upper(nullif(trim(p_country_code), ''));
  v_guest_daily_limit integer := 3;
  v_guest_match_limit integer := 1;
  v_guest_entry_cap bigint := 500;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_match
  FROM public.matches
  WHERE id = p_match_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match not found';
  END IF;

  IF p_entry_fee_fet < 0 OR p_stake_min_fet < 0 OR p_stake_max_fet < p_stake_min_fet THEN
    RAISE EXCEPTION 'Invalid stake rules';
  END IF;

  IF p_entry_fee_fet > 0 AND (p_entry_fee_fet < p_stake_min_fet OR p_entry_fee_fet > p_stake_max_fet) THEN
    RAISE EXCEPTION 'Fixed entry fee must be inside min/max stake bounds';
  END IF;

  v_is_admin := public.is_admin_manager(v_user_id);

  IF p_scope = 'global' THEN
    IF NOT v_is_admin THEN
      RAISE EXCEPTION 'Only platform admins can create global pools';
    END IF;
    v_country_code := NULL;
    p_venue_id := NULL;
  ELSIF p_scope = 'country' THEN
    IF v_country_code IS NULL OR v_country_code !~ '^[A-Z]{2}$' THEN
      RAISE EXCEPTION 'A valid country code is required for country pools';
    END IF;
    IF NOT v_is_admin THEN
      RAISE EXCEPTION 'Only platform admins can create country pools';
    END IF;
    p_venue_id := NULL;
  ELSIF p_scope = 'venue' THEN
    IF p_venue_id IS NULL THEN
      RAISE EXCEPTION 'Venue id is required for venue pools';
    END IF;

    SELECT coalesce(features_json, '{}'::jsonb)
    INTO v_venue_features
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
    v_allow_user_pool := lower(coalesce(v_venue_features ->> 'allow_user_pool_creation', 'false')) IN ('true', '1', 'yes', 'on');
    v_allow_user_official_pool := lower(coalesce(v_venue_features ->> 'allow_user_official_pool_creation', 'false')) IN ('true', '1', 'yes', 'on');
    v_guest_daily_limit := CASE
      WHEN coalesce(v_venue_features ->> 'guest_pool_daily_limit', '') ~ '^[0-9]+$'
        THEN greatest(0, least((v_venue_features ->> 'guest_pool_daily_limit')::integer, 25))
      ELSE 3
    END;
    v_guest_match_limit := CASE
      WHEN coalesce(v_venue_features ->> 'guest_pool_match_limit', '') ~ '^[0-9]+$'
        THEN greatest(0, least((v_venue_features ->> 'guest_pool_match_limit')::integer, 5))
      ELSE 1
    END;
    v_guest_entry_cap := CASE
      WHEN coalesce(v_venue_features ->> 'guest_pool_entry_cap_fet', '') ~ '^[0-9]+$'
        THEN greatest(1, least((v_venue_features ->> 'guest_pool_entry_cap_fet')::bigint, 100000))
      ELSE 500
    END;

    IF NOT v_is_admin AND NOT EXISTS (
      SELECT 1
      FROM public.curated_matches cm
      WHERE cm.match_id = p_match_id
        AND cm.is_active = true
        AND (cm.starts_at IS NULL OR cm.starts_at <= timezone('utc', now()))
        AND (cm.expires_at IS NULL OR cm.expires_at > timezone('utc', now()))
        AND (cm.venue_id = p_venue_id OR cm.venue_id IS NULL)
    ) THEN
      RAISE EXCEPTION 'This match has not been curated for venue pool creation';
    END IF;

    IF p_is_official AND NOT (v_is_admin OR v_is_venue_manager OR v_allow_user_official_pool) THEN
      RAISE EXCEPTION 'Only venue managers or admins can create official venue pools';
    END IF;

    IF NOT p_is_official AND NOT (v_is_admin OR v_is_venue_manager OR v_allow_user_pool) THEN
      RAISE EXCEPTION 'This venue has not enabled guest-created linked pools';
    END IF;

    IF NOT p_is_official AND NOT (v_is_admin OR v_is_venue_manager) THEN
      IF v_guest_daily_limit <= 0 OR v_guest_match_limit <= 0 THEN
        RAISE EXCEPTION 'Guest-created linked pools are currently limited for this venue';
      END IF;

      IF p_entry_fee_fet > v_guest_entry_cap OR p_stake_max_fet > v_guest_entry_cap THEN
        RAISE EXCEPTION 'Guest-created pool stake rules exceed this venue''s configured limit';
      END IF;

      IF (
        SELECT count(*)::integer
        FROM public.match_pools p
        WHERE p.creator_user_id = v_user_id
          AND p.venue_id = p_venue_id
          AND p.scope = 'venue'
          AND p.is_official = false
          AND p.status <> 'cancelled'
          AND p.created_at >= timezone('utc', now()) - interval '24 hours'
      ) >= v_guest_daily_limit THEN
        RAISE EXCEPTION 'Daily guest-created pool limit reached for this venue';
      END IF;

      IF (
        SELECT count(*)::integer
        FROM public.match_pools p
        WHERE p.creator_user_id = v_user_id
          AND p.venue_id = p_venue_id
          AND p.match_id = p_match_id
          AND p.scope = 'venue'
          AND p.is_official = false
          AND p.status <> 'cancelled'
      ) >= v_guest_match_limit THEN
        RAISE EXCEPTION 'Guest-created pool limit reached for this match at this venue';
      END IF;
    END IF;
  END IF;

  SELECT home_team, away_team
  INTO v_home_team, v_away_team
  FROM public.app_matches
  WHERE id = p_match_id;

  INSERT INTO public.match_pools (
    match_id,
    scope,
    country_code,
    venue_id,
    creator_user_id,
    title,
    entry_fee_fet,
    stake_min_fet,
    stake_max_fet,
    is_official
  )
  VALUES (
    p_match_id,
    p_scope,
    v_country_code,
    p_venue_id,
    v_user_id,
    coalesce(nullif(trim(p_title), ''), coalesce(v_home_team, 'Home') || ' vs ' || coalesce(v_away_team, 'Away')),
    p_entry_fee_fet,
    p_stake_min_fet,
    p_stake_max_fet,
    p_is_official
  )
  RETURNING * INTO v_pool;

  UPDATE public.match_pools
  SET share_url = '/pools/' || v_pool.share_slug
  WHERE id = v_pool.id
  RETURNING * INTO v_pool;

  INSERT INTO public.match_pool_camps (pool_id, code, label, result_code, display_order)
  VALUES
    (v_pool.id, 'home', coalesce(v_home_team, 'Home'), 'H', 10),
    (v_pool.id, 'draw', 'Draw', 'D', 20),
    (v_pool.id, 'away', coalesce(v_away_team, 'Away'), 'A', 30);

  RETURN jsonb_build_object(
    'status', 'created',
    'pool_id', v_pool.id,
    'match_id', v_pool.match_id,
    'scope', v_pool.scope,
    'venue_id', v_pool.venue_id,
    'share_url', v_pool.share_url
  );
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'An official venue pool already exists for this match';
END;
$_$;


--
-- Name: create_match_pool_invite(uuid, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_match_pool_invite(p_pool_id uuid, p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_pool public.match_pools%ROWTYPE;
  v_invite public.match_pool_invites%ROWTYPE;
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

  IF coalesce(v_pool.creator_reward_fet, 0) <= 0 THEN
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
    coalesce(v_pool.creator_user_id, v_user_id),
    p_expires_at,
    jsonb_build_object('created_by', v_user_id)
  )
  RETURNING * INTO v_invite;

  RETURN jsonb_build_object(
    'status', 'created',
    'invite_id', v_invite.id,
    'pool_id', v_invite.pool_id,
    'invite_code', v_invite.invite_code,
    'share_url', coalesce(v_pool.share_url, '/pools/' || v_pool.share_slug) || '?invite=' || v_invite.invite_code,
    'expires_at', v_invite.expires_at
  );
END;
$$;


--
-- Name: create_pool(text, text, uuid, uuid, text, bigint, bigint, bigint, jsonb, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_pool(p_match_id text, p_scope text DEFAULT 'global'::text, p_country_id uuid DEFAULT NULL::uuid, p_venue_id uuid DEFAULT NULL::uuid, p_title text DEFAULT NULL::text, p_stake_min bigint DEFAULT 1, p_stake_max bigint DEFAULT 100000, p_creator_reward_per_qualified_member bigint DEFAULT NULL::bigint, p_rules_json jsonb DEFAULT '{}'::jsonb, p_allow_multiple boolean DEFAULT false) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
  v_country_code text;
  v_result jsonb;
  v_pool_id uuid;
BEGIN
  IF p_scope NOT IN ('global', 'country', 'venue') THEN
    RAISE EXCEPTION 'Invalid pool scope';
  END IF;

  IF p_country_id IS NOT NULL THEN
    SELECT iso_code INTO v_country_code
    FROM public.countries
    WHERE id = p_country_id
      AND is_active = true;

    IF v_country_code IS NULL THEN
      RAISE EXCEPTION 'Active country not found';
    END IF;
  END IF;

  v_result := public.create_match_pool(
    p_match_id => p_match_id,
    p_scope => p_scope::public.match_pool_scope,
    p_country_code => v_country_code,
    p_venue_id => p_venue_id,
    p_title => p_title,
    p_entry_fee_fet => 0,
    p_stake_min_fet => p_stake_min,
    p_stake_max_fet => p_stake_max,
    p_is_official => true
  );

  v_pool_id := (v_result ->> 'pool_id')::uuid;

  UPDATE public.match_pools
  SET country_id = p_country_id,
      creator_reward_fet = coalesce(p_creator_reward_per_qualified_member, creator_reward_fet),
      rules_json = coalesce(p_rules_json, '{}'::jsonb) || jsonb_build_object('allow_multiple', p_allow_multiple),
      allow_multiple = p_allow_multiple
  WHERE id = v_pool_id;

  PERFORM public.sports_bar_write_audit(
    'create_pool',
    'pool',
    v_pool_id::text,
    NULL,
    (SELECT to_jsonb(p) FROM public.match_pools p WHERE p.id = v_pool_id)
  );

  RETURN v_result || jsonb_build_object('country_id', p_country_id);
END;
$$;


--
-- Name: create_venue_official_match_pool(uuid, text, text, bigint, bigint, bigint, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_venue_official_match_pool(p_venue_id uuid, p_match_id text, p_title text DEFAULT NULL::text, p_entry_fee_fet bigint DEFAULT 1, p_stake_min_fet bigint DEFAULT 1, p_stake_max_fet bigint DEFAULT 100000, p_creator_reward_fet bigint DEFAULT 1) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_result jsonb;
  v_pool_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT public.venue_user_has_role(
    p_venue_id,
    ARRAY['owner', 'manager']::public.venue_user_role[]
  ) THEN
    RAISE EXCEPTION 'Only venue owners or managers can create official pools';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.curated_matches cm
    WHERE cm.match_id = p_match_id
      AND cm.is_active = true
      AND (cm.starts_at IS NULL OR cm.starts_at <= timezone('utc', now()))
      AND (cm.expires_at IS NULL OR cm.expires_at > timezone('utc', now()))
      AND (cm.venue_id = p_venue_id OR cm.venue_id IS NULL)
  ) THEN
    RAISE EXCEPTION 'This match has not been curated for venue pool creation';
  END IF;

  v_result := public.create_match_pool(
    p_match_id,
    'venue'::public.match_pool_scope,
    NULL,
    p_venue_id,
    p_title,
    p_entry_fee_fet,
    p_stake_min_fet,
    p_stake_max_fet,
    true
  );

  v_pool_id := (v_result ->> 'pool_id')::uuid;

  UPDATE public.match_pools
  SET creator_reward_fet = greatest(coalesce(p_creator_reward_fet, 1), 0),
      creator_reward_rules = creator_reward_rules
        || jsonb_build_object(
          'status', 'active',
          'requires_invite', true,
          'requires_paid_entry', true,
          'reward_source', 'match_pool_invites'
        ),
      updated_at = timezone('utc', now())
  WHERE id = v_pool_id;

  RETURN v_result || jsonb_build_object(
    'creator_reward_fet', greatest(coalesce(p_creator_reward_fet, 1), 0)
  );
END;
$$;


--
-- Name: credit_fet_for_order(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.credit_fet_for_order(p_order_id uuid, p_idempotency_key text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
DECLARE
  v_order public.orders%ROWTYPE;
  v_config jsonb;
  v_reward_percent numeric;
  v_reward_trigger text;
  v_fet_per_eur numeric := greatest(public.app_config_numeric('fet_per_eur', 100), 1);
  v_rwf_per_eur numeric := greatest(public.app_config_numeric('rwf_per_eur', 1500), 1);
  v_order_eur numeric := 0;
  v_weighted_reward_eur numeric := 0;
  v_amount bigint := 0;
BEGIN
  SELECT *
  INTO v_order
  FROM public.orders
  WHERE id = p_order_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF v_order.status::text = 'cancelled'
     OR v_order.payment_status::text IN ('cancelled', 'refunded', 'failed') THEN
    RETURN jsonb_build_object('status', 'skipped', 'reason', 'order_not_valid', 'order_id', p_order_id);
  END IF;

  v_config := public.get_venue_fet_reward_config(v_order.venue_id);
  v_reward_percent := greatest(coalesce((v_config ->> 'reward_percent')::numeric, 0), 0);
  v_reward_trigger := coalesce(v_config ->> 'reward_trigger', 'paid');

  IF v_reward_trigger = 'paid' AND v_order.payment_status::text <> 'paid' THEN
    RETURN jsonb_build_object('status', 'skipped', 'reason', 'order_not_paid', 'order_id', p_order_id);
  END IF;

  IF v_reward_trigger = 'served' AND v_order.status::text <> 'served' THEN
    RETURN jsonb_build_object('status', 'skipped', 'reason', 'order_not_served', 'order_id', p_order_id);
  END IF;

  SELECT coalesce(sum(
    (CASE
      WHEN oi.currency_code = 'RWF' THEN oi.line_total / v_rwf_per_eur
      ELSE oi.line_total
    END)
    *
    coalesce(
      CASE
        WHEN (mi.metadata ->> 'fet_reward_percent') ~ '^[0-9]+(\.[0-9]+)?$'
          THEN (mi.metadata ->> 'fet_reward_percent')::numeric
        ELSE NULL
      END,
      v_reward_percent
    )
  ), 0)
  INTO v_weighted_reward_eur
  FROM public.order_items oi
  LEFT JOIN public.menu_items mi ON mi.id = oi.menu_item_id
  WHERE oi.order_id = p_order_id;

  IF v_weighted_reward_eur = 0 THEN
    v_order_eur := CASE
      WHEN v_order.currency_code = 'RWF' THEN v_order.total_amount / v_rwf_per_eur
      ELSE v_order.total_amount
    END;
    v_weighted_reward_eur := v_order_eur * v_reward_percent;
  END IF;

  v_amount := floor((v_weighted_reward_eur * v_fet_per_eur) / 100)::bigint;

  IF v_amount <= 0 THEN
    RETURN jsonb_build_object('status', 'skipped', 'reason', 'zero_reward', 'order_id', p_order_id);
  END IF;

  RETURN public.wallet_post_transaction(
    p_user_id => v_order.user_id,
    p_transaction_type => 'order_earn',
    p_direction => 'credit',
    p_amount_fet => v_amount,
    p_balance_bucket => 'available',
    p_idempotency_key => coalesce(p_idempotency_key, 'order_earn:' || p_order_id::text),
    p_reference_type => 'order',
    p_reference_id => p_order_id::text,
    p_title => 'FET earned from bar order',
    p_metadata => jsonb_build_object(
      'order_code', v_order.order_code,
      'reward_percent', v_reward_percent,
      'reward_trigger', v_reward_trigger,
      'currency_code', v_order.currency_code,
      'total_amount', v_order.total_amount
    ),
    p_order_id => p_order_id,
    p_venue_id => v_order.venue_id
  );
END;
$_$;


--
-- Name: credit_fet_for_order(uuid, uuid, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.credit_fet_for_order(p_user_id uuid, p_order_id uuid, p_amount bigint) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_order public.orders%ROWTYPE;
BEGIN
  IF p_user_id IS NULL OR p_order_id IS NULL THEN
    RAISE EXCEPTION 'User id and order id are required';
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be positive';
  END IF;

  SELECT *
  INTO v_order
  FROM public.orders
  WHERE id = p_order_id
    AND user_id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found for user';
  END IF;

  IF v_order.status::text = 'cancelled'
     OR v_order.payment_status::text IN ('cancelled', 'refunded', 'failed') THEN
    RAISE EXCEPTION 'Order is not eligible for FET rewards';
  END IF;

  RETURN public.wallet_post_transaction(
    p_user_id => p_user_id,
    p_transaction_type => 'order_earn',
    p_direction => 'credit',
    p_amount_fet => p_amount,
    p_balance_bucket => 'available',
    p_idempotency_key => 'order_earn:' || p_order_id::text,
    p_reference_type => 'order',
    p_reference_id => p_order_id::text,
    p_title => 'FET earned from bar order',
    p_metadata => jsonb_build_object('manual_amount_override', true),
    p_order_id => p_order_id,
    p_venue_id => v_order.venue_id
  );
END;
$$;


--
-- Name: credit_order_fet(uuid, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.credit_order_fet(p_order_id uuid, p_amount bigint DEFAULT NULL::bigint) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
  v_order public.orders%ROWTYPE;
  v_percent numeric := 0;
  v_amount bigint;
  v_wallet_id uuid;
  v_before bigint;
BEGIN
  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF v_order.payment_status::text NOT IN ('paid', 'partially_paid') THEN
    RAISE EXCEPTION 'Order must be paid before FET can be credited';
  END IF;

  SELECT coalesce(rr.order_fet_default_percent, v.fet_reward_percent, 0)
  INTO v_percent
  FROM public.venues v
  LEFT JOIN LATERAL (
    SELECT order_fet_default_percent
    FROM public.reward_rules rr
    WHERE rr.is_active = true
      AND (rr.starts_at IS NULL OR rr.starts_at <= timezone('utc', now()))
      AND (rr.ends_at IS NULL OR rr.ends_at > timezone('utc', now()))
      AND (
        (rr.scope = 'venue' AND rr.venue_id = v.id)
        OR (rr.scope = 'country' AND rr.country_id = v.country_id)
        OR rr.scope = 'platform'
      )
    ORDER BY CASE rr.scope WHEN 'venue' THEN 1 WHEN 'country' THEN 2 ELSE 3 END
    LIMIT 1
  ) rr ON true
  WHERE v.id = v_order.venue_id;

  v_amount := coalesce(p_amount, floor(v_order.total_amount * coalesce(v_percent, 0) / 100)::bigint);

  IF v_amount <= 0 THEN
    RETURN jsonb_build_object('status', 'skipped', 'reason', 'zero_reward', 'order_id', p_order_id);
  END IF;

  INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
  VALUES (v_order.user_id, 0, 0)
  ON CONFLICT (user_id) DO NOTHING;

  SELECT id, available_balance_fet
  INTO v_wallet_id, v_before
  FROM public.fet_wallets
  WHERE user_id = v_order.user_id
  FOR UPDATE;

  UPDATE public.fet_wallets
  SET available_balance_fet = available_balance_fet + v_amount,
      updated_at = timezone('utc', now())
  WHERE user_id = v_order.user_id;

  UPDATE public.orders
  SET fet_earned = fet_earned + v_amount,
      updated_at = timezone('utc', now())
  WHERE id = p_order_id;

  INSERT INTO public.fet_wallet_transactions (
    wallet_id,
    user_id,
    tx_type,
    direction,
    amount_fet,
    balance_before_fet,
    balance_after_fet,
    reference_type,
    reference_id,
    source,
    order_id,
    venue_id,
    title,
    metadata
  )
  VALUES (
    v_wallet_id,
    v_order.user_id,
    'order_earn',
    'credit',
    v_amount,
    coalesce(v_before, 0),
    coalesce(v_before, 0) + v_amount,
    'order',
    p_order_id::text,
    'order_earn',
    p_order_id,
    v_order.venue_id,
    'FET earned from venue order',
    jsonb_build_object('reward_percent', v_percent)
  );

  RETURN jsonb_build_object('status', 'credited', 'order_id', p_order_id, 'amount', v_amount);
END;
$$;


--
-- Name: credit_welcome_fet(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.credit_welcome_fet(p_user_id uuid DEFAULT NULL::uuid, p_idempotency_key text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id uuid := coalesce(p_user_id, auth.uid());
  v_amount bigint := greatest(
    coalesce(
      public.app_config_bigint('welcome_credit_fet', NULL),
      public.app_config_bigint('foundation_grant_fet', 50),
      50
    ),
    0
  );
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF v_amount = 0 THEN
    PERFORM public.reconcile_fet_wallet(v_user_id);
    RETURN jsonb_build_object('status', 'skipped', 'reason', 'welcome_credit_disabled');
  END IF;

  RETURN public.wallet_post_transaction(
    p_user_id => v_user_id,
    p_transaction_type => 'welcome_credit',
    p_direction => 'credit',
    p_amount_fet => v_amount,
    p_balance_bucket => 'available',
    p_idempotency_key => coalesce(p_idempotency_key, 'welcome_credit:' || v_user_id::text),
    p_reference_type => 'welcome_credit',
    p_reference_id => v_user_id::text,
    p_title => 'Welcome FET',
    p_metadata => jsonb_build_object('credited_once', true)
  );
END;
$$;


--
-- Name: current_session_is_anonymous(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.current_session_is_anonymous() RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  select coalesce(
    nullif(auth.jwt() ->> 'is_anonymous', '')::boolean,
    case
      when auth.jwt() -> 'app_metadata' ->> 'provider' = 'anonymous'
        then true
      else null
    end,
    public.auth_user_is_anonymous(auth.uid()),
    false
  );
$$;


--
-- Name: current_user_has_admin_role(text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.current_user_has_admin_role(p_roles text[] DEFAULT ARRAY['moderator'::text, 'admin'::text, 'super_admin'::text]) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.admin_users
    WHERE user_id = auth.uid()
      AND is_active = true
      AND role = ANY (p_roles)
  );
$$;


--
-- Name: current_user_platform_roles(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.current_user_platform_roles() RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_claims_raw text := nullif(current_setting('request.jwt.claims', true), '');
  v_claims jsonb := '{}'::jsonb;
  v_roles text[] := array[]::text[];
  v_role text;
begin
  if v_claims_raw is not null then
    begin
      v_claims := v_claims_raw::jsonb;
    exception
      when others then
        v_claims := '{}'::jsonb;
    end;
  end if;

  if v_user_id is null then
    v_roles := array_append(v_roles, 'anonymous');
  else
    v_roles := array_append(v_roles, 'authenticated');
  end if;

  v_role := nullif(lower(trim(coalesce(v_claims ->> 'role', ''))), '');
  if v_role is not null then
    v_roles := array_append(v_roles, v_role);
  end if;

  if jsonb_typeof(v_claims -> 'roles') = 'array' then
    for v_role in
      select lower(trim(value))
      from jsonb_array_elements_text(v_claims -> 'roles') as value
      where trim(value) <> ''
    loop
      v_roles := array_append(v_roles, v_role);
    end loop;
  end if;

  if jsonb_typeof(v_claims #> '{app_metadata,roles}') = 'array' then
    for v_role in
      select lower(trim(value))
      from jsonb_array_elements_text(v_claims #> '{app_metadata,roles}') as value
      where trim(value) <> ''
    loop
      v_roles := array_append(v_roles, v_role);
    end loop;
  end if;

  if jsonb_typeof(v_claims #> '{user_metadata,roles}') = 'array' then
    for v_role in
      select lower(trim(value))
      from jsonb_array_elements_text(v_claims #> '{user_metadata,roles}') as value
      where trim(value) <> ''
    loop
      v_roles := array_append(v_roles, v_role);
    end loop;
  end if;

  if jsonb_typeof(v_claims #> '{app_metadata,platform_roles}') = 'array' then
    for v_role in
      select lower(trim(value))
      from jsonb_array_elements_text(v_claims #> '{app_metadata,platform_roles}') as value
      where trim(value) <> ''
    loop
      v_roles := array_append(v_roles, v_role);
    end loop;
  end if;

  if jsonb_typeof(v_claims #> '{user_metadata,platform_roles}') = 'array' then
    for v_role in
      select lower(trim(value))
      from jsonb_array_elements_text(v_claims #> '{user_metadata,platform_roles}') as value
      where trim(value) <> ''
    loop
      v_roles := array_append(v_roles, v_role);
    end loop;
  end if;

  if v_user_id is not null and exists (
    select 1
    from public.admin_users
    where user_id = v_user_id
      and is_active = true
  ) then
    v_roles := array_append(v_roles, 'admin_operator');

    select lower(role)
    into v_role
    from public.admin_users
    where user_id = v_user_id
      and is_active = true
    limit 1;

    if v_role is not null then
      v_roles := array_append(v_roles, v_role);
    end if;
  end if;

  return (
    select coalesce(
      jsonb_agg(role_name order by role_name),
      '[]'::jsonb
    )
    from (
      select distinct role_name
      from unnest(v_roles) as role_name
      where role_name is not null
        and role_name <> ''
    ) deduped
  );
end;
$$;


--
-- Name: ensure_user_foundation(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ensure_user_foundation(p_user_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  phone_value text;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN;
  END IF;

  SELECT public.resolve_auth_user_phone(p_user_id) INTO phone_value;

  INSERT INTO public.profiles (id, user_id, phone_number)
  VALUES (p_user_id, p_user_id, phone_value)
  ON CONFLICT (id) DO UPDATE
    SET user_id = EXCLUDED.user_id,
        phone_number = coalesce(EXCLUDED.phone_number, profiles.phone_number);

  PERFORM public.credit_welcome_fet(p_user_id, 'welcome_credit:' || p_user_id::text);
END;
$$;


--
-- Name: fet_supply_cap(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fet_supply_cap() RETURNS bigint
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'public'
    AS $$
  SELECT 100000000::bigint;
$$;


--
-- Name: find_auth_user_by_phone(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.find_auth_user_by_phone(p_phone text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public'
    AS $$
DECLARE
  v_id uuid;
  v_normalized text;
  v_without_plus text;
BEGIN
  -- Normalize: strip spaces, dashes, parens
  v_normalized := regexp_replace(trim(coalesce(p_phone, '')), '[\s\-\(\)]', '', 'g');

  -- Try exact match first
  SELECT id INTO v_id
  FROM auth.users
  WHERE phone = v_normalized
  LIMIT 1;

  IF v_id IS NOT NULL THEN
    RETURN v_id;
  END IF;

  -- Try with '+' prefix removed
  v_without_plus := ltrim(v_normalized, '+');
  SELECT id INTO v_id
  FROM auth.users
  WHERE phone = v_without_plus
     OR phone = '+' || v_without_plus
  LIMIT 1;

  RETURN v_id;
END;
$$;


--
-- Name: generate_pool_share_card(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_pool_share_card(p_pool_id uuid, p_social_card_url text DEFAULT NULL::text, p_metadata jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_payload jsonb;
BEGIN
  IF p_social_card_url IS NOT NULL THEN
    RETURN public.set_match_pool_social_card_url(p_pool_id, p_social_card_url, p_metadata);
  END IF;

  v_payload := public.get_match_pool_social_card_payload(p_pool_id);
  RETURN jsonb_build_object('status', 'payload_ready', 'payload', v_payload);
END;
$$;


--
-- Name: generate_profile_fan_id(text, integer, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_profile_fan_id(p_seed text, p_attempt integer DEFAULT 0, p_profile_id uuid DEFAULT NULL::uuid) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: generate_team_form_features_for_matches(text[], integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_team_form_features_for_matches(p_match_ids text[] DEFAULT NULL::text[], p_limit integer DEFAULT 250) RETURNS integer
    LANGUAGE plpgsql
    SET search_path TO 'public'
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


--
-- Name: get_admin_me(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_admin_me() RETURNS public.admin_users
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
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


--
-- Name: get_app_bootstrap_config(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_app_bootstrap_config(p_market text DEFAULT 'global'::text, p_platform text DEFAULT 'all'::text) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_channel text := case
    when p_platform in ('android', 'ios') then 'mobile'
    when p_platform = 'web' then 'web'
    else 'web'
  end;
  v_result jsonb;
begin
  select jsonb_build_object(
    'platform_config_version', public.platform_feature_config_version(),
    'regions', (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'country_code', crm.country_code,
            'region', crm.region,
            'country_name', crm.country_name,
            'flag_emoji', crm.flag_emoji
          )
          order by crm.country_name
        ),
        '[]'::jsonb
      )
      from public.country_region_map crm
    ),
    'phone_presets', (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'country_code', pp.country_code,
            'dial_code', pp.dial_code,
            'hint', pp.hint,
            'min_digits', pp.min_digits
          )
          order by pp.country_code
        ),
        '[]'::jsonb
      )
      from public.phone_presets pp
    ),
    'currency_display', (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'currency_code', cdm.currency_code,
            'symbol', cdm.symbol,
            'decimals', cdm.decimals,
            'space_separated', cdm.space_separated
          )
          order by cdm.currency_code
        ),
        '[]'::jsonb
      )
      from public.currency_display_metadata cdm
    ),
    'country_currency_map', (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'country_code', ccm.country_code,
            'currency_code', ccm.currency_code,
            'country_name', ccm.country_name
          )
          order by ccm.country_code
        ),
        '[]'::jsonb
      )
      from public.country_currency_map ccm
    ),
    'feature_flags', (
      select coalesce(
        jsonb_object_agg(resolved.key, resolved.enabled),
        '{}'::jsonb
      )
      from (
        select distinct on (ff.key)
          ff.key,
          ff.enabled
        from public.feature_flags ff
        where (ff.market = p_market or ff.market = 'global')
          and (ff.platform = p_platform or ff.platform = 'all')
        order by
          ff.key,
          case when ff.market = p_market then 1 else 0 end desc,
          case when ff.platform = p_platform then 1 else 0 end desc,
          ff.updated_at desc
      ) as resolved
    ),
    'app_config', (
      select coalesce(
        jsonb_object_agg(acr.key, acr.value),
        '{}'::jsonb
      )
      from public.app_config_remote acr
    ),
    'launch_moments', (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'tag', lm.tag,
            'title', lm.title,
            'subtitle', lm.subtitle,
            'kicker', lm.kicker,
            'region_key', lm.region_key
          )
          order by lm.sort_order
        ),
        '[]'::jsonb
      )
      from public.launch_moments lm
      where lm.is_active = true
    ),
    'platform_features', (
      select coalesce(
        jsonb_agg(feature_row.feature_json order by feature_row.sort_order, feature_row.display_name),
        '[]'::jsonb
      )
      from (
        select
          pf.display_name,
          least(
            coalesce(pfc_mobile.sort_order, 999),
            coalesce(pfc_web.sort_order, 999)
          ) as sort_order,
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
              auth.uid() is not null
            )
          ) as feature_json
        from public.platform_features pf
        left join public.platform_feature_rules pfr
          on pfr.feature_key = pf.feature_key
        left join public.platform_feature_channels pfc_mobile
          on pfc_mobile.feature_key = pf.feature_key
         and pfc_mobile.channel = 'mobile'
        left join public.platform_feature_channels pfc_web
          on pfc_web.feature_key = pf.feature_key
         and pfc_web.channel = 'web'
      ) as feature_row
    ),
    'platform_content_blocks', (
      select coalesce(
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
          order by pcb.sort_order, pcb.block_key
        ),
        '[]'::jsonb
      )
      from public.platform_content_blocks pcb
      where pcb.is_active = true
        and (pcb.target_channel = v_channel or pcb.target_channel = 'both')
        and (
          pcb.feature_key is null
          or coalesce(
            (
              public.resolve_platform_feature(
                pcb.feature_key,
                v_channel,
                auth.uid() is not null
              ) ->> 'is_visible'
            )::boolean,
            false
          )
        )
    )
  )
  into v_result;

  return v_result;
end;
$$;


--
-- Name: get_competition_current_season(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_competition_current_season(p_competition_id text) RETURNS text
    LANGUAGE plpgsql STABLE
    SET search_path TO 'public'
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


--
-- Name: get_country_region(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_country_region(p_country_code text) RETURNS text
    LANGUAGE sql STABLE
    AS $$
  SELECT COALESCE(
    (SELECT region FROM public.country_region_map WHERE country_code = UPPER(p_country_code) LIMIT 1),
    'global'
  );
$$;


--
-- Name: get_match_pool_social_card_payload(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_match_pool_social_card_payload(p_pool_id uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
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
    'country_code', p.country_code,
    'venue_id', p.venue_id,
    'share_url', p.share_url,
    'social_card_url', p.social_card_url,
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
  WHERE p.id = p_pool_id
    AND (
      p.status IN ('open', 'locked', 'settled')
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


--
-- Name: get_venue_fet_reward_config(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_venue_fet_reward_config(p_venue_id uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_features jsonb;
  v_default_percent numeric := greatest(public.app_config_numeric('order_reward_percent_default', 10), 0);
  v_default_trigger text := 'paid';
  v_trigger_value jsonb;
BEGIN
  SELECT value
  INTO v_trigger_value
  FROM public.app_config_remote
  WHERE key = 'order_reward_trigger_default'
  LIMIT 1;

  v_default_trigger := coalesce(nullif(trim(both '"' from coalesce(v_trigger_value::text, '')), ''), 'paid');

  SELECT coalesce(features_json, '{}'::jsonb)
  INTO v_features
  FROM public.venues
  WHERE id = p_venue_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Venue not found';
  END IF;

  RETURN jsonb_build_object(
    'venue_id', p_venue_id,
    'reward_percent', coalesce(nullif(v_features ->> 'fet_reward_percent', '')::numeric, v_default_percent),
    'reward_trigger', CASE
      WHEN coalesce(v_features ->> 'fet_reward_trigger', v_default_trigger) IN ('paid', 'served')
        THEN coalesce(v_features ->> 'fet_reward_trigger', v_default_trigger)
      ELSE 'paid'
    END,
    'accepts_fet_spend', coalesce((v_features ->> 'accepts_fet_spend')::boolean, false),
    'redemption_fet_per_currency', nullif(v_features ->> 'fet_redemption_fet_per_currency', '')::numeric,
    'platform_default_reward_percent', v_default_percent,
    'platform_default_reward_trigger', v_default_trigger
  );
END;
$$;


--
-- Name: get_venue_fet_reward_summary(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_venue_fet_reward_summary(p_venue_id uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_today timestamptz := date_trunc('day', timezone('utc', now()));
  v_order_earned bigint := 0;
  v_order_spent bigint := 0;
  v_pending_settlements bigint := 0;
BEGIN
  IF NOT (
    coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role'
    OR coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb ->> 'role' = 'service_role'
    OR public.venue_user_has_role(p_venue_id)
    OR public.is_admin_manager(v_actor)
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT
    coalesce(sum(amount_fet) FILTER (
      WHERE direction = 'credit'
        AND coalesce(transaction_type, tx_type) = 'order_earn'
        AND created_at >= v_today
    ), 0)::bigint,
    coalesce(sum(amount_fet) FILTER (
      WHERE direction = 'debit'
        AND coalesce(transaction_type, tx_type) = 'order_spend'
        AND created_at >= v_today
    ), 0)::bigint,
    coalesce(sum(amount_fet) FILTER (
      WHERE balance_bucket = 'pending'
        AND status <> 'voided'
    ), 0)::bigint
  INTO v_order_earned, v_order_spent, v_pending_settlements
  FROM public.fet_wallet_transactions
  WHERE venue_id = p_venue_id;

  RETURN jsonb_build_object(
    'venue_id', p_venue_id,
    'order_earned_today_fet', v_order_earned,
    'order_spent_today_fet', v_order_spent,
    'pending_settlements_fet', v_pending_settlements
  );
END;
$$;


--
-- Name: get_wallet_balance(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_wallet_balance(p_user_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_user_id uuid := coalesce(p_user_id, auth.uid());
  v_is_service_role boolean := coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role'
    OR coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb ->> 'role' = 'service_role';
  v_balance jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF v_requester IS DISTINCT FROM v_user_id
     AND NOT v_is_service_role
     AND NOT public.is_active_admin_operator(v_requester) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  v_balance := public.reconcile_fet_wallet(v_user_id);
  RETURN v_balance;
END;
$$;


--
-- Name: guess_user_currency(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.guess_user_currency(p_user_id uuid DEFAULT auth.uid()) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: handle_new_auth_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_new_auth_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  PERFORM public.ensure_user_foundation(NEW.id);
  RETURN NEW;
END;
$$;


--
-- Name: is_active_admin_operator(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_active_admin_operator(p_user_id uuid) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: is_active_admin_user(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_active_admin_user(p_user_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.admin_users
    WHERE user_id = p_user_id
      AND is_active = true
      AND role IN ('super_admin', 'admin')
  );
$$;


--
-- Name: is_admin_manager(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_admin_manager(p_user_id uuid) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: is_order_owner(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_order_owner(p_order_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.orders
    WHERE id = p_order_id
      AND user_id = auth.uid()
  );
END;
$$;


--
-- Name: is_service_role_request(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_service_role_request() RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: is_super_admin_user(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_super_admin_user(p_user_id uuid) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: issue_anonymous_upgrade_claim(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.issue_anonymous_upgrade_claim() RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
declare
  v_anon_id uuid := auth.uid();
  v_claim_token text;
begin
  if v_anon_id is null then
    raise exception 'Authentication required';
  end if;

  perform public.sync_profile_auth_state(v_anon_id);

  if public.current_session_is_anonymous() is distinct from true then
    raise exception 'Anonymous session required';
  end if;

  v_claim_token := replace(gen_random_uuid()::text, '-', '')
    || replace(gen_random_uuid()::text, '-', '');

  insert into public.anonymous_upgrade_claims (
    anon_user_id,
    claim_token,
    issued_at,
    expires_at,
    consumed_at,
    consumed_by_user_id
  ) values (
    v_anon_id,
    v_claim_token,
    timezone('utc', now()),
    timezone('utc', now()) + interval '30 minutes',
    null,
    null
  )
  on conflict (anon_user_id) do update
  set claim_token = excluded.claim_token,
      issued_at = excluded.issued_at,
      expires_at = excluded.expires_at,
      consumed_at = null,
      consumed_by_user_id = null;

  return v_claim_token;
end;
$$;


--
-- Name: join_match_pool(uuid, uuid, bigint, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.join_match_pool(p_pool_id uuid, p_camp_id uuid, p_amount_fet bigint DEFAULT NULL::bigint, p_invite_code text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_pool public.match_pools%ROWTYPE;
  v_camp public.match_pool_camps%ROWTYPE;
  v_match public.matches%ROWTYPE;
  v_invite public.match_pool_invites%ROWTYPE;
  v_amount bigint;
  v_entry_id uuid;
  v_reward_tx_id uuid;
  v_reward_amount bigint := 0;
  v_min_qualified_stake bigint := greatest(coalesce(public.app_config_bigint('min_qualified_stake_fet', 1), 1), 1);
  v_reward_result jsonb;
  v_invite_code text := nullif(trim(coalesce(p_invite_code, '')), '');
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

  IF v_pool.status <> 'open' THEN
    RAISE EXCEPTION 'Pool is not open for entries';
  END IF;

  SELECT * INTO v_match
  FROM public.matches
  WHERE id = v_pool.match_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pool match not found';
  END IF;

  IF v_match.match_status <> 'scheduled' OR v_match.match_date <= timezone('utc', now()) THEN
    UPDATE public.match_pools
    SET status = 'locked',
        locked_at = coalesce(locked_at, timezone('utc', now()))
    WHERE id = v_pool.id;
    RAISE EXCEPTION 'Pool is locked because the match has started';
  END IF;

  SELECT * INTO v_camp
  FROM public.match_pool_camps
  WHERE id = p_camp_id
    AND pool_id = p_pool_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pool camp not found';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.match_pool_entries
    WHERE pool_id = p_pool_id
      AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'You have already joined this pool';
  END IF;

  IF v_invite_code IS NOT NULL THEN
    SELECT * INTO v_invite
    FROM public.match_pool_invites
    WHERE invite_code = v_invite_code
      AND pool_id = p_pool_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Invite code is invalid for this pool';
    END IF;

    IF v_invite.status <> 'created' THEN
      RAISE EXCEPTION 'Invite code has already been used or closed';
    END IF;

    IF v_invite.expires_at IS NOT NULL AND v_invite.expires_at <= timezone('utc', now()) THEN
      UPDATE public.match_pool_invites
      SET status = 'expired'
      WHERE id = v_invite.id;
      RAISE EXCEPTION 'Invite code has expired';
    END IF;

    IF v_invite.inviter_user_id = v_user_id THEN
      RAISE EXCEPTION 'Creator invite rewards cannot be self-awarded';
    END IF;
  END IF;

  v_amount := CASE
    WHEN v_pool.entry_fee_fet > 0 THEN v_pool.entry_fee_fet
    ELSE coalesce(p_amount_fet, v_pool.stake_min_fet)
  END;

  IF v_amount < v_pool.stake_min_fet OR v_amount > v_pool.stake_max_fet THEN
    RAISE EXCEPTION 'Stake amount is outside this pool''s rules';
  END IF;

  PERFORM public.wallet_post_transaction(
    p_user_id => v_user_id,
    p_transaction_type => 'pool_stake',
    p_direction => 'debit',
    p_amount_fet => v_amount,
    p_balance_bucket => 'available',
    p_idempotency_key => 'pool_stake_available:' || p_pool_id::text || ':' || v_user_id::text,
    p_reference_type => 'match_pool',
    p_reference_id => p_pool_id::text,
    p_title => 'FET staked into pool',
    p_metadata => jsonb_build_object(
      'camp_id', p_camp_id,
      'camp_code', v_camp.code,
      'scope', v_pool.scope,
      'invite_code', v_invite_code
    ),
    p_match_id => v_pool.match_id,
    p_pool_id => p_pool_id,
    p_venue_id => v_pool.venue_id
  );

  INSERT INTO public.match_pool_entries (
    pool_id,
    camp_id,
    user_id,
    amount_fet,
    metadata
  )
  VALUES (
    p_pool_id,
    p_camp_id,
    v_user_id,
    v_amount,
    jsonb_build_object('entry_source', 'rpc', 'invite_code', v_invite_code)
  )
  RETURNING id INTO v_entry_id;

  PERFORM public.wallet_post_transaction(
    p_user_id => v_user_id,
    p_transaction_type => 'pool_stake',
    p_direction => 'credit',
    p_amount_fet => v_amount,
    p_balance_bucket => 'staked',
    p_idempotency_key => 'pool_stake_staked:' || v_entry_id::text,
    p_reference_type => 'match_pool_entry',
    p_reference_id => v_entry_id::text,
    p_title => 'FET staked into pool',
    p_metadata => jsonb_build_object('pool_id', p_pool_id, 'camp_id', p_camp_id),
    p_match_id => v_pool.match_id,
    p_pool_id => p_pool_id,
    p_entry_id => v_entry_id,
    p_venue_id => v_pool.venue_id
  );

  UPDATE public.match_pool_camps
  SET member_count = member_count + 1,
      total_staked_fet = total_staked_fet + v_amount
  WHERE id = p_camp_id;

  UPDATE public.match_pools
  SET total_members = total_members + 1,
      total_staked_fet = total_staked_fet + v_amount
  WHERE id = p_pool_id;

  IF v_invite.id IS NOT NULL
     AND coalesce(v_pool.creator_reward_fet, 0) > 0
     AND v_pool.creator_user_id = v_invite.inviter_user_id
     AND v_amount >= coalesce(nullif(v_pool.creator_reward_rules ->> 'min_qualified_stake', '')::bigint, v_min_qualified_stake) THEN
    v_reward_amount := greatest(
      coalesce(v_pool.creator_reward_fet, public.app_config_bigint('pool_creator_reward_fet_default', 1), 1),
      0
    );

    IF v_reward_amount > 0 THEN
      v_reward_result := public.wallet_post_transaction(
        p_user_id => v_invite.inviter_user_id,
        p_transaction_type => 'creator_reward',
        p_direction => 'credit',
        p_amount_fet => v_reward_amount,
        p_balance_bucket => 'available',
        p_idempotency_key => 'creator_reward:' || v_invite.id::text,
        p_reference_type => 'match_pool_invite',
        p_reference_id => v_invite.id::text,
        p_title => 'Pool creator invite reward',
        p_metadata => jsonb_build_object(
          'invite_id', v_invite.id,
          'entry_id', v_entry_id,
          'invitee_user_id', v_user_id,
          'qualified', true,
          'min_qualified_stake', v_min_qualified_stake
        ),
        p_match_id => v_pool.match_id,
        p_pool_id => p_pool_id,
        p_entry_id => v_entry_id,
        p_venue_id => v_pool.venue_id
      );
      v_reward_tx_id := (v_reward_result ->> 'transaction_id')::uuid;
    END IF;

    UPDATE public.match_pool_invites
    SET invitee_user_id = v_user_id,
        joined_entry_id = v_entry_id,
        status = 'rewarded',
        reward_tx_id = v_reward_tx_id,
        reward_amount_fet = v_reward_amount,
        joined_at = timezone('utc', now()),
        rewarded_at = timezone('utc', now())
    WHERE id = v_invite.id;
  ELSIF v_invite.id IS NOT NULL THEN
    UPDATE public.match_pool_invites
    SET invitee_user_id = v_user_id,
        joined_entry_id = v_entry_id,
        status = 'joined',
        joined_at = timezone('utc', now())
    WHERE id = v_invite.id;
  END IF;

  RETURN jsonb_build_object(
    'status', 'joined',
    'entry_id', v_entry_id,
    'pool_id', p_pool_id,
    'camp_id', p_camp_id,
    'amount_fet', v_amount,
    'invite_reward_tx_id', v_reward_tx_id
  );
END;
$$;


--
-- Name: join_pool(uuid, uuid, bigint, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.join_pool(p_pool_id uuid, p_camp_id uuid, p_stake_amount bigint DEFAULT NULL::bigint, p_source text DEFAULT 'direct'::text, p_invite_code text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
  v_result jsonb;
  v_entry_id uuid;
  v_inviter uuid;
BEGIN
  IF p_source NOT IN ('direct', 'invite_link', 'venue_qr', 'social_share') THEN
    RAISE EXCEPTION 'Invalid pool entry source';
  END IF;

  v_result := public.join_match_pool(p_pool_id, p_camp_id, p_stake_amount, p_invite_code);
  v_entry_id := (v_result ->> 'entry_id')::uuid;

  IF p_invite_code IS NOT NULL THEN
    SELECT inviter_user_id INTO v_inviter
    FROM public.match_pool_invites
    WHERE invite_code = p_invite_code
      AND pool_id = p_pool_id;
  END IF;

  UPDATE public.match_pool_entries
  SET source = CASE WHEN p_invite_code IS NOT NULL THEN 'invite_link' ELSE p_source END,
      invited_by_user_id = v_inviter
  WHERE id = v_entry_id;

  UPDATE public.fet_wallet_transactions
  SET pool_entry_id = v_entry_id
  WHERE pool_id = p_pool_id
    AND user_id = auth.uid()
    AND tx_type IN ('match_pool_entry', 'pool_stake')
    AND pool_entry_id IS NULL;

  RETURN v_result || jsonb_build_object('source', CASE WHEN p_invite_code IS NOT NULL THEN 'invite_link' ELSE p_source END);
END;
$$;


--
-- Name: lock_fet_supply_cap(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.lock_fet_supply_cap() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  PERFORM pg_advisory_xact_lock(
    hashtextextended('public.fet_supply_cap', 0)
  );
END;
$$;


--
-- Name: lock_pool_for_match_start(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.lock_pool_for_match_start(p_match_id text DEFAULT NULL::text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_count integer := 0;
BEGIN
  UPDATE public.match_pools p
  SET status = 'locked',
      locked_at = coalesce(p.locked_at, timezone('utc', now())),
      updated_at = timezone('utc', now())
  FROM public.matches m
  WHERE m.id = p.match_id
    AND p.status = 'open'
    AND (p_match_id IS NULL OR p.match_id = p_match_id)
    AND coalesce(m.starts_at, m.match_date) <= timezone('utc', now());

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;


--
-- Name: log_app_runtime_errors_batch(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.log_app_runtime_errors_batch(p_errors jsonb) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: log_platform_control_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.log_platform_control_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: log_product_event(text, jsonb, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.log_product_event(p_event_name text, p_properties jsonb DEFAULT '{}'::jsonb, p_session_id text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: log_product_events_batch(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.log_product_events_batch(p_events jsonb) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: manual_mark_order_paid(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.manual_mark_order_paid(p_order_id uuid, p_payment_method text DEFAULT 'cash'::text, p_actor_note text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_order public.orders%ROWTYPE;
  v_before jsonb;
  v_after jsonb;
BEGIN
  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF NOT public.venue_user_has_role(v_order.venue_id, ARRAY['owner', 'manager', 'staff']::public.venue_user_role[]) THEN
    RAISE EXCEPTION 'Only venue operators can mark this order paid';
  END IF;

  IF v_order.status = 'cancelled' THEN
    RAISE EXCEPTION 'Cannot mark a cancelled order paid';
  END IF;

  v_before := to_jsonb(v_order);

  UPDATE public.orders
  SET payment_status = 'paid',
      payment_method = p_payment_method::public.payment_method,
      updated_at = timezone('utc', now())
  WHERE id = p_order_id
  RETURNING to_jsonb(orders.*) INTO v_after;

  INSERT INTO public.payment_events (
    order_id,
    provider,
    status,
    request_payload,
    response_payload
  )
  VALUES (
    p_order_id,
    p_payment_method::public.payment_method,
    'paid',
    jsonb_build_object('marked_by', auth.uid(), 'note', p_actor_note),
    jsonb_build_object('source', 'manual_mark_order_paid', 'provider_api_used', false)
  );

  PERFORM public.sports_bar_write_audit('manual_mark_order_paid', 'order', p_order_id::text, v_before, v_after);

  RETURN jsonb_build_object('status', 'paid', 'order_id', p_order_id);
END;
$$;


--
-- Name: mark_all_notifications_read(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mark_all_notifications_read() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  perform public.assert_platform_feature_available(
    'notifications',
    public.request_platform_channel()
  );

  update public.notification_log
  set read_at = coalesce(read_at, now())
  where user_id = auth.uid()
    and read_at is null;
end;
$$;


--
-- Name: mark_notification_read(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mark_notification_read(p_notification_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  perform public.assert_platform_feature_available(
    'notifications',
    public.request_platform_channel()
  );

  update public.notification_log
  set read_at = coalesce(read_at, now())
  where id = p_notification_id
    and user_id = auth.uid();
end;
$$;


--
-- Name: merge_anonymous_to_authenticated(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.merge_anonymous_to_authenticated(p_anon_id uuid, p_auth_id uuid) RETURNS void
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


--
-- Name: merge_anonymous_to_authenticated_secure(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.merge_anonymous_to_authenticated_secure(p_anon_id uuid, p_claim_token text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
declare
  v_auth_id uuid := auth.uid();
  v_claim public.anonymous_upgrade_claims%rowtype;
  v_auth_is_anonymous boolean := false;
begin
  if v_auth_id is null then
    raise exception 'Authentication required';
  end if;

  if p_anon_id is null or nullif(btrim(p_claim_token), '') is null then
    raise exception 'Anonymous user ID and claim token are required';
  end if;

  if p_anon_id = v_auth_id then
    raise exception 'Anonymous and authenticated user IDs must be different';
  end if;

  perform public.sync_profile_auth_state(v_auth_id);
  perform public.sync_profile_auth_state(p_anon_id);

  select *
  into v_claim
  from public.anonymous_upgrade_claims
  where anon_user_id = p_anon_id
    and claim_token = p_claim_token
    and consumed_at is null
    and expires_at > timezone('utc', now());

  if v_claim.anon_user_id is null then
    raise exception 'Invalid or expired upgrade claim';
  end if;

  v_auth_is_anonymous := public.current_session_is_anonymous();
  if v_auth_is_anonymous = true then
    raise exception 'Authenticated account required';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.user_id = p_anon_id
      and coalesce(p.is_anonymous, false) = true
  ) then
    raise exception 'Anonymous profile not found';
  end if;

  insert into public.profiles (
    id,
    user_id,
    is_anonymous,
    auth_method,
    created_at,
    updated_at
  )
  select
    v_auth_id,
    v_auth_id,
    false,
    'phone',
    timezone('utc', now()),
    timezone('utc', now())
  where not exists (
    select 1 from public.profiles p where p.user_id = v_auth_id
  );

  insert into public.user_favorite_teams (
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
  select
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
  from public.user_favorite_teams uft
  where uft.user_id = p_anon_id
    and not exists (
      select 1
      from public.user_favorite_teams existing
      where existing.user_id = v_auth_id
        and existing.team_id = uft.team_id
    );

  insert into public.user_followed_competitions (
    user_id,
    competition_id,
    created_at
  )
  select
    v_auth_id,
    ufc.competition_id,
    ufc.created_at
  from public.user_followed_competitions ufc
  where ufc.user_id = p_anon_id
    and not exists (
      select 1
      from public.user_followed_competitions existing
      where existing.user_id = v_auth_id
        and existing.competition_id = ufc.competition_id
    );

  update public.profiles auth_p
  set favorite_team_id = coalesce(auth_p.favorite_team_id, anon_p.favorite_team_id),
      favorite_team_name = coalesce(auth_p.favorite_team_name, anon_p.favorite_team_name),
      active_country = coalesce(auth_p.active_country, anon_p.active_country),
      country_code = coalesce(auth_p.country_code, anon_p.country_code),
      onboarding_completed = true,
      upgraded_from_anonymous_id = p_anon_id,
      is_anonymous = false,
      auth_method = coalesce(nullif(auth_p.auth_method, ''), 'phone'),
      updated_at = timezone('utc', now())
  from public.profiles anon_p
  where auth_p.user_id = v_auth_id
    and anon_p.user_id = p_anon_id;

  update public.anonymous_upgrade_claims
  set consumed_at = timezone('utc', now()),
      consumed_by_user_id = v_auth_id
  where anon_user_id = p_anon_id;

  delete from public.user_favorite_teams where user_id = p_anon_id;
  delete from public.user_followed_competitions where user_id = p_anon_id;
  delete from public.profiles where user_id = p_anon_id;
end;
$$;


--
-- Name: normalize_match_status(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.normalize_match_status(p_status text) RETURNS text
    LANGUAGE sql IMMUTABLE
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


--
-- Name: notify_wallet_credit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_wallet_credit() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
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


--
-- Name: phone_auth_email(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.phone_auth_email(p_phone text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE
    WHEN p_phone IS NULL OR regexp_replace(p_phone, '\D', '', 'g') = '' THEN NULL
    ELSE 'phone-' || regexp_replace(p_phone, '\D', '', 'g') || '@phone.fanzone.invalid'
  END;
$$;


--
-- Name: platform_feature_config_version(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.platform_feature_config_version() RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select md5(
    concat_ws(
      '|',
      coalesce((select max(updated_at)::text from public.platform_features), '0'),
      coalesce((select max(updated_at)::text from public.platform_feature_rules), '0'),
      coalesce((select max(updated_at)::text from public.platform_feature_channels), '0'),
      coalesce((select max(updated_at)::text from public.platform_content_blocks), '0')
    )
  );
$$;


--
-- Name: platform_feature_status_is_live(text, timestamp with time zone, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.platform_feature_status_is_live(p_status text, p_schedule_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_schedule_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_now timestamp with time zone DEFAULT timezone('utc'::text, now())) RETURNS boolean
    LANGUAGE sql STABLE
    SET search_path TO 'public'
    AS $$
  SELECT CASE
    WHEN coalesce(p_status, 'inactive') = 'inactive' THEN false
    WHEN coalesce(p_status, 'inactive') = 'scheduled' THEN
      coalesce(p_schedule_start_at, p_now) <= p_now
      AND (p_schedule_end_at IS NULL OR p_schedule_end_at > p_now)
    ELSE p_schedule_end_at IS NULL OR p_schedule_end_at > p_now
  END;
$$;


--
-- Name: platform_roles_allow_access(jsonb, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.platform_roles_allow_access(p_role_restrictions jsonb, p_user_roles jsonb DEFAULT public.current_user_platform_roles()) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_any text[];
  v_all text[];
  v_none text[];
begin
  if p_role_restrictions is null
    or p_role_restrictions = 'null'::jsonb
    or p_role_restrictions = '{}'::jsonb
    or p_role_restrictions = '[]'::jsonb
  then
    return true;
  end if;

  if jsonb_typeof(p_role_restrictions) = 'array' then
    return exists (
      select 1
      from jsonb_array_elements_text(p_role_restrictions) as required_role(value)
      join jsonb_array_elements_text(coalesce(p_user_roles, '[]'::jsonb)) as user_role(value)
        on lower(trim(required_role.value)) = lower(trim(user_role.value))
      where trim(required_role.value) <> ''
    );
  end if;

  if jsonb_typeof(p_role_restrictions) <> 'object' then
    return false;
  end if;

  select coalesce(array_agg(lower(trim(value))), array[]::text[])
  into v_any
  from jsonb_array_elements_text(coalesce(p_role_restrictions -> 'any_of', '[]'::jsonb)) as value
  where trim(value) <> '';

  select coalesce(array_agg(lower(trim(value))), array[]::text[])
  into v_all
  from jsonb_array_elements_text(coalesce(p_role_restrictions -> 'all_of', '[]'::jsonb)) as value
  where trim(value) <> '';

  select coalesce(array_agg(lower(trim(value))), array[]::text[])
  into v_none
  from jsonb_array_elements_text(coalesce(p_role_restrictions -> 'none_of', '[]'::jsonb)) as value
  where trim(value) <> '';

  if cardinality(v_any) > 0 and not exists (
    select 1
    from unnest(v_any) as required_role
    where required_role = any (
      array(
        select lower(trim(value))
        from jsonb_array_elements_text(coalesce(p_user_roles, '[]'::jsonb)) as value
      )
    )
  ) then
    return false;
  end if;

  if cardinality(v_all) > 0 and exists (
    select 1
    from unnest(v_all) as required_role
    where required_role <> all (
      array(
        select lower(trim(value))
        from jsonb_array_elements_text(coalesce(p_user_roles, '[]'::jsonb)) as value
      )
    )
  ) then
    return false;
  end if;

  if cardinality(v_none) > 0 and exists (
    select 1
    from unnest(v_none) as denied_role
    where denied_role = any (
      array(
        select lower(trim(value))
        from jsonb_array_elements_text(coalesce(p_user_roles, '[]'::jsonb)) as value
      )
    )
  ) then
    return false;
  end if;

  return true;
end;
$$;


--
-- Name: reconcile_fet_wallet(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reconcile_fet_wallet(p_user_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_balance record;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'User id is required';
  END IF;

  INSERT INTO public.fet_wallets (
    user_id,
    available_balance_fet,
    locked_balance_fet,
    staked_balance_fet,
    pending_balance_fet
  )
  VALUES (p_user_id, 0, 0, 0, 0)
  ON CONFLICT (user_id) DO NOTHING;

  SELECT *
  INTO v_balance
  FROM public.wallet_balance_from_ledger(p_user_id);

  IF v_balance.available_fet < 0 THEN
    RAISE EXCEPTION 'Wallet reconciliation failed: negative available FET for user %', p_user_id;
  END IF;

  IF v_balance.staked_fet < 0 THEN
    RAISE EXCEPTION 'Wallet reconciliation failed: negative staked FET for user %', p_user_id;
  END IF;

  IF v_balance.pending_fet < 0 THEN
    RAISE EXCEPTION 'Wallet reconciliation failed: negative pending FET for user %', p_user_id;
  END IF;

  UPDATE public.fet_wallets
  SET available_balance_fet = v_balance.available_fet,
      staked_balance_fet = v_balance.staked_fet,
      pending_balance_fet = v_balance.pending_fet,
      locked_balance_fet = v_balance.staked_fet + v_balance.pending_fet,
      updated_at = timezone('utc', now())
  WHERE user_id = p_user_id;

  RETURN jsonb_build_object(
    'user_id', p_user_id,
    'available_fet', v_balance.available_fet,
    'staked_fet', v_balance.staked_fet,
    'pending_fet', v_balance.pending_fet,
    'spent_fet', v_balance.spent_fet,
    'earned_fet', v_balance.earned_fet
  );
END;
$$;


--
-- Name: refresh_competition_derived_fields(text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_competition_derived_fields(p_competition_ids text[] DEFAULT NULL::text[]) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: refresh_team_derived_fields(text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_team_derived_fields(p_team_ids text[] DEFAULT NULL::text[]) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: refresh_team_form_features_for_match(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_team_form_features_for_match(p_match_id text) RETURNS void
    LANGUAGE plpgsql
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


--
-- Name: repair_wallet_bootstrap_gaps(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.repair_wallet_bootstrap_gaps() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: request_platform_channel(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.request_platform_channel() RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: require_active_admin_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.require_active_admin_user() RETURNS uuid
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: require_admin_manager_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.require_admin_manager_user() RETURNS uuid
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
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


--
-- Name: require_super_admin_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.require_super_admin_user() RETURNS uuid
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: resolve_auth_user_phone(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.resolve_auth_user_phone(p_user_id uuid) RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: resolve_platform_feature(text, text, boolean, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.resolve_platform_feature(p_feature_key text, p_channel text, p_is_authenticated boolean DEFAULT (auth.uid() IS NOT NULL), p_now timestamp with time zone DEFAULT timezone('utc'::text, now())) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_feature public.platform_features%rowtype;
  v_rules public.platform_feature_rules%rowtype;
  v_channel public.platform_feature_channels%rowtype;
  v_dependency_blocker text;
  v_is_live boolean := false;
  v_is_operational boolean := false;
  v_is_visible boolean := false;
  v_is_available boolean := false;
  v_roles_allowed boolean := true;
  v_auth_satisfied boolean := true;
  v_configured_visible boolean := false;
  v_visibility_reason text := 'visible';
  v_feature_channel text := case
    when lower(coalesce(p_channel, 'web')) in ('android', 'ios', 'mobile')
      then 'mobile'
    else 'web'
  end;
  v_user_roles jsonb := public.current_user_platform_roles();
begin
  select *
  into v_feature
  from public.platform_features
  where feature_key = coalesce(trim(p_feature_key), '');

  if not found then
    return jsonb_build_object(
      'feature_key', p_feature_key,
      'exists', false,
      'is_operational', false,
      'is_visible', false,
      'is_available', false,
      'visibility_reason', 'missing',
      'user_roles', v_user_roles,
      'config_version', public.platform_feature_config_version()
    );
  end if;

  select *
  into v_rules
  from public.platform_feature_rules
  where feature_key = v_feature.feature_key;

  select *
  into v_channel
  from public.platform_feature_channels
  where feature_key = v_feature.feature_key
    and channel = v_feature_channel;

  v_is_live := public.platform_feature_status_is_live(
    v_feature.status,
    v_rules.schedule_start_at,
    v_rules.schedule_end_at,
    p_now
  );

  if coalesce(v_rules.dependency_config, '{}'::jsonb) ? 'requires_all' then
    select dependency.feature_key
    into v_dependency_blocker
    from (
      select value::text as feature_key
      from jsonb_array_elements_text(
        coalesce(v_rules.dependency_config -> 'requires_all', '[]'::jsonb)
      )
    ) as dependency
    where coalesce(
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
    limit 1;
  end if;

  v_roles_allowed := public.platform_roles_allow_access(
    coalesce(v_rules.role_restrictions, '[]'::jsonb),
    v_user_roles
  );

  v_auth_satisfied :=
    coalesce(v_rules.auth_required, false) = false
    or coalesce(p_is_authenticated, false);

  v_is_operational :=
    coalesce(v_feature.is_enabled, false)
    and coalesce(v_channel.is_enabled, false)
    and v_is_live
    and v_dependency_blocker is null;

  v_configured_visible :=
    coalesce(v_channel.is_visible, false)
    and coalesce(v_feature.status, 'inactive') <> 'hidden';

  v_is_visible := v_is_operational and v_configured_visible;
  v_is_available := v_is_operational and v_roles_allowed and v_auth_satisfied;

  v_visibility_reason := case
    when coalesce(v_feature.is_enabled, false) = false then 'globally_disabled'
    when coalesce(v_channel.is_enabled, false) = false then 'channel_disabled'
    when coalesce(v_feature.status, 'inactive') = 'hidden' then 'hidden'
    when coalesce(v_channel.is_visible, false) = false then 'channel_hidden'
    when not v_is_live then 'scheduled'
    when v_dependency_blocker is not null then 'dependency_blocked'
    when not v_roles_allowed then 'role_restricted'
    when not v_auth_satisfied then 'auth_required'
    else 'visible'
  end;

  return jsonb_build_object(
    'feature_key', v_feature.feature_key,
    'display_name', v_feature.display_name,
    'description', v_feature.description,
    'status', v_feature.status,
    'exists', true,
    'is_enabled', v_feature.is_enabled,
    'is_operational', v_is_operational,
    'is_visible', v_is_visible,
    'is_available', v_is_available,
    'is_configured_visible', v_configured_visible,
    'auth_required', coalesce(v_rules.auth_required, false),
    'auth_satisfied', v_auth_satisfied,
    'roles_allowed', v_roles_allowed,
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
    'is_schedule_live', v_is_live,
    'visibility_reason', v_visibility_reason,
    'user_roles', v_user_roles,
    'config_version', public.platform_feature_config_version(),
    'metadata',
      coalesce(v_feature.metadata, '{}'::jsonb)
      || jsonb_build_object(
        'channel_metadata',
        coalesce(v_channel.metadata, '{}'::jsonb)
      )
  );
end;
$$;


--
-- Name: reverse_or_refund_pool_if_match_cancelled(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reverse_or_refund_pool_if_match_cancelled(p_pool_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
  v_pool public.match_pools%ROWTYPE;
  v_match_status text;
  v_entry record;
  v_wallet_id uuid;
  v_before bigint;
  v_refunded bigint := 0;
BEGIN
  SELECT * INTO v_pool
  FROM public.match_pools
  WHERE id = p_pool_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pool not found';
  END IF;

  SELECT coalesce(status, match_status)
  INTO v_match_status
  FROM public.matches
  WHERE id = v_pool.match_id;

  IF v_match_status NOT IN ('cancelled', 'postponed') AND v_pool.status <> 'cancelled' THEN
    RAISE EXCEPTION 'Pool can only be mass-refunded when match or pool is cancelled/postponed';
  END IF;

  FOR v_entry IN
    SELECT *
    FROM public.match_pool_entries
    WHERE pool_id = p_pool_id
      AND status = 'active'
    ORDER BY created_at, id
  LOOP
    INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
    VALUES (v_entry.user_id, 0, 0)
    ON CONFLICT (user_id) DO NOTHING;

    SELECT id, available_balance_fet
    INTO v_wallet_id, v_before
    FROM public.fet_wallets
    WHERE user_id = v_entry.user_id
    FOR UPDATE;

    UPDATE public.fet_wallets
    SET available_balance_fet = available_balance_fet + v_entry.amount_fet,
        updated_at = timezone('utc', now())
    WHERE user_id = v_entry.user_id;

    UPDATE public.match_pool_entries
    SET status = 'refunded',
        payout_fet = v_entry.amount_fet,
        updated_at = timezone('utc', now())
    WHERE id = v_entry.id;

    INSERT INTO public.fet_wallet_transactions (
      wallet_id,
      user_id,
      tx_type,
      direction,
      amount_fet,
      balance_before_fet,
      balance_after_fet,
      reference_type,
      reference_id,
      source,
      match_id,
      pool_id,
      pool_entry_id,
      venue_id,
      title,
      metadata
    )
    VALUES (
      v_wallet_id,
      v_entry.user_id,
      'pool_refund',
      'credit',
      v_entry.amount_fet,
      coalesce(v_before, 0),
      coalesce(v_before, 0) + v_entry.amount_fet,
      'pool',
      p_pool_id::text,
      'pool_refund',
      v_pool.match_id,
      p_pool_id,
      v_entry.id,
      v_pool.venue_id,
      'Pool refunded because match was cancelled or postponed',
      jsonb_build_object('reason', v_match_status)
    );

    v_refunded := v_refunded + v_entry.amount_fet;
  END LOOP;

  UPDATE public.match_pools
  SET status = 'cancelled',
      updated_at = timezone('utc', now())
  WHERE id = p_pool_id;

  INSERT INTO public.match_pool_settlements (
    pool_id,
    status,
    total_paid_fet,
    idempotency_key,
    match_id,
    completed_at,
    metadata
  )
  VALUES (
    p_pool_id,
    'reversed',
    v_refunded,
    'pool-refund-cancelled-' || p_pool_id::text,
    v_pool.match_id,
    timezone('utc', now()),
    jsonb_build_object('reason', v_match_status, 'refunded_fet', v_refunded)
  )
  ON CONFLICT (pool_id) DO UPDATE
  SET status = 'reversed',
      total_paid_fet = EXCLUDED.total_paid_fet,
      completed_at = timezone('utc', now()),
      metadata = public.match_pool_settlements.metadata || EXCLUDED.metadata;

  PERFORM public.sports_bar_write_audit(
    'reverse_or_refund_pool_if_match_cancelled',
    'pool',
    p_pool_id::text,
    NULL,
    jsonb_build_object('refunded_fet', v_refunded, 'reason', v_match_status)
  );

  RETURN jsonb_build_object('status', 'refunded', 'pool_id', p_pool_id, 'refunded_fet', v_refunded);
END;
$$;


--
-- Name: rls_auto_enable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rls_auto_enable() RETURNS event_trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
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


--
-- Name: safe_catalog_key(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.safe_catalog_key(p_value text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT trim(both '-' FROM regexp_replace(lower(coalesce(p_value, '')), '[^a-z0-9]+', '-', 'g'));
$$;


--
-- Name: season_end_year(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.season_end_year(p_label text) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE
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


--
-- Name: season_sort_key(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.season_sort_key(p_season text) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT coalesce(
    substring(coalesce(p_season, '') FROM '([0-9]{4})')::integer,
    0
  );
$$;


--
-- Name: season_start_year(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.season_start_year(p_label text) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE
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


--
-- Name: send_push_to_user(uuid, text, text, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.send_push_to_user(p_user_id uuid, p_type text, p_title text, p_body text, p_data jsonb DEFAULT '{}'::jsonb) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: set_match_pool_social_card_url(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_match_pool_social_card_url(p_pool_id uuid, p_social_card_url text, p_metadata jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $_$
DECLARE
  v_user_id uuid := auth.uid();
  v_pool public.match_pools%ROWTYPE;
  v_url text := nullif(trim(coalesce(p_social_card_url, '')), '');
  v_is_service_role boolean := coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role';
BEGIN
  SELECT * INTO v_pool
  FROM public.match_pools
  WHERE id = p_pool_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pool not found';
  END IF;

  IF v_url IS NULL OR (v_url !~ '^https://.+$' AND v_url !~ '^/.+') THEN
    RAISE EXCEPTION 'Social card URL must be an HTTPS URL or a site-relative path';
  END IF;

  IF NOT (
    v_is_service_role
    OR public.is_admin_manager(v_user_id)
    OR (
      v_pool.venue_id IS NOT NULL
      AND public.venue_user_has_role(v_pool.venue_id)
    )
  ) THEN
    RAISE EXCEPTION 'Only admins or venue operators can set social card URLs';
  END IF;

  UPDATE public.match_pools
  SET social_card_url = v_url,
      metadata = metadata || jsonb_build_object(
        'social_card', coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object(
          'updated_by', v_user_id,
          'updated_at', timezone('utc', now())
        )
      ),
      updated_at = timezone('utc', now())
  WHERE id = p_pool_id;

  RETURN jsonb_build_object(
    'status', 'updated',
    'pool_id', p_pool_id,
    'social_card_url', v_url
  );
END;
$_$;


--
-- Name: set_row_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_row_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


--
-- Name: settle_finished_match_pools(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.settle_finished_match_pools(p_limit integer DEFAULT 50) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
  v_pool_id uuid;
  v_count int := 0;
BEGIN
  FOR v_pool_id IN
    SELECT p.id
    FROM public.match_pools p
    JOIN public.matches m ON m.id = p.match_id
    WHERE p.status IN ('open', 'locked')
      AND m.match_status = 'finished'
      AND m.result_code IS NOT NULL
    ORDER BY m.match_date, p.created_at
    LIMIT greatest(1, least(coalesce(p_limit, 50), 250))
  LOOP
    BEGIN
      PERFORM public.settle_match_pool(v_pool_id);
      v_count := v_count + 1;
    EXCEPTION
      WHEN OTHERS THEN
        INSERT INTO public.match_pool_settlements (
          pool_id,
          status,
          idempotency_key,
          metadata
        )
        VALUES (
          v_pool_id,
          'failed',
          'match-pool-settlement-' || v_pool_id::text,
          jsonb_build_object('error', SQLERRM, 'failed_at', timezone('utc', now()))
        )
        ON CONFLICT (pool_id) DO UPDATE
        SET status = 'failed',
            metadata = public.match_pool_settlements.metadata
              || jsonb_build_object('error', SQLERRM, 'failed_at', timezone('utc', now()));
    END;
  END LOOP;

  RETURN v_count;
END;
$$;


--
-- Name: settle_match_pool(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.settle_match_pool(p_pool_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
  v_pool public.match_pools%ROWTYPE;
  v_match public.matches%ROWTYPE;
  v_result_camp public.match_pool_camps%ROWTYPE;
  v_settlement public.match_pool_settlements%ROWTYPE;
  v_winner_count bigint := 0;
  v_winning_stake bigint := 0;
  v_total_active bigint := 0;
  v_losing_stake bigint := 0;
  v_distributable_losing bigint := 0;
  v_total_paid bigint := 0;
  v_bonus_allocated bigint := 0;
  v_bonus_share bigint := 0;
  v_payout bigint := 0;
  v_row_index bigint := 0;
  v_entry record;
BEGIN
  SELECT * INTO v_pool
  FROM public.match_pools
  WHERE id = p_pool_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pool not found';
  END IF;

  IF v_pool.status = 'settled' THEN
    RETURN jsonb_build_object(
      'status', 'already_settled',
      'pool_id', p_pool_id,
      'settled_at', v_pool.settled_at
    );
  END IF;

  IF v_pool.status = 'cancelled' THEN
    RAISE EXCEPTION 'Cancelled pools cannot be settled';
  END IF;

  SELECT *
  INTO v_settlement
  FROM public.match_pool_settlements
  WHERE pool_id = p_pool_id
  FOR UPDATE;

  IF FOUND AND v_settlement.status = 'completed' THEN
    UPDATE public.match_pools
    SET status = 'settled',
        settled_at = coalesce(settled_at, v_settlement.completed_at, timezone('utc', now()))
    WHERE id = p_pool_id;

    RETURN jsonb_build_object(
      'status', 'already_settled',
      'pool_id', p_pool_id,
      'settlement_id', v_settlement.id
    );
  END IF;

  IF v_pool.platform_fee_bps <> 0 OR v_pool.venue_fee_bps <> 0 THEN
    RAISE EXCEPTION 'Pool fees are not enabled for automated settlement yet';
  END IF;

  SELECT * INTO v_match
  FROM public.matches
  WHERE id = v_pool.match_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pool match not found';
  END IF;

  IF v_match.match_status <> 'finished' OR v_match.result_code IS NULL THEN
    RAISE EXCEPTION 'Match is not final';
  END IF;

  SELECT * INTO v_result_camp
  FROM public.match_pool_camps
  WHERE pool_id = p_pool_id
    AND result_code = v_match.result_code;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No pool camp maps to the final result';
  END IF;

  UPDATE public.match_pools
  SET status = 'settling',
      locked_at = coalesce(locked_at, timezone('utc', now())),
      result_camp_id = v_result_camp.id
  WHERE id = p_pool_id;

  SELECT
    count(*) FILTER (WHERE camp_id = v_result_camp.id),
    coalesce(sum(amount_fet) FILTER (WHERE camp_id = v_result_camp.id), 0),
    coalesce(sum(amount_fet), 0)
  INTO v_winner_count, v_winning_stake, v_total_active
  FROM public.match_pool_entries
  WHERE pool_id = p_pool_id
    AND status = 'active';

  v_losing_stake := greatest(v_total_active - v_winning_stake, 0);
  v_distributable_losing := v_losing_stake;

  IF v_settlement.id IS NULL THEN
    INSERT INTO public.match_pool_settlements (
      pool_id,
      status,
      result_camp_id,
      winners_count,
      losing_stake_fet,
      idempotency_key,
      metadata
    )
    VALUES (
      p_pool_id,
      'running',
      v_result_camp.id,
      v_winner_count,
      v_losing_stake,
      'match-pool-settlement-' || p_pool_id::text,
      jsonb_build_object(
        'match_id', v_pool.match_id,
        'venue_id', v_pool.venue_id,
        'result_code', v_match.result_code,
        'pending_supported', true
      )
    )
    RETURNING * INTO v_settlement;
  ELSE
    UPDATE public.match_pool_settlements
    SET status = 'running',
        result_camp_id = v_result_camp.id,
        winners_count = v_winner_count,
        losing_stake_fet = v_losing_stake,
        metadata = metadata || jsonb_build_object(
          'match_id', v_pool.match_id,
          'venue_id', v_pool.venue_id,
          'result_code', v_match.result_code,
          'pending_supported', true
        )
    WHERE id = v_settlement.id
    RETURNING * INTO v_settlement;
  END IF;

  IF v_total_active = 0 THEN
    UPDATE public.match_pool_settlements
    SET status = 'completed',
        completed_at = timezone('utc', now()),
        metadata = metadata || jsonb_build_object('empty_pool', true)
    WHERE id = v_settlement.id;

    UPDATE public.match_pools
    SET status = 'settled',
        settled_at = timezone('utc', now())
    WHERE id = p_pool_id;

    RETURN jsonb_build_object('status', 'settled_empty', 'pool_id', p_pool_id);
  END IF;

  IF v_winner_count = 0 THEN
    FOR v_entry IN
      SELECT *
      FROM public.match_pool_entries
      WHERE pool_id = p_pool_id
        AND status = 'active'
      ORDER BY created_at, id
    LOOP
      PERFORM public.wallet_post_transaction(
        p_user_id => v_entry.user_id,
        p_transaction_type => 'pool_stake',
        p_direction => 'debit',
        p_amount_fet => v_entry.amount_fet,
        p_balance_bucket => 'staked',
        p_idempotency_key => 'pool_stake_release:' || v_entry.id::text,
        p_reference_type => 'match_pool_entry',
        p_reference_id => v_entry.id::text,
        p_title => 'Pool stake released',
        p_metadata => jsonb_build_object('result_camp_id', v_result_camp.id, 'refund', true),
        p_match_id => v_pool.match_id,
        p_pool_id => p_pool_id,
        p_entry_id => v_entry.id,
        p_settlement_id => v_settlement.id,
        p_venue_id => v_pool.venue_id
      );

      PERFORM public.wallet_post_transaction(
        p_user_id => v_entry.user_id,
        p_transaction_type => 'pool_win',
        p_direction => 'credit',
        p_amount_fet => v_entry.amount_fet,
        p_balance_bucket => 'available',
        p_idempotency_key => 'pool_refund:' || v_entry.id::text,
        p_reference_type => 'match_pool',
        p_reference_id => p_pool_id::text,
        p_title => 'Pool refunded because no winning entries joined',
        p_metadata => jsonb_build_object('entry_id', v_entry.id, 'result_camp_id', v_result_camp.id),
        p_match_id => v_pool.match_id,
        p_pool_id => p_pool_id,
        p_entry_id => v_entry.id,
        p_settlement_id => v_settlement.id,
        p_venue_id => v_pool.venue_id
      );

      UPDATE public.match_pool_entries
      SET status = 'refunded',
          payout_fet = v_entry.amount_fet
      WHERE id = v_entry.id;

      v_total_paid := v_total_paid + v_entry.amount_fet;
    END LOOP;
  ELSE
    FOR v_entry IN
      SELECT *
      FROM public.match_pool_entries
      WHERE pool_id = p_pool_id
        AND status = 'active'
      ORDER BY created_at, id
    LOOP
      PERFORM public.wallet_post_transaction(
        p_user_id => v_entry.user_id,
        p_transaction_type => 'pool_stake',
        p_direction => 'debit',
        p_amount_fet => v_entry.amount_fet,
        p_balance_bucket => 'staked',
        p_idempotency_key => 'pool_stake_release:' || v_entry.id::text,
        p_reference_type => 'match_pool_entry',
        p_reference_id => v_entry.id::text,
        p_title => 'Pool stake settled',
        p_metadata => jsonb_build_object('result_camp_id', v_result_camp.id),
        p_match_id => v_pool.match_id,
        p_pool_id => p_pool_id,
        p_entry_id => v_entry.id,
        p_settlement_id => v_settlement.id,
        p_venue_id => v_pool.venue_id
      );

      IF v_entry.camp_id = v_result_camp.id THEN
        v_row_index := v_row_index + 1;

        IF v_row_index = v_winner_count THEN
          v_bonus_share := v_distributable_losing - v_bonus_allocated;
        ELSE
          v_bonus_share := floor((v_distributable_losing::numeric * v_entry.amount_fet::numeric) / greatest(v_winning_stake, 1)::numeric)::bigint;
        END IF;

        v_bonus_allocated := v_bonus_allocated + v_bonus_share;
        v_payout := v_entry.amount_fet + v_bonus_share;

        PERFORM public.wallet_post_transaction(
          p_user_id => v_entry.user_id,
          p_transaction_type => 'pool_win',
          p_direction => 'credit',
          p_amount_fet => v_payout,
          p_balance_bucket => 'pending',
          p_idempotency_key => 'pool_win_pending:' || v_entry.id::text,
          p_reference_type => 'match_pool',
          p_reference_id => p_pool_id::text,
          p_title => 'Pool win pending settlement',
          p_metadata => jsonb_build_object(
            'entry_id', v_entry.id,
            'winning_stake_returned_fet', v_entry.amount_fet,
            'losing_stake_share_fet', v_bonus_share,
            'result_camp_id', v_result_camp.id
          ),
          p_match_id => v_pool.match_id,
          p_pool_id => p_pool_id,
          p_entry_id => v_entry.id,
          p_settlement_id => v_settlement.id,
          p_venue_id => v_pool.venue_id,
          p_status => 'pending'
        );

        PERFORM public.wallet_post_transaction(
          p_user_id => v_entry.user_id,
          p_transaction_type => 'pool_win',
          p_direction => 'debit',
          p_amount_fet => v_payout,
          p_balance_bucket => 'pending',
          p_idempotency_key => 'pool_win_pending_release:' || v_entry.id::text,
          p_reference_type => 'match_pool',
          p_reference_id => p_pool_id::text,
          p_title => 'Pool win settlement finalized',
          p_metadata => jsonb_build_object('entry_id', v_entry.id),
          p_match_id => v_pool.match_id,
          p_pool_id => p_pool_id,
          p_entry_id => v_entry.id,
          p_settlement_id => v_settlement.id,
          p_venue_id => v_pool.venue_id
        );

        PERFORM public.wallet_post_transaction(
          p_user_id => v_entry.user_id,
          p_transaction_type => 'pool_win',
          p_direction => 'credit',
          p_amount_fet => v_payout,
          p_balance_bucket => 'available',
          p_idempotency_key => 'pool_win:' || v_entry.id::text,
          p_reference_type => 'match_pool',
          p_reference_id => p_pool_id::text,
          p_title => 'Won match pool',
          p_metadata => jsonb_build_object(
            'entry_id', v_entry.id,
            'winning_stake_returned_fet', v_entry.amount_fet,
            'losing_stake_share_fet', v_bonus_share,
            'result_camp_id', v_result_camp.id
          ),
          p_match_id => v_pool.match_id,
          p_pool_id => p_pool_id,
          p_entry_id => v_entry.id,
          p_settlement_id => v_settlement.id,
          p_venue_id => v_pool.venue_id
        );

        UPDATE public.match_pool_entries
        SET status = 'won',
            payout_fet = v_payout
        WHERE id = v_entry.id;

        v_total_paid := v_total_paid + v_payout;
      ELSE
        UPDATE public.match_pool_entries
        SET status = 'lost',
            payout_fet = 0
        WHERE id = v_entry.id;
      END IF;
    END LOOP;
  END IF;

  UPDATE public.match_pool_settlements
  SET status = 'completed',
      completed_at = timezone('utc', now()),
      total_paid_fet = v_total_paid,
      payout_per_winner_fet = CASE
        WHEN v_winner_count > 0 THEN floor(v_total_paid::numeric / v_winner_count::numeric)::bigint
        ELSE 0
      END,
      metadata = metadata || jsonb_build_object(
        'total_active_stake_fet', v_total_active,
        'winning_stake_fet', v_winning_stake,
        'settlement_formula', 'winner_stake_return_plus_pro_rata_losing_stake',
        'no_winners_refunded', v_winner_count = 0,
        'pending_settlement_rows_created', v_winner_count > 0
      )
  WHERE id = v_settlement.id;

  UPDATE public.match_pools
  SET status = 'settled',
      settled_at = timezone('utc', now()),
      result_camp_id = v_result_camp.id
  WHERE id = p_pool_id;

  RETURN jsonb_build_object(
    'status', 'settled',
    'pool_id', p_pool_id,
    'settlement_id', v_settlement.id,
    'result_camp_id', v_result_camp.id,
    'winner_count', v_winner_count,
    'losing_stake_fet', v_losing_stake,
    'total_paid_fet', v_total_paid
  );
END;
$$;


--
-- Name: settle_pool(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.settle_pool(p_pool_id uuid, p_idempotency_key text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
  v_pool public.match_pools%ROWTYPE;
  v_match public.matches%ROWTYPE;
  v_result jsonb;
BEGIN
  SELECT * INTO v_pool
  FROM public.match_pools
  WHERE id = p_pool_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pool not found';
  END IF;

  SELECT * INTO v_match
  FROM public.matches
  WHERE id = v_pool.match_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pool match not found';
  END IF;

  IF coalesce(v_match.status, CASE v_match.match_status WHEN 'finished' THEN 'final' ELSE v_match.match_status END) <> 'final' THEN
    RAISE EXCEPTION 'Pool cannot settle before final result';
  END IF;

  IF v_match.result_code IS NULL THEN
    UPDATE public.matches
    SET result_code = public.sports_bar_result_code(coalesce(home_score, home_goals), coalesce(away_score, away_goals)),
        winner_camp = public.sports_bar_winner_camp(public.sports_bar_result_code(coalesce(home_score, home_goals), coalesce(away_score, away_goals))),
        match_status = 'finished',
        status = 'final'
    WHERE id = v_match.id;
  END IF;

  v_result := public.settle_match_pool(p_pool_id);

  IF p_idempotency_key IS NOT NULL THEN
    UPDATE public.match_pool_settlements
    SET idempotency_key = p_idempotency_key
    WHERE pool_id = p_pool_id
      AND idempotency_key = 'match-pool-settlement-' || p_pool_id::text;
  END IF;

  UPDATE public.match_pool_settlements s
  SET match_id = v_pool.match_id,
      error_message = s.metadata ->> 'error'
  WHERE s.pool_id = p_pool_id;

  PERFORM public.sports_bar_write_audit('settle_pool', 'pool', p_pool_id::text, NULL, v_result);

  RETURN v_result;
END;
$$;


--
-- Name: spend_fet_on_order(uuid, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.spend_fet_on_order(p_order_id uuid, p_amount bigint) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
  v_order public.orders%ROWTYPE;
  v_wallet_id uuid;
  v_before bigint;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be positive';
  END IF;

  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF v_order.user_id IS DISTINCT FROM auth.uid() AND coalesce(auth.role(), '') <> 'service_role' THEN
    RAISE EXCEPTION 'Users can only spend FET on their own orders';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.venues v
    WHERE v.id = v_order.venue_id
      AND v.accepts_fet_spend = true
  ) THEN
    RAISE EXCEPTION 'This venue does not accept FET spend';
  END IF;

  INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
  VALUES (v_order.user_id, 0, 0)
  ON CONFLICT (user_id) DO NOTHING;

  SELECT id, available_balance_fet
  INTO v_wallet_id, v_before
  FROM public.fet_wallets
  WHERE user_id = v_order.user_id
  FOR UPDATE;

  IF coalesce(v_before, 0) < p_amount THEN
    RAISE EXCEPTION 'Insufficient FET balance';
  END IF;

  UPDATE public.fet_wallets
  SET available_balance_fet = available_balance_fet - p_amount,
      updated_at = timezone('utc', now())
  WHERE user_id = v_order.user_id;

  UPDATE public.orders
  SET fet_spent = fet_spent + p_amount,
      payment_fet_amount = payment_fet_amount + p_amount,
      payment_status = CASE
        WHEN payment_status::text = 'paid' THEN payment_status
        ELSE 'partially_paid'::public.venue_payment_status
      END,
      updated_at = timezone('utc', now())
  WHERE id = p_order_id;

  INSERT INTO public.fet_wallet_transactions (
    wallet_id,
    user_id,
    tx_type,
    direction,
    amount_fet,
    balance_before_fet,
    balance_after_fet,
    reference_type,
    reference_id,
    source,
    order_id,
    venue_id,
    title,
    metadata
  )
  VALUES (
    v_wallet_id,
    v_order.user_id,
    'order_spend',
    'debit',
    p_amount,
    coalesce(v_before, 0),
    coalesce(v_before, 0) - p_amount,
    'order',
    p_order_id::text,
    'order_spend',
    p_order_id,
    v_order.venue_id,
    'FET spent on venue order',
    '{}'::jsonb
  );

  RETURN jsonb_build_object('status', 'spent', 'order_id', p_order_id, 'amount', p_amount);
END;
$$;


--
-- Name: spend_fet_on_order(uuid, bigint, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.spend_fet_on_order(p_order_id uuid, p_amount_fet bigint, p_idempotency_key text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_config jsonb;
  v_fet_per_eur numeric := greatest(public.app_config_numeric('fet_per_eur', 100), 1);
  v_rwf_per_eur numeric := greatest(public.app_config_numeric('rwf_per_eur', 1500), 1);
  v_fet_per_currency numeric;
  v_converted numeric;
  v_outstanding numeric;
  v_result jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_amount_fet IS NULL OR p_amount_fet <= 0 THEN
    RAISE EXCEPTION 'FET amount must be greater than zero';
  END IF;

  SELECT *
  INTO v_order
  FROM public.orders
  WHERE id = p_order_id
    AND user_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF v_order.status::text = 'cancelled'
     OR v_order.payment_status::text IN ('cancelled', 'refunded') THEN
    RAISE EXCEPTION 'Cancelled or refunded orders cannot use FET';
  END IF;

  v_config := public.get_venue_fet_reward_config(v_order.venue_id);
  IF NOT coalesce((v_config ->> 'accepts_fet_spend')::boolean, false) THEN
    RAISE EXCEPTION 'This venue does not accept FET spending';
  END IF;

  v_fet_per_currency := coalesce(
    nullif(v_config ->> 'redemption_fet_per_currency', '')::numeric,
    CASE
      WHEN v_order.currency_code = 'RWF' THEN v_fet_per_eur / v_rwf_per_eur
      ELSE v_fet_per_eur
    END
  );

  IF v_fet_per_currency <= 0 THEN
    RAISE EXCEPTION 'Venue FET redemption rule is invalid';
  END IF;

  v_converted := round((p_amount_fet::numeric / v_fet_per_currency), 2);
  v_outstanding := greatest(v_order.total_amount - coalesce(v_order.payment_fet_converted_amount, 0), 0);

  IF v_converted > v_outstanding THEN
    RAISE EXCEPTION 'FET spend exceeds outstanding order balance';
  END IF;

  v_result := public.wallet_post_transaction(
    p_user_id => v_user_id,
    p_transaction_type => 'order_spend',
    p_direction => 'debit',
    p_amount_fet => p_amount_fet,
    p_balance_bucket => 'available',
    p_idempotency_key => coalesce(p_idempotency_key, 'order_spend:' || p_order_id::text || ':' || v_user_id::text || ':' || p_amount_fet::text),
    p_reference_type => 'order',
    p_reference_id => p_order_id::text,
    p_title => 'FET spent on bar order',
    p_metadata => jsonb_build_object(
      'currency_code', v_order.currency_code,
      'converted_amount', v_converted,
      'fet_per_currency', v_fet_per_currency
    ),
    p_order_id => p_order_id,
    p_venue_id => v_order.venue_id
  );

  UPDATE public.orders
  SET payment_fet_amount = coalesce(payment_fet_amount, 0) + p_amount_fet,
      payment_fet_converted_amount = coalesce(payment_fet_converted_amount, 0) + v_converted,
      updated_at = timezone('utc', now())
  WHERE id = p_order_id;

  RETURN v_result || jsonb_build_object('converted_amount', v_converted);
END;
$$;


--
-- Name: sports_bar_is_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sports_bar_is_admin() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
  SELECT
    coalesce(auth.role(), '') = 'service_role'
    OR EXISTS (
      SELECT 1
      FROM public.admin_users au
      WHERE au.user_id = auth.uid()
        AND coalesce(au.is_active, true) = true
        AND au.role IN ('super_admin', 'admin')
    );
$$;


--
-- Name: sports_bar_prevent_early_settlement(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sports_bar_prevent_early_settlement() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_match_status text;
BEGIN
  SELECT coalesce(m.status, CASE m.match_status WHEN 'finished' THEN 'final' ELSE m.match_status END)
  INTO v_match_status
  FROM public.match_pools p
  JOIN public.matches m ON m.id = p.match_id
  WHERE p.id = NEW.pool_id;

  IF NEW.status IN ('running', 'completed')
     AND coalesce(v_match_status, '') <> 'final' THEN
    RAISE EXCEPTION 'Pool cannot settle before final result';
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: sports_bar_prevent_late_pool_entry(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sports_bar_prevent_late_pool_entry() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_pool public.match_pools%ROWTYPE;
  v_starts_at timestamptz;
BEGIN
  SELECT * INTO v_pool
  FROM public.match_pools
  WHERE id = NEW.pool_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pool not found';
  END IF;

  SELECT coalesce(starts_at, match_date)
  INTO v_starts_at
  FROM public.matches
  WHERE id = v_pool.match_id;

  IF v_pool.status <> 'open' OR (v_starts_at IS NOT NULL AND v_starts_at <= timezone('utc', now())) THEN
    RAISE EXCEPTION 'Pool is locked and cannot accept stakes';
  END IF;

  IF NEW.user_id IS DISTINCT FROM auth.uid() AND coalesce(auth.role(), '') <> 'service_role' THEN
    RAISE EXCEPTION 'Users can only create their own pool entries';
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: sports_bar_result_code(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sports_bar_result_code(p_home_score integer, p_away_score integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE
    WHEN p_home_score IS NULL OR p_away_score IS NULL THEN NULL
    WHEN p_home_score > p_away_score THEN 'H'
    WHEN p_home_score < p_away_score THEN 'A'
    ELSE 'D'
  END;
$$;


--
-- Name: sports_bar_set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sports_bar_set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = timezone('utc', now());
  RETURN NEW;
END;
$$;


--
-- Name: sports_bar_sync_wallet_aliases(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sports_bar_sync_wallet_aliases() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.id IS NULL THEN
    NEW.id := extensions.gen_random_uuid();
  END IF;

  NEW.balance_available := NEW.available_balance_fet;
  NEW.balance_staked := NEW.locked_balance_fet;
  NEW.balance_pending := coalesce(NEW.balance_pending, 0);
  NEW.updated_at := timezone('utc', now());
  RETURN NEW;
END;
$$;


--
-- Name: sports_bar_winner_camp(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sports_bar_winner_camp(p_result_code text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE p_result_code
    WHEN 'H' THEN 'home'
    WHEN 'D' THEN 'draw'
    WHEN 'A' THEN 'away'
    ELSE NULL
  END;
$$;


--
-- Name: sports_bar_write_audit(text, text, text, jsonb, jsonb, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sports_bar_write_audit(p_action text, p_entity_type text, p_entity_id text DEFAULT NULL::text, p_before_json jsonb DEFAULT NULL::jsonb, p_after_json jsonb DEFAULT NULL::jsonb, p_actor_user_id uuid DEFAULT NULL::uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
DECLARE
  v_id uuid;
  v_actor uuid := coalesce(p_actor_user_id, auth.uid());
BEGIN
  INSERT INTO public.audit_logs (
    actor_user_id,
    actor_role,
    action,
    entity_type,
    entity_id,
    before_json,
    after_json
  )
  VALUES (
    v_actor,
    coalesce(auth.role(), current_user),
    p_action,
    p_entity_type,
    p_entity_id,
    p_before_json,
    p_after_json
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;


--
-- Name: stake_fet(uuid, uuid, bigint, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.stake_fet(p_pool_id uuid, p_camp_id uuid, p_stake_amount bigint, p_source text DEFAULT 'direct'::text, p_invite_code text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT public.join_pool(p_pool_id, p_camp_id, p_stake_amount, p_source, p_invite_code);
$$;


--
-- Name: sync_profile_auth_state(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_profile_auth_state(p_user_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
declare
  v_auth_method text;
  v_is_anonymous boolean;
  v_phone text;
begin
  if p_user_id is null then
    raise exception 'User ID is required';
  end if;

  v_auth_method := public.auth_user_auth_method(p_user_id);
  v_is_anonymous := public.auth_user_is_anonymous(p_user_id);
  v_phone := public.resolve_auth_user_phone(p_user_id);

  insert into public.profiles (
    id,
    user_id,
    phone_number,
    is_anonymous,
    auth_method,
    created_at,
    updated_at
  )
  values (
    p_user_id,
    p_user_id,
    case when v_is_anonymous then null else v_phone end,
    v_is_anonymous,
    v_auth_method,
    timezone('utc', now()),
    timezone('utc', now())
  )
  on conflict (id) do update
  set user_id = excluded.user_id,
      phone_number = case
        when excluded.is_anonymous then profiles.phone_number
        else coalesce(excluded.phone_number, profiles.phone_number)
      end,
      is_anonymous = excluded.is_anonymous,
      auth_method = coalesce(nullif(excluded.auth_method, ''), profiles.auth_method),
      updated_at = timezone('utc', now());
end;
$$;


--
-- Name: sync_public_feature_flags_from_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_public_feature_flags_from_admin() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
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


--
-- Name: sync_runtime_feature_flags_from_platform(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_runtime_feature_flags_from_platform(p_feature_key text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: sync_runtime_feature_flags_on_platform_write(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_runtime_feature_flags_on_platform_write() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  PERFORM public.sync_runtime_feature_flags_from_platform(
    coalesce(NEW.feature_key, OLD.feature_key)
  );
  RETURN coalesce(NEW, OLD);
END;
$$;


--
-- Name: transfer_fet(text, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.transfer_fet(p_recipient_identifier text, p_amount_fet bigint) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: transfer_fet_by_fan_id(text, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.transfer_fet_by_fan_id(p_recipient_fan_id text, p_amount_fet bigint) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
DECLARE
  v_sender_id uuid := auth.uid();
  v_sender_fan_id text;
  v_recipient_id uuid;
  v_daily_limit integer := greatest(
    least(coalesce(public.app_config_bigint('wallet_transfer_daily_limit', 10), 10), 2147483647)::integer,
    1
  );
  v_clean_fan_id text := regexp_replace(coalesce(p_recipient_fan_id, ''), '[^0-9]', '', 'g');
  v_transfer_id text := extensions.gen_random_uuid()::text;
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

  PERFORM public.wallet_post_transaction(
    p_user_id => v_sender_id,
    p_transaction_type => 'transfer',
    p_direction => 'debit',
    p_amount_fet => p_amount_fet,
    p_balance_bucket => 'available',
    p_idempotency_key => 'transfer:' || v_transfer_id || ':sender',
    p_reference_type => 'transfer',
    p_reference_id => v_clean_fan_id,
    p_title => 'Transfer to Fan #' || v_clean_fan_id
  );

  PERFORM public.wallet_post_transaction(
    p_user_id => v_recipient_id,
    p_transaction_type => 'transfer',
    p_direction => 'credit',
    p_amount_fet => p_amount_fet,
    p_balance_bucket => 'available',
    p_idempotency_key => 'transfer:' || v_transfer_id || ':recipient',
    p_reference_type => 'transfer',
    p_reference_id => coalesce(v_sender_fan_id, '000000'),
    p_title => 'Transfer from Fan #' || coalesce(v_sender_fan_id, '000000')
  );

  RETURN jsonb_build_object(
    'success', true,
    'recipient_fan_id', v_clean_fan_id,
    'amount_fet', p_amount_fet
  );
END;
$_$;


--
-- Name: update_match_live_score(text, integer, integer, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_match_live_score(p_match_id text, p_home_score integer, p_away_score integer, p_status text DEFAULT 'live'::text, p_source text DEFAULT 'manual'::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_before jsonb;
  v_after jsonb;
  v_result_code text;
BEGIN
  IF NOT public.sports_bar_is_admin() THEN
    RAISE EXCEPTION 'Only admins can update match scores';
  END IF;

  IF p_status NOT IN ('scheduled', 'live', 'final', 'cancelled', 'postponed') THEN
    RAISE EXCEPTION 'Invalid match status';
  END IF;

  SELECT to_jsonb(m) INTO v_before
  FROM public.matches m
  WHERE id = p_match_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Match not found';
  END IF;

  v_result_code := CASE
    WHEN p_status = 'final' THEN public.sports_bar_result_code(p_home_score, p_away_score)
    ELSE NULL
  END;

  UPDATE public.matches
  SET status = p_status,
      match_status = CASE WHEN p_status = 'final' THEN 'finished' ELSE p_status END,
      home_score = p_home_score,
      away_score = p_away_score,
      live_home_score = p_home_score,
      live_away_score = p_away_score,
      home_goals = CASE WHEN p_status = 'final' THEN p_home_score ELSE home_goals END,
      away_goals = CASE WHEN p_status = 'final' THEN p_away_score ELSE away_goals END,
      result_code = coalesce(v_result_code, result_code),
      winner_camp = coalesce(public.sports_bar_winner_camp(v_result_code), winner_camp),
      source = coalesce(p_source, source),
      updated_at = timezone('utc', now())
  WHERE id = p_match_id
  RETURNING to_jsonb(matches.*) INTO v_after;

  PERFORM public.sports_bar_write_audit('update_match_live_score', 'match', p_match_id, v_before, v_after);

  IF p_status = 'live' THEN
    PERFORM public.lock_pool_for_match_start(p_match_id);
  END IF;

  RETURN jsonb_build_object('status', 'updated', 'match', v_after);
END;
$$;


--
-- Name: update_venue_fet_reward_config(uuid, numeric, text, boolean, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_venue_fet_reward_config(p_venue_id uuid, p_reward_percent numeric DEFAULT NULL::numeric, p_reward_trigger text DEFAULT NULL::text, p_accepts_fet_spend boolean DEFAULT NULL::boolean, p_redemption_fet_per_currency numeric DEFAULT NULL::numeric) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_patch jsonb;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT (
    public.venue_user_has_role(p_venue_id, ARRAY['owner', 'manager']::public.venue_user_role[])
    OR public.is_admin_manager(v_actor)
  ) THEN
    RAISE EXCEPTION 'Only venue owners, managers, or admins can update FET rewards';
  END IF;

  IF p_reward_percent IS NOT NULL AND (p_reward_percent < 0 OR p_reward_percent > 100) THEN
    RAISE EXCEPTION 'Reward percentage must be between 0 and 100';
  END IF;

  IF p_reward_trigger IS NOT NULL AND p_reward_trigger NOT IN ('paid', 'served') THEN
    RAISE EXCEPTION 'Reward trigger must be paid or served';
  END IF;

  IF p_redemption_fet_per_currency IS NOT NULL AND p_redemption_fet_per_currency <= 0 THEN
    RAISE EXCEPTION 'Redemption rate must be greater than zero';
  END IF;

  v_patch := jsonb_strip_nulls(jsonb_build_object(
    'fet_reward_percent', p_reward_percent,
    'fet_reward_trigger', p_reward_trigger,
    'accepts_fet_spend', p_accepts_fet_spend,
    'fet_redemption_fet_per_currency', p_redemption_fet_per_currency
  ));

  UPDATE public.venues
  SET features_json = coalesce(features_json, '{}'::jsonb) || v_patch,
      updated_at = timezone('utc', now())
  WHERE id = p_venue_id;

  RETURN public.get_venue_fet_reward_config(p_venue_id);
END;
$$;


--
-- Name: upsert_team_form_feature(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.upsert_team_form_feature(p_match_id text, p_team_id text) RETURNS void
    LANGUAGE plpgsql
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


--
-- Name: upsert_vault_secret(text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.upsert_vault_secret(p_name text, p_secret text, p_description text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'vault'
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


--
-- Name: venue_credit_fet_from_order(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.venue_credit_fet_from_order() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     AND (
       NEW.payment_status IS DISTINCT FROM OLD.payment_status
       OR NEW.status IS DISTINCT FROM OLD.status
     ) THEN
    PERFORM public.credit_fet_for_order(NEW.id);
  ELSIF TG_OP = 'INSERT' THEN
    PERFORM public.credit_fet_for_order(NEW.id);
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'FET order reward skipped for order %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;


--
-- Name: venue_endorse_pool(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.venue_endorse_pool(p_pool_id uuid, p_venue_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_before jsonb;
  v_after jsonb;
BEGIN
  IF NOT public.venue_user_has_role(p_venue_id, ARRAY['owner', 'manager']::public.venue_user_role[]) THEN
    RAISE EXCEPTION 'Only venue managers can endorse pools';
  END IF;

  SELECT to_jsonb(p) INTO v_before
  FROM public.match_pools p
  WHERE p.id = p_pool_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Pool not found';
  END IF;

  UPDATE public.match_pools
  SET venue_id = p_venue_id,
      scope = 'venue',
      metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('endorsed_by_venue_id', p_venue_id, 'endorsed_at', timezone('utc', now())),
      updated_at = timezone('utc', now())
  WHERE id = p_pool_id
  RETURNING to_jsonb(match_pools.*) INTO v_after;

  PERFORM public.sports_bar_write_audit('venue_endorse_pool', 'pool', p_pool_id::text, v_before, v_after);

  RETURN jsonb_build_object('status', 'endorsed', 'pool_id', p_pool_id, 'venue_id', p_venue_id);
END;
$$;


--
-- Name: venue_pool_match_options(uuid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.venue_pool_match_options(p_venue_id uuid, p_limit integer DEFAULT 50) RETURNS TABLE(match_id text, match_label text, competition_name text, kickoff_at timestamp with time zone, match_status text, country_code text, venue_id uuid, curation_reason text, priority_score integer, official_pool_id uuid)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT
    cm.match_id,
    coalesce(m.home_team, 'Home') || ' vs ' || coalesce(m.away_team, 'Away') AS match_label,
    m.competition_name,
    m.match_date AS kickoff_at,
    coalesce(m.match_status, m.status) AS match_status,
    cm.country_code,
    cm.venue_id,
    cm.reason AS curation_reason,
    cm.priority_score,
    existing.id AS official_pool_id
  FROM public.curated_matches cm
  JOIN public.app_matches m ON m.id = cm.match_id
  LEFT JOIN public.match_pools existing
    ON existing.match_id = cm.match_id
   AND existing.venue_id = p_venue_id
   AND existing.scope = 'venue'
   AND existing.is_official = true
   AND existing.status <> 'cancelled'
  WHERE public.venue_user_has_role(p_venue_id)
    AND cm.is_active = true
    AND (cm.starts_at IS NULL OR cm.starts_at <= timezone('utc', now()))
    AND (cm.expires_at IS NULL OR cm.expires_at > timezone('utc', now()))
    AND (cm.venue_id = p_venue_id OR cm.venue_id IS NULL)
    AND m.match_date > timezone('utc', now()) - interval '2 hours'
    AND coalesce(m.match_status, m.status) IN ('scheduled', 'upcoming', 'not_started', 'pending')
  ORDER BY
    CASE WHEN cm.venue_id = p_venue_id THEN 0 ELSE 1 END,
    cm.priority_score DESC,
    m.match_date ASC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 100));
$$;


--
-- Name: venue_reject_client_order_updates(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.venue_reject_client_order_updates() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  request_role text := coalesce(
    auth.role(),
    current_setting('request.jwt.claim.role', true),
    ''
  );
BEGIN
  IF TG_OP <> 'UPDATE' THEN
    RETURN NEW;
  END IF;

  IF request_role = 'service_role'
     OR current_user IN ('postgres', 'supabase_admin', 'service_role') THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'Order updates must use approved audited service functions'
    USING ERRCODE = '42501';
END;
$$;


--
-- Name: venue_set_order_timestamps(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.venue_set_order_timestamps() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = timezone('utc', now());

  IF tg_op = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
    NEW.status_changed_at = timezone('utc', now());

    IF NEW.status = 'received' AND OLD.accepted_at IS NULL THEN
      NEW.accepted_at = timezone('utc', now());
    END IF;

    IF NEW.status = 'served' AND OLD.served_at IS NULL THEN
      NEW.served_at = timezone('utc', now());
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: venue_set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.venue_set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = timezone('utc', now());
  RETURN NEW;
END;
$$;


--
-- Name: venue_sync_owner_membership(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.venue_sync_owner_membership() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  -- Deactivate old owner membership
  IF tg_op = 'UPDATE'
     AND OLD.owner_id IS DISTINCT FROM NEW.owner_id
     AND OLD.owner_id IS NOT NULL
  THEN
    UPDATE public.venue_users
    SET is_active = false,
        updated_at = timezone('utc', now())
    WHERE venue_id = NEW.id
      AND user_id = OLD.owner_id
      AND role = 'owner';
  END IF;

  -- Upsert new owner membership
  IF NEW.owner_id IS NOT NULL THEN
    INSERT INTO public.venue_users (venue_id, user_id, role, is_active)
    VALUES (NEW.id, NEW.owner_id, 'owner', true)
    ON CONFLICT (venue_id, user_id) DO UPDATE
    SET role = 'owner',
        is_active = true,
        updated_at = timezone('utc', now());
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: venue_user_has_role(uuid, public.venue_user_role[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.venue_user_has_role(target_venue_id uuid, allowed_roles public.venue_user_role[] DEFAULT ARRAY['owner'::public.venue_user_role, 'manager'::public.venue_user_role, 'staff'::public.venue_user_role]) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.venue_users vu
    WHERE vu.venue_id = target_venue_id
      AND vu.user_id = auth.uid()
      AND vu.is_active = true
      AND vu.role = ANY(allowed_roles)
  );
$$;


--
-- Name: wallet_balance_from_ledger(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.wallet_balance_from_ledger(p_user_id uuid) RETURNS TABLE(available_fet bigint, staked_fet bigint, pending_fet bigint, spent_fet bigint, earned_fet bigint)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  WITH tx AS (
    SELECT
      coalesce(transaction_type, tx_type) AS transaction_type,
      direction,
      amount_fet,
      coalesce(balance_bucket, 'available') AS balance_bucket,
      coalesce(status, 'posted') AS status
    FROM public.fet_wallet_transactions
    WHERE user_id = p_user_id
      AND coalesce(status, 'posted') <> 'voided'
  )
  SELECT
    coalesce(sum(
      CASE
        WHEN status = 'posted' AND balance_bucket = 'available' AND direction = 'credit' THEN amount_fet
        WHEN status = 'posted' AND balance_bucket = 'available' AND direction = 'debit' THEN -amount_fet
        ELSE 0
      END
    ), 0)::bigint AS available_fet,
    coalesce(sum(
      CASE
        WHEN status = 'posted' AND balance_bucket = 'staked' AND direction = 'credit' THEN amount_fet
        WHEN status = 'posted' AND balance_bucket = 'staked' AND direction = 'debit' THEN -amount_fet
        ELSE 0
      END
    ), 0)::bigint AS staked_fet,
    coalesce(sum(
      CASE
        WHEN balance_bucket = 'pending' AND direction = 'credit' THEN amount_fet
        WHEN balance_bucket = 'pending' AND direction = 'debit' THEN -amount_fet
        ELSE 0
      END
    ), 0)::bigint AS pending_fet,
    coalesce(sum(
      CASE
        WHEN status = 'posted'
          AND balance_bucket = 'available'
          AND direction = 'debit'
          AND transaction_type IN ('pool_stake', 'order_spend', 'transfer', 'admin_adjustment')
          THEN amount_fet
        ELSE 0
      END
    ), 0)::bigint AS spent_fet,
    coalesce(sum(
      CASE
        WHEN status = 'posted'
          AND balance_bucket = 'available'
          AND direction = 'credit'
          AND transaction_type IN ('welcome_credit', 'order_earn', 'creator_reward', 'pool_win', 'transfer', 'admin_adjustment')
          THEN amount_fet
        ELSE 0
      END
    ), 0)::bigint AS earned_fet
  FROM tx;
$$;


--
-- Name: wallet_post_transaction(uuid, text, text, bigint, text, text, text, text, text, jsonb, uuid, text, uuid, uuid, uuid, uuid, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.wallet_post_transaction(p_user_id uuid, p_transaction_type text, p_direction text, p_amount_fet bigint, p_balance_bucket text DEFAULT 'available'::text, p_idempotency_key text DEFAULT NULL::text, p_reference_type text DEFAULT NULL::text, p_reference_id text DEFAULT NULL::text, p_title text DEFAULT NULL::text, p_metadata jsonb DEFAULT '{}'::jsonb, p_order_id uuid DEFAULT NULL::uuid, p_match_id text DEFAULT NULL::text, p_pool_id uuid DEFAULT NULL::uuid, p_entry_id uuid DEFAULT NULL::uuid, p_settlement_id uuid DEFAULT NULL::uuid, p_venue_id uuid DEFAULT NULL::uuid, p_status text DEFAULT 'posted'::text, p_created_by uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
  v_wallet public.fet_wallets%ROWTYPE;
  v_existing public.fet_wallet_transactions%ROWTYPE;
  v_tx public.fet_wallet_transactions%ROWTYPE;
  v_before bigint := 0;
  v_after bigint := 0;
  v_bucket text := coalesce(nullif(trim(p_balance_bucket), ''), 'available');
  v_status text := coalesce(nullif(trim(p_status), ''), 'posted');
  v_type text := nullif(trim(coalesce(p_transaction_type, '')), '');
  v_source text;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'User id is required';
  END IF;

  IF v_type IS NULL THEN
    RAISE EXCEPTION 'Transaction type is required';
  END IF;

  IF p_direction NOT IN ('credit', 'debit') THEN
    RAISE EXCEPTION 'Transaction direction must be credit or debit';
  END IF;

  IF p_amount_fet IS NULL OR p_amount_fet <= 0 THEN
    RAISE EXCEPTION 'FET amount must be greater than zero';
  END IF;

  IF v_bucket NOT IN ('available', 'staked', 'pending') THEN
    RAISE EXCEPTION 'Unsupported wallet bucket: %', v_bucket;
  END IF;

  IF v_status NOT IN ('posted', 'pending', 'voided') THEN
    RAISE EXCEPTION 'Unsupported wallet transaction status: %', v_status;
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT *
    INTO v_existing
    FROM public.fet_wallet_transactions
    WHERE idempotency_key = p_idempotency_key
    LIMIT 1;

    IF FOUND THEN
      PERFORM public.reconcile_fet_wallet(p_user_id);
      RETURN jsonb_build_object(
        'status', 'idempotent_replay',
        'transaction_id', v_existing.id,
        'user_id', v_existing.user_id,
        'transaction_type', coalesce(v_existing.transaction_type, v_existing.tx_type),
        'amount_fet', v_existing.amount_fet
      );
    END IF;
  END IF;

  PERFORM public.reconcile_fet_wallet(p_user_id);

  SELECT *
  INTO v_wallet
  FROM public.fet_wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_bucket = 'available' THEN
    v_before := coalesce(v_wallet.available_balance_fet, 0);
  ELSIF v_bucket = 'staked' THEN
    v_before := coalesce(v_wallet.staked_balance_fet, 0);
  ELSE
    v_before := coalesce(v_wallet.pending_balance_fet, 0);
  END IF;

  IF p_direction = 'debit' AND v_status <> 'voided' AND v_before < p_amount_fet THEN
    RAISE EXCEPTION 'Insufficient FET balance'
      USING ERRCODE = 'P0001',
            DETAIL = format('bucket=%s available=%s required=%s', v_bucket, v_before, p_amount_fet);
  END IF;

  IF p_direction = 'credit'
     AND v_status = 'posted'
     AND v_bucket = 'available'
     AND v_type IN ('welcome_credit', 'order_earn', 'creator_reward', 'admin_adjustment') THEN
    PERFORM public.assert_fet_mint_within_cap(p_amount_fet, v_type);
  END IF;

  v_after := CASE
    WHEN v_status = 'voided' THEN v_before
    WHEN p_direction = 'credit' THEN v_before + p_amount_fet
    ELSE v_before - p_amount_fet
  END;
  v_source := coalesce(nullif(trim(p_reference_type), ''), v_type);

  BEGIN
    INSERT INTO public.fet_wallet_transactions (
      user_id,
      tx_type,
      transaction_type,
      direction,
      amount_fet,
      balance_before_fet,
      balance_after_fet,
      reference_type,
      reference_id,
      source,
      match_id,
      pool_id,
      order_id,
      entry_id,
      settlement_id,
      venue_id,
      balance_bucket,
      status,
      idempotency_key,
      created_by,
      title,
      metadata
    )
    VALUES (
      p_user_id,
      v_type,
      v_type,
      p_direction,
      p_amount_fet,
      v_before,
      v_after,
      p_reference_type,
      p_reference_id,
      v_source,
      p_match_id,
      p_pool_id,
      p_order_id,
      p_entry_id,
      p_settlement_id,
      p_venue_id,
      v_bucket,
      v_status,
      p_idempotency_key,
      p_created_by,
      p_title,
      coalesce(p_metadata, '{}'::jsonb)
    )
    RETURNING * INTO v_tx;
  EXCEPTION
    WHEN unique_violation THEN
      IF p_idempotency_key IS NULL THEN
        RAISE;
      END IF;

      SELECT *
      INTO v_tx
      FROM public.fet_wallet_transactions
      WHERE idempotency_key = p_idempotency_key
      LIMIT 1;
  END;

  PERFORM public.reconcile_fet_wallet(p_user_id);

  RETURN jsonb_build_object(
    'status', CASE WHEN v_tx.idempotency_key = p_idempotency_key THEN 'posted' ELSE 'posted' END,
    'transaction_id', v_tx.id,
    'user_id', v_tx.user_id,
    'transaction_type', coalesce(v_tx.transaction_type, v_tx.tx_type),
    'direction', v_tx.direction,
    'amount_fet', v_tx.amount_fet,
    'balance_bucket', v_tx.balance_bucket
  );
END;
$$;


--
-- Name: write_match_pool_operation_audit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.write_match_pool_operation_audit() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
  v_actor_user_id uuid := auth.uid();
  v_action text := lower(TG_OP) || '_match_pool';
  v_pool_id uuid;
  v_venue_id uuid;
  v_match_id text;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_pool_id := OLD.id;
    v_venue_id := OLD.venue_id;
    v_match_id := OLD.match_id;
  ELSE
    v_pool_id := NEW.id;
    v_venue_id := NEW.venue_id;
    v_match_id := NEW.match_id;
  END IF;

  INSERT INTO public.pool_operation_audit_logs (
    actor_user_id,
    action,
    pool_id,
    venue_id,
    match_id,
    before_state,
    after_state,
    metadata
  )
  VALUES (
    v_actor_user_id,
    v_action,
    v_pool_id,
    v_venue_id,
    v_match_id,
    CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
    CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END,
    jsonb_build_object(
      'table', TG_TABLE_NAME,
      'op', TG_OP,
      'request_role', coalesce(current_setting('request.jwt.claim.role', true), '')
    )
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: account_deletion_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_deletion_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    reason text NOT NULL,
    contact_email text,
    resolution_notes text,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    processed_at timestamp with time zone,
    processed_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT account_deletion_requests_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'in_review'::text, 'completed'::text, 'rejected'::text, 'cancelled'::text])))
);


--
-- Name: admin_audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_audit_logs (
    id bigint NOT NULL,
    admin_user_id uuid,
    action text NOT NULL,
    module text DEFAULT ''::text NOT NULL,
    target_type text DEFAULT ''::text NOT NULL,
    target_id text DEFAULT ''::text NOT NULL,
    before_state jsonb DEFAULT '{}'::jsonb,
    after_state jsonb DEFAULT '{}'::jsonb,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: admin_audit_logs_enriched; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.admin_audit_logs_enriched AS
 SELECT al.id,
    al.admin_user_id,
    al.action,
    al.module,
    al.target_type,
    al.target_id,
    al.before_state,
    al.after_state,
    al.metadata,
    al.created_at,
    au.display_name AS admin_name,
    au.phone AS admin_phone
   FROM (public.admin_audit_logs al
     LEFT JOIN public.admin_users au ON ((au.id = al.admin_user_id)))
  WHERE public.is_active_admin_operator(auth.uid());


--
-- Name: admin_audit_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.admin_audit_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: admin_audit_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.admin_audit_logs_id_seq OWNED BY public.admin_audit_logs.id;


--
-- Name: feature_flags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feature_flags (
    key text NOT NULL,
    market text DEFAULT 'global'::text NOT NULL,
    platform text DEFAULT 'all'::text NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    rollout_pct integer DEFAULT 100 NOT NULL,
    description text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT feature_flags_market_check CHECK ((market ~ '^[a-z_]+$'::text)),
    CONSTRAINT feature_flags_platform_check CHECK ((platform = ANY (ARRAY['all'::text, 'android'::text, 'ios'::text, 'web'::text]))),
    CONSTRAINT feature_flags_rollout_check CHECK (((rollout_pct >= 0) AND (rollout_pct <= 100)))
);


--
-- Name: platform_features; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.platform_features (
    feature_key text NOT NULL,
    display_name text NOT NULL,
    description text,
    status text DEFAULT 'active'::text NOT NULL,
    is_enabled boolean DEFAULT true NOT NULL,
    navigation_group text,
    default_route_key text,
    admin_notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT platform_features_status_check CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text, 'hidden'::text, 'beta'::text, 'scheduled'::text])))
);


--
-- Name: admin_feature_flags; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.admin_feature_flags AS
 SELECT ((((ff.key || ':'::text) || ff.market) || ':'::text) || ff.platform) AS id,
    ff.key,
    initcap(replace(ff.key, '_'::text, ' '::text)) AS label,
    ff.description,
    ff.enabled AS is_enabled,
    ff.market,
    split_part(ff.key, '_'::text, 1) AS module,
    jsonb_build_object('platform', ff.platform, 'rollout_pct', ff.rollout_pct) AS config,
    NULL::uuid AS updated_by,
    ff.updated_at AS created_at,
    ff.updated_at
   FROM (public.feature_flags ff
     LEFT JOIN public.platform_features pf ON ((pf.feature_key = ff.key)))
  WHERE ((pf.feature_key IS NULL) AND public.is_active_admin_operator(auth.uid()));


--
-- Name: platform_content_blocks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.platform_content_blocks (
    block_key text NOT NULL,
    block_type text NOT NULL,
    title text NOT NULL,
    content jsonb DEFAULT '{}'::jsonb NOT NULL,
    target_channel text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 100 NOT NULL,
    feature_key text,
    placement_key text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT platform_content_blocks_target_channel_check CHECK ((target_channel = ANY (ARRAY['mobile'::text, 'web'::text, 'both'::text])))
);


--
-- Name: admin_platform_content_blocks; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.admin_platform_content_blocks AS
 SELECT pcb.block_key AS id,
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
   FROM (public.platform_content_blocks pcb
     LEFT JOIN public.platform_features pf ON ((pf.feature_key = pcb.feature_key)))
  WHERE public.is_active_admin_operator(auth.uid());


--
-- Name: platform_feature_channels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.platform_feature_channels (
    feature_key text NOT NULL,
    channel text NOT NULL,
    is_visible boolean DEFAULT true NOT NULL,
    is_enabled boolean DEFAULT true NOT NULL,
    show_in_navigation boolean DEFAULT false NOT NULL,
    show_on_home boolean DEFAULT false NOT NULL,
    sort_order integer DEFAULT 100 NOT NULL,
    route_key text,
    entry_key text,
    navigation_label text,
    placement_key text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT platform_feature_channels_channel_check CHECK ((channel = ANY (ARRAY['mobile'::text, 'web'::text])))
);


--
-- Name: platform_feature_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.platform_feature_rules (
    feature_key text NOT NULL,
    auth_required boolean DEFAULT false NOT NULL,
    role_restrictions jsonb DEFAULT '[]'::jsonb NOT NULL,
    dependency_config jsonb DEFAULT '{}'::jsonb NOT NULL,
    rollout_config jsonb DEFAULT '{}'::jsonb NOT NULL,
    schedule_start_at timestamp with time zone,
    schedule_end_at timestamp with time zone,
    geo_config jsonb DEFAULT '{}'::jsonb NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: admin_platform_features; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.admin_platform_features AS
 SELECT pf.feature_key AS id,
    pf.feature_key,
    pf.display_name,
    pf.description,
    pf.status,
    pf.is_enabled,
    pf.navigation_group,
    pf.default_route_key,
    pf.admin_notes,
    pf.metadata,
    COALESCE(pfr.auth_required, false) AS auth_required,
    COALESCE(pfr.role_restrictions, '[]'::jsonb) AS role_restrictions,
    COALESCE(pfr.dependency_config, '{}'::jsonb) AS dependency_config,
    COALESCE(pfr.rollout_config, '{}'::jsonb) AS rollout_config,
    pfr.schedule_start_at,
    pfr.schedule_end_at,
    jsonb_build_object('channel', 'mobile', 'is_visible', COALESCE(pfc_mobile.is_visible, false), 'is_enabled', COALESCE(pfc_mobile.is_enabled, false), 'show_in_navigation', COALESCE(pfc_mobile.show_in_navigation, false), 'show_on_home', COALESCE(pfc_mobile.show_on_home, false), 'sort_order', COALESCE(pfc_mobile.sort_order, 100), 'route_key', pfc_mobile.route_key, 'entry_key', pfc_mobile.entry_key, 'navigation_label', pfc_mobile.navigation_label, 'placement_key', pfc_mobile.placement_key, 'metadata', COALESCE(pfc_mobile.metadata, '{}'::jsonb)) AS mobile_channel,
    jsonb_build_object('channel', 'web', 'is_visible', COALESCE(pfc_web.is_visible, false), 'is_enabled', COALESCE(pfc_web.is_enabled, false), 'show_in_navigation', COALESCE(pfc_web.show_in_navigation, false), 'show_on_home', COALESCE(pfc_web.show_on_home, false), 'sort_order', COALESCE(pfc_web.sort_order, 100), 'route_key', pfc_web.route_key, 'entry_key', pfc_web.entry_key, 'navigation_label', pfc_web.navigation_label, 'placement_key', pfc_web.placement_key, 'metadata', COALESCE(pfc_web.metadata, '{}'::jsonb)) AS web_channel,
    pf.created_at,
    GREATEST(pf.updated_at, COALESCE(pfr.updated_at, pf.updated_at), COALESCE(pfc_mobile.updated_at, pf.updated_at), COALESCE(pfc_web.updated_at, pf.updated_at)) AS updated_at
   FROM (((public.platform_features pf
     LEFT JOIN public.platform_feature_rules pfr ON ((pfr.feature_key = pf.feature_key)))
     LEFT JOIN public.platform_feature_channels pfc_mobile ON (((pfc_mobile.feature_key = pf.feature_key) AND (pfc_mobile.channel = 'mobile'::text))))
     LEFT JOIN public.platform_feature_channels pfc_web ON (((pfc_web.feature_key = pf.feature_key) AND (pfc_web.channel = 'web'::text))))
  WHERE public.is_active_admin_operator(auth.uid());


--
-- Name: anonymous_upgrade_claims; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.anonymous_upgrade_claims (
    anon_user_id uuid NOT NULL,
    claim_token text NOT NULL,
    issued_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    consumed_at timestamp with time zone,
    consumed_by_user_id uuid
);


--
-- Name: competitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.competitions (
    id text NOT NULL,
    name text NOT NULL,
    short_name text NOT NULL,
    country text NOT NULL,
    tier integer DEFAULT 1,
    data_source text NOT NULL,
    source_file text,
    seasons text[] DEFAULT '{}'::text[] NOT NULL,
    team_count integer,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    season text,
    status text DEFAULT 'active'::text NOT NULL,
    is_featured boolean DEFAULT false NOT NULL,
    region text,
    competition_type text,
    event_tag text,
    start_date date,
    end_date date,
    country_or_region text,
    is_international boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    country_id uuid,
    type text,
    priority integer DEFAULT 100 NOT NULL,
    CONSTRAINT competitions_tier_top_flight_only CHECK ((tier = 1))
);


--
-- Name: COLUMN competitions.region; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.competitions.region IS 'global, africa, europe, americas';


--
-- Name: COLUMN competitions.competition_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.competitions.competition_type IS 'league, cup, tournament, friendly, qualifier';


--
-- Name: COLUMN competitions.event_tag; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.competitions.event_tag IS 'Links to featured_events.event_tag (e.g. worldcup2026, ucl-final-2026)';


--
-- Name: matches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.matches (
    id text NOT NULL,
    competition_id text NOT NULL,
    home_team_id text,
    away_team_id text,
    venue text,
    source_url text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    live_home_score integer,
    live_away_score integer,
    live_minute integer,
    live_phase text,
    last_live_checked_at timestamp with time zone,
    last_live_sync_confidence numeric(5,4),
    last_live_review_required boolean DEFAULT false NOT NULL,
    is_home_featured boolean DEFAULT false NOT NULL,
    hide_from_home boolean DEFAULT false NOT NULL,
    home_feature_rank integer DEFAULT 0 NOT NULL,
    season_id text,
    stage text,
    matchday_or_round text,
    match_date timestamp with time zone NOT NULL,
    home_goals integer,
    away_goals integer,
    result_code text,
    match_status text DEFAULT 'scheduled'::text NOT NULL,
    is_neutral boolean DEFAULT false NOT NULL,
    source_name text,
    notes text,
    starts_at timestamp with time zone,
    status text,
    home_score integer,
    away_score integer,
    winner_camp text,
    source text,
    is_curated boolean DEFAULT false NOT NULL,
    country_visibility text[] DEFAULT '{}'::text[] NOT NULL,
    CONSTRAINT matches_away_score_check CHECK (((away_score IS NULL) OR (away_score >= 0))),
    CONSTRAINT matches_distinct_teams CHECK (((home_team_id IS NULL) OR (away_team_id IS NULL) OR (home_team_id <> away_team_id))),
    CONSTRAINT matches_home_score_check CHECK (((home_score IS NULL) OR (home_score >= 0))),
    CONSTRAINT matches_last_live_sync_confidence_check CHECK (((last_live_sync_confidence IS NULL) OR ((last_live_sync_confidence >= (0)::numeric) AND (last_live_sync_confidence <= (1)::numeric)))),
    CONSTRAINT matches_live_away_score_check CHECK (((live_away_score IS NULL) OR (live_away_score >= 0))),
    CONSTRAINT matches_live_home_score_check CHECK (((live_home_score IS NULL) OR (live_home_score >= 0))),
    CONSTRAINT matches_live_minute_check CHECK (((live_minute IS NULL) OR ((live_minute >= 0) AND (live_minute <= 200)))),
    CONSTRAINT matches_match_status_canonical CHECK ((match_status = ANY (ARRAY['scheduled'::text, 'live'::text, 'finished'::text, 'postponed'::text, 'cancelled'::text]))),
    CONSTRAINT matches_result_code_check CHECK (((result_code IS NULL) OR (result_code = ANY (ARRAY['H'::text, 'D'::text, 'A'::text])))),
    CONSTRAINT matches_winner_camp_check CHECK (((winner_camp IS NULL) OR (winner_camp = ANY (ARRAY['home'::text, 'draw'::text, 'away'::text]))))
);


--
-- Name: app_competitions; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.app_competitions AS
 SELECT c.id,
    c.name,
    COALESCE(NULLIF(TRIM(BOTH FROM c.short_name), ''::text), c.name) AS short_name,
    c.country_or_region AS country,
    COALESCE(c.tier,
        CASE
            WHEN (c.competition_type = 'league'::text) THEN 1
            ELSE 2
        END) AS tier,
    c.competition_type,
    c.is_international,
    c.is_active,
    c.created_at,
    c.updated_at,
    current_season.id AS current_season_id,
    current_season.season_label AS current_season_label,
    count(m.id) FILTER (WHERE (m.match_date >= now())) AS future_match_count
   FROM ((public.competitions c
     LEFT JOIN LATERAL ( SELECT s.id,
            s.season_label
           FROM public.seasons s
          WHERE ((s.competition_id = c.id) AND (s.is_current = true))
          ORDER BY s.start_year DESC
         LIMIT 1) current_season ON (true))
     LEFT JOIN public.matches m ON ((m.competition_id = c.id)))
  GROUP BY c.id, c.name, c.short_name, c.country_or_region, c.tier, c.competition_type, c.is_international, c.is_active, c.created_at, c.updated_at, current_season.id, current_season.season_label;


--
-- Name: app_competitions_ranked; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.app_competitions_ranked AS
 SELECT ac.id,
    ac.name,
    ac.short_name,
    ac.country,
    ac.tier,
    ac.competition_type,
    ac.is_international,
    ac.is_active,
    ac.created_at,
    ac.updated_at,
    ac.current_season_id,
    ac.current_season_label,
    ac.future_match_count,
        CASE
            WHEN (lower(ac.name) ~~ '%premier league%'::text) THEN (1)::bigint
            WHEN (lower(ac.name) ~~ '%champions league%'::text) THEN (2)::bigint
            WHEN (lower(ac.name) ~~ '%la liga%'::text) THEN (3)::bigint
            WHEN (lower(ac.name) ~~ '%serie a%'::text) THEN (4)::bigint
            WHEN (lower(ac.name) ~~ '%bundesliga%'::text) THEN (5)::bigint
            WHEN (lower(ac.name) ~~ '%ligue 1%'::text) THEN (6)::bigint
            WHEN ac.is_international THEN (20)::bigint
            ELSE (100 + row_number() OVER (ORDER BY ac.name))
        END AS catalog_rank
   FROM public.app_competitions ac;


--
-- Name: app_config_remote; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_config_remote (
    key text NOT NULL,
    value jsonb DEFAULT 'null'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    description text
);


--
-- Name: app_matches; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.app_matches AS
 SELECT m.id,
    m.competition_id,
    c.name AS competition_name,
    m.season_id,
    s.season_label,
    m.stage,
    m.matchday_or_round AS round,
    m.matchday_or_round,
    m.match_date,
    m.match_date AS date,
    to_char((m.match_date AT TIME ZONE 'UTC'::text), 'HH24:MI'::text) AS kickoff_time,
    m.home_team_id,
    ht.name AS home_team,
    COALESCE(ht.crest_url, ht.logo_url) AS home_logo_url,
    m.away_team_id,
    at.name AS away_team,
    COALESCE(at.crest_url, at.logo_url) AS away_logo_url,
    m.home_goals AS ft_home,
    m.away_goals AS ft_away,
    m.home_goals,
    m.away_goals,
    m.result_code,
        CASE
            WHEN (m.match_status = ANY (ARRAY['scheduled'::text, 'not_started'::text, 'pending'::text])) THEN 'upcoming'::text
            WHEN (m.match_status = ANY (ARRAY['live'::text, 'in_play'::text, 'in_progress'::text, 'playing'::text])) THEN 'live'::text
            WHEN (m.match_status = ANY (ARRAY['finished'::text, 'complete'::text, 'completed'::text, 'full_time'::text, 'ft'::text])) THEN 'finished'::text
            ELSE COALESCE(NULLIF(lower(m.match_status), ''::text), 'upcoming'::text)
        END AS status,
    m.match_status,
    m.is_neutral,
    m.source_name AS data_source,
    m.source_name,
    m.source_url,
    m.notes,
    m.created_at,
    m.updated_at,
    m.live_home_score,
    m.live_away_score,
    m.live_minute,
    m.live_phase,
    m.last_live_checked_at,
    m.last_live_sync_confidence,
    m.last_live_review_required
   FROM ((((public.matches m
     LEFT JOIN public.competitions c ON ((c.id = m.competition_id)))
     LEFT JOIN public.seasons s ON ((s.id = m.season_id)))
     LEFT JOIN public.teams ht ON ((ht.id = m.home_team_id)))
     LEFT JOIN public.teams at ON ((at.id = m.away_team_id)));


--
-- Name: app_runtime_errors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_runtime_errors (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    session_id text,
    reason text NOT NULL,
    error_message text NOT NULL,
    stack_trace text,
    platform text,
    app_version text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_logs (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL,
    actor_user_id uuid,
    actor_role text,
    action text NOT NULL,
    entity_type text NOT NULL,
    entity_id text,
    before_json jsonb,
    after_json jsonb,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: bell_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bell_requests (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL,
    venue_id uuid NOT NULL,
    table_id uuid NOT NULL,
    user_id uuid DEFAULT auth.uid() NOT NULL,
    message text,
    acknowledged_at timestamp with time zone,
    acknowledged_by uuid,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: countries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.countries (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL,
    name text NOT NULL,
    iso_code text NOT NULL,
    region text DEFAULT 'global'::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    rollout_priority integer DEFAULT 100 NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT countries_iso_code_check CHECK ((iso_code ~ '^[A-Z]{2}$'::text)),
    CONSTRAINT countries_name_check CHECK (((char_length(TRIM(BOTH FROM name)) >= 2) AND (char_length(TRIM(BOTH FROM name)) <= 120))),
    CONSTRAINT countries_rollout_priority_check CHECK ((rollout_priority >= 0))
);


--
-- Name: TABLE countries; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.countries IS 'Canonical country rollout catalog for venues, country pools, teams, and curated match visibility.';


--
-- Name: country_currency_map; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.country_currency_map (
    country_code text NOT NULL,
    currency_code text NOT NULL,
    country_name text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT country_currency_map_country_code_format CHECK ((country_code ~ '^[A-Z]{2}$'::text)),
    CONSTRAINT country_currency_map_currency_code_format CHECK ((currency_code ~ '^[A-Z]{3}$'::text))
);


--
-- Name: country_region_map; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.country_region_map (
    country_code text NOT NULL,
    region text DEFAULT 'global'::text NOT NULL,
    country_name text NOT NULL,
    flag_emoji text DEFAULT '🌍'::text NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT country_region_map_code_format CHECK ((country_code ~ '^[A-Z]{2}$'::text)),
    CONSTRAINT country_region_map_region_check CHECK ((region = ANY (ARRAY['africa'::text, 'europe'::text, 'americas'::text, 'north_america'::text, 'global'::text])))
);


--
-- Name: cron_job_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cron_job_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    job_name text NOT NULL,
    status text DEFAULT 'running'::text NOT NULL,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    duration_ms integer,
    result jsonb DEFAULT '{}'::jsonb,
    error_message text,
    CONSTRAINT cron_job_log_status_check CHECK ((status = ANY (ARRAY['running'::text, 'completed'::text, 'failed'::text])))
);


--
-- Name: curated_matches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.curated_matches (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL,
    match_id text NOT NULL,
    country_code text,
    venue_id uuid,
    priority_score integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    reason text DEFAULT ''::text NOT NULL,
    curated_by uuid,
    starts_at timestamp with time zone,
    expires_at timestamp with time zone,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT curated_matches_country_code_format CHECK (((country_code IS NULL) OR (country_code ~ '^[A-Z]{2}$'::text))),
    CONSTRAINT curated_matches_window_check CHECK (((expires_at IS NULL) OR (starts_at IS NULL) OR (expires_at > starts_at)))
);


--
-- Name: currency_display_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.currency_display_metadata (
    currency_code text NOT NULL,
    symbol text NOT NULL,
    decimals integer DEFAULT 2 NOT NULL,
    space_separated boolean DEFAULT false NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT currency_display_code_format CHECK ((currency_code ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT currency_display_decimals CHECK (((decimals >= 0) AND (decimals <= 4)))
);


--
-- Name: currency_rates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.currency_rates (
    base_currency text DEFAULT 'EUR'::text NOT NULL,
    target_currency text NOT NULL,
    rate numeric NOT NULL,
    source text DEFAULT 'manual'::text NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    raw_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT currency_rates_base_format CHECK ((base_currency ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT currency_rates_rate_check CHECK ((rate > (0)::numeric)),
    CONSTRAINT currency_rates_target_format CHECK ((target_currency ~ '^[A-Z]{3}$'::text))
);


--
-- Name: device_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.device_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token text NOT NULL,
    platform text NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT device_tokens_platform_check CHECK ((platform = ANY (ARRAY['ios'::text, 'android'::text, 'web'::text])))
);


--
-- Name: fan_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fan_id_seq
    START WITH 100000
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: featured_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.featured_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    short_name text NOT NULL,
    event_tag text NOT NULL,
    region text DEFAULT 'global'::text NOT NULL,
    competition_id text,
    start_date timestamp with time zone NOT NULL,
    end_date timestamp with time zone NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    banner_color text,
    description text,
    logo_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    headline text,
    cta_label text,
    cta_route text,
    priority_score integer DEFAULT 0 NOT NULL,
    audience_regions text[] DEFAULT ARRAY['global'::text] NOT NULL,
    CONSTRAINT featured_events_date_range CHECK ((end_date > start_date)),
    CONSTRAINT featured_events_region_check CHECK ((region = ANY (ARRAY['global'::text, 'africa'::text, 'europe'::text, 'americas'::text, 'north_america'::text])))
);


--
-- Name: fet_wallet_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fet_wallet_transactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    tx_type text NOT NULL,
    direction text NOT NULL,
    amount_fet bigint NOT NULL,
    balance_before_fet bigint,
    balance_after_fet bigint,
    reference_type text,
    reference_id text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    title text,
    source text,
    match_id text,
    pool_id uuid,
    order_id uuid,
    venue_id uuid,
    transaction_type text,
    balance_bucket text DEFAULT 'available'::text NOT NULL,
    status text DEFAULT 'posted'::text NOT NULL,
    idempotency_key text,
    entry_id uuid,
    settlement_id uuid,
    created_by uuid,
    wallet_id uuid,
    pool_entry_id uuid,
    CONSTRAINT fet_wallet_transactions_bucket_check CHECK ((balance_bucket = ANY (ARRAY['available'::text, 'staked'::text, 'pending'::text]))),
    CONSTRAINT fet_wallet_transactions_direction_check CHECK ((direction = ANY (ARRAY['credit'::text, 'debit'::text]))),
    CONSTRAINT fet_wallet_transactions_positive_amount CHECK ((amount_fet > 0)),
    CONSTRAINT fet_wallet_transactions_status_check CHECK ((status = ANY (ARRAY['posted'::text, 'pending'::text, 'voided'::text])))
);


--
-- Name: COLUMN fet_wallet_transactions.source; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.fet_wallet_transactions.source IS 'Canonical product source for ledger rows, e.g. order_reward, match_pool_entry, match_pool_settlement.';


--
-- Name: COLUMN fet_wallet_transactions.match_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.fet_wallet_transactions.match_id IS 'Match context for FET wallet credits/debits.';


--
-- Name: COLUMN fet_wallet_transactions.pool_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.fet_wallet_transactions.pool_id IS 'Pool context for FET wallet credits/debits.';


--
-- Name: COLUMN fet_wallet_transactions.order_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.fet_wallet_transactions.order_id IS 'Order context for FET wallet credits/debits.';


--
-- Name: COLUMN fet_wallet_transactions.venue_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.fet_wallet_transactions.venue_id IS 'Venue context for FET wallet credits/debits.';


--
-- Name: fet_ledger; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.fet_ledger WITH (security_invoker='true') AS
 SELECT tx.id,
    tx.wallet_id,
    tx.user_id,
        CASE tx.tx_type
            WHEN 'wallet_welcome_bonus'::text THEN 'welcome_credit'::text
            WHEN 'welcome_bonus'::text THEN 'welcome_credit'::text
            WHEN 'order_reward'::text THEN 'order_earn'::text
            WHEN 'order_earn'::text THEN 'order_earn'::text
            WHEN 'order_spend'::text THEN 'order_spend'::text
            WHEN 'match_pool_entry'::text THEN 'pool_stake'::text
            WHEN 'pool_stake'::text THEN 'pool_stake'::text
            WHEN 'match_pool_settlement'::text THEN 'pool_win'::text
            WHEN 'pool_win'::text THEN 'pool_win'::text
            WHEN 'match_pool_refund'::text THEN 'pool_refund'::text
            WHEN 'pool_refund'::text THEN 'pool_refund'::text
            WHEN 'creator_reward'::text THEN 'creator_reward'::text
            WHEN 'settlement_fee'::text THEN 'settlement_fee'::text
            WHEN 'admin_credit'::text THEN 'admin_adjustment'::text
            WHEN 'admin_debit'::text THEN 'admin_adjustment'::text
            ELSE tx.tx_type
        END AS transaction_type,
    tx.amount_fet AS amount,
    tx.direction,
    tx.status,
    tx.order_id,
    tx.pool_id,
    tx.pool_entry_id,
    tx.match_id,
    tx.venue_id,
    tx.metadata AS metadata_json,
    tx.created_at
   FROM public.fet_wallet_transactions tx;


--
-- Name: VIEW fet_ledger; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.fet_ledger IS 'Canonical FET wallet ledger over public.fet_wallet_transactions.';


--
-- Name: fet_wallets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fet_wallets (
    user_id uuid NOT NULL,
    available_balance_fet bigint DEFAULT 0 NOT NULL,
    locked_balance_fet bigint DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    staked_balance_fet bigint DEFAULT 0 NOT NULL,
    pending_balance_fet bigint DEFAULT 0 NOT NULL,
    id uuid DEFAULT extensions.gen_random_uuid(),
    balance_available bigint DEFAULT 0 NOT NULL,
    balance_staked bigint DEFAULT 0 NOT NULL,
    balance_pending bigint DEFAULT 0 NOT NULL,
    CONSTRAINT fet_wallets_balance_available_check CHECK ((balance_available >= 0)),
    CONSTRAINT fet_wallets_balance_pending_check CHECK ((balance_pending >= 0)),
    CONSTRAINT fet_wallets_balance_staked_check CHECK ((balance_staked >= 0))
);


--
-- Name: fet_supply_overview; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.fet_supply_overview AS
 SELECT COALESCE(sum(fet_wallets.available_balance_fet), (0)::numeric) AS total_available,
    COALESCE(sum((fet_wallets.staked_balance_fet + fet_wallets.pending_balance_fet)), (0)::numeric) AS total_locked,
    COALESCE(sum(((fet_wallets.available_balance_fet + fet_wallets.staked_balance_fet) + fet_wallets.pending_balance_fet)), (0)::numeric) AS total_supply,
    count(*) AS total_wallets,
    count(*) FILTER (WHERE (fet_wallets.available_balance_fet > 0)) AS active_wallets,
    (COALESCE(avg(fet_wallets.available_balance_fet), (0)::numeric))::bigint AS avg_balance,
    COALESCE(max(fet_wallets.available_balance_fet), (0)::bigint) AS max_balance,
    (public.fet_supply_cap())::numeric AS supply_cap,
    GREATEST(((public.fet_supply_cap())::numeric - COALESCE(sum(((fet_wallets.available_balance_fet + fet_wallets.staked_balance_fet) + fet_wallets.pending_balance_fet)), (0)::numeric)), (0)::numeric) AS remaining_mintable
   FROM public.fet_wallets;


--
-- Name: fet_supply_overview_admin; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.fet_supply_overview_admin AS
 SELECT fet_supply_overview.total_available,
    fet_supply_overview.total_locked,
    fet_supply_overview.total_supply,
    fet_supply_overview.total_wallets,
    fet_supply_overview.active_wallets,
    fet_supply_overview.avg_balance,
    fet_supply_overview.max_balance,
    fet_supply_overview.supply_cap,
    fet_supply_overview.remaining_mintable
   FROM public.fet_supply_overview
  WHERE public.is_active_admin_operator(auth.uid());


--
-- Name: fet_transactions_admin; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.fet_transactions_admin AS
 SELECT tx.id,
    tx.user_id,
    tx.tx_type,
    tx.direction,
    tx.amount_fet,
    tx.balance_before_fet,
    tx.balance_after_fet,
    tx.reference_type,
    tx.reference_id,
    tx.metadata,
    tx.created_at,
    tx.title,
    COALESCE(NULLIF(TRIM(BOTH FROM (u.raw_user_meta_data ->> 'display_name'::text)), ''::text), NULLIF(TRIM(BOTH FROM (u.raw_user_meta_data ->> 'full_name'::text)), ''::text), NULLIF(split_part(COALESCE(u.email, ''::text), '@'::text, 1), ''::text), NULLIF(u.phone, ''::text), (tx.user_id)::text) AS display_name,
    COALESCE(((tx.metadata ->> 'flagged'::text))::boolean, false) AS flagged,
    COALESCE(tx.transaction_type, tx.tx_type) AS transaction_type,
    tx.balance_bucket,
    tx.status,
    tx.idempotency_key,
    tx.source,
    tx.match_id,
    tx.pool_id,
    tx.order_id,
    tx.entry_id,
    tx.settlement_id,
    tx.venue_id,
    tx.created_by
   FROM (public.fet_wallet_transactions tx
     LEFT JOIN auth.users u ON ((u.id = tx.user_id)))
  WHERE public.is_active_admin_operator(auth.uid());


--
-- Name: launch_moments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.launch_moments (
    tag text NOT NULL,
    title text NOT NULL,
    subtitle text NOT NULL,
    kicker text NOT NULL,
    region_key text DEFAULT 'global'::text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT launch_moments_region_check CHECK ((region_key = ANY (ARRAY['africa'::text, 'europe'::text, 'americas'::text, 'north_america'::text, 'global'::text])))
);


--
-- Name: match_alert_dispatch_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.match_alert_dispatch_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    match_id text NOT NULL,
    alert_type text NOT NULL,
    dispatch_key text NOT NULL,
    live_event_id text,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    dispatched_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: match_alert_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.match_alert_subscriptions (
    user_id uuid NOT NULL,
    match_id text NOT NULL,
    alert_kickoff boolean DEFAULT true NOT NULL,
    alert_goals boolean DEFAULT true NOT NULL,
    alert_result boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: match_pool_camps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.match_pool_camps (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL,
    pool_id uuid NOT NULL,
    code text NOT NULL,
    label text NOT NULL,
    result_code text,
    display_order integer DEFAULT 0 NOT NULL,
    member_count bigint DEFAULT 0 NOT NULL,
    total_staked_fet bigint DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    camp_key text,
    team_id text,
    is_winning_camp boolean DEFAULT false NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT match_pool_camps_code_check CHECK (((char_length(TRIM(BOTH FROM code)) >= 1) AND (char_length(TRIM(BOTH FROM code)) <= 32))),
    CONSTRAINT match_pool_camps_label_check CHECK (((char_length(TRIM(BOTH FROM label)) >= 1) AND (char_length(TRIM(BOTH FROM label)) <= 120))),
    CONSTRAINT match_pool_camps_member_count_check CHECK ((member_count >= 0)),
    CONSTRAINT match_pool_camps_result_code_check CHECK (((result_code IS NULL) OR (result_code = ANY (ARRAY['H'::text, 'D'::text, 'A'::text])))),
    CONSTRAINT match_pool_camps_total_staked_fet_check CHECK ((total_staked_fet >= 0))
);


--
-- Name: match_pool_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.match_pool_entries (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL,
    pool_id uuid NOT NULL,
    camp_id uuid NOT NULL,
    user_id uuid NOT NULL,
    amount_fet bigint NOT NULL,
    status public.match_pool_entry_status DEFAULT 'active'::public.match_pool_entry_status NOT NULL,
    payout_fet bigint DEFAULT 0 NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    source text DEFAULT 'direct'::text NOT NULL,
    invited_by_user_id uuid,
    CONSTRAINT match_pool_entries_amount_fet_check CHECK ((amount_fet > 0)),
    CONSTRAINT match_pool_entries_payout_fet_check CHECK ((payout_fet >= 0))
);


--
-- Name: TABLE match_pool_entries; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.match_pool_entries IS 'Pool entries are wallet-backed. Authenticated clients read entries through RLS and create/cancel through backend functions, not direct table writes.';


--
-- Name: match_pool_invites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.match_pool_invites (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL,
    pool_id uuid NOT NULL,
    inviter_user_id uuid NOT NULL,
    invitee_user_id uuid,
    joined_entry_id uuid,
    invite_code text DEFAULT lower(substr(replace((extensions.gen_random_uuid())::text, '-'::text, ''::text), 1, 16)) NOT NULL,
    status text DEFAULT 'created'::text NOT NULL,
    reward_tx_id uuid,
    reward_amount_fet bigint DEFAULT 0 NOT NULL,
    expires_at timestamp with time zone,
    joined_at timestamp with time zone,
    rewarded_at timestamp with time zone,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT match_pool_invites_reward_amount_fet_check CHECK ((reward_amount_fet >= 0)),
    CONSTRAINT match_pool_invites_status_check CHECK ((status = ANY (ARRAY['created'::text, 'joined'::text, 'rewarded'::text, 'cancelled'::text, 'expired'::text])))
);


--
-- Name: match_pool_settlements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.match_pool_settlements (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL,
    pool_id uuid NOT NULL,
    status public.match_pool_settlement_status DEFAULT 'running'::public.match_pool_settlement_status NOT NULL,
    result_camp_id uuid,
    winners_count bigint DEFAULT 0 NOT NULL,
    losing_stake_fet bigint DEFAULT 0 NOT NULL,
    total_paid_fet bigint DEFAULT 0 NOT NULL,
    payout_per_winner_fet bigint DEFAULT 0 NOT NULL,
    idempotency_key text NOT NULL,
    started_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    completed_at timestamp with time zone,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    match_id text,
    error_message text,
    reversed_at timestamp with time zone,
    CONSTRAINT match_pool_settlements_losing_stake_fet_check CHECK ((losing_stake_fet >= 0)),
    CONSTRAINT match_pool_settlements_payout_per_winner_fet_check CHECK ((payout_per_winner_fet >= 0)),
    CONSTRAINT match_pool_settlements_total_paid_fet_check CHECK ((total_paid_fet >= 0)),
    CONSTRAINT match_pool_settlements_winners_count_check CHECK ((winners_count >= 0))
);


--
-- Name: match_pool_stats; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.match_pool_stats AS
SELECT
    NULL::uuid AS id,
    NULL::text AS match_id,
    NULL::public.match_pool_scope AS scope,
    NULL::text AS country_code,
    NULL::uuid AS venue_id,
    NULL::uuid AS creator_user_id,
    NULL::text AS title,
    NULL::public.match_pool_status AS status,
    NULL::boolean AS is_official,
    NULL::bigint AS entry_fee_fet,
    NULL::bigint AS stake_min_fet,
    NULL::bigint AS stake_max_fet,
    NULL::bigint AS total_members,
    NULL::bigint AS total_staked_fet,
    NULL::text AS share_slug,
    NULL::text AS share_url,
    NULL::text AS social_card_url,
    NULL::uuid AS result_camp_id,
    NULL::timestamp with time zone AS created_at,
    NULL::timestamp with time zone AS updated_at,
    NULL::jsonb AS camps;


--
-- Name: match_pools; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.match_pools (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL,
    match_id text NOT NULL,
    scope public.match_pool_scope DEFAULT 'global'::public.match_pool_scope NOT NULL,
    country_code text,
    venue_id uuid,
    creator_user_id uuid,
    title text NOT NULL,
    status public.match_pool_status DEFAULT 'open'::public.match_pool_status NOT NULL,
    is_official boolean DEFAULT true NOT NULL,
    entry_fee_fet bigint DEFAULT 1 NOT NULL,
    stake_min_fet bigint DEFAULT 1 NOT NULL,
    stake_max_fet bigint DEFAULT 100000 NOT NULL,
    min_participants integer DEFAULT 2 NOT NULL,
    total_members bigint DEFAULT 0 NOT NULL,
    total_staked_fet bigint DEFAULT 0 NOT NULL,
    creator_reward_fet bigint DEFAULT 1 NOT NULL,
    creator_reward_rules jsonb DEFAULT jsonb_build_object('requires_invite', true, 'requires_paid_entry', true, 'status', 'configured_not_active') NOT NULL,
    platform_fee_bps integer DEFAULT 0 NOT NULL,
    venue_fee_bps integer DEFAULT 0 NOT NULL,
    share_slug text DEFAULT lower(substr(replace((extensions.gen_random_uuid())::text, '-'::text, ''::text), 1, 12)) NOT NULL,
    share_url text,
    social_card_url text,
    result_camp_id uuid,
    locked_at timestamp with time zone,
    settled_at timestamp with time zone,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    country_id uuid,
    rules_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    allow_multiple boolean DEFAULT false NOT NULL,
    CONSTRAINT match_pools_country_code_format CHECK (((country_code IS NULL) OR (country_code ~ '^[A-Z]{2}$'::text))),
    CONSTRAINT match_pools_creator_reward_fet_check CHECK ((creator_reward_fet >= 0)),
    CONSTRAINT match_pools_entry_fee_fet_check CHECK ((entry_fee_fet >= 0)),
    CONSTRAINT match_pools_min_participants_check CHECK ((min_participants >= 0)),
    CONSTRAINT match_pools_platform_fee_bps_check CHECK (((platform_fee_bps >= 0) AND (platform_fee_bps <= 10000))),
    CONSTRAINT match_pools_scope_fields CHECK ((((scope = 'global'::public.match_pool_scope) AND (country_code IS NULL) AND (venue_id IS NULL)) OR ((scope = 'country'::public.match_pool_scope) AND (country_code IS NOT NULL) AND (venue_id IS NULL)) OR ((scope = 'venue'::public.match_pool_scope) AND (venue_id IS NOT NULL)))),
    CONSTRAINT match_pools_stake_bounds CHECK (((stake_max_fet >= stake_min_fet) AND ((entry_fee_fet = 0) OR ((entry_fee_fet >= stake_min_fet) AND (entry_fee_fet <= stake_max_fet))))),
    CONSTRAINT match_pools_stake_max_fet_check CHECK ((stake_max_fet >= 0)),
    CONSTRAINT match_pools_stake_min_fet_check CHECK ((stake_min_fet >= 0)),
    CONSTRAINT match_pools_title_check CHECK (((char_length(TRIM(BOTH FROM title)) >= 2) AND (char_length(TRIM(BOTH FROM title)) <= 160))),
    CONSTRAINT match_pools_total_members_check CHECK ((total_members >= 0)),
    CONSTRAINT match_pools_total_staked_fet_check CHECK ((total_staked_fet >= 0)),
    CONSTRAINT match_pools_venue_fee_bps_check CHECK (((venue_fee_bps >= 0) AND (venue_fee_bps <= 10000)))
);


--
-- Name: menu_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.menu_categories (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL,
    venue_id uuid NOT NULL,
    name text NOT NULL,
    display_order integer DEFAULT 0 NOT NULL,
    is_visible boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT menu_categories_display_order_check CHECK ((display_order >= 0)),
    CONSTRAINT menu_categories_name_check CHECK (((char_length(TRIM(BOTH FROM name)) >= 1) AND (char_length(TRIM(BOTH FROM name)) <= 80)))
);


--
-- Name: menu_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.menu_items (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL,
    venue_id uuid NOT NULL,
    category_id uuid NOT NULL,
    name text NOT NULL,
    description text,
    price numeric(12,2) NOT NULL,
    currency_code text NOT NULL,
    image_url text,
    is_available boolean DEFAULT true NOT NULL,
    is_featured boolean DEFAULT false NOT NULL,
    dietary_flags jsonb DEFAULT '{}'::jsonb NOT NULL,
    allergens text[] DEFAULT '{}'::text[] NOT NULL,
    add_ons jsonb DEFAULT '[]'::jsonb NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    display_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    currency text,
    fet_earn_percent_override numeric(5,2),
    CONSTRAINT menu_items_add_ons_check CHECK ((jsonb_typeof(add_ons) = 'array'::text)),
    CONSTRAINT menu_items_currency_code_check CHECK ((currency_code = ANY (ARRAY['RWF'::text, 'EUR'::text]))),
    CONSTRAINT menu_items_dietary_flags_check CHECK ((jsonb_typeof(dietary_flags) = 'object'::text)),
    CONSTRAINT menu_items_display_order_check CHECK ((display_order >= 0)),
    CONSTRAINT menu_items_fet_earn_percent_override_check CHECK (((fet_earn_percent_override IS NULL) OR ((fet_earn_percent_override >= (0)::numeric) AND (fet_earn_percent_override <= (100)::numeric)))),
    CONSTRAINT menu_items_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text)),
    CONSTRAINT menu_items_name_check CHECK (((char_length(TRIM(BOTH FROM name)) >= 1) AND (char_length(TRIM(BOTH FROM name)) <= 120))),
    CONSTRAINT menu_items_price_check CHECK ((price >= (0)::numeric))
);


--
-- Name: moderation_reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.moderation_reports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    reporter_user_id uuid,
    target_type text NOT NULL,
    target_id text NOT NULL,
    reason text NOT NULL,
    description text,
    status text DEFAULT 'open'::text,
    severity text DEFAULT 'low'::text,
    assigned_to uuid,
    resolution_notes text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
    CONSTRAINT moderation_reports_severity_check CHECK ((severity = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'critical'::text]))),
    CONSTRAINT moderation_reports_status_check CHECK ((status = ANY (ARRAY['open'::text, 'investigating'::text, 'resolved'::text, 'dismissed'::text, 'escalated'::text])))
);


--
-- Name: notification_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    type text NOT NULL,
    title text NOT NULL,
    body text,
    data jsonb DEFAULT '{}'::jsonb,
    sent_at timestamp with time zone DEFAULT now(),
    read_at timestamp with time zone
);


--
-- Name: notification_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_preferences (
    user_id uuid NOT NULL,
    goal_alerts boolean DEFAULT true,
    community_news boolean DEFAULT true,
    marketing boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    reward_updates boolean DEFAULT true NOT NULL,
    pool_updates boolean DEFAULT true
);


--
-- Name: onboarding_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.onboarding_requests (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL,
    venue_id uuid NOT NULL,
    submitted_by uuid NOT NULL,
    email text,
    phone text,
    whatsapp text,
    revolut_link text,
    momo_code text,
    menu_items_json jsonb,
    status text DEFAULT 'pending'::text NOT NULL,
    admin_notes text,
    reviewed_by uuid,
    reviewed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT onboarding_requests_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])))
);


--
-- Name: order_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_items (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL,
    order_id uuid NOT NULL,
    menu_item_id uuid,
    item_name_snapshot text NOT NULL,
    item_description_snapshot text,
    quantity integer NOT NULL,
    unit_price numeric(12,2) NOT NULL,
    line_total numeric(12,2) NOT NULL,
    currency_code text NOT NULL,
    add_ons jsonb DEFAULT '[]'::jsonb NOT NULL,
    special_instructions text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    total_price numeric(12,2),
    notes text,
    CONSTRAINT order_items_add_ons_check CHECK ((jsonb_typeof(add_ons) = 'array'::text)),
    CONSTRAINT order_items_currency_code_check CHECK ((currency_code = ANY (ARRAY['RWF'::text, 'EUR'::text]))),
    CONSTRAINT order_items_line_total_check CHECK ((line_total >= (0)::numeric)),
    CONSTRAINT order_items_quantity_check CHECK ((quantity > 0)),
    CONSTRAINT order_items_unit_price_check CHECK ((unit_price >= (0)::numeric))
);


--
-- Name: TABLE order_items; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.order_items IS 'RLS enforced: Accessible only by order owner or venue staff via orders JOIN.';


--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL,
    venue_id uuid NOT NULL,
    table_id uuid NOT NULL,
    user_id uuid DEFAULT auth.uid() NOT NULL,
    order_code text DEFAULT upper(encode(extensions.gen_random_bytes(6), 'hex'::text)) NOT NULL,
    status public.order_status DEFAULT 'placed'::public.order_status NOT NULL,
    payment_method public.payment_method NOT NULL,
    payment_status public.venue_payment_status DEFAULT 'pending'::public.venue_payment_status NOT NULL,
    payment_reference text,
    currency_code text NOT NULL,
    subtotal_amount numeric(12,2) DEFAULT 0 NOT NULL,
    tax_amount numeric(12,2) DEFAULT 0 NOT NULL,
    tip_amount numeric(12,2) DEFAULT 0 NOT NULL,
    total_amount numeric(12,2) NOT NULL,
    special_instructions text,
    estimated_ready_at timestamp with time zone,
    accepted_at timestamp with time zone,
    served_at timestamp with time zone,
    status_changed_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    payment_fet_amount bigint DEFAULT 0 NOT NULL,
    payment_fet_converted_amount numeric(12,2) DEFAULT 0 NOT NULL,
    currency text,
    fet_earned bigint DEFAULT 0 NOT NULL,
    fet_spent bigint DEFAULT 0 NOT NULL,
    CONSTRAINT orders_currency_code_check CHECK ((currency_code = ANY (ARRAY['RWF'::text, 'EUR'::text]))),
    CONSTRAINT orders_fet_earned_check CHECK ((fet_earned >= 0)),
    CONSTRAINT orders_fet_spent_check CHECK ((fet_spent >= 0)),
    CONSTRAINT orders_subtotal_amount_check CHECK ((subtotal_amount >= (0)::numeric)),
    CONSTRAINT orders_tax_amount_check CHECK ((tax_amount >= (0)::numeric)),
    CONSTRAINT orders_tip_amount_check CHECK ((tip_amount >= (0)::numeric)),
    CONSTRAINT orders_total_amount_check CHECK ((total_amount >= (0)::numeric))
);


--
-- Name: TABLE orders; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.orders IS 'Order updates are server-managed through audited Edge Functions. Client sessions may insert/read through RLS, but status and payment mutations require service-role functions.';


--
-- Name: COLUMN orders.payment_fet_amount; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.orders.payment_fet_amount IS 'Amount of FET tokens applied to this order.';


--
-- Name: COLUMN orders.payment_fet_converted_amount; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.orders.payment_fet_converted_amount IS 'Value of applied FET tokens in the order currency.';


--
-- Name: COLUMN orders.fet_earned; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.orders.fet_earned IS 'FET credited to the guest from this paid order.';


--
-- Name: COLUMN orders.fet_spent; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.orders.fet_spent IS 'FET applied by the guest toward this order.';


--
-- Name: otp_verifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.otp_verifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    phone text NOT NULL,
    otp_hash text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    verified boolean DEFAULT false NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    request_ip text,
    user_agent text
);


--
-- Name: payment_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_events (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL,
    order_id uuid NOT NULL,
    provider public.payment_method NOT NULL,
    status public.venue_payment_status DEFAULT 'pending'::public.venue_payment_status NOT NULL,
    external_reference text,
    request_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    response_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT payment_events_request_payload_check CHECK ((jsonb_typeof(request_payload) = 'object'::text)),
    CONSTRAINT payment_events_response_payload_check CHECK ((jsonb_typeof(response_payload) = 'object'::text))
);


--
-- Name: pending_menu_imports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pending_menu_imports (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL,
    venue_id uuid NOT NULL,
    created_by uuid DEFAULT auth.uid() NOT NULL,
    source public.menu_import_source NOT NULL,
    status public.menu_import_status DEFAULT 'pending'::public.menu_import_status NOT NULL,
    storage_bucket text DEFAULT 'menu-ocr-queue'::text NOT NULL,
    storage_path text NOT NULL,
    original_filename text,
    detected_currency text,
    extracted_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    review_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    error_message text,
    processed_at timestamp with time zone,
    reviewed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT pending_menu_imports_detected_currency_check CHECK (((detected_currency IS NULL) OR (detected_currency = ANY (ARRAY['RWF'::text, 'EUR'::text])))),
    CONSTRAINT pending_menu_imports_extracted_payload_check CHECK ((jsonb_typeof(extracted_payload) = 'object'::text)),
    CONSTRAINT pending_menu_imports_review_payload_check CHECK ((jsonb_typeof(review_payload) = 'object'::text))
);


--
-- Name: phone_presets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phone_presets (
    country_code text NOT NULL,
    dial_code text NOT NULL,
    hint text NOT NULL,
    min_digits integer DEFAULT 9 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT phone_presets_code_format CHECK ((country_code ~ '^[A-Z]{2}$'::text)),
    CONSTRAINT phone_presets_dial_format CHECK ((dial_code ~ '^\+\d+$'::text)),
    CONSTRAINT phone_presets_min_digits CHECK (((min_digits >= 5) AND (min_digits <= 15)))
);


--
-- Name: platform_feature_audit_logs; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.platform_feature_audit_logs AS
 SELECT aal.id,
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
   FROM (public.admin_audit_logs aal
     LEFT JOIN public.admin_users au ON ((au.id = aal.admin_user_id)))
  WHERE ((aal.module = 'platform-control'::text) AND public.is_active_admin_operator(auth.uid()));


--
-- Name: pool_camps; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.pool_camps WITH (security_invoker='true') AS
 SELECT match_pool_camps.id,
    match_pool_camps.pool_id,
    COALESCE(match_pool_camps.camp_key, match_pool_camps.code) AS camp_key,
    match_pool_camps.label,
    match_pool_camps.team_id,
    match_pool_camps.member_count AS total_members,
    match_pool_camps.total_staked_fet AS total_staked,
    match_pool_camps.is_winning_camp,
    match_pool_camps.created_at,
    match_pool_camps.updated_at
   FROM public.match_pool_camps;


--
-- Name: pool_entries; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.pool_entries WITH (security_invoker='true') AS
 SELECT match_pool_entries.id,
    match_pool_entries.pool_id,
    match_pool_entries.camp_id,
    match_pool_entries.user_id,
    match_pool_entries.amount_fet AS stake_amount,
    (match_pool_entries.status)::text AS status,
    match_pool_entries.source,
    match_pool_entries.invited_by_user_id,
    match_pool_entries.created_at,
    match_pool_entries.updated_at
   FROM public.match_pool_entries;


--
-- Name: VIEW pool_entries; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.pool_entries IS 'Canonical pool entry API over public.match_pool_entries. Wallet mutation must use backend functions.';


--
-- Name: pool_operation_audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pool_operation_audit_logs (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL,
    actor_user_id uuid,
    action text NOT NULL,
    pool_id uuid,
    venue_id uuid,
    match_id text,
    before_state jsonb,
    after_state jsonb,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: pools; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.pools WITH (security_invoker='true') AS
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
    match_pools.updated_at
   FROM public.match_pools;


--
-- Name: VIEW pools; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.pools IS 'Canonical sports-bar pool API over public.match_pools. Underlying table is retained for runtime compatibility.';


--
-- Name: product_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    event_name text NOT NULL,
    properties jsonb DEFAULT '{}'::jsonb NOT NULL,
    session_id text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: rate_limits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rate_limits (
    id bigint NOT NULL,
    user_id uuid NOT NULL,
    action text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: rate_limits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rate_limits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rate_limits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rate_limits_id_seq OWNED BY public.rate_limits.id;


--
-- Name: reward_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reward_rules (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL,
    scope text NOT NULL,
    country_id uuid,
    venue_id uuid,
    welcome_fet_amount bigint DEFAULT 0 NOT NULL,
    order_fet_default_percent numeric(5,2) DEFAULT 0 NOT NULL,
    pool_creator_reward_per_member bigint DEFAULT 0 NOT NULL,
    min_qualified_stake bigint DEFAULT 0 NOT NULL,
    min_qualified_members integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    starts_at timestamp with time zone,
    ends_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT reward_rules_min_qualified_members_check CHECK ((min_qualified_members >= 0)),
    CONSTRAINT reward_rules_min_qualified_stake_check CHECK ((min_qualified_stake >= 0)),
    CONSTRAINT reward_rules_order_fet_default_percent_check CHECK (((order_fet_default_percent >= (0)::numeric) AND (order_fet_default_percent <= (100)::numeric))),
    CONSTRAINT reward_rules_pool_creator_reward_per_member_check CHECK ((pool_creator_reward_per_member >= 0)),
    CONSTRAINT reward_rules_scope_check CHECK ((scope = ANY (ARRAY['platform'::text, 'country'::text, 'venue'::text]))),
    CONSTRAINT reward_rules_scope_target_check CHECK ((((scope = 'platform'::text) AND (country_id IS NULL) AND (venue_id IS NULL)) OR ((scope = 'country'::text) AND (country_id IS NOT NULL) AND (venue_id IS NULL)) OR ((scope = 'venue'::text) AND (venue_id IS NOT NULL)))),
    CONSTRAINT reward_rules_welcome_fet_amount_check CHECK ((welcome_fet_amount >= 0)),
    CONSTRAINT reward_rules_window_check CHECK (((ends_at IS NULL) OR (starts_at IS NULL) OR (ends_at > starts_at)))
);


--
-- Name: settlement_runs; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.settlement_runs WITH (security_invoker='true') AS
 SELECT match_pool_settlements.id,
    match_pool_settlements.match_id,
    match_pool_settlements.pool_id,
    (match_pool_settlements.status)::text AS status,
    match_pool_settlements.idempotency_key,
    match_pool_settlements.started_at,
    match_pool_settlements.completed_at,
    match_pool_settlements.error_message,
    match_pool_settlements.metadata AS metadata_json
   FROM public.match_pool_settlements;


--
-- Name: VIEW settlement_runs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.settlement_runs IS 'Canonical settlement-run API over public.match_pool_settlements with idempotency keys.';


--
-- Name: tables; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tables (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL,
    venue_id uuid NOT NULL,
    table_number text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT tables_table_number_check CHECK (((char_length(TRIM(BOTH FROM table_number)) >= 1) AND (char_length(TRIM(BOTH FROM table_number)) <= 24)))
);


--
-- Name: team_aliases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.team_aliases (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    team_id text NOT NULL,
    alias_name text NOT NULL,
    source_name text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT team_aliases_alias_name_not_blank CHECK ((btrim(alias_name) <> ''::text))
);


--
-- Name: team_form_features; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.team_form_features (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    match_id text NOT NULL,
    team_id text NOT NULL,
    last5_points integer DEFAULT 0 NOT NULL,
    last5_wins integer DEFAULT 0 NOT NULL,
    last5_draws integer DEFAULT 0 NOT NULL,
    last5_losses integer DEFAULT 0 NOT NULL,
    last5_goals_for integer DEFAULT 0 NOT NULL,
    last5_goals_against integer DEFAULT 0 NOT NULL,
    last5_clean_sheets integer DEFAULT 0 NOT NULL,
    last5_failed_to_score integer DEFAULT 0 NOT NULL,
    home_form_last5 integer DEFAULT 0 NOT NULL,
    away_form_last5 integer DEFAULT 0 NOT NULL,
    over25_last5 integer DEFAULT 0 NOT NULL,
    btts_last5 integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_favorite_teams; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_favorite_teams (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    team_id text NOT NULL,
    team_name text NOT NULL,
    team_short_name text,
    team_country text,
    team_country_code text,
    team_league text,
    team_crest_url text,
    source text DEFAULT 'popular'::text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_favorite_teams_country_code_format CHECK (((team_country_code IS NULL) OR (team_country_code = ''::text) OR (team_country_code ~ '^[A-Z]{2}$'::text))),
    CONSTRAINT user_favorite_teams_source_check CHECK ((source = ANY (ARRAY['local'::text, 'popular'::text, 'settings'::text, 'synced'::text])))
);


--
-- Name: user_followed_competitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_followed_competitions (
    user_id uuid NOT NULL,
    competition_id text NOT NULL,
    notify_matchday boolean DEFAULT false NOT NULL,
    notify_live boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_market_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_market_preferences (
    user_id uuid NOT NULL,
    primary_region text DEFAULT 'global'::text NOT NULL,
    selected_regions text[] DEFAULT ARRAY['global'::text] NOT NULL,
    focus_event_tags text[] DEFAULT '{}'::text[] NOT NULL,
    favorite_competition_ids text[] DEFAULT '{}'::text[] NOT NULL,
    follow_world_cup boolean DEFAULT true NOT NULL,
    follow_champions_league boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_market_preferences_primary_region_check CHECK ((primary_region = ANY (ARRAY['global'::text, 'africa'::text, 'europe'::text, 'north_america'::text])))
);


--
-- Name: user_status; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_status (
    user_id uuid NOT NULL,
    is_banned boolean DEFAULT false,
    banned_until timestamp with time zone,
    ban_reason text,
    is_suspended boolean DEFAULT false,
    suspended_until timestamp with time zone,
    suspend_reason text,
    wallet_frozen boolean DEFAULT false,
    wallet_freeze_reason text,
    longest_streak integer DEFAULT 0,
    total_fet_earned bigint DEFAULT 0,
    total_fet_spent bigint DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    pool_streak integer DEFAULT 0 NOT NULL,
    total_pools integer DEFAULT 0 NOT NULL,
    pool_wins integer DEFAULT 0 NOT NULL
);


--
-- Name: user_profiles_admin; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.user_profiles_admin AS
 SELECT u.id,
    u.email,
    u.phone,
    (COALESCE(u.raw_user_meta_data, '{}'::jsonb) || jsonb_strip_nulls(jsonb_build_object('display_name', COALESCE(NULLIF(TRIM(BOTH FROM (u.raw_user_meta_data ->> 'display_name'::text)), ''::text), NULLIF(TRIM(BOTH FROM (u.raw_user_meta_data ->> 'full_name'::text)), ''::text), NULLIF(split_part(COALESCE(u.email, (''::character varying)::text), '@'::text, 1), ''::text), NULLIF(u.phone, ''::text)), 'is_banned', COALESCE(us.is_banned, false), 'is_suspended', COALESCE(us.is_suspended, false), 'wallet_frozen', COALESCE(us.wallet_frozen, false), 'ban_reason', us.ban_reason, 'suspend_reason', us.suspend_reason, 'wallet_freeze_reason', us.wallet_freeze_reason))) AS raw_user_meta_data,
    u.created_at,
    u.last_sign_in_at,
    COALESCE(fw.available_balance_fet, (0)::bigint) AS available_balance_fet,
    COALESCE(fw.locked_balance_fet, (0)::bigint) AS locked_balance_fet,
    COALESCE(NULLIF(TRIM(BOTH FROM (u.raw_user_meta_data ->> 'display_name'::text)), ''::text), NULLIF(TRIM(BOTH FROM (u.raw_user_meta_data ->> 'full_name'::text)), ''::text), NULLIF(split_part(COALESCE(u.email, (''::character varying)::text), '@'::text, 1), ''::text), NULLIF(u.phone, ''::text), (u.id)::text) AS display_name,
        CASE
            WHEN COALESCE(us.wallet_frozen, false) THEN 'frozen'::text
            WHEN (COALESCE(us.is_banned, false) AND ((us.banned_until IS NULL) OR (us.banned_until > timezone('utc'::text, now())))) THEN 'banned'::text
            WHEN (COALESCE(us.is_suspended, false) AND ((us.suspended_until IS NULL) OR (us.suspended_until > timezone('utc'::text, now())))) THEN 'suspended'::text
            ELSE 'active'::text
        END AS status,
    us.ban_reason,
    us.suspend_reason,
    us.wallet_freeze_reason
   FROM ((auth.users u
     LEFT JOIN public.fet_wallets fw ON ((fw.user_id = u.id)))
     LEFT JOIN public.user_status us ON ((us.user_id = u.id)))
  WHERE public.is_active_admin_operator(auth.uid());


--
-- Name: venue_tables; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.venue_tables WITH (security_invoker='true') AS
 SELECT tables.id,
    tables.venue_id,
    tables.table_number,
    tables.is_active,
    tables.created_at,
    tables.updated_at
   FROM public.tables;


--
-- Name: VIEW venue_tables; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.venue_tables IS 'Canonical table surface over the existing public.tables runtime table.';


--
-- Name: venue_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.venue_users (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL,
    venue_id uuid NOT NULL,
    user_id uuid NOT NULL,
    role public.venue_user_role DEFAULT 'staff'::public.venue_user_role NOT NULL,
    invited_by uuid,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: venues; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.venues (
    id uuid DEFAULT extensions.gen_random_uuid() NOT NULL,
    owner_id uuid,
    name text NOT NULL,
    slug text,
    country_code text NOT NULL,
    venue_type public.venue_type NOT NULL,
    currency_code text NOT NULL,
    description text,
    contact_email extensions.citext,
    contact_phone_hash text,
    contact_phone_last4 text,
    website_url text,
    google_place_id text,
    address_line1 text,
    address_line2 text,
    city text,
    region text,
    postal_code text,
    latitude double precision,
    longitude double precision,
    timezone text DEFAULT 'Europe/Malta'::text NOT NULL,
    logo_url text,
    cover_url text,
    is_open boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    onboarding_status public.onboarding_status DEFAULT 'draft'::public.onboarding_status NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    hours_json jsonb DEFAULT '{}'::jsonb,
    photos_json jsonb DEFAULT '[]'::jsonb,
    revolut_link text,
    whatsapp text,
    momo_code text,
    ai_description text,
    ai_image_url text,
    primary_category text,
    cuisine_types text[] DEFAULT '{}'::text[],
    ambiance_tags text[] DEFAULT '{}'::text[],
    special_features text[] DEFAULT '{}'::text[],
    ai_category_confidence numeric(5,4),
    last_ai_update timestamp with time zone,
    price_level integer,
    rating numeric(3,2),
    claimed boolean DEFAULT false,
    owner_email text,
    owner_pin text,
    owner_phone text,
    tenant_id uuid,
    price_band integer,
    features_json jsonb DEFAULT '{}'::jsonb,
    verified_at timestamp with time zone,
    country_id uuid,
    owner_user_id uuid,
    type text,
    address text,
    status text DEFAULT 'draft'::text NOT NULL,
    fet_reward_percent numeric(5,2) DEFAULT 0 NOT NULL,
    accepts_fet_spend boolean DEFAULT false NOT NULL,
    payment_methods text[] DEFAULT ARRAY['cash'::text] NOT NULL,
    CONSTRAINT venues_contact_phone_last4_check CHECK (((contact_phone_last4 IS NULL) OR (contact_phone_last4 ~ '^[0-9]{4}$'::text))),
    CONSTRAINT venues_country_code_format CHECK ((country_code ~ '^[A-Z]{2}$'::text)),
    CONSTRAINT venues_currency_code_check CHECK ((currency_code = ANY (ARRAY['RWF'::text, 'EUR'::text]))),
    CONSTRAINT venues_fet_reward_percent_check CHECK (((fet_reward_percent >= (0)::numeric) AND (fet_reward_percent <= (100)::numeric))),
    CONSTRAINT venues_name_check CHECK (((char_length(TRIM(BOTH FROM name)) >= 2) AND (char_length(TRIM(BOTH FROM name)) <= 120)))
);


--
-- Name: COLUMN venues.fet_reward_percent; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.venues.fet_reward_percent IS 'Default FET earning percentage for paid orders at this venue.';


--
-- Name: COLUMN venues.accepts_fet_spend; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.venues.accepts_fet_spend IS 'Whether this venue lets guests spend FET against orders.';


--
-- Name: wallet_overview; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.wallet_overview AS
 SELECT w.user_id,
    w.available_balance_fet,
    w.locked_balance_fet,
    p.fan_id,
    p.display_name,
    w.staked_balance_fet,
    w.pending_balance_fet,
    b.spent_fet,
    b.earned_fet
   FROM ((public.fet_wallets w
     JOIN public.profiles p ON ((p.user_id = w.user_id)))
     JOIN LATERAL public.wallet_balance_from_ledger(w.user_id) b(available_fet, staked_fet, pending_fet, spent_fet, earned_fet) ON (true))
  WHERE (w.user_id = auth.uid());


--
-- Name: wallet_overview_admin; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.wallet_overview_admin AS
 SELECT fw.user_id,
    COALESCE(NULLIF(TRIM(BOTH FROM (u.raw_user_meta_data ->> 'display_name'::text)), ''::text), NULLIF(TRIM(BOTH FROM (u.raw_user_meta_data ->> 'full_name'::text)), ''::text), NULLIF(split_part(COALESCE(u.email, ''::text), '@'::text, 1), ''::text), NULLIF(u.phone, ''::text), (fw.user_id)::text) AS display_name,
    u.email,
    u.phone,
        CASE
            WHEN COALESCE(us.wallet_frozen, false) THEN 'frozen'::text
            WHEN (COALESCE(us.is_banned, false) AND ((us.banned_until IS NULL) OR (us.banned_until > timezone('utc'::text, now())))) THEN 'banned'::text
            WHEN (COALESCE(us.is_suspended, false) AND ((us.suspended_until IS NULL) OR (us.suspended_until > timezone('utc'::text, now())))) THEN 'suspended'::text
            ELSE 'active'::text
        END AS status,
    us.wallet_freeze_reason,
    fw.available_balance_fet,
    fw.locked_balance_fet,
    fw.updated_at,
    fw.created_at,
    fw.staked_balance_fet,
    fw.pending_balance_fet,
    b.spent_fet,
    b.earned_fet
   FROM (((public.fet_wallets fw
     LEFT JOIN auth.users u ON ((u.id = fw.user_id)))
     LEFT JOIN public.user_status us ON ((us.user_id = fw.user_id)))
     JOIN LATERAL public.wallet_balance_from_ledger(fw.user_id) b(available_fet, staked_fet, pending_fet, spent_fet, earned_fet) ON (true))
  WHERE public.is_active_admin_operator(auth.uid());


--
-- Name: whatsapp_auth_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.whatsapp_auth_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    phone text NOT NULL,
    refresh_token_hash text NOT NULL,
    access_expires_at timestamp with time zone NOT NULL,
    refresh_expires_at timestamp with time zone NOT NULL,
    refreshed_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_at timestamp with time zone,
    revoke_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: admin_audit_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_audit_logs ALTER COLUMN id SET DEFAULT nextval('public.admin_audit_logs_id_seq'::regclass);


--
-- Name: rate_limits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate_limits ALTER COLUMN id SET DEFAULT nextval('public.rate_limits_id_seq'::regclass);


--
-- Name: account_deletion_requests account_deletion_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_deletion_requests
    ADD CONSTRAINT account_deletion_requests_pkey PRIMARY KEY (id);


--
-- Name: admin_audit_logs admin_audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_audit_logs
    ADD CONSTRAINT admin_audit_logs_pkey PRIMARY KEY (id);


--
-- Name: admin_users admin_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_users
    ADD CONSTRAINT admin_users_pkey PRIMARY KEY (id);


--
-- Name: admin_users admin_users_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_users
    ADD CONSTRAINT admin_users_user_id_key UNIQUE (user_id);


--
-- Name: admin_users admin_users_whatsapp_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_users
    ADD CONSTRAINT admin_users_whatsapp_number_key UNIQUE (whatsapp_number);


--
-- Name: anonymous_upgrade_claims anonymous_upgrade_claims_claim_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.anonymous_upgrade_claims
    ADD CONSTRAINT anonymous_upgrade_claims_claim_token_key UNIQUE (claim_token);


--
-- Name: anonymous_upgrade_claims anonymous_upgrade_claims_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.anonymous_upgrade_claims
    ADD CONSTRAINT anonymous_upgrade_claims_pkey PRIMARY KEY (anon_user_id);


--
-- Name: app_config_remote app_config_remote_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_config_remote
    ADD CONSTRAINT app_config_remote_pkey PRIMARY KEY (key);


--
-- Name: app_runtime_errors app_runtime_errors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_runtime_errors
    ADD CONSTRAINT app_runtime_errors_pkey PRIMARY KEY (id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: bell_requests bell_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bell_requests
    ADD CONSTRAINT bell_requests_pkey PRIMARY KEY (id);


--
-- Name: competitions competitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.competitions
    ADD CONSTRAINT competitions_pkey PRIMARY KEY (id);


--
-- Name: competitions competitions_type_sports_bar_check; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.competitions
    ADD CONSTRAINT competitions_type_sports_bar_check CHECK (((type IS NULL) OR (type = ANY (ARRAY['league'::text, 'cup'::text, 'world_cup'::text, 'local_curated'::text])))) NOT VALID;


--
-- Name: countries countries_iso_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.countries
    ADD CONSTRAINT countries_iso_code_key UNIQUE (iso_code);


--
-- Name: countries countries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.countries
    ADD CONSTRAINT countries_pkey PRIMARY KEY (id);


--
-- Name: country_currency_map country_currency_map_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.country_currency_map
    ADD CONSTRAINT country_currency_map_pkey PRIMARY KEY (country_code);


--
-- Name: country_region_map country_region_map_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.country_region_map
    ADD CONSTRAINT country_region_map_pkey PRIMARY KEY (country_code);


--
-- Name: cron_job_log cron_job_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cron_job_log
    ADD CONSTRAINT cron_job_log_pkey PRIMARY KEY (id);


--
-- Name: curated_matches curated_matches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.curated_matches
    ADD CONSTRAINT curated_matches_pkey PRIMARY KEY (id);


--
-- Name: currency_display_metadata currency_display_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.currency_display_metadata
    ADD CONSTRAINT currency_display_metadata_pkey PRIMARY KEY (currency_code);


--
-- Name: currency_rates currency_rates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.currency_rates
    ADD CONSTRAINT currency_rates_pkey PRIMARY KEY (base_currency, target_currency);


--
-- Name: device_tokens device_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.device_tokens
    ADD CONSTRAINT device_tokens_pkey PRIMARY KEY (id);


--
-- Name: device_tokens device_tokens_user_id_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.device_tokens
    ADD CONSTRAINT device_tokens_user_id_token_key UNIQUE (user_id, token);


--
-- Name: feature_flags feature_flags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feature_flags
    ADD CONSTRAINT feature_flags_pkey PRIMARY KEY (key, market, platform);


--
-- Name: featured_events featured_events_event_tag_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.featured_events
    ADD CONSTRAINT featured_events_event_tag_key UNIQUE (event_tag);


--
-- Name: featured_events featured_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.featured_events
    ADD CONSTRAINT featured_events_pkey PRIMARY KEY (id);


--
-- Name: fet_wallet_transactions fet_wallet_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fet_wallet_transactions
    ADD CONSTRAINT fet_wallet_transactions_pkey PRIMARY KEY (id);


--
-- Name: fet_wallets fet_wallets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fet_wallets
    ADD CONSTRAINT fet_wallets_pkey PRIMARY KEY (user_id);


--
-- Name: launch_moments launch_moments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.launch_moments
    ADD CONSTRAINT launch_moments_pkey PRIMARY KEY (tag);


--
-- Name: match_alert_dispatch_log match_alert_dispatch_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_alert_dispatch_log
    ADD CONSTRAINT match_alert_dispatch_log_pkey PRIMARY KEY (id);


--
-- Name: match_alert_dispatch_log match_alert_dispatch_log_user_id_match_id_alert_type_dispat_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_alert_dispatch_log
    ADD CONSTRAINT match_alert_dispatch_log_user_id_match_id_alert_type_dispat_key UNIQUE (user_id, match_id, alert_type, dispatch_key);


--
-- Name: match_alert_subscriptions match_alert_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_alert_subscriptions
    ADD CONSTRAINT match_alert_subscriptions_pkey PRIMARY KEY (user_id, match_id);


--
-- Name: match_pool_camps match_pool_camps_camp_key_check; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.match_pool_camps
    ADD CONSTRAINT match_pool_camps_camp_key_check CHECK (((camp_key IS NULL) OR (camp_key = ANY (ARRAY['home'::text, 'draw'::text, 'away'::text, 'custom'::text])))) NOT VALID;


--
-- Name: match_pool_camps match_pool_camps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pool_camps
    ADD CONSTRAINT match_pool_camps_pkey PRIMARY KEY (id);


--
-- Name: match_pool_camps match_pool_camps_pool_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pool_camps
    ADD CONSTRAINT match_pool_camps_pool_code_unique UNIQUE (pool_id, code);


--
-- Name: match_pool_camps match_pool_camps_pool_id_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pool_camps
    ADD CONSTRAINT match_pool_camps_pool_id_id_unique UNIQUE (pool_id, id);


--
-- Name: match_pool_entries match_pool_entries_one_active_user; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pool_entries
    ADD CONSTRAINT match_pool_entries_one_active_user UNIQUE (pool_id, user_id);


--
-- Name: match_pool_entries match_pool_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pool_entries
    ADD CONSTRAINT match_pool_entries_pkey PRIMARY KEY (id);


--
-- Name: match_pool_entries match_pool_entries_source_check; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.match_pool_entries
    ADD CONSTRAINT match_pool_entries_source_check CHECK ((source = ANY (ARRAY['direct'::text, 'invite_link'::text, 'venue_qr'::text, 'social_share'::text]))) NOT VALID;


--
-- Name: match_pool_invites match_pool_invites_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pool_invites
    ADD CONSTRAINT match_pool_invites_code_unique UNIQUE (invite_code);


--
-- Name: match_pool_invites match_pool_invites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pool_invites
    ADD CONSTRAINT match_pool_invites_pkey PRIMARY KEY (id);


--
-- Name: match_pool_settlements match_pool_settlements_idempotency_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pool_settlements
    ADD CONSTRAINT match_pool_settlements_idempotency_unique UNIQUE (idempotency_key);


--
-- Name: match_pool_settlements match_pool_settlements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pool_settlements
    ADD CONSTRAINT match_pool_settlements_pkey PRIMARY KEY (id);


--
-- Name: match_pool_settlements match_pool_settlements_pool_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pool_settlements
    ADD CONSTRAINT match_pool_settlements_pool_unique UNIQUE (pool_id);


--
-- Name: match_pools match_pools_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pools
    ADD CONSTRAINT match_pools_pkey PRIMARY KEY (id);


--
-- Name: match_pools match_pools_share_slug_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pools
    ADD CONSTRAINT match_pools_share_slug_unique UNIQUE (share_slug);


--
-- Name: matches matches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_pkey PRIMARY KEY (id);


--
-- Name: matches matches_status_sports_bar_check; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.matches
    ADD CONSTRAINT matches_status_sports_bar_check CHECK (((status IS NULL) OR (status = ANY (ARRAY['scheduled'::text, 'live'::text, 'final'::text, 'cancelled'::text, 'postponed'::text])))) NOT VALID;


--
-- Name: menu_categories menu_categories_id_venue_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_categories
    ADD CONSTRAINT menu_categories_id_venue_id_key UNIQUE (id, venue_id);


--
-- Name: menu_categories menu_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_categories
    ADD CONSTRAINT menu_categories_pkey PRIMARY KEY (id);


--
-- Name: menu_items menu_items_id_venue_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_items
    ADD CONSTRAINT menu_items_id_venue_id_key UNIQUE (id, venue_id);


--
-- Name: menu_items menu_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_items
    ADD CONSTRAINT menu_items_pkey PRIMARY KEY (id);


--
-- Name: moderation_reports moderation_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.moderation_reports
    ADD CONSTRAINT moderation_reports_pkey PRIMARY KEY (id);


--
-- Name: notification_log notification_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_log
    ADD CONSTRAINT notification_log_pkey PRIMARY KEY (id);


--
-- Name: notification_preferences notification_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_preferences
    ADD CONSTRAINT notification_preferences_pkey PRIMARY KEY (user_id);


--
-- Name: onboarding_requests onboarding_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.onboarding_requests
    ADD CONSTRAINT onboarding_requests_pkey PRIMARY KEY (id);


--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);


--
-- Name: orders orders_order_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_order_code_key UNIQUE (order_code);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: otp_verifications otp_verifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.otp_verifications
    ADD CONSTRAINT otp_verifications_pkey PRIMARY KEY (id);


--
-- Name: payment_events payment_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_events
    ADD CONSTRAINT payment_events_pkey PRIMARY KEY (id);


--
-- Name: pending_menu_imports pending_menu_imports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pending_menu_imports
    ADD CONSTRAINT pending_menu_imports_pkey PRIMARY KEY (id);


--
-- Name: phone_presets phone_presets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phone_presets
    ADD CONSTRAINT phone_presets_pkey PRIMARY KEY (country_code);


--
-- Name: platform_content_blocks platform_content_blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_content_blocks
    ADD CONSTRAINT platform_content_blocks_pkey PRIMARY KEY (block_key);


--
-- Name: platform_feature_channels platform_feature_channels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_feature_channels
    ADD CONSTRAINT platform_feature_channels_pkey PRIMARY KEY (feature_key, channel);


--
-- Name: platform_feature_rules platform_feature_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_feature_rules
    ADD CONSTRAINT platform_feature_rules_pkey PRIMARY KEY (feature_key);


--
-- Name: platform_features platform_features_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_features
    ADD CONSTRAINT platform_features_pkey PRIMARY KEY (feature_key);


--
-- Name: pool_operation_audit_logs pool_operation_audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pool_operation_audit_logs
    ADD CONSTRAINT pool_operation_audit_logs_pkey PRIMARY KEY (id);


--
-- Name: product_events product_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_events
    ADD CONSTRAINT product_events_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_fan_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_fan_id_key UNIQUE (fan_id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_user_id_key UNIQUE (user_id);


--
-- Name: profiles profiles_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_username_key UNIQUE (username);


--
-- Name: rate_limits rate_limits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate_limits
    ADD CONSTRAINT rate_limits_pkey PRIMARY KEY (id);


--
-- Name: reward_rules reward_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reward_rules
    ADD CONSTRAINT reward_rules_pkey PRIMARY KEY (id);


--
-- Name: seasons seasons_label_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seasons
    ADD CONSTRAINT seasons_label_unique UNIQUE (competition_id, season_label);


--
-- Name: seasons seasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seasons
    ADD CONSTRAINT seasons_pkey PRIMARY KEY (id);


--
-- Name: standings standings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.standings
    ADD CONSTRAINT standings_pkey PRIMARY KEY (id);


--
-- Name: standings standings_unique_snapshot; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.standings
    ADD CONSTRAINT standings_unique_snapshot UNIQUE (competition_id, season_id, snapshot_type, snapshot_date, team_id);


--
-- Name: tables tables_id_venue_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tables
    ADD CONSTRAINT tables_id_venue_id_key UNIQUE (id, venue_id);


--
-- Name: tables tables_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tables
    ADD CONSTRAINT tables_pkey PRIMARY KEY (id);


--
-- Name: tables tables_venue_id_table_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tables
    ADD CONSTRAINT tables_venue_id_table_number_key UNIQUE (venue_id, table_number);


--
-- Name: team_aliases team_aliases_unique_team_alias; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_aliases
    ADD CONSTRAINT team_aliases_unique_team_alias UNIQUE (team_id, alias_name);


--
-- Name: team_aliases team_aliases_v2_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_aliases
    ADD CONSTRAINT team_aliases_v2_pkey PRIMARY KEY (id);


--
-- Name: team_form_features team_form_features_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_form_features
    ADD CONSTRAINT team_form_features_pkey PRIMARY KEY (id);


--
-- Name: team_form_features team_form_features_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_form_features
    ADD CONSTRAINT team_form_features_unique UNIQUE (match_id, team_id);


--
-- Name: teams teams_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_pkey PRIMARY KEY (id);


--
-- Name: user_favorite_teams user_favorite_teams_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_favorite_teams
    ADD CONSTRAINT user_favorite_teams_pkey PRIMARY KEY (id);


--
-- Name: user_favorite_teams user_favorite_teams_user_id_team_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_favorite_teams
    ADD CONSTRAINT user_favorite_teams_user_id_team_id_key UNIQUE (user_id, team_id);


--
-- Name: user_followed_competitions user_followed_competitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_followed_competitions
    ADD CONSTRAINT user_followed_competitions_pkey PRIMARY KEY (user_id, competition_id);


--
-- Name: user_market_preferences user_market_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_market_preferences
    ADD CONSTRAINT user_market_preferences_pkey PRIMARY KEY (user_id);


--
-- Name: user_status user_status_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_status
    ADD CONSTRAINT user_status_pkey PRIMARY KEY (user_id);


--
-- Name: venue_users venue_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venue_users
    ADD CONSTRAINT venue_users_pkey PRIMARY KEY (id);


--
-- Name: venue_users venue_users_venue_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venue_users
    ADD CONSTRAINT venue_users_venue_id_user_id_key UNIQUE (venue_id, user_id);


--
-- Name: venues venues_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT venues_pkey PRIMARY KEY (id);


--
-- Name: venues venues_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT venues_slug_key UNIQUE (slug);


--
-- Name: whatsapp_auth_sessions whatsapp_auth_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.whatsapp_auth_sessions
    ADD CONSTRAINT whatsapp_auth_sessions_pkey PRIMARY KEY (id);


--
-- Name: whatsapp_auth_sessions whatsapp_auth_sessions_refresh_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.whatsapp_auth_sessions
    ADD CONSTRAINT whatsapp_auth_sessions_refresh_token_hash_key UNIQUE (refresh_token_hash);


--
-- Name: audit_logs_action_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_action_idx ON public.audit_logs USING btree (action, created_at DESC);


--
-- Name: audit_logs_actor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_actor_idx ON public.audit_logs USING btree (actor_user_id, created_at DESC);


--
-- Name: audit_logs_entity_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_entity_idx ON public.audit_logs USING btree (entity_type, entity_id, created_at DESC);


--
-- Name: bell_requests_venue_ack_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX bell_requests_venue_ack_created_idx ON public.bell_requests USING btree (venue_id, acknowledged_at, created_at DESC);


--
-- Name: competitions_active_priority_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX competitions_active_priority_idx ON public.competitions USING btree (is_active, priority);


--
-- Name: competitions_country_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX competitions_country_id_idx ON public.competitions USING btree (country_id);


--
-- Name: curated_matches_active_country_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX curated_matches_active_country_idx ON public.curated_matches USING btree (is_active, country_code, priority_score DESC);


--
-- Name: curated_matches_active_venue_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX curated_matches_active_venue_idx ON public.curated_matches USING btree (is_active, venue_id, priority_score DESC);


--
-- Name: curated_matches_scope_unique_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX curated_matches_scope_unique_idx ON public.curated_matches USING btree (match_id, COALESCE(country_code, ''::text), COALESCE(venue_id, '00000000-0000-0000-0000-000000000000'::uuid));


--
-- Name: fet_wallet_transactions_bucket_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fet_wallet_transactions_bucket_status_idx ON public.fet_wallet_transactions USING btree (user_id, balance_bucket, status);


--
-- Name: fet_wallet_transactions_idempotency_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX fet_wallet_transactions_idempotency_idx ON public.fet_wallet_transactions USING btree (idempotency_key) WHERE (idempotency_key IS NOT NULL);


--
-- Name: fet_wallet_transactions_match_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fet_wallet_transactions_match_idx ON public.fet_wallet_transactions USING btree (match_id, created_at DESC) WHERE (match_id IS NOT NULL);


--
-- Name: fet_wallet_transactions_order_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fet_wallet_transactions_order_idx ON public.fet_wallet_transactions USING btree (order_id, created_at DESC) WHERE (order_id IS NOT NULL);


--
-- Name: fet_wallet_transactions_pool_entry_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fet_wallet_transactions_pool_entry_idx ON public.fet_wallet_transactions USING btree (pool_entry_id);


--
-- Name: fet_wallet_transactions_pool_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fet_wallet_transactions_pool_idx ON public.fet_wallet_transactions USING btree (pool_id, created_at DESC) WHERE (pool_id IS NOT NULL);


--
-- Name: fet_wallet_transactions_user_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fet_wallet_transactions_user_type_idx ON public.fet_wallet_transactions USING btree (user_id, transaction_type, created_at DESC);


--
-- Name: fet_wallet_transactions_venue_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fet_wallet_transactions_venue_idx ON public.fet_wallet_transactions USING btree (venue_id, created_at DESC) WHERE (venue_id IS NOT NULL);


--
-- Name: fet_wallet_transactions_wallet_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fet_wallet_transactions_wallet_id_idx ON public.fet_wallet_transactions USING btree (wallet_id);


--
-- Name: fet_wallets_id_unique_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX fet_wallets_id_unique_idx ON public.fet_wallets USING btree (id);


--
-- Name: fet_wallets_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fet_wallets_user_id_idx ON public.fet_wallets USING btree (user_id);


--
-- Name: idx_account_deletion_requests_pending_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_account_deletion_requests_pending_unique ON public.account_deletion_requests USING btree (user_id) WHERE (status = ANY (ARRAY['pending'::text, 'in_review'::text]));


--
-- Name: idx_account_deletion_requests_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_account_deletion_requests_status ON public.account_deletion_requests USING btree (status, requested_at DESC);


--
-- Name: idx_account_deletion_requests_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_account_deletion_requests_user ON public.account_deletion_requests USING btree (user_id, requested_at DESC);


--
-- Name: idx_admin_users_phone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_users_phone ON public.admin_users USING btree (phone);


--
-- Name: idx_anonymous_upgrade_claims_expires; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_anonymous_upgrade_claims_expires ON public.anonymous_upgrade_claims USING btree (expires_at) WHERE (consumed_at IS NULL);


--
-- Name: idx_app_runtime_errors_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_app_runtime_errors_created_at ON public.app_runtime_errors USING btree (created_at DESC);


--
-- Name: idx_app_runtime_errors_reason; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_app_runtime_errors_reason ON public.app_runtime_errors USING btree (reason);


--
-- Name: idx_app_runtime_errors_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_app_runtime_errors_user_id ON public.app_runtime_errors USING btree (user_id) WHERE (user_id IS NOT NULL);


--
-- Name: idx_competitions_active_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_competitions_active_name ON public.competitions USING btree (is_active, name);


--
-- Name: idx_competitions_country_tier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_competitions_country_tier ON public.competitions USING btree (country, tier);


--
-- Name: idx_competitions_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_competitions_status ON public.competitions USING btree (status, is_featured);


--
-- Name: idx_cron_job_log_name_started; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cron_job_log_name_started ON public.cron_job_log USING btree (job_name, started_at DESC);


--
-- Name: idx_device_tokens_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_device_tokens_user ON public.device_tokens USING btree (user_id) WHERE (is_active = true);


--
-- Name: idx_featured_events_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_featured_events_active ON public.featured_events USING btree (is_active, start_date, end_date);


--
-- Name: idx_featured_events_priority; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_featured_events_priority ON public.featured_events USING btree (priority_score DESC, start_date);


--
-- Name: idx_featured_events_tag; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_featured_events_tag ON public.featured_events USING btree (event_tag);


--
-- Name: idx_match_alert_dispatch_log_match_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_match_alert_dispatch_log_match_type ON public.match_alert_dispatch_log USING btree (match_id, alert_type, dispatched_at DESC);


--
-- Name: idx_match_alert_dispatch_log_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_match_alert_dispatch_log_user ON public.match_alert_dispatch_log USING btree (user_id, dispatched_at DESC);


--
-- Name: idx_match_alert_subscriptions_match; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_match_alert_subscriptions_match ON public.match_alert_subscriptions USING btree (match_id);


--
-- Name: idx_matches_away_team; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_matches_away_team ON public.matches USING btree (away_team_id);


--
-- Name: idx_matches_competition_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_matches_competition_date ON public.matches USING btree (competition_id, match_date DESC);


--
-- Name: idx_matches_competition_season_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_matches_competition_season_date ON public.matches USING btree (competition_id, season_id, match_date DESC);


--
-- Name: idx_matches_home_team; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_matches_home_team ON public.matches USING btree (home_team_id);


--
-- Name: idx_matches_match_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_matches_match_date ON public.matches USING btree (match_date);


--
-- Name: idx_matches_season_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_matches_season_status ON public.matches USING btree (season_id, match_status, match_date DESC);


--
-- Name: idx_matches_status_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_matches_status_date ON public.matches USING btree (match_status, match_date DESC);


--
-- Name: idx_notification_log_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notification_log_user ON public.notification_log USING btree (user_id, sent_at DESC);


--
-- Name: idx_otp_verifications_cleanup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_otp_verifications_cleanup ON public.otp_verifications USING btree (verified, expires_at, created_at);


--
-- Name: idx_otp_verifications_phone_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_otp_verifications_phone_active ON public.otp_verifications USING btree (phone, expires_at DESC) WHERE (verified = false);


--
-- Name: idx_otp_verifications_phone_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_otp_verifications_phone_created ON public.otp_verifications USING btree (phone, created_at DESC);


--
-- Name: idx_otp_verifications_phone_verified; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_otp_verifications_phone_verified ON public.otp_verifications USING btree (phone, verified, expires_at DESC);


--
-- Name: idx_otp_verifications_request_ip_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_otp_verifications_request_ip_created ON public.otp_verifications USING btree (request_ip, created_at DESC) WHERE (request_ip IS NOT NULL);


--
-- Name: idx_product_events_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_events_created_at ON public.product_events USING btree (created_at DESC);


--
-- Name: idx_product_events_event_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_events_event_name ON public.product_events USING btree (event_name);


--
-- Name: idx_product_events_session; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_events_session ON public.product_events USING btree (session_id) WHERE (session_id IS NOT NULL);


--
-- Name: idx_product_events_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_events_user_id ON public.product_events USING btree (user_id) WHERE (user_id IS NOT NULL);


--
-- Name: idx_profiles_is_anonymous; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_profiles_is_anonymous ON public.profiles USING btree (is_anonymous) WHERE (is_anonymous = true);


--
-- Name: idx_profiles_phone_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_profiles_phone_number ON public.profiles USING btree (phone_number) WHERE (phone_number IS NOT NULL);


--
-- Name: idx_rate_limits_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rate_limits_lookup ON public.rate_limits USING btree (user_id, action, created_at DESC);


--
-- Name: idx_reports_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reports_status ON public.moderation_reports USING btree (status);


--
-- Name: idx_reports_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reports_target ON public.moderation_reports USING btree (target_type, target_id);


--
-- Name: idx_seasons_competition_current; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_seasons_competition_current ON public.seasons USING btree (competition_id, is_current DESC, start_year DESC);


--
-- Name: idx_standings_competition_snapshot; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_standings_competition_snapshot ON public.standings USING btree (competition_id, season_id, snapshot_type, snapshot_date DESC, "position");


--
-- Name: idx_team_aliases_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_team_aliases_lookup ON public.team_aliases USING btree (lower(alias_name));


--
-- Name: idx_team_aliases_team_alias_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_team_aliases_team_alias_unique ON public.team_aliases USING btree (team_id, lower(alias_name));


--
-- Name: idx_team_form_features_match; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_team_form_features_match ON public.team_form_features USING btree (match_id, team_id);


--
-- Name: idx_team_form_features_team_match; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_team_form_features_team_match ON public.team_form_features USING btree (team_id, match_id);


--
-- Name: idx_teams_active_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_teams_active_name ON public.teams USING btree (is_active, name);


--
-- Name: idx_teams_country; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_teams_country ON public.teams USING btree (country);


--
-- Name: idx_teams_country_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_teams_country_code ON public.teams USING btree (country_code);


--
-- Name: idx_teams_popular_pick; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_teams_popular_pick ON public.teams USING btree (is_popular_pick, popular_pick_rank) WHERE (is_popular_pick = true);


--
-- Name: idx_teams_region; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_teams_region ON public.teams USING btree (region);


--
-- Name: idx_user_favorite_teams_country; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_favorite_teams_country ON public.user_favorite_teams USING btree (team_country_code);


--
-- Name: idx_user_favorite_teams_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_favorite_teams_user ON public.user_favorite_teams USING btree (user_id, source, sort_order, created_at);


--
-- Name: idx_user_status_banned; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_status_banned ON public.user_status USING btree (is_banned) WHERE (is_banned = true);


--
-- Name: idx_whatsapp_auth_sessions_cleanup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_whatsapp_auth_sessions_cleanup ON public.whatsapp_auth_sessions USING btree (revoked_at, refresh_expires_at, updated_at);


--
-- Name: idx_whatsapp_auth_sessions_phone_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_whatsapp_auth_sessions_phone_active ON public.whatsapp_auth_sessions USING btree (phone, refresh_expires_at DESC) WHERE (revoked_at IS NULL);


--
-- Name: idx_whatsapp_auth_sessions_user_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_whatsapp_auth_sessions_user_active ON public.whatsapp_auth_sessions USING btree (user_id, refresh_expires_at DESC) WHERE (revoked_at IS NULL);


--
-- Name: match_pool_camps_pool_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_pool_camps_pool_idx ON public.match_pool_camps USING btree (pool_id, display_order);


--
-- Name: match_pool_entries_camp_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_pool_entries_camp_id_idx ON public.match_pool_entries USING btree (camp_id);


--
-- Name: match_pool_entries_invited_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_pool_entries_invited_by_idx ON public.match_pool_entries USING btree (invited_by_user_id);


--
-- Name: match_pool_entries_pool_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_pool_entries_pool_status_idx ON public.match_pool_entries USING btree (pool_id, status);


--
-- Name: match_pool_entries_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_pool_entries_user_idx ON public.match_pool_entries USING btree (user_id, created_at DESC);


--
-- Name: match_pool_invites_inviter_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_pool_invites_inviter_idx ON public.match_pool_invites USING btree (inviter_user_id, created_at DESC);


--
-- Name: match_pool_invites_one_rewarded_invitee_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX match_pool_invites_one_rewarded_invitee_idx ON public.match_pool_invites USING btree (pool_id, invitee_user_id) WHERE ((invitee_user_id IS NOT NULL) AND (status = ANY (ARRAY['joined'::text, 'rewarded'::text])));


--
-- Name: match_pool_invites_pool_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_pool_invites_pool_idx ON public.match_pool_invites USING btree (pool_id, created_at DESC);


--
-- Name: match_pool_settlements_idempotency_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_pool_settlements_idempotency_idx ON public.match_pool_settlements USING btree (idempotency_key);


--
-- Name: match_pool_settlements_match_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_pool_settlements_match_idx ON public.match_pool_settlements USING btree (match_id);


--
-- Name: match_pool_settlements_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_pool_settlements_status_idx ON public.match_pool_settlements USING btree (status, started_at DESC);


--
-- Name: match_pools_country_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_pools_country_id_idx ON public.match_pools USING btree (country_id);


--
-- Name: match_pools_country_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_pools_country_status_idx ON public.match_pools USING btree (country_code, status, created_at DESC);


--
-- Name: match_pools_match_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_pools_match_status_idx ON public.match_pools USING btree (match_id, status);


--
-- Name: match_pools_one_official_venue_match_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX match_pools_one_official_venue_match_idx ON public.match_pools USING btree (venue_id, match_id) WHERE ((scope = 'venue'::public.match_pool_scope) AND (is_official = true) AND (status <> 'cancelled'::public.match_pool_status));


--
-- Name: match_pools_venue_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_pools_venue_status_idx ON public.match_pools USING btree (venue_id, status, created_at DESC);


--
-- Name: matches_away_team_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX matches_away_team_id_idx ON public.matches USING btree (away_team_id);


--
-- Name: matches_competition_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX matches_competition_id_idx ON public.matches USING btree (competition_id);


--
-- Name: matches_curated_starts_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX matches_curated_starts_at_idx ON public.matches USING btree (is_curated, starts_at);


--
-- Name: matches_home_team_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX matches_home_team_id_idx ON public.matches USING btree (home_team_id);


--
-- Name: matches_starts_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX matches_starts_at_idx ON public.matches USING btree (starts_at);


--
-- Name: matches_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX matches_status_idx ON public.matches USING btree (status);


--
-- Name: menu_categories_venue_active_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX menu_categories_venue_active_idx ON public.menu_categories USING btree (venue_id, is_active, sort_order);


--
-- Name: menu_categories_venue_order_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX menu_categories_venue_order_idx ON public.menu_categories USING btree (venue_id, display_order);


--
-- Name: menu_items_venue_available_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX menu_items_venue_available_idx ON public.menu_items USING btree (venue_id, is_available);


--
-- Name: menu_items_venue_category_available_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX menu_items_venue_category_available_idx ON public.menu_items USING btree (venue_id, category_id, is_available);


--
-- Name: menu_items_venue_category_order_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX menu_items_venue_category_order_idx ON public.menu_items USING btree (venue_id, category_id, display_order);


--
-- Name: onboarding_requests_status_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX onboarding_requests_status_created_idx ON public.onboarding_requests USING btree (status, created_at DESC);


--
-- Name: onboarding_requests_venue_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX onboarding_requests_venue_idx ON public.onboarding_requests USING btree (venue_id);


--
-- Name: order_items_menu_item_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX order_items_menu_item_id_idx ON public.order_items USING btree (menu_item_id);


--
-- Name: order_items_order_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX order_items_order_id_idx ON public.order_items USING btree (order_id);


--
-- Name: order_items_order_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX order_items_order_idx ON public.order_items USING btree (order_id);


--
-- Name: orders_payment_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX orders_payment_status_idx ON public.orders USING btree (payment_status);


--
-- Name: orders_table_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX orders_table_id_idx ON public.orders USING btree (table_id);


--
-- Name: orders_user_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX orders_user_created_idx ON public.orders USING btree (user_id, created_at DESC);


--
-- Name: orders_venue_status_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX orders_venue_status_created_idx ON public.orders USING btree (venue_id, status, created_at DESC);


--
-- Name: payment_events_order_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX payment_events_order_created_idx ON public.payment_events USING btree (order_id, created_at DESC);


--
-- Name: payment_events_provider_reference_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX payment_events_provider_reference_uidx ON public.payment_events USING btree (provider, external_reference) WHERE (external_reference IS NOT NULL);


--
-- Name: pending_menu_imports_venue_status_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pending_menu_imports_venue_status_created_idx ON public.pending_menu_imports USING btree (venue_id, status, created_at DESC);


--
-- Name: pool_operation_audit_logs_action_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pool_operation_audit_logs_action_idx ON public.pool_operation_audit_logs USING btree (action, created_at DESC);


--
-- Name: pool_operation_audit_logs_pool_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pool_operation_audit_logs_pool_idx ON public.pool_operation_audit_logs USING btree (pool_id, created_at DESC);


--
-- Name: pool_operation_audit_logs_venue_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pool_operation_audit_logs_venue_idx ON public.pool_operation_audit_logs USING btree (venue_id, created_at DESC) WHERE (venue_id IS NOT NULL);


--
-- Name: pools_one_country_pool_per_match_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX pools_one_country_pool_per_match_idx ON public.match_pools USING btree (match_id, country_id) WHERE ((scope = 'country'::public.match_pool_scope) AND (country_id IS NOT NULL) AND (status <> 'cancelled'::public.match_pool_status) AND (allow_multiple = false));


--
-- Name: pools_one_global_official_pool_per_match_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX pools_one_global_official_pool_per_match_idx ON public.match_pools USING btree (match_id) WHERE ((scope = 'global'::public.match_pool_scope) AND (is_official = true) AND (status <> 'cancelled'::public.match_pool_status) AND (allow_multiple = false));


--
-- Name: pools_one_venue_pool_per_match_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX pools_one_venue_pool_per_match_idx ON public.match_pools USING btree (match_id, venue_id) WHERE ((scope = 'venue'::public.match_pool_scope) AND (venue_id IS NOT NULL) AND (status <> 'cancelled'::public.match_pool_status) AND (allow_multiple = false));


--
-- Name: reward_rules_country_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reward_rules_country_idx ON public.reward_rules USING btree (country_id, is_active);


--
-- Name: reward_rules_one_active_platform_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX reward_rules_one_active_platform_idx ON public.reward_rules USING btree (scope) WHERE ((scope = 'platform'::text) AND (is_active = true));


--
-- Name: reward_rules_venue_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reward_rules_venue_idx ON public.reward_rules USING btree (venue_id, is_active);


--
-- Name: tables_venue_active_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tables_venue_active_idx ON public.tables USING btree (venue_id, is_active);


--
-- Name: teams_country_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX teams_country_id_idx ON public.teams USING btree (country_id);


--
-- Name: teams_popularity_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX teams_popularity_idx ON public.teams USING btree (popularity_score DESC);


--
-- Name: venue_users_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX venue_users_user_idx ON public.venue_users USING btree (user_id);


--
-- Name: venues_claimed_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX venues_claimed_idx ON public.venues USING btree (claimed);


--
-- Name: venues_country_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX venues_country_id_idx ON public.venues USING btree (country_id);


--
-- Name: venues_country_open_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX venues_country_open_idx ON public.venues USING btree (country_code, is_open, is_active);


--
-- Name: venues_owner_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX venues_owner_id_idx ON public.venues USING btree (owner_id);


--
-- Name: venues_owner_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX venues_owner_user_id_idx ON public.venues USING btree (owner_user_id);


--
-- Name: venues_primary_category_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX venues_primary_category_idx ON public.venues USING btree (primary_category);


--
-- Name: venues_slug_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX venues_slug_idx ON public.venues USING btree (slug) WHERE (slug IS NOT NULL);


--
-- Name: venues_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX venues_status_idx ON public.venues USING btree (status);


--
-- Name: match_pool_stats _RETURN; Type: RULE; Schema: public; Owner: -
--

CREATE OR REPLACE VIEW public.match_pool_stats AS
 SELECT p.id,
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
    COALESCE(jsonb_agg(jsonb_build_object('id', c.id, 'code', c.code, 'label', c.label, 'result_code', c.result_code, 'member_count', c.member_count, 'total_staked_fet', c.total_staked_fet, 'display_order', c.display_order) ORDER BY c.display_order, c.created_at) FILTER (WHERE (c.id IS NOT NULL)), '[]'::jsonb) AS camps
   FROM (public.match_pools p
     LEFT JOIN public.match_pool_camps c ON ((c.pool_id = p.id)))
  GROUP BY p.id;


--
-- Name: countries countries_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER countries_set_updated_at BEFORE UPDATE ON public.countries FOR EACH ROW EXECUTE FUNCTION public.sports_bar_set_updated_at();


--
-- Name: orders enforce_orders_service_updates; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER enforce_orders_service_updates BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.venue_reject_client_order_updates();


--
-- Name: fet_wallets fet_wallets_sync_sports_bar_aliases; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER fet_wallets_sync_sports_bar_aliases BEFORE INSERT OR UPDATE ON public.fet_wallets FOR EACH ROW EXECUTE FUNCTION public.sports_bar_sync_wallet_aliases();


--
-- Name: match_pool_camps match_pool_camps_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER match_pool_camps_set_updated_at BEFORE UPDATE ON public.match_pool_camps FOR EACH ROW EXECUTE FUNCTION public.sports_bar_set_updated_at();


--
-- Name: match_pool_entries match_pool_entries_prevent_late_entry; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER match_pool_entries_prevent_late_entry BEFORE INSERT ON public.match_pool_entries FOR EACH ROW EXECUTE FUNCTION public.sports_bar_prevent_late_pool_entry();


--
-- Name: match_pool_settlements match_pool_settlements_prevent_early_settlement; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER match_pool_settlements_prevent_early_settlement BEFORE INSERT OR UPDATE ON public.match_pool_settlements FOR EACH ROW EXECUTE FUNCTION public.sports_bar_prevent_early_settlement();


--
-- Name: match_pools match_pools_operation_audit_write; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER match_pools_operation_audit_write AFTER INSERT OR DELETE OR UPDATE ON public.match_pools FOR EACH ROW EXECUTE FUNCTION public.write_match_pool_operation_audit();


--
-- Name: platform_content_blocks platform_content_blocks_audit_write; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER platform_content_blocks_audit_write AFTER INSERT OR DELETE OR UPDATE ON public.platform_content_blocks FOR EACH ROW EXECUTE FUNCTION public.log_platform_control_change();


--
-- Name: platform_feature_channels platform_feature_channels_audit_write; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER platform_feature_channels_audit_write AFTER INSERT OR DELETE OR UPDATE ON public.platform_feature_channels FOR EACH ROW EXECUTE FUNCTION public.log_platform_control_change();


--
-- Name: platform_feature_channels platform_feature_channels_sync_feature_flags_write; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER platform_feature_channels_sync_feature_flags_write AFTER INSERT OR DELETE OR UPDATE ON public.platform_feature_channels FOR EACH ROW EXECUTE FUNCTION public.sync_runtime_feature_flags_on_platform_write();


--
-- Name: platform_feature_rules platform_feature_rules_audit_write; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER platform_feature_rules_audit_write AFTER INSERT OR DELETE OR UPDATE ON public.platform_feature_rules FOR EACH ROW EXECUTE FUNCTION public.log_platform_control_change();


--
-- Name: platform_feature_rules platform_feature_rules_sync_feature_flags_write; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER platform_feature_rules_sync_feature_flags_write AFTER INSERT OR DELETE OR UPDATE ON public.platform_feature_rules FOR EACH ROW EXECUTE FUNCTION public.sync_runtime_feature_flags_on_platform_write();


--
-- Name: platform_features platform_features_audit_write; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER platform_features_audit_write AFTER INSERT OR DELETE OR UPDATE ON public.platform_features FOR EACH ROW EXECUTE FUNCTION public.log_platform_control_change();


--
-- Name: platform_features platform_features_sync_feature_flags_write; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER platform_features_sync_feature_flags_write AFTER INSERT OR DELETE OR UPDATE ON public.platform_features FOR EACH ROW EXECUTE FUNCTION public.sync_runtime_feature_flags_on_platform_write();


--
-- Name: reward_rules reward_rules_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER reward_rules_set_updated_at BEFORE UPDATE ON public.reward_rules FOR EACH ROW EXECUTE FUNCTION public.sports_bar_set_updated_at();


--
-- Name: menu_categories set_menu_categories_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_menu_categories_updated_at BEFORE UPDATE ON public.menu_categories FOR EACH ROW EXECUTE FUNCTION public.venue_set_updated_at();


--
-- Name: menu_items set_menu_items_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_menu_items_updated_at BEFORE UPDATE ON public.menu_items FOR EACH ROW EXECUTE FUNCTION public.venue_set_updated_at();


--
-- Name: orders set_orders_timestamps; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_orders_timestamps BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.venue_set_order_timestamps();


--
-- Name: payment_events set_payment_events_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_payment_events_updated_at BEFORE UPDATE ON public.payment_events FOR EACH ROW EXECUTE FUNCTION public.venue_set_updated_at();


--
-- Name: pending_menu_imports set_pending_menu_imports_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_pending_menu_imports_updated_at BEFORE UPDATE ON public.pending_menu_imports FOR EACH ROW EXECUTE FUNCTION public.venue_set_updated_at();


--
-- Name: profiles set_profiles_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: tables set_tables_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_tables_updated_at BEFORE UPDATE ON public.tables FOR EACH ROW EXECUTE FUNCTION public.venue_set_updated_at();


--
-- Name: venue_users set_venue_users_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_venue_users_updated_at BEFORE UPDATE ON public.venue_users FOR EACH ROW EXECUTE FUNCTION public.venue_set_updated_at();


--
-- Name: venues set_venues_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_venues_updated_at BEFORE UPDATE ON public.venues FOR EACH ROW EXECUTE FUNCTION public.venue_set_updated_at();


--
-- Name: fet_wallets set_wallet_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_wallet_updated_at BEFORE UPDATE ON public.fet_wallets FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: venues sync_owner_membership; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sync_owner_membership AFTER INSERT OR UPDATE OF owner_id ON public.venues FOR EACH ROW EXECUTE FUNCTION public.venue_sync_owner_membership();


--
-- Name: matches trg_apply_match_result_code; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_apply_match_result_code BEFORE INSERT OR UPDATE OF home_goals, away_goals, match_status ON public.matches FOR EACH ROW EXECUTE FUNCTION public.apply_match_result_code();


--
-- Name: competitions trg_competitions_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_competitions_updated_at BEFORE UPDATE ON public.competitions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: orders trg_credit_fet_on_order_insert_paid; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_credit_fet_on_order_insert_paid AFTER INSERT ON public.orders FOR EACH ROW WHEN ((new.payment_status = 'paid'::public.venue_payment_status)) EXECUTE FUNCTION public.venue_credit_fet_from_order();


--
-- Name: orders trg_credit_fet_on_order_paid; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_credit_fet_on_order_paid AFTER UPDATE OF payment_status ON public.orders FOR EACH ROW WHEN ((new.payment_status = 'paid'::public.venue_payment_status)) EXECUTE FUNCTION public.venue_credit_fet_from_order();


--
-- Name: curated_matches trg_curated_matches_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_curated_matches_updated_at BEFORE UPDATE ON public.curated_matches FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: match_pool_entries trg_match_pool_entries_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_match_pool_entries_updated_at BEFORE UPDATE ON public.match_pool_entries FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: match_pool_invites trg_match_pool_invites_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_match_pool_invites_updated_at BEFORE UPDATE ON public.match_pool_invites FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: match_pools trg_match_pools_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_match_pools_updated_at BEFORE UPDATE ON public.match_pools FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: matches trg_matches_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_matches_updated_at BEFORE UPDATE ON public.matches FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: fet_wallet_transactions trg_notify_wallet_credit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_notify_wallet_credit AFTER INSERT ON public.fet_wallet_transactions FOR EACH ROW WHEN (((new.direction = 'credit'::text) AND (new.amount_fet >= 10))) EXECUTE FUNCTION public.notify_wallet_credit();


--
-- Name: profiles trg_profiles_assign_fan_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_profiles_assign_fan_id BEFORE INSERT OR UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.assign_profile_fan_id();


--
-- Name: seasons trg_seasons_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_seasons_updated_at BEFORE UPDATE ON public.seasons FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: standings trg_standings_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_standings_updated_at BEFORE UPDATE ON public.standings FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: team_form_features trg_team_form_features_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_team_form_features_updated_at BEFORE UPDATE ON public.team_form_features FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: teams trg_teams_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_teams_updated_at BEFORE UPDATE ON public.teams FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: account_deletion_requests account_deletion_requests_processed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_deletion_requests
    ADD CONSTRAINT account_deletion_requests_processed_by_fkey FOREIGN KEY (processed_by) REFERENCES auth.users(id);


--
-- Name: account_deletion_requests account_deletion_requests_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_deletion_requests
    ADD CONSTRAINT account_deletion_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: admin_audit_logs admin_audit_logs_admin_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_audit_logs
    ADD CONSTRAINT admin_audit_logs_admin_user_id_fkey FOREIGN KEY (admin_user_id) REFERENCES public.admin_users(id);


--
-- Name: admin_users admin_users_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_users
    ADD CONSTRAINT admin_users_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: anonymous_upgrade_claims anonymous_upgrade_claims_anon_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.anonymous_upgrade_claims
    ADD CONSTRAINT anonymous_upgrade_claims_anon_user_id_fkey FOREIGN KEY (anon_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: anonymous_upgrade_claims anonymous_upgrade_claims_consumed_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.anonymous_upgrade_claims
    ADD CONSTRAINT anonymous_upgrade_claims_consumed_by_user_id_fkey FOREIGN KEY (consumed_by_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: app_runtime_errors app_runtime_errors_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_runtime_errors
    ADD CONSTRAINT app_runtime_errors_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: audit_logs audit_logs_actor_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: bell_requests bell_requests_acknowledged_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bell_requests
    ADD CONSTRAINT bell_requests_acknowledged_by_fkey FOREIGN KEY (acknowledged_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: bell_requests bell_requests_table_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bell_requests
    ADD CONSTRAINT bell_requests_table_fkey FOREIGN KEY (table_id, venue_id) REFERENCES public.tables(id, venue_id) ON DELETE CASCADE;


--
-- Name: bell_requests bell_requests_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bell_requests
    ADD CONSTRAINT bell_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: bell_requests bell_requests_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bell_requests
    ADD CONSTRAINT bell_requests_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venues(id) ON DELETE CASCADE;


--
-- Name: competitions competitions_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.competitions
    ADD CONSTRAINT competitions_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.countries(id) ON DELETE SET NULL;


--
-- Name: curated_matches curated_matches_curated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.curated_matches
    ADD CONSTRAINT curated_matches_curated_by_fkey FOREIGN KEY (curated_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: curated_matches curated_matches_match_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.curated_matches
    ADD CONSTRAINT curated_matches_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE CASCADE;


--
-- Name: curated_matches curated_matches_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.curated_matches
    ADD CONSTRAINT curated_matches_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venues(id) ON DELETE CASCADE;


--
-- Name: device_tokens device_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.device_tokens
    ADD CONSTRAINT device_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: featured_events featured_events_competition_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.featured_events
    ADD CONSTRAINT featured_events_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES public.competitions(id);


--
-- Name: fet_wallet_transactions fet_wallet_transactions_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fet_wallet_transactions
    ADD CONSTRAINT fet_wallet_transactions_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.match_pool_entries(id) ON DELETE SET NULL;


--
-- Name: fet_wallet_transactions fet_wallet_transactions_match_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fet_wallet_transactions
    ADD CONSTRAINT fet_wallet_transactions_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE SET NULL;


--
-- Name: fet_wallet_transactions fet_wallet_transactions_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fet_wallet_transactions
    ADD CONSTRAINT fet_wallet_transactions_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE SET NULL;


--
-- Name: fet_wallet_transactions fet_wallet_transactions_pool_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fet_wallet_transactions
    ADD CONSTRAINT fet_wallet_transactions_pool_entry_id_fkey FOREIGN KEY (pool_entry_id) REFERENCES public.match_pool_entries(id) ON DELETE SET NULL;


--
-- Name: fet_wallet_transactions fet_wallet_transactions_pool_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fet_wallet_transactions
    ADD CONSTRAINT fet_wallet_transactions_pool_id_fkey FOREIGN KEY (pool_id) REFERENCES public.match_pools(id) ON DELETE SET NULL;


--
-- Name: fet_wallet_transactions fet_wallet_transactions_settlement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fet_wallet_transactions
    ADD CONSTRAINT fet_wallet_transactions_settlement_id_fkey FOREIGN KEY (settlement_id) REFERENCES public.match_pool_settlements(id) ON DELETE SET NULL;


--
-- Name: fet_wallet_transactions fet_wallet_transactions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fet_wallet_transactions
    ADD CONSTRAINT fet_wallet_transactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: fet_wallet_transactions fet_wallet_transactions_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fet_wallet_transactions
    ADD CONSTRAINT fet_wallet_transactions_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venues(id) ON DELETE SET NULL;


--
-- Name: fet_wallet_transactions fet_wallet_transactions_wallet_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fet_wallet_transactions
    ADD CONSTRAINT fet_wallet_transactions_wallet_id_fkey FOREIGN KEY (wallet_id) REFERENCES public.fet_wallets(id) ON DELETE SET NULL;


--
-- Name: fet_wallets fet_wallets_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fet_wallets
    ADD CONSTRAINT fet_wallets_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: match_alert_dispatch_log match_alert_dispatch_log_match_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_alert_dispatch_log
    ADD CONSTRAINT match_alert_dispatch_log_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE CASCADE;


--
-- Name: match_alert_dispatch_log match_alert_dispatch_log_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_alert_dispatch_log
    ADD CONSTRAINT match_alert_dispatch_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: match_alert_subscriptions match_alert_subscriptions_match_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_alert_subscriptions
    ADD CONSTRAINT match_alert_subscriptions_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE CASCADE;


--
-- Name: match_alert_subscriptions match_alert_subscriptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_alert_subscriptions
    ADD CONSTRAINT match_alert_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: match_pool_camps match_pool_camps_pool_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pool_camps
    ADD CONSTRAINT match_pool_camps_pool_id_fkey FOREIGN KEY (pool_id) REFERENCES public.match_pools(id) ON DELETE CASCADE;


--
-- Name: match_pool_camps match_pool_camps_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pool_camps
    ADD CONSTRAINT match_pool_camps_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE SET NULL;


--
-- Name: match_pool_entries match_pool_entries_camp_belongs_to_pool; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pool_entries
    ADD CONSTRAINT match_pool_entries_camp_belongs_to_pool FOREIGN KEY (pool_id, camp_id) REFERENCES public.match_pool_camps(pool_id, id) ON DELETE CASCADE;


--
-- Name: match_pool_entries match_pool_entries_invited_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pool_entries
    ADD CONSTRAINT match_pool_entries_invited_by_user_id_fkey FOREIGN KEY (invited_by_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: match_pool_entries match_pool_entries_pool_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pool_entries
    ADD CONSTRAINT match_pool_entries_pool_id_fkey FOREIGN KEY (pool_id) REFERENCES public.match_pools(id) ON DELETE CASCADE;


--
-- Name: match_pool_entries match_pool_entries_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pool_entries
    ADD CONSTRAINT match_pool_entries_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: match_pool_invites match_pool_invites_invitee_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pool_invites
    ADD CONSTRAINT match_pool_invites_invitee_user_id_fkey FOREIGN KEY (invitee_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: match_pool_invites match_pool_invites_inviter_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pool_invites
    ADD CONSTRAINT match_pool_invites_inviter_user_id_fkey FOREIGN KEY (inviter_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: match_pool_invites match_pool_invites_joined_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pool_invites
    ADD CONSTRAINT match_pool_invites_joined_entry_id_fkey FOREIGN KEY (joined_entry_id) REFERENCES public.match_pool_entries(id) ON DELETE SET NULL;


--
-- Name: match_pool_invites match_pool_invites_pool_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pool_invites
    ADD CONSTRAINT match_pool_invites_pool_id_fkey FOREIGN KEY (pool_id) REFERENCES public.match_pools(id) ON DELETE CASCADE;


--
-- Name: match_pool_invites match_pool_invites_reward_tx_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pool_invites
    ADD CONSTRAINT match_pool_invites_reward_tx_id_fkey FOREIGN KEY (reward_tx_id) REFERENCES public.fet_wallet_transactions(id) ON DELETE SET NULL;


--
-- Name: match_pool_settlements match_pool_settlements_match_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pool_settlements
    ADD CONSTRAINT match_pool_settlements_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE SET NULL;


--
-- Name: match_pool_settlements match_pool_settlements_pool_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pool_settlements
    ADD CONSTRAINT match_pool_settlements_pool_id_fkey FOREIGN KEY (pool_id) REFERENCES public.match_pools(id) ON DELETE CASCADE;


--
-- Name: match_pool_settlements match_pool_settlements_result_camp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pool_settlements
    ADD CONSTRAINT match_pool_settlements_result_camp_id_fkey FOREIGN KEY (result_camp_id) REFERENCES public.match_pool_camps(id) ON DELETE SET NULL;


--
-- Name: match_pools match_pools_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pools
    ADD CONSTRAINT match_pools_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.countries(id) ON DELETE SET NULL;


--
-- Name: match_pools match_pools_creator_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pools
    ADD CONSTRAINT match_pools_creator_user_id_fkey FOREIGN KEY (creator_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: match_pools match_pools_match_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pools
    ADD CONSTRAINT match_pools_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE CASCADE;


--
-- Name: match_pools match_pools_result_camp_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pools
    ADD CONSTRAINT match_pools_result_camp_fkey FOREIGN KEY (result_camp_id) REFERENCES public.match_pool_camps(id) ON DELETE SET NULL;


--
-- Name: match_pools match_pools_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_pools
    ADD CONSTRAINT match_pools_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venues(id) ON DELETE CASCADE;


--
-- Name: matches matches_away_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_away_team_id_fkey FOREIGN KEY (away_team_id) REFERENCES public.teams(id);


--
-- Name: matches matches_competition_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES public.competitions(id);


--
-- Name: matches matches_home_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_home_team_id_fkey FOREIGN KEY (home_team_id) REFERENCES public.teams(id);


--
-- Name: matches matches_season_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_season_id_fkey FOREIGN KEY (season_id) REFERENCES public.seasons(id) ON DELETE SET NULL;


--
-- Name: menu_categories menu_categories_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_categories
    ADD CONSTRAINT menu_categories_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venues(id) ON DELETE CASCADE;


--
-- Name: menu_items menu_items_category_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_items
    ADD CONSTRAINT menu_items_category_fkey FOREIGN KEY (category_id, venue_id) REFERENCES public.menu_categories(id, venue_id) ON DELETE CASCADE;


--
-- Name: menu_items menu_items_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_items
    ADD CONSTRAINT menu_items_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venues(id) ON DELETE CASCADE;


--
-- Name: moderation_reports moderation_reports_assigned_to_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.moderation_reports
    ADD CONSTRAINT moderation_reports_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES public.admin_users(id);


--
-- Name: moderation_reports moderation_reports_reporter_auth_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.moderation_reports
    ADD CONSTRAINT moderation_reports_reporter_auth_fkey FOREIGN KEY (reporter_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: notification_log notification_log_user_id_auth_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_log
    ADD CONSTRAINT notification_log_user_id_auth_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: notification_preferences notification_preferences_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_preferences
    ADD CONSTRAINT notification_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: onboarding_requests onboarding_requests_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.onboarding_requests
    ADD CONSTRAINT onboarding_requests_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: onboarding_requests onboarding_requests_submitted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.onboarding_requests
    ADD CONSTRAINT onboarding_requests_submitted_by_fkey FOREIGN KEY (submitted_by) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: onboarding_requests onboarding_requests_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.onboarding_requests
    ADD CONSTRAINT onboarding_requests_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venues(id) ON DELETE CASCADE;


--
-- Name: order_items order_items_menu_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_menu_item_id_fkey FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id) ON DELETE SET NULL;


--
-- Name: order_items order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;


--
-- Name: orders orders_table_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_table_fkey FOREIGN KEY (table_id, venue_id) REFERENCES public.tables(id, venue_id) ON DELETE RESTRICT;


--
-- Name: orders orders_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: orders orders_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venues(id) ON DELETE CASCADE;


--
-- Name: payment_events payment_events_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_events
    ADD CONSTRAINT payment_events_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;


--
-- Name: pending_menu_imports pending_menu_imports_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pending_menu_imports
    ADD CONSTRAINT pending_menu_imports_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: pending_menu_imports pending_menu_imports_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pending_menu_imports
    ADD CONSTRAINT pending_menu_imports_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venues(id) ON DELETE CASCADE;


--
-- Name: platform_content_blocks platform_content_blocks_feature_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_content_blocks
    ADD CONSTRAINT platform_content_blocks_feature_key_fkey FOREIGN KEY (feature_key) REFERENCES public.platform_features(feature_key) ON DELETE SET NULL;


--
-- Name: platform_feature_channels platform_feature_channels_feature_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_feature_channels
    ADD CONSTRAINT platform_feature_channels_feature_key_fkey FOREIGN KEY (feature_key) REFERENCES public.platform_features(feature_key) ON DELETE CASCADE;


--
-- Name: platform_feature_rules platform_feature_rules_feature_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_feature_rules
    ADD CONSTRAINT platform_feature_rules_feature_key_fkey FOREIGN KEY (feature_key) REFERENCES public.platform_features(feature_key) ON DELETE CASCADE;


--
-- Name: pool_operation_audit_logs pool_operation_audit_logs_actor_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pool_operation_audit_logs
    ADD CONSTRAINT pool_operation_audit_logs_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: pool_operation_audit_logs pool_operation_audit_logs_match_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pool_operation_audit_logs
    ADD CONSTRAINT pool_operation_audit_logs_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE SET NULL;


--
-- Name: pool_operation_audit_logs pool_operation_audit_logs_pool_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pool_operation_audit_logs
    ADD CONSTRAINT pool_operation_audit_logs_pool_id_fkey FOREIGN KEY (pool_id) REFERENCES public.match_pools(id) ON DELETE SET NULL;


--
-- Name: pool_operation_audit_logs pool_operation_audit_logs_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pool_operation_audit_logs
    ADD CONSTRAINT pool_operation_audit_logs_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venues(id) ON DELETE SET NULL;


--
-- Name: product_events product_events_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_events
    ADD CONSTRAINT product_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: profiles profiles_favorite_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_favorite_team_id_fkey FOREIGN KEY (favorite_team_id) REFERENCES public.teams(id) ON DELETE SET NULL;


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: reward_rules reward_rules_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reward_rules
    ADD CONSTRAINT reward_rules_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.countries(id) ON DELETE CASCADE;


--
-- Name: reward_rules reward_rules_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reward_rules
    ADD CONSTRAINT reward_rules_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venues(id) ON DELETE CASCADE;


--
-- Name: seasons seasons_competition_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seasons
    ADD CONSTRAINT seasons_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES public.competitions(id) ON DELETE CASCADE;


--
-- Name: standings standings_competition_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.standings
    ADD CONSTRAINT standings_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES public.competitions(id) ON DELETE CASCADE;


--
-- Name: standings standings_season_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.standings
    ADD CONSTRAINT standings_season_id_fkey FOREIGN KEY (season_id) REFERENCES public.seasons(id) ON DELETE CASCADE;


--
-- Name: standings standings_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.standings
    ADD CONSTRAINT standings_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: tables tables_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tables
    ADD CONSTRAINT tables_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venues(id) ON DELETE CASCADE;


--
-- Name: team_aliases team_aliases_v2_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_aliases
    ADD CONSTRAINT team_aliases_v2_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: team_form_features team_form_features_match_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_form_features
    ADD CONSTRAINT team_form_features_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE CASCADE;


--
-- Name: team_form_features team_form_features_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_form_features
    ADD CONSTRAINT team_form_features_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: teams teams_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.countries(id) ON DELETE SET NULL;


--
-- Name: user_favorite_teams user_favorite_teams_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_favorite_teams
    ADD CONSTRAINT user_favorite_teams_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: user_favorite_teams user_favorite_teams_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_favorite_teams
    ADD CONSTRAINT user_favorite_teams_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_followed_competitions user_followed_competitions_competition_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_followed_competitions
    ADD CONSTRAINT user_followed_competitions_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES public.competitions(id) ON DELETE CASCADE;


--
-- Name: user_followed_competitions user_followed_competitions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_followed_competitions
    ADD CONSTRAINT user_followed_competitions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_market_preferences user_market_preferences_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_market_preferences
    ADD CONSTRAINT user_market_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_status user_status_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_status
    ADD CONSTRAINT user_status_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: venue_users venue_users_invited_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venue_users
    ADD CONSTRAINT venue_users_invited_by_fkey FOREIGN KEY (invited_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: venue_users venue_users_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venue_users
    ADD CONSTRAINT venue_users_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: venue_users venue_users_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venue_users
    ADD CONSTRAINT venue_users_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venues(id) ON DELETE CASCADE;


--
-- Name: venues venues_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT venues_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.countries(id) ON DELETE RESTRICT;


--
-- Name: venues venues_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT venues_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: venues venues_owner_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT venues_owner_user_id_fkey FOREIGN KEY (owner_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: whatsapp_auth_sessions whatsapp_auth_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.whatsapp_auth_sessions
    ADD CONSTRAINT whatsapp_auth_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: admin_users Active admins read admin directory; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Active admins read admin directory" ON public.admin_users FOR SELECT TO authenticated USING (public.is_active_admin_operator(auth.uid()));


--
-- Name: app_config_remote Admin write app config remote; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admin write app config remote" ON public.app_config_remote TO authenticated USING (public.is_admin_manager(auth.uid())) WITH CHECK (public.is_admin_manager(auth.uid()));


--
-- Name: country_currency_map Admin write country currency map; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admin write country currency map" ON public.country_currency_map TO authenticated USING (public.is_admin_manager(auth.uid())) WITH CHECK (public.is_admin_manager(auth.uid()));


--
-- Name: country_region_map Admin write country region map; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admin write country region map" ON public.country_region_map TO authenticated USING (public.is_admin_manager(auth.uid())) WITH CHECK (public.is_admin_manager(auth.uid()));


--
-- Name: currency_display_metadata Admin write currency display metadata; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admin write currency display metadata" ON public.currency_display_metadata TO authenticated USING (public.is_admin_manager(auth.uid())) WITH CHECK (public.is_admin_manager(auth.uid()));


--
-- Name: feature_flags Admin write feature flags; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admin write feature flags" ON public.feature_flags TO authenticated USING (public.is_admin_manager(auth.uid())) WITH CHECK (public.is_admin_manager(auth.uid()));


--
-- Name: launch_moments Admin write launch moments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admin write launch moments" ON public.launch_moments TO authenticated USING (public.is_admin_manager(auth.uid())) WITH CHECK (public.is_admin_manager(auth.uid()));


--
-- Name: phone_presets Admin write phone presets; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admin write phone presets" ON public.phone_presets TO authenticated USING (public.is_admin_manager(auth.uid())) WITH CHECK (public.is_admin_manager(auth.uid()));


--
-- Name: teams Admin write teams; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admin write teams" ON public.teams TO authenticated USING (public.is_admin_manager(auth.uid())) WITH CHECK (public.is_admin_manager(auth.uid()));


--
-- Name: account_deletion_requests Admins manage account deletion requests; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins manage account deletion requests" ON public.account_deletion_requests TO authenticated USING (public.is_admin_manager(auth.uid())) WITH CHECK (public.is_admin_manager(auth.uid()));


--
-- Name: competitions Admins manage competitions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins manage competitions" ON public.competitions TO authenticated USING (public.is_admin_manager(auth.uid())) WITH CHECK (public.is_admin_manager(auth.uid()));


--
-- Name: matches Admins manage matches; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins manage matches" ON public.matches TO authenticated USING (public.is_admin_manager(auth.uid())) WITH CHECK (public.is_admin_manager(auth.uid()));


--
-- Name: moderation_reports Admins manage moderation reports; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins manage moderation reports" ON public.moderation_reports TO authenticated USING (public.is_admin_manager(auth.uid())) WITH CHECK (public.is_admin_manager(auth.uid()));


--
-- Name: platform_content_blocks Admins manage platform content blocks; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins manage platform content blocks" ON public.platform_content_blocks TO authenticated USING (public.is_admin_manager(auth.uid())) WITH CHECK (public.is_admin_manager(auth.uid()));


--
-- Name: platform_feature_channels Admins manage platform feature channels; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins manage platform feature channels" ON public.platform_feature_channels TO authenticated USING (public.is_admin_manager(auth.uid())) WITH CHECK (public.is_admin_manager(auth.uid()));


--
-- Name: platform_feature_rules Admins manage platform feature rules; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins manage platform feature rules" ON public.platform_feature_rules TO authenticated USING (public.is_admin_manager(auth.uid())) WITH CHECK (public.is_admin_manager(auth.uid()));


--
-- Name: platform_features Admins manage platform features; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins manage platform features" ON public.platform_features TO authenticated USING (public.is_admin_manager(auth.uid())) WITH CHECK (public.is_admin_manager(auth.uid()));


--
-- Name: standings Admins manage standings; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins manage standings" ON public.standings TO authenticated USING (public.current_user_has_admin_role(ARRAY['moderator'::text, 'admin'::text, 'super_admin'::text])) WITH CHECK (public.current_user_has_admin_role(ARRAY['moderator'::text, 'admin'::text, 'super_admin'::text]));


--
-- Name: team_aliases Admins manage team aliases; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins manage team aliases" ON public.team_aliases TO authenticated USING (public.current_user_has_admin_role(ARRAY['moderator'::text, 'admin'::text, 'super_admin'::text])) WITH CHECK (public.current_user_has_admin_role(ARRAY['moderator'::text, 'admin'::text, 'super_admin'::text]));


--
-- Name: team_form_features Admins manage team form features; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins manage team form features" ON public.team_form_features TO authenticated USING (public.current_user_has_admin_role(ARRAY['moderator'::text, 'admin'::text, 'super_admin'::text])) WITH CHECK (public.current_user_has_admin_role(ARRAY['moderator'::text, 'admin'::text, 'super_admin'::text]));


--
-- Name: moderation_reports Admins read moderation reports; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins read moderation reports" ON public.moderation_reports FOR SELECT TO authenticated USING (public.is_active_admin_operator(auth.uid()));


--
-- Name: notification_log Admins read notifications; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins read notifications" ON public.notification_log FOR SELECT TO authenticated USING (public.is_active_admin_operator(auth.uid()));


--
-- Name: fet_wallet_transactions Admins read wallet transactions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins read wallet transactions" ON public.fet_wallet_transactions FOR SELECT TO authenticated USING (public.is_active_admin_operator(auth.uid()));


--
-- Name: app_config_remote Public read app config remote; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read app config remote" ON public.app_config_remote FOR SELECT USING (true);


--
-- Name: competitions Public read competitions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read competitions" ON public.competitions FOR SELECT USING (true);


--
-- Name: country_currency_map Public read country currency map; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read country currency map" ON public.country_currency_map FOR SELECT USING (true);


--
-- Name: country_region_map Public read country region map; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read country region map" ON public.country_region_map FOR SELECT USING (true);


--
-- Name: currency_display_metadata Public read currency display; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read currency display" ON public.currency_display_metadata FOR SELECT USING (true);


--
-- Name: feature_flags Public read feature flags; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read feature flags" ON public.feature_flags FOR SELECT USING (true);


--
-- Name: launch_moments Public read launch moments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read launch moments" ON public.launch_moments FOR SELECT USING (true);


--
-- Name: matches Public read matches; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read matches" ON public.matches FOR SELECT USING (true);


--
-- Name: phone_presets Public read phone presets; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read phone presets" ON public.phone_presets FOR SELECT USING (true);


--
-- Name: teams Public read teams; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read teams" ON public.teams FOR SELECT USING (true);


--
-- Name: admin_users Super admins manage admin directory; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Super admins manage admin directory" ON public.admin_users TO authenticated USING (public.is_super_admin_user(auth.uid())) WITH CHECK (public.is_super_admin_user(auth.uid()));


--
-- Name: user_favorite_teams Users can delete own favorite teams; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete own favorite teams" ON public.user_favorite_teams FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: product_events Users can insert own events; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own events" ON public.product_events FOR INSERT TO authenticated WITH CHECK ((user_id = auth.uid()));


--
-- Name: user_favorite_teams Users can insert own favorite teams; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own favorite teams" ON public.user_favorite_teams FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: user_market_preferences Users can insert own market preferences; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own market preferences" ON public.user_market_preferences FOR INSERT TO authenticated WITH CHECK ((auth.uid() = user_id));


--
-- Name: profiles Users can insert own profile; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: user_followed_competitions Users can manage followed competitions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can manage followed competitions" ON public.user_followed_competitions USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: user_favorite_teams Users can read own favorite teams; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can read own favorite teams" ON public.user_favorite_teams FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: user_market_preferences Users can read own market preferences; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can read own market preferences" ON public.user_market_preferences FOR SELECT TO authenticated USING ((auth.uid() = user_id));


--
-- Name: user_favorite_teams Users can update own favorite teams; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update own favorite teams" ON public.user_favorite_teams FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: user_market_preferences Users can update own market preferences; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update own market preferences" ON public.user_market_preferences FOR UPDATE TO authenticated USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: profiles Users can update own profile; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: profiles Users can view own profile; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: fet_wallet_transactions Users can view own transactions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view own transactions" ON public.fet_wallet_transactions FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: fet_wallets Users can view own wallet; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view own wallet" ON public.fet_wallets FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: account_deletion_requests Users cancel own pending deletion requests; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users cancel own pending deletion requests" ON public.account_deletion_requests FOR UPDATE TO authenticated USING (((auth.uid() = user_id) AND (status = 'pending'::text))) WITH CHECK (((auth.uid() = user_id) AND (status = ANY (ARRAY['pending'::text, 'cancelled'::text]))));


--
-- Name: account_deletion_requests Users create own account deletion requests; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users create own account deletion requests" ON public.account_deletion_requests FOR INSERT TO authenticated WITH CHECK (((auth.uid() = user_id) AND (status = 'pending'::text) AND (processed_at IS NULL) AND (processed_by IS NULL)));


--
-- Name: user_followed_competitions Users manage own competition follows; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own competition follows" ON public.user_followed_competitions TO authenticated USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: device_tokens Users manage own device tokens; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own device tokens" ON public.device_tokens TO authenticated USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: match_alert_subscriptions Users manage own match alerts; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own match alerts" ON public.match_alert_subscriptions TO authenticated USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: notification_preferences Users manage own notification prefs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own notification prefs" ON public.notification_preferences TO authenticated USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: account_deletion_requests Users read own account deletion requests; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users read own account deletion requests" ON public.account_deletion_requests FOR SELECT TO authenticated USING ((auth.uid() = user_id));


--
-- Name: notification_log Users read own notifications; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users read own notifications" ON public.notification_log FOR SELECT TO authenticated USING ((auth.uid() = user_id));


--
-- Name: user_status Users read own status; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users read own status" ON public.user_status FOR SELECT TO authenticated USING ((auth.uid() = user_id));


--
-- Name: fet_wallet_transactions Users read own transactions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users read own transactions" ON public.fet_wallet_transactions FOR SELECT TO authenticated USING ((auth.uid() = user_id));


--
-- Name: fet_wallets Users read own wallet; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users read own wallet" ON public.fet_wallets FOR SELECT TO authenticated USING ((auth.uid() = user_id));


--
-- Name: notification_log Users update own notifications; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users update own notifications" ON public.notification_log FOR UPDATE TO authenticated USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: account_deletion_requests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.account_deletion_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: admin_audit_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: admin_users; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;

--
-- Name: anonymous_upgrade_claims; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.anonymous_upgrade_claims ENABLE ROW LEVEL SECURITY;

--
-- Name: app_config_remote; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.app_config_remote ENABLE ROW LEVEL SECURITY;

--
-- Name: app_runtime_errors; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.app_runtime_errors ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_logs audit_logs_admin_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_logs_admin_read ON public.audit_logs FOR SELECT TO authenticated USING (public.sports_bar_is_admin());


--
-- Name: bell_requests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.bell_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: bell_requests bell_requests_insert_user; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY bell_requests_insert_user ON public.bell_requests FOR INSERT TO authenticated WITH CHECK ((user_id = auth.uid()));


--
-- Name: bell_requests bell_requests_select_user; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY bell_requests_select_user ON public.bell_requests FOR SELECT TO authenticated USING ((user_id = auth.uid()));


--
-- Name: bell_requests bell_requests_select_venue; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY bell_requests_select_venue ON public.bell_requests FOR SELECT TO authenticated USING (public.venue_user_has_role(venue_id));


--
-- Name: bell_requests bell_requests_update_venue; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY bell_requests_update_venue ON public.bell_requests FOR UPDATE TO authenticated USING (public.venue_user_has_role(venue_id)) WITH CHECK (public.venue_user_has_role(venue_id));


--
-- Name: competitions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.competitions ENABLE ROW LEVEL SECURITY;

--
-- Name: countries; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.countries ENABLE ROW LEVEL SECURITY;

--
-- Name: countries countries_admin_manage; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY countries_admin_manage ON public.countries TO authenticated USING (public.sports_bar_is_admin()) WITH CHECK (public.sports_bar_is_admin());


--
-- Name: countries countries_select_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY countries_select_active ON public.countries FOR SELECT TO anon, authenticated USING (((is_active = true) OR public.sports_bar_is_admin()));


--
-- Name: country_currency_map; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.country_currency_map ENABLE ROW LEVEL SECURITY;

--
-- Name: country_region_map; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.country_region_map ENABLE ROW LEVEL SECURITY;

--
-- Name: cron_job_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cron_job_log ENABLE ROW LEVEL SECURITY;

--
-- Name: curated_matches; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.curated_matches ENABLE ROW LEVEL SECURITY;

--
-- Name: curated_matches curated_matches_admin_manage; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY curated_matches_admin_manage ON public.curated_matches TO authenticated USING (public.is_admin_manager(( SELECT auth.uid() AS uid))) WITH CHECK (public.is_admin_manager(( SELECT auth.uid() AS uid)));


--
-- Name: curated_matches curated_matches_select_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY curated_matches_select_active ON public.curated_matches FOR SELECT TO anon, authenticated USING (((is_active = true) AND ((starts_at IS NULL) OR (starts_at <= timezone('utc'::text, now()))) AND ((expires_at IS NULL) OR (expires_at > timezone('utc'::text, now())))));


--
-- Name: currency_display_metadata; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.currency_display_metadata ENABLE ROW LEVEL SECURITY;

--
-- Name: currency_rates; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.currency_rates ENABLE ROW LEVEL SECURITY;

--
-- Name: currency_rates currency_rates_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY currency_rates_public_read ON public.currency_rates FOR SELECT USING (true);


--
-- Name: device_tokens; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: feature_flags; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;

--
-- Name: featured_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.featured_events ENABLE ROW LEVEL SECURITY;

--
-- Name: featured_events featured_events_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY featured_events_public_read ON public.featured_events FOR SELECT USING (true);


--
-- Name: fet_wallet_transactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.fet_wallet_transactions ENABLE ROW LEVEL SECURITY;

--
-- Name: fet_wallets; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.fet_wallets ENABLE ROW LEVEL SECURITY;

--
-- Name: launch_moments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.launch_moments ENABLE ROW LEVEL SECURITY;

--
-- Name: match_alert_dispatch_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.match_alert_dispatch_log ENABLE ROW LEVEL SECURITY;

--
-- Name: match_alert_subscriptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.match_alert_subscriptions ENABLE ROW LEVEL SECURITY;

--
-- Name: match_pool_camps; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.match_pool_camps ENABLE ROW LEVEL SECURITY;

--
-- Name: match_pool_camps match_pool_camps_select_visible; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY match_pool_camps_select_visible ON public.match_pool_camps FOR SELECT TO anon, authenticated USING ((EXISTS ( SELECT 1
   FROM public.match_pools p
  WHERE ((p.id = match_pool_camps.pool_id) AND ((p.status = ANY (ARRAY['open'::public.match_pool_status, 'locked'::public.match_pool_status, 'settled'::public.match_pool_status])) OR (p.creator_user_id = ( SELECT auth.uid() AS uid)) OR public.is_admin_manager(( SELECT auth.uid() AS uid)) OR ((p.venue_id IS NOT NULL) AND public.venue_user_has_role(p.venue_id)))))));


--
-- Name: match_pool_entries; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.match_pool_entries ENABLE ROW LEVEL SECURITY;

--
-- Name: match_pool_entries match_pool_entries_select_own_or_operator; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY match_pool_entries_select_own_or_operator ON public.match_pool_entries FOR SELECT TO authenticated USING (((user_id = ( SELECT auth.uid() AS uid)) OR public.is_admin_manager(( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM public.match_pools p
  WHERE ((p.id = match_pool_entries.pool_id) AND (p.venue_id IS NOT NULL) AND public.venue_user_has_role(p.venue_id))))));


--
-- Name: match_pool_invites; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.match_pool_invites ENABLE ROW LEVEL SECURITY;

--
-- Name: match_pool_invites match_pool_invites_select_participant_or_operator; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY match_pool_invites_select_participant_or_operator ON public.match_pool_invites FOR SELECT TO authenticated USING (((inviter_user_id = ( SELECT auth.uid() AS uid)) OR (invitee_user_id = ( SELECT auth.uid() AS uid)) OR public.is_admin_manager(( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM public.match_pools p
  WHERE ((p.id = match_pool_invites.pool_id) AND (p.venue_id IS NOT NULL) AND public.venue_user_has_role(p.venue_id))))));


--
-- Name: match_pool_settlements; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.match_pool_settlements ENABLE ROW LEVEL SECURITY;

--
-- Name: match_pool_settlements match_pool_settlements_select_operator; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY match_pool_settlements_select_operator ON public.match_pool_settlements FOR SELECT TO authenticated USING ((public.is_admin_manager(( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM public.match_pools p
  WHERE ((p.id = match_pool_settlements.pool_id) AND (p.venue_id IS NOT NULL) AND public.venue_user_has_role(p.venue_id))))));


--
-- Name: match_pools; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.match_pools ENABLE ROW LEVEL SECURITY;

--
-- Name: match_pools match_pools_select_public; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY match_pools_select_public ON public.match_pools FOR SELECT TO anon, authenticated USING (((status = ANY (ARRAY['open'::public.match_pool_status, 'locked'::public.match_pool_status, 'live'::public.match_pool_status, 'settled'::public.match_pool_status])) OR (creator_user_id = ( SELECT auth.uid() AS uid)) OR public.sports_bar_is_admin() OR ((venue_id IS NOT NULL) AND public.venue_user_has_role(venue_id))));


--
-- Name: matches; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;

--
-- Name: menu_categories; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.menu_categories ENABLE ROW LEVEL SECURITY;

--
-- Name: menu_categories menu_categories_delete_member; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY menu_categories_delete_member ON public.menu_categories FOR DELETE TO authenticated USING (public.venue_user_has_role(venue_id, ARRAY['owner'::public.venue_user_role, 'manager'::public.venue_user_role]));


--
-- Name: menu_categories menu_categories_insert_member; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY menu_categories_insert_member ON public.menu_categories FOR INSERT TO authenticated WITH CHECK (public.venue_user_has_role(venue_id));


--
-- Name: menu_categories menu_categories_select_member; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY menu_categories_select_member ON public.menu_categories FOR SELECT TO authenticated USING (public.venue_user_has_role(venue_id));


--
-- Name: menu_categories menu_categories_select_public; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY menu_categories_select_public ON public.menu_categories FOR SELECT USING (((is_visible = true) AND (EXISTS ( SELECT 1
   FROM public.venues v
  WHERE ((v.id = menu_categories.venue_id) AND (v.is_active = true))))));


--
-- Name: menu_categories menu_categories_update_member; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY menu_categories_update_member ON public.menu_categories FOR UPDATE TO authenticated USING (public.venue_user_has_role(venue_id)) WITH CHECK (public.venue_user_has_role(venue_id));


--
-- Name: menu_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.menu_items ENABLE ROW LEVEL SECURITY;

--
-- Name: menu_items menu_items_delete_member; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY menu_items_delete_member ON public.menu_items FOR DELETE TO authenticated USING (public.venue_user_has_role(venue_id, ARRAY['owner'::public.venue_user_role, 'manager'::public.venue_user_role]));


--
-- Name: menu_items menu_items_insert_member; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY menu_items_insert_member ON public.menu_items FOR INSERT TO authenticated WITH CHECK (public.venue_user_has_role(venue_id));


--
-- Name: menu_items menu_items_select_public; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY menu_items_select_public ON public.menu_items FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.venues v
  WHERE ((v.id = menu_items.venue_id) AND (v.is_active = true)))));


--
-- Name: menu_items menu_items_update_member; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY menu_items_update_member ON public.menu_items FOR UPDATE TO authenticated USING (public.venue_user_has_role(venue_id)) WITH CHECK (public.venue_user_has_role(venue_id));


--
-- Name: moderation_reports; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.moderation_reports ENABLE ROW LEVEL SECURITY;

--
-- Name: notification_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notification_log ENABLE ROW LEVEL SECURITY;

--
-- Name: notification_preferences; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

--
-- Name: onboarding_requests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.onboarding_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: onboarding_requests onboarding_requests_insert_submitter; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY onboarding_requests_insert_submitter ON public.onboarding_requests FOR INSERT TO authenticated WITH CHECK ((submitted_by = ( SELECT auth.uid() AS uid)));


--
-- Name: onboarding_requests onboarding_requests_select_submitter; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY onboarding_requests_select_submitter ON public.onboarding_requests FOR SELECT TO authenticated USING (((submitted_by = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM public.admin_users au
  WHERE ((au.user_id = ( SELECT auth.uid() AS uid)) AND (au.is_active = true) AND (au.role = ANY (ARRAY['super_admin'::text, 'admin'::text, 'moderator'::text])))))));


--
-- Name: onboarding_requests onboarding_requests_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY onboarding_requests_update_admin ON public.onboarding_requests FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.admin_users au
  WHERE ((au.user_id = ( SELECT auth.uid() AS uid)) AND (au.is_active = true) AND (au.role = ANY (ARRAY['super_admin'::text, 'admin'::text, 'moderator'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.admin_users au
  WHERE ((au.user_id = ( SELECT auth.uid() AS uid)) AND (au.is_active = true) AND (au.role = ANY (ARRAY['super_admin'::text, 'admin'::text, 'moderator'::text]))))));


--
-- Name: order_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

--
-- Name: order_items order_items_insert_user; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY order_items_insert_user ON public.order_items FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.orders o
  WHERE ((o.id = order_items.order_id) AND (o.user_id = auth.uid())))));


--
-- Name: order_items order_items_select_user; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY order_items_select_user ON public.order_items FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.orders o
  WHERE ((o.id = order_items.order_id) AND (o.user_id = auth.uid())))));


--
-- Name: order_items order_items_select_venue; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY order_items_select_venue ON public.order_items FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.orders o
  WHERE ((o.id = order_items.order_id) AND public.venue_user_has_role(o.venue_id)))));


--
-- Name: orders; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

--
-- Name: orders orders_insert_user; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY orders_insert_user ON public.orders FOR INSERT TO authenticated WITH CHECK ((user_id = auth.uid()));


--
-- Name: orders orders_select_user; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY orders_select_user ON public.orders FOR SELECT TO authenticated USING ((user_id = auth.uid()));


--
-- Name: orders orders_select_venue_member; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY orders_select_venue_member ON public.orders FOR SELECT TO authenticated USING (public.venue_user_has_role(venue_id));


--
-- Name: otp_verifications; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.otp_verifications ENABLE ROW LEVEL SECURITY;

--
-- Name: payment_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.payment_events ENABLE ROW LEVEL SECURITY;

--
-- Name: payment_events payment_events_select_venue; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY payment_events_select_venue ON public.payment_events FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.orders o
  WHERE ((o.id = payment_events.order_id) AND public.venue_user_has_role(o.venue_id)))));


--
-- Name: pending_menu_imports; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.pending_menu_imports ENABLE ROW LEVEL SECURITY;

--
-- Name: pending_menu_imports pending_menu_imports_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pending_menu_imports_delete ON public.pending_menu_imports FOR DELETE TO authenticated USING (public.venue_user_has_role(venue_id, ARRAY['owner'::public.venue_user_role, 'manager'::public.venue_user_role]));


--
-- Name: pending_menu_imports pending_menu_imports_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pending_menu_imports_insert ON public.pending_menu_imports FOR INSERT TO authenticated WITH CHECK (public.venue_user_has_role(venue_id));


--
-- Name: pending_menu_imports pending_menu_imports_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pending_menu_imports_select ON public.pending_menu_imports FOR SELECT TO authenticated USING (public.venue_user_has_role(venue_id));


--
-- Name: pending_menu_imports pending_menu_imports_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pending_menu_imports_update ON public.pending_menu_imports FOR UPDATE TO authenticated USING (public.venue_user_has_role(venue_id)) WITH CHECK (public.venue_user_has_role(venue_id));


--
-- Name: phone_presets; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.phone_presets ENABLE ROW LEVEL SECURITY;

--
-- Name: platform_content_blocks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.platform_content_blocks ENABLE ROW LEVEL SECURITY;

--
-- Name: platform_feature_channels; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.platform_feature_channels ENABLE ROW LEVEL SECURITY;

--
-- Name: platform_feature_rules; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.platform_feature_rules ENABLE ROW LEVEL SECURITY;

--
-- Name: platform_features; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.platform_features ENABLE ROW LEVEL SECURITY;

--
-- Name: pool_operation_audit_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.pool_operation_audit_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: pool_operation_audit_logs pool_operation_audit_logs_select_operator; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pool_operation_audit_logs_select_operator ON public.pool_operation_audit_logs FOR SELECT TO authenticated USING ((public.is_admin_manager(( SELECT auth.uid() AS uid)) OR ((venue_id IS NOT NULL) AND public.venue_user_has_role(venue_id))));


--
-- Name: product_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.product_events ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: rate_limits; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;

--
-- Name: reward_rules; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.reward_rules ENABLE ROW LEVEL SECURITY;

--
-- Name: reward_rules reward_rules_admin_manage; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY reward_rules_admin_manage ON public.reward_rules TO authenticated USING (public.sports_bar_is_admin()) WITH CHECK (public.sports_bar_is_admin());


--
-- Name: reward_rules reward_rules_select_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY reward_rules_select_active ON public.reward_rules FOR SELECT TO authenticated USING (((is_active = true) OR public.sports_bar_is_admin() OR ((venue_id IS NOT NULL) AND public.venue_user_has_role(venue_id, ARRAY['owner'::public.venue_user_role, 'manager'::public.venue_user_role]))));


--
-- Name: seasons; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.seasons ENABLE ROW LEVEL SECURITY;

--
-- Name: seasons seasons_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY seasons_public_read ON public.seasons FOR SELECT USING (true);


--
-- Name: standings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.standings ENABLE ROW LEVEL SECURITY;

--
-- Name: standings standings_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY standings_public_read ON public.standings FOR SELECT USING (true);


--
-- Name: tables; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tables ENABLE ROW LEVEL SECURITY;

--
-- Name: tables tables_delete_member; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tables_delete_member ON public.tables FOR DELETE TO authenticated USING (public.venue_user_has_role(venue_id, ARRAY['owner'::public.venue_user_role, 'manager'::public.venue_user_role]));


--
-- Name: tables tables_insert_member; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tables_insert_member ON public.tables FOR INSERT TO authenticated WITH CHECK (public.venue_user_has_role(venue_id));


--
-- Name: tables tables_select_public; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tables_select_public ON public.tables FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.venues v
  WHERE ((v.id = tables.venue_id) AND (v.is_active = true)))));


--
-- Name: tables tables_update_member; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tables_update_member ON public.tables FOR UPDATE TO authenticated USING (public.venue_user_has_role(venue_id)) WITH CHECK (public.venue_user_has_role(venue_id));


--
-- Name: team_aliases; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.team_aliases ENABLE ROW LEVEL SECURITY;

--
-- Name: team_aliases team_aliases_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY team_aliases_public_read ON public.team_aliases FOR SELECT USING (true);


--
-- Name: team_form_features; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.team_form_features ENABLE ROW LEVEL SECURITY;

--
-- Name: team_form_features team_form_features_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY team_form_features_public_read ON public.team_form_features FOR SELECT USING (true);


--
-- Name: teams; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;

--
-- Name: user_favorite_teams; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_favorite_teams ENABLE ROW LEVEL SECURITY;

--
-- Name: user_followed_competitions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_followed_competitions ENABLE ROW LEVEL SECURITY;

--
-- Name: user_market_preferences; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_market_preferences ENABLE ROW LEVEL SECURITY;

--
-- Name: user_status; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_status ENABLE ROW LEVEL SECURITY;

--
-- Name: venue_users; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.venue_users ENABLE ROW LEVEL SECURITY;

--
-- Name: venue_users venue_users_delete_owner; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY venue_users_delete_owner ON public.venue_users FOR DELETE TO authenticated USING (public.venue_user_has_role(venue_id, ARRAY['owner'::public.venue_user_role]));


--
-- Name: venue_users venue_users_insert_owner; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY venue_users_insert_owner ON public.venue_users FOR INSERT TO authenticated WITH CHECK (public.venue_user_has_role(venue_id, ARRAY['owner'::public.venue_user_role, 'manager'::public.venue_user_role]));


--
-- Name: venue_users venue_users_select_member; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY venue_users_select_member ON public.venue_users FOR SELECT TO authenticated USING (((user_id = auth.uid()) OR public.venue_user_has_role(venue_id, ARRAY['owner'::public.venue_user_role, 'manager'::public.venue_user_role])));


--
-- Name: venue_users venue_users_update_owner; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY venue_users_update_owner ON public.venue_users FOR UPDATE TO authenticated USING (public.venue_user_has_role(venue_id, ARRAY['owner'::public.venue_user_role])) WITH CHECK (public.venue_user_has_role(venue_id, ARRAY['owner'::public.venue_user_role]));


--
-- Name: venues; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.venues ENABLE ROW LEVEL SECURITY;

--
-- Name: venues venues_insert_owner; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY venues_insert_owner ON public.venues FOR INSERT TO authenticated WITH CHECK ((owner_id = auth.uid()));


--
-- Name: venues venues_select_public; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY venues_select_public ON public.venues FOR SELECT USING ((is_active = true));


--
-- Name: venues venues_update_member; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY venues_update_member ON public.venues FOR UPDATE TO authenticated USING (public.venue_user_has_role(id, ARRAY['owner'::public.venue_user_role, 'manager'::public.venue_user_role])) WITH CHECK (public.venue_user_has_role(id, ARRAY['owner'::public.venue_user_role, 'manager'::public.venue_user_role]));


--
-- Name: whatsapp_auth_sessions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.whatsapp_auth_sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- Name: FUNCTION active_admin_record_id(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.active_admin_record_id() TO anon;
GRANT ALL ON FUNCTION public.active_admin_record_id() TO authenticated;
GRANT ALL ON FUNCTION public.active_admin_record_id() TO service_role;


--
-- Name: FUNCTION admin_adjust_fet(p_target_user_id uuid, p_amount_fet bigint, p_direction text, p_reason text, p_idempotency_key text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_adjust_fet(p_target_user_id uuid, p_amount_fet bigint, p_direction text, p_reason text, p_idempotency_key text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_adjust_fet(p_target_user_id uuid, p_amount_fet bigint, p_direction text, p_reason text, p_idempotency_key text) TO authenticated;
GRANT ALL ON FUNCTION public.admin_adjust_fet(p_target_user_id uuid, p_amount_fet bigint, p_direction text, p_reason text, p_idempotency_key text) TO service_role;


--
-- Name: FUNCTION admin_ban_user(p_target_user_id uuid, p_reason text, p_until timestamp with time zone); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_ban_user(p_target_user_id uuid, p_reason text, p_until timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_ban_user(p_target_user_id uuid, p_reason text, p_until timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.admin_ban_user(p_target_user_id uuid, p_reason text, p_until timestamp with time zone) TO service_role;


--
-- Name: TABLE admin_users; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.admin_users TO anon;
GRANT ALL ON TABLE public.admin_users TO authenticated;
GRANT ALL ON TABLE public.admin_users TO service_role;


--
-- Name: FUNCTION admin_change_admin_role(p_admin_id uuid, p_role text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_change_admin_role(p_admin_id uuid, p_role text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_change_admin_role(p_admin_id uuid, p_role text) TO authenticated;
GRANT ALL ON FUNCTION public.admin_change_admin_role(p_admin_id uuid, p_role text) TO service_role;


--
-- Name: FUNCTION admin_competition_distribution(p_days integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_competition_distribution(p_days integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_competition_distribution(p_days integer) TO authenticated;
GRANT ALL ON FUNCTION public.admin_competition_distribution(p_days integer) TO service_role;


--
-- Name: FUNCTION admin_credit_fet(p_target_user_id uuid, p_amount bigint, p_reason text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_credit_fet(p_target_user_id uuid, p_amount bigint, p_reason text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_credit_fet(p_target_user_id uuid, p_amount bigint, p_reason text) TO authenticated;
GRANT ALL ON FUNCTION public.admin_credit_fet(p_target_user_id uuid, p_amount bigint, p_reason text) TO service_role;


--
-- Name: FUNCTION admin_curate_match(p_match_id text, p_country_id uuid, p_venue_id uuid, p_priority integer, p_reason text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.admin_curate_match(p_match_id text, p_country_id uuid, p_venue_id uuid, p_priority integer, p_reason text) TO authenticated;
GRANT ALL ON FUNCTION public.admin_curate_match(p_match_id text, p_country_id uuid, p_venue_id uuid, p_priority integer, p_reason text) TO service_role;


--
-- Name: FUNCTION admin_dashboard_kpis(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_dashboard_kpis() FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_dashboard_kpis() TO authenticated;
GRANT ALL ON FUNCTION public.admin_dashboard_kpis() TO service_role;


--
-- Name: FUNCTION admin_debit_fet(p_target_user_id uuid, p_amount bigint, p_reason text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_debit_fet(p_target_user_id uuid, p_amount bigint, p_reason text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_debit_fet(p_target_user_id uuid, p_amount bigint, p_reason text) TO authenticated;
GRANT ALL ON FUNCTION public.admin_debit_fet(p_target_user_id uuid, p_amount bigint, p_reason text) TO service_role;


--
-- Name: FUNCTION admin_fet_flow_weekly(p_weeks integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_fet_flow_weekly(p_weeks integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_fet_flow_weekly(p_weeks integer) TO authenticated;
GRANT ALL ON FUNCTION public.admin_fet_flow_weekly(p_weeks integer) TO service_role;


--
-- Name: FUNCTION admin_freeze_wallet(p_target_user_id uuid, p_reason text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_freeze_wallet(p_target_user_id uuid, p_reason text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_freeze_wallet(p_target_user_id uuid, p_reason text) TO authenticated;
GRANT ALL ON FUNCTION public.admin_freeze_wallet(p_target_user_id uuid, p_reason text) TO service_role;


--
-- Name: FUNCTION admin_global_search(p_query text, p_limit integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_global_search(p_query text, p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_global_search(p_query text, p_limit integer) TO authenticated;
GRANT ALL ON FUNCTION public.admin_global_search(p_query text, p_limit integer) TO service_role;


--
-- Name: FUNCTION admin_grant_access(p_phone text, p_role text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_grant_access(p_phone text, p_role text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_grant_access(p_phone text, p_role text) TO authenticated;
GRANT ALL ON FUNCTION public.admin_grant_access(p_phone text, p_role text) TO service_role;


--
-- Name: FUNCTION admin_log_action(p_action text, p_module text, p_target_type text, p_target_id text, p_before_state jsonb, p_after_state jsonb, p_metadata jsonb); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_log_action(p_action text, p_module text, p_target_type text, p_target_id text, p_before_state jsonb, p_after_state jsonb, p_metadata jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_log_action(p_action text, p_module text, p_target_type text, p_target_id text, p_before_state jsonb, p_after_state jsonb, p_metadata jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.admin_log_action(p_action text, p_module text, p_target_type text, p_target_id text, p_before_state jsonb, p_after_state jsonb, p_metadata jsonb) TO service_role;


--
-- Name: FUNCTION admin_pool_engagement_daily(p_days integer); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.admin_pool_engagement_daily(p_days integer) TO authenticated;
GRANT ALL ON FUNCTION public.admin_pool_engagement_daily(p_days integer) TO service_role;


--
-- Name: FUNCTION admin_pool_engagement_kpis(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.admin_pool_engagement_kpis() TO authenticated;
GRANT ALL ON FUNCTION public.admin_pool_engagement_kpis() TO service_role;


--
-- Name: FUNCTION admin_pool_operations_kpis(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_pool_operations_kpis() FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_pool_operations_kpis() TO authenticated;
GRANT ALL ON FUNCTION public.admin_pool_operations_kpis() TO service_role;


--
-- Name: FUNCTION admin_pool_operations_queue(p_limit integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_pool_operations_queue(p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_pool_operations_queue(p_limit integer) TO authenticated;
GRANT ALL ON FUNCTION public.admin_pool_operations_queue(p_limit integer) TO service_role;


--
-- Name: FUNCTION admin_query_daily_active_users(p_since timestamp with time zone, p_until timestamp with time zone); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_query_daily_active_users(p_since timestamp with time zone, p_until timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_query_daily_active_users(p_since timestamp with time zone, p_until timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.admin_query_daily_active_users(p_since timestamp with time zone, p_until timestamp with time zone) TO service_role;


--
-- Name: FUNCTION admin_query_event_counts(p_since timestamp with time zone, p_until timestamp with time zone); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_query_event_counts(p_since timestamp with time zone, p_until timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_query_event_counts(p_since timestamp with time zone, p_until timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.admin_query_event_counts(p_since timestamp with time zone, p_until timestamp with time zone) TO service_role;


--
-- Name: FUNCTION admin_query_screen_views(p_since timestamp with time zone, p_until timestamp with time zone); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_query_screen_views(p_since timestamp with time zone, p_until timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_query_screen_views(p_since timestamp with time zone, p_until timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.admin_query_screen_views(p_since timestamp with time zone, p_until timestamp with time zone) TO service_role;


--
-- Name: FUNCTION admin_revoke_access(p_admin_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_revoke_access(p_admin_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_revoke_access(p_admin_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.admin_revoke_access(p_admin_id uuid) TO service_role;


--
-- Name: FUNCTION admin_run_pool_settlement(p_limit integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_run_pool_settlement(p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_run_pool_settlement(p_limit integer) TO authenticated;
GRANT ALL ON FUNCTION public.admin_run_pool_settlement(p_limit integer) TO service_role;


--
-- Name: FUNCTION admin_set_competition_featured(p_competition_id text, p_is_featured boolean); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_set_competition_featured(p_competition_id text, p_is_featured boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_set_competition_featured(p_competition_id text, p_is_featured boolean) TO authenticated;
GRANT ALL ON FUNCTION public.admin_set_competition_featured(p_competition_id text, p_is_featured boolean) TO service_role;


--
-- Name: FUNCTION admin_set_feature_flag(p_flag_id text, p_is_enabled boolean); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_set_feature_flag(p_flag_id text, p_is_enabled boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_set_feature_flag(p_flag_id text, p_is_enabled boolean) TO authenticated;
GRANT ALL ON FUNCTION public.admin_set_feature_flag(p_flag_id text, p_is_enabled boolean) TO service_role;


--
-- Name: FUNCTION admin_set_featured_event_active(p_event_id uuid, p_is_active boolean); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_set_featured_event_active(p_event_id uuid, p_is_active boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_set_featured_event_active(p_event_id uuid, p_is_active boolean) TO authenticated;
GRANT ALL ON FUNCTION public.admin_set_featured_event_active(p_event_id uuid, p_is_active boolean) TO service_role;


--
-- Name: FUNCTION admin_trigger_currency_rate_refresh(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_trigger_currency_rate_refresh() FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_trigger_currency_rate_refresh() TO authenticated;
GRANT ALL ON FUNCTION public.admin_trigger_currency_rate_refresh() TO service_role;


--
-- Name: FUNCTION admin_unban_user(p_target_user_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_unban_user(p_target_user_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_unban_user(p_target_user_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.admin_unban_user(p_target_user_id uuid) TO service_role;


--
-- Name: FUNCTION admin_unfreeze_wallet(p_target_user_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_unfreeze_wallet(p_target_user_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_unfreeze_wallet(p_target_user_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.admin_unfreeze_wallet(p_target_user_id uuid) TO service_role;


--
-- Name: FUNCTION admin_update_account_deletion_request(p_request_id uuid, p_status text, p_resolution_notes text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_update_account_deletion_request(p_request_id uuid, p_status text, p_resolution_notes text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_update_account_deletion_request(p_request_id uuid, p_status text, p_resolution_notes text) TO authenticated;
GRANT ALL ON FUNCTION public.admin_update_account_deletion_request(p_request_id uuid, p_status text, p_resolution_notes text) TO service_role;


--
-- Name: FUNCTION admin_update_match_result(p_match_id text, p_home_goals integer, p_away_goals integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_update_match_result(p_match_id text, p_home_goals integer, p_away_goals integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_update_match_result(p_match_id text, p_home_goals integer, p_away_goals integer) TO authenticated;
GRANT ALL ON FUNCTION public.admin_update_match_result(p_match_id text, p_home_goals integer, p_away_goals integer) TO service_role;


--
-- Name: FUNCTION admin_update_moderation_report_status(p_report_id uuid, p_status text, p_resolution_notes text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_update_moderation_report_status(p_report_id uuid, p_status text, p_resolution_notes text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_update_moderation_report_status(p_report_id uuid, p_status text, p_resolution_notes text) TO authenticated;
GRANT ALL ON FUNCTION public.admin_update_moderation_report_status(p_report_id uuid, p_status text, p_resolution_notes text) TO service_role;


--
-- Name: FUNCTION admin_upsert_feature_flag(p_key text, p_market text, p_platform text, p_enabled boolean, p_description text, p_rollout_pct integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_upsert_feature_flag(p_key text, p_market text, p_platform text, p_enabled boolean, p_description text, p_rollout_pct integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_upsert_feature_flag(p_key text, p_market text, p_platform text, p_enabled boolean, p_description text, p_rollout_pct integer) TO authenticated;
GRANT ALL ON FUNCTION public.admin_upsert_feature_flag(p_key text, p_market text, p_platform text, p_enabled boolean, p_description text, p_rollout_pct integer) TO service_role;


--
-- Name: FUNCTION admin_upsert_platform_content_block(p_payload jsonb); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_upsert_platform_content_block(p_payload jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_upsert_platform_content_block(p_payload jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.admin_upsert_platform_content_block(p_payload jsonb) TO service_role;


--
-- Name: FUNCTION admin_upsert_platform_feature(p_payload jsonb); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_upsert_platform_feature(p_payload jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_upsert_platform_feature(p_payload jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.admin_upsert_platform_feature(p_payload jsonb) TO service_role;


--
-- Name: TABLE seasons; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.seasons TO anon;
GRANT ALL ON TABLE public.seasons TO authenticated;
GRANT ALL ON TABLE public.seasons TO service_role;


--
-- Name: TABLE standings; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.standings TO anon;
GRANT ALL ON TABLE public.standings TO authenticated;
GRANT ALL ON TABLE public.standings TO service_role;


--
-- Name: TABLE teams; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.teams TO anon;
GRANT ALL ON TABLE public.teams TO authenticated;
GRANT ALL ON TABLE public.teams TO service_role;


--
-- Name: TABLE competition_standings; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.competition_standings TO anon;
GRANT ALL ON TABLE public.competition_standings TO authenticated;
GRANT ALL ON TABLE public.competition_standings TO service_role;


--
-- Name: FUNCTION app_competition_standings(p_competition_id text, p_season text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.app_competition_standings(p_competition_id text, p_season text) TO anon;
GRANT ALL ON FUNCTION public.app_competition_standings(p_competition_id text, p_season text) TO authenticated;
GRANT ALL ON FUNCTION public.app_competition_standings(p_competition_id text, p_season text) TO service_role;


--
-- Name: FUNCTION app_config_bigint(p_key text, p_default bigint); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.app_config_bigint(p_key text, p_default bigint) TO anon;
GRANT ALL ON FUNCTION public.app_config_bigint(p_key text, p_default bigint) TO authenticated;
GRANT ALL ON FUNCTION public.app_config_bigint(p_key text, p_default bigint) TO service_role;


--
-- Name: FUNCTION apply_match_result_code(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.apply_match_result_code() TO anon;
GRANT ALL ON FUNCTION public.apply_match_result_code() TO authenticated;
GRANT ALL ON FUNCTION public.apply_match_result_code() TO service_role;


--
-- Name: FUNCTION assert_fet_mint_within_cap(p_amount bigint, p_context text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.assert_fet_mint_within_cap(p_amount bigint, p_context text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.assert_fet_mint_within_cap(p_amount bigint, p_context text) TO anon;
GRANT ALL ON FUNCTION public.assert_fet_mint_within_cap(p_amount bigint, p_context text) TO authenticated;
GRANT ALL ON FUNCTION public.assert_fet_mint_within_cap(p_amount bigint, p_context text) TO service_role;


--
-- Name: FUNCTION assert_platform_feature_available(p_feature_key text, p_channel text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.assert_platform_feature_available(p_feature_key text, p_channel text) TO authenticated;
GRANT ALL ON FUNCTION public.assert_platform_feature_available(p_feature_key text, p_channel text) TO service_role;


--
-- Name: FUNCTION assert_verified_account_required(p_message text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.assert_verified_account_required(p_message text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.assert_verified_account_required(p_message text) TO service_role;


--
-- Name: FUNCTION assert_wallet_available(p_user_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.assert_wallet_available(p_user_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.assert_wallet_available(p_user_id uuid) TO anon;
GRANT ALL ON FUNCTION public.assert_wallet_available(p_user_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.assert_wallet_available(p_user_id uuid) TO service_role;


--
-- Name: FUNCTION assign_profile_fan_id(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.assign_profile_fan_id() TO anon;
GRANT ALL ON FUNCTION public.assign_profile_fan_id() TO authenticated;
GRANT ALL ON FUNCTION public.assign_profile_fan_id() TO service_role;


--
-- Name: FUNCTION audit_wallet_bootstrap_gaps(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.audit_wallet_bootstrap_gaps() FROM PUBLIC;
GRANT ALL ON FUNCTION public.audit_wallet_bootstrap_gaps() TO service_role;


--
-- Name: FUNCTION check_rate_limit(p_user_id uuid, p_action text, p_max_count integer, p_window_hours integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.check_rate_limit(p_user_id uuid, p_action text, p_max_count integer, p_window_hours integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.check_rate_limit(p_user_id uuid, p_action text, p_max_count integer, p_window_hours integer) TO anon;
GRANT ALL ON FUNCTION public.check_rate_limit(p_user_id uuid, p_action text, p_max_count integer, p_window_hours integer) TO authenticated;
GRANT ALL ON FUNCTION public.check_rate_limit(p_user_id uuid, p_action text, p_max_count integer, p_window_hours integer) TO service_role;


--
-- Name: FUNCTION check_rate_limit(p_user_id uuid, p_action text, p_max_count integer, p_window interval); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.check_rate_limit(p_user_id uuid, p_action text, p_max_count integer, p_window interval) FROM PUBLIC;
GRANT ALL ON FUNCTION public.check_rate_limit(p_user_id uuid, p_action text, p_max_count integer, p_window interval) TO anon;
GRANT ALL ON FUNCTION public.check_rate_limit(p_user_id uuid, p_action text, p_max_count integer, p_window interval) TO authenticated;
GRANT ALL ON FUNCTION public.check_rate_limit(p_user_id uuid, p_action text, p_max_count integer, p_window interval) TO service_role;


--
-- Name: FUNCTION cleanup_expired_otps(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.cleanup_expired_otps() FROM PUBLIC;
GRANT ALL ON FUNCTION public.cleanup_expired_otps() TO service_role;


--
-- Name: FUNCTION cleanup_rate_limits(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.cleanup_rate_limits() FROM PUBLIC;
GRANT ALL ON FUNCTION public.cleanup_rate_limits() TO service_role;


--
-- Name: FUNCTION competition_catalog_rank(p_competition_id text, p_competition_name text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.competition_catalog_rank(p_competition_id text, p_competition_name text) TO anon;
GRANT ALL ON FUNCTION public.competition_catalog_rank(p_competition_id text, p_competition_name text) TO authenticated;
GRANT ALL ON FUNCTION public.competition_catalog_rank(p_competition_id text, p_competition_name text) TO service_role;


--
-- Name: FUNCTION generate_fan_id(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.generate_fan_id() TO anon;
GRANT ALL ON FUNCTION public.generate_fan_id() TO authenticated;
GRANT ALL ON FUNCTION public.generate_fan_id() TO service_role;


--
-- Name: TABLE profiles; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.profiles TO anon;
GRANT ALL ON TABLE public.profiles TO authenticated;
GRANT ALL ON TABLE public.profiles TO service_role;


--
-- Name: FUNCTION complete_user_onboarding(p_display_name text, p_favorite_team_id text, p_favorite_team_name text, p_country_code text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.complete_user_onboarding(p_display_name text, p_favorite_team_id text, p_favorite_team_name text, p_country_code text) TO anon;
GRANT ALL ON FUNCTION public.complete_user_onboarding(p_display_name text, p_favorite_team_id text, p_favorite_team_name text, p_country_code text) TO authenticated;
GRANT ALL ON FUNCTION public.complete_user_onboarding(p_display_name text, p_favorite_team_id text, p_favorite_team_name text, p_country_code text) TO service_role;


--
-- Name: FUNCTION compute_result_code(p_home_goals integer, p_away_goals integer); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.compute_result_code(p_home_goals integer, p_away_goals integer) TO anon;
GRANT ALL ON FUNCTION public.compute_result_code(p_home_goals integer, p_away_goals integer) TO authenticated;
GRANT ALL ON FUNCTION public.compute_result_code(p_home_goals integer, p_away_goals integer) TO service_role;


--
-- Name: FUNCTION create_match_pool(p_match_id text, p_scope public.match_pool_scope, p_country_code text, p_venue_id uuid, p_title text, p_entry_fee_fet bigint, p_stake_min_fet bigint, p_stake_max_fet bigint, p_is_official boolean); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.create_match_pool(p_match_id text, p_scope public.match_pool_scope, p_country_code text, p_venue_id uuid, p_title text, p_entry_fee_fet bigint, p_stake_min_fet bigint, p_stake_max_fet bigint, p_is_official boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.create_match_pool(p_match_id text, p_scope public.match_pool_scope, p_country_code text, p_venue_id uuid, p_title text, p_entry_fee_fet bigint, p_stake_min_fet bigint, p_stake_max_fet bigint, p_is_official boolean) TO authenticated;
GRANT ALL ON FUNCTION public.create_match_pool(p_match_id text, p_scope public.match_pool_scope, p_country_code text, p_venue_id uuid, p_title text, p_entry_fee_fet bigint, p_stake_min_fet bigint, p_stake_max_fet bigint, p_is_official boolean) TO service_role;


--
-- Name: FUNCTION create_match_pool_invite(p_pool_id uuid, p_expires_at timestamp with time zone); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.create_match_pool_invite(p_pool_id uuid, p_expires_at timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION public.create_match_pool_invite(p_pool_id uuid, p_expires_at timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.create_match_pool_invite(p_pool_id uuid, p_expires_at timestamp with time zone) TO service_role;


--
-- Name: FUNCTION create_pool(p_match_id text, p_scope text, p_country_id uuid, p_venue_id uuid, p_title text, p_stake_min bigint, p_stake_max bigint, p_creator_reward_per_qualified_member bigint, p_rules_json jsonb, p_allow_multiple boolean); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.create_pool(p_match_id text, p_scope text, p_country_id uuid, p_venue_id uuid, p_title text, p_stake_min bigint, p_stake_max bigint, p_creator_reward_per_qualified_member bigint, p_rules_json jsonb, p_allow_multiple boolean) TO authenticated;
GRANT ALL ON FUNCTION public.create_pool(p_match_id text, p_scope text, p_country_id uuid, p_venue_id uuid, p_title text, p_stake_min bigint, p_stake_max bigint, p_creator_reward_per_qualified_member bigint, p_rules_json jsonb, p_allow_multiple boolean) TO service_role;


--
-- Name: FUNCTION create_venue_official_match_pool(p_venue_id uuid, p_match_id text, p_title text, p_entry_fee_fet bigint, p_stake_min_fet bigint, p_stake_max_fet bigint, p_creator_reward_fet bigint); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.create_venue_official_match_pool(p_venue_id uuid, p_match_id text, p_title text, p_entry_fee_fet bigint, p_stake_min_fet bigint, p_stake_max_fet bigint, p_creator_reward_fet bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION public.create_venue_official_match_pool(p_venue_id uuid, p_match_id text, p_title text, p_entry_fee_fet bigint, p_stake_min_fet bigint, p_stake_max_fet bigint, p_creator_reward_fet bigint) TO authenticated;
GRANT ALL ON FUNCTION public.create_venue_official_match_pool(p_venue_id uuid, p_match_id text, p_title text, p_entry_fee_fet bigint, p_stake_min_fet bigint, p_stake_max_fet bigint, p_creator_reward_fet bigint) TO service_role;


--
-- Name: FUNCTION credit_fet_for_order(p_order_id uuid, p_idempotency_key text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.credit_fet_for_order(p_order_id uuid, p_idempotency_key text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.credit_fet_for_order(p_order_id uuid, p_idempotency_key text) TO service_role;


--
-- Name: FUNCTION credit_fet_for_order(p_user_id uuid, p_order_id uuid, p_amount bigint); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.credit_fet_for_order(p_user_id uuid, p_order_id uuid, p_amount bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION public.credit_fet_for_order(p_user_id uuid, p_order_id uuid, p_amount bigint) TO service_role;


--
-- Name: FUNCTION credit_order_fet(p_order_id uuid, p_amount bigint); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.credit_order_fet(p_order_id uuid, p_amount bigint) TO authenticated;
GRANT ALL ON FUNCTION public.credit_order_fet(p_order_id uuid, p_amount bigint) TO service_role;


--
-- Name: FUNCTION credit_welcome_fet(p_user_id uuid, p_idempotency_key text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.credit_welcome_fet(p_user_id uuid, p_idempotency_key text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.credit_welcome_fet(p_user_id uuid, p_idempotency_key text) TO authenticated;
GRANT ALL ON FUNCTION public.credit_welcome_fet(p_user_id uuid, p_idempotency_key text) TO service_role;


--
-- Name: FUNCTION current_user_has_admin_role(p_roles text[]); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.current_user_has_admin_role(p_roles text[]) FROM PUBLIC;
GRANT ALL ON FUNCTION public.current_user_has_admin_role(p_roles text[]) TO anon;
GRANT ALL ON FUNCTION public.current_user_has_admin_role(p_roles text[]) TO authenticated;
GRANT ALL ON FUNCTION public.current_user_has_admin_role(p_roles text[]) TO service_role;


--
-- Name: FUNCTION current_user_platform_roles(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.current_user_platform_roles() FROM PUBLIC;
GRANT ALL ON FUNCTION public.current_user_platform_roles() TO authenticated;
GRANT ALL ON FUNCTION public.current_user_platform_roles() TO service_role;


--
-- Name: FUNCTION ensure_user_foundation(p_user_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.ensure_user_foundation(p_user_id uuid) TO anon;
GRANT ALL ON FUNCTION public.ensure_user_foundation(p_user_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.ensure_user_foundation(p_user_id uuid) TO service_role;


--
-- Name: FUNCTION fet_supply_cap(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.fet_supply_cap() FROM PUBLIC;
GRANT ALL ON FUNCTION public.fet_supply_cap() TO anon;
GRANT ALL ON FUNCTION public.fet_supply_cap() TO authenticated;
GRANT ALL ON FUNCTION public.fet_supply_cap() TO service_role;


--
-- Name: FUNCTION find_auth_user_by_phone(p_phone text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.find_auth_user_by_phone(p_phone text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.find_auth_user_by_phone(p_phone text) TO anon;
GRANT ALL ON FUNCTION public.find_auth_user_by_phone(p_phone text) TO authenticated;
GRANT ALL ON FUNCTION public.find_auth_user_by_phone(p_phone text) TO service_role;


--
-- Name: FUNCTION generate_pool_share_card(p_pool_id uuid, p_social_card_url text, p_metadata jsonb); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.generate_pool_share_card(p_pool_id uuid, p_social_card_url text, p_metadata jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.generate_pool_share_card(p_pool_id uuid, p_social_card_url text, p_metadata jsonb) TO service_role;


--
-- Name: FUNCTION generate_profile_fan_id(p_seed text, p_attempt integer, p_profile_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.generate_profile_fan_id(p_seed text, p_attempt integer, p_profile_id uuid) TO anon;
GRANT ALL ON FUNCTION public.generate_profile_fan_id(p_seed text, p_attempt integer, p_profile_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.generate_profile_fan_id(p_seed text, p_attempt integer, p_profile_id uuid) TO service_role;


--
-- Name: FUNCTION generate_team_form_features_for_matches(p_match_ids text[], p_limit integer); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.generate_team_form_features_for_matches(p_match_ids text[], p_limit integer) TO anon;
GRANT ALL ON FUNCTION public.generate_team_form_features_for_matches(p_match_ids text[], p_limit integer) TO authenticated;
GRANT ALL ON FUNCTION public.generate_team_form_features_for_matches(p_match_ids text[], p_limit integer) TO service_role;


--
-- Name: FUNCTION get_admin_me(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_admin_me() FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_admin_me() TO anon;
GRANT ALL ON FUNCTION public.get_admin_me() TO authenticated;
GRANT ALL ON FUNCTION public.get_admin_me() TO service_role;


--
-- Name: FUNCTION get_app_bootstrap_config(p_market text, p_platform text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.get_app_bootstrap_config(p_market text, p_platform text) TO anon;
GRANT ALL ON FUNCTION public.get_app_bootstrap_config(p_market text, p_platform text) TO authenticated;
GRANT ALL ON FUNCTION public.get_app_bootstrap_config(p_market text, p_platform text) TO service_role;


--
-- Name: FUNCTION get_competition_current_season(p_competition_id text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.get_competition_current_season(p_competition_id text) TO anon;
GRANT ALL ON FUNCTION public.get_competition_current_season(p_competition_id text) TO authenticated;
GRANT ALL ON FUNCTION public.get_competition_current_season(p_competition_id text) TO service_role;


--
-- Name: FUNCTION get_country_region(p_country_code text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.get_country_region(p_country_code text) TO anon;
GRANT ALL ON FUNCTION public.get_country_region(p_country_code text) TO authenticated;
GRANT ALL ON FUNCTION public.get_country_region(p_country_code text) TO service_role;


--
-- Name: FUNCTION get_match_pool_social_card_payload(p_pool_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_match_pool_social_card_payload(p_pool_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_match_pool_social_card_payload(p_pool_id uuid) TO anon;
GRANT ALL ON FUNCTION public.get_match_pool_social_card_payload(p_pool_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_match_pool_social_card_payload(p_pool_id uuid) TO service_role;


--
-- Name: FUNCTION get_venue_fet_reward_config(p_venue_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.get_venue_fet_reward_config(p_venue_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_venue_fet_reward_config(p_venue_id uuid) TO service_role;


--
-- Name: FUNCTION get_venue_fet_reward_summary(p_venue_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_venue_fet_reward_summary(p_venue_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_venue_fet_reward_summary(p_venue_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_venue_fet_reward_summary(p_venue_id uuid) TO service_role;


--
-- Name: FUNCTION get_wallet_balance(p_user_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_wallet_balance(p_user_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_wallet_balance(p_user_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_wallet_balance(p_user_id uuid) TO service_role;


--
-- Name: FUNCTION guess_user_currency(p_user_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.guess_user_currency(p_user_id uuid) TO anon;
GRANT ALL ON FUNCTION public.guess_user_currency(p_user_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.guess_user_currency(p_user_id uuid) TO service_role;


--
-- Name: FUNCTION handle_new_auth_user(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.handle_new_auth_user() TO anon;
GRANT ALL ON FUNCTION public.handle_new_auth_user() TO authenticated;
GRANT ALL ON FUNCTION public.handle_new_auth_user() TO service_role;


--
-- Name: FUNCTION is_active_admin_operator(p_user_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.is_active_admin_operator(p_user_id uuid) TO anon;
GRANT ALL ON FUNCTION public.is_active_admin_operator(p_user_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.is_active_admin_operator(p_user_id uuid) TO service_role;


--
-- Name: FUNCTION is_active_admin_user(p_user_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.is_active_admin_user(p_user_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.is_active_admin_user(p_user_id uuid) TO anon;
GRANT ALL ON FUNCTION public.is_active_admin_user(p_user_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.is_active_admin_user(p_user_id uuid) TO service_role;


--
-- Name: FUNCTION is_admin_manager(p_user_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.is_admin_manager(p_user_id uuid) TO anon;
GRANT ALL ON FUNCTION public.is_admin_manager(p_user_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.is_admin_manager(p_user_id uuid) TO service_role;


--
-- Name: FUNCTION is_order_owner(p_order_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.is_order_owner(p_order_id uuid) TO authenticated;


--
-- Name: FUNCTION is_service_role_request(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.is_service_role_request() FROM PUBLIC;
GRANT ALL ON FUNCTION public.is_service_role_request() TO anon;
GRANT ALL ON FUNCTION public.is_service_role_request() TO authenticated;
GRANT ALL ON FUNCTION public.is_service_role_request() TO service_role;


--
-- Name: FUNCTION is_super_admin_user(p_user_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.is_super_admin_user(p_user_id uuid) TO anon;
GRANT ALL ON FUNCTION public.is_super_admin_user(p_user_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.is_super_admin_user(p_user_id uuid) TO service_role;


--
-- Name: FUNCTION issue_anonymous_upgrade_claim(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.issue_anonymous_upgrade_claim() FROM PUBLIC;
GRANT ALL ON FUNCTION public.issue_anonymous_upgrade_claim() TO anon;
GRANT ALL ON FUNCTION public.issue_anonymous_upgrade_claim() TO authenticated;
GRANT ALL ON FUNCTION public.issue_anonymous_upgrade_claim() TO service_role;


--
-- Name: FUNCTION join_match_pool(p_pool_id uuid, p_camp_id uuid, p_amount_fet bigint, p_invite_code text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.join_match_pool(p_pool_id uuid, p_camp_id uuid, p_amount_fet bigint, p_invite_code text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.join_match_pool(p_pool_id uuid, p_camp_id uuid, p_amount_fet bigint, p_invite_code text) TO authenticated;
GRANT ALL ON FUNCTION public.join_match_pool(p_pool_id uuid, p_camp_id uuid, p_amount_fet bigint, p_invite_code text) TO service_role;


--
-- Name: FUNCTION join_pool(p_pool_id uuid, p_camp_id uuid, p_stake_amount bigint, p_source text, p_invite_code text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.join_pool(p_pool_id uuid, p_camp_id uuid, p_stake_amount bigint, p_source text, p_invite_code text) TO authenticated;
GRANT ALL ON FUNCTION public.join_pool(p_pool_id uuid, p_camp_id uuid, p_stake_amount bigint, p_source text, p_invite_code text) TO service_role;


--
-- Name: FUNCTION lock_fet_supply_cap(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.lock_fet_supply_cap() FROM PUBLIC;
GRANT ALL ON FUNCTION public.lock_fet_supply_cap() TO anon;
GRANT ALL ON FUNCTION public.lock_fet_supply_cap() TO authenticated;
GRANT ALL ON FUNCTION public.lock_fet_supply_cap() TO service_role;


--
-- Name: FUNCTION lock_pool_for_match_start(p_match_id text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.lock_pool_for_match_start(p_match_id text) TO authenticated;
GRANT ALL ON FUNCTION public.lock_pool_for_match_start(p_match_id text) TO service_role;


--
-- Name: FUNCTION log_app_runtime_errors_batch(p_errors jsonb); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.log_app_runtime_errors_batch(p_errors jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.log_app_runtime_errors_batch(p_errors jsonb) TO anon;
GRANT ALL ON FUNCTION public.log_app_runtime_errors_batch(p_errors jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.log_app_runtime_errors_batch(p_errors jsonb) TO service_role;


--
-- Name: FUNCTION log_product_event(p_event_name text, p_properties jsonb, p_session_id text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.log_product_event(p_event_name text, p_properties jsonb, p_session_id text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.log_product_event(p_event_name text, p_properties jsonb, p_session_id text) TO anon;
GRANT ALL ON FUNCTION public.log_product_event(p_event_name text, p_properties jsonb, p_session_id text) TO authenticated;
GRANT ALL ON FUNCTION public.log_product_event(p_event_name text, p_properties jsonb, p_session_id text) TO service_role;


--
-- Name: FUNCTION log_product_events_batch(p_events jsonb); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.log_product_events_batch(p_events jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.log_product_events_batch(p_events jsonb) TO anon;
GRANT ALL ON FUNCTION public.log_product_events_batch(p_events jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.log_product_events_batch(p_events jsonb) TO service_role;


--
-- Name: FUNCTION manual_mark_order_paid(p_order_id uuid, p_payment_method text, p_actor_note text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.manual_mark_order_paid(p_order_id uuid, p_payment_method text, p_actor_note text) TO authenticated;
GRANT ALL ON FUNCTION public.manual_mark_order_paid(p_order_id uuid, p_payment_method text, p_actor_note text) TO service_role;


--
-- Name: FUNCTION mark_all_notifications_read(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.mark_all_notifications_read() FROM PUBLIC;
GRANT ALL ON FUNCTION public.mark_all_notifications_read() TO authenticated;
GRANT ALL ON FUNCTION public.mark_all_notifications_read() TO service_role;


--
-- Name: FUNCTION mark_notification_read(p_notification_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.mark_notification_read(p_notification_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.mark_notification_read(p_notification_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.mark_notification_read(p_notification_id uuid) TO service_role;


--
-- Name: FUNCTION merge_anonymous_to_authenticated(p_anon_id uuid, p_auth_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.merge_anonymous_to_authenticated(p_anon_id uuid, p_auth_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.merge_anonymous_to_authenticated(p_anon_id uuid, p_auth_id uuid) TO service_role;


--
-- Name: FUNCTION merge_anonymous_to_authenticated_secure(p_anon_id uuid, p_claim_token text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.merge_anonymous_to_authenticated_secure(p_anon_id uuid, p_claim_token text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.merge_anonymous_to_authenticated_secure(p_anon_id uuid, p_claim_token text) TO anon;
GRANT ALL ON FUNCTION public.merge_anonymous_to_authenticated_secure(p_anon_id uuid, p_claim_token text) TO authenticated;
GRANT ALL ON FUNCTION public.merge_anonymous_to_authenticated_secure(p_anon_id uuid, p_claim_token text) TO service_role;


--
-- Name: FUNCTION normalize_match_status(p_status text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.normalize_match_status(p_status text) TO anon;
GRANT ALL ON FUNCTION public.normalize_match_status(p_status text) TO authenticated;
GRANT ALL ON FUNCTION public.normalize_match_status(p_status text) TO service_role;


--
-- Name: FUNCTION notify_wallet_credit(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.notify_wallet_credit() FROM PUBLIC;
GRANT ALL ON FUNCTION public.notify_wallet_credit() TO service_role;


--
-- Name: FUNCTION phone_auth_email(p_phone text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.phone_auth_email(p_phone text) TO anon;
GRANT ALL ON FUNCTION public.phone_auth_email(p_phone text) TO authenticated;
GRANT ALL ON FUNCTION public.phone_auth_email(p_phone text) TO service_role;


--
-- Name: FUNCTION platform_feature_config_version(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.platform_feature_config_version() FROM PUBLIC;
GRANT ALL ON FUNCTION public.platform_feature_config_version() TO authenticated;
GRANT ALL ON FUNCTION public.platform_feature_config_version() TO service_role;
GRANT ALL ON FUNCTION public.platform_feature_config_version() TO anon;


--
-- Name: FUNCTION platform_feature_status_is_live(p_status text, p_schedule_start_at timestamp with time zone, p_schedule_end_at timestamp with time zone, p_now timestamp with time zone); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.platform_feature_status_is_live(p_status text, p_schedule_start_at timestamp with time zone, p_schedule_end_at timestamp with time zone, p_now timestamp with time zone) TO anon;
GRANT ALL ON FUNCTION public.platform_feature_status_is_live(p_status text, p_schedule_start_at timestamp with time zone, p_schedule_end_at timestamp with time zone, p_now timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.platform_feature_status_is_live(p_status text, p_schedule_start_at timestamp with time zone, p_schedule_end_at timestamp with time zone, p_now timestamp with time zone) TO service_role;


--
-- Name: FUNCTION platform_roles_allow_access(p_role_restrictions jsonb, p_user_roles jsonb); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.platform_roles_allow_access(p_role_restrictions jsonb, p_user_roles jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.platform_roles_allow_access(p_role_restrictions jsonb, p_user_roles jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.platform_roles_allow_access(p_role_restrictions jsonb, p_user_roles jsonb) TO service_role;


--
-- Name: FUNCTION reconcile_fet_wallet(p_user_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.reconcile_fet_wallet(p_user_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.reconcile_fet_wallet(p_user_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.reconcile_fet_wallet(p_user_id uuid) TO service_role;


--
-- Name: FUNCTION refresh_competition_derived_fields(p_competition_ids text[]); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.refresh_competition_derived_fields(p_competition_ids text[]) TO anon;
GRANT ALL ON FUNCTION public.refresh_competition_derived_fields(p_competition_ids text[]) TO authenticated;
GRANT ALL ON FUNCTION public.refresh_competition_derived_fields(p_competition_ids text[]) TO service_role;


--
-- Name: FUNCTION refresh_team_derived_fields(p_team_ids text[]); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.refresh_team_derived_fields(p_team_ids text[]) TO anon;
GRANT ALL ON FUNCTION public.refresh_team_derived_fields(p_team_ids text[]) TO authenticated;
GRANT ALL ON FUNCTION public.refresh_team_derived_fields(p_team_ids text[]) TO service_role;


--
-- Name: FUNCTION refresh_team_form_features_for_match(p_match_id text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.refresh_team_form_features_for_match(p_match_id text) TO anon;
GRANT ALL ON FUNCTION public.refresh_team_form_features_for_match(p_match_id text) TO authenticated;
GRANT ALL ON FUNCTION public.refresh_team_form_features_for_match(p_match_id text) TO service_role;


--
-- Name: FUNCTION repair_wallet_bootstrap_gaps(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.repair_wallet_bootstrap_gaps() FROM PUBLIC;
GRANT ALL ON FUNCTION public.repair_wallet_bootstrap_gaps() TO service_role;


--
-- Name: FUNCTION request_platform_channel(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.request_platform_channel() TO anon;
GRANT ALL ON FUNCTION public.request_platform_channel() TO authenticated;
GRANT ALL ON FUNCTION public.request_platform_channel() TO service_role;


--
-- Name: FUNCTION require_active_admin_user(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.require_active_admin_user() FROM PUBLIC;
GRANT ALL ON FUNCTION public.require_active_admin_user() TO anon;
GRANT ALL ON FUNCTION public.require_active_admin_user() TO authenticated;
GRANT ALL ON FUNCTION public.require_active_admin_user() TO service_role;


--
-- Name: FUNCTION require_admin_manager_user(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.require_admin_manager_user() TO anon;
GRANT ALL ON FUNCTION public.require_admin_manager_user() TO authenticated;
GRANT ALL ON FUNCTION public.require_admin_manager_user() TO service_role;


--
-- Name: FUNCTION require_super_admin_user(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.require_super_admin_user() FROM PUBLIC;
GRANT ALL ON FUNCTION public.require_super_admin_user() TO anon;
GRANT ALL ON FUNCTION public.require_super_admin_user() TO authenticated;
GRANT ALL ON FUNCTION public.require_super_admin_user() TO service_role;


--
-- Name: FUNCTION resolve_auth_user_phone(p_user_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.resolve_auth_user_phone(p_user_id uuid) TO anon;
GRANT ALL ON FUNCTION public.resolve_auth_user_phone(p_user_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.resolve_auth_user_phone(p_user_id uuid) TO service_role;


--
-- Name: FUNCTION resolve_platform_feature(p_feature_key text, p_channel text, p_is_authenticated boolean, p_now timestamp with time zone); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.resolve_platform_feature(p_feature_key text, p_channel text, p_is_authenticated boolean, p_now timestamp with time zone) TO anon;
GRANT ALL ON FUNCTION public.resolve_platform_feature(p_feature_key text, p_channel text, p_is_authenticated boolean, p_now timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.resolve_platform_feature(p_feature_key text, p_channel text, p_is_authenticated boolean, p_now timestamp with time zone) TO service_role;


--
-- Name: FUNCTION reverse_or_refund_pool_if_match_cancelled(p_pool_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.reverse_or_refund_pool_if_match_cancelled(p_pool_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.reverse_or_refund_pool_if_match_cancelled(p_pool_id uuid) TO service_role;


--
-- Name: FUNCTION rls_auto_enable(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.rls_auto_enable() TO anon;
GRANT ALL ON FUNCTION public.rls_auto_enable() TO authenticated;
GRANT ALL ON FUNCTION public.rls_auto_enable() TO service_role;


--
-- Name: FUNCTION safe_catalog_key(p_value text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.safe_catalog_key(p_value text) TO anon;
GRANT ALL ON FUNCTION public.safe_catalog_key(p_value text) TO authenticated;
GRANT ALL ON FUNCTION public.safe_catalog_key(p_value text) TO service_role;


--
-- Name: FUNCTION season_end_year(p_label text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.season_end_year(p_label text) TO anon;
GRANT ALL ON FUNCTION public.season_end_year(p_label text) TO authenticated;
GRANT ALL ON FUNCTION public.season_end_year(p_label text) TO service_role;


--
-- Name: FUNCTION season_sort_key(p_season text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.season_sort_key(p_season text) TO anon;
GRANT ALL ON FUNCTION public.season_sort_key(p_season text) TO authenticated;
GRANT ALL ON FUNCTION public.season_sort_key(p_season text) TO service_role;


--
-- Name: FUNCTION season_start_year(p_label text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.season_start_year(p_label text) TO anon;
GRANT ALL ON FUNCTION public.season_start_year(p_label text) TO authenticated;
GRANT ALL ON FUNCTION public.season_start_year(p_label text) TO service_role;


--
-- Name: FUNCTION send_push_to_user(p_user_id uuid, p_type text, p_title text, p_body text, p_data jsonb); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.send_push_to_user(p_user_id uuid, p_type text, p_title text, p_body text, p_data jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.send_push_to_user(p_user_id uuid, p_type text, p_title text, p_body text, p_data jsonb) TO service_role;


--
-- Name: FUNCTION set_match_pool_social_card_url(p_pool_id uuid, p_social_card_url text, p_metadata jsonb); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.set_match_pool_social_card_url(p_pool_id uuid, p_social_card_url text, p_metadata jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.set_match_pool_social_card_url(p_pool_id uuid, p_social_card_url text, p_metadata jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.set_match_pool_social_card_url(p_pool_id uuid, p_social_card_url text, p_metadata jsonb) TO service_role;


--
-- Name: FUNCTION set_row_updated_at(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.set_row_updated_at() TO anon;
GRANT ALL ON FUNCTION public.set_row_updated_at() TO authenticated;
GRANT ALL ON FUNCTION public.set_row_updated_at() TO service_role;


--
-- Name: FUNCTION set_updated_at(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.set_updated_at() TO anon;
GRANT ALL ON FUNCTION public.set_updated_at() TO authenticated;
GRANT ALL ON FUNCTION public.set_updated_at() TO service_role;


--
-- Name: FUNCTION settle_finished_match_pools(p_limit integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.settle_finished_match_pools(p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.settle_finished_match_pools(p_limit integer) TO service_role;


--
-- Name: FUNCTION settle_match_pool(p_pool_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.settle_match_pool(p_pool_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.settle_match_pool(p_pool_id uuid) TO service_role;


--
-- Name: FUNCTION settle_pool(p_pool_id uuid, p_idempotency_key text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.settle_pool(p_pool_id uuid, p_idempotency_key text) TO authenticated;
GRANT ALL ON FUNCTION public.settle_pool(p_pool_id uuid, p_idempotency_key text) TO service_role;


--
-- Name: FUNCTION spend_fet_on_order(p_order_id uuid, p_amount bigint); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.spend_fet_on_order(p_order_id uuid, p_amount bigint) TO authenticated;
GRANT ALL ON FUNCTION public.spend_fet_on_order(p_order_id uuid, p_amount bigint) TO service_role;


--
-- Name: FUNCTION spend_fet_on_order(p_order_id uuid, p_amount_fet bigint, p_idempotency_key text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.spend_fet_on_order(p_order_id uuid, p_amount_fet bigint, p_idempotency_key text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.spend_fet_on_order(p_order_id uuid, p_amount_fet bigint, p_idempotency_key text) TO authenticated;
GRANT ALL ON FUNCTION public.spend_fet_on_order(p_order_id uuid, p_amount_fet bigint, p_idempotency_key text) TO service_role;


--
-- Name: FUNCTION stake_fet(p_pool_id uuid, p_camp_id uuid, p_stake_amount bigint, p_source text, p_invite_code text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.stake_fet(p_pool_id uuid, p_camp_id uuid, p_stake_amount bigint, p_source text, p_invite_code text) TO authenticated;
GRANT ALL ON FUNCTION public.stake_fet(p_pool_id uuid, p_camp_id uuid, p_stake_amount bigint, p_source text, p_invite_code text) TO service_role;


--
-- Name: FUNCTION sync_public_feature_flags_from_admin(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.sync_public_feature_flags_from_admin() TO anon;
GRANT ALL ON FUNCTION public.sync_public_feature_flags_from_admin() TO authenticated;
GRANT ALL ON FUNCTION public.sync_public_feature_flags_from_admin() TO service_role;


--
-- Name: FUNCTION sync_runtime_feature_flags_from_platform(p_feature_key text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.sync_runtime_feature_flags_from_platform(p_feature_key text) TO service_role;


--
-- Name: FUNCTION transfer_fet(p_recipient_identifier text, p_amount_fet bigint); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.transfer_fet(p_recipient_identifier text, p_amount_fet bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION public.transfer_fet(p_recipient_identifier text, p_amount_fet bigint) TO anon;
GRANT ALL ON FUNCTION public.transfer_fet(p_recipient_identifier text, p_amount_fet bigint) TO authenticated;
GRANT ALL ON FUNCTION public.transfer_fet(p_recipient_identifier text, p_amount_fet bigint) TO service_role;


--
-- Name: FUNCTION transfer_fet_by_fan_id(p_recipient_fan_id text, p_amount_fet bigint); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.transfer_fet_by_fan_id(p_recipient_fan_id text, p_amount_fet bigint) TO anon;
GRANT ALL ON FUNCTION public.transfer_fet_by_fan_id(p_recipient_fan_id text, p_amount_fet bigint) TO authenticated;
GRANT ALL ON FUNCTION public.transfer_fet_by_fan_id(p_recipient_fan_id text, p_amount_fet bigint) TO service_role;


--
-- Name: FUNCTION update_match_live_score(p_match_id text, p_home_score integer, p_away_score integer, p_status text, p_source text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.update_match_live_score(p_match_id text, p_home_score integer, p_away_score integer, p_status text, p_source text) TO authenticated;
GRANT ALL ON FUNCTION public.update_match_live_score(p_match_id text, p_home_score integer, p_away_score integer, p_status text, p_source text) TO service_role;


--
-- Name: FUNCTION update_venue_fet_reward_config(p_venue_id uuid, p_reward_percent numeric, p_reward_trigger text, p_accepts_fet_spend boolean, p_redemption_fet_per_currency numeric); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.update_venue_fet_reward_config(p_venue_id uuid, p_reward_percent numeric, p_reward_trigger text, p_accepts_fet_spend boolean, p_redemption_fet_per_currency numeric) FROM PUBLIC;
GRANT ALL ON FUNCTION public.update_venue_fet_reward_config(p_venue_id uuid, p_reward_percent numeric, p_reward_trigger text, p_accepts_fet_spend boolean, p_redemption_fet_per_currency numeric) TO authenticated;
GRANT ALL ON FUNCTION public.update_venue_fet_reward_config(p_venue_id uuid, p_reward_percent numeric, p_reward_trigger text, p_accepts_fet_spend boolean, p_redemption_fet_per_currency numeric) TO service_role;


--
-- Name: FUNCTION upsert_team_form_feature(p_match_id text, p_team_id text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.upsert_team_form_feature(p_match_id text, p_team_id text) TO anon;
GRANT ALL ON FUNCTION public.upsert_team_form_feature(p_match_id text, p_team_id text) TO authenticated;
GRANT ALL ON FUNCTION public.upsert_team_form_feature(p_match_id text, p_team_id text) TO service_role;


--
-- Name: FUNCTION upsert_vault_secret(p_name text, p_secret text, p_description text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.upsert_vault_secret(p_name text, p_secret text, p_description text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.upsert_vault_secret(p_name text, p_secret text, p_description text) TO service_role;


--
-- Name: FUNCTION venue_endorse_pool(p_pool_id uuid, p_venue_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.venue_endorse_pool(p_pool_id uuid, p_venue_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.venue_endorse_pool(p_pool_id uuid, p_venue_id uuid) TO service_role;


--
-- Name: FUNCTION venue_pool_match_options(p_venue_id uuid, p_limit integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.venue_pool_match_options(p_venue_id uuid, p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.venue_pool_match_options(p_venue_id uuid, p_limit integer) TO authenticated;
GRANT ALL ON FUNCTION public.venue_pool_match_options(p_venue_id uuid, p_limit integer) TO service_role;


--
-- Name: FUNCTION venue_reject_client_order_updates(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.venue_reject_client_order_updates() FROM PUBLIC;
GRANT ALL ON FUNCTION public.venue_reject_client_order_updates() TO service_role;


--
-- Name: FUNCTION wallet_post_transaction(p_user_id uuid, p_transaction_type text, p_direction text, p_amount_fet bigint, p_balance_bucket text, p_idempotency_key text, p_reference_type text, p_reference_id text, p_title text, p_metadata jsonb, p_order_id uuid, p_match_id text, p_pool_id uuid, p_entry_id uuid, p_settlement_id uuid, p_venue_id uuid, p_status text, p_created_by uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.wallet_post_transaction(p_user_id uuid, p_transaction_type text, p_direction text, p_amount_fet bigint, p_balance_bucket text, p_idempotency_key text, p_reference_type text, p_reference_id text, p_title text, p_metadata jsonb, p_order_id uuid, p_match_id text, p_pool_id uuid, p_entry_id uuid, p_settlement_id uuid, p_venue_id uuid, p_status text, p_created_by uuid) FROM PUBLIC;


--
-- Name: FUNCTION write_match_pool_operation_audit(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.write_match_pool_operation_audit() FROM PUBLIC;


--
-- Name: TABLE account_deletion_requests; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.account_deletion_requests TO anon;
GRANT ALL ON TABLE public.account_deletion_requests TO authenticated;
GRANT ALL ON TABLE public.account_deletion_requests TO service_role;


--
-- Name: TABLE admin_audit_logs; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.admin_audit_logs TO anon;
GRANT ALL ON TABLE public.admin_audit_logs TO authenticated;
GRANT ALL ON TABLE public.admin_audit_logs TO service_role;


--
-- Name: TABLE admin_audit_logs_enriched; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.admin_audit_logs_enriched TO anon;
GRANT ALL ON TABLE public.admin_audit_logs_enriched TO authenticated;
GRANT ALL ON TABLE public.admin_audit_logs_enriched TO service_role;


--
-- Name: SEQUENCE admin_audit_logs_id_seq; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON SEQUENCE public.admin_audit_logs_id_seq TO anon;
GRANT ALL ON SEQUENCE public.admin_audit_logs_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.admin_audit_logs_id_seq TO service_role;


--
-- Name: TABLE feature_flags; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.feature_flags TO service_role;
GRANT SELECT ON TABLE public.feature_flags TO anon;
GRANT SELECT ON TABLE public.feature_flags TO authenticated;


--
-- Name: TABLE platform_features; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.platform_features TO service_role;


--
-- Name: TABLE admin_feature_flags; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.admin_feature_flags TO service_role;
GRANT SELECT ON TABLE public.admin_feature_flags TO authenticated;


--
-- Name: TABLE platform_content_blocks; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.platform_content_blocks TO service_role;


--
-- Name: TABLE admin_platform_content_blocks; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.admin_platform_content_blocks TO authenticated;
GRANT SELECT ON TABLE public.admin_platform_content_blocks TO service_role;


--
-- Name: TABLE platform_feature_channels; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.platform_feature_channels TO service_role;


--
-- Name: TABLE platform_feature_rules; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.platform_feature_rules TO service_role;


--
-- Name: TABLE admin_platform_features; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.admin_platform_features TO authenticated;
GRANT SELECT ON TABLE public.admin_platform_features TO service_role;


--
-- Name: TABLE anonymous_upgrade_claims; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.anonymous_upgrade_claims TO anon;
GRANT ALL ON TABLE public.anonymous_upgrade_claims TO authenticated;
GRANT ALL ON TABLE public.anonymous_upgrade_claims TO service_role;


--
-- Name: TABLE competitions; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.competitions TO anon;
GRANT ALL ON TABLE public.competitions TO authenticated;
GRANT ALL ON TABLE public.competitions TO service_role;


--
-- Name: TABLE matches; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.matches TO anon;
GRANT ALL ON TABLE public.matches TO authenticated;
GRANT ALL ON TABLE public.matches TO service_role;


--
-- Name: TABLE app_competitions; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.app_competitions TO anon;
GRANT ALL ON TABLE public.app_competitions TO authenticated;
GRANT ALL ON TABLE public.app_competitions TO service_role;


--
-- Name: TABLE app_competitions_ranked; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.app_competitions_ranked TO anon;
GRANT ALL ON TABLE public.app_competitions_ranked TO authenticated;
GRANT ALL ON TABLE public.app_competitions_ranked TO service_role;


--
-- Name: TABLE app_config_remote; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.app_config_remote TO anon;
GRANT ALL ON TABLE public.app_config_remote TO authenticated;
GRANT ALL ON TABLE public.app_config_remote TO service_role;


--
-- Name: TABLE app_matches; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.app_matches TO anon;
GRANT ALL ON TABLE public.app_matches TO authenticated;
GRANT ALL ON TABLE public.app_matches TO service_role;


--
-- Name: TABLE app_runtime_errors; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.app_runtime_errors TO anon;
GRANT ALL ON TABLE public.app_runtime_errors TO authenticated;
GRANT ALL ON TABLE public.app_runtime_errors TO service_role;


--
-- Name: TABLE bell_requests; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT ON TABLE public.bell_requests TO authenticated;


--
-- Name: TABLE country_currency_map; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.country_currency_map TO anon;
GRANT ALL ON TABLE public.country_currency_map TO authenticated;
GRANT ALL ON TABLE public.country_currency_map TO service_role;


--
-- Name: TABLE country_region_map; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.country_region_map TO anon;
GRANT ALL ON TABLE public.country_region_map TO authenticated;
GRANT ALL ON TABLE public.country_region_map TO service_role;


--
-- Name: TABLE cron_job_log; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.cron_job_log TO anon;
GRANT ALL ON TABLE public.cron_job_log TO authenticated;
GRANT ALL ON TABLE public.cron_job_log TO service_role;


--
-- Name: TABLE curated_matches; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.curated_matches TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.curated_matches TO authenticated;
GRANT ALL ON TABLE public.curated_matches TO service_role;


--
-- Name: TABLE currency_display_metadata; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.currency_display_metadata TO anon;
GRANT ALL ON TABLE public.currency_display_metadata TO authenticated;
GRANT ALL ON TABLE public.currency_display_metadata TO service_role;


--
-- Name: TABLE currency_rates; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.currency_rates TO anon;
GRANT ALL ON TABLE public.currency_rates TO authenticated;
GRANT ALL ON TABLE public.currency_rates TO service_role;


--
-- Name: TABLE device_tokens; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.device_tokens TO anon;
GRANT ALL ON TABLE public.device_tokens TO authenticated;
GRANT ALL ON TABLE public.device_tokens TO service_role;


--
-- Name: SEQUENCE fan_id_seq; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON SEQUENCE public.fan_id_seq TO anon;
GRANT ALL ON SEQUENCE public.fan_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.fan_id_seq TO service_role;


--
-- Name: TABLE featured_events; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.featured_events TO anon;
GRANT ALL ON TABLE public.featured_events TO authenticated;
GRANT ALL ON TABLE public.featured_events TO service_role;


--
-- Name: TABLE fet_wallet_transactions; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.fet_wallet_transactions TO anon;
GRANT ALL ON TABLE public.fet_wallet_transactions TO authenticated;
GRANT ALL ON TABLE public.fet_wallet_transactions TO service_role;


--
-- Name: TABLE fet_ledger; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.fet_ledger TO authenticated;


--
-- Name: TABLE fet_wallets; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.fet_wallets TO anon;
GRANT ALL ON TABLE public.fet_wallets TO authenticated;
GRANT ALL ON TABLE public.fet_wallets TO service_role;


--
-- Name: TABLE fet_supply_overview; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.fet_supply_overview TO anon;
GRANT ALL ON TABLE public.fet_supply_overview TO authenticated;
GRANT ALL ON TABLE public.fet_supply_overview TO service_role;


--
-- Name: TABLE fet_supply_overview_admin; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.fet_supply_overview_admin TO anon;
GRANT ALL ON TABLE public.fet_supply_overview_admin TO authenticated;
GRANT ALL ON TABLE public.fet_supply_overview_admin TO service_role;


--
-- Name: TABLE fet_transactions_admin; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.fet_transactions_admin TO anon;
GRANT ALL ON TABLE public.fet_transactions_admin TO authenticated;
GRANT ALL ON TABLE public.fet_transactions_admin TO service_role;


--
-- Name: TABLE launch_moments; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.launch_moments TO anon;
GRANT ALL ON TABLE public.launch_moments TO authenticated;
GRANT ALL ON TABLE public.launch_moments TO service_role;


--
-- Name: TABLE match_alert_dispatch_log; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.match_alert_dispatch_log TO anon;
GRANT ALL ON TABLE public.match_alert_dispatch_log TO authenticated;
GRANT ALL ON TABLE public.match_alert_dispatch_log TO service_role;


--
-- Name: TABLE match_alert_subscriptions; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.match_alert_subscriptions TO anon;
GRANT ALL ON TABLE public.match_alert_subscriptions TO authenticated;
GRANT ALL ON TABLE public.match_alert_subscriptions TO service_role;


--
-- Name: TABLE match_pool_camps; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.match_pool_camps TO anon;
GRANT SELECT ON TABLE public.match_pool_camps TO authenticated;
GRANT ALL ON TABLE public.match_pool_camps TO service_role;


--
-- Name: TABLE match_pool_entries; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.match_pool_entries TO authenticated;
GRANT ALL ON TABLE public.match_pool_entries TO service_role;


--
-- Name: TABLE match_pool_invites; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.match_pool_invites TO authenticated;
GRANT ALL ON TABLE public.match_pool_invites TO service_role;


--
-- Name: TABLE match_pool_settlements; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.match_pool_settlements TO authenticated;
GRANT ALL ON TABLE public.match_pool_settlements TO service_role;


--
-- Name: TABLE match_pool_stats; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.match_pool_stats TO anon;
GRANT SELECT ON TABLE public.match_pool_stats TO authenticated;


--
-- Name: TABLE match_pools; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.match_pools TO anon;
GRANT SELECT ON TABLE public.match_pools TO authenticated;
GRANT ALL ON TABLE public.match_pools TO service_role;


--
-- Name: TABLE menu_categories; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.menu_categories TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.menu_categories TO authenticated;


--
-- Name: TABLE menu_items; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.menu_items TO anon;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.menu_items TO authenticated;


--
-- Name: TABLE moderation_reports; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.moderation_reports TO anon;
GRANT ALL ON TABLE public.moderation_reports TO authenticated;
GRANT ALL ON TABLE public.moderation_reports TO service_role;


--
-- Name: TABLE notification_log; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.notification_log TO anon;
GRANT ALL ON TABLE public.notification_log TO authenticated;
GRANT ALL ON TABLE public.notification_log TO service_role;


--
-- Name: TABLE notification_preferences; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.notification_preferences TO anon;
GRANT ALL ON TABLE public.notification_preferences TO authenticated;
GRANT ALL ON TABLE public.notification_preferences TO service_role;


--
-- Name: TABLE onboarding_requests; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.onboarding_requests TO authenticated;


--
-- Name: TABLE order_items; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT ON TABLE public.order_items TO authenticated;


--
-- Name: TABLE orders; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT ON TABLE public.orders TO authenticated;


--
-- Name: TABLE otp_verifications; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.otp_verifications TO service_role;


--
-- Name: TABLE payment_events; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.payment_events TO authenticated;


--
-- Name: TABLE pending_menu_imports; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.pending_menu_imports TO authenticated;


--
-- Name: TABLE phone_presets; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.phone_presets TO anon;
GRANT ALL ON TABLE public.phone_presets TO authenticated;
GRANT ALL ON TABLE public.phone_presets TO service_role;


--
-- Name: TABLE platform_feature_audit_logs; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.platform_feature_audit_logs TO authenticated;
GRANT SELECT ON TABLE public.platform_feature_audit_logs TO service_role;


--
-- Name: TABLE pool_camps; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.pool_camps TO anon;
GRANT SELECT ON TABLE public.pool_camps TO authenticated;


--
-- Name: TABLE pool_entries; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.pool_entries TO authenticated;


--
-- Name: TABLE pool_operation_audit_logs; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.pool_operation_audit_logs TO authenticated;
GRANT ALL ON TABLE public.pool_operation_audit_logs TO service_role;


--
-- Name: TABLE pools; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.pools TO anon;
GRANT SELECT ON TABLE public.pools TO authenticated;


--
-- Name: TABLE product_events; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.product_events TO anon;
GRANT ALL ON TABLE public.product_events TO authenticated;
GRANT ALL ON TABLE public.product_events TO service_role;


--
-- Name: TABLE rate_limits; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.rate_limits TO service_role;


--
-- Name: SEQUENCE rate_limits_id_seq; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON SEQUENCE public.rate_limits_id_seq TO anon;
GRANT ALL ON SEQUENCE public.rate_limits_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.rate_limits_id_seq TO service_role;


--
-- Name: TABLE settlement_runs; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.settlement_runs TO authenticated;


--
-- Name: TABLE tables; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.tables TO anon;
GRANT SELECT ON TABLE public.tables TO authenticated;


--
-- Name: TABLE team_aliases; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.team_aliases TO anon;
GRANT ALL ON TABLE public.team_aliases TO authenticated;
GRANT ALL ON TABLE public.team_aliases TO service_role;


--
-- Name: TABLE team_form_features; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.team_form_features TO anon;
GRANT ALL ON TABLE public.team_form_features TO authenticated;
GRANT ALL ON TABLE public.team_form_features TO service_role;


--
-- Name: TABLE user_favorite_teams; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.user_favorite_teams TO anon;
GRANT ALL ON TABLE public.user_favorite_teams TO authenticated;
GRANT ALL ON TABLE public.user_favorite_teams TO service_role;


--
-- Name: TABLE user_followed_competitions; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.user_followed_competitions TO anon;
GRANT ALL ON TABLE public.user_followed_competitions TO authenticated;
GRANT ALL ON TABLE public.user_followed_competitions TO service_role;


--
-- Name: TABLE user_market_preferences; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.user_market_preferences TO anon;
GRANT ALL ON TABLE public.user_market_preferences TO authenticated;
GRANT ALL ON TABLE public.user_market_preferences TO service_role;


--
-- Name: TABLE user_status; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.user_status TO anon;
GRANT ALL ON TABLE public.user_status TO authenticated;
GRANT ALL ON TABLE public.user_status TO service_role;


--
-- Name: TABLE user_profiles_admin; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.user_profiles_admin TO anon;
GRANT ALL ON TABLE public.user_profiles_admin TO authenticated;
GRANT ALL ON TABLE public.user_profiles_admin TO service_role;


--
-- Name: TABLE venue_tables; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.venue_tables TO anon;
GRANT SELECT ON TABLE public.venue_tables TO authenticated;


--
-- Name: TABLE venue_users; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.venue_users TO authenticated;


--
-- Name: TABLE venues; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.venues TO anon;
GRANT SELECT ON TABLE public.venues TO authenticated;


--
-- Name: TABLE wallet_overview; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.wallet_overview TO anon;
GRANT ALL ON TABLE public.wallet_overview TO authenticated;
GRANT ALL ON TABLE public.wallet_overview TO service_role;


--
-- Name: TABLE wallet_overview_admin; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.wallet_overview_admin TO anon;
GRANT ALL ON TABLE public.wallet_overview_admin TO authenticated;
GRANT ALL ON TABLE public.wallet_overview_admin TO service_role;


--
-- Name: TABLE whatsapp_auth_sessions; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.whatsapp_auth_sessions TO anon;
GRANT ALL ON TABLE public.whatsapp_auth_sessions TO authenticated;
GRANT ALL ON TABLE public.whatsapp_auth_sessions TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES  TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS  TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO service_role;


--
-- PostgreSQL database dump complete
--
