BEGIN;

-- ============================================================
-- 20260421060000_seed_data_gap_feature_flags.sql
--
-- Seeds feature flags for data-gap features as disabled.
-- These tabs are now gated in the Flutter app and will only
-- show once the data pipelines are built to populate them.
-- ============================================================

-- Ensure the feature flags exist as disabled
INSERT INTO public.feature_flags (key, market, platform, enabled, rollout_pct)
VALUES
  ('ai_analysis', 'global', 'all', false, 0),
  ('advanced_stats', 'global', 'all', false, 0)
ON CONFLICT (key, market, platform) DO NOTHING;

-- Also ensure these flags are present for admin visibility
INSERT INTO public.feature_flags (key, market, platform, enabled, rollout_pct)
VALUES
  ('match_lineups', 'global', 'all', true, 100),
  ('match_alerts', 'global', 'all', true, 100)
ON CONFLICT (key, market, platform) DO NOTHING;

COMMIT;
