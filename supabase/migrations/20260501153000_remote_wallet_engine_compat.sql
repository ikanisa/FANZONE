-- Consolidated FET wallet engine compatibility for remote projects that kept
-- the older wallet table shape after migration-history squashing.

ALTER TABLE public.fet_wallets
  ADD COLUMN IF NOT EXISTS staked_balance_fet bigint DEFAULT 0,
  ADD COLUMN IF NOT EXISTS pending_balance_fet bigint DEFAULT 0,
  ADD COLUMN IF NOT EXISTS id uuid DEFAULT extensions.gen_random_uuid(),
  ADD COLUMN IF NOT EXISTS balance_available bigint DEFAULT 0,
  ADD COLUMN IF NOT EXISTS balance_staked bigint DEFAULT 0,
  ADD COLUMN IF NOT EXISTS balance_pending bigint DEFAULT 0;

UPDATE public.fet_wallets
SET staked_balance_fet = coalesce(staked_balance_fet, locked_balance_fet, 0),
    pending_balance_fet = coalesce(pending_balance_fet, 0),
    balance_available = coalesce(balance_available, available_balance_fet, 0),
    balance_staked = coalesce(balance_staked, staked_balance_fet, locked_balance_fet, 0),
    balance_pending = coalesce(balance_pending, pending_balance_fet, 0),
    id = coalesce(id, extensions.gen_random_uuid())
WHERE staked_balance_fet IS NULL
   OR pending_balance_fet IS NULL
   OR balance_available IS NULL
   OR balance_staked IS NULL
   OR balance_pending IS NULL
   OR id IS NULL;

ALTER TABLE public.fet_wallets
  ALTER COLUMN staked_balance_fet SET DEFAULT 0,
  ALTER COLUMN staked_balance_fet SET NOT NULL,
  ALTER COLUMN pending_balance_fet SET DEFAULT 0,
  ALTER COLUMN pending_balance_fet SET NOT NULL,
  ALTER COLUMN id SET DEFAULT extensions.gen_random_uuid(),
  ALTER COLUMN balance_available SET DEFAULT 0,
  ALTER COLUMN balance_available SET NOT NULL,
  ALTER COLUMN balance_staked SET DEFAULT 0,
  ALTER COLUMN balance_staked SET NOT NULL,
  ALTER COLUMN balance_pending SET DEFAULT 0,
  ALTER COLUMN balance_pending SET NOT NULL;

ALTER TABLE public.fet_wallet_transactions
  ADD COLUMN IF NOT EXISTS transaction_type text,
  ADD COLUMN IF NOT EXISTS balance_bucket text DEFAULT 'available',
  ADD COLUMN IF NOT EXISTS status text DEFAULT 'posted',
  ADD COLUMN IF NOT EXISTS idempotency_key text,
  ADD COLUMN IF NOT EXISTS entry_id uuid,
  ADD COLUMN IF NOT EXISTS settlement_id uuid,
  ADD COLUMN IF NOT EXISTS created_by uuid,
  ADD COLUMN IF NOT EXISTS wallet_id uuid,
  ADD COLUMN IF NOT EXISTS pool_entry_id uuid;

UPDATE public.fet_wallet_transactions
SET transaction_type = coalesce(transaction_type, tx_type),
    balance_bucket = coalesce(balance_bucket, 'available'),
    status = coalesce(status, 'posted'),
    pool_entry_id = coalesce(pool_entry_id, entry_id)
WHERE transaction_type IS NULL
   OR balance_bucket IS NULL
   OR status IS NULL
   OR pool_entry_id IS NULL;

ALTER TABLE public.fet_wallet_transactions
  ALTER COLUMN balance_bucket SET DEFAULT 'available',
  ALTER COLUMN balance_bucket SET NOT NULL,
  ALTER COLUMN status SET DEFAULT 'posted',
  ALTER COLUMN status SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS fet_wallet_transactions_idempotency_key_idx
