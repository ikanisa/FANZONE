-- ============================================================
-- 011_fan_identity.sql
-- Fan Identity System: XP, levels, badges, reputation
-- Phase 3: Engagement & Identity
-- ============================================================

BEGIN;

-- ======================
-- 1) Fan profiles — XP and level tracking
-- ======================

CREATE TABLE IF NOT EXISTS public.fan_profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  total_xp BIGINT DEFAULT 0,
  current_level INT DEFAULT 1,
  reputation_score INT DEFAULT 0,
  streak_days INT DEFAULT 0,
  longest_streak INT DEFAULT 0,
  last_active_date DATE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ======================
-- 2) Level definitions (seeded)
-- ======================

CREATE TABLE IF NOT EXISTS public.fan_levels (
  level INT PRIMARY KEY,
  name TEXT NOT NULL,
  title TEXT NOT NULL,
  min_xp BIGINT NOT NULL,
  icon_name TEXT,
  color_hex TEXT,
  perks JSONB DEFAULT '[]'
);

-- Seed levels
INSERT INTO public.fan_levels (level, name, title, min_xp, icon_name, color_hex) VALUES
  (1, 'Rookie',    'Fresh Supporter',    0,      'user',       '#A8A29E'),
  (2, 'Regular',   'Matchday Regular',   100,    'star',       '#22C55E'),
  (3, 'Committed', 'Dedicated Fan',      500,    'heart',      '#0EA5E9'),
  (4, 'Veteran',   'Seasoned Predictor', 1500,   'shield',     '#8B5CF6'),
  (5, 'Expert',    'Expert Analyst',     5000,   'award',      '#F59E0B'),
  (6, 'Elite',     'Elite Tactician',    15000,  'crown',      '#EF4444'),
  (7, 'Legend',    'FANZONE Legend',     50000,  'trophy',     '#FFD700')
ON CONFLICT (level) DO NOTHING;

-- ======================
-- 3) Badge definitions
-- ======================

CREATE TABLE IF NOT EXISTS public.fan_badges (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  category TEXT NOT NULL,     -- 'prediction', 'social', 'community', 'milestone'
  icon_name TEXT NOT NULL,
  rarity TEXT DEFAULT 'common',  -- 'common', 'rare', 'epic', 'legendary'
  xp_reward INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  criteria JSONB DEFAULT '{}'
);

-- Seed initial 20 badges
INSERT INTO public.fan_badges (id, name, description, category, icon_name, rarity, xp_reward) VALUES
  -- Prediction badges
  ('first_prediction',   'First Prediction',  'Submit your first prediction',       'prediction', 'target',     'common',    10),
  ('ten_correct',        'Sharpshooter',      'Get 10 predictions correct',         'prediction', 'crosshair',  'rare',      50),
  ('perfect_score',      'Oracle',            'Predict the exact score correctly',   'prediction', 'eye',        'epic',      100),
  ('five_win_streak',    'On Fire',           'Get 5 predictions right in a row',   'prediction', 'flame',      'rare',      75),
  -- Pool badges
  ('first_pool',         'Pool Rookie',       'Create your first prediction pool',  'prediction', 'waves',      'common',    15),
  ('pool_champion',      'Pool Champion',     'Win a prediction pool',              'prediction', 'trophy',     'rare',      50),
  ('pool_shark',         'Pool Shark',        'Win 10 prediction pools',            'prediction', 'fish',       'epic',      150),
  ('big_spender',        'Big Spender',       'Stake 1000+ FET total in pools',     'prediction', 'coins',      'rare',      75),
  -- Community badges
  ('team_supporter',     'True Supporter',    'Join a team fan community',          'community',  'heart',      'common',    20),
  ('top_contributor',    'Top Contributor',   'Contribute 500+ FET to a team',      'community',  'hand-heart', 'rare',      100),
  ('community_builder',  'Community Builder', 'Support 3 different teams',          'community',  'users',      'rare',      50),
  ('news_reader',        'News Hound',        'Read 50 team news articles',         'community',  'newspaper',  'common',    25),
  -- Milestone badges
  ('streak_7',           'Weekly Warrior',    'Maintain a 7-day login streak',      'milestone',  'calendar',   'common',    50),
  ('streak_30',          'Monthly Master',    'Maintain a 30-day login streak',     'milestone',  'calendar-check', 'rare',   250),
  ('streak_100',         'Century Club',      'Maintain a 100-day login streak',    'milestone',  'flame',      'legendary', 1000),
  ('level_5',            'Expert Status',     'Reach Level 5',                      'milestone',  'award',      'epic',      200),
  ('level_7',            'Legendary Status',  'Reach Level 7',                      'milestone',  'crown',      'legendary', 500),
  -- Special badges
  ('early_adopter',      'Early Adopter',     'Joined before public launch',        'milestone',  'rocket',     'legendary', 200),
  ('malta_derby',        'Malta Derby Fan',   'Predict a Malta derby match',        'prediction', 'flag',       'rare',      50),
  ('community_warrior',  'Community Warrior', 'Win 5 fan club prediction contests', 'community',  'swords',     'epic',      150)
