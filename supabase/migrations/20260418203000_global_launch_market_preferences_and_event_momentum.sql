-- ============================================================
-- 20260418203000_global_launch_market_preferences_and_event_momentum.sql
-- Add explicit user market preferences and seed global launch
-- event momentum for Africa, Europe, and North America.
-- ============================================================

BEGIN;

-- -----------------------------------------------------------------
-- 1) Explicit market preferences
-- -----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.user_market_preferences (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  primary_region TEXT NOT NULL DEFAULT 'global'
    CHECK (primary_region IN ('global', 'africa', 'europe', 'north_america')),
  selected_regions TEXT[] NOT NULL DEFAULT ARRAY['global']::text[],
  focus_event_tags TEXT[] NOT NULL DEFAULT '{}'::text[],
  favorite_competition_ids TEXT[] NOT NULL DEFAULT '{}'::text[],
  follow_world_cup BOOLEAN NOT NULL DEFAULT true,
  follow_champions_league BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.user_market_preferences ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_market_preferences'
      AND policyname = 'Users can read own market preferences'
  ) THEN
    CREATE POLICY "Users can read own market preferences"
      ON public.user_market_preferences
      FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_market_preferences'
      AND policyname = 'Users can insert own market preferences'
  ) THEN
    CREATE POLICY "Users can insert own market preferences"
      ON public.user_market_preferences
      FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_market_preferences'
      AND policyname = 'Users can update own market preferences'
  ) THEN
    CREATE POLICY "Users can update own market preferences"
      ON public.user_market_preferences
      FOR UPDATE
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

GRANT SELECT, INSERT, UPDATE ON public.user_market_preferences TO authenticated;

-- -----------------------------------------------------------------
-- 2) Regional launch metadata for existing event tables
-- -----------------------------------------------------------------

ALTER TABLE public.featured_events
  ADD COLUMN IF NOT EXISTS headline TEXT,
  ADD COLUMN IF NOT EXISTS cta_label TEXT,
  ADD COLUMN IF NOT EXISTS cta_route TEXT,
  ADD COLUMN IF NOT EXISTS priority_score INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS audience_regions TEXT[] NOT NULL DEFAULT ARRAY['global']::text[];

ALTER TABLE public.global_challenges
  ADD COLUMN IF NOT EXISTS slug TEXT,
  ADD COLUMN IF NOT EXISTS priority_score INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS audience_regions TEXT[] NOT NULL DEFAULT ARRAY['global']::text[];

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'global_challenges_slug_key'
  ) THEN
    ALTER TABLE public.global_challenges
      ADD CONSTRAINT global_challenges_slug_key UNIQUE (slug);
  END IF;
END $$;

ALTER TABLE public.featured_events
  DROP CONSTRAINT IF EXISTS featured_events_region_check;

ALTER TABLE public.featured_events
  ADD CONSTRAINT featured_events_region_check
  CHECK (region IN ('global', 'africa', 'europe', 'americas', 'north_america'));

ALTER TABLE public.global_challenges
  DROP CONSTRAINT IF EXISTS global_challenges_region_check;

ALTER TABLE public.global_challenges
  ADD CONSTRAINT global_challenges_region_check
  CHECK (region IN ('global', 'africa', 'europe', 'americas', 'north_america'));

CREATE INDEX IF NOT EXISTS idx_featured_events_priority
  ON public.featured_events (priority_score DESC, start_date);

CREATE INDEX IF NOT EXISTS idx_global_challenges_priority
  ON public.global_challenges (priority_score DESC, start_at);

-- -----------------------------------------------------------------
-- 3) Admin and operational launch metadata
-- These admin tables are optional across environments, so only extend
-- the ones that actually exist on the target project.
-- -----------------------------------------------------------------

