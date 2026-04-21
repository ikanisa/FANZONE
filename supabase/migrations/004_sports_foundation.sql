-- ============================================================
-- 004_sports_foundation.sql
-- Foundation tables for matches, teams, competitions, and live events.
-- Aligns with Flutter app definitions and Edge Function inserts.
-- ============================================================

BEGIN;

-- 1) competitions table
CREATE TABLE IF NOT EXISTS public.competitions (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  short_name TEXT,
  country TEXT,
  tier INT,
  data_source TEXT DEFAULT 'manual',
  status TEXT DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2) teams table
CREATE TABLE IF NOT EXISTS public.teams (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  short_name TEXT,
  country TEXT,
  competition_ids TEXT[],
  logo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3) matches table (formerly conceptualized as fixtures)
CREATE TABLE IF NOT EXISTS public.matches (
  id TEXT PRIMARY KEY,
  competition_id TEXT REFERENCES public.competitions(id) ON DELETE CASCADE,
  season TEXT,
  round TEXT,
  match_group TEXT,
  date TIMESTAMPTZ NOT NULL,
  kickoff_time TEXT,
  home_team_id TEXT REFERENCES public.teams(id),
  away_team_id TEXT REFERENCES public.teams(id),
  home_team TEXT NOT NULL,
  away_team TEXT NOT NULL,
  ft_home INT,
  ft_away INT,
  ht_home INT,
  ht_away INT,
  et_home INT,
  et_away INT,
  status TEXT DEFAULT 'upcoming',
  venue TEXT,
  data_source TEXT,
  source_url TEXT,
  home_logo_url TEXT,
  away_logo_url TEXT,
  
  -- Betting odds multipliers populated by gemini-sports-data edge function
  home_multiplier NUMERIC(10,2),
  draw_multiplier NUMERIC(10,2),
  away_multiplier NUMERIC(10,2),
  
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 4) live_match_events table
CREATE TABLE IF NOT EXISTS public.live_match_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id TEXT REFERENCES public.matches(id) ON DELETE CASCADE,
  minute INT,
  event_type TEXT, -- 'GOAL', 'YELLOW_CARD', 'RED_CARD', 'SUBSTITUTION'
  team TEXT,
  player TEXT,
  details TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- competition_standings is already defined as a remote view in the db

-- 6) news table (referenced in flutter app)
CREATE TABLE IF NOT EXISTS public.news (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  summary TEXT,
  content TEXT,
  image_url TEXT,
  source_url TEXT,
  published_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ======================
-- SECURITY POLICIES (Row Level Security)
-- ======================

ALTER TABLE public.competitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_match_events ENABLE ROW LEVEL SECURITY;
-- competition_standings is a view, no direct RLS on it required here
ALTER TABLE public.news ENABLE ROW LEVEL SECURITY;

-- Allow public read access to all sports data tables
CREATE POLICY "Public read access for competitions" ON public.competitions FOR SELECT USING (true);
CREATE POLICY "Public read access for teams" ON public.teams FOR SELECT USING (true);
CREATE POLICY "Public read access for matches" ON public.matches FOR SELECT USING (true);
CREATE POLICY "Public read access for live events" ON public.live_match_events FOR SELECT USING (true);
CREATE POLICY "Public read access for news" ON public.news FOR SELECT USING (true);

-- Insert/Update is restricted to Service Role (which bypasses RLS) or Admin (if defined)
-- The gemini-sports-data edge function uses Service Role Key, natively bypassing these policies.

COMMIT;
