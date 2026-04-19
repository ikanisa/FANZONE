-- Align the app's canonical sports tables with the live-update pipeline.
-- 1) Publish live tables to Supabase Realtime so Flutter stream providers work.
-- 2) Add a match-keyed odds cache table because public.matches does not contain
--    home/draw/away multiplier columns in the deployed database.

CREATE TABLE IF NOT EXISTS public.match_odds_cache (
  match_id TEXT PRIMARY KEY REFERENCES public.matches(id) ON DELETE CASCADE,
  home_multiplier NUMERIC(10,3) NOT NULL,
  draw_multiplier NUMERIC(10,3) NOT NULL,
  away_multiplier NUMERIC(10,3) NOT NULL,
  provider TEXT NOT NULL DEFAULT 'google_gemini_search',
  source_payload JSONB,
  refreshed_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.match_odds_cache ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON TABLE public.match_odds_cache TO anon, authenticated;

DROP POLICY IF EXISTS "Public can view match odds cache" ON public.match_odds_cache;
CREATE POLICY "Public can view match odds cache"
ON public.match_odds_cache
FOR SELECT
TO anon, authenticated
USING (true);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'matches'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.matches';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'live_match_events'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.live_match_events';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'match_odds_cache'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.match_odds_cache';
  END IF;
END
$$;
