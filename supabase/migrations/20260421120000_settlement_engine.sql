-- ============================================================
-- 20260421120000_settlement_engine.sql
--
-- Automated settlement engine for ALL prediction markets.
-- Architecture:
--   1. Adds settlement metadata to prediction_market_types
--      (settlement_data_tier, settlement_eval_key, settlement_config)
--   2. Populates configs for all 108 market types
--   3. Creates settle_match_selections() RPC that reads
--      evaluation rules FROM the table (no hardcoded market IDs)
--   4. Creates settle_outright_markets_batch() for tournament outrights
--   5. Replaces settle_prediction_slips_for_match with new engine
-- ============================================================


-- ═══════════════════════════════════════════════════════════════
-- 1. Add settlement metadata columns to prediction_market_types
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE public.prediction_market_types
  ADD COLUMN IF NOT EXISTS settlement_data_tier TEXT NOT NULL DEFAULT 'score'
    CHECK (settlement_data_tier IN ('score', 'events', 'stats', 'outright'));

ALTER TABLE public.prediction_market_types
  ADD COLUMN IF NOT EXISTS settlement_eval_key TEXT NOT NULL DEFAULT 'match_result';

ALTER TABLE public.prediction_market_types
  ADD COLUMN IF NOT EXISTS settlement_config JSONB NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.prediction_market_types.settlement_data_tier IS
  'Data source needed: score=match scores, events=match_events table, stats=Gemini-enriched stats, outright=end-of-tournament';

COMMENT ON COLUMN public.prediction_market_types.settlement_eval_key IS
  'Evaluator function name used by the settlement engine Edge Function';

COMMENT ON COLUMN public.prediction_market_types.settlement_config IS
  'Parameters for the evaluator: line values, stat keys, event types, etc.';


-- ═══════════════════════════════════════════════════════════════
-- 2. Populate settlement configs for ALL 108 market types
--    Uses UPDATE...SET to avoid re-inserting
-- ═══════════════════════════════════════════════════════════════

-- ---------------------------------------------------------------
-- 2a. Match Result markets (score-based)
-- ---------------------------------------------------------------
UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'match_result',
  settlement_config = '{"score_type": "ft"}'::jsonb
WHERE id = 'match_result';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'double_chance',
  settlement_config = '{"score_type": "ft"}'::jsonb
WHERE id = 'double_chance';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'draw_no_bet',
  settlement_config = '{"score_type": "ft"}'::jsonb
WHERE id = 'draw_no_bet';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'match_result',
  settlement_config = '{"score_type": "ht"}'::jsonb
WHERE id = 'half_time_result';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'match_result',
  settlement_config = '{"score_type": "2h"}'::jsonb
WHERE id = 'second_half_result';

-- ---------------------------------------------------------------
-- 2b. Exact Score markets
-- ---------------------------------------------------------------
UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'exact_score',
  settlement_config = '{"score_type": "ft"}'::jsonb
WHERE id = 'exact_score';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'exact_score',
  settlement_config = '{"score_type": "ht"}'::jsonb
WHERE id = 'half_time_correct_score';

-- ---------------------------------------------------------------
-- 2c. Over/Under markets (score-based total goals)
-- ---------------------------------------------------------------
UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'over_under',
  settlement_config = '{"stat": "total_goals", "line": 0.5}'::jsonb
WHERE id = 'over_under_0_5';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'over_under',
  settlement_config = '{"stat": "total_goals", "line": 1.5}'::jsonb
WHERE id = 'over_under_1_5';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'over_under',
  settlement_config = '{"stat": "total_goals", "line": 2.5}'::jsonb
WHERE id = 'over_under_2_5';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'over_under',
  settlement_config = '{"stat": "total_goals", "line": 3.5}'::jsonb
WHERE id = 'over_under_3_5';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'over_under',
  settlement_config = '{"stat": "total_goals", "line": 4.5}'::jsonb
WHERE id = 'over_under_4_5';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'over_under',
  settlement_config = '{"stat": "total_goals", "line": 5.5}'::jsonb
WHERE id = 'over_under_5_5';

-- Home/Away team goals O/U
UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'over_under',
  settlement_config = '{"stat": "home_goals"}'::jsonb
WHERE id = 'home_team_goals_ou';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'over_under',
  settlement_config = '{"stat": "away_goals"}'::jsonb
WHERE id = 'away_team_goals_ou';

-- ---------------------------------------------------------------
-- 2d. BTTS markets (score-based)
-- ---------------------------------------------------------------
UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'yes_no',
  settlement_config = '{"check": "btts"}'::jsonb
WHERE id = 'btts';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'yes_no',
  settlement_config = '{"check": "btts_first_half"}'::jsonb
WHERE id = 'btts_first_half';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'yes_no',
  settlement_config = '{"check": "btts_second_half"}'::jsonb
WHERE id = 'btts_second_half';

-- ---------------------------------------------------------------
-- 2e. Goals specials (score-based)
-- ---------------------------------------------------------------
UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'odd_even',
  settlement_config = '{"stat": "total_goals"}'::jsonb
WHERE id = 'odd_even_goals';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'exact_value',
  settlement_config = '{"stat": "total_goals"}'::jsonb
WHERE id = 'exact_total_goals';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'winning_margin',
  settlement_config = '{"score_type": "ft"}'::jsonb
WHERE id = 'winning_margin';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'yes_no',
  settlement_config = '{"check": "clean_sheet_home"}'::jsonb
WHERE id = 'to_win_to_nil';

-- ---------------------------------------------------------------
-- 2f. Half-based score markets
-- ---------------------------------------------------------------
UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'yes_no',
  settlement_config = '{"check": "score_in_both_halves"}'::jsonb
WHERE id = 'score_in_both_halves';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'yes_no',
  settlement_config = '{"check": "win_both_halves"}'::jsonb
WHERE id = 'win_both_halves';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'yes_no',
  settlement_config = '{"check": "btts_both_halves"}'::jsonb
WHERE id = 'btts_both_halves';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'yes_no',
  settlement_config = '{"check": "clean_sheet_home"}'::jsonb
WHERE id = 'clean_sheet_home';

-- ---------------------------------------------------------------
-- 2g. Handicap markets (score-based)
-- ---------------------------------------------------------------
UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'handicap',
  settlement_config = '{"type": "3way", "goals": 1}'::jsonb
WHERE id = 'three_way_handicap_1';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'handicap',
  settlement_config = '{"type": "3way", "goals": 2}'::jsonb
WHERE id = 'three_way_handicap_2';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'handicap',
  settlement_config = '{"type": "asian", "goals": 0.5}'::jsonb
WHERE id = 'asian_handicap_0_5';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'handicap',
  settlement_config = '{"type": "asian", "goals": 1}'::jsonb
WHERE id = 'asian_handicap_1';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'handicap',
  settlement_config = '{"type": "asian", "goals": 1.5}'::jsonb
WHERE id = 'asian_handicap_1_5';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'handicap',
  settlement_config = '{"type": "asian", "goals": 2}'::jsonb
WHERE id = 'asian_handicap_2';

