-- ============================================================================
-- FANZONE — RLS Policy Verification Test Suite
-- ============================================================================
-- Run against a Supabase project with test data to verify RLS enforcement.
-- Tests both positive (should succeed) and negative (should be denied) cases.
--
-- Usage:
--   1. Create two test users in Supabase Auth Dashboard
--   2. Replace UUIDs below with actual test user IDs
--   3. Run each section as the appropriate role
--
-- NOTE: These tests are designed to be run via Supabase SQL Editor
-- or psql connected to the project database.
-- ============================================================================

-- ── Test Configuration ──
-- Replace these with actual test user UUIDs from your Supabase auth.users table.
-- DO NOT use production user IDs.
\set TEST_USER_A '00000000-0000-0000-0000-000000000001'
\set TEST_USER_B '00000000-0000-0000-0000-000000000002'


-- ============================================================================
-- 1) PUBLIC READ: Matches, Competitions, Teams
-- ============================================================================
-- These should be readable by anyone (no auth required).

-- POSITIVE: Anon can read matches
SELECT count(*) AS match_count FROM public.matches LIMIT 1;
-- Expected: >= 0 (should not throw permission denied)

-- POSITIVE: Anon can read competitions
SELECT count(*) AS comp_count FROM public.competitions LIMIT 1;

-- POSITIVE: Anon can read teams
SELECT count(*) AS team_count FROM public.teams LIMIT 1;

-- POSITIVE: Anon can read competition_standings
SELECT count(*) AS standing_count FROM public.competition_standings LIMIT 1;

-- POSITIVE: Anon can read public_leaderboard view
SELECT count(*) AS lb_count FROM public.public_leaderboard LIMIT 1;


-- ============================================================================
-- 2) AUTH-ONLY READ: Wallets (own user only)
-- ============================================================================
-- Wallet balance and transactions should only be visible to the owning user.

-- POSITIVE: User A can read own wallet
-- Run as authenticated user A:
-- SELECT balance FROM public.fet_wallets WHERE user_id = :'TEST_USER_A';
-- Expected: Returns their balance

-- NEGATIVE: User A cannot read User B's wallet
-- Run as authenticated user A:
-- SELECT balance FROM public.fet_wallets WHERE user_id = :'TEST_USER_B';
-- Expected: Returns 0 rows (RLS filters it out)

-- NEGATIVE: Anon cannot read any wallet
-- Run as anon:
-- SELECT count(*) FROM public.fet_wallets;
-- Expected: 0 rows


-- ============================================================================
-- 3) AUTH-ONLY READ: Wallet Transactions (own user only)
-- ============================================================================

-- POSITIVE: User A sees own transactions
-- SELECT count(*) FROM public.fet_wallet_transactions WHERE user_id = :'TEST_USER_A';
-- Expected: >= 0

-- NEGATIVE: User A cannot see User B's transactions
-- SELECT count(*) FROM public.fet_wallet_transactions WHERE user_id = :'TEST_USER_B';
-- Expected: 0 rows


-- ============================================================================
-- 4) AUTH WRITE: User Predictions (authenticated only)
-- ============================================================================

-- POSITIVE: Authenticated user can submit a prediction (via RPC)
-- SELECT submit_user_prediction('match-test', 'H', true, true, 2, 1);
-- Expected: Returns prediction id

-- NEGATIVE: Anon cannot submit a prediction
-- SELECT submit_user_prediction('match-test', 'H', true, true, 2, 1);
-- Expected: Permission denied


-- ============================================================================
-- 5) AUTH-ONLY: Notification Log (own user only)
-- ============================================================================

-- POSITIVE: User A sees own notifications
-- SELECT count(*) FROM public.notification_log WHERE user_id = :'TEST_USER_A';
-- Expected: >= 0

-- NEGATIVE: User A cannot see User B's notifications
-- SELECT count(*) FROM public.notification_log WHERE user_id = :'TEST_USER_B';
-- Expected: 0 rows


-- ============================================================================
-- 6) AUTH-ONLY: Match Alert Subscriptions (own user only)
-- ============================================================================

-- POSITIVE: User A can set own alert
-- INSERT INTO public.match_alert_subscriptions (user_id, match_id)
-- VALUES (:'TEST_USER_A', 'match-test')
-- ON CONFLICT (user_id, match_id) DO NOTHING;
-- Expected: Success

-- NEGATIVE: User A cannot insert alert for User B
-- INSERT INTO public.match_alert_subscriptions (user_id, match_id)
-- VALUES (:'TEST_USER_B', 'match-test');
-- Expected: RLS violation


-- ============================================================================
-- 7) AUTH-ONLY: User Favorite Teams / Followed Competitions
-- ============================================================================

-- POSITIVE: User A can follow a team
-- INSERT INTO public.user_favorite_teams (user_id, team_id, team_name)
-- VALUES (:'TEST_USER_A', 'valletta-fc', 'Valletta FC')
-- ON CONFLICT DO NOTHING;

-- NEGATIVE: User A cannot modify User B's follows
-- DELETE FROM public.user_favorite_teams WHERE user_id = :'TEST_USER_B';
-- Expected: 0 rows affected (filtered by RLS)


-- ============================================================================
-- 8) RATE LIMITING: FET Transfers
-- ============================================================================

-- Test that transfer rate limiting enforces 10 per 24h
-- Run 11 times as the same user:
-- SELECT transfer_fet_rate_limited('user-b-phone', 10);
-- Expected: First 10 succeed, 11th throws 'Rate limit exceeded'


-- ============================================================================
-- 9) Prediction Rewards + FET Supply

-- POSITIVE: Authenticated user can read own token rewards
-- SELECT count(*) FROM public.token_rewards WHERE user_id = :'TEST_USER_A';
-- Expected: >= 0

-- NEGATIVE: User A cannot read User B's token rewards
-- SELECT count(*) FROM public.token_rewards WHERE user_id = :'TEST_USER_B';
-- Expected: 0 rows

-- ============================================================================

-- Verify supply cap is enforced
SELECT public.fet_supply_cap() AS supply_cap;
-- Expected: Returns the configured cap (e.g., 10000000)

-- Verify current supply is within cap
SELECT
  COALESCE(SUM(available_balance_fet + locked_balance_fet), 0) AS total_circulating
FROM public.fet_wallets;
-- Expected: Less than supply cap


-- ============================================================================
-- SUMMARY
-- ============================================================================
-- After running all tests, verify:
--   ✅ Public tables (matches, competitions, teams) are readable by anon
--   ✅ Wallet data is isolated per user
--   ✅ Notification log is isolated per user
--   ✅ Match alerts are isolated per user
--   ✅ Prediction submission requires auth
--   ✅ Rate limits prevent abuse on wallet transfers
--   ✅ FET supply cap is enforced
--   ❌ No cross-user data leakage on any auth-gated table