ON public.fet_wallet_transactions (idempotency_key)
WHERE idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS fet_wallet_transactions_user_created_idx
ON public.fet_wallet_transactions (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS fet_wallet_transactions_pool_idx
ON public.fet_wallet_transactions (pool_id);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'fet_wallet_transactions_bucket_check'
      AND conrelid = 'public.fet_wallet_transactions'::regclass
  ) THEN
    ALTER TABLE public.fet_wallet_transactions
      ADD CONSTRAINT fet_wallet_transactions_bucket_check
      CHECK (balance_bucket = ANY (ARRAY['available'::text, 'staked'::text, 'pending'::text]))
      NOT VALID;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'fet_wallet_transactions_status_check'
      AND conrelid = 'public.fet_wallet_transactions'::regclass
  ) THEN
    ALTER TABLE public.fet_wallet_transactions
      ADD CONSTRAINT fet_wallet_transactions_status_check
      CHECK (status = ANY (ARRAY['posted'::text, 'pending'::text, 'voided'::text]))
      NOT VALID;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.reconcile_fet_wallet(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_wallet public.fet_wallets%ROWTYPE;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'User id is required';
  END IF;

  INSERT INTO public.fet_wallets (user_id)
  VALUES (p_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  UPDATE public.fet_wallets
  SET staked_balance_fet = coalesce(staked_balance_fet, locked_balance_fet, 0),
      locked_balance_fet = coalesce(staked_balance_fet, locked_balance_fet, 0),
      pending_balance_fet = coalesce(pending_balance_fet, 0),
      balance_available = coalesce(available_balance_fet, 0),
      balance_staked = coalesce(staked_balance_fet, locked_balance_fet, 0),
      balance_pending = coalesce(pending_balance_fet, 0),
      updated_at = timezone('utc', now())
  WHERE user_id = p_user_id
  RETURNING * INTO v_wallet;

  RETURN jsonb_build_object(
    'user_id', p_user_id,
    'available_fet', coalesce(v_wallet.available_balance_fet, 0),
    'staked_fet', coalesce(v_wallet.staked_balance_fet, v_wallet.locked_balance_fet, 0),
    'pending_fet', coalesce(v_wallet.pending_balance_fet, 0),
    'total_fet',
      coalesce(v_wallet.available_balance_fet, 0)
      + coalesce(v_wallet.staked_balance_fet, v_wallet.locked_balance_fet, 0)
      + coalesce(v_wallet.pending_balance_fet, 0)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_wallet_balance(p_user_id uuid DEFAULT NULL::uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_user_id uuid := coalesce(p_user_id, auth.uid());
  v_is_service_role boolean :=
    coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role'
    OR coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb ->> 'role' = 'service_role';
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF v_requester IS DISTINCT FROM v_user_id
     AND NOT v_is_service_role
     AND NOT public.is_active_admin_operator(v_requester) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN public.reconcile_fet_wallet(v_user_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.wallet_post_transaction(
  p_user_id uuid,
  p_transaction_type text,
  p_direction text,
  p_amount_fet bigint,
  p_balance_bucket text DEFAULT 'available'::text,
  p_idempotency_key text DEFAULT NULL::text,
  p_reference_type text DEFAULT NULL::text,
  p_reference_id text DEFAULT NULL::text,
  p_title text DEFAULT NULL::text,
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_order_id uuid DEFAULT NULL::uuid,
  p_match_id text DEFAULT NULL::text,
  p_pool_id uuid DEFAULT NULL::uuid,
  p_entry_id uuid DEFAULT NULL::uuid,
  p_settlement_id uuid DEFAULT NULL::uuid,
  p_venue_id uuid DEFAULT NULL::uuid,
  p_status text DEFAULT 'posted'::text,
  p_created_by uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_wallet public.fet_wallets%ROWTYPE;
  v_existing public.fet_wallet_transactions%ROWTYPE;
  v_tx public.fet_wallet_transactions%ROWTYPE;
  v_bucket text := coalesce(nullif(trim(p_balance_bucket), ''), 'available');
  v_status text := coalesce(nullif(trim(p_status), ''), 'posted');
  v_type text := nullif(trim(coalesce(p_transaction_type, '')), '');
  v_before bigint := 0;
  v_after bigint := 0;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'User id is required';
  END IF;

  IF v_type IS NULL THEN
    RAISE EXCEPTION 'Transaction type is required';
  END IF;

  IF p_direction NOT IN ('credit', 'debit') THEN
    RAISE EXCEPTION 'Transaction direction must be credit or debit';
  END IF;

  IF p_amount_fet IS NULL OR p_amount_fet <= 0 THEN
    RAISE EXCEPTION 'FET amount must be greater than zero';
  END IF;

  IF v_bucket NOT IN ('available', 'staked', 'pending') THEN
    RAISE EXCEPTION 'Unsupported wallet bucket: %', v_bucket;
  END IF;

  IF v_status NOT IN ('posted', 'pending', 'voided') THEN
    RAISE EXCEPTION 'Unsupported wallet transaction status: %', v_status;
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT *
    INTO v_existing
    FROM public.fet_wallet_transactions
    WHERE idempotency_key = p_idempotency_key
    LIMIT 1;

    IF FOUND THEN
      RETURN jsonb_build_object(
        'status', 'idempotent_replay',
        'transaction_id', v_existing.id,
        'user_id', v_existing.user_id,
        'transaction_type', coalesce(v_existing.transaction_type, v_existing.tx_type),
        'amount_fet', v_existing.amount_fet,
        'balance_bucket', v_existing.balance_bucket
      );
    END IF;
  END IF;

  PERFORM public.reconcile_fet_wallet(p_user_id);

  SELECT *
  INTO v_wallet
  FROM public.fet_wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_bucket = 'available' THEN
    v_before := coalesce(v_wallet.available_balance_fet, 0);
  ELSIF v_bucket = 'staked' THEN
    v_before := coalesce(v_wallet.staked_balance_fet, v_wallet.locked_balance_fet, 0);
  ELSE
    v_before := coalesce(v_wallet.pending_balance_fet, 0);
  END IF;

  IF p_direction = 'debit' AND v_status <> 'voided' AND v_before < p_amount_fet THEN
    RAISE EXCEPTION 'Insufficient FET balance'
      USING ERRCODE = 'P0001',
            DETAIL = format('bucket=%s available=%s required=%s', v_bucket, v_before, p_amount_fet);
  END IF;

  v_after := CASE
    WHEN v_status = 'voided' THEN v_before
    WHEN p_direction = 'credit' THEN v_before + p_amount_fet
    ELSE v_before - p_amount_fet
  END;

  IF v_bucket = 'available' THEN
    UPDATE public.fet_wallets
    SET available_balance_fet = v_after,
        balance_available = v_after,
        updated_at = timezone('utc', now())
    WHERE user_id = p_user_id;
  ELSIF v_bucket = 'staked' THEN
    UPDATE public.fet_wallets
    SET staked_balance_fet = v_after,
        locked_balance_fet = v_after,
        balance_staked = v_after,
        updated_at = timezone('utc', now())
    WHERE user_id = p_user_id;
  ELSE
    UPDATE public.fet_wallets
    SET pending_balance_fet = v_after,
        balance_pending = v_after,
        updated_at = timezone('utc', now())
    WHERE user_id = p_user_id;
  END IF;

  INSERT INTO public.fet_wallet_transactions (
    user_id,
    tx_type,
    transaction_type,
    direction,
    amount_fet,
    balance_before_fet,
    balance_after_fet,
    reference_type,
    reference_id,
    source,
    match_id,
    pool_id,
    order_id,
    entry_id,
    pool_entry_id,
    settlement_id,
    venue_id,
    balance_bucket,
    status,
    idempotency_key,
    created_by,
    title,
    metadata
  )
  VALUES (
    p_user_id,
    v_type,
    v_type,
    p_direction,
    p_amount_fet,
    v_before,
    v_after,
    p_reference_type,
    p_reference_id,
    coalesce(p_reference_type, v_type),
    p_match_id,
    p_pool_id,
    p_order_id,
    p_entry_id,
    p_entry_id,
    p_settlement_id,
    p_venue_id,
    v_bucket,
    v_status,
    p_idempotency_key,
    p_created_by,
    p_title,
    coalesce(p_metadata, '{}'::jsonb)
  )
  RETURNING * INTO v_tx;

  RETURN jsonb_build_object(
    'status', 'posted',
    'transaction_id', v_tx.id,
    'user_id', v_tx.user_id,
    'transaction_type', coalesce(v_tx.transaction_type, v_tx.tx_type),
    'direction', v_tx.direction,
    'amount_fet', v_tx.amount_fet,
    'balance_bucket', v_tx.balance_bucket
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.credit_welcome_fet(
  p_user_id uuid DEFAULT NULL::uuid,
  p_idempotency_key text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := coalesce(p_user_id, auth.uid());
  v_amount bigint := greatest(coalesce(public.app_config_bigint('welcome_credit_fet', 50), 50), 0);
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF v_amount = 0 THEN
    RETURN jsonb_build_object('status', 'skipped', 'reason', 'welcome_credit_disabled');
  END IF;

  RETURN public.wallet_post_transaction(
    p_user_id => v_user_id,
    p_transaction_type => 'welcome_credit',
    p_direction => 'credit',
    p_amount_fet => v_amount,
    p_balance_bucket => 'available',
    p_idempotency_key => coalesce(p_idempotency_key, 'welcome_credit:' || v_user_id::text),
    p_reference_type => 'welcome_credit',
    p_reference_id => v_user_id::text,
    p_title => 'Welcome FET',
    p_metadata => jsonb_build_object('credited_once', true)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.credit_fet_for_order(
  p_order_id uuid,
  p_idempotency_key text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_order public.orders%ROWTYPE;
  v_venue public.venues%ROWTYPE;
  v_percent numeric := 0;
  v_amount bigint := 0;
BEGIN
  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF v_order.status::text = 'cancelled'
     OR v_order.payment_status::text NOT IN ('paid', 'partially_paid') THEN
    RETURN jsonb_build_object('status', 'skipped', 'reason', 'order_not_paid', 'order_id', p_order_id);
  END IF;

  SELECT * INTO v_venue
  FROM public.venues
  WHERE id = v_order.venue_id;

  v_percent := coalesce(
    nullif(v_venue.features_json ->> 'fet_reward_percent', '')::numeric,
    v_venue.fet_reward_percent,
    public.app_config_numeric('order_reward_percent_default', 0),
    0
  );
  v_amount := floor(coalesce(v_order.total_amount, 0) * greatest(v_percent, 0))::bigint;

  IF v_amount <= 0 THEN
    RETURN jsonb_build_object('status', 'skipped', 'reason', 'zero_reward', 'order_id', p_order_id);
  END IF;

  RETURN public.wallet_post_transaction(
    p_user_id => v_order.user_id,
    p_transaction_type => 'order_earn',
    p_direction => 'credit',
    p_amount_fet => v_amount,
    p_balance_bucket => 'available',
    p_idempotency_key => coalesce(p_idempotency_key, 'order_earn:' || p_order_id::text),
    p_reference_type => 'order_reward',
    p_reference_id => p_order_id::text,
    p_title => 'Venue order reward',
    p_order_id => p_order_id,
    p_venue_id => v_order.venue_id,
    p_metadata => jsonb_build_object('reward_percent', v_percent)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.credit_order_fet(
  p_order_id uuid,
  p_amount bigint DEFAULT NULL::bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_order public.orders%ROWTYPE;
BEGIN
  IF p_amount IS NULL THEN
    RETURN public.credit_fet_for_order(p_order_id);
  END IF;

  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  RETURN public.wallet_post_transaction(
    p_user_id => v_order.user_id,
    p_transaction_type => 'order_earn',
    p_direction => 'credit',
    p_amount_fet => p_amount,
    p_balance_bucket => 'available',
    p_idempotency_key => 'order_earn:' || p_order_id::text,
    p_reference_type => 'order_reward',
    p_reference_id => p_order_id::text,
    p_title => 'Venue order reward',
    p_order_id => p_order_id,
    p_venue_id => v_order.venue_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.join_match_pool(
  p_pool_id uuid,
  p_camp_id uuid,
  p_amount_fet bigint DEFAULT NULL::bigint,
  p_invite_code text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_pool public.match_pools%ROWTYPE;
  v_camp public.match_pool_camps%ROWTYPE;
  v_invite public.match_pool_invites%ROWTYPE;
  v_entry public.match_pool_entries%ROWTYPE;
  v_amount bigint;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_pool
  FROM public.match_pools
  WHERE id = p_pool_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pool not found';
  END IF;

  IF v_pool.status NOT IN ('open', 'locked', 'live') THEN
    RAISE EXCEPTION 'Pool is not open for entries';
  END IF;

  SELECT * INTO v_camp
  FROM public.match_pool_camps
  WHERE id = p_camp_id
    AND pool_id = p_pool_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pool camp not found';
  END IF;

  v_amount := coalesce(p_amount_fet, v_pool.entry_fee_fet, v_pool.stake_min_fet, 1);
  IF v_amount < v_pool.stake_min_fet OR v_amount > v_pool.stake_max_fet THEN
    RAISE EXCEPTION 'Stake amount is outside pool limits';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.match_pool_entries
    WHERE pool_id = p_pool_id
      AND user_id = v_user_id
      AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'User has already joined this pool';
  END IF;

  PERFORM public.wallet_post_transaction(
    p_user_id => v_user_id,
    p_transaction_type => 'pool_stake',
    p_direction => 'debit',
    p_amount_fet => v_amount,
    p_balance_bucket => 'available',
    p_idempotency_key => 'pool_stake_available:' || p_pool_id::text || ':' || v_user_id::text,
    p_reference_type => 'match_pool_entry',
    p_reference_id => p_pool_id::text,
    p_title => 'Pool stake',
    p_match_id => v_pool.match_id,
    p_pool_id => p_pool_id,
    p_venue_id => v_pool.venue_id
  );

  INSERT INTO public.match_pool_entries (
    pool_id,
    camp_id,
    user_id,
    amount_fet,
    metadata
  )
  VALUES (
    p_pool_id,
    p_camp_id,
    v_user_id,
    v_amount,
    jsonb_build_object('invite_code', p_invite_code)
  )
  RETURNING * INTO v_entry;

  PERFORM public.wallet_post_transaction(
    p_user_id => v_user_id,
    p_transaction_type => 'pool_stake',
    p_direction => 'credit',
    p_amount_fet => v_amount,
    p_balance_bucket => 'staked',
    p_idempotency_key => 'pool_stake_locked:' || v_entry.id::text,
    p_reference_type => 'match_pool_entry',
    p_reference_id => v_entry.id::text,
    p_title => 'Pool stake locked',
    p_match_id => v_pool.match_id,
    p_pool_id => p_pool_id,
    p_entry_id => v_entry.id,
    p_venue_id => v_pool.venue_id
  );

  UPDATE public.match_pool_camps
  SET member_count = member_count + 1,
      total_staked_fet = total_staked_fet + v_amount,
      updated_at = timezone('utc', now())
  WHERE id = p_camp_id;

  UPDATE public.match_pools
  SET total_members = total_members + 1,
      total_staked_fet = total_staked_fet + v_amount,
      updated_at = timezone('utc', now())
  WHERE id = p_pool_id;

  IF p_invite_code IS NOT NULL THEN
    SELECT * INTO v_invite
    FROM public.match_pool_invites
    WHERE pool_id = p_pool_id
      AND invite_code = p_invite_code
      AND status = 'created'
    LIMIT 1;

    IF FOUND
       AND v_invite.inviter_user_id IS DISTINCT FROM v_user_id
       AND coalesce(v_pool.creator_reward_fet, 0) > 0 THEN
      PERFORM public.wallet_post_transaction(
        p_user_id => v_invite.inviter_user_id,
        p_transaction_type => 'creator_reward',
        p_direction => 'credit',
        p_amount_fet => v_pool.creator_reward_fet,
        p_balance_bucket => 'available',
        p_idempotency_key => 'creator_reward:' || v_invite.id::text || ':' || v_entry.id::text,
        p_reference_type => 'match_pool_invite',
        p_reference_id => v_invite.id::text,
        p_title => 'Pool creator reward',
        p_match_id => v_pool.match_id,
        p_pool_id => p_pool_id,
        p_entry_id => v_entry.id,
        p_venue_id => v_pool.venue_id
      );

      UPDATE public.match_pool_invites
      SET invitee_user_id = v_user_id,
          joined_entry_id = v_entry.id,
          status = 'rewarded',
          reward_amount_fet = v_pool.creator_reward_fet,
          joined_at = timezone('utc', now()),
          rewarded_at = timezone('utc', now()),
          updated_at = timezone('utc', now())
      WHERE id = v_invite.id;
    END IF;
  END IF;

  RETURN jsonb_build_object('status', 'joined', 'entry_id', v_entry.id, 'pool_id', p_pool_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.settle_match_pool(p_pool_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_pool public.match_pools%ROWTYPE;
  v_match public.matches%ROWTYPE;
  v_result_camp public.match_pool_camps%ROWTYPE;
  v_settlement public.match_pool_settlements%ROWTYPE;
  v_winner_count bigint := 0;
  v_winning_stake bigint := 0;
  v_total_active bigint := 0;
  v_losing_stake bigint := 0;
  v_bonus_share bigint := 0;
  v_entry record;
BEGIN
  SELECT * INTO v_pool
  FROM public.match_pools
  WHERE id = p_pool_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pool not found';
  END IF;

  IF v_pool.status = 'settled' THEN
    RETURN jsonb_build_object('status', 'already_settled', 'pool_id', p_pool_id, 'settled_at', v_pool.settled_at);
  END IF;

  SELECT * INTO v_settlement
  FROM public.match_pool_settlements
  WHERE pool_id = p_pool_id
  FOR UPDATE;

  IF FOUND AND v_settlement.status = 'completed' THEN
    UPDATE public.match_pools
    SET status = 'settled',
        settled_at = coalesce(settled_at, v_settlement.completed_at, timezone('utc', now()))
    WHERE id = p_pool_id;
    RETURN jsonb_build_object('status', 'already_settled', 'pool_id', p_pool_id, 'settlement_id', v_settlement.id);
  END IF;

  SELECT * INTO v_match
  FROM public.matches
  WHERE id = v_pool.match_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pool match not found';
  END IF;

  IF coalesce(v_match.status, CASE v_match.match_status WHEN 'finished' THEN 'final' ELSE v_match.match_status END) <> 'final'
     AND v_match.match_status <> 'finished' THEN
    RAISE EXCEPTION 'Match is not final';
  END IF;

  IF v_match.result_code IS NULL THEN
    RAISE EXCEPTION 'Match result is missing';
  END IF;

  SELECT * INTO v_result_camp
  FROM public.match_pool_camps
  WHERE pool_id = p_pool_id
    AND result_code = v_match.result_code;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No pool camp maps to the final result';
  END IF;

  SELECT
    count(*) FILTER (WHERE camp_id = v_result_camp.id),
    coalesce(sum(amount_fet) FILTER (WHERE camp_id = v_result_camp.id), 0),
    coalesce(sum(amount_fet), 0)
  INTO v_winner_count, v_winning_stake, v_total_active
  FROM public.match_pool_entries
  WHERE pool_id = p_pool_id
    AND status = 'active';

  v_losing_stake := greatest(v_total_active - v_winning_stake, 0);
  IF v_winner_count > 0 THEN
    v_bonus_share := floor(v_losing_stake / v_winner_count);
  END IF;

  IF v_settlement.id IS NULL THEN
    INSERT INTO public.match_pool_settlements (
      pool_id,
      match_id,
      status,
      result_camp_id,
      winners_count,
      losing_stake_fet,
      payout_per_winner_fet,
      idempotency_key,
      metadata
    )
    VALUES (
      p_pool_id,
      v_pool.match_id,
      'running',
      v_result_camp.id,
      v_winner_count,
      v_losing_stake,
      v_bonus_share,
      'match-pool-settlement-' || p_pool_id::text,
      jsonb_build_object('result_code', v_match.result_code)
    )
    RETURNING * INTO v_settlement;
  ELSE
    UPDATE public.match_pool_settlements
    SET match_id = v_pool.match_id,
        status = 'running',
        result_camp_id = v_result_camp.id,
        winners_count = v_winner_count,
        losing_stake_fet = v_losing_stake,
        payout_per_winner_fet = v_bonus_share,
        metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('result_code', v_match.result_code)
    WHERE id = v_settlement.id
    RETURNING * INTO v_settlement;
  END IF;

  FOR v_entry IN
    SELECT *
    FROM public.match_pool_entries
    WHERE pool_id = p_pool_id
      AND status = 'active'
    ORDER BY created_at, id
  LOOP
    PERFORM public.wallet_post_transaction(
      p_user_id => v_entry.user_id,
      p_transaction_type => 'pool_stake',
      p_direction => 'debit',
      p_amount_fet => v_entry.amount_fet,
      p_balance_bucket => 'staked',
      p_idempotency_key => 'pool_stake_release:' || v_entry.id::text,
      p_reference_type => 'match_pool_entry',
      p_reference_id => v_entry.id::text,
      p_title => 'Pool stake settled',
      p_match_id => v_pool.match_id,
      p_pool_id => p_pool_id,
      p_entry_id => v_entry.id,
      p_settlement_id => v_settlement.id,
      p_venue_id => v_pool.venue_id
    );

    IF v_entry.camp_id = v_result_camp.id THEN
      PERFORM public.wallet_post_transaction(
        p_user_id => v_entry.user_id,
        p_transaction_type => 'pool_win',
        p_direction => 'credit',
        p_amount_fet => v_entry.amount_fet + v_bonus_share,
        p_balance_bucket => 'available',
        p_idempotency_key => 'pool_win:' || v_entry.id::text || ':' || v_settlement.id::text,
        p_reference_type => 'match_pool_settlement',
        p_reference_id => v_settlement.id::text,
        p_title => 'Pool win',
        p_metadata => jsonb_build_object('winning_camp_id', v_result_camp.id, 'bonus_share_fet', v_bonus_share),
        p_match_id => v_pool.match_id,
        p_pool_id => p_pool_id,
        p_entry_id => v_entry.id,
        p_settlement_id => v_settlement.id,
        p_venue_id => v_pool.venue_id
      );

      UPDATE public.match_pool_entries
      SET payout_fet = v_entry.amount_fet + v_bonus_share,
          status = 'won',
          updated_at = timezone('utc', now())
      WHERE id = v_entry.id;
    ELSE
      UPDATE public.match_pool_entries
      SET payout_fet = 0,
          status = 'lost',
          updated_at = timezone('utc', now())
      WHERE id = v_entry.id;
    END IF;
  END LOOP;

  UPDATE public.match_pool_camps
  SET is_winning_camp = (id = v_result_camp.id),
      updated_at = timezone('utc', now())
  WHERE pool_id = p_pool_id;

  UPDATE public.match_pool_settlements
  SET status = 'completed',
      completed_at = timezone('utc', now()),
      total_paid_fet = (v_winning_stake + (v_bonus_share * v_winner_count))
  WHERE id = v_settlement.id
  RETURNING * INTO v_settlement;

  UPDATE public.match_pools
  SET status = 'settled',
      result_camp_id = v_result_camp.id,
      settled_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
  WHERE id = p_pool_id;

  RETURN jsonb_build_object(
    'status', 'settled',
    'pool_id', p_pool_id,
    'settlement_id', v_settlement.id,
    'winners_count', v_winner_count,
    'losing_stake_fet', v_losing_stake,
    'payout_per_winner_fet', v_bonus_share
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.reconcile_fet_wallet(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_wallet_balance(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.wallet_post_transaction(uuid,text,text,bigint,text,text,text,text,text,jsonb,uuid,text,uuid,uuid,uuid,uuid,text,uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.credit_welcome_fet(uuid,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.credit_fet_for_order(uuid,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.credit_order_fet(uuid,bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.join_match_pool(uuid,uuid,bigint,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.settle_match_pool(uuid) TO service_role;
