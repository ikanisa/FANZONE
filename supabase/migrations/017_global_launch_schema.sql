-- ============================================================
-- 017_global_launch_schema.sql
-- Additive schema changes for FANZONE global launch.
-- Extends competitions, adds featured_events, global_challenges,
-- and profile region tracking.
-- ============================================================

BEGIN;

-- -----------------------------------------------------------------
-- 1) Extend competitions for global event architecture
-- -----------------------------------------------------------------

ALTER TABLE public.competitions ADD COLUMN IF NOT EXISTS region TEXT;
ALTER TABLE public.competitions ADD COLUMN IF NOT EXISTS competition_type TEXT;
ALTER TABLE public.competitions ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT false;
ALTER TABLE public.competitions ADD COLUMN IF NOT EXISTS event_tag TEXT;
ALTER TABLE public.competitions ADD COLUMN IF NOT EXISTS start_date DATE;
ALTER TABLE public.competitions ADD COLUMN IF NOT EXISTS end_date DATE;

COMMENT ON COLUMN public.competitions.region IS 'global, africa, europe, americas';
COMMENT ON COLUMN public.competitions.competition_type IS 'league, cup, tournament, friendly, qualifier';
COMMENT ON COLUMN public.competitions.event_tag IS 'Links to featured_events.event_tag (e.g. worldcup2026, ucl-final-2026)';

-- -----------------------------------------------------------------
-- 2) Featured Events table
-- -----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.featured_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  short_name TEXT NOT NULL,
  event_tag TEXT NOT NULL UNIQUE,
  region TEXT NOT NULL DEFAULT 'global'
    CHECK (region IN ('global', 'africa', 'europe', 'americas')),
  competition_id TEXT REFERENCES public.competitions(id),
  start_date TIMESTAMPTZ NOT NULL,
  end_date TIMESTAMPTZ NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  banner_color TEXT,
  description TEXT,
  logo_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT featured_events_date_range CHECK (end_date > start_date)
);

ALTER TABLE public.featured_events ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'featured_events'
      AND policyname = 'Public read featured events'
  ) THEN
    CREATE POLICY "Public read featured events"
      ON public.featured_events
      FOR SELECT
      USING (true);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_featured_events_active
  ON public.featured_events (is_active, start_date, end_date);

CREATE INDEX IF NOT EXISTS idx_featured_events_tag
  ON public.featured_events (event_tag);

-- -----------------------------------------------------------------
-- 3) Global Challenges table (event-scoped prediction challenges)
-- -----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.global_challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_tag TEXT NOT NULL REFERENCES public.featured_events(event_tag),
  name TEXT NOT NULL,
  description TEXT,
  match_ids TEXT[] NOT NULL DEFAULT '{}',
  entry_fee_fet BIGINT NOT NULL DEFAULT 0 CHECK (entry_fee_fet >= 0),
  prize_pool_fet BIGINT NOT NULL DEFAULT 0 CHECK (prize_pool_fet >= 0),
  max_participants INTEGER,
  current_participants INTEGER NOT NULL DEFAULT 0,
  region TEXT NOT NULL DEFAULT 'global'
    CHECK (region IN ('global', 'africa', 'europe', 'americas')),
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('draft', 'open', 'locked', 'settled', 'cancelled')),
  start_at TIMESTAMPTZ,
  end_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.global_challenges ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'global_challenges'
      AND policyname = 'Public read global challenges'
  ) THEN
    CREATE POLICY "Public read global challenges"
      ON public.global_challenges
      FOR SELECT
      USING (true);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_global_challenges_event
  ON public.global_challenges (event_tag, status);

CREATE INDEX IF NOT EXISTS idx_global_challenges_region
  ON public.global_challenges (region, status);

-- -----------------------------------------------------------------
-- 4) Extend profiles with region tracking
-- -----------------------------------------------------------------

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS region TEXT;

COMMENT ON COLUMN public.profiles.region IS
  'Inferred user region: global, africa, europe, americas';

-- -----------------------------------------------------------------
-- 5) Seed initial featured events
-- -----------------------------------------------------------------

INSERT INTO public.featured_events (
  name, short_name, event_tag, region, start_date, end_date,
  is_active, description, banner_color
) VALUES
  (
    'FIFA World Cup 2026',
    'WC 2026',
    'worldcup2026',
    'global',
    '2026-06-11T00:00:00Z',
    '2026-07-19T23:59:59Z',
    true,
    'The 23rd FIFA World Cup across USA, Canada, and Mexico. 48 teams compete for the ultimate prize in football.',
    '#1A237E'
  ),
  (
    'UEFA Champions League Final 2025/26',
    'UCL Final',
    'ucl-final-2026',
    'global',
    '2026-05-20T00:00:00Z',
    '2026-05-31T23:59:59Z',
    true,
    'The pinnacle of European club football. Two titans battle for continental glory.',
    '#1565C0'
  ),
  (
    'Africa Cup of Nations 2025',
    'AFCON 2025',
    'afcon2025',
    'africa',
    '2025-12-21T00:00:00Z',
    '2026-01-18T23:59:59Z',
    true,
    'The continent''s premier national team tournament featuring 24 African nations.',
    '#388E3C'
  ),
  (
    'Copa América 2028',
    'Copa 2028',
    'copa2028',
    'americas',
    '2028-06-01T00:00:00Z',
    '2028-07-14T23:59:59Z',
    false,
    'South America''s premier national team competition.',
    '#F57F17'
  ),
  (
    'CONCACAF Gold Cup 2027',
    'Gold Cup',
    'goldcup2027',
    'americas',
    '2027-06-15T00:00:00Z',
    '2027-07-16T23:59:59Z',
    false,
    'North America, Central America, and Caribbean championship.',
    '#E65100'
  ),
  (
    'CAF Champions League 2025/26',
    'CAFCL',
    'cafcl-2026',
    'africa',
    '2025-08-01T00:00:00Z',
    '2026-06-30T23:59:59Z',
    true,
    'Africa''s premier club competition. The continent''s best battle for continental supremacy.',
    '#2E7D32'
  )
ON CONFLICT (event_tag) DO UPDATE
SET name = EXCLUDED.name,
    short_name = EXCLUDED.short_name,
    region = EXCLUDED.region,
    start_date = EXCLUDED.start_date,
    end_date = EXCLUDED.end_date,
    is_active = EXCLUDED.is_active,
    description = EXCLUDED.description,
    banner_color = EXCLUDED.banner_color,
    updated_at = now();

-- -----------------------------------------------------------------
-- 6) Update existing competitions with region data where possible
-- -----------------------------------------------------------------

UPDATE public.competitions
SET region = CASE
  WHEN country IN ('England', 'Scotland', 'Spain', 'Germany', 'France', 'Italy',
                    'Netherlands', 'Portugal', 'Turkey', 'Malta', 'Switzerland',
                    'Sweden', 'Norway', 'Denmark', 'Poland', 'Belgium',
                    'Austria', 'Greece', 'Czech Republic', 'Romania') THEN 'europe'
  WHEN country IN ('Nigeria', 'Kenya', 'South Africa', 'Egypt', 'Rwanda',
                    'Tanzania', 'Uganda', 'Ghana', 'Morocco', 'Algeria',
                    'Tunisia', 'DR Congo', 'Senegal', 'Cameroon', 'Ethiopia') THEN 'africa'
  WHEN country IN ('United States', 'Canada', 'Mexico', 'Brazil', 'Argentina',
                    'Colombia', 'Chile', 'Peru') THEN 'americas'
  ELSE 'global'
END
WHERE region IS NULL;

COMMIT;
