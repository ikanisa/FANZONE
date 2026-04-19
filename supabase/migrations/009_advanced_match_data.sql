-- ============================================================
-- 009_advanced_match_data.sql
-- Advanced match statistics: xG, possession, player stats, events
-- Phase 2: Data & Intelligence
-- ============================================================

BEGIN;

-- ======================
-- 1) Match-level advanced stats
-- ======================

CREATE TABLE IF NOT EXISTS public.match_advanced_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id TEXT NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  home_xg NUMERIC(4,2),
  away_xg NUMERIC(4,2),
  home_possession INT CHECK (home_possession BETWEEN 0 AND 100),
  away_possession INT CHECK (away_possession BETWEEN 0 AND 100),
  home_shots INT DEFAULT 0,
  away_shots INT DEFAULT 0,
  home_shots_on_target INT DEFAULT 0,
  away_shots_on_target INT DEFAULT 0,
  home_corners INT DEFAULT 0,
  away_corners INT DEFAULT 0,
  home_fouls INT DEFAULT 0,
  away_fouls INT DEFAULT 0,
  home_yellow_cards INT DEFAULT 0,
  away_yellow_cards INT DEFAULT 0,
  home_red_cards INT DEFAULT 0,
  away_red_cards INT DEFAULT 0,
  data_source TEXT NOT NULL DEFAULT 'gemini_grounded',
  refreshed_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(match_id)
);

-- ======================
-- 2) Player-level match stats
-- ======================

CREATE TABLE IF NOT EXISTS public.match_player_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id TEXT NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  team_id TEXT REFERENCES public.teams(id),
  player_name TEXT NOT NULL,
  player_number INT,
  position TEXT, -- 'GK','DEF','MID','FWD'
  minutes_played INT DEFAULT 0,
  goals INT DEFAULT 0,
  assists INT DEFAULT 0,
  yellow_cards INT DEFAULT 0,
  red_cards INT DEFAULT 0,
  shots INT DEFAULT 0,
  shots_on_target INT DEFAULT 0,
  passes_completed INT DEFAULT 0,
  pass_accuracy NUMERIC(4,1),
  rating NUMERIC(3,1), -- match rating 0.0-10.0
  is_starter BOOLEAN DEFAULT true,
  substituted_in_minute INT,
  substituted_out_minute INT,
  data_source TEXT NOT NULL DEFAULT 'gemini_grounded',
  UNIQUE(match_id, player_name, team_id)
);

-- ======================
-- 3) Match timeline events
-- ======================

CREATE TABLE IF NOT EXISTS public.match_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id TEXT NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  minute INT NOT NULL,
  event_type TEXT NOT NULL CHECK (event_type IN (
    'goal', 'own_goal', 'penalty_scored', 'penalty_missed',
    'yellow_card', 'red_card', 'substitution',
    'var_decision', 'kick_off', 'half_time', 'full_time'
  )),
  team_id TEXT REFERENCES public.teams(id),
  player_name TEXT,
  assist_player_name TEXT,
  description TEXT,
  metadata JSONB DEFAULT '{}'
);

-- ======================
-- 4) Indexes
-- ======================

CREATE INDEX IF NOT EXISTS idx_match_events_match ON public.match_events(match_id, minute);
CREATE INDEX IF NOT EXISTS idx_match_player_stats_match ON public.match_player_stats(match_id);
CREATE INDEX IF NOT EXISTS idx_match_advanced_stats_match ON public.match_advanced_stats(match_id);

-- ======================
-- 5) RLS — public read for all stats
-- ======================

ALTER TABLE public.match_advanced_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_player_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read match stats"
  ON public.match_advanced_stats FOR SELECT USING (true);
CREATE POLICY "Public read player stats"
  ON public.match_player_stats FOR SELECT USING (true);
CREATE POLICY "Public read match events"
  ON public.match_events FOR SELECT USING (true);

-- Write is service_role only (edge functions)

COMMIT;
