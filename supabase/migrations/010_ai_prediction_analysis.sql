-- ============================================================
-- 010_ai_prediction_analysis.sql
-- Pre-match AI analysis table for Gemini-generated predictions.
-- Phase 2: Data & Intelligence
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.match_ai_analysis (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id TEXT NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  analysis_type TEXT NOT NULL DEFAULT 'pre_match',

  -- Structured predictions
  predicted_outcome TEXT,             -- '1', 'X', '2'
  confidence_score NUMERIC(3,2)
    CHECK (confidence_score BETWEEN 0 AND 1),
  predicted_score_home INT,
  predicted_score_away INT,

  -- Form analysis
  home_form_summary TEXT,             -- "W-W-D-L-W (last 5)"
  away_form_summary TEXT,
  h2h_summary TEXT,                   -- "Home team won 3 of last 5"

  -- Key factors
  key_factors JSONB DEFAULT '[]',     -- [{factor, impact, description}]

  -- Full narrative
  analysis_narrative TEXT,            -- 2-3 paragraph AI analysis

  -- Metadata
  model_version TEXT DEFAULT 'gemini-2.0-flash',
  generated_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ,             -- After kickoff, analysis is archived

  UNIQUE(match_id, analysis_type)
);

ALTER TABLE public.match_ai_analysis ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read AI analysis"
  ON public.match_ai_analysis FOR SELECT USING (true);

-- Write is service_role only (edge function: gemini-match-analysis)

CREATE INDEX IF NOT EXISTS idx_match_ai_analysis_match
  ON public.match_ai_analysis(match_id);
CREATE INDEX IF NOT EXISTS idx_match_ai_analysis_upcoming
  ON public.match_ai_analysis(match_id, analysis_type)
  WHERE expires_at > now();

COMMIT;
