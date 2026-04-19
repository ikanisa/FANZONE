-- ============================================================
-- 20260420000000_guest_auth_and_onboarding_v2.sql
-- Guest/anonymous auth support + onboarding v2 schema changes
--
-- Adds is_anonymous and auth_method tracking to profiles,
-- enables anonymous user → authenticated user data merging,
-- and ensures RLS policies allow anonymous users appropriate
-- read/write access during onboarding.
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

-- Index for finding anonymous profiles for cleanup jobs
CREATE INDEX IF NOT EXISTS idx_profiles_is_anonymous
  ON public.profiles (is_anonymous)
  WHERE is_anonymous = true;

-- -----------------------------------------------------------------
-- 2. Merge RPC: transfer anonymous user data to authenticated user
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
  -- Validate inputs
  IF p_anon_id IS NULL OR p_auth_id IS NULL THEN
    RAISE EXCEPTION 'Both anonymous and authenticated user IDs are required';
  END IF;

  IF p_anon_id = p_auth_id THEN
    RAISE EXCEPTION 'Anonymous and authenticated user IDs must be different';
  END IF;

  -- Transfer favorite teams that don't already exist for authenticated user
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
      WHERE existing.user_id = p_auth_id
        AND existing.team_id = uft.team_id
    );

  -- Transfer followed teams that don't already exist
  INSERT INTO public.user_followed_teams (user_id, team_id, created_at)
  SELECT p_auth_id, uft.team_id, uft.created_at
  FROM public.user_followed_teams uft
  WHERE uft.user_id = p_anon_id
    AND NOT EXISTS (
      SELECT 1 FROM public.user_followed_teams existing
      WHERE existing.user_id = p_auth_id
        AND existing.team_id = uft.team_id
    );

  -- Transfer followed competitions that don't already exist
  INSERT INTO public.user_followed_competitions (user_id, competition_id, created_at)
  SELECT p_auth_id, ufc.competition_id, ufc.created_at
  FROM public.user_followed_competitions ufc
  WHERE ufc.user_id = p_anon_id
    AND NOT EXISTS (
      SELECT 1 FROM public.user_followed_competitions existing
      WHERE existing.user_id = p_auth_id
        AND existing.competition_id = ufc.competition_id
    );

  -- Copy onboarding fields from anonymous profile to authenticated profile
  -- only if authenticated profile doesn't already have them set
  UPDATE public.profiles auth_p
  SET
    favorite_team_id = COALESCE(auth_p.favorite_team_id, anon_p.favorite_team_id),
    favorite_team_name = COALESCE(auth_p.favorite_team_name, anon_p.favorite_team_name),
    active_country = COALESCE(auth_p.active_country, anon_p.active_country),
    country_code = COALESCE(auth_p.country_code, anon_p.country_code),
    region = COALESCE(auth_p.region, anon_p.region),
    onboarding_completed = true,
    upgraded_from_anonymous_id = p_anon_id,
    updated_at = now()
  FROM public.profiles anon_p
  WHERE auth_p.id = p_auth_id
    AND anon_p.id = p_anon_id;

  -- Clean up anonymous user data
  DELETE FROM public.user_favorite_teams WHERE user_id = p_anon_id;
  DELETE FROM public.user_followed_teams WHERE user_id = p_anon_id;
  DELETE FROM public.user_followed_competitions WHERE user_id = p_anon_id;
  DELETE FROM public.profiles WHERE id = p_anon_id;
END;
$$;

REVOKE ALL ON FUNCTION public.merge_anonymous_to_authenticated(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.merge_anonymous_to_authenticated(uuid, uuid) TO authenticated;

-- -----------------------------------------------------------------
-- 3. Ensure anonymous users can manage their own profiles
--    The existing RLS policies use `TO authenticated` which also
--    covers anonymous users (they are authenticated with anon token).
--    Supabase anonymous users still receive the `authenticated` role,
--    so existing policies already apply. No new policies needed.
-- -----------------------------------------------------------------

-- -----------------------------------------------------------------
-- 4. Ensure public-read tables are accessible to anon role
--    (matches, competitions, teams, standings are already public-read
--    via existing policies with `USING (true)`)
-- -----------------------------------------------------------------

-- Grant anon role SELECT on profiles for public leaderboard view
-- (profiles are already granted to authenticated, which includes anonymous)

COMMIT;
