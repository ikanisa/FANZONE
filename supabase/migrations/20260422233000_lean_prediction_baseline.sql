--
-- PostgreSQL database dump
--

\restrict c5an2gv7aSc5fH5cvXvhoi9GzvLhM0RZbrEgbbFeHx3YR3p0SFpm2a9GIEfsBhZ

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.9 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
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

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


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
-- Name: admin_approve_partner(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_approve_partner(p_partner_id uuid) RETURNS jsonb
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

  SELECT to_jsonb(partner)
  INTO v_before
  FROM public.partners partner
  WHERE partner.id = p_partner_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;

  UPDATE public.partners
  SET status = 'approved',
      approved_by = v_admin_record_id,
      updated_at = timezone('utc', now())
  WHERE id = p_partner_id;

  SELECT to_jsonb(partner)
  INTO v_after
  FROM public.partners partner
  WHERE partner.id = p_partner_id;

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
    'approve_partner',
    'partners',
    'partner',
    p_partner_id::text,
    v_before,
    v_after,
    jsonb_build_object('status', 'approved')
  );

  RETURN jsonb_build_object('id', p_partner_id, 'status', 'approved');
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


--
-- Name: admin_create_campaign(text, text, text, jsonb, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_create_campaign(p_title text, p_message text, p_type text, p_segment jsonb DEFAULT '{}'::jsonb, p_scheduled_at timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
DECLARE
  v_admin_record_id uuid;
  v_campaign public.campaigns%ROWTYPE;
BEGIN
  PERFORM public.require_admin_manager_user();
  v_admin_record_id := public.active_admin_record_id();

  INSERT INTO public.campaigns (
    title,
    message,
    type,
    segment,
    status,
    scheduled_at,
    country,
    created_by,
    updated_at
  ) VALUES (
    p_title,
    p_message,
    p_type,
    COALESCE(p_segment, '{}'::jsonb),
    CASE WHEN p_scheduled_at IS NULL THEN 'draft' ELSE 'scheduled' END,
    p_scheduled_at,
    'MT',
    v_admin_record_id,
    timezone('utc', now())
  )
  RETURNING * INTO v_campaign;

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
    'create_campaign',
    'notifications',
    'campaign',
    v_campaign.id::text,
    NULL,
    to_jsonb(v_campaign),
    jsonb_build_object('scheduled', p_scheduled_at IS NOT NULL)
  );

  RETURN jsonb_build_object(
    'id', v_campaign.id,
    'status', v_campaign.status
  );
END;
$$;


--
-- Name: admin_credit_fet(uuid, bigint, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_credit_fet(p_target_user_id uuid, p_amount bigint, p_reason text DEFAULT 'Admin credit'::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: admin_dashboard_kpis(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_dashboard_kpis() RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
DECLARE
  v_active_users bigint := 0;
  v_open_prediction_matches bigint := 0;
  v_total_fet_issued numeric := 0;
  v_fet_transferred_24h bigint := 0;
  v_pending_redemptions bigint := 0;
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

  IF to_regclass('public.redemptions') IS NOT NULL THEN
    SELECT coalesce(count(*)::bigint, 0)
    INTO v_pending_redemptions
    FROM public.redemptions
    WHERE status = 'pending';
  END IF;

  IF to_regclass('public.marketplace_redemptions') IS NOT NULL THEN
    v_pending_redemptions := v_pending_redemptions + coalesce((
      SELECT count(*)::bigint
      FROM public.marketplace_redemptions
      WHERE status IN ('pending', 'approved')
    ), 0);
  END IF;

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
    'pendingRedemptions', coalesce(v_pending_redemptions, 0),
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


--
-- Name: admin_delete_banner(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_delete_banner(p_banner_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
DECLARE
  v_admin_record_id uuid;
  v_before jsonb;
BEGIN
  PERFORM public.require_admin_manager_user();
  v_admin_record_id := public.active_admin_record_id();

  SELECT to_jsonb(banner)
  INTO v_before
  FROM public.content_banners banner
  WHERE banner.id = p_banner_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Banner not found';
  END IF;

  DELETE FROM public.content_banners
  WHERE id = p_banner_id;

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
    'delete_banner',
    'content',
    'banner',
    p_banner_id::text,
    v_before,
    NULL,
    '{}'::jsonb
  );

  RETURN jsonb_build_object('id', p_banner_id, 'deleted', true);
END;
$$;


--
-- Name: admin_delete_campaign(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_delete_campaign(p_campaign_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
DECLARE
  v_admin_record_id uuid;
  v_before jsonb;
BEGIN
  PERFORM public.require_admin_manager_user();
  v_admin_record_id := public.active_admin_record_id();

  SELECT to_jsonb(campaign)
  INTO v_before
  FROM public.campaigns campaign
  WHERE campaign.id = p_campaign_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Campaign not found';
  END IF;

  DELETE FROM public.campaigns
  WHERE id = p_campaign_id;

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
    'delete_campaign',
    'notifications',
    'campaign',
    p_campaign_id::text,
    v_before,
    NULL,
    '{}'::jsonb
  );

  RETURN jsonb_build_object('id', p_campaign_id, 'deleted', true);
END;
$$;


--
-- Name: admin_engagement_daily(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_engagement_daily(p_days integer DEFAULT 7) RETURNS TABLE(day text, dau bigint, predictions bigint)
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


--
-- Name: admin_engagement_kpis(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_engagement_kpis() RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
  WITH _auth AS (
    SELECT public.require_active_admin_user()
  ),
  activity AS (
    SELECT u.id AS user_id, timezone('utc', u.last_sign_in_at) AS activity_at
    FROM auth.users u
    WHERE u.last_sign_in_at IS NOT NULL

    UNION ALL

    SELECT user_id, timezone('utc', created_at)
    FROM public.user_predictions

    UNION ALL

    SELECT user_id, timezone('utc', awarded_at)
    FROM public.token_rewards
    WHERE status = 'awarded'

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
      SELECT count(*)::bigint
      FROM public.user_predictions
      WHERE created_at >= timezone('utc', now()) - interval '7 days'
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
          'contribution',
          'team_contribution',
          'redemption'
        )
    ), 0)
  );
$$;


--
-- Name: admin_fet_flow_weekly(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_fet_flow_weekly(p_weeks integer DEFAULT 4) RETURNS TABLE(week text, issued bigint, transferred bigint, redeemed bigint, rewarded bigint)
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
      amount_fet,
      reference_type
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
         AND (tx.tx_type = 'redemption' OR tx.reference_type = 'marketplace_redemption')
          THEN tx.amount_fet
        ELSE 0
      END
    ), 0)::bigint AS redeemed,
    coalesce(max(r.rewarded_total), 0)::bigint AS rewarded
  FROM weeks w
  LEFT JOIN tx
    ON tx.bucket_week = w.bucket_week
  LEFT JOIN rewards r
    ON r.bucket_week = w.bucket_week
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
  SELECT *
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
  ORDER BY group_rank, title
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
    )
  INTO v_target_user_id, v_target_display_name
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
      phone = v_normalized_phone,
      display_name = coalesce(nullif(trim(display_name), ''), v_target_display_name),
      role = v_role,
      is_active = true,
      invited_by = coalesce(invited_by, v_actor_admin_id),
      updated_at = timezone('utc', now())
    WHERE id = v_existing.id
    RETURNING *
    INTO v_result;
  ELSE
    INSERT INTO public.admin_users (
      user_id,
      phone,
      display_name,
      role,
      is_active,
      invited_by
    )
    VALUES (
      v_target_user_id,
      v_normalized_phone,
      v_target_display_name,
      v_role,
      true,
      v_actor_admin_id
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

CREATE FUNCTION public.admin_log_action(p_action text, p_module text, p_target_type text DEFAULT NULL::text, p_target_id text DEFAULT NULL::text, p_before_state jsonb DEFAULT NULL::jsonb, p_after_state jsonb DEFAULT NULL::jsonb, p_metadata jsonb DEFAULT '{}'::jsonb) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_actor_user_id uuid := public.require_active_admin_user();
  v_actor_admin_id uuid;
  v_audit_id uuid;
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
-- Name: admin_reject_partner(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_reject_partner(p_partner_id uuid, p_reason text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
DECLARE
  v_admin_record_id uuid;
  v_before jsonb;
  v_after jsonb;
  v_reason text := nullif(trim(p_reason), '');
BEGIN
  PERFORM public.require_admin_manager_user();
  v_admin_record_id := public.active_admin_record_id();

  IF v_reason IS NULL THEN
    RAISE EXCEPTION 'Rejection reason is required';
  END IF;

  SELECT to_jsonb(partner)
  INTO v_before
  FROM public.partners partner
  WHERE partner.id = p_partner_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;

  UPDATE public.partners
  SET status = 'rejected',
      approved_by = NULL,
      metadata = coalesce(metadata, '{}'::jsonb) ||
        jsonb_build_object('rejection_reason', v_reason),
      updated_at = timezone('utc', now())
  WHERE id = p_partner_id;

  SELECT to_jsonb(partner)
  INTO v_after
  FROM public.partners partner
  WHERE partner.id = p_partner_id;

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
    'reject_partner',
    'partners',
    'partner',
    p_partner_id::text,
    v_before,
    v_after,
    jsonb_build_object('reason', v_reason)
  );

  RETURN jsonb_build_object(
    'id', p_partner_id,
    'status', 'rejected',
    'reason', v_reason
  );
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
-- Name: admin_send_campaign(uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_send_campaign(p_campaign_id uuid, p_force boolean DEFAULT false) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
      BEGIN
        PERFORM public.require_active_admin_user();
        RAISE EXCEPTION 'Campaign infrastructure is not available in this deployment';
      END;
      $$;


--
-- Name: admin_set_banner_active(uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_set_banner_active(p_banner_id uuid, p_is_active boolean) RETURNS jsonb
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

  SELECT to_jsonb(banner)
  INTO v_before
  FROM public.content_banners banner
  WHERE banner.id = p_banner_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Banner not found';
  END IF;

  UPDATE public.content_banners
  SET is_active = p_is_active,
      updated_at = timezone('utc', now())
  WHERE id = p_banner_id;

  SELECT to_jsonb(banner)
  INTO v_after
  FROM public.content_banners banner
  WHERE banner.id = p_banner_id;

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
    'toggle_banner_active',
    'content',
    'banner',
    p_banner_id::text,
    v_before,
    v_after,
    jsonb_build_object('is_active', p_is_active)
  );

  RETURN jsonb_build_object(
    'id', p_banner_id,
    'is_active', p_is_active
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
-- Name: admin_set_feature_flag(uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_set_feature_flag(p_flag_id uuid, p_is_enabled boolean) RETURNS jsonb
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

  SELECT to_jsonb(flag)
  INTO v_before
  FROM public.admin_feature_flags flag
  WHERE flag.id = p_flag_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Feature flag not found';
  END IF;

  UPDATE public.admin_feature_flags
  SET is_enabled = p_is_enabled,
      updated_by = v_admin_record_id,
      updated_at = timezone('utc', now())
  WHERE id = p_flag_id;

  SELECT to_jsonb(flag)
  INTO v_after
  FROM public.admin_feature_flags flag
  WHERE flag.id = p_flag_id;

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
    p_flag_id::text,
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
-- Name: admin_set_partner_featured(uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_set_partner_featured(p_partner_id uuid, p_is_featured boolean) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
DECLARE
  v_admin_record_id uuid;
  v_before jsonb;
  v_after jsonb;
  v_current_status text;
BEGIN
  PERFORM public.require_admin_manager_user();
  v_admin_record_id := public.active_admin_record_id();

  SELECT status, to_jsonb(partner)
  INTO v_current_status, v_before
  FROM public.partners partner
  WHERE partner.id = p_partner_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;

  IF p_is_featured AND v_current_status <> 'approved' THEN
    RAISE EXCEPTION 'Only approved partners can be featured';
  END IF;

  UPDATE public.partners
  SET is_featured = p_is_featured,
      updated_at = timezone('utc', now())
  WHERE id = p_partner_id;

  SELECT to_jsonb(partner)
  INTO v_after
  FROM public.partners partner
  WHERE partner.id = p_partner_id;

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
    'toggle_partner_featured',
    'partners',
    'partner',
    p_partner_id::text,
    v_before,
    v_after,
    jsonb_build_object('is_featured', p_is_featured)
  );

  RETURN jsonb_build_object(
    'id', p_partner_id,
    'is_featured', p_is_featured
  );
END;
$$;


--
-- Name: admin_set_reward_active(uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_set_reward_active(p_reward_id uuid, p_is_active boolean) RETURNS jsonb
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

  SELECT to_jsonb(reward)
  INTO v_before
  FROM public.rewards reward
  WHERE reward.id = p_reward_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Reward not found';
  END IF;

  UPDATE public.rewards
  SET is_active = p_is_active,
      updated_at = timezone('utc', now())
  WHERE id = p_reward_id;

  SELECT to_jsonb(reward)
  INTO v_after
  FROM public.rewards reward
  WHERE reward.id = p_reward_id;

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
    'toggle_reward_active',
    'rewards',
    'reward',
    p_reward_id::text,
    v_before,
    v_after,
    jsonb_build_object('is_active', p_is_active)
  );

  RETURN jsonb_build_object(
    'id', p_reward_id,
    'is_active', p_is_active
  );
END;
$$;


--
-- Name: admin_set_reward_featured(uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_set_reward_featured(p_reward_id uuid, p_is_featured boolean) RETURNS jsonb
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

  SELECT to_jsonb(reward)
  INTO v_before
  FROM public.rewards reward
  WHERE reward.id = p_reward_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Reward not found';
  END IF;

  UPDATE public.rewards
  SET is_featured = p_is_featured,
      updated_at = timezone('utc', now())
  WHERE id = p_reward_id;

  SELECT to_jsonb(reward)
  INTO v_after
  FROM public.rewards reward
  WHERE reward.id = p_reward_id;

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
    'toggle_reward_featured',
    'rewards',
    'reward',
    p_reward_id::text,
    v_before,
    v_after,
    jsonb_build_object('is_featured', p_is_featured)
  );

  RETURN jsonb_build_object(
    'id', p_reward_id,
    'is_featured', p_is_featured
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
-- Name: admin_update_campaign_status(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_update_campaign_status(p_campaign_id uuid, p_status text) RETURNS jsonb
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

  SELECT to_jsonb(campaign)
  INTO v_before
  FROM public.campaigns campaign
  WHERE campaign.id = p_campaign_id;

  IF v_before IS NULL THEN
    RAISE EXCEPTION 'Campaign not found';
  END IF;

  UPDATE public.campaigns
  SET status = p_status,
      sent_at = CASE
        WHEN p_status = 'sent' AND sent_at IS NULL THEN timezone('utc', now())
        ELSE sent_at
      END,
      updated_at = timezone('utc', now())
  WHERE id = p_campaign_id;

  SELECT to_jsonb(campaign)
  INTO v_after
  FROM public.campaigns campaign
  WHERE campaign.id = p_campaign_id;

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
    'update_campaign_status',
    'notifications',
    'campaign',
    p_campaign_id::text,
    v_before,
    v_after,
    jsonb_build_object('status', p_status)
  );

  RETURN jsonb_build_object('id', p_campaign_id, 'status', p_status);
END;
$$;


--
-- Name: admin_update_match_result(text, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_update_match_result(p_match_id text, p_home_goals integer, p_away_goals integer) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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

  RETURN public.score_user_predictions_for_match(p_match_id);
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
    CONSTRAINT matches_last_live_sync_confidence_check CHECK (((last_live_sync_confidence IS NULL) OR ((last_live_sync_confidence >= (0)::numeric) AND (last_live_sync_confidence <= (1)::numeric)))),
    CONSTRAINT matches_live_away_score_check CHECK (((live_away_score IS NULL) OR (live_away_score >= 0))),
    CONSTRAINT matches_live_home_score_check CHECK (((live_home_score IS NULL) OR (live_home_score >= 0))),
    CONSTRAINT matches_live_minute_check CHECK (((live_minute IS NULL) OR ((live_minute >= 0) AND (live_minute <= 200))))
);


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
    team_type text DEFAULT 'club'::text NOT NULL
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
    ht.crest_url AS home_logo_url,
    m.away_team_id,
    at.name AS away_team,
    at.crest_url AS away_logo_url,
    m.home_goals AS ft_home,
    m.away_goals AS ft_away,
    m.home_goals,
    m.away_goals,
    m.result_code,
    m.match_status AS status,
    m.match_status,
    m.is_neutral,
    m.source_name AS data_source,
    m.source_name,
    m.source_url,
    m.notes,
    m.created_at,
    m.updated_at
   FROM ((((public.matches m
     LEFT JOIN public.competitions c ON ((c.id = m.competition_id)))
     LEFT JOIN public.seasons s ON ((s.id = m.season_id)))
     LEFT JOIN public.teams ht ON ((ht.id = m.home_team_id)))
     LEFT JOIN public.teams at ON ((at.id = m.away_team_id)));

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
    AS $$ WITH wallet_stats AS (SELECT w.user_id, w.available_balance_fet, w.locked_balance_fet, coalesce((SELECT sum(t.amount_fet) FROM fet_wallet_transactions t WHERE t.user_id = w.user_id AND t.tx_type = 'foundation_grant'), 0) AS welcome_bonus_amount, (SELECT count(*) FROM fet_wallet_transactions t WHERE t.user_id = w.user_id AND t.tx_type NOT IN ('foundation_grant', 'wallet_balance_correction')) AS non_bonus_transaction_count, 50::bigint AS expected_bootstrap_balance FROM fet_wallets w) SELECT * FROM wallet_stats ws WHERE ws.welcome_bonus_amount <> 50 OR (ws.available_balance_fet + ws.locked_balance_fet < 50 AND ws.non_bonus_transaction_count = 0); $$;


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
-- Name: cleanup_old_live_update_runs(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cleanup_old_live_update_runs(p_retain_days integer DEFAULT 14) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_deleted integer;
BEGIN
  DELETE FROM public.match_live_update_runs
  WHERE finished_at IS NOT NULL
    AND finished_at < now() - make_interval(days => p_retain_days);

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
    show_name_on_leaderboards boolean DEFAULT false NOT NULL,
    allow_fan_discovery boolean DEFAULT false NOT NULL,
    is_anonymous boolean DEFAULT false NOT NULL,
    auth_method text DEFAULT 'phone'::text NOT NULL,
    upgraded_from_anonymous_id uuid,
    CONSTRAINT profiles_display_name_length CHECK (((display_name IS NULL) OR ((char_length(TRIM(BOTH FROM display_name)) >= 3) AND (char_length(TRIM(BOTH FROM display_name)) <= 24)))),
    CONSTRAINT profiles_fan_id_six_digits CHECK ((fan_id ~ '^\d{6}$'::text))
);


--
-- Name: COLUMN profiles.region; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.profiles.region IS 'Inferred user region: global, africa, europe, americas';


--
-- Name: COLUMN profiles.show_name_on_leaderboards; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.profiles.show_name_on_leaderboards IS 'When true, public leaderboard surfaces may show the user display name instead of the Fan ID.';


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
-- Name: ensure_user_foundation(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ensure_user_foundation(p_user_id uuid) RETURNS void
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

  IF to_regclass('public.app_preferences') IS NOT NULL THEN
    INSERT INTO public.app_preferences (user_id)
    VALUES (p_user_id)
    ON CONFLICT (user_id) DO NOTHING;
  END IF;

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
        p_user_id,
        'Foundation grant - welcome bonus'
      );
    END IF;
  END IF;
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
BEGIN
  SELECT id INTO v_id
  FROM auth.users
  WHERE phone = p_phone
  LIMIT 1;

  RETURN v_id;
END;
$$;


--
-- Name: generate_prediction_engine_output(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_prediction_engine_output(p_match_id text, p_model_version text DEFAULT 'simple_form_v1'::text) RETURNS uuid
    LANGUAGE plpgsql
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


--
-- Name: generate_predictions_for_upcoming_matches(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_predictions_for_upcoming_matches(p_limit integer DEFAULT 50) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_count integer := 0;
  rec record;
BEGIN
  FOR rec IN
    SELECT id
    FROM public.matches
    WHERE match_status IN ('scheduled', 'live')
      AND match_date >= now() - interval '6 hours'
    ORDER BY match_date ASC
    LIMIT greatest(1, p_limit)
  LOOP
    PERFORM public.generate_prediction_engine_output(rec.id);
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
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
    'feature_flags', (
      SELECT COALESCE(
        jsonb_object_agg(ff.key, ff.enabled),
        '{}'::jsonb
      )
      FROM public.feature_flags ff
      WHERE (ff.market = p_market OR ff.market = 'global')
        AND (ff.platform = p_platform OR ff.platform = 'all')
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

  RETURN v_result;
END;
$$;


--
-- Name: get_competition_current_season(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_competition_current_season(p_competition_id text) RETURNS text
    LANGUAGE plpgsql STABLE
    SET search_path TO 'public'
    AS $$
DECLARE
  v_season text;
BEGIN
  IF p_competition_id IS NULL OR btrim(p_competition_id) = '' THEN
    RETURN NULL;
  END IF;

  SELECT m.season
  INTO v_season
  FROM public.matches AS m
  WHERE m.competition_id = p_competition_id
    AND m.season IS NOT NULL
    AND public.normalize_match_status_value(m.status) IN ('live', 'upcoming')
  ORDER BY
    CASE
      WHEN public.normalize_match_status_value(m.status) = 'live' THEN 0
      ELSE 1
    END,
    m.date ASC NULLS LAST
  LIMIT 1;

  IF v_season IS NOT NULL THEN
    RETURN v_season;
  END IF;

  SELECT m.season
  INTO v_season
  FROM public.matches AS m
  WHERE m.competition_id = p_competition_id
    AND m.season IS NOT NULL
  ORDER BY
    m.date DESC NULLS LAST,
    public.season_sort_key(m.season) DESC,
    m.season DESC
  LIMIT 1;

  IF v_season IS NOT NULL THEN
    RETURN v_season;
  END IF;

  SELECT s.season
  INTO v_season
  FROM public.competition_standings AS s
  WHERE s.competition_id = p_competition_id
    AND nullif(btrim(s.season), '') IS NOT NULL
  ORDER BY
    public.season_sort_key(s.season) DESC,
    s.season DESC
  LIMIT 1;

  RETURN v_season;
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
-- Name: install_openfootball_sync_schedule(text, text, text, text, jsonb, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.install_openfootball_sync_schedule(p_project_url text, p_anon_key text, p_admin_secret text, p_schedule text DEFAULT '17 */6 * * *'::text, p_payload jsonb DEFAULT NULL::jsonb, p_job_name text DEFAULT 'market-sync-openfootball'::text) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'cron', 'vault'
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
-- Name: mark_all_notifications_read(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mark_all_notifications_read() RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  UPDATE public.user_notifications
  SET read_at = COALESCE(read_at, now())
  WHERE user_id = auth.uid()
    AND read_at IS NULL;
$$;


--
-- Name: mark_notification_read(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mark_notification_read(p_notification_id uuid) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  UPDATE public.user_notifications
  SET read_at = COALESCE(read_at, now())
  WHERE id = p_notification_id
    AND user_id = auth.uid();
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

  -- Transfer favorite teams
  INSERT INTO public.user_favorite_teams (user_id, team_id, team_name, team_short_name,
    team_country, team_country_code, team_league, team_crest_url, source, sort_order,
    created_at, updated_at)
  SELECT p_auth_id, uft.team_id, uft.team_name, uft.team_short_name,
    uft.team_country, uft.team_country_code, uft.team_league, uft.team_crest_url,
    uft.source, uft.sort_order, uft.created_at, now()
  FROM public.user_favorite_teams uft
  WHERE uft.user_id = p_anon_id
    AND NOT EXISTS (
      SELECT 1 FROM public.user_favorite_teams existing
      WHERE existing.user_id = p_auth_id AND existing.team_id = uft.team_id
    );

  -- Transfer followed teams
  INSERT INTO public.user_followed_teams (user_id, team_id, created_at)
  SELECT p_auth_id, uft.team_id, uft.created_at
  FROM public.user_followed_teams uft
  WHERE uft.user_id = p_anon_id
    AND NOT EXISTS (
      SELECT 1 FROM public.user_followed_teams existing
      WHERE existing.user_id = p_auth_id AND existing.team_id = uft.team_id
    );

  -- Transfer followed competitions
  INSERT INTO public.user_followed_competitions (user_id, competition_id, created_at)
  SELECT p_auth_id, ufc.competition_id, ufc.created_at
  FROM public.user_followed_competitions ufc
  WHERE ufc.user_id = p_anon_id
    AND NOT EXISTS (
      SELECT 1 FROM public.user_followed_competitions existing
      WHERE existing.user_id = p_auth_id AND existing.competition_id = ufc.competition_id
    );

  -- Copy onboarding fields
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

  -- Clean up anonymous user data
  DELETE FROM public.user_favorite_teams WHERE user_id = p_anon_id;
  DELETE FROM public.user_followed_teams WHERE user_id = p_anon_id;
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
-- Name: normalize_match_status_before_write(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.normalize_match_status_before_write() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.status := coalesce(
    public.normalize_match_status_value(NEW.status),
    lower(coalesce(NEW.status, 'upcoming'))
  );
  RETURN NEW;
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
-- Name: redeem_offer(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.redeem_offer(p_offer_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id UUID;
  v_offer RECORD;
  v_balance BIGINT;
  v_redemption_id UUID;
  v_delivery_value TEXT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  SELECT * INTO v_offer FROM public.marketplace_offers
  WHERE id = p_offer_id AND is_active = true
  FOR UPDATE;

  IF v_offer IS NULL THEN RAISE EXCEPTION 'Offer not found or inactive'; END IF;
  IF v_offer.stock IS NOT NULL AND v_offer.stock <= 0 THEN
    RAISE EXCEPTION 'Offer is out of stock';
  END IF;
  IF v_offer.valid_until IS NOT NULL AND v_offer.valid_until < now() THEN
    RAISE EXCEPTION 'Offer has expired';
  END IF;

  SELECT available_balance_fet INTO v_balance
  FROM public.fet_wallets WHERE user_id = v_user_id FOR UPDATE;

  IF v_balance IS NULL OR v_balance < v_offer.cost_fet THEN
    RAISE EXCEPTION 'Insufficient FET balance';
  END IF;

  UPDATE public.fet_wallets
  SET available_balance_fet = available_balance_fet - v_offer.cost_fet,
      updated_at = now()
  WHERE user_id = v_user_id;

  IF v_offer.stock IS NOT NULL THEN
    UPDATE public.marketplace_offers SET stock = stock - 1 WHERE id = p_offer_id;
  END IF;

  v_delivery_value := 'FZ-' || upper(substring(gen_random_uuid()::text FROM 1 FOR 8));

  INSERT INTO public.marketplace_redemptions (
    offer_id, user_id, cost_fet, delivery_type, delivery_value, status
  ) VALUES (
    p_offer_id, v_user_id, v_offer.cost_fet, v_offer.delivery_type,
    v_delivery_value, 'fulfilled'
  ) RETURNING id INTO v_redemption_id;

  INSERT INTO public.fet_wallet_transactions (
    user_id, tx_type, direction, amount_fet,
    balance_before_fet, balance_after_fet,
    reference_type, reference_id, title
  ) VALUES (
    v_user_id, 'redemption', 'debit', v_offer.cost_fet,
    v_balance, v_balance - v_offer.cost_fet,
    'marketplace_redemption', v_redemption_id,
    'Redeemed: ' || v_offer.title
  );

  RETURN jsonb_build_object(
    'status', 'fulfilled',
    'redemption_id', v_redemption_id,
    'delivery_type', v_offer.delivery_type,
    'delivery_value', v_delivery_value,
    'balance_after', v_balance - v_offer.cost_fet
  );
END;
$$;


--
-- Name: redeem_reward(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.redeem_reward(p_offer_id uuid) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_cost bigint;
    v_code text := upper(substring(gen_random_uuid()::text from 1 for 8));
BEGIN
    SELECT fet_cost INTO v_cost FROM public.reward_offers WHERE id = p_offer_id AND is_available = true;
    IF v_cost IS NULL THEN RAISE EXCEPTION 'Offer not found or unavailable'; END IF;

    -- Check balance
    IF (SELECT available_balance_fet FROM public.fet_wallets WHERE user_id = v_user_id FOR UPDATE) < v_cost THEN
        RAISE EXCEPTION 'Insufficient FET balance';
    END IF;

    -- Debit wallet
    UPDATE public.fet_wallets SET available_balance_fet = available_balance_fet - v_cost WHERE user_id = v_user_id;

    -- Log transaction
    INSERT INTO public.fet_wallet_transactions (user_id, tx_type, direction, amount_fet, reference_type, reference_id)
    VALUES (v_user_id, 'reward_redemption', 'debit', v_cost, 'redemption', p_offer_id);

    -- Create redemption record
    INSERT INTO public.redemptions (user_id, offer_id, status, redemption_code)
    VALUES (v_user_id, p_offer_id, 'pending', v_code);

    RETURN v_code;
END;
$$;


--
-- Name: refresh_crowd_predictions(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_crowd_predictions() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_job_id uuid;
BEGIN
  INSERT INTO public.cron_job_log (job_name, status)
  VALUES ('refresh_crowd_predictions', 'running')
  RETURNING id INTO v_job_id;

  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_crowd_predictions;

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


--
-- Name: refresh_global_leaderboard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_global_leaderboard() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: refresh_materialized_views(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_materialized_views() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: refresh_season_leaderboard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_season_leaderboard() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  IF to_regclass('public.mv_season_leaderboard') IS NOT NULL THEN
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_season_leaderboard;
  END IF;
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
-- Name: remove_openfootball_sync_schedule(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.remove_openfootball_sync_schedule(p_job_name text DEFAULT 'market-sync-openfootball'::text) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'cron'
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


--
-- Name: repair_wallet_bootstrap_gaps(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.repair_wallet_bootstrap_gaps() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$ DECLARE v_repaired_count integer := 0; BEGIN WITH candidate_wallets AS (SELECT audit.user_id, audit.available_balance_fet, audit.locked_balance_fet FROM public.audit_wallet_bootstrap_gaps() audit WHERE audit.non_bonus_transaction_count = 0 AND NOT EXISTS (SELECT 1 FROM public.fet_wallet_transactions t WHERE t.user_id = audit.user_id AND t.tx_type = 'wallet_balance_correction') FOR UPDATE), updated_wallets AS (UPDATE public.fet_wallets wallet SET available_balance_fet = 50, updated_at = now() FROM candidate_wallets candidate WHERE wallet.user_id = candidate.user_id RETURNING wallet.user_id, candidate.available_balance_fet AS balance_before_fet, 50::bigint AS balance_after_fet), inserted_transactions AS (INSERT INTO public.fet_wallet_transactions (user_id, tx_type, direction, amount_fet, balance_before_fet, balance_after_fet, reference_type, metadata) SELECT updated.user_id, 'wallet_balance_correction', 'credit', updated.balance_after_fet - updated.balance_before_fet, updated.balance_before_fet, updated.balance_after_fet, 'wallet_repair', jsonb_build_object('reason', 'corrected welcome bonus to 50 FET', 'expected_bootstrap_balance', 50) FROM updated_wallets updated RETURNING 1) SELECT COUNT(*) INTO v_repaired_count FROM inserted_transactions; RETURN COALESCE(v_repaired_count, 0); END; $$;


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
-- Name: score_finished_matches_with_pending_predictions(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.score_finished_matches_with_pending_predictions(p_limit integer DEFAULT 50) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  rec record;
  v_count integer := 0;
BEGIN
  FOR rec IN
    SELECT DISTINCT m.id
    FROM public.matches m
    JOIN public.user_predictions up
      ON up.match_id = m.id
    WHERE m.match_status = 'finished'
      AND up.reward_status = 'pending'
    ORDER BY m.match_date DESC
    LIMIT greatest(1, p_limit)
  LOOP
    PERFORM public.score_user_predictions_for_match(rec.id);
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;


--
-- Name: score_user_predictions_for_match(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.score_user_predictions_for_match(p_match_id text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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
-- Name: submit_user_prediction(text, text, boolean, boolean, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.submit_user_prediction(p_match_id text, p_predicted_result_code text DEFAULT NULL::text, p_predicted_over25 boolean DEFAULT NULL::boolean, p_predicted_btts boolean DEFAULT NULL::boolean, p_predicted_home_goals integer DEFAULT NULL::integer, p_predicted_away_goals integer DEFAULT NULL::integer) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_match record;
  v_prediction_id uuid;
  v_result_code text;
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

  IF v_match.match_date <= now() OR v_match.match_status NOT IN ('scheduled', 'live') THEN
    RAISE EXCEPTION 'Predictions are closed for this match';
  END IF;

  v_result_code := CASE
    WHEN p_predicted_result_code IS NULL OR trim(p_predicted_result_code) = '' THEN NULL
    ELSE upper(trim(p_predicted_result_code))
  END;

  IF v_result_code IS NOT NULL AND v_result_code NOT IN ('H', 'D', 'A') THEN
    RAISE EXCEPTION 'predicted_result_code must be H, D, or A';
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


--
-- Name: sync_match_logos_from_teams(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_match_logos_from_teams() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_home_updated integer := 0;
  v_away_updated integer := 0;
BEGIN
  WITH home_updates AS (
    UPDATE public.matches AS m
    SET
      home_logo_url = t.crest_url,
      updated_at = timezone('utc', now())
    FROM public.teams AS t
    WHERE
      m.home_team_id = t.id
      AND t.crest_url IS NOT NULL
      AND t.crest_url != ''
      AND (m.home_logo_url IS NULL OR m.home_logo_url = '' OR m.home_logo_url != t.crest_url)
    RETURNING m.id
  )
  SELECT count(*) INTO v_home_updated FROM home_updates;

  WITH away_updates AS (
    UPDATE public.matches AS m
    SET
      away_logo_url = t.crest_url,
      updated_at = timezone('utc', now())
    FROM public.teams AS t
    WHERE
      m.away_team_id = t.id
      AND t.crest_url IS NOT NULL
      AND t.crest_url != ''
      AND (m.away_logo_url IS NULL OR m.away_logo_url = '' OR m.away_logo_url != t.crest_url)
    RETURNING m.id
  )
  SELECT count(*) INTO v_away_updated FROM away_updates;

  RETURN jsonb_build_object(
    'home_logos_updated', v_home_updated,
    'away_logos_updated', v_away_updated,
    'synced_at', timezone('utc', now())
  );
END;
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
-- Name: transfer_fet(text, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.transfer_fet(p_recipient_identifier text, p_amount_fet bigint) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: transfer_fet_by_fan_id(text, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.transfer_fet_by_fan_id(p_recipient_fan_id text, p_amount_fet bigint) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
DECLARE
  v_sender_id UUID := auth.uid();
  v_sender_fan_id TEXT;
  v_recipient_id UUID;
  v_sender_balance BIGINT;
  v_recipient_balance_before BIGINT := 0;
  v_clean_fan_id TEXT := regexp_replace(COALESCE(p_recipient_fan_id, ''), '[^0-9]', '', 'g');
BEGIN
  IF v_sender_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  PERFORM public.assert_wallet_available(v_sender_id);

  IF NOT public.check_rate_limit(v_sender_id, 'transfer_fet', 10, interval '1 day') THEN
    RAISE EXCEPTION 'Rate limit exceeded — max 10 transfers per day';
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

  SELECT COALESCE(user_id, id)
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
      COALESCE(v_recipient_balance_before, 0),
      COALESCE(v_recipient_balance_before, 0) + p_amount_fet,
      'transfer',
      v_sender_fan_id,
      'Transfer from Fan #' || COALESCE(v_sender_fan_id, '000000')
    );

  RETURN jsonb_build_object(
    'success', true,
    'recipient_fan_id', v_clean_fan_id,
    'amount_fet', p_amount_fet
  );
END;
$_$;


--
-- Name: transfer_fet_rate_limited(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.transfer_fet_rate_limited(p_recipient_email text, p_amount integer) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT check_rate_limit(v_user_id, 'transfer_fet', 10, 24) THEN
    RAISE EXCEPTION 'Rate limit exceeded — max 10 transfers per day';
  END IF;

  PERFORM transfer_fet(p_recipient_email, p_amount);
END;
$$;


--
-- Name: transfer_fet_rate_limited(text, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.transfer_fet_rate_limited(p_recipient_identifier text, p_amount_fet bigint) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT public.transfer_fet(p_recipient_identifier, p_amount_fet);
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
 SELECT id,
    name,
    short_name,
    country,
    tier,
    competition_type,
    is_international,
    is_active,
    created_at,
    updated_at,
    current_season_id,
    current_season_label,
    future_match_count,
        CASE
            WHEN (lower(name) ~~ '%premier league%'::text) THEN (1)::bigint
            WHEN (lower(name) ~~ '%champions league%'::text) THEN (2)::bigint
            WHEN (lower(name) ~~ '%la liga%'::text) THEN (3)::bigint
            WHEN (lower(name) ~~ '%serie a%'::text) THEN (4)::bigint
            WHEN (lower(name) ~~ '%bundesliga%'::text) THEN (5)::bigint
            WHEN (lower(name) ~~ '%ligue 1%'::text) THEN (6)::bigint
            WHEN is_international THEN (20)::bigint
            ELSE (100 + row_number() OVER (ORDER BY name))
        END AS catalog_rank
   FROM public.app_competitions ac;


--
-- Name: app_config_remote; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_config_remote (
    key text NOT NULL,
    value jsonb DEFAULT 'null'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


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
    source text DEFAULT 'gemini'::text NOT NULL,
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
-- Name: fan_badges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fan_badges (
    id text NOT NULL,
    name text NOT NULL,
    description text DEFAULT ''::text,
    category text DEFAULT 'milestone'::text,
    icon_name text DEFAULT 'award'::text,
    color_hex text DEFAULT '#22C55E'::text,
    criteria_type text DEFAULT 'manual'::text,
    criteria_value integer DEFAULT 0
);


--
-- Name: fan_clubs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fan_clubs (
    id text NOT NULL,
    name text NOT NULL,
    members integer DEFAULT 0 NOT NULL,
    total_pool integer DEFAULT 0 NOT NULL,
    crest text DEFAULT '⚽'::text NOT NULL,
    league text DEFAULT ''::text NOT NULL,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: fan_earned_badges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fan_earned_badges (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    badge_id text,
    earned_at timestamp with time zone DEFAULT now()
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
-- Name: fan_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fan_levels (
    level integer NOT NULL,
    name text NOT NULL,
    title text DEFAULT ''::text NOT NULL,
    min_xp integer DEFAULT 0 NOT NULL,
    icon_name text DEFAULT 'user'::text,
    color_hex text DEFAULT '#A8A29E'::text
);


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
-- Name: fet_wallets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fet_wallets (
    user_id uuid NOT NULL,
    available_balance_fet bigint DEFAULT 0 NOT NULL,
    locked_balance_fet bigint DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: fet_supply_overview; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.fet_supply_overview AS
 SELECT COALESCE(sum(available_balance_fet), (0)::numeric) AS total_available,
    COALESCE(sum(locked_balance_fet), (0)::numeric) AS total_locked,
    COALESCE(sum((available_balance_fet + locked_balance_fet)), (0)::numeric) AS total_supply,
    count(*) AS total_wallets,
    count(*) FILTER (WHERE (available_balance_fet > 0)) AS active_wallets,
    (COALESCE(avg(available_balance_fet), (0)::numeric))::bigint AS avg_balance,
    COALESCE(max(available_balance_fet), (0)::bigint) AS max_balance,
    (public.fet_supply_cap())::numeric AS supply_cap,
    GREATEST(((public.fet_supply_cap())::numeric - COALESCE(sum((available_balance_fet + locked_balance_fet)), (0)::numeric)), (0)::numeric) AS remaining_mintable
   FROM public.fet_wallets;


--
-- Name: fet_supply_overview_admin; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.fet_supply_overview_admin AS
 SELECT total_available,
    total_locked,
    total_supply,
    total_wallets,
    active_wallets,
    avg_balance,
    max_balance,
    supply_cap,
    remaining_mintable
   FROM public.fet_supply_overview
  WHERE public.is_active_admin_operator(auth.uid());


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
    reference_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    title text,
    CONSTRAINT fet_wallet_transactions_direction_check CHECK ((direction = ANY (ARRAY['credit'::text, 'debit'::text])))
);


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
    COALESCE(NULLIF(TRIM(BOTH FROM (u.raw_user_meta_data ->> 'display_name'::text)), ''::text), NULLIF(TRIM(BOTH FROM (u.raw_user_meta_data ->> 'full_name'::text)), ''::text), NULLIF(split_part((COALESCE(u.email, ''::character varying))::text, '@'::text, 1), ''::text), NULLIF(u.phone, ''::text), (tx.user_id)::text) AS display_name,
    COALESCE(((tx.metadata ->> 'flagged'::text))::boolean, false) AS flagged
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
-- Name: leaderboard_seasons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leaderboard_seasons (
    id text NOT NULL,
    name text NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    status text DEFAULT 'active'::text
);


--
-- Name: marketplace_offers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.marketplace_offers (
    id text NOT NULL,
    partner_id text,
    title text NOT NULL,
    description text DEFAULT ''::text,
    category text DEFAULT 'merch'::text,
    cost_fet integer DEFAULT 0 NOT NULL,
    delivery_type text DEFAULT 'voucher'::text,
    is_active boolean DEFAULT true,
    original_value text
);


--
-- Name: marketplace_partners; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.marketplace_partners (
    id text NOT NULL,
    name text NOT NULL,
    description text DEFAULT ''::text,
    logo_url text,
    is_active boolean DEFAULT true
);


--
-- Name: marketplace_redemptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.marketplace_redemptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    offer_id text NOT NULL,
    user_id uuid NOT NULL,
    cost_fet bigint NOT NULL,
    delivery_type text NOT NULL,
    delivery_value text,
    status text DEFAULT 'pending'::text,
    redeemed_at timestamp with time zone DEFAULT now(),
    used_at timestamp with time zone,
    expires_at timestamp with time zone,
    CONSTRAINT marketplace_redemptions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'fulfilled'::text, 'used'::text, 'expired'::text, 'refunded'::text])))
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
-- Name: user_predictions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_predictions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    match_id text NOT NULL,
    predicted_result_code text,
    predicted_over25 boolean,
    predicted_btts boolean,
    predicted_home_goals integer,
    predicted_away_goals integer,
    points_awarded integer DEFAULT 0 NOT NULL,
    reward_status text DEFAULT 'pending'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_predictions_predicted_away_goals_check CHECK (((predicted_away_goals IS NULL) OR (predicted_away_goals >= 0))),
    CONSTRAINT user_predictions_predicted_home_goals_check CHECK (((predicted_home_goals IS NULL) OR (predicted_home_goals >= 0))),
    CONSTRAINT user_predictions_predicted_result_code_check CHECK ((predicted_result_code = ANY (ARRAY['H'::text, 'D'::text, 'A'::text]))),
    CONSTRAINT user_predictions_reward_status_check CHECK ((reward_status = ANY (ARRAY['pending'::text, 'awarded'::text, 'no_reward'::text, 'reversed'::text])))
);


--
-- Name: match_prediction_consensus; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.match_prediction_consensus AS
 SELECT match_id,
    count(*) AS total_predictions,
    count(*) FILTER (WHERE (predicted_result_code = 'H'::text)) AS home_pick_count,
    count(*) FILTER (WHERE (predicted_result_code = 'D'::text)) AS draw_pick_count,
    count(*) FILTER (WHERE (predicted_result_code = 'A'::text)) AS away_pick_count,
    (round(((100.0 * (count(*) FILTER (WHERE (predicted_result_code = 'H'::text)))::numeric) / (NULLIF(count(*), 0))::numeric), 0))::integer AS home_pct,
    (round(((100.0 * (count(*) FILTER (WHERE (predicted_result_code = 'D'::text)))::numeric) / (NULLIF(count(*), 0))::numeric), 0))::integer AS draw_pct,
    (round(((100.0 * (count(*) FILTER (WHERE (predicted_result_code = 'A'::text)))::numeric) / (NULLIF(count(*), 0))::numeric), 0))::integer AS away_pct
   FROM public.user_predictions up
  GROUP BY match_id;


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
-- Name: news; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.news (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    source text NOT NULL,
    title text NOT NULL,
    url text NOT NULL,
    image_url text,
    published_at timestamp with time zone,
    fetched_at timestamp with time zone DEFAULT now()
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
    prediction_updates boolean DEFAULT true NOT NULL,
    reward_updates boolean DEFAULT true NOT NULL
);


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
-- Name: token_rewards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.token_rewards (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    user_prediction_id uuid NOT NULL,
    match_id text NOT NULL,
    reward_type text DEFAULT 'prediction_reward'::text NOT NULL,
    token_amount bigint DEFAULT 0 NOT NULL,
    status text DEFAULT 'awarded'::text NOT NULL,
    awarded_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT token_rewards_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'awarded'::text, 'reversed'::text]))),
    CONSTRAINT token_rewards_token_amount_check CHECK ((token_amount >= 0))
);


--
-- Name: prediction_leaderboard; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.prediction_leaderboard AS
 SELECT up.user_id,
    COALESCE(NULLIF(TRIM(BOTH FROM p.display_name), ''::text), NULLIF(TRIM(BOTH FROM p.fan_id), ''::text), 'Fan'::text) AS display_name,
    count(*) AS prediction_count,
    COALESCE(sum(up.points_awarded), (0)::bigint) AS total_points,
    COALESCE(sum(tr.token_amount) FILTER (WHERE (tr.status = 'awarded'::text)), (0)::numeric) AS total_fet,
    count(*) FILTER (WHERE ((up.predicted_result_code IS NOT NULL) AND (up.predicted_result_code = m.result_code))) AS correct_results,
    count(*) FILTER (WHERE ((up.predicted_home_goals IS NOT NULL) AND (up.predicted_away_goals IS NOT NULL) AND (up.predicted_home_goals = m.home_goals) AND (up.predicted_away_goals = m.away_goals))) AS exact_scores
   FROM (((public.user_predictions up
     LEFT JOIN public.profiles p ON ((p.user_id = up.user_id)))
     LEFT JOIN public.matches m ON ((m.id = up.match_id)))
     LEFT JOIN public.token_rewards tr ON ((tr.user_prediction_id = up.id)))
  GROUP BY up.user_id, COALESCE(NULLIF(TRIM(BOTH FROM p.display_name), ''::text), NULLIF(TRIM(BOTH FROM p.fan_id), ''::text), 'Fan'::text);


--
-- Name: predictions_engine_outputs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.predictions_engine_outputs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    match_id text NOT NULL,
    model_version text DEFAULT 'simple_form_v1'::text NOT NULL,
    home_win_score numeric(6,4) DEFAULT 0.3333 NOT NULL,
    draw_score numeric(6,4) DEFAULT 0.3333 NOT NULL,
    away_win_score numeric(6,4) DEFAULT 0.3333 NOT NULL,
    over25_score numeric(6,4) DEFAULT 0.5000 NOT NULL,
    btts_score numeric(6,4) DEFAULT 0.5000 NOT NULL,
    predicted_home_goals integer,
    predicted_away_goals integer,
    confidence_label text DEFAULT 'low'::text NOT NULL,
    generated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT predictions_engine_outputs_confidence_label_check CHECK ((confidence_label = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text])))
);


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
-- Name: public_leaderboard; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.public_leaderboard AS
 SELECT user_id,
    display_name,
    prediction_count,
    total_points,
    total_fet,
    correct_results,
    exact_scores
   FROM public.prediction_leaderboard;


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
-- Name: team_aliases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.team_aliases (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    team_id text NOT NULL,
    alias_name text NOT NULL,
    source_name text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
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
    prediction_streak integer DEFAULT 0,
    longest_streak integer DEFAULT 0,
    total_predictions integer DEFAULT 0,
    total_prediction_entries integer DEFAULT 0,
    correct_predictions integer DEFAULT 0,
    total_fet_earned bigint DEFAULT 0,
    total_fet_spent bigint DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: user_profiles_admin; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.user_profiles_admin AS
 SELECT u.id,
    u.email,
    u.phone,
    (COALESCE(u.raw_user_meta_data, '{}'::jsonb) || jsonb_strip_nulls(jsonb_build_object('display_name', COALESCE(NULLIF(TRIM(BOTH FROM (u.raw_user_meta_data ->> 'display_name'::text)), ''::text), NULLIF(TRIM(BOTH FROM (u.raw_user_meta_data ->> 'full_name'::text)), ''::text), NULLIF(split_part((COALESCE(u.email, ''::character varying))::text, '@'::text, 1), ''::text), NULLIF(u.phone, ''::text)), 'is_banned', COALESCE(us.is_banned, false), 'is_suspended', COALESCE(us.is_suspended, false), 'wallet_frozen', COALESCE(us.wallet_frozen, false), 'ban_reason', us.ban_reason, 'suspend_reason', us.suspend_reason, 'wallet_freeze_reason', us.wallet_freeze_reason))) AS raw_user_meta_data,
    u.created_at,
    u.last_sign_in_at,
    COALESCE(fw.available_balance_fet, (0)::bigint) AS available_balance_fet,
    COALESCE(fw.locked_balance_fet, (0)::bigint) AS locked_balance_fet,
    COALESCE(NULLIF(TRIM(BOTH FROM (u.raw_user_meta_data ->> 'display_name'::text)), ''::text), NULLIF(TRIM(BOTH FROM (u.raw_user_meta_data ->> 'full_name'::text)), ''::text), NULLIF(split_part((COALESCE(u.email, ''::character varying))::text, '@'::text, 1), ''::text), NULLIF(u.phone, ''::text), (u.id)::text) AS display_name,
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
-- Name: wallet_overview; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.wallet_overview AS
 SELECT w.user_id,
    w.available_balance_fet,
    w.locked_balance_fet,
    p.fan_id,
    p.display_name
   FROM (public.fet_wallets w
     JOIN public.profiles p ON ((p.user_id = w.user_id)))
  WHERE (w.user_id = auth.uid());


--
-- Name: wallet_overview_admin; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.wallet_overview_admin AS
 SELECT fw.user_id,
    COALESCE(NULLIF(TRIM(BOTH FROM (u.raw_user_meta_data ->> 'display_name'::text)), ''::text), NULLIF(TRIM(BOTH FROM (u.raw_user_meta_data ->> 'full_name'::text)), ''::text), NULLIF(split_part((COALESCE(u.email, ''::character varying))::text, '@'::text, 1), ''::text), NULLIF(u.phone, ''::text), (fw.user_id)::text) AS display_name,
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
    fw.created_at
   FROM ((public.fet_wallets fw
     LEFT JOIN auth.users u ON ((u.id = fw.user_id)))
     LEFT JOIN public.user_status us ON ((us.user_id = fw.user_id)))
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
-- Name: competitions competitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.competitions
    ADD CONSTRAINT competitions_pkey PRIMARY KEY (id);


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
-- Name: fan_badges fan_badges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fan_badges
    ADD CONSTRAINT fan_badges_pkey PRIMARY KEY (id);


--
-- Name: fan_clubs fan_clubs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fan_clubs
    ADD CONSTRAINT fan_clubs_pkey PRIMARY KEY (id);


--
-- Name: fan_earned_badges fan_earned_badges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fan_earned_badges
    ADD CONSTRAINT fan_earned_badges_pkey PRIMARY KEY (id);


--
-- Name: fan_earned_badges fan_earned_badges_user_id_badge_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fan_earned_badges
    ADD CONSTRAINT fan_earned_badges_user_id_badge_id_key UNIQUE (user_id, badge_id);


--
-- Name: fan_levels fan_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fan_levels
    ADD CONSTRAINT fan_levels_pkey PRIMARY KEY (level);


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
-- Name: leaderboard_seasons leaderboard_seasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leaderboard_seasons
    ADD CONSTRAINT leaderboard_seasons_pkey PRIMARY KEY (id);


--
-- Name: marketplace_offers marketplace_offers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.marketplace_offers
    ADD CONSTRAINT marketplace_offers_pkey PRIMARY KEY (id);


--
-- Name: marketplace_partners marketplace_partners_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.marketplace_partners
    ADD CONSTRAINT marketplace_partners_pkey PRIMARY KEY (id);


--
-- Name: marketplace_redemptions marketplace_redemptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.marketplace_redemptions
    ADD CONSTRAINT marketplace_redemptions_pkey PRIMARY KEY (id);


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
-- Name: matches matches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_pkey PRIMARY KEY (id);


--
-- Name: moderation_reports moderation_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.moderation_reports
    ADD CONSTRAINT moderation_reports_pkey PRIMARY KEY (id);


--
-- Name: news news_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news
    ADD CONSTRAINT news_pkey PRIMARY KEY (id);


--
-- Name: news news_url_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news
    ADD CONSTRAINT news_url_key UNIQUE (url);


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
-- Name: otp_verifications otp_verifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.otp_verifications
    ADD CONSTRAINT otp_verifications_pkey PRIMARY KEY (id);


--
-- Name: phone_presets phone_presets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phone_presets
    ADD CONSTRAINT phone_presets_pkey PRIMARY KEY (country_code);


--
-- Name: predictions_engine_outputs predictions_engine_outputs_match_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.predictions_engine_outputs
    ADD CONSTRAINT predictions_engine_outputs_match_id_key UNIQUE (match_id);


--
-- Name: predictions_engine_outputs predictions_engine_outputs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.predictions_engine_outputs
    ADD CONSTRAINT predictions_engine_outputs_pkey PRIMARY KEY (id);


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
-- Name: token_rewards token_rewards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.token_rewards
    ADD CONSTRAINT token_rewards_pkey PRIMARY KEY (id);


--
-- Name: token_rewards token_rewards_unique_prediction; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.token_rewards
    ADD CONSTRAINT token_rewards_unique_prediction UNIQUE (user_prediction_id, reward_type);


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
-- Name: user_predictions user_predictions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_predictions
    ADD CONSTRAINT user_predictions_pkey PRIMARY KEY (id);


--
-- Name: user_predictions user_predictions_unique_match; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_predictions
    ADD CONSTRAINT user_predictions_unique_match UNIQUE (user_id, match_id);


--
-- Name: user_status user_status_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_status
    ADD CONSTRAINT user_status_pkey PRIMARY KEY (user_id);


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
-- Name: idx_engine_outputs_generated; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_engine_outputs_generated ON public.predictions_engine_outputs USING btree (generated_at DESC);


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
-- Name: idx_marketplace_redemptions_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_marketplace_redemptions_user ON public.marketplace_redemptions USING btree (user_id, redeemed_at DESC);


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
-- Name: idx_news_fetched; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_fetched ON public.news USING btree (fetched_at DESC);


--
-- Name: idx_news_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_source ON public.news USING btree (source);


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
-- Name: idx_token_rewards_user_awarded; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_token_rewards_user_awarded ON public.token_rewards USING btree (user_id, awarded_at DESC);


--
-- Name: idx_user_favorite_teams_country; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_favorite_teams_country ON public.user_favorite_teams USING btree (team_country_code);


--
-- Name: idx_user_favorite_teams_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_favorite_teams_user ON public.user_favorite_teams USING btree (user_id, source, sort_order, created_at);


--
-- Name: idx_user_predictions_match; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_predictions_match ON public.user_predictions USING btree (match_id, reward_status);


--
-- Name: idx_user_predictions_user_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_predictions_user_created ON public.user_predictions USING btree (user_id, created_at DESC);


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
-- Name: profiles set_profiles_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: fet_wallets set_wallet_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_wallet_updated_at BEFORE UPDATE ON public.fet_wallets FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: matches trg_apply_match_result_code; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_apply_match_result_code BEFORE INSERT OR UPDATE OF home_goals, away_goals, match_status ON public.matches FOR EACH ROW EXECUTE FUNCTION public.apply_match_result_code();


--
-- Name: competitions trg_competitions_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_competitions_updated_at BEFORE UPDATE ON public.competitions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: matches trg_matches_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_matches_set_updated_at BEFORE UPDATE ON public.matches FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


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
-- Name: user_predictions trg_user_predictions_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_user_predictions_updated_at BEFORE UPDATE ON public.user_predictions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


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
-- Name: device_tokens device_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.device_tokens
    ADD CONSTRAINT device_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: fan_earned_badges fan_earned_badges_badge_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fan_earned_badges
    ADD CONSTRAINT fan_earned_badges_badge_id_fkey FOREIGN KEY (badge_id) REFERENCES public.fan_badges(id);


--
-- Name: fan_earned_badges fan_earned_badges_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fan_earned_badges
    ADD CONSTRAINT fan_earned_badges_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: featured_events featured_events_competition_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.featured_events
    ADD CONSTRAINT featured_events_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES public.competitions(id);


--
-- Name: fet_wallet_transactions fet_wallet_transactions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fet_wallet_transactions
    ADD CONSTRAINT fet_wallet_transactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: fet_wallets fet_wallets_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fet_wallets
    ADD CONSTRAINT fet_wallets_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: marketplace_offers marketplace_offers_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.marketplace_offers
    ADD CONSTRAINT marketplace_offers_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES public.marketplace_partners(id);


--
-- Name: marketplace_redemptions marketplace_redemptions_offer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.marketplace_redemptions
    ADD CONSTRAINT marketplace_redemptions_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.marketplace_offers(id);


--
-- Name: marketplace_redemptions marketplace_redemptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.marketplace_redemptions
    ADD CONSTRAINT marketplace_redemptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


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
-- Name: predictions_engine_outputs predictions_engine_outputs_match_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.predictions_engine_outputs
    ADD CONSTRAINT predictions_engine_outputs_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE CASCADE;


--
-- Name: product_events product_events_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_events
    ADD CONSTRAINT product_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


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
-- Name: token_rewards token_rewards_match_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.token_rewards
    ADD CONSTRAINT token_rewards_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE CASCADE;


--
-- Name: token_rewards token_rewards_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.token_rewards
    ADD CONSTRAINT token_rewards_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: token_rewards token_rewards_user_prediction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.token_rewards
    ADD CONSTRAINT token_rewards_user_prediction_id_fkey FOREIGN KEY (user_prediction_id) REFERENCES public.user_predictions(id) ON DELETE CASCADE;


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
-- Name: user_predictions user_predictions_match_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_predictions
    ADD CONSTRAINT user_predictions_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE CASCADE;


--
-- Name: user_predictions user_predictions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_predictions
    ADD CONSTRAINT user_predictions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_status user_status_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_status
    ADD CONSTRAINT user_status_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


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
-- Name: competitions Admin write competitions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admin write competitions" ON public.competitions TO authenticated USING (public.is_admin_manager(auth.uid())) WITH CHECK (public.is_admin_manager(auth.uid()));


--
-- Name: feature_flags Admin write feature flags; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admin write feature flags" ON public.feature_flags TO authenticated USING (public.is_admin_manager(auth.uid())) WITH CHECK (public.is_admin_manager(auth.uid()));


--
-- Name: launch_moments Admin write launch moments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admin write launch moments" ON public.launch_moments TO authenticated USING (public.is_admin_manager(auth.uid())) WITH CHECK (public.is_admin_manager(auth.uid()));


--
-- Name: matches Admin write matches; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admin write matches" ON public.matches TO authenticated USING (public.is_admin_manager(auth.uid())) WITH CHECK (public.is_admin_manager(auth.uid()));


--
-- Name: news Admin write news; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admin write news" ON public.news TO authenticated USING (public.is_admin_manager(auth.uid())) WITH CHECK (public.is_admin_manager(auth.uid()));


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
-- Name: predictions_engine_outputs Admins manage prediction engine outputs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins manage prediction engine outputs" ON public.predictions_engine_outputs TO authenticated USING (public.current_user_has_admin_role(ARRAY['moderator'::text, 'admin'::text, 'super_admin'::text])) WITH CHECK (public.current_user_has_admin_role(ARRAY['moderator'::text, 'admin'::text, 'super_admin'::text]));


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
-- Name: token_rewards Admins manage token rewards; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins manage token rewards" ON public.token_rewards TO authenticated USING (public.current_user_has_admin_role(ARRAY['moderator'::text, 'admin'::text, 'super_admin'::text])) WITH CHECK (public.current_user_has_admin_role(ARRAY['moderator'::text, 'admin'::text, 'super_admin'::text]));


--
-- Name: moderation_reports Admins read moderation reports; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins read moderation reports" ON public.moderation_reports FOR SELECT TO authenticated USING (public.is_active_admin_operator(auth.uid()));


--
-- Name: notification_log Admins read notifications; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins read notifications" ON public.notification_log FOR SELECT TO authenticated USING (public.is_active_admin_operator(auth.uid()));


--
-- Name: user_predictions Admins read user predictions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins read user predictions" ON public.user_predictions FOR SELECT TO authenticated USING (public.current_user_has_admin_role(ARRAY['moderator'::text, 'admin'::text, 'super_admin'::text]));


--
-- Name: fet_wallet_transactions Admins read wallet transactions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins read wallet transactions" ON public.fet_wallet_transactions FOR SELECT TO authenticated USING (public.is_active_admin_operator(auth.uid()));


--
-- Name: competitions Public read access for competitions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read access for competitions" ON public.competitions FOR SELECT USING (true);


--
-- Name: matches Public read access for matches; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read access for matches" ON public.matches FOR SELECT USING (true);


--
-- Name: news Public read access for news; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read access for news" ON public.news FOR SELECT USING (true);


--
-- Name: teams Public read access for teams; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read access for teams" ON public.teams FOR SELECT USING (true);


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
-- Name: currency_rates Public read currency rates; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read currency rates" ON public.currency_rates FOR SELECT USING (true);


--
-- Name: feature_flags Public read feature flags; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read feature flags" ON public.feature_flags FOR SELECT USING (true);


--
-- Name: featured_events Public read featured events; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read featured events" ON public.featured_events FOR SELECT USING (true);


--
-- Name: launch_moments Public read launch moments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read launch moments" ON public.launch_moments FOR SELECT USING (true);


--
-- Name: matches Public read matches; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read matches" ON public.matches FOR SELECT USING (true);


--
-- Name: news Public read news; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read news" ON public.news FOR SELECT USING (true);


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
-- Name: user_predictions Users insert own predictions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users insert own predictions" ON public.user_predictions FOR INSERT TO authenticated WITH CHECK ((auth.uid() = user_id));


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
-- Name: user_predictions Users read own predictions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users read own predictions" ON public.user_predictions FOR SELECT TO authenticated USING ((auth.uid() = user_id));


--
-- Name: marketplace_redemptions Users read own redemptions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users read own redemptions" ON public.marketplace_redemptions FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: user_status Users read own status; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users read own status" ON public.user_status FOR SELECT TO authenticated USING ((auth.uid() = user_id));


--
-- Name: token_rewards Users read own token rewards; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users read own token rewards" ON public.token_rewards FOR SELECT TO authenticated USING ((auth.uid() = user_id));


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
-- Name: user_predictions Users update own predictions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users update own predictions" ON public.user_predictions FOR UPDATE TO authenticated USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


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
-- Name: competitions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.competitions ENABLE ROW LEVEL SECURITY;

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
-- Name: predictions_engine_outputs engine_outputs_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY engine_outputs_public_read ON public.predictions_engine_outputs FOR SELECT USING (true);


--
-- Name: fan_badges; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.fan_badges ENABLE ROW LEVEL SECURITY;

--
-- Name: fan_badges fan_badges_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fan_badges_public_read ON public.fan_badges FOR SELECT USING (true);


--
-- Name: fan_clubs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.fan_clubs ENABLE ROW LEVEL SECURITY;

--
-- Name: fan_clubs fan_clubs_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fan_clubs_read ON public.fan_clubs FOR SELECT USING (true);


--
-- Name: fan_earned_badges; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.fan_earned_badges ENABLE ROW LEVEL SECURITY;

--
-- Name: fan_levels; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.fan_levels ENABLE ROW LEVEL SECURITY;

--
-- Name: fan_levels fan_levels_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fan_levels_public_read ON public.fan_levels FOR SELECT USING (true);


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
-- Name: leaderboard_seasons; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.leaderboard_seasons ENABLE ROW LEVEL SECURITY;

--
-- Name: leaderboard_seasons leaderboard_seasons_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY leaderboard_seasons_public_read ON public.leaderboard_seasons FOR SELECT USING (true);


--
-- Name: marketplace_offers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.marketplace_offers ENABLE ROW LEVEL SECURITY;

--
-- Name: marketplace_offers marketplace_offers_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY marketplace_offers_public_read ON public.marketplace_offers FOR SELECT USING (true);


--
-- Name: marketplace_partners; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.marketplace_partners ENABLE ROW LEVEL SECURITY;

--
-- Name: marketplace_partners marketplace_partners_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY marketplace_partners_public_read ON public.marketplace_partners FOR SELECT USING (true);


--
-- Name: marketplace_redemptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.marketplace_redemptions ENABLE ROW LEVEL SECURITY;

--
-- Name: match_alert_dispatch_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.match_alert_dispatch_log ENABLE ROW LEVEL SECURITY;

--
-- Name: match_alert_subscriptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.match_alert_subscriptions ENABLE ROW LEVEL SECURITY;

--
-- Name: matches; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;

--
-- Name: moderation_reports; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.moderation_reports ENABLE ROW LEVEL SECURITY;

--
-- Name: news; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.news ENABLE ROW LEVEL SECURITY;

--
-- Name: notification_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notification_log ENABLE ROW LEVEL SECURITY;

--
-- Name: notification_preferences; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

--
-- Name: otp_verifications; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.otp_verifications ENABLE ROW LEVEL SECURITY;

--
-- Name: phone_presets; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.phone_presets ENABLE ROW LEVEL SECURITY;

--
-- Name: predictions_engine_outputs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.predictions_engine_outputs ENABLE ROW LEVEL SECURITY;

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
-- Name: token_rewards; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.token_rewards ENABLE ROW LEVEL SECURITY;

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
-- Name: user_predictions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_predictions ENABLE ROW LEVEL SECURITY;

--
-- Name: user_status; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_status ENABLE ROW LEVEL SECURITY;

--
-- Name: whatsapp_auth_sessions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.whatsapp_auth_sessions ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--

\unrestrict c5an2gv7aSc5fH5cvXvhoi9GzvLhM0RZbrEgbbFeHx3YR3p0SFpm2a9GIEfsBhZ
