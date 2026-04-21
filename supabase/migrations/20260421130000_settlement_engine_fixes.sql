-- ============================================================
-- 20260421130000_settlement_engine_fixes.sql
--
-- Post-deployment fixes for the settlement engine:
--   1. Ensure prediction_slip_selections table exists (widened)
--   2. Widen prediction_slips status constraint
--   3. Fix unmatched market type settlement configs
-- ============================================================


-- ═══════════════════════════════════════════════════════════════
-- 1. Create prediction_slip_selections if not exists (widened)
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.prediction_slip_selections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slip_id UUID NOT NULL REFERENCES public.prediction_slips(id) ON DELETE CASCADE,
  match_id TEXT NOT NULL,
  match_name TEXT NOT NULL DEFAULT '',
  market TEXT NOT NULL DEFAULT 'match_result',
  market_type_id TEXT REFERENCES public.prediction_market_types(id),
  selection TEXT NOT NULL,
  potential_earn_fet BIGINT NOT NULL DEFAULT 0,
  base_fet INT DEFAULT 50,
  result TEXT DEFAULT 'pending'
    CHECK (result IN ('pending', 'won', 'lost', 'void')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_prediction_slip_selections_slip
  ON public.prediction_slip_selections (slip_id);

CREATE INDEX IF NOT EXISTS idx_prediction_slip_selections_match
  ON public.prediction_slip_selections (match_id);

CREATE INDEX IF NOT EXISTS idx_slip_selections_market_type
  ON public.prediction_slip_selections (market_type_id);

CREATE INDEX IF NOT EXISTS idx_slip_selections_result
  ON public.prediction_slip_selections (result)
  WHERE result = 'pending';

ALTER TABLE public.prediction_slip_selections ENABLE ROW LEVEL SECURITY;

-- RLS policies (guarded)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'prediction_slip_selections' AND policyname = 'Users read own slip selections') THEN
    CREATE POLICY "Users read own slip selections"
      ON public.prediction_slip_selections FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM public.prediction_slips
          WHERE public.prediction_slips.id = public.prediction_slip_selections.slip_id
            AND public.prediction_slips.user_id = auth.uid()
        )
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'prediction_slip_selections' AND policyname = 'Users insert own slip selections') THEN
    CREATE POLICY "Users insert own slip selections"
      ON public.prediction_slip_selections FOR INSERT
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM public.prediction_slips
          WHERE public.prediction_slips.id = public.prediction_slip_selections.slip_id
            AND public.prediction_slips.user_id = auth.uid()
        )
      );
  END IF;
END $$;

GRANT ALL ON public.prediction_slip_selections TO service_role;


-- ═══════════════════════════════════════════════════════════════
-- 2. Widen prediction_slips status constraint
-- ═══════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_constraint_name TEXT;
BEGIN
  SELECT conname INTO v_constraint_name
  FROM pg_constraint
  WHERE conrelid = 'public.prediction_slips'::regclass
    AND contype = 'c'
    AND pg_get_constraintdef(oid) ILIKE '%status%';

  IF v_constraint_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.prediction_slips DROP CONSTRAINT %I', v_constraint_name);
  END IF;

  ALTER TABLE public.prediction_slips ADD CONSTRAINT prediction_slips_status_check
    CHECK (status IN ('submitted', 'settled', 'settled_win', 'settled_loss', 'cancelled'));
END $$;

ALTER TABLE public.prediction_slips ADD COLUMN IF NOT EXISTS settled_at TIMESTAMPTZ;


-- ═══════════════════════════════════════════════════════════════
-- 3. Fix settlement configs for market IDs that differ from expected
-- ═══════════════════════════════════════════════════════════════

