-- ============================================================
-- 20260421080000_drop_ghost_tables_and_data_cleanup.sql
--
-- Drops 7 ghost tables discovered during production data audit.
-- These tables exist in the DB but have ZERO Flutter references
-- and ZERO Edge Function references.
--
-- Also removes the duplicate 'premier-league' competition
-- (the app uses 'epl' which has 6,080 matches).
-- ============================================================

-- ──────────────────────────────────────────────────────────────
-- Phase 1: Drop ghost tables
-- ──────────────────────────────────────────────────────────────

-- reward_catalog: 4 rows, 0 Flutter refs — legacy, superseded by marketplace_offers
DROP TABLE IF EXISTS public.reward_catalog CASCADE;

-- reward_offers: 4 rows, 0 Flutter refs — legacy, superseded by marketplace_offers
DROP TABLE IF EXISTS public.reward_offers CASCADE;

-- reward_redemptions: 0 rows, 0 Flutter refs — legacy, superseded by marketplace_redemptions
DROP TABLE IF EXISTS public.reward_redemptions CASCADE;

-- fixture_market_votes: 0 rows, 0 Flutter refs — unused feature
DROP TABLE IF EXISTS public.fixture_market_votes CASCADE;

-- user_notifications: 7 rows, 0 Flutter refs — superseded by notification_log
DROP TABLE IF EXISTS public.user_notifications CASCADE;

-- sync_log: 1 row, 0 Flutter refs — legacy sync tracking
DROP TABLE IF EXISTS public.sync_log CASCADE;

-- prediction_challenge_settlements: 0 rows, 0 Flutter refs
-- superseded by match_settlement_log
DROP TABLE IF EXISTS public.prediction_challenge_settlements CASCADE;

-- whatsapp_otp_delivery_log: 0 rows, 0 Flutter refs — internal
DROP TABLE IF EXISTS public.whatsapp_otp_delivery_log CASCADE;

-- ──────────────────────────────────────────────────────────────
-- Phase 2: Remove duplicate competition
--
-- 'epl' has 6,080 matches — this is the active ID.
-- 'premier-league' has 0 matches — this is a duplicate entry.
-- ──────────────────────────────────────────────────────────────

DELETE FROM public.competitions
WHERE id = 'premier-league'
  AND NOT EXISTS (
    SELECT 1 FROM public.matches
    WHERE competition_id = 'premier-league'
    LIMIT 1
  );

-- ──────────────────────────────────────────────────────────────
-- Phase 3: Mark old finished matches with null scores as
-- 'postponed' (safer than 'cancelled' — avoids trigger issues)
-- These are matches the ingestion pipeline marked as finished
-- but never populated scores for. Most likely data source gaps.
-- ──────────────────────────────────────────────────────────────

UPDATE public.matches
SET status = 'postponed'
WHERE status = 'finished'
  AND ft_home IS NULL
  AND ft_away IS NULL
  AND date < CURRENT_DATE - interval '7 days';

-- ──────────────────────────────────────────────────────────────
-- Phase 4: Verify final state
-- ──────────────────────────────────────────────────────────────

DO $$
DECLARE
  v_tables integer;
  v_remaining integer;
BEGIN
  SELECT count(*) INTO v_tables
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_type = 'BASE TABLE';

  SELECT count(*) INTO v_remaining
  FROM public.matches
  WHERE status = 'finished'
    AND ft_home IS NULL;

  RAISE NOTICE 'Final public table count: %', v_tables;
  RAISE NOTICE 'Remaining finished matches with null scores: %', v_remaining;
END $$;
