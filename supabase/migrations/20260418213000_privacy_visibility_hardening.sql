BEGIN;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS show_name_on_leaderboards BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS allow_fan_discovery BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN public.profiles.show_name_on_leaderboards IS
  'When true, public leaderboard surfaces may show the user display name instead of the Fan ID.';

COMMENT ON COLUMN public.profiles.allow_fan_discovery IS
  'Reserved preference for privacy-safe fan discovery if that feature is enabled later.';

CREATE OR REPLACE VIEW public.public_leaderboard AS
SELECT
  fw.user_id,
  p.fan_id,
  CASE
    WHEN coalesce(p.show_name_on_leaderboards, false) THEN coalesce(
      nullif(trim(p.display_name), ''),
      nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
      nullif(u.phone, ''),
      coalesce('Fan #' || nullif(trim(p.fan_id), ''), 'Fan')
    )
    ELSE coalesce('Fan #' || nullif(trim(p.fan_id), ''), 'Fan')
  END AS display_name,
  coalesce(fw.available_balance_fet, 0) + coalesce(fw.locked_balance_fet, 0) AS total_fet
FROM public.fet_wallets fw
LEFT JOIN public.profiles p
  ON p.id = fw.user_id OR p.user_id = fw.user_id
LEFT JOIN auth.users u
  ON u.id = fw.user_id;

GRANT SELECT ON public.public_leaderboard TO anon, authenticated;

DO $$
BEGIN
  IF to_regclass('public.leaderboard_entries') IS NOT NULL
     AND to_regclass('public.leaderboard_seasons') IS NOT NULL
     AND to_regclass('public.fan_profiles') IS NOT NULL THEN
    EXECUTE 'DROP MATERIALIZED VIEW IF EXISTS public.mv_season_leaderboard';

    EXECUTE $view$
      CREATE MATERIALIZED VIEW public.mv_season_leaderboard AS
      SELECT
        le.id,
        le.season_id,
        le.user_id,
        le.points,
        le.correct_predictions,
        le.total_predictions,
        le.exact_scores,
        le.rank,
        le.prize_fet,
        CASE
          WHEN coalesce(p.show_name_on_leaderboards, false) THEN coalesce(
            nullif(trim(fp.display_name), ''),
            coalesce('Fan #' || nullif(trim(p.fan_id), ''), 'Fan')
          )
          ELSE coalesce('Fan #' || nullif(trim(p.fan_id), ''), 'Fan')
        END AS display_name,
        fp.current_level,
        ls.name AS season_name,
        ls.season_type
      FROM public.leaderboard_entries le
      LEFT JOIN public.fan_profiles fp
        ON fp.user_id = le.user_id
      LEFT JOIN public.profiles p
        ON p.id = le.user_id OR p.user_id = le.user_id
      JOIN public.leaderboard_seasons ls
        ON ls.id = le.season_id
      WHERE ls.status = 'active'
      ORDER BY le.points DESC
    $view$;

    EXECUTE '
      CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_season_leaderboard_unique
        ON public.mv_season_leaderboard (season_id, user_id)
    ';

    EXECUTE 'GRANT SELECT ON public.mv_season_leaderboard TO anon, authenticated';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION refresh_season_leaderboard()
RETURNS void AS $$
BEGIN
  IF to_regclass('public.mv_season_leaderboard') IS NOT NULL THEN
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_season_leaderboard;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