-- Handicap markets
UPDATE public.prediction_market_types SET settlement_eval_key = 'handicap', settlement_data_tier = 'score', settlement_config = '{"type": "asian", "goals": -0.5}'::jsonb WHERE id = 'asian_handicap_m0_5' AND settlement_config = '{}'::jsonb;
UPDATE public.prediction_market_types SET settlement_eval_key = 'handicap', settlement_data_tier = 'score', settlement_config = '{"type": "asian", "goals": -1}'::jsonb WHERE id = 'asian_handicap_m1_0' AND settlement_config = '{}'::jsonb;
UPDATE public.prediction_market_types SET settlement_eval_key = 'handicap', settlement_data_tier = 'score', settlement_config = '{"type": "asian", "goals": -1.5}'::jsonb WHERE id = 'asian_handicap_m1_5' AND settlement_config = '{}'::jsonb;
UPDATE public.prediction_market_types SET settlement_eval_key = 'handicap', settlement_data_tier = 'score', settlement_config = '{"type": "asian", "goals": 0.5}'::jsonb WHERE id = 'asian_handicap_p0_5' AND settlement_config = '{}'::jsonb;
UPDATE public.prediction_market_types SET settlement_eval_key = 'handicap', settlement_data_tier = 'score', settlement_config = '{"type": "asian", "goals": 1.5}'::jsonb WHERE id = 'asian_handicap_p1_5' AND settlement_config = '{}'::jsonb;
UPDATE public.prediction_market_types SET settlement_eval_key = 'handicap', settlement_data_tier = 'score', settlement_config = '{"type": "3way", "goals": -1}'::jsonb WHERE id = 'three_way_handicap_m1' AND settlement_config = '{}'::jsonb;
UPDATE public.prediction_market_types SET settlement_eval_key = 'handicap', settlement_data_tier = 'score', settlement_config = '{"type": "3way", "goals": 0}'::jsonb WHERE id = 'three_way_handicap_tie' AND settlement_config = '{}'::jsonb;

-- O/U variants
UPDATE public.prediction_market_types SET settlement_eval_key = 'over_under', settlement_config = '{"stat": "total_goals"}'::jsonb WHERE id = 'over_under' AND settlement_config = '{}'::jsonb;
UPDATE public.prediction_market_types SET settlement_eval_key = 'over_under', settlement_data_tier = 'score', settlement_config = '{"stat": "first_half_goals"}'::jsonb WHERE id = 'first_half_goals_ou' AND settlement_config = '{}'::jsonb;
UPDATE public.prediction_market_types SET settlement_eval_key = 'over_under', settlement_data_tier = 'score', settlement_config = '{"stat": "second_half_goals"}'::jsonb WHERE id = 'second_half_goals_ou' AND settlement_config = '{}'::jsonb;

-- Live event markets
UPDATE public.prediction_market_types SET settlement_eval_key = 'player_event', settlement_data_tier = 'events', settlement_config = '{"event_type": "card", "position": "next"}'::jsonb WHERE id = 'next_card' AND settlement_config = '{}'::jsonb;
UPDATE public.prediction_market_types SET settlement_eval_key = 'team_event', settlement_data_tier = 'stats', settlement_config = '{"event_type": "corner", "position": "next"}'::jsonb WHERE id = 'next_corner' AND settlement_config = '{}'::jsonb;
UPDATE public.prediction_market_types SET settlement_eval_key = 'team_event', settlement_data_tier = 'events', settlement_config = '{"event_type": "goal", "position": "next"}'::jsonb WHERE id = 'next_team_to_score' AND settlement_config = '{}'::jsonb;

-- Score specials
UPDATE public.prediction_market_types SET settlement_eval_key = 'exact_score', settlement_config = '{"score_type": "ft", "any_time": true}'::jsonb WHERE id = 'anytime_correct_score' AND settlement_config = '{}'::jsonb;
UPDATE public.prediction_market_types SET settlement_eval_key = 'match_result', settlement_config = '{"score_type": "rest"}'::jsonb WHERE id = 'rest_of_match_winner' AND settlement_config = '{}'::jsonb;
UPDATE public.prediction_market_types SET settlement_eval_key = 'yes_no', settlement_config = '{"check": "win_from_behind"}'::jsonb WHERE id = 'to_win_from_behind' AND settlement_config = '{}'::jsonb;