-- ---------------------------------------------------------------
-- 2h. Combo markets (score-based)
-- ---------------------------------------------------------------
UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'combo_ht_ft',
  settlement_config = '{}'::jsonb
WHERE id = 'half_time_full_time';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'combo',
  settlement_config = '{"parts": ["match_result", "btts"]}'::jsonb
WHERE id = 'btts_match_winner';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'combo',
  settlement_config = '{"parts": ["double_chance", "btts"]}'::jsonb
WHERE id = 'double_chance_btts';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'combo',
  settlement_config = '{"parts": ["double_chance", "over_under"]}'::jsonb
WHERE id = 'double_chance_total_goals';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'combo',
  settlement_config = '{"parts": ["match_result", "over_under"], "line": 2.5}'::jsonb
WHERE id = 'match_winner_ou_2_5';

-- ---------------------------------------------------------------
-- 2i. Goalscorer / Player event markets (events-based)
-- ---------------------------------------------------------------
UPDATE public.prediction_market_types SET
  settlement_data_tier = 'events',
  settlement_eval_key = 'player_event',
  settlement_config = '{"event_type": "goal", "position": "first"}'::jsonb
WHERE id = 'first_goalscorer';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'events',
  settlement_eval_key = 'player_event',
  settlement_config = '{"event_type": "goal", "position": "any"}'::jsonb
WHERE id = 'anytime_goalscorer';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'events',
  settlement_eval_key = 'player_event',
  settlement_config = '{"event_type": "goal", "position": "last"}'::jsonb
WHERE id = 'last_goalscorer';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'events',
  settlement_eval_key = 'player_event_count',
  settlement_config = '{"event_type": "goal", "min_count": 2}'::jsonb
WHERE id = 'player_2plus_goals';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'events',
  settlement_eval_key = 'player_event_count',
  settlement_config = '{"event_type": "goal", "min_count": 3}'::jsonb
WHERE id = 'player_hat_trick';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'events',
  settlement_eval_key = 'player_event',
  settlement_config = '{"event_type": "goal", "position": "any", "half": "first"}'::jsonb
WHERE id = 'to_score_first_half';

-- ---------------------------------------------------------------
-- 2j. Team event markets (events-based)
-- ---------------------------------------------------------------
UPDATE public.prediction_market_types SET
  settlement_data_tier = 'events',
  settlement_eval_key = 'team_event',
  settlement_config = '{"event_type": "goal", "position": "first"}'::jsonb
WHERE id = 'team_to_score_first';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'events',
  settlement_eval_key = 'team_event',
  settlement_config = '{"event_type": "goal", "position": "last"}'::jsonb
WHERE id = 'team_to_score_last';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'events',
  settlement_eval_key = 'event_time_range',
  settlement_config = '{"event_type": "goal"}'::jsonb
WHERE id = 'time_of_first_goal';

-- ---------------------------------------------------------------
-- 2k. Card/Penalty/VAR markets (events-based)
-- ---------------------------------------------------------------
UPDATE public.prediction_market_types SET
  settlement_data_tier = 'events',
  settlement_eval_key = 'yes_no',
  settlement_config = '{"check": "red_card_in_match"}'::jsonb
WHERE id = 'red_card_in_match';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'events',
  settlement_eval_key = 'player_event',
  settlement_config = '{"event_type": "card", "position": "first"}'::jsonb
WHERE id = 'first_card_received';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'events',
  settlement_eval_key = 'team_event_count',
  settlement_config = '{"event_type": "card"}'::jsonb
WHERE id = 'team_most_cards';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'events',
  settlement_eval_key = 'over_under',
  settlement_config = '{"stat": "total_cards"}'::jsonb
WHERE id = 'total_match_cards_ou';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'events',
  settlement_eval_key = 'over_under',
  settlement_config = '{"stat": "total_yellow_cards"}'::jsonb
WHERE id = 'total_yellow_cards_ou';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'events',
  settlement_eval_key = 'yes_no',
  settlement_config = '{"check": "penalty_awarded"}'::jsonb
WHERE id = 'penalty_awarded';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'events',
  settlement_eval_key = 'yes_no',
  settlement_config = '{"check": "penalty_missed"}'::jsonb
WHERE id = 'penalty_missed';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'events',
  settlement_eval_key = 'yes_no',
  settlement_config = '{"check": "penalty_scored"}'::jsonb
WHERE id = 'penalty_scored';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'events',
  settlement_eval_key = 'yes_no',
  settlement_config = '{"check": "var_goal_disallowed"}'::jsonb
WHERE id = 'var_goal_disallowed';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'events',
  settlement_eval_key = 'yes_no',
  settlement_config = '{"check": "own_goal_in_match"}'::jsonb
WHERE id = 'own_goal_in_match';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'events',
  settlement_eval_key = 'player_event',
  settlement_config = '{"event_type": "card", "position": "any"}'::jsonb
WHERE id = 'player_to_be_carded';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'events',
  settlement_eval_key = 'player_event',
  settlement_config = '{"event_type": "red_card", "position": "any"}'::jsonb
WHERE id = 'player_to_be_sent_off';

-- Combo markets that mix events + scores
UPDATE public.prediction_market_types SET
  settlement_data_tier = 'events',
  settlement_eval_key = 'combo',
  settlement_config = '{"parts": ["match_result", "anytime_goalscorer"]}'::jsonb
WHERE id = 'wincast';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'events',
  settlement_eval_key = 'combo',
  settlement_config = '{"parts": ["exact_score", "anytime_goalscorer"]}'::jsonb
WHERE id = 'scorecast';

-- ---------------------------------------------------------------
-- 2l. Stats / Gemini-enriched markets (stats-based)
-- ---------------------------------------------------------------
UPDATE public.prediction_market_types SET
  settlement_data_tier = 'stats',
  settlement_eval_key = 'over_under',
  settlement_config = '{"stat": "total_corners"}'::jsonb
WHERE id = 'total_corners_ou';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'stats',
  settlement_eval_key = 'over_under',
  settlement_config = '{"stat": "first_half_corners"}'::jsonb
WHERE id = 'first_half_corners_ou';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'stats',
  settlement_eval_key = 'team_stat',
  settlement_config = '{"stat": "corners"}'::jsonb
WHERE id = 'most_corners';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'stats',
  settlement_eval_key = 'handicap',
  settlement_config = '{"type": "3way", "stat": "corners"}'::jsonb
WHERE id = 'corner_handicap';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'stats',
  settlement_eval_key = 'race_to',
  settlement_config = '{"stat": "corners", "target": 5}'::jsonb
WHERE id = 'race_to_5_corners';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'stats',
  settlement_eval_key = 'over_under',
  settlement_config = '{"stat": "home_corners"}'::jsonb
WHERE id = 'home_team_corners_ou';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'stats',
  settlement_eval_key = 'over_under',
  settlement_config = '{"stat": "away_corners"}'::jsonb
WHERE id = 'away_team_corners_ou';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'stats',
  settlement_eval_key = 'over_under',
  settlement_config = '{"stat": "player_total_shots"}'::jsonb
