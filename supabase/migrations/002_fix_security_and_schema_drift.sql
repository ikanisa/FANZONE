-- ============================================================
-- FANZONE Engagement Tables — CORRECTIVE Migration
-- Fixes: insecure transfer_fet, stale table names, missing guards
-- Run AFTER 001_engagement_tables.sql
-- ============================================================

-- ======================
-- 1) DROP the insecure transfer_fet function
-- ======================
DROP FUNCTION IF EXISTS transfer_fet(UUID, TEXT, INT);

-- ======================
-- 2) Recreate transfer_fet with auth.uid() enforcement
--    - Ignores client-supplied sender_id entirely
--    - Uses auth.uid() as the only trusted identity
--    - Validates amount > 0
--    - Runs inside a serializable transaction block
-- ======================
CREATE OR REPLACE FUNCTION transfer_fet(
  p_recipient_email TEXT,
  p_amount INT
) RETURNS VOID AS $$
DECLARE
  v_sender_id UUID;
  v_recipient_id UUID;
  v_sender_balance BIGINT;
BEGIN
  -- 1. Identity: always use authenticated caller, never trust client
  v_sender_id := auth.uid();
  IF v_sender_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 2. Validate amount
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than zero';
  END IF;

  -- 3. Find recipient
  SELECT id INTO v_recipient_id
  FROM auth.users
  WHERE email = p_recipient_email;

  IF v_recipient_id IS NULL THEN
    RAISE EXCEPTION 'Recipient not found';
  END IF;

  IF v_sender_id = v_recipient_id THEN
    RAISE EXCEPTION 'Cannot transfer to yourself';
  END IF;

  -- 4. Check sender balance (from the REAL table: fet_wallets)
  SELECT available_balance_fet INTO v_sender_balance
  FROM fet_wallets
  WHERE user_id = v_sender_id
  FOR UPDATE; -- row-level lock to prevent race conditions

  IF v_sender_balance IS NULL OR v_sender_balance < p_amount THEN
    RAISE EXCEPTION 'Insufficient balance';
  END IF;

  -- 5. Debit sender
  UPDATE fet_wallets
  SET available_balance_fet = available_balance_fet - p_amount,
      updated_at = now()
  WHERE user_id = v_sender_id;

  -- 6. Credit recipient (create wallet if missing)
  INSERT INTO fet_wallets (user_id, available_balance_fet, locked_balance_fet)
  VALUES (v_recipient_id, p_amount, 0)
  ON CONFLICT (user_id)
  DO UPDATE SET available_balance_fet = fet_wallets.available_balance_fet + p_amount,
                updated_at = now();

  -- 7. Record transactions (in the REAL table: fet_wallet_transactions)
  INSERT INTO fet_wallet_transactions (user_id, tx_type, direction, amount_fet, balance_before_fet, balance_after_fet, reference_type, title)
  VALUES
    (v_sender_id, 'transfer', 'debit', p_amount, v_sender_balance, v_sender_balance - p_amount, 'transfer', 'Transfer to ' || p_recipient_email),
    (v_recipient_id, 'transfer', 'credit', p_amount, COALESCE((SELECT available_balance_fet FROM fet_wallets WHERE user_id = v_recipient_id), 0) - p_amount, COALESCE((SELECT available_balance_fet FROM fet_wallets WHERE user_id = v_recipient_id), 0), 'transfer', 'Transfer received');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ======================
-- 3) DROP stale duplicate tables that don't match real schema
--    The real tables are: fet_wallets, fet_wallet_transactions,
--    prediction_challenges, prediction_challenge_entries,
--    public_leaderboard, challenge_feed
-- ======================
DROP TABLE IF EXISTS challenge_entries CASCADE;
DROP TABLE IF EXISTS challenges CASCADE;
DROP TABLE IF EXISTS wallet_transactions CASCADE;
DROP TABLE IF EXISTS user_wallets CASCADE;
DROP TABLE IF EXISTS leaderboard CASCADE;

-- The following tables may still be useful, keep them:
-- fan_clubs, user_followed_teams, user_followed_competitions