DO $$
BEGIN
  IF to_regclass('public.content_banners') IS NOT NULL THEN
    EXECUTE '
      ALTER TABLE public.content_banners
        ADD COLUMN IF NOT EXISTS audience_regions TEXT[] NOT NULL DEFAULT ARRAY[''global'']::text[],
        ADD COLUMN IF NOT EXISTS event_tag TEXT,
        ADD COLUMN IF NOT EXISTS priority_score INTEGER NOT NULL DEFAULT 0
    ';
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.campaigns') IS NOT NULL THEN
    EXECUTE '
      ALTER TABLE public.campaigns
        ADD COLUMN IF NOT EXISTS audience_regions TEXT[] NOT NULL DEFAULT ARRAY[''global'']::text[],
        ADD COLUMN IF NOT EXISTS event_tag TEXT
    ';
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.partners') IS NOT NULL THEN
    EXECUTE '
      ALTER TABLE public.partners
        ADD COLUMN IF NOT EXISTS audience_regions TEXT[] NOT NULL DEFAULT ARRAY[''global'']::text[]
    ';
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.rewards') IS NOT NULL THEN
    EXECUTE '
      ALTER TABLE public.rewards
        ADD COLUMN IF NOT EXISTS audience_regions TEXT[] NOT NULL DEFAULT ARRAY[''global'']::text[]
    ';
  END IF;
END $$;

-- -----------------------------------------------------------------
-- 4) Normalize North America terminology in profile and competition rows
-- -----------------------------------------------------------------

UPDATE public.profiles
SET region = 'north_america'
WHERE region = 'americas'
  AND country_code IN ('US', 'CA', 'MX');

UPDATE public.competitions
SET region = 'north_america'
WHERE region = 'americas'
  AND country IN ('United States', 'Canada', 'Mexico');

-- -----------------------------------------------------------------
-- 5) Global-launch featured events
-- -----------------------------------------------------------------

INSERT INTO public.featured_events (
  name,
  short_name,
  event_tag,
  region,
  competition_id,
  start_date,
  end_date,
  is_active,
  banner_color,
  description,
  headline,
  cta_label,
  cta_route,
  priority_score,
  audience_regions,
  updated_at
) VALUES
  (
    'Road to FIFA World Cup 2026',
    'Road to WC26',
    'road-to-world-cup-2026',
    'global',
    NULL,
    '2026-04-18T00:00:00Z',
    '2026-06-10T23:59:59Z',
    true,
    '#0F7B6C',
    'The global build-up period before kick-off across the USA, Canada, and Mexico. This is the acquisition and habit-forming window for the tournament cycle.',
    'Build global football habit before opening night.',
    'Open Predict',
    '/predict',
    110,
    ARRAY['global', 'africa', 'europe', 'north_america']::text[],
    now()
  ),
  (
    'FIFA World Cup 2026',
    'WC 2026',
    'worldcup2026',
    'global',
    NULL,
    '2026-06-11T00:00:00Z',
    '2026-07-19T23:59:59Z',
    true,
    '#1A237E',
    'The tournament proper across the United States, Canada, and Mexico, with the final on 19 July 2026 in New York New Jersey.',
    'The world comes together in North America.',
    'View Matchday Hub',
    '/',
    120,
    ARRAY['global', 'africa', 'europe', 'north_america']::text[],
    now()
  ),
  (
    'UEFA Champions League Final 2025/26',
    'UCL Final',
    'ucl-final-2026',
    'europe',
    NULL,
    '2026-04-18T00:00:00Z',
    '2026-05-31T23:59:59Z',
    true,
    '#1565C0',
    'Budapest becomes the centre of the European club game as the run-in turns into final-week conversion momentum.',
    'Drive Europe-wide prediction intent before the final on 30 May 2026.',
    'Open Predict',
    '/predict',
    105,
    ARRAY['global', 'europe', 'africa']::text[],
    now()
  ),
  (
    'Africa Fan Momentum 2026',
    'Africa 2026',
    'africa-fan-momentum-2026',
    'africa',
    NULL,
    '2026-04-18T00:00:00Z',
    '2026-07-19T23:59:59Z',
    true,
    '#2E7D32',
    'A continent-first supporter growth window that keeps African club discovery, fan zones, and challenge participation visible during the wider football cycle.',
    'Keep African fan communities visible in a global launch.',
    'Open Clubs',
    '/clubs',
    95,
    ARRAY['africa', 'global']::text[],
    now()
  ),
  (
    'North America Host Cities 2026',
    'Host Cities',
    'north-america-host-cities-2026',
    'north_america',
    NULL,
    '2026-04-18T00:00:00Z',
    '2026-07-19T23:59:59Z',
    true,
    '#E65100',
    'A host-market growth window focused on USA, Canada, and Mexico ahead of and during the World Cup cycle.',
    'Surface host-market energy early across USA, Canada, and Mexico.',
    'Open Matchday Hub',
    '/',
    100,
    ARRAY['north_america', 'global']::text[],
    now()
  )
