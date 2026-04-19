-- ============================================================
-- FANZONE: Free Prediction Slips — Tables + RPC + RLS
-- Migration: 008_prediction_slips.sql
--
-- This implements the solo, free (non-staked) prediction feature.
-- Users submit a "slip" with one or more match selections.
-- No FET is staked or deducted. Separate from Pools (staked).
-- ============================================================

-- ======================
-- TABLES
-- ======================

-- Master slip: one per submission
CREATE TABLE IF NOT EXISTS prediction_slips (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status         TEXT NOT NULL DEFAULT 'submitted'
                   CHECK (status IN ('submitted', 'settled_win', 'settled_loss', 'voided')),
  selection_count INT NOT NULL DEFAULT 0,
  projected_earn_fet BIGINT NOT NULL DEFAULT 0,
  submitted_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  settled_at     TIMESTAMPTZ,
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Individual selections within a slip
CREATE TABLE IF NOT EXISTS prediction_slip_selections (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slip_id        UUID NOT NULL REFERENCES prediction_slips(id) ON DELETE CASCADE,
  match_id       TEXT NOT NULL,
  match_name     TEXT NOT NULL DEFAULT '',
  market         TEXT NOT NULL DEFAULT 'match_result'
                   CHECK (market IN ('match_result', 'exact_score', 'over_under', 'btts')),
  selection      TEXT NOT NULL,   -- '1', 'X', '2', '2-1', 'over_2.5', etc.
  potential_earn_fet BIGINT NOT NULL DEFAULT 0,
  result         TEXT DEFAULT 'pending'
                   CHECK (result IN ('pending', 'won', 'lost', 'void')),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_prediction_slips_user
  ON prediction_slips (user_id, submitted_at DESC);

CREATE INDEX IF NOT EXISTS idx_prediction_slip_selections_slip
  ON prediction_slip_selections (slip_id);

CREATE INDEX IF NOT EXISTS idx_prediction_slip_selections_match
  ON prediction_slip_selections (match_id);

-- ======================
-- RLS POLICIES
-- ======================

ALTER TABLE prediction_slips ENABLE ROW LEVEL SECURITY;
ALTER TABLE prediction_slip_selections ENABLE ROW LEVEL SECURITY;

-- Users can read their own slips
CREATE POLICY "Users read own slips"
  ON prediction_slips FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own slips (via RPC only, but policy still needed)
CREATE POLICY "Users insert own slips"
  ON prediction_slips FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can read their own selections
CREATE POLICY "Users read own slip selections"
  ON prediction_slip_selections FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM prediction_slips
      WHERE prediction_slips.id = prediction_slip_selections.slip_id
        AND prediction_slips.user_id = auth.uid()
    )
  );

-- Users can insert selections for their own slips
CREATE POLICY "Users insert own slip selections"
  ON prediction_slip_selections FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM prediction_slips
      WHERE prediction_slips.id = prediction_slip_selections.slip_id
        AND prediction_slips.user_id = auth.uid()
    )
  );

-- ======================
-- RPC: submit_prediction_slip
-- ======================
-- Atomically creates a slip + its selections in one call.
-- No FET deduction — this is the free prediction path.

CREATE OR REPLACE FUNCTION submit_prediction_slip(
  p_selections JSONB
)
RETURNS UUID
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
      COALESCE(v_sel->>'market', 'match_result'),
      v_sel->>'selection',
      COALESCE((v_sel->>'potential_earn_fet')::BIGINT, 0)
    );
  END LOOP;

  RETURN v_slip_id;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION submit_prediction_slip(JSONB) TO authenticated;

-- ======================
-- Updated-at trigger
-- ======================

CREATE OR REPLACE FUNCTION update_prediction_slips_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prediction_slips_updated_at
  BEFORE UPDATE ON prediction_slips
  FOR EACH ROW EXECUTE FUNCTION update_prediction_slips_updated_at();
