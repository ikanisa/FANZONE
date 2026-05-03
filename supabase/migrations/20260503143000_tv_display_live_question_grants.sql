-- Allow the public venue TV display to read live game prompts without exposing
-- answer keys or granting host/player mutation privileges.

REVOKE ALL ON FUNCTION public.get_game_session_question(uuid, integer)
FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_game_session_question(uuid, integer)
TO anon, authenticated, service_role;

COMMENT ON FUNCTION public.get_game_session_question(uuid, integer) IS
  'TV-safe live-question read: returns prompt/options only, never correct answers. The function filters to live sessions unless the caller is venue staff/admin/player.';

-- The TV app embeds game_team_members only to count members. RLS still denies
-- anon rows because no anon policy exists, but the table grant prevents a
-- permission error in PostgREST embedded selects.
GRANT SELECT ON TABLE public.game_team_members TO anon;
