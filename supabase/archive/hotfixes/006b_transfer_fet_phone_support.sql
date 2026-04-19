-- ============================================================
-- 006_transfer_fet_phone_support.sql
-- Fixes transfer_fet to support phone-based recipient lookup
-- since FANZONE uses WhatsApp phone OTP auth (not email).
-- ============================================================

BEGIN;

-- Replace transfer_fet to accept either phone or email
DROP FUNCTION IF EXISTS transfer_fet(TEXT, INT);

CREATE OR REPLACE FUNCTION transfer_fet(
  p_recipient_identifier TEXT,
  p_amount_fet INT
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
  IF p_amount_fet IS NULL OR p_amount_fet <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than zero';
  END IF;

  -- 3. Find recipient — try phone first (primary auth method), then email
  SELECT id INTO v_recipient_id
  FROM auth.users
  WHERE phone = p_recipient_identifier;

  IF v_recipient_id IS NULL THEN
    SELECT id INTO v_recipient_id
    FROM auth.users
    WHERE email = p_recipient_identifier;
  END IF;

  IF v_recipient_id IS NULL THEN
    RAISE EXCEPTION 'Recipient not found';
  END IF;

  IF v_sender_id = v_recipient_id THEN
    RAISE EXCEPTION 'Cannot transfer to yourself';
  END IF;

  -- 4. Check sender balance
  SELECT available_balance_fet INTO v_sender_balance
  FROM fet_wallets
  WHERE user_id = v_sender_id
  FOR UPDATE; -- row-level lock to prevent race conditions

  IF v_sender_balance IS NULL OR v_sender_balance < p_amount_fet THEN
    RAISE EXCEPTION 'Insufficient balance';
  END IF;

  -- 5. Debit sender
  UPDATE fet_wallets
  SET available_balance_fet = available_balance_fet - p_amount_fet,
      updated_at = now()
  WHERE user_id = v_sender_id;

  -- 6. Credit recipient (create wallet if missing)
  INSERT INTO fet_wallets (user_id, available_balance_fet, locked_balance_fet)
  VALUES (v_recipient_id, p_amount_fet, 0)
  ON CONFLICT (user_id)
  DO UPDATE SET available_balance_fet = fet_wallets.available_balance_fet + p_amount_fet,
                updated_at = now();

  -- 7. Record transactions
  INSERT INTO fet_wallet_transactions (user_id, tx_type, direction, amount_fet, balance_before_fet, balance_after_fet, reference_type, title)
  VALUES
    (v_sender_id, 'transfer', 'debit', p_amount_fet, v_sender_balance, v_sender_balance - p_amount_fet, 'transfer', 'Transfer to ' || p_recipient_identifier),
    (v_recipient_id, 'transfer', 'credit', p_amount_fet, COALESCE((SELECT available_balance_fet FROM fet_wallets WHERE user_id = v_recipient_id), 0) - p_amount_fet, COALESCE((SELECT available_balance_fet FROM fet_wallets WHERE user_id = v_recipient_id), 0), 'transfer', 'Transfer received');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
