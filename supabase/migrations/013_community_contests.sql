-- ============================================================
-- 013_community_contests.sql
-- Fan Club vs Fan Club prediction contests
-- Phase 3: Engagement & Identity
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.community_contests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  match_id TEXT NOT NULL REFERENCES public.matches(id),
  home_team_id TEXT NOT NULL REFERENCES public.teams(id),
  away_team_id TEXT NOT NULL REFERENCES public.teams(id),
  status TEXT DEFAULT 'open'
    CHECK (status IN ('open', 'locked', 'settled')),
  home_fan_count INT DEFAULT 0,
  away_fan_count INT DEFAULT 0,
  home_accuracy_avg NUMERIC(5,2) DEFAULT 0,
  away_accuracy_avg NUMERIC(5,2) DEFAULT 0,
  winning_fan_club TEXT, -- team_id of winning fan club
  created_at TIMESTAMPTZ DEFAULT now(),
  settled_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.community_contest_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contest_id UUID NOT NULL REFERENCES public.community_contests(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  team_id TEXT NOT NULL REFERENCES public.teams(id),
  predicted_home_score INT NOT NULL,
  predicted_away_score INT NOT NULL,
  accuracy_score NUMERIC(5,2),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(contest_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_community_contests_match
  ON public.community_contests(match_id);
CREATE INDEX IF NOT EXISTS idx_community_contests_status
  ON public.community_contests(status) WHERE status = 'open';
CREATE INDEX IF NOT EXISTS idx_community_contest_entries_contest
  ON public.community_contest_entries(contest_id, team_id);

-- Auto-create contests for matches between supported teams
CREATE OR REPLACE FUNCTION auto_create_community_contest()
RETURNS trigger AS $$
DECLARE
  v_home_fans INT;
  v_away_fans INT;
BEGIN
  -- Only for upcoming matches with team IDs
  IF NEW.status = 'upcoming' AND NEW.home_team_id IS NOT NULL AND NEW.away_team_id IS NOT NULL THEN
    SELECT COALESCE(COUNT(*), 0) INTO v_home_fans
    FROM public.team_supporters
    WHERE team_id = NEW.home_team_id AND is_active = true;

    SELECT COALESCE(COUNT(*), 0) INTO v_away_fans
    FROM public.team_supporters
    WHERE team_id = NEW.away_team_id AND is_active = true;

    -- Only create if both teams have 5+ active fans
    IF v_home_fans >= 5 AND v_away_fans >= 5 THEN
      INSERT INTO public.community_contests (name, match_id, home_team_id, away_team_id)
      VALUES (
        NEW.home_team || ' fans vs ' || NEW.away_team || ' fans',
        NEW.id, NEW.home_team_id, NEW.away_team_id
      ) ON CONFLICT DO NOTHING;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Use CREATE OR REPLACE equivalent with DROP IF EXISTS
DROP TRIGGER IF EXISTS trg_auto_community_contest ON public.matches;
CREATE TRIGGER trg_auto_community_contest
  AFTER INSERT ON public.matches
  FOR EACH ROW EXECUTE FUNCTION auto_create_community_contest();

-- RLS
ALTER TABLE public.community_contests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_contest_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read community contests"
  ON public.community_contests FOR SELECT USING (true);
CREATE POLICY "Public read contest entries"
  ON public.community_contest_entries FOR SELECT USING (true);
-- Writes go through RPCs (not direct insert)

COMMIT;
