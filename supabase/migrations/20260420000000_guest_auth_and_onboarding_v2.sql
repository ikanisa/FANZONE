-- ============================================================
-- 20260420000000_guest_auth_and_onboarding_v2.sql
-- Guest/anonymous auth support + WhatsApp Cloud API OTP pipeline
--
-- 1. Adds is_anonymous and auth_method tracking to profiles
-- 2. Creates otp_verifications table for custom WhatsApp OTP
-- 3. Creates find_auth_user_by_phone RPC for Edge Function user lookup
-- 4. Creates merge_anonymous_to_authenticated RPC for guest upgrade
-- ============================================================

BEGIN;

-- -----------------------------------------------------------------
-- 1. Add anonymous-auth tracking columns to profiles
-- -----------------------------------------------------------------

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_anonymous boolean NOT NULL DEFAULT false;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS auth_method text NOT NULL DEFAULT 'phone';

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS upgraded_from_anonymous_id uuid;

CREATE INDEX IF NOT EXISTS idx_profiles_is_anonymous
  ON public.profiles (is_anonymous)
  WHERE is_anonymous = true;

-- -----------------------------------------------------------------
-- 2. OTP verifications table for WhatsApp Cloud API pipeline
-- -----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.otp_verifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone text NOT NULL,
  otp_hash text NOT NULL,
  expires_at timestamptz NOT NULL,
  verified boolean NOT NULL DEFAULT false,
  attempts integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_otp_verifications_phone_active
  ON public.otp_verifications (phone, expires_at DESC)
  WHERE verified = false;

-- Cleanup support for verified or expired OTP records.
CREATE INDEX IF NOT EXISTS idx_otp_verifications_cleanup
  ON public.otp_verifications (verified, expires_at, created_at);

ALTER TABLE public.otp_verifications ENABLE ROW LEVEL SECURITY;

-- Only service_role can access OTP verifications (Edge Functions)
-- No RLS policy for authenticated/anon — this table is admin-only.

-- -----------------------------------------------------------------
-- 3. Find auth user by phone (SECURITY DEFINER for Edge Function)
-- -----------------------------------------------------------------

DROP FUNCTION IF EXISTS public.find_auth_user_by_phone(text);

CREATE FUNCTION public.find_auth_user_by_phone(p_phone text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public
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

REVOKE ALL ON FUNCTION public.find_auth_user_by_phone(text) FROM PUBLIC;
-- Only service role should call this (Edge Functions use service role)

-- -----------------------------------------------------------------
-- 4. Merge anonymous user data to authenticated user
-- -----------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.merge_anonymous_to_authenticated(
  p_anon_id uuid,
  p_auth_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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

REVOKE ALL ON FUNCTION public.merge_anonymous_to_authenticated(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.merge_anonymous_to_authenticated(uuid, uuid) TO authenticated;

COMMIT;
