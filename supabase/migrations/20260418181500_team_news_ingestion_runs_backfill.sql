BEGIN;

CREATE TABLE IF NOT EXISTS public.team_news_ingestion_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id text NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  run_type text NOT NULL DEFAULT 'gemini_grounded_search',
  status text NOT NULL DEFAULT 'running'
    CHECK (status IN ('running', 'completed', 'failed')),
  articles_found integer DEFAULT 0,
  articles_stored integer DEFAULT 0,
  result_summary text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.team_news_ingestion_runs
  ADD COLUMN IF NOT EXISTS run_type text NOT NULL DEFAULT 'gemini_grounded_search';
ALTER TABLE public.team_news_ingestion_runs
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'running';
ALTER TABLE public.team_news_ingestion_runs
  ADD COLUMN IF NOT EXISTS articles_found integer DEFAULT 0;
ALTER TABLE public.team_news_ingestion_runs
  ADD COLUMN IF NOT EXISTS articles_stored integer DEFAULT 0;
ALTER TABLE public.team_news_ingestion_runs
  ADD COLUMN IF NOT EXISTS result_summary text;
ALTER TABLE public.team_news_ingestion_runs
  ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.team_news_ingestion_runs
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'team_news_ingestion_runs_status_check'
      AND conrelid = 'public.team_news_ingestion_runs'::regclass
  ) THEN
    ALTER TABLE public.team_news_ingestion_runs
      ADD CONSTRAINT team_news_ingestion_runs_status_check
      CHECK (status IN ('running', 'completed', 'failed'));
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_team_news_ingestion_runs_team_id
  ON public.team_news_ingestion_runs(team_id, created_at DESC);

ALTER TABLE public.team_news_ingestion_runs ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.team_news_ingestion_runs FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.team_news_ingestion_runs TO service_role;

COMMIT;
