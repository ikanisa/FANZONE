-- Tighten table/function grants for release-blocker hardening objects.

REVOKE INSERT, UPDATE, DELETE ON TABLE
  public.venue_fet_wallets,
  public.venue_fet_wallet_transactions,
  public.game_templates,
  public.game_questions,
  public.game_sessions,
  public.game_session_questions,
  public.game_teams,
  public.game_team_members,
  public.game_answers,
  public.music_bingo_cards,
  public.music_bingo_claims,
  public.venue_screen_states
FROM anon, authenticated;

GRANT SELECT ON TABLE
  public.game_templates,
  public.game_sessions,
  public.game_teams,
  public.venue_screen_states
TO anon, authenticated;

GRANT SELECT ON TABLE
  public.venue_fet_wallets,
  public.venue_fet_wallet_transactions,
  public.game_questions,
  public.game_session_questions,
  public.game_team_members,
  public.game_answers,
  public.music_bingo_cards,
  public.music_bingo_claims
TO authenticated;

REVOKE ALL ON FUNCTION public.venue_wallet_post_transaction(uuid, text, text, bigint, text, text, text, text, text, jsonb, uuid, uuid, text, uuid)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.venue_wallet_post_transaction(uuid, text, text, bigint, text, text, text, text, text, jsonb, uuid, uuid, text, uuid)
TO service_role;

REVOKE ALL ON FUNCTION public.credit_fet_for_order(uuid, text)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.credit_fet_for_order(uuid, text)
TO service_role;

REVOKE ALL ON FUNCTION public.settle_match_pool(uuid)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.settle_match_pool(uuid)
TO service_role;

REVOKE ALL ON FUNCTION public.user_has_qualifying_order(uuid, uuid, timestamptz)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.user_has_qualifying_order(uuid, uuid, timestamptz)
TO service_role;

REVOKE ALL ON FUNCTION public.pool_scheduled_start(uuid)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pool_scheduled_start(uuid)
TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.request_venue_fet_top_up(uuid, bigint, text)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_venue_fet_top_up(uuid, bigint, text)
TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_venue_fet_wallet(uuid)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_venue_fet_wallet(uuid)
TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.create_pool(text, text, uuid, uuid, text, bigint, bigint, bigint, jsonb, boolean)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_pool(text, text, uuid, uuid, text, bigint, bigint, bigint, jsonb, boolean)
TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.create_match_pool(text, public.match_pool_scope, text, uuid, text, bigint, bigint, bigint, boolean)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_match_pool(text, public.match_pool_scope, text, uuid, text, bigint, bigint, bigint, boolean)
TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.create_venue_official_match_pool(uuid, text, text, bigint, bigint, bigint, bigint, bigint)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_venue_official_match_pool(uuid, text, text, bigint, bigint, bigint, bigint, bigint)
TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.join_match_pool(uuid, uuid, bigint, text)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.join_match_pool(uuid, uuid, bigint, text)
TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.venue_settle_match_pool(uuid)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.venue_settle_match_pool(uuid)
TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.create_game_session(uuid, text, timestamptz, bigint)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_game_session(uuid, text, timestamptz, bigint)
TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.create_game_team(uuid, text)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_game_team(uuid, text)
TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.join_game_team(uuid)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.join_game_team(uuid)
TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.start_game_session(uuid)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_game_session(uuid)
TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_game_session_question(uuid, integer)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_game_session_question(uuid, integer)
TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.submit_game_answer(uuid, uuid, uuid, text)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_game_answer(uuid, uuid, uuid, text)
TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.submit_music_bingo_claim(uuid, jsonb)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_music_bingo_claim(uuid, jsonb)
TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.verify_music_bingo_claim(uuid, boolean, bigint, text)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.verify_music_bingo_claim(uuid, boolean, bigint, text)
TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.set_venue_screen_state(uuid, text, uuid, uuid, jsonb)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_venue_screen_state(uuid, text, uuid, uuid, jsonb)
TO authenticated, service_role;
