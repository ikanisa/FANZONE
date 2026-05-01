-- ============================================================================
-- RLS Policy Performance Hardening
-- Migration: 20260501080000_rls_policy_performance_hardening.sql
-- Purpose: Remove avoidable overlapping policies and per-row auth.uid()
-- evaluations on newly deployed hospitality tables.
-- ============================================================================

BEGIN;

DROP POLICY IF EXISTS "Venue managers can manage stakes" ON public.venue_match_stakes;
DROP POLICY IF EXISTS "Venue managers can create stakes" ON public.venue_match_stakes;
CREATE POLICY "Venue managers can create stakes"
  ON public.venue_match_stakes FOR INSERT
  TO authenticated
  WITH CHECK (public.dinein_is_venue_member(venue_id, ARRAY['owner', 'manager']::public.venue_user_role[]));

DROP POLICY IF EXISTS "Venue managers can update stakes" ON public.venue_match_stakes;
CREATE POLICY "Venue managers can update stakes"
  ON public.venue_match_stakes FOR UPDATE
  TO authenticated
  USING (public.dinein_is_venue_member(venue_id, ARRAY['owner', 'manager']::public.venue_user_role[]))
  WITH CHECK (public.dinein_is_venue_member(venue_id, ARRAY['owner', 'manager']::public.venue_user_role[]));

DROP POLICY IF EXISTS "Venue managers can delete stakes" ON public.venue_match_stakes;
CREATE POLICY "Venue managers can delete stakes"
  ON public.venue_match_stakes FOR DELETE
  TO authenticated
  USING (public.dinein_is_venue_member(venue_id, ARRAY['owner', 'manager']::public.venue_user_role[]));

DROP POLICY IF EXISTS "Anyone can view venue stakes" ON public.venue_match_stakes;
DROP POLICY IF EXISTS "Users can view active/settled stakes" ON public.venue_match_stakes;
CREATE POLICY "Users can view active/settled stakes"
  ON public.venue_match_stakes FOR SELECT
  TO authenticated, anon
  USING (
    status IN ('open', 'settled')
    OR public.dinein_is_venue_member(venue_id, ARRAY['owner', 'manager']::public.venue_user_role[])
  );

DROP POLICY IF EXISTS "Users can view their own stake entries" ON public.venue_match_stake_entries;
DROP POLICY IF EXISTS "Venue managers can view all entries for their venue" ON public.venue_match_stake_entries;
DROP POLICY IF EXISTS "Users and venue managers can view stake entries" ON public.venue_match_stake_entries;
CREATE POLICY "Users and venue managers can view stake entries"
  ON public.venue_match_stake_entries FOR SELECT
  TO authenticated
  USING (
    user_id = (select auth.uid())
    OR EXISTS (
      SELECT 1
      FROM public.venue_match_stakes s
      WHERE s.id = stake_id
        AND public.dinein_is_venue_member(s.venue_id)
    )
  );

DROP POLICY IF EXISTS onboarding_requests_select_submitter ON public.onboarding_requests;
CREATE POLICY onboarding_requests_select_submitter ON public.onboarding_requests
  FOR SELECT TO authenticated
  USING (
    submitted_by = (select auth.uid())
    OR EXISTS (
      SELECT 1
      FROM public.admin_users au
      WHERE au.user_id = (select auth.uid())
        AND au.is_active = true
        AND au.role IN ('super_admin', 'admin', 'moderator')
    )
  );

DROP POLICY IF EXISTS onboarding_requests_insert_submitter ON public.onboarding_requests;
CREATE POLICY onboarding_requests_insert_submitter ON public.onboarding_requests
  FOR INSERT TO authenticated
  WITH CHECK (submitted_by = (select auth.uid()));

DROP POLICY IF EXISTS onboarding_requests_update_admin ON public.onboarding_requests;
CREATE POLICY onboarding_requests_update_admin ON public.onboarding_requests
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.admin_users au
      WHERE au.user_id = (select auth.uid())
        AND au.is_active = true
        AND au.role IN ('super_admin', 'admin', 'moderator')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.admin_users au
      WHERE au.user_id = (select auth.uid())
        AND au.is_active = true
        AND au.role IN ('super_admin', 'admin', 'moderator')
    )
  );

COMMIT;
