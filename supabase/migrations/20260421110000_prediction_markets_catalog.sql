BEGIN;

-- ============================================================
-- 20260421110000_prediction_markets_catalog.sql
--
-- Comprehensive prediction markets system for FANZONE.
-- Covers 2026 World Cup + Global & African League markets.
--
-- Contents:
--   1. prediction_market_categories (12 categories)
--   2. prediction_market_types (~150 market types)
--   3. prediction_market_league_availability
--   4. tournament_outright_markets
--   5. tournament_outright_entries
--   6. Widen prediction_slip_selections.market constraint
--   7. Seed data: categories, market types, availability, WC outrights
--   8. RPCs: get_market_catalog, get_outright_markets,
--           submit_outright_prediction, admin_settle_outright_market,
--           admin_manage_market_type
--   9. Updated submit_prediction_slip to accept any market type
-- ============================================================


-- ═══════════════════════════════════════════════════════════════
-- 1. PREDICTION MARKET CATEGORIES
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.prediction_market_categories (
  id            TEXT PRIMARY KEY,
  name          TEXT NOT NULL,
  description   TEXT DEFAULT '',
  display_order INT NOT NULL DEFAULT 0,
  icon_name     TEXT DEFAULT 'sports_soccer',
  is_active     BOOLEAN NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.prediction_market_categories ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "market_categories_public_read"
    ON public.prediction_market_categories FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

REVOKE INSERT, UPDATE, DELETE ON public.prediction_market_categories FROM anon, authenticated;
GRANT SELECT ON public.prediction_market_categories TO anon, authenticated;


-- ═══════════════════════════════════════════════════════════════
-- 2. PREDICTION MARKET TYPES (master catalog)
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.prediction_market_types (
  id               TEXT PRIMARY KEY,
  category_id      TEXT NOT NULL REFERENCES public.prediction_market_categories(id),
  name             TEXT NOT NULL,
  description      TEXT DEFAULT '',
  example_selection TEXT DEFAULT '',
  bet_type         TEXT NOT NULL DEFAULT 'pre_match'
                     CHECK (bet_type IN ('outright', 'pre_match', 'pre_match_live', 'live')),
  base_fet         INT NOT NULL DEFAULT 50,
  scope            TEXT NOT NULL DEFAULT 'match'
                     CHECK (scope IN ('tournament', 'league', 'match', 'player')),
  settlement_type  TEXT NOT NULL DEFAULT 'manual'
                     CHECK (settlement_type IN ('auto', 'manual', 'semi_auto')),
  is_active        BOOLEAN NOT NULL DEFAULT true,
  display_order    INT NOT NULL DEFAULT 0,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_market_types_category
  ON public.prediction_market_types (category_id, display_order);

CREATE INDEX IF NOT EXISTS idx_market_types_scope
  ON public.prediction_market_types (scope, bet_type);

ALTER TABLE public.prediction_market_types ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "market_types_public_read"
    ON public.prediction_market_types FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

REVOKE INSERT, UPDATE, DELETE ON public.prediction_market_types FROM anon, authenticated;
GRANT SELECT ON public.prediction_market_types TO anon, authenticated;


-- ═══════════════════════════════════════════════════════════════
-- 3. LEAGUE AVAILABILITY (which markets are available per league)
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.prediction_market_league_availability (
  market_type_id TEXT NOT NULL REFERENCES public.prediction_market_types(id) ON DELETE CASCADE,
  competition_id TEXT NOT NULL REFERENCES public.competitions(id) ON DELETE CASCADE,
  is_available   BOOLEAN NOT NULL DEFAULT true,
  PRIMARY KEY (market_type_id, competition_id)
);

ALTER TABLE public.prediction_market_league_availability ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "market_availability_public_read"
    ON public.prediction_market_league_availability FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

REVOKE INSERT, UPDATE, DELETE ON public.prediction_market_league_availability FROM anon, authenticated;
GRANT SELECT ON public.prediction_market_league_availability TO anon, authenticated;


-- ═══════════════════════════════════════════════════════════════
-- 4. TOURNAMENT OUTRIGHT MARKETS
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.tournament_outright_markets (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  market_type_id  TEXT NOT NULL REFERENCES public.prediction_market_types(id),
  tournament_id   TEXT NOT NULL,
  competition_id  TEXT REFERENCES public.competitions(id),
  name            TEXT NOT NULL,
  description     TEXT DEFAULT '',
  status          TEXT NOT NULL DEFAULT 'open'
                    CHECK (status IN ('open', 'locked', 'settled', 'cancelled')),
  base_fet        INT NOT NULL DEFAULT 50,
  settlement_value TEXT,
  settled_at      TIMESTAMPTZ,
  lock_at         TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_outright_markets_tournament
  ON public.tournament_outright_markets (tournament_id, status);

CREATE INDEX IF NOT EXISTS idx_outright_markets_type
  ON public.tournament_outright_markets (market_type_id);

ALTER TABLE public.tournament_outright_markets ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "outright_markets_public_read"
    ON public.tournament_outright_markets FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

REVOKE INSERT, UPDATE, DELETE ON public.tournament_outright_markets FROM anon, authenticated;
GRANT SELECT ON public.tournament_outright_markets TO anon, authenticated;


-- ═══════════════════════════════════════════════════════════════
-- 5. TOURNAMENT OUTRIGHT ENTRIES (user picks)
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.tournament_outright_entries (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outright_market_id  UUID NOT NULL REFERENCES public.tournament_outright_markets(id) ON DELETE CASCADE,
  user_id             UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  selection           TEXT NOT NULL,
  stake_fet           BIGINT NOT NULL DEFAULT 0,
  status              TEXT NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active', 'won', 'lost', 'refunded')),
  payout_fet          BIGINT NOT NULL DEFAULT 0,
  submitted_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  settled_at          TIMESTAMPTZ,
  UNIQUE (outright_market_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_outright_entries_user
  ON public.tournament_outright_entries (user_id, submitted_at DESC);

CREATE INDEX IF NOT EXISTS idx_outright_entries_market
  ON public.tournament_outright_entries (outright_market_id, status);

ALTER TABLE public.tournament_outright_entries ENABLE ROW LEVEL SECURITY;

-- Users read own entries
DO $$ BEGIN
  CREATE POLICY "outright_entries_users_read_own"
    ON public.tournament_outright_entries FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Users insert own entries (controlled via RPC)
DO $$ BEGIN
  CREATE POLICY "outright_entries_users_insert_own"
    ON public.tournament_outright_entries FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

GRANT SELECT, INSERT ON public.tournament_outright_entries TO authenticated;


-- ═══════════════════════════════════════════════════════════════
-- 6. RESTORE + WIDEN prediction_slip_selections
--    An earlier cleanup migration dropped the child table because it
--    was empty, but the free-slip flow still depends on it for submit
--    and settlement. Recreate the canonical table if needed, then
--    widen the market constraint and add market_type metadata.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.prediction_slip_selections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slip_id UUID NOT NULL REFERENCES public.prediction_slips(id) ON DELETE CASCADE,
  match_id TEXT NOT NULL,
  match_name TEXT NOT NULL DEFAULT '',
  market TEXT NOT NULL DEFAULT 'match_result'
    CHECK (market IN ('match_result', 'exact_score', 'over_under', 'btts')),
  selection TEXT NOT NULL,
  potential_earn_fet BIGINT NOT NULL DEFAULT 0,
  result TEXT DEFAULT 'pending'
    CHECK (result IN ('pending', 'won', 'lost', 'void')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_prediction_slip_selections_slip
  ON public.prediction_slip_selections (slip_id);

CREATE INDEX IF NOT EXISTS idx_prediction_slip_selections_match
  ON public.prediction_slip_selections (match_id);

ALTER TABLE public.prediction_slip_selections ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'prediction_slip_selections'
      AND policyname = 'Users read own slip selections'
  ) THEN
    CREATE POLICY "Users read own slip selections"
      ON public.prediction_slip_selections FOR SELECT
      USING (
        EXISTS (
          SELECT 1
          FROM public.prediction_slips
          WHERE public.prediction_slips.id = public.prediction_slip_selections.slip_id
            AND public.prediction_slips.user_id = auth.uid()
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'prediction_slip_selections'
      AND policyname = 'Users insert own slip selections'
  ) THEN
    CREATE POLICY "Users insert own slip selections"
      ON public.prediction_slip_selections FOR INSERT
      WITH CHECK (
        EXISTS (
          SELECT 1
          FROM public.prediction_slips
          WHERE public.prediction_slips.id = public.prediction_slip_selections.slip_id
            AND public.prediction_slips.user_id = auth.uid()
        )
      );
  END IF;
END $$;

DO $$
DECLARE
  v_constraint_name TEXT;
  v_table_exists BOOLEAN;
BEGIN
  -- Check if table exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'prediction_slip_selections'
  ) INTO v_table_exists;

  IF NOT v_table_exists THEN
    RAISE NOTICE 'prediction_slip_selections does not exist — skipping constraint/column changes';
    RETURN;
  END IF;

  -- Drop the old CHECK constraint (name may vary)
  SELECT conname INTO v_constraint_name
  FROM pg_constraint
  WHERE conrelid = 'public.prediction_slip_selections'::regclass
    AND contype = 'c'
    AND pg_get_constraintdef(oid) ILIKE '%market%';

  IF v_constraint_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.prediction_slip_selections DROP CONSTRAINT %I', v_constraint_name);
  END IF;

  -- Add new columns
  EXECUTE 'ALTER TABLE public.prediction_slip_selections ADD COLUMN IF NOT EXISTS market_type_id TEXT REFERENCES public.prediction_market_types(id)';
  EXECUTE 'ALTER TABLE public.prediction_slip_selections ADD COLUMN IF NOT EXISTS base_fet INT DEFAULT 50';
  EXECUTE 'CREATE INDEX IF NOT EXISTS idx_slip_selections_market_type ON public.prediction_slip_selections (market_type_id)';
END $$;


-- ═══════════════════════════════════════════════════════════════
-- 7. SEED DATA
-- ═══════════════════════════════════════════════════════════════

-- ---------------------------------------------------------------
-- 7a. Market Categories (12)
-- ---------------------------------------------------------------

INSERT INTO public.prediction_market_categories (id, name, description, display_order, icon_name) VALUES
  ('outright',       'Outright / Tournament', 'Tournament and league-level futures', 1,  'emoji_events'),
  ('match_betting',  'Match Betting',         'Match result and qualification markets', 2, 'sports_soccer'),
  ('goals',          'Goals Betting',         'Goals totals, both teams to score, correct score', 3, 'scoreboard'),
  ('handicap',       'Handicap Betting',      'Asian and European handicap markets', 4, 'swap_horiz'),
  ('goalscorer',     'Goalscorer Markets',    'First, anytime, last goalscorer predictions', 5, 'person'),
  ('match_props',    'Match Props',           'Winning margin, clean sheet, comeback markets', 6, 'analytics'),
  ('corners',        'Corners Betting',       'Corner kick totals and team corners', 7, 'flag'),
  ('cards',          'Cards Betting',         'Booking and card-related markets', 8, 'style'),
  ('player_props',   'Player Props',          'Individual player performance markets', 9, 'person_pin'),
  ('match_events',   'Match Events',          'Penalty, VAR, and in-match event markets', 10, 'event'),
  ('live',           'In-Play / Live',        'Live betting markets during the match', 11, 'live_tv'),
  ('combo',          'Combo Markets',         'Combined multi-outcome markets', 12, 'merge_type')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  display_order = EXCLUDED.display_order,
  icon_name = EXCLUDED.icon_name;


-- ---------------------------------------------------------------
-- 7b. Market Types — Outright / Tournament (18 WC + 5 League)
-- ---------------------------------------------------------------

INSERT INTO public.prediction_market_types (id, category_id, name, description, example_selection, bet_type, base_fet, scope, settlement_type, display_order) VALUES
  -- World Cup Tournament Outrights
  ('tournament_winner',          'outright', 'Tournament Winner',        'Predict the overall winner of the tournament',          'Brazil',            'outright', 500, 'tournament', 'manual', 1),
  ('tournament_runner_up',       'outright', 'Tournament Runner-Up',     'Predict the team that will lose in the final',          'England',           'outright', 375, 'tournament', 'manual', 2),
  ('to_reach_final',             'outright', 'To Reach the Final',       'Predict if a specific team will make it to the final',  'France',            'outright', 250, 'tournament', 'manual', 3),
  ('to_reach_semi_finals',       'outright', 'To Reach the Semi-Finals', 'Predict if a team will reach the final four',           'Argentina',         'outright', 200, 'tournament', 'manual', 4),
  ('to_reach_quarter_finals',    'outright', 'To Reach the Quarter-Finals', 'Predict if a team will reach the final eight',       'USA',               'outright', 150, 'tournament', 'manual', 5),
  ('golden_boot_winner',         'outright', 'Golden Boot Winner',       'Predict the top goalscorer of the tournament',          'Kylian Mbappe',     'outright', 250, 'tournament', 'manual', 6),
  ('golden_ball_winner',         'outright', 'Golden Ball Winner',       'Predict the best player of the tournament',             'Lionel Messi',      'outright', 250, 'tournament', 'manual', 7),
  ('golden_glove_winner',        'outright', 'Golden Glove Winner',      'Predict the best goalkeeper of the tournament',         'Emiliano Martinez', 'outright', 250, 'tournament', 'manual', 8),
  ('best_young_player',          'outright', 'Best Young Player',        'Predict the best young player of the tournament',       'Jude Bellingham',   'outright', 250, 'tournament', 'manual', 9),
  ('group_winner',               'outright', 'Group Winner',             'Predict the winner of a specific group',                'Mexico',            'outright', 125, 'tournament', 'manual', 10),
  ('group_to_qualify',           'outright', 'Group To Qualify (Yes/No)', 'Predict if a specific team will advance from their group', 'Canada - Yes',  'outright', 100, 'tournament', 'manual', 11),
  ('total_tournament_goals',     'outright', 'Total Tournament Goals',   'Predict if total goals in all matches will be over/under a line', 'Over 170.5', 'outright', 250, 'tournament', 'manual', 12),
  ('total_tournament_red_cards', 'outright', 'Total Tournament Red Cards', 'Predict total red cards shown in the entire tournament', 'Under 15.5',    'outright', 150, 'tournament', 'manual', 13),
  ('winning_continent',          'outright', 'Winning Continent',        'Predict which continent the winning team will be from', 'UEFA',              'outright', 200, 'tournament', 'manual', 14),
  ('highest_scoring_team',       'outright', 'Highest Scoring Team',     'Predict the team that scores the most goals overall',   'Brazil',            'outright', 200, 'tournament', 'manual', 15),
  ('lowest_scoring_team',        'outright', 'Lowest Scoring Team',      'Predict the team that scores the fewest goals overall', 'Saudi Arabia',      'outright', 200, 'tournament', 'manual', 16),

  -- League Outrights
  ('league_winner',              'outright', 'League Winner',            'Predict the overall champion of the league season',     'Arsenal',           'outright', 500, 'league', 'manual', 17),
  ('relegation',                 'outright', 'Relegation',               'Predict a team to be relegated',                        'Luton Town',        'outright', 375, 'league', 'manual', 18),
  ('top_goalscorer',             'outright', 'Top Goalscorer',           'Predict the player with most league goals',             'Haaland',           'outright', 250, 'league', 'manual', 19),
  ('top_4_finish',               'outright', 'Top 4 Finish',             'Predict a team to finish in the top 4',                 'Aston Villa',       'outright', 250, 'league', 'manual', 20),
  ('most_assists',               'outright', 'Most Assists',             'Predict the player with most assists',                  'De Bruyne',         'outright', 250, 'league', 'manual', 21)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  base_fet = EXCLUDED.base_fet,
  scope = EXCLUDED.scope;


-- ---------------------------------------------------------------
-- 7c. Market Types — Match Betting (9)
-- ---------------------------------------------------------------

INSERT INTO public.prediction_market_types (id, category_id, name, description, example_selection, bet_type, base_fet, scope, settlement_type, display_order) VALUES
  ('match_result',          'match_betting', 'Match Result (1X2)',       'Predict the outcome of the match at the end of normal time', '1 (Home Team Win)',  'pre_match', 50,  'match', 'auto',  1),
  ('double_chance',         'match_betting', 'Double Chance',            'Bet on two of the three possible match outcomes',            '1X (Home Win or Draw)', 'pre_match', 50, 'match', 'auto', 2),
  ('draw_no_bet',           'match_betting', 'Draw No Bet',              'Bet on a team to win but stakes are refunded if the match ends in a draw', 'Away Team', 'pre_match', 50, 'match', 'auto', 3),
  ('half_time_result',      'match_betting', 'Half-Time Result (1X2)',   'Predict the result at half-time',                           'Draw',               'pre_match', 50,  'match', 'auto',  4),
  ('half_time_full_time',   'match_betting', 'Half-Time/Full-Time',      'Predict the result at half-time and the result at full-time', 'Draw/Home Team',    'pre_match', 100, 'match', 'semi_auto', 5),
  ('to_qualify',            'match_betting', 'To Qualify / Advance',     'Predict which team will advance to the next round (includes ET/Pens)', 'Team B',  'pre_match', 75,  'match', 'manual', 6),
  ('method_of_victory',     'match_betting', 'Method of Victory',        'Predict how a team will win a knockout match',              'Team A in Extra Time', 'pre_match', 125, 'match', 'manual', 7),
  ('match_to_extra_time',   'match_betting', 'Match to Go to Extra Time', 'Predict if a knockout match will end in a draw after 90 mins', 'Yes',            'pre_match', 100, 'match', 'manual', 8),
  ('match_to_penalties',    'match_betting', 'Match to Go to Penalties', 'Predict if a knockout match will be decided by a penalty shootout', 'Yes',          'pre_match', 150, 'match', 'manual', 9),
  -- League-specific match predictions
  ('second_half_result',    'match_betting', 'Second Half Result',       'Predict the result of the second half exclusively',          'Home Team',          'pre_match', 50,  'match', 'auto', 10),
  ('anytime_correct_score', 'match_betting', 'Anytime Correct Score',    'Predict if a scoreline will occur at any point',             '1-0',                'pre_match', 75,  'match', 'manual', 11)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  base_fet = EXCLUDED.base_fet;


-- ---------------------------------------------------------------
-- 7d. Market Types — Goals Betting (37)
-- ---------------------------------------------------------------

INSERT INTO public.prediction_market_types (id, category_id, name, description, example_selection, bet_type, base_fet, scope, settlement_type, display_order) VALUES
  ('btts',                 'goals', 'Both Teams to Score (BTTS)',         'Predict whether both teams will score at least one goal',    'Yes',          'pre_match_live', 50,  'match', 'auto', 1),
  ('btts_first_half',      'goals', 'BTTS - First Half',                 'Predict if both teams will score in the first half',         'Yes',          'pre_match',      100, 'match', 'auto', 2),
  ('btts_second_half',     'goals', 'BTTS - Second Half',                'Predict if both teams will score in the second half',        'No',           'pre_match',      75,  'match', 'auto', 3),
  ('btts_match_winner',    'goals', 'BTTS & Match Winner',               'Predict both teams to score AND the match winner',           'Yes & Home',   'pre_match',      125, 'match', 'auto', 4),
  ('over_under_0_5',       'goals', 'Over/Under 0.5 Goals',              'Predict if total goals will be over or under 0.5',           'Over 0.5',     'pre_match_live', 25,  'match', 'auto', 5),
  ('over_under_1_5',       'goals', 'Over/Under 1.5 Goals',              'Predict if total goals will be over or under 1.5',           'Over 1.5',     'pre_match_live', 50,  'match', 'auto', 6),
  ('over_under_2_5',       'goals', 'Over/Under 2.5 Goals',              'Predict if total goals will be over or under 2.5',           'Over 2.5',     'pre_match_live', 50,  'match', 'auto', 7),
  ('over_under_3_5',       'goals', 'Over/Under 3.5 Goals',              'Predict if total goals will be over or under 3.5',           'Under 3.5',    'pre_match_live', 50,  'match', 'auto', 8),
  ('over_under_4_5',       'goals', 'Over/Under 4.5 Goals',              'Predict if total goals will be over or under 4.5',           'Under 4.5',    'pre_match_live', 75,  'match', 'auto', 9),
  ('over_under_5_5',       'goals', 'Over/Under 5.5 Goals',              'Predict if total goals will be over or under 5.5',           'Under 5.5',    'pre_match_live', 100, 'match', 'auto', 10),
  ('over_under_6_5',       'goals', 'Over/Under 6.5 Goals',              'Predict if total goals will be over or under 6.5',           'Under 6.5',    'pre_match_live', 125, 'match', 'auto', 11),
  ('home_team_goals_ou',   'goals', 'Home Team Total Goals (O/U)',        'Predict total goals scored by the Home Team',                'Over 1.5',     'pre_match',      50,  'match', 'auto', 12),
  ('home_team_goals_0_5',  'goals', 'Home Team Goals Over/Under 0.5',     'Predict if the home team will score over or under 0.5 goals','Over 0.5',     'pre_match',      40,  'match', 'auto', 13),
  ('home_team_goals_1_5',  'goals', 'Home Team Goals Over/Under 1.5',     'Predict if the home team will score over or under 1.5 goals','Over 1.5',     'pre_match',      50,  'match', 'auto', 14),
  ('home_team_goals_2_5',  'goals', 'Home Team Goals Over/Under 2.5',     'Predict if the home team will score over or under 2.5 goals','Under 2.5',    'pre_match',      65,  'match', 'auto', 15),
  ('home_team_goals_3_5',  'goals', 'Home Team Goals Over/Under 3.5',     'Predict if the home team will score over or under 3.5 goals','Under 3.5',    'pre_match',      80,  'match', 'auto', 16),
  ('away_team_goals_ou',   'goals', 'Away Team Total Goals (O/U)',        'Predict total goals scored by the Away Team',                'Under 1.5',    'pre_match',      50,  'match', 'auto', 17),
  ('away_team_goals_0_5',  'goals', 'Away Team Goals Over/Under 0.5',     'Predict if the away team will score over or under 0.5 goals','Over 0.5',     'pre_match',      40,  'match', 'auto', 18),
  ('away_team_goals_1_5',  'goals', 'Away Team Goals Over/Under 1.5',     'Predict if the away team will score over or under 1.5 goals','Under 1.5',    'pre_match',      50,  'match', 'auto', 19),
  ('away_team_goals_2_5',  'goals', 'Away Team Goals Over/Under 2.5',     'Predict if the away team will score over or under 2.5 goals','Under 2.5',    'pre_match',      65,  'match', 'auto', 20),
  ('away_team_goals_3_5',  'goals', 'Away Team Goals Over/Under 3.5',     'Predict if the away team will score over or under 3.5 goals','Under 3.5',    'pre_match',      80,  'match', 'auto', 21),
  ('exact_total_goals',    'goals', 'Exact Total Goals',                  'Predict the exact number of goals scored in the match',      '3 Goals',      'pre_match',      100, 'match', 'auto', 22),
  ('odd_even_goals',       'goals', 'Odd/Even Total Goals',               'Predict if the total number of goals will be odd or even',   'Odd',          'pre_match',      50,  'match', 'auto', 23),
  ('exact_score',          'goals', 'Correct Score',                      'Predict the exact final score of the match',                 '2-1',          'pre_match',      125, 'match', 'auto', 24),
  ('half_time_correct_score', 'goals', 'Half-Time Correct Score',         'Predict the exact score at half-time',                       '0-0',          'pre_match',      75,  'match', 'auto', 25),
  ('time_of_first_goal',   'goals', 'Time of First Goal',                 'Predict the 15-minute bracket of the first goal',            '0-15 Minutes', 'pre_match',      75,  'match', 'manual', 26),
  ('team_to_score_first',  'goals', 'Team to Score First',                'Predict which team scores the first goal',                   'Home Team',    'pre_match_live', 50,  'match', 'auto', 27),
  ('team_to_score_last',   'goals', 'Team to Score Last',                 'Predict which team scores the final goal of the match',      'Away Team',    'pre_match_live', 50,  'match', 'auto', 28),
  -- League-specific
  ('first_half_goals_ou',  'goals', 'First Half Goals (O/U)',             'Total goals in first half',                                  'Over 1.5',     'pre_match',      75,  'match', 'auto', 29),
  ('first_half_goals_0_5', 'goals', 'First Half Goals Over/Under 0.5',    'Predict if first-half goals will be over or under 0.5',      'Over 0.5',     'pre_match',      40,  'match', 'auto', 30),
  ('first_half_goals_1_5', 'goals', 'First Half Goals Over/Under 1.5',    'Predict if first-half goals will be over or under 1.5',      'Under 1.5',    'pre_match',      55,  'match', 'auto', 31),
  ('first_half_goals_2_5', 'goals', 'First Half Goals Over/Under 2.5',    'Predict if first-half goals will be over or under 2.5',      'Under 2.5',    'pre_match',      70,  'match', 'auto', 32),
  ('second_half_goals_ou', 'goals', 'Second Half Goals (O/U)',            'Total goals in second half',                                 'Over 1.5',     'pre_match',      75,  'match', 'auto', 33),
  ('second_half_goals_0_5','goals', 'Second Half Goals Over/Under 0.5',   'Predict if second-half goals will be over or under 0.5',     'Over 0.5',     'pre_match',      40,  'match', 'auto', 34),
  ('second_half_goals_1_5','goals', 'Second Half Goals Over/Under 1.5',   'Predict if second-half goals will be over or under 1.5',     'Under 1.5',    'pre_match',      55,  'match', 'auto', 35),
  ('second_half_goals_2_5','goals', 'Second Half Goals Over/Under 2.5',   'Predict if second-half goals will be over or under 2.5',     'Under 2.5',    'pre_match',      70,  'match', 'auto', 36),
  -- Backward compat alias
  ('over_under',           'goals', 'Over/Under Goals (Legacy)',           'Legacy over/under market',                                  'over_2.5',     'pre_match_live', 50,  'match', 'auto', 99)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  base_fet = EXCLUDED.base_fet;


-- ---------------------------------------------------------------
-- 7e. Market Types — Handicap Betting (7)
-- ---------------------------------------------------------------

INSERT INTO public.prediction_market_types (id, category_id, name, description, example_selection, bet_type, base_fet, scope, settlement_type, display_order) VALUES
  ('asian_handicap_m0_5',   'handicap', 'Asian Handicap -0.5',  'Team must win the match to win the bet',                   'Home -0.5',       'pre_match_live', 50,  'match', 'auto', 1),
  ('asian_handicap_m1_0',   'handicap', 'Asian Handicap -1.0',  'Team must win by 2+ (refund on 1)',                        'Home -1.0',       'pre_match_live', 75,  'match', 'semi_auto', 2),
  ('asian_handicap_m1_5',   'handicap', 'Asian Handicap -1.5',  'Team must win by 2 or more goals',                         'Home -1.5',       'pre_match_live', 75,  'match', 'auto', 3),
  ('asian_handicap_p0_5',   'handicap', 'Asian Handicap +0.5',  'Team must win or draw',                                    'Away +0.5',       'pre_match_live', 50,  'match', 'auto', 4),
  ('asian_handicap_p1_5',   'handicap', 'Asian Handicap +1.5',  'Team can win, draw, or lose by 1 goal',                    'Away +1.5',       'pre_match_live', 75,  'match', 'auto', 5),
  ('three_way_handicap_m1', 'handicap', '3-Way Handicap -1',    'European handicap, predicting outcome after applying a -1 goal deficit', 'Home -1', 'pre_match', 75, 'match', 'auto', 6),
  ('three_way_handicap_tie','handicap', '3-Way Handicap Tie',   'Predicting a draw after a handicap is applied',            'Tie (Home -1)',   'pre_match',      100, 'match', 'auto', 7)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  base_fet = EXCLUDED.base_fet;


-- ---------------------------------------------------------------
-- 7f. Market Types — Goalscorer Markets (9)
-- ---------------------------------------------------------------

INSERT INTO public.prediction_market_types (id, category_id, name, description, example_selection, bet_type, base_fet, scope, settlement_type, display_order) VALUES
  ('first_goalscorer',     'goalscorer', 'First Goalscorer',         'Predict which player will score the first goal',          'Lionel Messi',    'pre_match', 100, 'player', 'manual', 1),
  ('anytime_goalscorer',   'goalscorer', 'Anytime Goalscorer',       'Predict a player to score at any point during normal time','Erling Haaland',  'pre_match', 75,  'player', 'manual', 2),
  ('last_goalscorer',      'goalscorer', 'Last Goalscorer',          'Predict which player will score the last goal',           'Vinicius Jr',     'pre_match', 100, 'player', 'manual', 3),
  ('player_2plus_goals',   'goalscorer', 'Player to Score 2+ Goals', 'Predict a player to score two or more goals',             'Harry Kane',      'pre_match', 150, 'player', 'manual', 4),
  ('player_hat_trick',     'goalscorer', 'Player to Score a Hat-Trick', 'Predict a player to score three or more goals',        'Kylian Mbappe',   'pre_match', 250, 'player', 'manual', 5),
  ('wincast',              'goalscorer', 'Wincast',                   'Predict anytime goalscorer AND the match winner',         'Haaland & Norway','pre_match', 125, 'player', 'manual', 6),
  ('scorecast',            'goalscorer', 'Scorecast',                 'Predict first goalscorer AND correct match score',        'Messi & 2-0',    'pre_match', 250, 'player', 'manual', 7),
  ('to_score_first_half',  'goalscorer', 'To Score in First Half',    'Player to score in 1st half',                             'Ollie Watkins',   'pre_match', 125, 'player', 'manual', 8)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  base_fet = EXCLUDED.base_fet;


-- ---------------------------------------------------------------
-- 7g. Market Types — Match Props (9)
-- ---------------------------------------------------------------

INSERT INTO public.prediction_market_types (id, category_id, name, description, example_selection, bet_type, base_fet, scope, settlement_type, display_order) VALUES
  ('winning_margin',            'match_props', 'Winning Margin',                   'Predict the exact goal margin a team will win by',                        'Home Team by 2 Goals', 'pre_match', 100, 'match', 'auto',   1),
  ('to_win_to_nil',             'match_props', 'To Win to Nil',                    'Predict a team to win without conceding a goal',                          'Home Team',            'pre_match', 100, 'match', 'auto',   2),
  ('to_win_from_behind',        'match_props', 'To Win from Behind',               'Predict a team to concede first but ultimately win',                      'Away Team',            'pre_match', 150, 'match', 'manual', 3),
  ('btts_both_halves',          'match_props', 'Both Teams to Score in Both Halves','Predict BTTS to hit in both the 1st and 2nd half',                       'Yes',                  'pre_match', 200, 'match', 'auto',   4),
  ('own_goal_in_match',         'match_props', 'Own Goal in Match',                 'Predict if an own goal will be scored',                                   'Yes',                  'pre_match', 150, 'match', 'manual', 5),
  ('win_both_halves',           'match_props', 'Win Both Halves',                   'Score more goals in BOTH halves',                                         'Home Team',            'pre_match', 175, 'match', 'auto',   6),
  ('score_in_both_halves',      'match_props', 'Score in Both Halves',              'Score at least one in both halves',                                       'Away Team',            'pre_match', 100, 'match', 'auto',   7),
  ('clean_sheet_home',          'match_props', 'Clean Sheet - Home Team',           'Home team keeps clean sheet',                                             'Yes',                  'pre_match', 75,  'match', 'auto',   8)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  base_fet = EXCLUDED.base_fet;


-- ---------------------------------------------------------------
-- 7h. Market Types — Corners Betting (20)
-- ---------------------------------------------------------------

INSERT INTO public.prediction_market_types (id, category_id, name, description, example_selection, bet_type, base_fet, scope, settlement_type, display_order) VALUES
  ('total_corners_ou',     'corners', 'Total Corners (O/U)',         'Predict if total corners will be over/under a set line',       'Over 9.5',              'pre_match_live', 50,  'match', 'manual', 1),
  ('total_corners_8_5',    'corners', 'Total Corners Over/Under 8.5','Predict if total corners will be over or under 8.5',           'Over 8.5',              'pre_match_live', 50,  'match', 'auto', 2),
  ('total_corners_9_5',    'corners', 'Total Corners Over/Under 9.5','Predict if total corners will be over or under 9.5',           'Under 9.5',             'pre_match_live', 50,  'match', 'auto', 3),
  ('total_corners_10_5',   'corners', 'Total Corners Over/Under 10.5','Predict if total corners will be over or under 10.5',         'Under 10.5',            'pre_match_live', 60,  'match', 'auto', 4),
  ('total_corners_11_5',   'corners', 'Total Corners Over/Under 11.5','Predict if total corners will be over or under 11.5',         'Under 11.5',            'pre_match_live', 70,  'match', 'auto', 5),
  ('total_corners_12_5',   'corners', 'Total Corners Over/Under 12.5','Predict if total corners will be over or under 12.5',         'Under 12.5',            'pre_match_live', 80,  'match', 'auto', 6),
  ('first_half_corners_ou','corners', 'First Half Corners (O/U)',    'Predict if 1st half corners will be over/under a set line',    'Over 4.5',              'pre_match',      50,  'match', 'manual', 7),
  ('most_corners',         'corners', 'Most Corners',                'Predict which team will be awarded the most corners',          'Home Team',             'pre_match',      50,  'match', 'manual', 8),
  ('corner_handicap',      'corners', 'Corner Handicap',             'Handicap applied to team corner totals',                       'Home -2.5 Corners',     'pre_match',      75,  'match', 'manual', 9),
  ('race_to_5_corners',    'corners', 'Race to 5 Corners',           'Predict which team will reach 5 corners first',                'Away Team',             'pre_match_live', 75,  'match', 'manual', 10),
  ('home_team_corners_ou', 'corners', 'Home Team Total Corners',     'Home team corners over/under',                                 'Over 5.5',              'pre_match',      50,  'match', 'manual', 11),
  ('home_team_corners_2_5','corners', 'Home Team Corners Over/Under 2.5','Predict if the home team will win over or under 2.5 corners','Over 2.5',          'pre_match',      35,  'match', 'auto', 12),
  ('home_team_corners_3_5','corners', 'Home Team Corners Over/Under 3.5','Predict if the home team will win over or under 3.5 corners','Over 3.5',          'pre_match',      40,  'match', 'auto', 13),
  ('home_team_corners_4_5','corners', 'Home Team Corners Over/Under 4.5','Predict if the home team will win over or under 4.5 corners','Under 4.5',         'pre_match',      50,  'match', 'auto', 14),
  ('home_team_corners_5_5','corners', 'Home Team Corners Over/Under 5.5','Predict if the home team will win over or under 5.5 corners','Under 5.5',         'pre_match',      60,  'match', 'auto', 15),
  ('away_team_corners_ou', 'corners', 'Away Team Total Corners',     'Away team corners over/under',                                 'Under 4.5',             'pre_match',      50,  'match', 'manual', 16),
  ('away_team_corners_2_5','corners', 'Away Team Corners Over/Under 2.5','Predict if the away team will win over or under 2.5 corners','Over 2.5',          'pre_match',      35,  'match', 'auto', 17),
  ('away_team_corners_3_5','corners', 'Away Team Corners Over/Under 3.5','Predict if the away team will win over or under 3.5 corners','Over 3.5',          'pre_match',      40,  'match', 'auto', 18),
  ('away_team_corners_4_5','corners', 'Away Team Corners Over/Under 4.5','Predict if the away team will win over or under 4.5 corners','Under 4.5',         'pre_match',      50,  'match', 'auto', 19),
  ('away_team_corners_5_5','corners', 'Away Team Corners Over/Under 5.5','Predict if the away team will win over or under 5.5 corners','Under 5.5',         'pre_match',      60,  'match', 'auto', 20)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  base_fet = EXCLUDED.base_fet;


-- ---------------------------------------------------------------
-- 7i. Market Types — Cards Betting (19)
-- ---------------------------------------------------------------

INSERT INTO public.prediction_market_types (id, category_id, name, description, example_selection, bet_type, base_fet, scope, settlement_type, display_order) VALUES
  ('total_match_cards_ou',    'cards', 'Total Match Cards (O/U)',     'Predict total booking points/cards over or under a line',  'Over 4.5 Cards',  'pre_match_live', 50,  'match', 'manual', 1),
  ('total_match_cards_3_5',   'cards', 'Total Match Cards Over/Under 3.5','Predict total cards over or under 3.5',                'Over 3.5',        'pre_match_live', 45,  'match', 'auto', 2),
  ('total_match_cards_4_5',   'cards', 'Total Match Cards Over/Under 4.5','Predict total cards over or under 4.5',                'Under 4.5',       'pre_match_live', 50,  'match', 'auto', 3),
  ('total_match_cards_5_5',   'cards', 'Total Match Cards Over/Under 5.5','Predict total cards over or under 5.5',                'Under 5.5',       'pre_match_live', 60,  'match', 'auto', 4),
  ('total_match_cards_6_5',   'cards', 'Total Match Cards Over/Under 6.5','Predict total cards over or under 6.5',                'Under 6.5',       'pre_match_live', 70,  'match', 'auto', 5),
  ('total_yellow_cards_ou',   'cards', 'Total Match Yellow Cards',    'Total yellow cards over/under',                            'Over 3.5',        'pre_match',      50,  'match', 'manual', 6),
  ('total_yellow_cards_2_5',  'cards', 'Total Yellow Cards Over/Under 2.5','Predict total yellow cards over or under 2.5',        'Over 2.5',        'pre_match',      40,  'match', 'auto', 7),
  ('total_yellow_cards_3_5',  'cards', 'Total Yellow Cards Over/Under 3.5','Predict total yellow cards over or under 3.5',        'Under 3.5',       'pre_match',      50,  'match', 'auto', 8),
  ('total_yellow_cards_4_5',  'cards', 'Total Yellow Cards Over/Under 4.5','Predict total yellow cards over or under 4.5',        'Under 4.5',       'pre_match',      60,  'match', 'auto', 9),
  ('total_yellow_cards_5_5',  'cards', 'Total Yellow Cards Over/Under 5.5','Predict total yellow cards over or under 5.5',        'Under 5.5',       'pre_match',      70,  'match', 'auto', 10),
  ('team_most_cards',         'cards', 'Team with Most Cards',        'Predict which team receives more cards',                   'Away Team',       'pre_match',      50,  'match', 'manual', 11),
  ('home_team_total_cards_1_5','cards','Home Team Cards Over/Under 1.5','Predict if the home team will receive over or under 1.5 cards','Over 1.5',     'pre_match',      40,  'match', 'auto', 12),
  ('home_team_total_cards_2_5','cards','Home Team Cards Over/Under 2.5','Predict if the home team will receive over or under 2.5 cards','Under 2.5',    'pre_match',      50,  'match', 'auto', 13),
  ('home_team_total_cards_3_5','cards','Home Team Cards Over/Under 3.5','Predict if the home team will receive over or under 3.5 cards','Under 3.5',    'pre_match',      60,  'match', 'auto', 14),
  ('away_team_total_cards_1_5','cards','Away Team Cards Over/Under 1.5','Predict if the away team will receive over or under 1.5 cards','Over 1.5',     'pre_match',      40,  'match', 'auto', 15),
  ('away_team_total_cards_2_5','cards','Away Team Cards Over/Under 2.5','Predict if the away team will receive over or under 2.5 cards','Under 2.5',    'pre_match',      50,  'match', 'auto', 16),
  ('away_team_total_cards_3_5','cards','Away Team Cards Over/Under 3.5','Predict if the away team will receive over or under 3.5 cards','Under 3.5',    'pre_match',      60,  'match', 'auto', 17),
  ('red_card_in_match',       'cards', 'Red Card in Match',           'Predict if any player will be sent off',                   'Yes',             'pre_match_live', 125, 'match', 'manual', 18),
  ('first_card_received',     'cards', 'First Card Received',         'Predict which team gets the first yellow or red card',     'Home Team',       'pre_match',      50,  'match', 'manual', 19)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  base_fet = EXCLUDED.base_fet;


-- ---------------------------------------------------------------
-- 7j. Market Types — Player Props (8)
-- ---------------------------------------------------------------

INSERT INTO public.prediction_market_types (id, category_id, name, description, example_selection, bet_type, base_fet, scope, settlement_type, display_order) VALUES
  ('player_to_be_carded',      'player_props', 'Player to be Carded',         'Predict if a specific player will receive a card',          'Player X',  'pre_match_live', 75,  'player', 'manual', 1),
  ('player_to_be_sent_off',    'player_props', 'Player to be Sent Off',       'Predict if a specific player receives a red card',          'Player Y',  'pre_match',      200, 'player', 'manual', 2),
  ('player_shots_on_target_ou','player_props', 'Player Shots on Target (O/U)','Predict over/under for a player shots on target',           'Over 1.5',  'pre_match',      75,  'player', 'manual', 3),
  ('player_total_shots_ou',    'player_props', 'Player Total Shots (O/U)',    'Predict total shots (on or off target) by a player',         'Over 2.5',  'pre_match',      75,  'player', 'manual', 4),
  ('player_assists_ou',        'player_props', 'Player Assists (O/U)',        'Predict if a player will register an assist',                'Over 0.5',  'pre_match',      100, 'player', 'manual', 5),
  ('player_total_passes_ou',   'player_props', 'Player Total Passes (O/U)',   'Predict total passes completed by a specific player',        'Over 45.5', 'pre_match',      75,  'player', 'manual', 6),
  ('player_tackles_ou',        'player_props', 'Player Tackles (O/U)',        'Player tackles made over/under',                             'Over 2.5',  'pre_match',      75,  'player', 'manual', 7),
  ('goalkeeper_saves_ou',      'player_props', 'Goalkeeper Saves (O/U)',      'Total saves by goalkeeper over/under',                       'Over 3.5',  'pre_match',      75,  'player', 'manual', 8)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  base_fet = EXCLUDED.base_fet;


-- ---------------------------------------------------------------
-- 7k. Market Types — Match Events (4)
-- ---------------------------------------------------------------

INSERT INTO public.prediction_market_types (id, category_id, name, description, example_selection, bet_type, base_fet, scope, settlement_type, display_order) VALUES
  ('penalty_awarded',       'match_events', 'Penalty Awarded',           'Predict if a penalty will be awarded in the match',        'Yes', 'pre_match_live', 100, 'match', 'manual', 1),
  ('penalty_missed',        'match_events', 'Penalty Missed',            'Predict if a penalty will be taken and missed',            'Yes', 'pre_match_live', 175, 'match', 'manual', 2),
  ('penalty_scored',        'match_events', 'Penalty Scored',            'Predict if a penalty will be awarded and scored',          'Yes', 'pre_match_live', 125, 'match', 'manual', 3),
  ('var_goal_disallowed',   'match_events', 'VAR Review - Goal Disallowed', 'Predict if a goal will be ruled out by VAR',            'Yes', 'pre_match_live', 125, 'match', 'manual', 4)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  base_fet = EXCLUDED.base_fet;


-- ---------------------------------------------------------------
-- 7l. Market Types — In-Play / Live (4)
-- ---------------------------------------------------------------

INSERT INTO public.prediction_market_types (id, category_id, name, description, example_selection, bet_type, base_fet, scope, settlement_type, display_order) VALUES
  ('next_team_to_score',    'live', 'Next Team to Score',          'Predict which team scores the next specific goal',       'Home Team',  'live', 50, 'match', 'manual', 1),
  ('rest_of_match_winner',  'live', 'Rest of the Match Winner',   'Predict who wins the remainder of the match from current score', 'Away Team', 'live', 50, 'match', 'manual', 2),
  ('next_corner',           'live', 'Next Team to get a Corner',  'Predict who gets the next corner kick',                  'Home Team',  'live', 25, 'match', 'manual', 3),
  ('next_card',             'live', 'Next Team to get a Card',    'Predict who gets the next yellow or red card',            'Away Team',  'live', 50, 'match', 'manual', 4)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  base_fet = EXCLUDED.base_fet;


-- ---------------------------------------------------------------
-- 7m. Market Types — Combo Markets (4)
-- ---------------------------------------------------------------

INSERT INTO public.prediction_market_types (id, category_id, name, description, example_selection, bet_type, base_fet, scope, settlement_type, display_order) VALUES
  ('match_winner_ou_2_5',       'combo', 'Match Winner + O/U 2.5 Goals',  'Combine match winner and total goals over/under 2.5',      'Home + Over 2.5',  'pre_match', 75,  'match', 'auto',   1),
  ('double_chance_btts',        'combo', 'Double Chance + BTTS',          'Combine double chance with both teams to score',            '1X + Yes',          'pre_match', 75,  'match', 'auto',   2),
  ('double_chance_total_goals', 'combo', 'Double Chance + Total Goals',   'Combine double chance and Over/Under',                     '12 + Over 2.5',    'pre_match', 75,  'match', 'auto',   3),
  ('match_winner_most_corners', 'combo', 'Match Winner + Most Corners',   'Combine match winner with who gets the most corners',      'Home + Home',       'pre_match', 100, 'match', 'manual', 4)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  base_fet = EXCLUDED.base_fet;


-- ---------------------------------------------------------------
-- 7n. League Availability Mappings
--     NULL competition_id = "All Leagues" (handled at query time)
--     Only insert explicit restrictions (EPL/La Liga only markets)
-- ---------------------------------------------------------------

INSERT INTO public.competitions (
  id,
  name,
  short_name,
  country,
  tier,
  data_source,
  status,
  region,
  competition_type,
  is_featured
) VALUES
  ('epl',               'Premier League',          'EPL',   'England', 1, 'manual', 'active', 'europe', 'league', true),
  ('la-liga',           'La Liga',                 'LL',    'Spain',   1, 'manual', 'active', 'europe', 'league', true),
  ('serie-a',           'Serie A',                 'SA',    'Italy',   1, 'manual', 'active', 'europe', 'league', true),
  ('bundesliga',        'Bundesliga',              'BL',    'Germany', 1, 'manual', 'active', 'europe', 'league', true),
  ('ligue-1',           'Ligue 1',                 'L1',    'France',  1, 'manual', 'active', 'europe', 'league', true),
  ('champions-league',  'UEFA Champions League',   'UCL',   'Europe',  1, 'manual', 'active', 'europe', 'cup',    true),
  ('malta-premier',     'Malta Premier League',    'MPL',   'Malta',   1, 'manual', 'active', 'europe', 'league', true),
  ('rwanda-premier',    'Rwanda Premier League',   'RPL',   'Rwanda',  1, 'manual', 'active', 'africa', 'league', true),
  ('caf-champions',     'CAF Champions League',    'CAFCL', 'Africa',  1, 'manual', 'active', 'africa', 'cup',    true)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  short_name = EXCLUDED.short_name,
  country = EXCLUDED.country,
  tier = EXCLUDED.tier,
  data_source = EXCLUDED.data_source,
  status = EXCLUDED.status,
  region = EXCLUDED.region,
  competition_type = EXCLUDED.competition_type,
  is_featured = EXCLUDED.is_featured;

-- These markets are ONLY available for EPL and La Liga
INSERT INTO public.prediction_market_league_availability (market_type_id, competition_id, is_available) VALUES
  -- Top 4 Finish (EPL, La Liga only)
  ('top_4_finish',               'epl', true),
  ('top_4_finish',               'la-liga',         true),
  -- Most Assists (EPL, La Liga only)
  ('most_assists',               'epl', true),
  ('most_assists',               'la-liga',         true),
  -- Player Props (EPL, La Liga only)
  ('player_total_shots_ou',      'epl', true),
  ('player_total_shots_ou',      'la-liga',         true),
  ('player_shots_on_target_ou',  'epl', true),
  ('player_shots_on_target_ou',  'la-liga',         true),
  ('player_total_passes_ou',     'epl', true),
  ('player_total_passes_ou',     'la-liga',         true),
  ('player_tackles_ou',          'epl', true),
  ('player_tackles_ou',          'la-liga',         true),
  ('player_assists_ou',          'epl', true),
  ('player_assists_ou',          'la-liga',         true),
  ('goalkeeper_saves_ou',        'epl', true),
  ('goalkeeper_saves_ou',        'la-liga',         true),
  ('player_to_be_carded',       'epl', true),
  ('player_to_be_carded',       'la-liga',         true),
  -- VAR Review (EPL, La Liga only)
  ('var_goal_disallowed',        'epl', true),
  ('var_goal_disallowed',        'la-liga',         true)
ON CONFLICT (market_type_id, competition_id) DO NOTHING;


-- ---------------------------------------------------------------
-- 7o. World Cup 2026 Outright Market Instances
-- ---------------------------------------------------------------

INSERT INTO public.tournament_outright_markets (market_type_id, tournament_id, competition_id, name, description, status, base_fet, lock_at) VALUES
  ('tournament_winner',          'worldcup2026', NULL, 'World Cup 2026 Winner',           'Predict the overall winner of the 2026 World Cup',                              'open', 500, '2026-06-11 00:00:00+00'),
  ('tournament_runner_up',       'worldcup2026', NULL, 'World Cup 2026 Runner-Up',        'Predict the team that will lose in the final',                                  'open', 375, '2026-06-11 00:00:00+00'),
  ('to_reach_final',             'worldcup2026', NULL, 'To Reach the Final',              'Predict if a specific team will make it to the final match',                    'open', 250, '2026-06-11 00:00:00+00'),
  ('to_reach_semi_finals',       'worldcup2026', NULL, 'To Reach the Semi-Finals',        'Predict if a team will reach the final four',                                   'open', 200, '2026-06-11 00:00:00+00'),
  ('to_reach_quarter_finals',    'worldcup2026', NULL, 'To Reach the Quarter-Finals',     'Predict if a team will reach the final eight',                                  'open', 150, '2026-06-11 00:00:00+00'),
  ('golden_boot_winner',         'worldcup2026', NULL, 'Golden Boot Winner',              'Predict the top goalscorer of the tournament',                                  'open', 250, '2026-06-11 00:00:00+00'),
  ('golden_ball_winner',         'worldcup2026', NULL, 'Golden Ball Winner',              'Predict the best player of the tournament',                                     'open', 250, '2026-06-11 00:00:00+00'),
  ('golden_glove_winner',        'worldcup2026', NULL, 'Golden Glove Winner',             'Predict the best goalkeeper of the tournament',                                 'open', 250, '2026-06-11 00:00:00+00'),
  ('best_young_player',          'worldcup2026', NULL, 'Best Young Player',               'Predict the best young player of the tournament',                               'open', 250, '2026-06-11 00:00:00+00'),
  ('group_winner',               'worldcup2026', NULL, 'Group A Winner',                  'Predict the winner of Group A',                                                 'open', 125, '2026-06-11 00:00:00+00'),
  ('group_winner',               'worldcup2026', NULL, 'Group B Winner',                  'Predict the winner of Group B',                                                 'open', 125, '2026-06-11 00:00:00+00'),
  ('group_winner',               'worldcup2026', NULL, 'Group C Winner',                  'Predict the winner of Group C',                                                 'open', 125, '2026-06-11 00:00:00+00'),
  ('group_winner',               'worldcup2026', NULL, 'Group D Winner',                  'Predict the winner of Group D',                                                 'open', 125, '2026-06-11 00:00:00+00'),
  ('group_winner',               'worldcup2026', NULL, 'Group E Winner',                  'Predict the winner of Group E',                                                 'open', 125, '2026-06-11 00:00:00+00'),
  ('group_winner',               'worldcup2026', NULL, 'Group F Winner',                  'Predict the winner of Group F',                                                 'open', 125, '2026-06-11 00:00:00+00'),
  ('group_winner',               'worldcup2026', NULL, 'Group G Winner',                  'Predict the winner of Group G',                                                 'open', 125, '2026-06-11 00:00:00+00'),
  ('group_winner',               'worldcup2026', NULL, 'Group H Winner',                  'Predict the winner of Group H',                                                 'open', 125, '2026-06-11 00:00:00+00'),
  ('group_winner',               'worldcup2026', NULL, 'Group I Winner',                  'Predict the winner of Group I',                                                 'open', 125, '2026-06-11 00:00:00+00'),
  ('group_winner',               'worldcup2026', NULL, 'Group J Winner',                  'Predict the winner of Group J',                                                 'open', 125, '2026-06-11 00:00:00+00'),
  ('group_winner',               'worldcup2026', NULL, 'Group K Winner',                  'Predict the winner of Group K',                                                 'open', 125, '2026-06-11 00:00:00+00'),
  ('group_winner',               'worldcup2026', NULL, 'Group L Winner',                  'Predict the winner of Group L',                                                 'open', 125, '2026-06-11 00:00:00+00'),
  ('group_to_qualify',           'worldcup2026', NULL, 'Group Qualification',             'Predict if a specific team will advance from their group',                      'open', 100, '2026-06-11 00:00:00+00'),
  ('total_tournament_goals',     'worldcup2026', NULL, 'Total Tournament Goals',          'Predict if total goals in all matches will be over/under a line',               'open', 250, '2026-06-11 00:00:00+00'),
  ('total_tournament_red_cards', 'worldcup2026', NULL, 'Total Tournament Red Cards',      'Predict total red cards shown in the entire tournament',                        'open', 150, '2026-06-11 00:00:00+00'),
  ('winning_continent',          'worldcup2026', NULL, 'Winning Continent',               'Predict which continent the winning team will be from',                         'open', 200, '2026-06-11 00:00:00+00'),
  ('highest_scoring_team',       'worldcup2026', NULL, 'Highest Scoring Team',            'Predict the team that scores the most goals overall',                           'open', 200, '2026-06-11 00:00:00+00'),
  ('lowest_scoring_team',        'worldcup2026', NULL, 'Lowest Scoring Team',             'Predict the team that scores the fewest goals overall',                         'open', 200, '2026-06-11 00:00:00+00')
;

-- ---------------------------------------------------------------
-- 7p. League Season Outright Market Instances (2025/26)
-- ---------------------------------------------------------------

INSERT INTO public.tournament_outright_markets (market_type_id, tournament_id, competition_id, name, description, status, base_fet, lock_at) VALUES
  -- Premier League
  ('league_winner',    'epl-2025-26', 'epl', 'Premier League Winner 2025/26',   'Predict the Premier League champion', 'open', 500, '2026-05-25 00:00:00+00'),
  ('relegation',       'epl-2025-26', 'epl', 'Premier League Relegation 2025/26', 'Predict a team to be relegated from the Premier League', 'open', 375, '2026-05-25 00:00:00+00'),
  ('top_goalscorer',   'epl-2025-26', 'epl', 'PL Top Goalscorer 2025/26',       'Predict the top scorer in the Premier League', 'open', 250, '2026-05-25 00:00:00+00'),
  ('top_4_finish',     'epl-2025-26', 'epl', 'PL Top 4 Finish 2025/26',         'Predict a team to finish in the Premier League top 4', 'open', 250, '2026-05-25 00:00:00+00'),
  ('most_assists',     'epl-2025-26', 'epl', 'PL Most Assists 2025/26',         'Predict the player with most PL assists', 'open', 250, '2026-05-25 00:00:00+00'),
  -- La Liga
  ('league_winner',    'la-liga-2025-26',        'la-liga',         'La Liga Winner 2025/26',          'Predict the La Liga champion', 'open', 500, '2026-05-31 00:00:00+00'),
  ('relegation',       'la-liga-2025-26',        'la-liga',         'La Liga Relegation 2025/26',      'Predict a team to be relegated from La Liga', 'open', 375, '2026-05-31 00:00:00+00'),
  ('top_goalscorer',   'la-liga-2025-26',        'la-liga',         'La Liga Top Goalscorer 2025/26',  'Predict the top scorer in La Liga', 'open', 250, '2026-05-31 00:00:00+00'),
  ('top_4_finish',     'la-liga-2025-26',        'la-liga',         'La Liga Top 4 Finish 2025/26',    'Predict a team to finish in the La Liga top 4', 'open', 250, '2026-05-31 00:00:00+00'),
  ('most_assists',     'la-liga-2025-26',        'la-liga',         'La Liga Most Assists 2025/26',    'Predict the player with most La Liga assists', 'open', 250, '2026-05-31 00:00:00+00'),
  -- Serie A
  ('league_winner',    'serie-a-2025-26',        'serie-a',         'Serie A Winner 2025/26',          'Predict the Serie A champion', 'open', 500, '2026-05-25 00:00:00+00'),
  ('relegation',       'serie-a-2025-26',        'serie-a',         'Serie A Relegation 2025/26',      'Predict a team to be relegated from Serie A', 'open', 375, '2026-05-25 00:00:00+00'),
  ('top_goalscorer',   'serie-a-2025-26',        'serie-a',         'Serie A Top Goalscorer 2025/26',  'Predict the top scorer in Serie A', 'open', 250, '2026-05-25 00:00:00+00'),
  -- Bundesliga
  ('league_winner',    'bundesliga-2025-26',     'bundesliga',      'Bundesliga Winner 2025/26',       'Predict the Bundesliga champion', 'open', 500, '2026-05-16 00:00:00+00'),
  ('relegation',       'bundesliga-2025-26',     'bundesliga',      'Bundesliga Relegation 2025/26',   'Predict a team to be relegated from Bundesliga', 'open', 375, '2026-05-16 00:00:00+00'),
  ('top_goalscorer',   'bundesliga-2025-26',     'bundesliga',      'Bundesliga Top Goalscorer 2025/26', 'Predict the top scorer in Bundesliga', 'open', 250, '2026-05-16 00:00:00+00'),
  -- Ligue 1
  ('league_winner',    'ligue-1-2025-26',        'ligue-1',         'Ligue 1 Winner 2025/26',          'Predict the Ligue 1 champion', 'open', 500, '2026-05-24 00:00:00+00'),
  ('relegation',       'ligue-1-2025-26',        'ligue-1',         'Ligue 1 Relegation 2025/26',      'Predict a team to be relegated from Ligue 1', 'open', 375, '2026-05-24 00:00:00+00'),
  ('top_goalscorer',   'ligue-1-2025-26',        'ligue-1',         'Ligue 1 Top Goalscorer 2025/26',  'Predict the top scorer in Ligue 1', 'open', 250, '2026-05-24 00:00:00+00'),
  -- Rwanda Premier League
  ('league_winner',    'rwanda-premier-2025-26', 'rwanda-premier',  'RPL Winner 2025/26',              'Predict the Rwanda Premier League champion', 'open', 500, '2026-06-30 00:00:00+00'),
  ('relegation',       'rwanda-premier-2025-26', 'rwanda-premier',  'RPL Relegation 2025/26',          'Predict a team to be relegated from RPL', 'open', 375, '2026-06-30 00:00:00+00'),
  ('top_goalscorer',   'rwanda-premier-2025-26', 'rwanda-premier',  'RPL Top Goalscorer 2025/26',      'Predict the RPL top scorer', 'open', 250, '2026-06-30 00:00:00+00'),
  -- Malta Premier League
  ('league_winner',    'malta-premier-2025-26',  'malta-premier',   'Malta PL Winner 2025/26',         'Predict the Malta Premier League champion', 'open', 500, '2026-05-15 00:00:00+00'),
  ('relegation',       'malta-premier-2025-26',  'malta-premier',   'Malta PL Relegation 2025/26',     'Predict a team to be relegated from Malta PL', 'open', 375, '2026-05-15 00:00:00+00'),
  ('top_goalscorer',   'malta-premier-2025-26',  'malta-premier',   'Malta PL Top Goalscorer 2025/26', 'Predict the Malta PL top scorer', 'open', 250, '2026-05-15 00:00:00+00'),
  -- CAF Champions League
  ('league_winner',    'caf-champions-2025-26',  'caf-champions',   'CAF CL Winner 2025/26',           'Predict the CAF Champions League winner', 'open', 500, '2026-06-30 00:00:00+00'),
  ('top_goalscorer',   'caf-champions-2025-26',  'caf-champions',   'CAF CL Top Goalscorer 2025/26',   'Predict the CAF CL top scorer', 'open', 250, '2026-06-30 00:00:00+00'),
  -- UCL
  ('league_winner',    'champions-league-2025-26', 'champions-league', 'UCL Winner 2025/26',           'Predict the UEFA Champions League winner', 'open', 500, '2026-05-27 00:00:00+00'),
  ('top_goalscorer',   'champions-league-2025-26', 'champions-league', 'UCL Top Goalscorer 2025/26',   'Predict the UCL top scorer', 'open', 250, '2026-05-27 00:00:00+00')
;


-- ---------------------------------------------------------------
-- 7q. Backfill market_type_id for existing prediction_slip_selections
-- ---------------------------------------------------------------

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'prediction_slip_selections'
  ) THEN
    UPDATE public.prediction_slip_selections
    SET market_type_id = CASE market
      WHEN 'match_result' THEN 'match_result'
      WHEN 'exact_score'  THEN 'exact_score'
      WHEN 'over_under'   THEN 'over_under'
      WHEN 'btts'         THEN 'btts'
      ELSE market
    END
    WHERE market_type_id IS NULL;
  END IF;
END $$;


-- ═══════════════════════════════════════════════════════════════
-- 8. RPC FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

-- ---------------------------------------------------------------
-- 8a. get_market_catalog — Returns available markets for a competition
-- ---------------------------------------------------------------

CREATE OR REPLACE FUNCTION get_market_catalog(
  p_competition_id TEXT DEFAULT NULL,
  p_scope TEXT DEFAULT NULL,
  p_bet_type TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', mt.id,
      'category_id', mt.category_id,
      'category_name', mc.name,
      'name', mt.name,
      'description', mt.description,
      'example_selection', mt.example_selection,
      'bet_type', mt.bet_type,
      'base_fet', mt.base_fet,
      'scope', mt.scope,
      'settlement_type', mt.settlement_type,
      'display_order', mt.display_order
    ) ORDER BY mc.display_order, mt.display_order
  )
  INTO v_result
  FROM public.prediction_market_types mt
  JOIN public.prediction_market_categories mc ON mc.id = mt.category_id
  WHERE mt.is_active = true
    AND mc.is_active = true
    AND (p_scope IS NULL OR mt.scope = p_scope)
    AND (p_bet_type IS NULL OR mt.bet_type = p_bet_type)
    AND (
      -- If no competition specified, return all non-restricted markets
      p_competition_id IS NULL
      OR
      -- Market has no league restriction (available to all)
      NOT EXISTS (
        SELECT 1 FROM public.prediction_market_league_availability
        WHERE market_type_id = mt.id
      )
      OR
      -- Market is explicitly available for this competition
      EXISTS (
        SELECT 1 FROM public.prediction_market_league_availability
        WHERE market_type_id = mt.id
          AND competition_id = p_competition_id
          AND is_available = true
      )
    );

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION get_market_catalog(TEXT, TEXT, TEXT) TO anon, authenticated;


-- ---------------------------------------------------------------
-- 8b. get_outright_markets — Returns outright markets for a tournament
-- ---------------------------------------------------------------

CREATE OR REPLACE FUNCTION get_outright_markets(
  p_tournament_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();

  SELECT jsonb_agg(
    jsonb_build_object(
      'id', om.id,
      'market_type_id', om.market_type_id,
      'tournament_id', om.tournament_id,
      'competition_id', om.competition_id,
      'name', om.name,
      'description', om.description,
      'status', om.status,
      'base_fet', om.base_fet,
      'lock_at', om.lock_at,
      'settlement_value', om.settlement_value,
      'user_entry', (
        SELECT jsonb_build_object(
          'id', oe.id,
          'selection', oe.selection,
          'status', oe.status,
          'payout_fet', oe.payout_fet,
          'submitted_at', oe.submitted_at
        )
        FROM public.tournament_outright_entries oe
        WHERE oe.outright_market_id = om.id
          AND oe.user_id = v_user_id
      )
    ) ORDER BY om.base_fet DESC, om.name
  )
  INTO v_result
  FROM public.tournament_outright_markets om
  WHERE om.tournament_id = p_tournament_id
    AND om.status != 'cancelled';

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION get_outright_markets(TEXT) TO anon, authenticated;


-- ---------------------------------------------------------------
-- 8c. submit_outright_prediction — Submit a free outright prediction
-- ---------------------------------------------------------------

CREATE OR REPLACE FUNCTION submit_outright_prediction(
  p_outright_market_id UUID,
  p_selection TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_market RECORD;
  v_entry_id UUID;
  v_projected_earn BIGINT;
BEGIN
  -- Auth check
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Validate selection
  IF p_selection IS NULL OR trim(p_selection) = '' THEN
    RAISE EXCEPTION 'Selection is required';
  END IF;

  -- Get and validate market
  SELECT * INTO v_market
  FROM public.tournament_outright_markets
  WHERE id = p_outright_market_id
  FOR UPDATE;

  IF v_market IS NULL THEN
    RAISE EXCEPTION 'Market not found';
  END IF;

  IF v_market.status != 'open' THEN
    RAISE EXCEPTION 'Market is not open for predictions (status: %)', v_market.status;
  END IF;

  IF v_market.lock_at IS NOT NULL AND v_market.lock_at <= now() THEN
    RAISE EXCEPTION 'Market is locked — predictions are no longer accepted';
  END IF;

  -- Check for duplicate entry
  IF EXISTS (
    SELECT 1 FROM public.tournament_outright_entries
    WHERE outright_market_id = p_outright_market_id
      AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'You have already submitted a prediction for this market';
  END IF;

  -- Projected earn = base_fet (free prediction — earn on win)
  v_projected_earn := v_market.base_fet;

  -- Create entry (free — no FET deducted)
  INSERT INTO public.tournament_outright_entries (
    outright_market_id, user_id, selection, stake_fet, status
  ) VALUES (
    p_outright_market_id, v_user_id, trim(p_selection), 0, 'active'
  ) RETURNING id INTO v_entry_id;

  RETURN jsonb_build_object(
    'status', 'submitted',
    'entry_id', v_entry_id,
    'market_name', v_market.name,
    'selection', p_selection,
    'projected_earn_fet', v_projected_earn
  );
END;
$$;

GRANT EXECUTE ON FUNCTION submit_outright_prediction(UUID, TEXT) TO authenticated;


-- ---------------------------------------------------------------
-- 8d. admin_settle_outright_market — Settle an outright market
-- ---------------------------------------------------------------

CREATE OR REPLACE FUNCTION admin_settle_outright_market(
  p_market_id UUID,
  p_correct_answer TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
  v_market RECORD;
  v_entry RECORD;
  v_winner_count INT := 0;
  v_loser_count INT := 0;
  v_balance_before BIGINT;
BEGIN
  -- Admin auth
  v_admin_id := auth.uid();
  IF NOT EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE user_id = v_admin_id AND is_active = true
      AND role IN ('super_admin', 'admin')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  -- Lock and validate market
  SELECT * INTO v_market
  FROM public.tournament_outright_markets
  WHERE id = p_market_id
  FOR UPDATE;

  IF v_market IS NULL THEN
    RAISE EXCEPTION 'Market not found';
  END IF;

  IF v_market.status NOT IN ('open', 'locked') THEN
    RAISE EXCEPTION 'Market already settled or cancelled (status: %)', v_market.status;
  END IF;

  IF p_correct_answer IS NULL OR trim(p_correct_answer) = '' THEN
    RAISE EXCEPTION 'Correct answer is required';
  END IF;

  -- Settle each entry
  FOR v_entry IN
    SELECT * FROM public.tournament_outright_entries
    WHERE outright_market_id = p_market_id AND status = 'active'
    FOR UPDATE
  LOOP
    IF lower(trim(v_entry.selection)) = lower(trim(p_correct_answer)) THEN
      -- Winner
      v_winner_count := v_winner_count + 1;

      UPDATE public.tournament_outright_entries
      SET status = 'won',
          payout_fet = v_market.base_fet,
          settled_at = now()
      WHERE id = v_entry.id;

      -- Credit wallet
      SELECT available_balance_fet INTO v_balance_before
      FROM public.fet_wallets
      WHERE user_id = v_entry.user_id
      FOR UPDATE;

      -- Create wallet if needed
      INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
      VALUES (v_entry.user_id, v_market.base_fet, 0)
      ON CONFLICT (user_id) DO UPDATE
      SET available_balance_fet = fet_wallets.available_balance_fet + v_market.base_fet,
          updated_at = now();

      INSERT INTO public.fet_wallet_transactions (
        user_id, tx_type, direction, amount_fet,
        balance_before_fet, balance_after_fet,
        reference_type, reference_id, title
      ) VALUES (
        v_entry.user_id, 'outright_win', 'credit', v_market.base_fet,
        COALESCE(v_balance_before, 0),
        COALESCE(v_balance_before, 0) + v_market.base_fet,
        'tournament_outright_market', p_market_id,
        'Outright win: ' || v_market.name || ' — ' || v_entry.selection
      );
    ELSE
      -- Loser
      v_loser_count := v_loser_count + 1;

      UPDATE public.tournament_outright_entries
      SET status = 'lost',
          settled_at = now()
      WHERE id = v_entry.id;
    END IF;
  END LOOP;

  -- Update market
  UPDATE public.tournament_outright_markets
  SET status = 'settled',
      settlement_value = p_correct_answer,
      settled_at = now(),
      updated_at = now()
  WHERE id = p_market_id;

  -- Audit log
  INSERT INTO public.admin_audit_logs (
    admin_user_id, action, module, target_type, target_id,
    after_state, metadata
  )
  SELECT au.id, 'settle_outright', 'markets', 'outright_market', p_market_id::text,
    jsonb_build_object(
      'correct_answer', p_correct_answer,
      'winners', v_winner_count,
      'losers', v_loser_count,
      'payout_per_winner', v_market.base_fet
    ),
    '{}'::jsonb
  FROM public.admin_users au WHERE au.user_id = v_admin_id;

  RETURN jsonb_build_object(
    'status', 'settled',
    'market_id', p_market_id,
    'correct_answer', p_correct_answer,
    'winner_count', v_winner_count,
    'loser_count', v_loser_count,
    'payout_per_winner', v_market.base_fet
  );
END;
$$;


-- ---------------------------------------------------------------
-- 8e. admin_manage_market_type — CRUD for market types
-- ---------------------------------------------------------------

CREATE OR REPLACE FUNCTION admin_manage_market_type(
  p_action TEXT,
  p_market_type_id TEXT,
  p_data JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
BEGIN
  -- Admin auth
  v_admin_id := auth.uid();
  IF NOT EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE user_id = v_admin_id AND is_active = true
      AND role IN ('super_admin', 'admin')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF p_action = 'create' THEN
    INSERT INTO public.prediction_market_types (
      id, category_id, name, description, example_selection,
      bet_type, base_fet, scope, settlement_type, is_active, display_order
    ) VALUES (
      p_market_type_id,
      p_data->>'category_id',
      p_data->>'name',
      COALESCE(p_data->>'description', ''),
      COALESCE(p_data->>'example_selection', ''),
      COALESCE(p_data->>'bet_type', 'pre_match'),
      COALESCE((p_data->>'base_fet')::INT, 50),
      COALESCE(p_data->>'scope', 'match'),
      COALESCE(p_data->>'settlement_type', 'manual'),
      true,
      COALESCE((p_data->>'display_order')::INT, 0)
    );

    RETURN jsonb_build_object('status', 'created', 'id', p_market_type_id);

  ELSIF p_action = 'update' THEN
    UPDATE public.prediction_market_types
    SET name = COALESCE(p_data->>'name', name),
        description = COALESCE(p_data->>'description', description),
        base_fet = COALESCE((p_data->>'base_fet')::INT, base_fet),
        is_active = COALESCE((p_data->>'is_active')::BOOLEAN, is_active)
    WHERE id = p_market_type_id;

    RETURN jsonb_build_object('status', 'updated', 'id', p_market_type_id);

  ELSIF p_action = 'deactivate' THEN
    UPDATE public.prediction_market_types
    SET is_active = false
    WHERE id = p_market_type_id;

    RETURN jsonb_build_object('status', 'deactivated', 'id', p_market_type_id);

  ELSIF p_action = 'activate' THEN
    UPDATE public.prediction_market_types
    SET is_active = true
    WHERE id = p_market_type_id;

    RETURN jsonb_build_object('status', 'activated', 'id', p_market_type_id);

  ELSE
    RAISE EXCEPTION 'Unknown action: %. Use create, update, activate, or deactivate.', p_action;
  END IF;

  -- Audit
  INSERT INTO public.admin_audit_logs (
    admin_user_id, action, module, target_type, target_id,
    after_state
  )
  SELECT au.id, 'manage_market_type_' || p_action, 'markets', 'market_type', p_market_type_id,
    p_data
  FROM public.admin_users au WHERE au.user_id = v_admin_id;
END;
$$;


-- ---------------------------------------------------------------
-- 8f. Updated submit_prediction_slip — accepts any market type
--     DROP first to change return type safely
-- ---------------------------------------------------------------

DROP FUNCTION IF EXISTS submit_prediction_slip(JSONB);

CREATE OR REPLACE FUNCTION submit_prediction_slip(
  p_selections JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_slip_id UUID;
  v_count INT;
  v_total_earn BIGINT := 0;
  v_sel JSONB;
  v_market_val TEXT;
  v_market_type_id TEXT;
  v_base_fet INT;
  v_table_exists BOOLEAN;
BEGIN
  -- Auth check
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Validate input
  IF p_selections IS NULL OR jsonb_array_length(p_selections) = 0 THEN
    RAISE EXCEPTION 'At least one selection is required';
  END IF;

  -- Check if prediction_slips table exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'prediction_slips'
  ) INTO v_table_exists;

  IF NOT v_table_exists THEN
    RAISE EXCEPTION 'Prediction slips system is not yet deployed';
  END IF;

  v_count := jsonb_array_length(p_selections);

  -- Sum projected earnings
  FOR v_sel IN SELECT * FROM jsonb_array_elements(p_selections) LOOP
    v_total_earn := v_total_earn + COALESCE((v_sel->>'potential_earn_fet')::BIGINT, 0);
  END LOOP;

  -- Create the slip
  INSERT INTO prediction_slips (user_id, selection_count, projected_earn_fet)
  VALUES (v_user_id, v_count, v_total_earn)
  RETURNING id INTO v_slip_id;

  -- Insert each selection
  FOR v_sel IN SELECT * FROM jsonb_array_elements(p_selections) LOOP
    -- Resolve market_type_id
    v_market_val := COALESCE(v_sel->>'market', 'match_result');
    v_market_type_id := COALESCE(v_sel->>'market_type_id', v_market_val);

    -- Look up base_fet from catalog if available
    SELECT base_fet INTO v_base_fet
    FROM public.prediction_market_types
    WHERE id = v_market_type_id;

    INSERT INTO prediction_slip_selections (
      slip_id,
      match_id,
      match_name,
      market,
      selection,
      potential_earn_fet
    ) VALUES (
      v_slip_id,
      v_sel->>'match_id',
      COALESCE(v_sel->>'match_name', ''),
      v_market_val,
      v_sel->>'selection',
      COALESCE((v_sel->>'potential_earn_fet')::BIGINT, 0)
    );
  END LOOP;

  RETURN jsonb_build_object(
    'status', 'submitted',
    'slip_id', v_slip_id,
    'selection_count', v_count,
    'projected_earn_fet', v_total_earn
  );
END;
$$;

GRANT EXECUTE ON FUNCTION submit_prediction_slip(JSONB) TO authenticated;


-- ═══════════════════════════════════════════════════════════════
-- 9. UPDATED-AT TRIGGERS
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.update_outright_markets_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_outright_markets_updated_at ON public.tournament_outright_markets;
CREATE TRIGGER trg_outright_markets_updated_at
  BEFORE UPDATE ON public.tournament_outright_markets
  FOR EACH ROW EXECUTE FUNCTION public.update_outright_markets_updated_at();


COMMIT;