ON CONFLICT (event_tag) DO UPDATE
SET name = EXCLUDED.name,
    short_name = EXCLUDED.short_name,
    region = EXCLUDED.region,
    competition_id = EXCLUDED.competition_id,
    start_date = EXCLUDED.start_date,
    end_date = EXCLUDED.end_date,
    is_active = EXCLUDED.is_active,
    banner_color = EXCLUDED.banner_color,
    description = EXCLUDED.description,
    headline = EXCLUDED.headline,
    cta_label = EXCLUDED.cta_label,
    cta_route = EXCLUDED.cta_route,
    priority_score = EXCLUDED.priority_score,
    audience_regions = EXCLUDED.audience_regions,
    updated_at = now();

-- -----------------------------------------------------------------
-- 6) Launch challenges seeded for home and predict discovery
-- -----------------------------------------------------------------

INSERT INTO public.global_challenges (
  slug,
  event_tag,
  name,
  description,
  entry_fee_fet,
  prize_pool_fet,
  region,
  status,
  start_at,
  end_at,
  priority_score,
  audience_regions,
  updated_at
) VALUES
  (
    'road-to-world-cup-global-challenge',
    'road-to-world-cup-2026',
    'Road to World Cup Global Challenge',
    'A free global challenge designed to build prediction habit before the opening match on 11 June 2026.',
    0,
    50000,
    'global',
    'open',
    '2026-04-18T00:00:00Z',
    '2026-06-10T23:59:59Z',
    100,
    ARRAY['global', 'africa', 'europe', 'north_america']::text[],
    now()
  ),
  (
    'ucl-final-predictor-2026',
    'ucl-final-2026',
    'UCL Final Predictor',
    'A final-week challenge built for Europe-wide and global fan acquisition in the lead-up to Budapest on 30 May 2026.',
    0,
    15000,
    'europe',
    'open',
    '2026-04-18T00:00:00Z',
    '2026-05-30T18:00:00Z',
    95,
    ARRAY['global', 'europe', 'africa']::text[],
    now()
  ),
  (
    'africa-fan-momentum-challenge',
    'africa-fan-momentum-2026',
    'Africa Fan Momentum Challenge',
    'A free challenge tuned for African supporter growth, club discovery, and repeat participation.',
    0,
    12000,
    'africa',
    'open',
    '2026-04-18T00:00:00Z',
    '2026-07-19T23:59:59Z',
    90,
    ARRAY['africa', 'global']::text[],
    now()
  ),
  (
    'north-america-host-cities-challenge',
    'north-america-host-cities-2026',
    'North America Host Cities Challenge',
    'A free challenge designed for USA, Canada, and Mexico momentum as host-market attention accelerates.',
    0,
    12000,
    'north_america',
    'open',
    '2026-04-18T00:00:00Z',
    '2026-07-19T23:59:59Z',
    92,
    ARRAY['north_america', 'global']::text[],
    now()
  )
ON CONFLICT (slug) DO UPDATE
SET event_tag = EXCLUDED.event_tag,
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    entry_fee_fet = EXCLUDED.entry_fee_fet,
    prize_pool_fet = EXCLUDED.prize_pool_fet,
    region = EXCLUDED.region,
    status = EXCLUDED.status,
    start_at = EXCLUDED.start_at,
    end_at = EXCLUDED.end_at,
    priority_score = EXCLUDED.priority_score,
    audience_regions = EXCLUDED.audience_regions,
    updated_at = now();

COMMIT;
