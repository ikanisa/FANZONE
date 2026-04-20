BEGIN;

-- ============================================================
-- 20260421050000_table_consolidation_cleanup.sql
--
-- Table consolidation based on full audit of 88 tables.
-- Cross-referenced every table against Flutter (lib/) and
-- Edge Functions (supabase/functions/).
--
-- Phase 1: Safe drops (zero references anywhere)
-- Phase 2: Merge duplicate notification preferences
-- Phase 3: Drop unused admin_feature_flags (superseded)
-- Phase 4: Drop legacy redemptions table
-- Phase 5: Deprecation comments on rewards/partners
-- ============================================================

-- ==================================================================
-- Phase 1: Drop tables with ZERO references in Flutter + Edge Functions
-- ==================================================================

-- 1a. app_config_remote — 0 Flutter refs, 0 Edge refs, 0 SQL function refs
DROP TABLE IF EXISTS public.app_config_remote CASCADE;

-- 1b. app_preferences — 0 Flutter refs, 0 Edge refs
DROP TABLE IF EXISTS public.app_preferences CASCADE;

-- 1c. content_banners — 0 Flutter refs, 0 Edge refs
DROP TABLE IF EXISTS public.content_banners CASCADE;

-- 1d. campaigns — 0 Flutter refs, 0 Edge refs
DROP TABLE IF EXISTS public.campaigns CASCADE;

-- 1e. country_league_catalog — 0 Flutter refs, 0 Edge refs
--     Overlaps with competitions table which is fully used
DROP TABLE IF EXISTS public.country_league_catalog CASCADE;

-- 1f. feed_rate_limits — 0 Flutter refs, 0 Edge refs
--     Rate limiting is handled by the general rate_limits table
DROP TABLE IF EXISTS public.feed_rate_limits CASCADE;

-- 1g. competition_seasons — 0 Flutter refs, 0 Edge refs
--     Redundant with leaderboard_seasons which IS used
DROP TABLE IF EXISTS public.competition_seasons CASCADE;

-- 1h. user_followed_teams — 0 Flutter refs, 0 Edge refs
--     Duplicate concept; Flutter uses user_favorite_teams instead
DROP TABLE IF EXISTS public.user_followed_teams CASCADE;

-- ==================================================================
-- Phase 2: Merge duplicate notification preferences
--
-- notification_preferences (from 20260418031500):
--   Columns: goal_alerts, pool_updates, daily_challenge, wallet_activity,
--            community_news, marketing
--   → Flutter queries THIS one (notification_settings_gateway.dart)
--
-- user_notification_preferences (from 20260421020000):
--   Columns: push_enabled, match_alerts_enabled, pool_results_enabled,
--            community_updates_enabled, marketing_enabled
--   → ZERO Flutter refs — this is the duplicate
--
-- Strategy: Drop user_notification_preferences.
--          If any data exists, we can't auto-merge because schemas differ.
--          notification_preferences is the source of truth.
-- ==================================================================

DROP TABLE IF EXISTS public.user_notification_preferences CASCADE;

-- ==================================================================
-- Phase 3: Drop admin_feature_flags (superseded by feature_flags)
--
-- admin_feature_flags: simple key/is_enabled (from 006)
-- feature_flags: key + market + platform + rollout_pct (from 20260420010000)
-- Flutter queries feature_flags (11 refs). admin_feature_flags has 0 refs.
-- ==================================================================

-- Migrate any flags that exist in admin_feature_flags but not feature_flags
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = 'public'
             AND table_name = 'admin_feature_flags')
    AND EXISTS (SELECT 1 FROM information_schema.tables
                WHERE table_schema = 'public'
                AND table_name = 'feature_flags')
  THEN
    INSERT INTO public.feature_flags (key, market, platform, enabled, rollout_pct)
    SELECT
      aff.key,
      'global',
      'all',
      aff.is_enabled,
      100
    FROM public.admin_feature_flags aff
    WHERE NOT EXISTS (
      SELECT 1 FROM public.feature_flags ff
      WHERE ff.key = aff.key AND ff.market = 'global'
    );
  END IF;
END $$;

DROP TABLE IF EXISTS public.admin_feature_flags CASCADE;

-- ==================================================================
-- Phase 4: Drop legacy redemptions table
--
-- Flutter wallet_gateway.dart queries marketplace_redemptions (not redemptions)
-- The redemptions table from 006_admin_infrastructure is the old schema
-- with FK to rewards.id — which we are deprecating
-- ==================================================================

DROP TABLE IF EXISTS public.redemptions CASCADE;

-- ==================================================================
-- Phase 5: Deprecation comments on legacy admin tables
-- rewards + partners are still referenced by admin SQL RPCs.
-- They will be cleaned up when admin panel is migrated.
-- ==================================================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = 'public' AND table_name = 'rewards')
  THEN
    COMMENT ON TABLE public.rewards IS
      '⚠️ DEPRECATED — Flutter uses marketplace_offers instead. '
      'Kept temporarily because admin SQL RPCs still reference it. '
      'TODO: migrate admin RPCs to marketplace_offers, then DROP.';
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = 'public' AND table_name = 'partners')
  THEN
    COMMENT ON TABLE public.partners IS
      '⚠️ DEPRECATED — Flutter uses marketplace_partners instead. '
      'Kept temporarily because admin SQL RPCs still reference it. '
      'TODO: migrate admin RPCs to marketplace_partners, then DROP.';
  END IF;
END $$;

-- ==================================================================
-- Phase 6: Verify final state
-- ==================================================================

DO $$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*) INTO v_count
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_type = 'BASE TABLE';

  RAISE NOTICE 'Final public table count: %', v_count;
END $$;

COMMIT;
