-- Targeted Supabase advisor WARN cleanup for policies touched by the release
-- hardening work and fan-profile flow. The broader legacy warning set remains
-- documented because those policies span unrelated modules.

DROP POLICY IF EXISTS "Users can read own favorite teams"
  ON public.user_favorite_teams;
DROP POLICY IF EXISTS "Users can insert own favorite teams"
  ON public.user_favorite_teams;
DROP POLICY IF EXISTS "Users can update own favorite teams"
  ON public.user_favorite_teams;
DROP POLICY IF EXISTS "Users can delete own favorite teams"
  ON public.user_favorite_teams;

CREATE POLICY "Users can read own favorite teams"
  ON public.user_favorite_teams
  FOR SELECT
  USING ((select auth.uid()) = user_id);

CREATE POLICY "Users can insert own favorite teams"
  ON public.user_favorite_teams
  FOR INSERT
  WITH CHECK ((select auth.uid()) = user_id);

CREATE POLICY "Users can update own favorite teams"
  ON public.user_favorite_teams
  FOR UPDATE
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

CREATE POLICY "Users can delete own favorite teams"
  ON public.user_favorite_teams
  FOR DELETE
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS game_answers_select_restricted
  ON public.game_answers;
CREATE POLICY game_answers_select_restricted
  ON public.game_answers
  FOR SELECT
  USING (
    user_id = (select auth.uid())
    OR (select sports_bar_is_admin())
    OR EXISTS (
      SELECT 1
      FROM public.game_sessions s
      WHERE s.id = game_answers.session_id
        AND public.venue_user_has_role(s.venue_id)
    )
  );

DROP POLICY IF EXISTS game_team_members_select_participants
  ON public.game_team_members;
CREATE POLICY game_team_members_select_participants
  ON public.game_team_members
  FOR SELECT
  USING (
    user_id = (select auth.uid())
    OR (select sports_bar_is_admin())
    OR EXISTS (
      SELECT 1
      FROM public.game_sessions s
      WHERE s.id = game_team_members.session_id
        AND public.venue_user_has_role(s.venue_id)
    )
  );

DROP POLICY IF EXISTS music_bingo_cards_select_team
  ON public.music_bingo_cards;
CREATE POLICY music_bingo_cards_select_team
  ON public.music_bingo_cards
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.game_team_members m
      WHERE m.team_id = music_bingo_cards.team_id
        AND m.user_id = (select auth.uid())
    )
    OR (select sports_bar_is_admin())
    OR EXISTS (
      SELECT 1
      FROM public.game_sessions s
      WHERE s.id = music_bingo_cards.session_id
        AND public.venue_user_has_role(s.venue_id)
    )
  );

DROP POLICY IF EXISTS music_bingo_claims_select_team
  ON public.music_bingo_claims;
CREATE POLICY music_bingo_claims_select_team
  ON public.music_bingo_claims
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.game_team_members m
      WHERE m.team_id = music_bingo_claims.team_id
        AND m.user_id = (select auth.uid())
    )
    OR (select sports_bar_is_admin())
    OR EXISTS (
      SELECT 1
      FROM public.game_sessions s
      WHERE s.id = music_bingo_claims.session_id
        AND public.venue_user_has_role(s.venue_id)
    )
  );
