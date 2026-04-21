-- Screenshot-to-Multipliers Pipeline
-- Adds automated screenshot capture + Gemini Vision extraction for betting odds.

-- ─────────────────────────────────────────────────────────────
-- 1) Enhance match_odds_cache with pipeline metadata
-- ─────────────────────────────────────────────────────────────

ALTER TABLE public.match_odds_cache
  ADD COLUMN IF NOT EXISTS source_tier TEXT NOT NULL DEFAULT 'gemini_grounding',
  ADD COLUMN IF NOT EXISTS screenshot_id UUID;

COMMENT ON COLUMN public.match_odds_cache.source_tier IS
  'Which extraction tier provided the odds: screenshot_vision, gemini_grounding, statistical_fallback';

-- ─────────────────────────────────────────────────────────────
-- 2) Screenshots log — every capture + extraction is tracked
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.odds_screenshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- What was captured
  source_url TEXT NOT NULL,
  source_site TEXT NOT NULL DEFAULT 'bet365',
  capture_provider TEXT NOT NULL DEFAULT 'browserless',

  -- Image data
  image_base64 TEXT,
  image_storage_path TEXT,
  viewport_width INTEGER NOT NULL DEFAULT 1440,
  viewport_height INTEGER NOT NULL DEFAULT 900,

  -- Extraction results
  status TEXT NOT NULL DEFAULT 'pending',
  extracted_odds JSONB,
  matched_count INTEGER NOT NULL DEFAULT 0,
  total_fixtures_found INTEGER NOT NULL DEFAULT 0,
  gemini_model TEXT,
  extraction_confidence NUMERIC(5,3),

  -- Errors
  capture_error TEXT,
  extraction_error TEXT,

  -- Timestamps
  captured_at TIMESTAMPTZ,
  extracted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.odds_screenshots ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON TABLE public.odds_screenshots TO anon, authenticated;

DROP POLICY IF EXISTS "Public can view odds screenshots" ON public.odds_screenshots;
CREATE POLICY "Public can view odds screenshots"
ON public.odds_screenshots
FOR SELECT TO anon, authenticated
USING (true);

-- FK from match_odds_cache → odds_screenshots
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'match_odds_cache_screenshot_id_fkey'
  ) THEN
    ALTER TABLE public.match_odds_cache
      ADD CONSTRAINT match_odds_cache_screenshot_id_fkey
      FOREIGN KEY (screenshot_id)
      REFERENCES public.odds_screenshots(id)
      ON DELETE SET NULL;
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────
-- 3) pg_cron: daily screenshot-odds pipeline at 06:00 UTC
-- ─────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

SELECT cron.unschedule('daily-screenshot-odds')
WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'daily-screenshot-odds'
);

SELECT cron.schedule(
  'daily-screenshot-odds',
  '0 6 * * *',
  $$
  SELECT net.http_post(
    url := current_setting('app.settings.supabase_url', true) || '/functions/v1/screenshot-odds-extract',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
    ),
    body := jsonb_build_object(
      'trigger', 'pg_cron',
      'mode', 'auto',
      'scheduled_at', now()::text
    )
  ) AS request_id;
  $$
);

-- Realtime for odds_screenshots
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'odds_screenshots'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.odds_screenshots';
  END IF;
END $$;
