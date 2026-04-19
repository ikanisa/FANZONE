-- ============================================================
-- 012_seasonal_leaderboards.sql
-- Season-scoped leaderboards and competitions
-- Phase 3: Engagement & Identity
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.leaderboard_seasons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  season_type TEXT NOT NULL, -- 'monthly', 'seasonal', 'competition', 'special_event'
  competition_id TEXT REFERENCES public.competitions(id),
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ NOT NULL,
  status TEXT DEFAULT 'upcoming'
    CHECK (status IN ('upcoming', 'active', 'completed', 'archived')),
  prize_pool_fet BIGINT DEFAULT 0,
  rules JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.leaderboard_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  season_id UUID NOT NULL REFERENCES public.leaderboard_seasons(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  points INT DEFAULT 0,
  correct_predictions INT DEFAULT 0,
  total_predictions INT DEFAULT 0,
  exact_scores INT DEFAULT 0,
  rank INT,
  prize_fet BIGINT DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(season_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_leaderboard_entries_season
  ON public.leaderboard_entries(season_id, points DESC);
CREATE INDEX IF NOT EXISTS idx_leaderboard_seasons_active
  ON public.leaderboard_seasons(status) WHERE status = 'active';

-- Materialized view for fast leaderboard reads
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_season_leaderboard AS
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
  fp.display_name,
  fp.current_level,
  ls.name AS season_name,
  ls.season_type
FROM public.leaderboard_entries le
LEFT JOIN public.fan_profiles fp ON fp.user_id = le.user_id
JOIN public.leaderboard_seasons ls ON ls.id = le.season_id
WHERE ls.status = 'active'
ORDER BY le.points DESC;

-- Refresh function (call after prediction settlement)
CREATE OR REPLACE FUNCTION refresh_season_leaderboard()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_season_leaderboard;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS
ALTER TABLE public.leaderboard_seasons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaderboard_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read seasons"
  ON public.leaderboard_seasons FOR SELECT USING (true);
CREATE POLICY "Public read leaderboard entries"
  ON public.leaderboard_entries FOR SELECT USING (true);

COMMIT;