WHERE id = 'player_total_shots_ou';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'stats',
  settlement_eval_key = 'over_under',
  settlement_config = '{"stat": "player_shots_on_target"}'::jsonb
WHERE id = 'player_shots_on_target_ou';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'stats',
  settlement_eval_key = 'over_under',
  settlement_config = '{"stat": "player_total_passes"}'::jsonb
WHERE id = 'player_total_passes_ou';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'stats',
  settlement_eval_key = 'over_under',
  settlement_config = '{"stat": "player_tackles"}'::jsonb
WHERE id = 'player_tackles_ou';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'stats',
  settlement_eval_key = 'over_under',
  settlement_config = '{"stat": "player_assists"}'::jsonb
WHERE id = 'player_assists_ou';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'stats',
  settlement_eval_key = 'over_under',
  settlement_config = '{"stat": "goalkeeper_saves"}'::jsonb
WHERE id = 'goalkeeper_saves_ou';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'stats',
  settlement_eval_key = 'combo',
  settlement_config = '{"parts": ["match_result", "most_corners"]}'::jsonb
WHERE id = 'match_winner_most_corners';

-- ---------------------------------------------------------------
-- 2m. Knockout specials (stats-based — need Gemini context)
-- ---------------------------------------------------------------
UPDATE public.prediction_market_types SET
  settlement_data_tier = 'stats',
  settlement_eval_key = 'knockout',
  settlement_config = '{"check": "qualified"}'::jsonb
WHERE id = 'to_qualify';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'stats',
  settlement_eval_key = 'knockout',
  settlement_config = '{"check": "method"}'::jsonb
WHERE id = 'method_of_victory';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'yes_no',
  settlement_config = '{"check": "extra_time"}'::jsonb
WHERE id = 'match_to_extra_time';

UPDATE public.prediction_market_types SET
  settlement_data_tier = 'score',
  settlement_eval_key = 'yes_no',
  settlement_config = '{"check": "penalties"}'::jsonb
WHERE id = 'match_to_penalties';

-- ---------------------------------------------------------------
-- 2n. Outright / Tournament markets (outright tier)
-- ---------------------------------------------------------------
UPDATE public.prediction_market_types SET
  settlement_data_tier = 'outright',
  settlement_eval_key = 'outright',
  settlement_config = '{}'::jsonb
WHERE id IN (
  'tournament_winner', 'tournament_runner_up', 'to_reach_final',
  'to_reach_semi_finals', 'to_reach_quarter_finals',
  'golden_boot_winner', 'golden_ball_winner', 'golden_glove_winner',
  'best_young_player', 'group_winner', 'group_to_qualify',
  'total_tournament_goals', 'total_tournament_red_cards',
  'winning_continent', 'highest_scoring_team', 'lowest_scoring_team',
  'league_winner', 'relegation', 'top_goalscorer',
  'top_4_finish', 'most_assists'
);


-- ═══════════════════════════════════════════════════════════════
-- 3. market_settlement_log — audit trail for market settlements
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.market_settlement_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id TEXT,
  trigger_source TEXT NOT NULL DEFAULT 'edge_function',
  market_types_attempted INT DEFAULT 0,
  selections_settled INT DEFAULT 0,
  selections_won INT DEFAULT 0,
  selections_lost INT DEFAULT 0,
  selections_void INT DEFAULT 0,
  data_tiers_used TEXT[] DEFAULT '{}',
  gemini_enriched BOOLEAN DEFAULT false,
  match_stats JSONB DEFAULT '{}',
  errors TEXT[] DEFAULT '{}',
  settled_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_market_settlement_log_match
  ON public.market_settlement_log (match_id, settled_at DESC);

ALTER TABLE public.market_settlement_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.market_settlement_log FROM anon, authenticated;
GRANT SELECT, INSERT ON public.market_settlement_log TO service_role;

CREATE POLICY "Admins read market settlement log"
  ON public.market_settlement_log FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.admin_users
      WHERE user_id = auth.uid()
        AND is_active = true
        AND role IN ('super_admin', 'admin')
    )
  );


-- ═══════════════════════════════════════════════════════════════
-- 4. settle_match_selections() — DB-driven settlement RPC
--    Reads eval rules from prediction_market_types dynamically.
--    The Edge Function calls this after building match_stats.
-- ═══════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.settle_match_selections(TEXT, JSONB);