ON CONFLICT (id) DO NOTHING;

-- ======================
-- 4) User earned badges
-- ======================

CREATE TABLE IF NOT EXISTS public.fan_earned_badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  badge_id TEXT NOT NULL REFERENCES public.fan_badges(id),
  earned_at TIMESTAMPTZ DEFAULT now(),
  metadata JSONB DEFAULT '{}',
  UNIQUE(user_id, badge_id)
);

-- ======================
-- 5) XP transaction log
-- ======================

CREATE TABLE IF NOT EXISTS public.fan_xp_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  xp_earned INT NOT NULL,
  reference_type TEXT,
  reference_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fan_xp_log_user ON public.fan_xp_log(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fan_earned_badges_user ON public.fan_earned_badges(user_id);

-- ======================
-- 6) RPC: award_xp (server-side)
-- ======================

CREATE OR REPLACE FUNCTION award_xp(
  p_user_id UUID,
  p_action TEXT,
  p_xp INT,
  p_reference_type TEXT DEFAULT NULL,
  p_reference_id TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_new_xp BIGINT;
  v_new_level INT;
  v_level_name TEXT;
  v_leveled_up BOOLEAN := false;
BEGIN
  -- Record XP transaction
  INSERT INTO public.fan_xp_log (user_id, action, xp_earned, reference_type, reference_id)
  VALUES (p_user_id, p_action, p_xp, p_reference_type, p_reference_id);

  -- Upsert fan profile with XP
  INSERT INTO public.fan_profiles (user_id, total_xp)
  VALUES (p_user_id, p_xp)
  ON CONFLICT (user_id)
  DO UPDATE SET total_xp = fan_profiles.total_xp + p_xp, updated_at = now();

  SELECT total_xp INTO v_new_xp FROM public.fan_profiles WHERE user_id = p_user_id;

  -- Calculate new level
  SELECT level, name INTO v_new_level, v_level_name
  FROM public.fan_levels
  WHERE min_xp <= v_new_xp
  ORDER BY level DESC LIMIT 1;

  -- Check for level-up
  IF v_new_level > (SELECT current_level FROM public.fan_profiles WHERE user_id = p_user_id) THEN
    v_leveled_up := true;
    UPDATE public.fan_profiles SET current_level = v_new_level WHERE user_id = p_user_id;
  END IF;

  RETURN jsonb_build_object(
    'total_xp', v_new_xp,
    'level', v_new_level,
    'level_name', v_level_name,
    'leveled_up', v_leveled_up
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ======================
-- 7) RLS
-- ======================

ALTER TABLE public.fan_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fan_earned_badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fan_xp_log ENABLE ROW LEVEL SECURITY;

-- Fan profiles: users read own, public read basic info via view
CREATE POLICY "Users read own fan profile"
  ON public.fan_profiles FOR SELECT USING (auth.uid() = user_id);

-- Earned badges: users see own
CREATE POLICY "Users read own earned badges"
  ON public.fan_earned_badges FOR SELECT USING (auth.uid() = user_id);

-- XP log: users see own
CREATE POLICY "Users read own XP log"
  ON public.fan_xp_log FOR SELECT USING (auth.uid() = user_id);

-- Badge definitions: public read
-- fan_badges has no RLS (public read via default)
-- fan_levels has no RLS (public read via default)

COMMIT;
