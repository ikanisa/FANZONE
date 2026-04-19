-- ============================================================
-- 003_backend_audit_fixes.sql
-- Drop stale transfer_fet overloads, duplicate policies, and
-- restrict prediction entries to authenticated users.
-- ============================================================

-- 1) Drop stale transfer_fet overloads (keep only the production one)
--    Production version: transfer_fet(p_recipient_identifier TEXT, p_amount_fet BIGINT) → jsonb
DROP FUNCTION IF EXISTS transfer_fet(p_recipient_id UUID, p_amount BIGINT);
DROP FUNCTION IF EXISTS transfer_fet(p_recipient_email TEXT, p_amount INT);

-- 2) Drop duplicate follow policies (keep the ones with with_check)
DROP POLICY IF EXISTS followed_teams_own ON user_followed_teams;
DROP POLICY IF EXISTS followed_comps_own ON user_followed_competitions;

-- 3) Restrict prediction_challenge_entries to authenticated users only
DROP POLICY IF EXISTS "Anyone can view entries" ON prediction_challenge_entries;
CREATE POLICY "Authenticated can view entries"
  ON prediction_challenge_entries FOR SELECT TO authenticated USING (true);

-- 4) Restrict prediction_challenge_settlements to authenticated
DROP POLICY IF EXISTS "Anyone can view settlements" ON prediction_challenge_settlements;
CREATE POLICY "Authenticated can view settlements"
  ON prediction_challenge_settlements FOR SELECT TO authenticated USING (true);