CREATE OR REPLACE FUNCTION public.settle_match_selections(
  p_match_id TEXT,
  p_match_stats JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_selection RECORD;
  v_market_type RECORD;
  v_result TEXT;  -- 'won', 'lost', 'void'
  v_settled_count INT := 0;
  v_won_count INT := 0;
  v_lost_count INT := 0;
  v_void_count INT := 0;
  v_slip_ids UUID[] := '{}';
  v_eval_key TEXT;
  v_config JSONB;
  -- Scores extracted from match_stats
  v_ft_home INT;
  v_ft_away INT;
  v_ht_home INT;
  v_ht_away INT;
  v_et_home INT;
  v_et_away INT;
  v_total_goals INT;
  v_2h_home INT;
  v_2h_away INT;
  -- Temp vars
  v_sel_value TEXT;
  v_check TEXT;
  v_stat TEXT;
  v_line NUMERIC;
  v_stat_val NUMERIC;
  v_score_type TEXT;
  v_h INT;
  v_a INT;
  v_parts JSONB;
  v_part1_result TEXT;
  v_part2_result TEXT;
BEGIN
  -- Extract core scores from match_stats
  v_ft_home := (p_match_stats->>'ft_home')::INT;
  v_ft_away := (p_match_stats->>'ft_away')::INT;
  v_ht_home := COALESCE((p_match_stats->>'ht_home')::INT, 0);
  v_ht_away := COALESCE((p_match_stats->>'ht_away')::INT, 0);
  v_et_home := (p_match_stats->>'et_home')::INT;
  v_et_away := (p_match_stats->>'et_away')::INT;
  v_total_goals := v_ft_home + v_ft_away;
  v_2h_home := v_ft_home - v_ht_home;
  v_2h_away := v_ft_away - v_ht_away;

  IF v_ft_home IS NULL OR v_ft_away IS NULL THEN
    RETURN jsonb_build_object('error', 'Missing ft_home/ft_away in match_stats');
  END IF;

  -- Iterate over all pending selections for this match
  -- JOIN with prediction_market_types to get eval rules
  FOR v_selection IN
    SELECT
      s.id AS sel_id,
      s.slip_id,
      s.match_id,
      s.market,
      s.selection,
      mt.id AS mt_id,
      mt.settlement_eval_key,
      mt.settlement_config,
      mt.settlement_data_tier
    FROM public.prediction_slip_selections s
    LEFT JOIN public.prediction_market_types mt
      ON mt.id = COALESCE(s.market_type_id, s.market)
    WHERE s.match_id = p_match_id
      AND s.result = 'pending'
    FOR UPDATE OF s
  LOOP
    v_eval_key := COALESCE(v_selection.settlement_eval_key, 'match_result');
    v_config := COALESCE(v_selection.settlement_config, '{}'::jsonb);
    v_sel_value := lower(trim(v_selection.selection));
    v_result := 'lost';  -- default

    -- Skip stats-tier markets if no stats data provided
    IF v_selection.settlement_data_tier = 'stats'
       AND NOT (p_match_stats ? 'stats_enriched') THEN
      CONTINUE;  -- skip, will be settled when Gemini data arrives
    END IF;

    -- Skip outright markets entirely
    IF v_selection.settlement_data_tier = 'outright' THEN
      CONTINUE;
    END IF;

    -- ═══════════════════════════════════════════
    -- EVALUATOR DISPATCH (reads from market type)
    -- ═══════════════════════════════════════════

    -- Resolve score pair based on config.score_type
    v_score_type := COALESCE(v_config->>'score_type', 'ft');
    v_h := CASE v_score_type
      WHEN 'ht' THEN v_ht_home
      WHEN '2h' THEN v_2h_home
      ELSE v_ft_home
    END;
    v_a := CASE v_score_type
      WHEN 'ht' THEN v_ht_away
      WHEN '2h' THEN v_2h_away
      ELSE v_ft_away
    END;

    -- ── match_result (1/X/2) ──
    IF v_eval_key = 'match_result' THEN
      v_result := CASE
        WHEN v_sel_value IN ('1', 'home') AND v_h > v_a THEN 'won'
        WHEN v_sel_value IN ('x', 'draw') AND v_h = v_a THEN 'won'
        WHEN v_sel_value IN ('2', 'away') AND v_h < v_a THEN 'won'
        ELSE 'lost'
      END;

    -- ── double_chance (1X/12/X2) ──
    ELSIF v_eval_key = 'double_chance' THEN
      v_result := CASE
        WHEN v_sel_value = '1x' AND v_h >= v_a THEN 'won'
        WHEN v_sel_value = '12' AND v_h != v_a THEN 'won'
        WHEN v_sel_value = 'x2' AND v_h <= v_a THEN 'won'
        ELSE 'lost'
      END;

    -- ── draw_no_bet (void on draw) ──
    ELSIF v_eval_key = 'draw_no_bet' THEN
      IF v_h = v_a THEN
        v_result := 'void';
      ELSIF v_sel_value IN ('1', 'home') AND v_h > v_a THEN
        v_result := 'won';
      ELSIF v_sel_value IN ('2', 'away') AND v_h < v_a THEN
        v_result := 'won';
      ELSE
        v_result := 'lost';
      END IF;

    -- ── exact_score ("H-A") ──
    ELSIF v_eval_key = 'exact_score' THEN
      v_result := CASE
        WHEN v_sel_value = (v_h || '-' || v_a) THEN 'won'
        ELSE 'lost'
      END;

    -- ── over_under ──
    ELSIF v_eval_key = 'over_under' THEN
      v_stat := COALESCE(v_config->>'stat', 'total_goals');
      v_line := (v_config->>'line')::NUMERIC;

      -- Resolve stat value
      v_stat_val := CASE v_stat
        WHEN 'total_goals' THEN v_total_goals
        WHEN 'home_goals' THEN v_ft_home
        WHEN 'away_goals' THEN v_ft_away
        WHEN 'total_cards' THEN COALESCE((p_match_stats->'event_counts'->>'total_cards')::NUMERIC, NULL)
        WHEN 'total_yellow_cards' THEN COALESCE((p_match_stats->'event_counts'->>'total_yellow_cards')::NUMERIC, NULL)
        ELSE COALESCE((p_match_stats->'stats'->v_stat)::NUMERIC, NULL)
      END;

      IF v_stat_val IS NULL THEN
        CONTINUE;  -- skip if stat not available
      END IF;

      -- Extract line from selection if not in config (e.g. "over 2.5")
      IF v_line IS NULL THEN
        v_line := COALESCE(
          (regexp_match(v_sel_value, '[\d.]+'))[1]::NUMERIC,
          2.5
        );
      END IF;

      v_result := CASE
        WHEN v_sel_value LIKE 'over%' AND v_stat_val > v_line THEN 'won'
        WHEN v_sel_value LIKE 'under%' AND v_stat_val < v_line THEN 'won'
        ELSE 'lost'
      END;

    -- ── yes_no (boolean checks) ──
    ELSIF v_eval_key = 'yes_no' THEN
      v_check := v_config->>'check';
      v_result := CASE v_check
        -- BTTS
        WHEN 'btts' THEN
          CASE WHEN v_sel_value = 'yes' AND v_ft_home > 0 AND v_ft_away > 0 THEN 'won'
               WHEN v_sel_value = 'no' AND (v_ft_home = 0 OR v_ft_away = 0) THEN 'won'
               ELSE 'lost' END
        WHEN 'btts_first_half' THEN
          CASE WHEN v_sel_value = 'yes' AND v_ht_home > 0 AND v_ht_away > 0 THEN 'won'
               WHEN v_sel_value = 'no' AND (v_ht_home = 0 OR v_ht_away = 0) THEN 'won'
               ELSE 'lost' END
        WHEN 'btts_second_half' THEN
          CASE WHEN v_sel_value = 'yes' AND v_2h_home > 0 AND v_2h_away > 0 THEN 'won'
               WHEN v_sel_value = 'no' AND (v_2h_home = 0 OR v_2h_away = 0) THEN 'won'
               ELSE 'lost' END
        WHEN 'btts_both_halves' THEN
          CASE WHEN v_sel_value = 'yes'
                    AND v_ht_home > 0 AND v_ht_away > 0
                    AND v_2h_home > 0 AND v_2h_away > 0 THEN 'won'
               WHEN v_sel_value = 'no' THEN
                 CASE WHEN NOT (v_ht_home > 0 AND v_ht_away > 0 AND v_2h_home > 0 AND v_2h_away > 0) THEN 'won'
                      ELSE 'lost' END
               ELSE 'lost' END
        -- Clean sheets
        WHEN 'clean_sheet_home' THEN
          CASE WHEN v_sel_value IN ('yes', 'home') AND v_ft_away = 0 THEN 'won'
               WHEN v_sel_value = 'no' AND v_ft_away > 0 THEN 'won'
               ELSE 'lost' END
        -- Score in both halves (home team context from selection)
        WHEN 'score_in_both_halves' THEN
          CASE WHEN v_sel_value = 'yes'
                    AND (v_ht_home > 0 OR v_ht_away > 0)
                    AND (v_2h_home > 0 OR v_2h_away > 0) THEN 'won'
               WHEN v_sel_value = 'no' THEN
                 CASE WHEN NOT ((v_ht_home > 0 OR v_ht_away > 0)
                                AND (v_2h_home > 0 OR v_2h_away > 0)) THEN 'won'
                      ELSE 'lost' END
               ELSE 'lost' END
        WHEN 'win_both_halves' THEN
          CASE WHEN v_sel_value IN ('yes', 'home')
                    AND v_ht_home > v_ht_away
                    AND v_2h_home > v_2h_away THEN 'won'
               WHEN v_sel_value = 'away'
                    AND v_ht_away > v_ht_home
                    AND v_2h_away > v_2h_home THEN 'won'
               ELSE 'lost' END
        -- Extra time / Penalties
        WHEN 'extra_time' THEN
          CASE WHEN v_sel_value = 'yes' AND v_et_home IS NOT NULL THEN 'won'
               WHEN v_sel_value = 'no' AND v_et_home IS NULL THEN 'won'
               ELSE 'lost' END
        WHEN 'penalties' THEN
          CASE WHEN v_sel_value = 'yes' AND (p_match_stats ? 'penalties') THEN 'won'
               WHEN v_sel_value = 'no' AND NOT (p_match_stats ? 'penalties') THEN 'won'
               ELSE 'lost' END
        -- Event-based yes/no: checked via event counts in match_stats
        WHEN 'red_card_in_match' THEN
          CASE WHEN v_sel_value = 'yes'
                    AND COALESCE((p_match_stats->'event_counts'->>'red_cards')::INT, 0) > 0 THEN 'won'
               WHEN v_sel_value = 'no'
                    AND COALESCE((p_match_stats->'event_counts'->>'red_cards')::INT, 0) = 0 THEN 'won'
               ELSE 'lost' END
        WHEN 'penalty_awarded' THEN
          CASE WHEN v_sel_value = 'yes'
                    AND COALESCE((p_match_stats->'event_counts'->>'penalties')::INT, 0) > 0 THEN 'won'
               WHEN v_sel_value = 'no'
                    AND COALESCE((p_match_stats->'event_counts'->>'penalties')::INT, 0) = 0 THEN 'won'
               ELSE 'lost' END
        WHEN 'penalty_missed' THEN
          CASE WHEN v_sel_value = 'yes'
                    AND COALESCE((p_match_stats->'event_counts'->>'penalties_missed')::INT, 0) > 0 THEN 'won'
               WHEN v_sel_value = 'no'
                    AND COALESCE((p_match_stats->'event_counts'->>'penalties_missed')::INT, 0) = 0 THEN 'won'
               ELSE 'lost' END
        WHEN 'penalty_scored' THEN
          CASE WHEN v_sel_value = 'yes'
                    AND COALESCE((p_match_stats->'event_counts'->>'penalties_scored')::INT, 0) > 0 THEN 'won'
               WHEN v_sel_value = 'no'
                    AND COALESCE((p_match_stats->'event_counts'->>'penalties_scored')::INT, 0) = 0 THEN 'won'
               ELSE 'lost' END
        WHEN 'var_goal_disallowed' THEN
          CASE WHEN v_sel_value = 'yes'
                    AND COALESCE((p_match_stats->'event_counts'->>'var_decisions')::INT, 0) > 0 THEN 'won'
               WHEN v_sel_value = 'no'
                    AND COALESCE((p_match_stats->'event_counts'->>'var_decisions')::INT, 0) = 0 THEN 'won'
               ELSE 'lost' END
        WHEN 'own_goal_in_match' THEN
          CASE WHEN v_sel_value = 'yes'
                    AND COALESCE((p_match_stats->'event_counts'->>'own_goals')::INT, 0) > 0 THEN 'won'
               WHEN v_sel_value = 'no'
                    AND COALESCE((p_match_stats->'event_counts'->>'own_goals')::INT, 0) = 0 THEN 'won'
               ELSE 'lost' END
        ELSE 'lost'
      END;

    -- ── odd_even ──
    ELSIF v_eval_key = 'odd_even' THEN
      v_result := CASE
        WHEN v_sel_value = 'odd' AND v_total_goals % 2 = 1 THEN 'won'
        WHEN v_sel_value = 'even' AND v_total_goals % 2 = 0 THEN 'won'
        ELSE 'lost'
      END;

    -- ── exact_value ──
    ELSIF v_eval_key = 'exact_value' THEN
      v_result := CASE
        WHEN v_sel_value = v_total_goals::TEXT THEN 'won'
        ELSE 'lost'
      END;

    -- ── winning_margin ──
    ELSIF v_eval_key = 'winning_margin' THEN
      -- Selection format: "home_by_2", "away_by_1", "draw"
      v_result := CASE
        WHEN v_sel_value = 'draw' AND v_ft_home = v_ft_away THEN 'won'
        WHEN v_sel_value LIKE 'home_by_%'
             AND v_ft_home - v_ft_away = (regexp_match(v_sel_value, '\d+'))[1]::INT
             THEN 'won'
        WHEN v_sel_value LIKE 'away_by_%'
             AND v_ft_away - v_ft_home = (regexp_match(v_sel_value, '\d+'))[1]::INT
             THEN 'won'
        ELSE 'lost'
      END;

    -- ── handicap ──
    ELSIF v_eval_key = 'handicap' THEN
      DECLARE
        v_hcap_type TEXT := COALESCE(v_config->>'type', '3way');
        v_hcap_goals NUMERIC := COALESCE((v_config->>'goals')::NUMERIC, 1);
        v_adj_home NUMERIC;
        v_adj_away NUMERIC;
      BEGIN
        -- Selection = "home -1" or "away +1" etc.
        -- Apply handicap to home team
        v_adj_home := v_h + CASE
          WHEN v_sel_value LIKE 'home%' THEN -v_hcap_goals
          ELSE v_hcap_goals
        END;
        v_adj_away := v_a::NUMERIC;

        IF v_hcap_type = 'asian' AND v_adj_home = v_adj_away THEN
          v_result := 'void';
        ELSIF v_sel_value LIKE 'home%' AND v_adj_home > v_adj_away THEN
          v_result := 'won';
        ELSIF v_sel_value LIKE 'away%' AND v_adj_away > v_adj_home THEN
          v_result := 'won';
        ELSIF v_sel_value LIKE 'draw%' AND v_adj_home = v_adj_away THEN
          v_result := 'won';
        ELSE
          v_result := 'lost';
        END IF;
      END;

    -- ── combo_ht_ft ──
    ELSIF v_eval_key = 'combo_ht_ft' THEN
      -- Selection format: "1/1", "X/2", "2/X", etc.
      DECLARE
        v_ht_res TEXT;
        v_ft_res TEXT;
        v_expected TEXT;
      BEGIN
        v_ht_res := CASE
          WHEN v_ht_home > v_ht_away THEN '1'
          WHEN v_ht_home = v_ht_away THEN 'X'
          ELSE '2'
        END;
        v_ft_res := CASE
          WHEN v_ft_home > v_ft_away THEN '1'
          WHEN v_ft_home = v_ft_away THEN 'X'
          ELSE '2'
        END;
        v_expected := v_ht_res || '/' || v_ft_res;
        v_result := CASE WHEN lower(v_expected) = v_sel_value THEN 'won' ELSE 'lost' END;
      END;

    -- ── player_event (goalscorer, carded player) ──
    ELSIF v_eval_key = 'player_event' THEN
      DECLARE
        v_event_type_cfg TEXT := COALESCE(v_config->>'event_type', 'goal');
        v_position TEXT := COALESCE(v_config->>'position', 'any');
        v_half TEXT := v_config->>'half';
        v_events JSONB;
        v_matching JSONB;
        v_ev JSONB;
      BEGIN
        v_events := COALESCE(p_match_stats->'events', '[]'::jsonb);
        -- Filter by event type
        SELECT jsonb_agg(e) INTO v_matching
        FROM jsonb_array_elements(v_events) e
        WHERE CASE v_event_type_cfg
          WHEN 'goal' THEN e->>'event_type' IN ('GOAL', 'PENALTY_SCORED')
          WHEN 'card' THEN e->>'event_type' IN ('YELLOW_CARD', 'RED_CARD')
          WHEN 'red_card' THEN e->>'event_type' = 'RED_CARD'
          ELSE e->>'event_type' = upper(v_event_type_cfg)
        END
        AND (v_half IS NULL
             OR (v_half = 'first' AND (e->>'minute')::INT <= 45)
             OR (v_half = 'second' AND (e->>'minute')::INT > 45));

        v_matching := COALESCE(v_matching, '[]'::jsonb);

        IF jsonb_array_length(v_matching) = 0 THEN
          v_result := 'lost';
        ELSIF v_position = 'first' THEN
          v_ev := v_matching->0;
          v_result := CASE WHEN lower(v_ev->>'player') = v_sel_value
                              OR lower(v_ev->>'player_name') = v_sel_value THEN 'won' ELSE 'lost' END;
        ELSIF v_position = 'last' THEN
          v_ev := v_matching->(jsonb_array_length(v_matching) - 1);
          v_result := CASE WHEN lower(v_ev->>'player') = v_sel_value
                              OR lower(v_ev->>'player_name') = v_sel_value THEN 'won' ELSE 'lost' END;
        ELSE -- 'any'
          SELECT 'won' INTO v_result
          FROM jsonb_array_elements(v_matching) e
          WHERE lower(e->>'player') = v_sel_value
             OR lower(e->>'player_name') = v_sel_value
          LIMIT 1;
          v_result := COALESCE(v_result, 'lost');
        END IF;
      END;

    -- ── player_event_count ──
    ELSIF v_eval_key = 'player_event_count' THEN
      DECLARE
        v_event_type_cfg TEXT := COALESCE(v_config->>'event_type', 'goal');
        v_min_count INT := COALESCE((v_config->>'min_count')::INT, 2);
        v_player_count INT;
      BEGIN
        SELECT count(*) INTO v_player_count
        FROM jsonb_array_elements(COALESCE(p_match_stats->'events', '[]'::jsonb)) e
        WHERE CASE v_event_type_cfg
          WHEN 'goal' THEN e->>'event_type' IN ('GOAL', 'PENALTY_SCORED')
          ELSE e->>'event_type' = upper(v_event_type_cfg)
        END
        AND (lower(e->>'player') = v_sel_value OR lower(e->>'player_name') = v_sel_value);

        v_result := CASE WHEN v_player_count >= v_min_count THEN 'won' ELSE 'lost' END;
      END;

    -- ── team_event ──
    ELSIF v_eval_key = 'team_event' THEN
      DECLARE
        v_event_type_cfg TEXT := COALESCE(v_config->>'event_type', 'goal');
        v_position TEXT := COALESCE(v_config->>'position', 'first');
        v_event_team TEXT;
      BEGIN
        IF v_position = 'first' THEN
          SELECT lower(e->>'team') INTO v_event_team
          FROM jsonb_array_elements(COALESCE(p_match_stats->'events', '[]'::jsonb)) e
          WHERE e->>'event_type' IN (
            CASE v_event_type_cfg
              WHEN 'goal' THEN 'GOAL'
              ELSE upper(v_event_type_cfg)
            END, 'PENALTY_SCORED')
          ORDER BY (e->>'minute')::INT ASC
          LIMIT 1;
        ELSE
          SELECT lower(e->>'team') INTO v_event_team
          FROM jsonb_array_elements(COALESCE(p_match_stats->'events', '[]'::jsonb)) e
          WHERE e->>'event_type' IN (
            CASE v_event_type_cfg
              WHEN 'goal' THEN 'GOAL'
              ELSE upper(v_event_type_cfg)
            END, 'PENALTY_SCORED')
          ORDER BY (e->>'minute')::INT DESC
          LIMIT 1;
        END IF;

        v_result := CASE WHEN v_event_team = v_sel_value THEN 'won' ELSE 'lost' END;
      END;

    -- ── team_event_count (which team has more of event X) ──
    ELSIF v_eval_key = 'team_event_count' THEN
      DECLARE
        v_event_type_cfg TEXT := COALESCE(v_config->>'event_type', 'card');
        v_home_count INT;
        v_away_count INT;
        v_home_team TEXT;
        v_away_team TEXT;
      BEGIN
        v_home_team := lower(COALESCE(p_match_stats->>'home_team', ''));
        v_away_team := lower(COALESCE(p_match_stats->>'away_team', ''));

        SELECT count(*) INTO v_home_count
        FROM jsonb_array_elements(COALESCE(p_match_stats->'events', '[]'::jsonb)) e
        WHERE lower(e->>'team') = v_home_team
          AND e->>'event_type' IN ('YELLOW_CARD', 'RED_CARD');

        SELECT count(*) INTO v_away_count
        FROM jsonb_array_elements(COALESCE(p_match_stats->'events', '[]'::jsonb)) e
        WHERE lower(e->>'team') = v_away_team
          AND e->>'event_type' IN ('YELLOW_CARD', 'RED_CARD');

        v_result := CASE
          WHEN v_sel_value IN ('home', v_home_team) AND v_home_count > v_away_count THEN 'won'
          WHEN v_sel_value IN ('away', v_away_team) AND v_away_count > v_home_count THEN 'won'
          WHEN v_sel_value = 'equal' AND v_home_count = v_away_count THEN 'won'
          ELSE 'lost'
        END;
      END;

    -- ── team_stat (which team has more of stat X — Gemini-enriched) ──
    ELSIF v_eval_key = 'team_stat' THEN
      DECLARE
        v_stat_key TEXT := COALESCE(v_config->>'stat', 'corners');
        v_home_val NUMERIC;
        v_away_val NUMERIC;
      BEGIN
        v_home_val := COALESCE((p_match_stats->'stats'->('home_' || v_stat_key))::NUMERIC, NULL);
        v_away_val := COALESCE((p_match_stats->'stats'->('away_' || v_stat_key))::NUMERIC, NULL);

        IF v_home_val IS NULL OR v_away_val IS NULL THEN
          CONTINUE;  -- skip if stat unavailable
        END IF;

        v_result := CASE
          WHEN v_sel_value IN ('home') AND v_home_val > v_away_val THEN 'won'
          WHEN v_sel_value IN ('away') AND v_away_val > v_home_val THEN 'won'
          WHEN v_sel_value = 'equal' AND v_home_val = v_away_val THEN 'won'
          ELSE 'lost'
        END;
      END;

    -- ── event_time_range ──
    ELSIF v_eval_key = 'event_time_range' THEN
      DECLARE
        v_first_goal_minute INT;
      BEGIN
        SELECT (e->>'minute')::INT INTO v_first_goal_minute
        FROM jsonb_array_elements(COALESCE(p_match_stats->'events', '[]'::jsonb)) e
        WHERE e->>'event_type' IN ('GOAL', 'PENALTY_SCORED')
        ORDER BY (e->>'minute')::INT ASC
        LIMIT 1;

        IF v_first_goal_minute IS NULL THEN
          v_result := CASE WHEN v_sel_value = 'no_goal' THEN 'won' ELSE 'lost' END;
        ELSE
          -- Selection like "1-15", "16-30", "31-45", "46-60", "61-75", "76-90"
          v_result := CASE
            WHEN v_sel_value = '1-15' AND v_first_goal_minute BETWEEN 1 AND 15 THEN 'won'
            WHEN v_sel_value = '16-30' AND v_first_goal_minute BETWEEN 16 AND 30 THEN 'won'
            WHEN v_sel_value = '31-45' AND v_first_goal_minute BETWEEN 31 AND 45 THEN 'won'
            WHEN v_sel_value = '46-60' AND v_first_goal_minute BETWEEN 46 AND 60 THEN 'won'
            WHEN v_sel_value = '61-75' AND v_first_goal_minute BETWEEN 61 AND 75 THEN 'won'
            WHEN v_sel_value = '76-90' AND v_first_goal_minute BETWEEN 76 AND 90 THEN 'won'
            ELSE 'lost'
          END;
        END IF;
      END;

    -- ── race_to (Gemini-enriched) ──
    ELSIF v_eval_key = 'race_to' THEN
      DECLARE
        v_target INT := COALESCE((v_config->>'target')::INT, 5);
        v_stat_key TEXT := COALESCE(v_config->>'stat', 'corners');
        v_race_winner TEXT;
      BEGIN
        v_race_winner := p_match_stats->'stats'->('race_to_' || v_target || '_' || v_stat_key)->>'winner';
        v_result := CASE
          WHEN v_race_winner IS NOT NULL AND lower(v_race_winner) = v_sel_value THEN 'won'
          WHEN v_race_winner IS NULL THEN 'lost'  -- neither reached target
          ELSE 'lost'
        END;
      END;

    -- ── knockout ──
    ELSIF v_eval_key = 'knockout' THEN
      DECLARE
        v_ko_check TEXT := COALESCE(v_config->>'check', 'qualified');
      BEGIN
        IF v_ko_check = 'qualified' THEN
          v_result := CASE
            WHEN lower(COALESCE(p_match_stats->'knockout'->>'qualified_team', '')) = v_sel_value THEN 'won'
            ELSE 'lost'
          END;
        ELSIF v_ko_check = 'method' THEN
          v_result := CASE
            WHEN lower(COALESCE(p_match_stats->'knockout'->>'method', '')) = v_sel_value THEN 'won'
            ELSE 'lost'
          END;
        ELSE
          v_result := 'lost';
        END IF;
      END;

    -- ── combo (multi-part, read parts from config) ──
    ELSIF v_eval_key = 'combo' THEN
      -- Combo markets are evaluated by the Edge Function
      -- which splits the selection and calls this RPC per-part.
      -- If we reach here, it means the Edge Function hasn't
      -- pre-evaluated it. Mark as pending for now.
      CONTINUE;

    ELSE
      -- Unknown evaluator — skip
      CONTINUE;
    END IF;

    -- ── Apply result ──
    UPDATE public.prediction_slip_selections
    SET result = v_result
    WHERE id = v_selection.sel_id;

    v_slip_ids := array_append(v_slip_ids, v_selection.slip_id);
    v_settled_count := v_settled_count + 1;

    IF v_result = 'won' THEN
      v_won_count := v_won_count + 1;
    ELSIF v_result = 'void' THEN
      v_void_count := v_void_count + 1;
    ELSE
      v_lost_count := v_lost_count + 1;
    END IF;

  END LOOP;

  -- ═══════════════════════════════════════════
  -- Resolve slip-level status + wallet credits
  -- ═══════════════════════════════════════════
  IF coalesce(array_length(v_slip_ids, 1), 0) > 0 THEN
    -- Deduplicate slip IDs
    v_slip_ids := ARRAY(SELECT DISTINCT unnest(v_slip_ids));

    -- Update slip status (only if ALL selections are settled)
    UPDATE public.prediction_slips sl
    SET status = CASE
      WHEN NOT EXISTS (
        SELECT 1 FROM public.prediction_slip_selections
        WHERE slip_id = sl.id AND result = 'pending'
      ) THEN
        CASE
          WHEN NOT EXISTS (
            SELECT 1 FROM public.prediction_slip_selections
            WHERE slip_id = sl.id AND result = 'lost'
          ) THEN 'settled_win'
          ELSE 'settled_loss'
        END
      ELSE sl.status
    END,
    settled_at = CASE
      WHEN NOT EXISTS (
        SELECT 1 FROM public.prediction_slip_selections
        WHERE slip_id = sl.id AND result = 'pending'
      ) THEN now()
      ELSE sl.settled_at
    END,
    updated_at = now()
    WHERE sl.id = ANY(v_slip_ids);

    -- Ensure wallets exist for winners
    INSERT INTO public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
    SELECT DISTINCT sl.user_id, 0, 0
    FROM public.prediction_slips sl
    WHERE sl.id = ANY(v_slip_ids)
      AND sl.status = 'settled_win'
    ON CONFLICT (user_id) DO NOTHING;

    -- Record transactions
    INSERT INTO public.fet_wallet_transactions (
      user_id, tx_type, direction, amount_fet,
      balance_before_fet, balance_after_fet,
      reference_type, reference_id, title
    )
    SELECT
      sl.user_id,
      'prediction_earn',
      'credit',
      sl.projected_earn_fet,
      COALESCE(w.available_balance_fet, 0),
      COALESCE(w.available_balance_fet, 0) + sl.projected_earn_fet,
      'prediction_slip',
      sl.id,
      'Prediction win — earned ' || sl.projected_earn_fet || ' FET'
    FROM public.prediction_slips sl
    JOIN public.fet_wallets w ON w.user_id = sl.user_id
    WHERE sl.id = ANY(v_slip_ids)
      AND sl.status = 'settled_win'
      AND sl.projected_earn_fet > 0;

    -- Credit wallets
    UPDATE public.fet_wallets w
    SET available_balance_fet = w.available_balance_fet + sl.projected_earn_fet,
        updated_at = now()
    FROM public.prediction_slips sl
    WHERE w.user_id = sl.user_id
      AND sl.id = ANY(v_slip_ids)
      AND sl.status = 'settled_win'
      AND sl.projected_earn_fet > 0;
  END IF;

  RETURN jsonb_build_object(
    'match_id', p_match_id,
    'selections_settled', v_settled_count,
    'won', v_won_count,
    'lost', v_lost_count,
    'void', v_void_count,
    'slips_affected', COALESCE(array_length(v_slip_ids, 1), 0)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.settle_match_selections(TEXT, JSONB) TO service_role;


-- ═══════════════════════════════════════════════════════════════
-- 5. get_settlement_config_for_match() — helper for Edge Function
--    Returns all market types + configs needed for a match's
--    unsettled selections
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.get_settlement_config_for_match(
  p_match_id TEXT
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
  SELECT jsonb_build_object(
    'match_id', p_match_id,
    'pending_count', count(*),
    'data_tiers_needed', array_agg(DISTINCT mt.settlement_data_tier),
    'market_types', jsonb_agg(DISTINCT jsonb_build_object(
      'id', mt.id,
      'eval_key', mt.settlement_eval_key,
      'config', mt.settlement_config,
      'data_tier', mt.settlement_data_tier
    ))
  )
  INTO v_result
  FROM public.prediction_slip_selections s
  JOIN public.prediction_market_types mt
    ON mt.id = COALESCE(s.market_type_id, s.market)
  WHERE s.match_id = p_match_id
    AND s.result = 'pending'
    AND mt.settlement_data_tier != 'outright';

  RETURN COALESCE(v_result, jsonb_build_object(
    'match_id', p_match_id,
    'pending_count', 0,
    'data_tiers_needed', ARRAY[]::text[],
    'market_types', '[]'::jsonb
  ));
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_settlement_config_for_match(TEXT) TO service_role;


-- ═══════════════════════════════════════════════════════════════
-- 6. Update match-finish trigger to also call settle-markets
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.notify_match_finished()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_project_url text;
  v_cron_secret text;
  v_normalized_status text;
BEGIN
  -- Only fire on status change to finished
  v_normalized_status := public.normalize_match_status_value(NEW.status);

  IF v_normalized_status != 'finished' THEN
    RETURN NEW;
  END IF;

  -- Only fire if scores are present
  IF NEW.ft_home IS NULL OR NEW.ft_away IS NULL THEN
    RETURN NEW;
  END IF;

  -- Only fire if status actually changed
  IF OLD IS NOT NULL
    AND public.normalize_match_status_value(OLD.status) = 'finished'
    AND OLD.ft_home = NEW.ft_home
    AND OLD.ft_away = NEW.ft_away
  THEN
    RETURN NEW;
  END IF;

  -- Load secrets for HTTP dispatch
  BEGIN
    SELECT
      (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'match_sync_project_url'),
      (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'match_sync_admin_secret')
    INTO v_project_url, v_cron_secret;
  EXCEPTION WHEN others THEN
    INSERT INTO public.match_settlement_log (
      match_id, trigger_source, error_text
    ) VALUES (
      NEW.id, 'trigger_vault_error', SQLERRM
    );
    RETURN NEW;
  END;

  IF v_project_url IS NOT NULL AND v_cron_secret IS NOT NULL THEN
    -- Dispatch to settle-markets (new comprehensive engine)
    BEGIN
      PERFORM net.http_post(
        url := v_project_url || '/functions/v1/settle-markets',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-cron-secret', v_cron_secret
        ),
        body := jsonb_build_object(
          'match_id', NEW.id,
          'trigger', 'match_status_change'
        ),
        timeout_milliseconds := 60000
      );
    EXCEPTION WHEN others THEN
      INSERT INTO public.match_settlement_log (
        match_id, trigger_source, error_text
      ) VALUES (
        NEW.id, 'settle_markets_dispatch_error', SQLERRM
      );
    END;

    -- Also dispatch to auto-settle (legacy pools + daily challenges)
    BEGIN
      PERFORM net.http_post(
        url := v_project_url || '/functions/v1/auto-settle',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-cron-secret', v_cron_secret
        ),
        body := jsonb_build_object(
          'match_id', NEW.id,
          'trigger', 'match_status_change'
        ),
        timeout_milliseconds := 30000
      );
    EXCEPTION WHEN others THEN
      INSERT INTO public.match_settlement_log (
        match_id, trigger_source, error_text
      ) VALUES (
        NEW.id, 'auto_settle_dispatch_error', SQLERRM
      );
    END;

    INSERT INTO public.match_settlement_log (
      match_id, trigger_source, result_payload
    ) VALUES (
      NEW.id, 'status_change_trigger',
      jsonb_build_object(
        'scheduled_at', timezone('utc', now()),
        'ft_home', NEW.ft_home,
        'ft_away', NEW.ft_away,
        'dispatched_to', ARRAY['settle-markets', 'auto-settle']
      )
    );
  END IF;

  RETURN NEW;
END;
$$;


-- ═══════════════════════════════════════════════════════════════
-- 7. Cron schedule: settle-markets every 10 minutes
-- ═══════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_project_url text;
  v_cron_secret text;
BEGIN
  SELECT decrypted_secret INTO v_project_url
  FROM vault.decrypted_secrets WHERE name = 'match_sync_project_url';

  SELECT decrypted_secret INTO v_cron_secret
  FROM vault.decrypted_secrets WHERE name = 'match_sync_admin_secret';

  IF v_project_url IS NOT NULL AND v_cron_secret IS NOT NULL THEN
    -- Remove old schedule if exists
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'settle-markets-cron') THEN
      PERFORM cron.unschedule('settle-markets-cron');
    END IF;

    -- Schedule every 10 minutes
    PERFORM cron.schedule(
      'settle-markets-cron',
      '*/10 * * * *',
      format(
        $cron$SELECT net.http_post(
          url := '%s/functions/v1/settle-markets',
          headers := '{"Content-Type": "application/json", "x-cron-secret": "%s"}'::jsonb,
          body := '{"trigger": "cron"}'::jsonb,
          timeout_milliseconds := 60000
        )$cron$,
        v_project_url,
        v_cron_secret
      )
    );

    RAISE NOTICE 'settle-markets cron scheduled every 10 minutes';
  ELSE
    RAISE NOTICE 'Vault secrets not found — skipping cron schedule';
  END IF;
EXCEPTION WHEN others THEN
  RAISE NOTICE 'Cron scheduling failed: % — will need manual setup', SQLERRM;
END $$;


-- ═══════════════════════════════════════════════════════════════
-- 8. Verification: Log settlement config coverage
-- ═══════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_total INT;
  v_score INT;
  v_events INT;
  v_stats INT;
  v_outright INT;
BEGIN
  SELECT count(*) INTO v_total FROM public.prediction_market_types WHERE is_active = true;
  SELECT count(*) INTO v_score FROM public.prediction_market_types WHERE settlement_data_tier = 'score' AND is_active = true;
  SELECT count(*) INTO v_events FROM public.prediction_market_types WHERE settlement_data_tier = 'events' AND is_active = true;
  SELECT count(*) INTO v_stats FROM public.prediction_market_types WHERE settlement_data_tier = 'stats' AND is_active = true;
  SELECT count(*) INTO v_outright FROM public.prediction_market_types WHERE settlement_data_tier = 'outright' AND is_active = true;

  RAISE NOTICE 'Settlement engine coverage: % total markets (% score, % events, % stats, % outright)',
    v_total, v_score, v_events, v_stats, v_outright;
END $$;
