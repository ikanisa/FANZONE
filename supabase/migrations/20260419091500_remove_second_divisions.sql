-- ============================================================
-- 20260419091500_remove_second_divisions.sql
-- Remove all second-division (tier > 1) competitions and their
-- associated data. FANZONE shows only top-flight domestic
-- leagues (EPL, La Liga, Serie A, Bundesliga, Ligue 1, etc.)
-- plus international/cup competitions.
-- ============================================================

BEGIN;

-- 1) Delete matches belonging to tier > 1 competitions
DELETE FROM public.matches
WHERE competition_id IN (
  SELECT id FROM public.competitions WHERE tier > 1
);

-- 2) Delete standings rows for tier > 1 competitions (only if it's a real table, not a view)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'competition_standings'
      AND table_type = 'BASE TABLE'
  ) THEN
    DELETE FROM public.competition_standings
    WHERE competition_id IN (
      SELECT id FROM public.competitions WHERE tier > 1
    );
  END IF;
END $$;

-- 3) Delete tier > 1 competitions themselves
DELETE FROM public.competitions WHERE tier > 1;

-- 4) Ensure all remaining competitions have tier = 1
--    (null tiers are treated as tier 1 for safety)
UPDATE public.competitions SET tier = 1 WHERE tier IS NULL;

-- 5) Add a CHECK constraint to prevent future tier > 1 inserts
ALTER TABLE public.competitions
  DROP CONSTRAINT IF EXISTS competitions_tier_top_flight_only;

ALTER TABLE public.competitions
  ADD CONSTRAINT competitions_tier_top_flight_only
  CHECK (tier = 1);

COMMIT;
