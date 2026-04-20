-- ============================================================
-- 20260421090000_deep_data_cleanup_phase2.sql
--
-- Deep cleanup based on production data audit:
--
-- 1. DROP football_fixtures (3,698 rows) — DUPLICATE of matches
--    Different ID format, same data, 0 Flutter/Edge Function refs.
--    Created outside migrations (via Supabase dashboard).
--
-- 2. DROP fixture_market_cache (45 rows) — unused prediction cache
--    0 Flutter/Edge refs. Not in any migration file.
--
-- 3. DROP public_fixture_markets (3,698 rows — VIEW on football_fixtures)
--    0 Flutter/Edge refs. The app uses matches_live_view instead.
--
-- 4. DROP partners (4 rows) — DUPLICATE of marketplace_partners
--    0 Flutter refs. marketplace_partners has 2 rows + is the 
--    canonical table referenced by marketplace_offers + admin RPCs.
--
-- 5. DROP prediction_slip_selections (0 rows) — child of prediction_slips
--    0 Flutter refs. prediction_slips IS used by Flutter but
--    selections table is not referenced.
--
-- 6. KEEP fan_clubs — it's a VIEW used by wallet_gateway.dart
--    but it returns empty [] because no active teams have supporters.
--    Action: verified it's a VIEW (not a table), leave it.
--
-- 7. KEEP prediction_slips — used by prediction_slip_gateway.dart
--
-- 8. KEEP team_crest_metadata, team_crest_fetch_runs — used by
--    gemini-team-crests Edge Function (pipeline tables)
--
-- 9. KEEP team_aliases, team_competitions, team_catalog_entries —
--    these are views/junction tables powering search and catalog
--
-- 10. KEEP matches_live_view — VIEW used by match_listing_gateway
-- ============================================================

-- ──────────────────────────────────────────────────────────────
-- Phase 1: Drop tables created outside migrations (dashboard)
-- These have NO migration file and NO app references.
-- ──────────────────────────────────────────────────────────────

-- public_fixture_markets is likely a VIEW on football_fixtures
-- Drop it first to avoid dependency issues
DROP VIEW IF EXISTS public.public_fixture_markets CASCADE;

-- football_fixtures: 3,698 rows, DUPLICATE of matches table.
-- Uses numeric fixture_id vs matches' text ID format.
-- Created via Supabase Dashboard, not in any migration.
DROP TABLE IF EXISTS public.football_fixtures CASCADE;

-- fixture_market_cache: 45 rows, betting market cache.
-- Not referenced by any Flutter code or Edge Function.
-- Created via Dashboard.
DROP TABLE IF EXISTS public.fixture_market_cache CASCADE;

-- ──────────────────────────────────────────────────────────────
-- Phase 2: Drop legacy 'partners' table
-- DUPLICATE of marketplace_partners which is the canonical table.
-- partners: 4 rows (same 4 partners as marketplace_partners)
-- 0 Flutter refs, 0 Edge Function refs.
-- marketplace_partners is referenced by admin RPCs + seed.
-- ──────────────────────────────────────────────────────────────

-- First drop any FK constraints pointing to partners
ALTER TABLE IF EXISTS public.rewards
  DROP CONSTRAINT IF EXISTS rewards_partner_id_fkey;

DROP TABLE IF EXISTS public.partners CASCADE;

-- Also drop the deprecated 'rewards' table since its FK was
-- to partners (which we just dropped). rewards has 0 Flutter refs
-- and is superseded by marketplace_offers.
DROP TABLE IF EXISTS public.rewards CASCADE;

-- ──────────────────────────────────────────────────────────────
-- Phase 3: Drop unused child table
-- prediction_slip_selections: 0 rows, 0 Flutter refs.
-- Parent table prediction_slips IS used by Flutter.
-- ──────────────────────────────────────────────────────────────

DROP TABLE IF EXISTS public.prediction_slip_selections CASCADE;

-- ──────────────────────────────────────────────────────────────
-- Phase 4: Historical WC competitions (wc-2010 to wc-2022)
-- CANNOT be deleted — FK constraint from thousands of matches.
-- They remain in the DB but the Flutter app should filter
-- competitions to show only current-season ones.
-- ──────────────────────────────────────────────────────────────
-- No action needed here.

-- ──────────────────────────────────────────────────────────────
-- Phase 5: Verify final state
-- ──────────────────────────────────────────────────────────────

DO $$
DECLARE
  v_tables integer;
  v_views integer;
  v_competitions integer;
BEGIN
  SELECT count(*) INTO v_tables
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_type = 'BASE TABLE';

  SELECT count(*) INTO v_views
  FROM information_schema.views
  WHERE table_schema = 'public';

  SELECT count(*) INTO v_competitions
  FROM public.competitions;

  RAISE NOTICE 'Final table count: %', v_tables;
  RAISE NOTICE 'Final view count: %', v_views;
  RAISE NOTICE 'Final competition count: %', v_competitions;
END $$;
