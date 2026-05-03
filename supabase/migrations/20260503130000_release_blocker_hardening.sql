-- Release blocker hardening for venue-linked pools, eligibility settlement,
-- venue FET wallets, centralized game sessions, and TV screen state.

-- ---------------------------------------------------------------------------
-- Fan ID immutability and collision safety.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.assign_profile_fan_id()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_seed text;
  v_candidate text;
  v_attempt integer := 0;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.fan_id ~ '^\d{6}$' THEN
    NEW.fan_id := OLD.fan_id;
    RETURN NEW;
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('profiles.fan_id'));

  v_seed := COALESCE(NEW.user_id::text, NEW.id::text, extensions.gen_random_uuid()::text);

  LOOP
    v_candidate := public.generate_profile_fan_id(
      v_seed,
      v_attempt,
      COALESCE(NEW.id, NEW.user_id)
    );

    EXIT WHEN NOT EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.fan_id = v_candidate
        AND p.id IS DISTINCT FROM NEW.id
    );

    v_attempt := v_attempt + 1;
    IF v_attempt > 50 THEN
      RAISE EXCEPTION 'Could not allocate unique fan ID';
    END IF;
  END LOOP;

  NEW.fan_id := v_candidate;
  RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- Venue wallet ledger.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.venue_fet_wallets (
  venue_id uuid PRIMARY KEY REFERENCES public.venues(id) ON DELETE CASCADE,
  available_balance_fet bigint NOT NULL DEFAULT 0,
  staked_balance_fet bigint NOT NULL DEFAULT 0,
  pending_balance_fet bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT venue_fet_wallets_available_nonnegative CHECK (available_balance_fet >= 0),
  CONSTRAINT venue_fet_wallets_staked_nonnegative CHECK (staked_balance_fet >= 0),
  CONSTRAINT venue_fet_wallets_pending_nonnegative CHECK (pending_balance_fet >= 0)
);

CREATE TABLE IF NOT EXISTS public.venue_fet_wallet_transactions (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  venue_id uuid NOT NULL REFERENCES public.venues(id) ON DELETE CASCADE,
  transaction_type text NOT NULL,
  direction text NOT NULL,
  amount_fet bigint NOT NULL,
  balance_bucket text NOT NULL DEFAULT 'available',
  balance_before_fet bigint NOT NULL,
  balance_after_fet bigint NOT NULL,
  reference_type text,
  reference_id text,
  pool_id uuid REFERENCES public.match_pools(id) ON DELETE SET NULL,
  game_session_id uuid,
  idempotency_key text,
  title text,
  status text NOT NULL DEFAULT 'posted',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT venue_fet_wallet_transactions_amount_positive CHECK (amount_fet > 0),
  CONSTRAINT venue_fet_wallet_transactions_direction_check CHECK (direction = ANY (ARRAY['credit', 'debit'])),
  CONSTRAINT venue_fet_wallet_transactions_bucket_check CHECK (balance_bucket = ANY (ARRAY['available', 'staked', 'pending'])),
  CONSTRAINT venue_fet_wallet_transactions_status_check CHECK (status = ANY (ARRAY['posted', 'pending', 'voided']))
);

CREATE UNIQUE INDEX IF NOT EXISTS venue_fet_wallet_transactions_idempotency_idx
  ON public.venue_fet_wallet_transactions (idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS venue_fet_wallet_transactions_venue_created_idx
  ON public.venue_fet_wallet_transactions (venue_id, created_at DESC);

DROP TRIGGER IF EXISTS set_venue_fet_wallets_updated_at ON public.venue_fet_wallets;
CREATE TRIGGER set_venue_fet_wallets_updated_at
BEFORE UPDATE ON public.venue_fet_wallets
FOR EACH ROW
EXECUTE FUNCTION public.venue_set_updated_at();

ALTER TABLE public.venue_fet_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.venue_fet_wallet_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS venue_fet_wallets_select_staff ON public.venue_fet_wallets;
CREATE POLICY venue_fet_wallets_select_staff
ON public.venue_fet_wallets
FOR SELECT
TO authenticated
USING (public.sports_bar_is_admin() OR public.venue_user_has_role(venue_id));

DROP POLICY IF EXISTS venue_fet_wallet_transactions_select_staff ON public.venue_fet_wallet_transactions;
CREATE POLICY venue_fet_wallet_transactions_select_staff
ON public.venue_fet_wallet_transactions
FOR SELECT
TO authenticated
USING (public.sports_bar_is_admin() OR public.venue_user_has_role(venue_id));

CREATE OR REPLACE FUNCTION public.venue_wallet_post_transaction(
  p_venue_id uuid,
  p_transaction_type text,
  p_direction text,
  p_amount_fet bigint,
  p_balance_bucket text DEFAULT 'available',
  p_idempotency_key text DEFAULT NULL,
  p_reference_type text DEFAULT NULL,
  p_reference_id text DEFAULT NULL,
  p_title text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_pool_id uuid DEFAULT NULL,
  p_game_session_id uuid DEFAULT NULL,
  p_status text DEFAULT 'posted',
  p_created_by uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_wallet public.venue_fet_wallets%ROWTYPE;
  v_existing public.venue_fet_wallet_transactions%ROWTYPE;
  v_tx public.venue_fet_wallet_transactions%ROWTYPE;
  v_bucket text := coalesce(nullif(trim(p_balance_bucket), ''), 'available');
  v_status text := coalesce(nullif(trim(p_status), ''), 'posted');
  v_type text := nullif(trim(coalesce(p_transaction_type, '')), '');
  v_before bigint := 0;
  v_after bigint := 0;
BEGIN
  IF p_venue_id IS NULL THEN
    RAISE EXCEPTION 'Venue id is required';
  END IF;

  IF coalesce(auth.role(), '') <> 'service_role'
     AND NOT public.sports_bar_is_admin()
     AND NOT public.venue_user_has_role(p_venue_id, ARRAY['owner', 'manager']::public.venue_user_role[]) THEN
    RAISE EXCEPTION 'Only venue managers can mutate venue wallet entries';
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
    RAISE EXCEPTION 'Unsupported venue wallet bucket: %', v_bucket;
  END IF;

  IF v_status NOT IN ('posted', 'pending', 'voided') THEN
    RAISE EXCEPTION 'Unsupported venue wallet transaction status: %', v_status;
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT *
    INTO v_existing
    FROM public.venue_fet_wallet_transactions
    WHERE idempotency_key = p_idempotency_key
    LIMIT 1;

    IF FOUND THEN
      RETURN jsonb_build_object(
        'status', 'idempotent_replay',
        'transaction_id', v_existing.id,
        'venue_id', v_existing.venue_id,
        'transaction_type', v_existing.transaction_type,
        'amount_fet', v_existing.amount_fet,
        'balance_bucket', v_existing.balance_bucket
      );
    END IF;
  END IF;

  INSERT INTO public.venue_fet_wallets (venue_id)
  VALUES (p_venue_id)
  ON CONFLICT (venue_id) DO NOTHING;

  SELECT *
  INTO v_wallet
  FROM public.venue_fet_wallets
  WHERE venue_id = p_venue_id
  FOR UPDATE;

  v_before := CASE v_bucket
    WHEN 'available' THEN v_wallet.available_balance_fet
    WHEN 'staked' THEN v_wallet.staked_balance_fet
    ELSE v_wallet.pending_balance_fet
  END;

  IF p_direction = 'debit' AND v_status <> 'voided' AND v_before < p_amount_fet THEN
    RAISE EXCEPTION 'Insufficient venue FET balance'
      USING ERRCODE = 'P0001',
            DETAIL = format('venue_id=%s bucket=%s available=%s required=%s', p_venue_id, v_bucket, v_before, p_amount_fet);
  END IF;

  v_after := CASE
    WHEN v_status = 'voided' THEN v_before
    WHEN p_direction = 'credit' THEN v_before + p_amount_fet
    ELSE v_before - p_amount_fet
  END;

  IF v_bucket = 'available' THEN
    UPDATE public.venue_fet_wallets
    SET available_balance_fet = v_after,
        updated_at = timezone('utc', now())
    WHERE venue_id = p_venue_id;
  ELSIF v_bucket = 'staked' THEN
    UPDATE public.venue_fet_wallets
    SET staked_balance_fet = v_after,
        updated_at = timezone('utc', now())
    WHERE venue_id = p_venue_id;
  ELSE
    UPDATE public.venue_fet_wallets
    SET pending_balance_fet = v_after,
        updated_at = timezone('utc', now())
    WHERE venue_id = p_venue_id;
  END IF;

  INSERT INTO public.venue_fet_wallet_transactions (
    venue_id,
    transaction_type,
    direction,
    amount_fet,
    balance_bucket,
    balance_before_fet,
    balance_after_fet,
    reference_type,
    reference_id,
    pool_id,
    game_session_id,
    idempotency_key,
    title,
    status,
    metadata,
    created_by
  )
  VALUES (
    p_venue_id,
    v_type,
    p_direction,
    p_amount_fet,
    v_bucket,
    v_before,
    v_after,
    p_reference_type,
    p_reference_id,
    p_pool_id,
    p_game_session_id,
    p_idempotency_key,
    p_title,
    v_status,
    COALESCE(p_metadata, '{}'::jsonb),
    COALESCE(p_created_by, auth.uid())
  )
  RETURNING * INTO v_tx;

  RETURN jsonb_build_object(
    'status', 'posted',
    'transaction_id', v_tx.id,
    'venue_id', v_tx.venue_id,
    'transaction_type', v_tx.transaction_type,
    'direction', v_tx.direction,
    'amount_fet', v_tx.amount_fet,
    'balance_bucket', v_tx.balance_bucket
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.request_venue_fet_top_up(
  p_venue_id uuid,
  p_amount_fet bigint,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT public.venue_user_has_role(p_venue_id, ARRAY['owner', 'manager']::public.venue_user_role[]) THEN
    RAISE EXCEPTION 'Only venue owners or managers can request FET top-ups';
  END IF;

  RETURN public.venue_wallet_post_transaction(
    p_venue_id => p_venue_id,
    p_transaction_type => 'venue_top_up_request',
    p_direction => 'credit',
    p_amount_fet => p_amount_fet,
    p_balance_bucket => 'pending',
    p_idempotency_key => 'venue_top_up_request:' || p_venue_id::text || ':' || auth.uid()::text || ':' || extract(epoch FROM timezone('utc', now()))::bigint::text,
    p_reference_type => 'venue_top_up_request',
    p_reference_id => p_venue_id::text,
    p_title => 'Venue FET top-up request',
    p_metadata => jsonb_build_object('note', nullif(trim(coalesce(p_note, '')), '')),
    p_status => 'pending',
    p_created_by => auth.uid()
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_venue_fet_wallet(p_venue_id uuid)
RETURNS TABLE(
  venue_id uuid,
  available_balance_fet bigint,
  staked_balance_fet bigint,
  pending_balance_fet bigint,
  updated_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT w.venue_id,
         w.available_balance_fet,
         w.staked_balance_fet,
         w.pending_balance_fet,
         w.updated_at
  FROM public.venue_fet_wallets w
  WHERE w.venue_id = p_venue_id
    AND (public.sports_bar_is_admin() OR public.venue_user_has_role(p_venue_id));
$$;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS fet_earned bigint DEFAULT 0 NOT NULL;

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
  v_result jsonb;
  v_result_amount bigint := 0;
BEGIN
  SELECT *
  INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF v_order.status::text = 'cancelled'
     OR v_order.payment_status::text NOT IN ('paid', 'partially_paid') THEN
    RETURN jsonb_build_object('status', 'skipped', 'reason', 'order_not_paid', 'order_id', p_order_id);
  END IF;

  SELECT *
  INTO v_venue
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

  v_result := public.wallet_post_transaction(
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

  v_result_amount := COALESCE((v_result ->> 'amount_fet')::bigint, v_amount);

  UPDATE public.orders
  SET fet_earned = GREATEST(coalesce(fet_earned, 0), v_result_amount),
      updated_at = timezone('utc', now())
  WHERE id = p_order_id;

  RETURN v_result || jsonb_build_object('order_fet_earned', v_result_amount);
END;
$$;

-- ---------------------------------------------------------------------------
-- Venue-linked pool creation and join rules.
-- ---------------------------------------------------------------------------

ALTER TABLE public.match_pools DROP CONSTRAINT IF EXISTS match_pools_scope_fields;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'match_pools_venue_required'
      AND conrelid = 'public.match_pools'::regclass
  ) THEN
    ALTER TABLE public.match_pools
      ADD CONSTRAINT match_pools_venue_required CHECK (venue_id IS NOT NULL) NOT VALID;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.pool_scheduled_start(p_pool_id uuid)
RETURNS timestamptz
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT COALESCE(m.starts_at, m.match_date)
  FROM public.match_pools p
  JOIN public.matches m ON m.id = p.match_id
  WHERE p.id = p_pool_id;
$$;

CREATE OR REPLACE FUNCTION public.user_has_qualifying_order(
  p_user_id uuid,
  p_venue_id uuid,
  p_start_at timestamptz
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT COALESCE(EXISTS (
    SELECT 1
    FROM public.orders o
    WHERE o.user_id = p_user_id
      AND o.venue_id = p_venue_id
      AND o.status::text <> 'cancelled'
      AND o.payment_status::text = 'paid'
      AND p_start_at IS NOT NULL
      AND o.created_at >= p_start_at - interval '2 hours'
      AND o.created_at <= p_start_at
  ), false);
$$;

CREATE OR REPLACE FUNCTION public.create_pool(
  p_match_id text,
  p_scope text DEFAULT 'venue',
  p_country_id uuid DEFAULT NULL,
  p_venue_id uuid DEFAULT NULL,
  p_title text DEFAULT NULL,
  p_stake_min bigint DEFAULT 1,
  p_stake_max bigint DEFAULT 100000,
  p_creator_reward_per_qualified_member bigint DEFAULT NULL,
  p_rules_json jsonb DEFAULT '{}'::jsonb,
  p_allow_multiple boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_match public.matches%ROWTYPE;
  v_pool public.match_pools%ROWTYPE;
  v_existing public.match_pools%ROWTYPE;
  v_home_team text := 'Home';
  v_away_team text := 'Away';
  v_country_code text;
  v_is_admin boolean := public.sports_bar_is_admin();
  v_is_venue_manager boolean := false;
  v_is_official boolean := v_is_admin;
  v_visibility text := lower(coalesce(nullif(p_rules_json ->> 'visibility', ''), 'shareable'));
  v_endorsement_status text := 'not_required';
  v_auto_endorse boolean := false;
  v_status public.match_pool_status := 'open';
  v_venue_features jsonb := '{}'::jsonb;
  v_entry_fee bigint;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_venue_id IS NULL THEN
    RAISE EXCEPTION 'Every prediction pool must be linked to a venue';
  END IF;

  IF p_scope <> 'venue' THEN
    RAISE EXCEPTION 'Prediction pools are venue-linked. Use global/country filters for browsing only.';
  END IF;

  IF p_stake_min < 1 OR p_stake_max < p_stake_min THEN
    RAISE EXCEPTION 'Invalid stake rules';
  END IF;

  v_entry_fee := p_stake_min;

  IF p_rules_json ? 'is_official' THEN
    v_is_official := lower(p_rules_json ->> 'is_official') IN ('true', '1', 'yes', 'on');
  END IF;

  SELECT *
  INTO v_match
  FROM public.matches
  WHERE id = p_match_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match not found';
  END IF;

  IF COALESCE(v_match.status, CASE v_match.match_status WHEN 'finished' THEN 'final' ELSE v_match.match_status END) NOT IN ('scheduled', 'live') THEN
    RAISE EXCEPTION 'Pools can only be created for scheduled or live curated matches';
  END IF;

  IF COALESCE(v_match.starts_at, v_match.match_date) IS NOT NULL
     AND COALESCE(v_match.starts_at, v_match.match_date) <= timezone('utc', now()) THEN
    RAISE EXCEPTION 'Pool cannot be created after match start';
  END IF;

  SELECT home_team, away_team
  INTO v_home_team, v_away_team
  FROM public.app_matches
  WHERE id = p_match_id;

  SELECT COALESCE(features_json, '{}'::jsonb), country_code, country_id
  INTO v_venue_features, v_country_code, p_country_id
  FROM public.venues
  WHERE id = p_venue_id
    AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active venue not found';
  END IF;

  v_is_venue_manager := public.venue_user_has_role(
    p_venue_id,
    ARRAY['owner', 'manager']::public.venue_user_role[]
  );

  IF v_is_official AND NOT (v_is_admin OR v_is_venue_manager) THEN
    RAISE EXCEPTION 'Only admins or venue managers can create official pools';
  END IF;

  SELECT *
  INTO v_existing
  FROM public.match_pools
  WHERE match_id = p_match_id
    AND venue_id = p_venue_id
    AND scope = 'venue'
    AND status <> 'cancelled'
    AND allow_multiple = false
  ORDER BY is_official DESC, created_at
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'status', 'existing_pool',
      'pool_id', v_existing.id,
      'match_id', v_existing.match_id,
      'scope', v_existing.scope,
      'venue_id', v_existing.venue_id,
      'share_url', v_existing.share_url,
      'endorsement_status', COALESCE(v_existing.metadata ->> 'venue_endorsement_status', 'endorsed')
    );
  END IF;

  v_auto_endorse := v_is_admin
    OR v_is_venue_manager
    OR lower(COALESCE(v_venue_features ->> 'allow_user_pool_auto_endorse', 'false')) IN ('true', '1', 'yes', 'on');

  IF NOT v_auto_endorse AND NOT public.app_config_bool('allow_user_venue_pool_creation', true) THEN
    RAISE EXCEPTION 'Guest-created venue pools are disabled';
  END IF;

  v_status := CASE WHEN v_auto_endorse THEN 'open'::public.match_pool_status ELSE 'draft'::public.match_pool_status END;
  v_endorsement_status := CASE WHEN v_auto_endorse THEN 'endorsed' ELSE 'pending' END;
  v_is_official := v_is_official AND (v_is_admin OR v_is_venue_manager);

  INSERT INTO public.match_pools (
    match_id,
    scope,
    country_code,
    country_id,
    venue_id,
    creator_user_id,
    title,
    status,
    is_official,
    entry_fee_fet,
    stake_min_fet,
    stake_max_fet,
    creator_reward_fet,
    rules_json,
    allow_multiple,
    metadata
  )
  VALUES (
    p_match_id,
    'venue'::public.match_pool_scope,
    v_country_code,
    p_country_id,
    p_venue_id,
    v_user_id,
    COALESCE(NULLIF(trim(p_title), ''), COALESCE(v_home_team, 'Home') || ' vs ' || COALESCE(v_away_team, 'Away')),
    v_status,
    v_is_official,
    v_entry_fee,
    p_stake_min,
    p_stake_max,
    GREATEST(COALESCE(p_creator_reward_per_qualified_member, 0), 0),
    COALESCE(p_rules_json, '{}'::jsonb)
      || jsonb_build_object(
        'visibility', v_visibility,
        'allow_multiple', p_allow_multiple,
        'pool_only_gameplay', true,
        'eligibility_window_minutes', 120
      ),
    p_allow_multiple,
    jsonb_build_object(
      'visibility', v_visibility,
      'venue_endorsement_status', v_endorsement_status,
      'created_via', 'create_pool',
      'pool_only_gameplay', true,
      'eligibility_window_minutes', 120
    )
  )
  RETURNING * INTO v_pool;

  UPDATE public.match_pools
  SET share_url = '/pools/' || v_pool.share_slug
  WHERE id = v_pool.id
  RETURNING * INTO v_pool;

  INSERT INTO public.match_pool_camps (pool_id, code, camp_key, label, result_code, display_order)
  VALUES
    (v_pool.id, 'home', 'home', COALESCE(v_home_team, 'Home'), 'H', 10),
    (v_pool.id, 'draw', 'draw', 'Draw', 'D', 20),
    (v_pool.id, 'away', 'away', COALESCE(v_away_team, 'Away'), 'A', 30);

  PERFORM public.sports_bar_write_audit(
    'create_pool',
    'pool',
    v_pool.id::text,
    NULL,
    to_jsonb(v_pool)
  );

  RETURN jsonb_build_object(
    'status', 'created',
    'pool_id', v_pool.id,
    'match_id', v_pool.match_id,
    'scope', v_pool.scope,
    'venue_id', v_pool.venue_id,
    'share_url', v_pool.share_url,
    'endorsement_status', v_endorsement_status
  );
EXCEPTION
  WHEN unique_violation THEN
    SELECT *
    INTO v_existing
    FROM public.match_pools
    WHERE match_id = p_match_id
      AND venue_id = p_venue_id
      AND scope = 'venue'
      AND status <> 'cancelled'
    ORDER BY is_official DESC, created_at
    LIMIT 1;

    IF FOUND THEN
      RETURN jsonb_build_object(
        'status', 'existing_pool',
        'pool_id', v_existing.id,
        'match_id', v_existing.match_id,
        'scope', v_existing.scope,
        'venue_id', v_existing.venue_id,
        'share_url', v_existing.share_url,
        'endorsement_status', COALESCE(v_existing.metadata ->> 'venue_endorsement_status', 'endorsed')
      );
    END IF;
    RAISE;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_match_pool(
  p_match_id text,
  p_scope public.match_pool_scope DEFAULT 'venue'::public.match_pool_scope,
  p_country_code text DEFAULT NULL,
  p_venue_id uuid DEFAULT NULL,
  p_title text DEFAULT NULL,
  p_entry_fee_fet bigint DEFAULT 1,
  p_stake_min_fet bigint DEFAULT 1,
  p_stake_max_fet bigint DEFAULT 100000,
  p_is_official boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
BEGIN
  IF p_venue_id IS NULL THEN
    RAISE EXCEPTION 'Every prediction pool must be linked to a venue';
  END IF;

  RETURN public.create_pool(
    p_match_id => p_match_id,
    p_scope => 'venue',
    p_country_id => NULL,
    p_venue_id => p_venue_id,
    p_title => p_title,
    p_stake_min => GREATEST(COALESCE(NULLIF(p_entry_fee_fet, 0), p_stake_min_fet), 1),
    p_stake_max => GREATEST(COALESCE(p_stake_max_fet, 1), GREATEST(COALESCE(NULLIF(p_entry_fee_fet, 0), p_stake_min_fet), 1)),
    p_creator_reward_per_qualified_member => NULL,
    p_rules_json => jsonb_build_object(
      'is_official', p_is_official,
      'legacy_country_code', p_country_code,
      'legacy_entry_fee_fet', p_entry_fee_fet
    ),
    p_allow_multiple => false
  );
END;
$$;

DROP FUNCTION IF EXISTS public.create_venue_official_match_pool(uuid, text, text, bigint, bigint, bigint, bigint);

CREATE FUNCTION public.create_venue_official_match_pool(
  p_venue_id uuid,
  p_match_id text,
  p_title text DEFAULT NULL,
  p_entry_fee_fet bigint DEFAULT 1,
  p_stake_min_fet bigint DEFAULT 1,
  p_stake_max_fet bigint DEFAULT 100000,
  p_creator_reward_fet bigint DEFAULT 1,
  p_bar_stake_fet bigint DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_result jsonb;
  v_pool_id uuid;
  v_bar_stake bigint := GREATEST(COALESCE(p_bar_stake_fet, 0), 0);
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT public.venue_user_has_role(
    p_venue_id,
    ARRAY['owner', 'manager']::public.venue_user_role[]
  ) THEN
    RAISE EXCEPTION 'Only venue owners or managers can create official pools';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.curated_matches cm
    WHERE cm.match_id = p_match_id
      AND cm.is_active = true
      AND (cm.starts_at IS NULL OR cm.starts_at <= timezone('utc', now()))
      AND (cm.expires_at IS NULL OR cm.expires_at > timezone('utc', now()))
      AND (cm.venue_id = p_venue_id OR cm.venue_id IS NULL)
  ) THEN
    RAISE EXCEPTION 'This match has not been curated for venue pool creation';
  END IF;

  v_result := public.create_pool(
    p_match_id => p_match_id,
    p_scope => 'venue',
    p_country_id => NULL,
    p_venue_id => p_venue_id,
    p_title => p_title,
    p_stake_min => GREATEST(COALESCE(NULLIF(p_entry_fee_fet, 0), p_stake_min_fet), 1),
    p_stake_max => GREATEST(COALESCE(p_stake_max_fet, 1), GREATEST(COALESCE(NULLIF(p_entry_fee_fet, 0), p_stake_min_fet), 1)),
    p_creator_reward_per_qualified_member => GREATEST(COALESCE(p_creator_reward_fet, 0), 0),
    p_rules_json => jsonb_build_object('is_official', true, 'created_by_venue_dashboard', true),
    p_allow_multiple => false
  );

  v_pool_id := (v_result ->> 'pool_id')::uuid;

  UPDATE public.match_pools
  SET creator_reward_fet = GREATEST(COALESCE(p_creator_reward_fet, 1), 0),
      creator_reward_rules = creator_reward_rules
        || jsonb_build_object(
          'status', 'active',
          'requires_invite', true,
          'requires_paid_entry', true,
          'reward_source', 'match_pool_invites'
        ),
      updated_at = timezone('utc', now())
  WHERE id = v_pool_id;

  IF (v_result ->> 'status') = 'created' AND v_bar_stake > 0 THEN
    PERFORM public.venue_wallet_post_transaction(
      p_venue_id => p_venue_id,
      p_transaction_type => 'venue_pool_stake',
      p_direction => 'debit',
      p_amount_fet => v_bar_stake,
      p_balance_bucket => 'available',
      p_idempotency_key => 'venue_pool_stake_available:' || v_pool_id::text,
      p_reference_type => 'match_pool',
      p_reference_id => v_pool_id::text,
      p_title => 'Venue pool stake',
      p_metadata => jsonb_build_object('match_id', p_match_id),
      p_pool_id => v_pool_id,
      p_created_by => auth.uid()
    );

    PERFORM public.venue_wallet_post_transaction(
      p_venue_id => p_venue_id,
      p_transaction_type => 'venue_pool_stake',
      p_direction => 'credit',
      p_amount_fet => v_bar_stake,
      p_balance_bucket => 'staked',
      p_idempotency_key => 'venue_pool_stake_locked:' || v_pool_id::text,
      p_reference_type => 'match_pool',
      p_reference_id => v_pool_id::text,
      p_title => 'Venue pool stake locked',
      p_metadata => jsonb_build_object('match_id', p_match_id),
      p_pool_id => v_pool_id,
      p_created_by => auth.uid()
    );

    UPDATE public.match_pools
    SET total_staked_fet = total_staked_fet + v_bar_stake,
        metadata = COALESCE(metadata, '{}'::jsonb)
          || jsonb_build_object(
            'bar_stake_fet', v_bar_stake,
            'bar_stake_status', 'locked',
            'bar_stake_venue_id', p_venue_id
          ),
        updated_at = timezone('utc', now())
    WHERE id = v_pool_id;
  END IF;

  RETURN v_result || jsonb_build_object(
    'creator_reward_fet', GREATEST(COALESCE(p_creator_reward_fet, 1), 0),
    'bar_stake_fet', v_bar_stake
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
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_pool public.match_pools%ROWTYPE;
  v_camp public.match_pool_camps%ROWTYPE;
  v_invite public.match_pool_invites%ROWTYPE;
  v_entry public.match_pool_entries%ROWTYPE;
  v_amount bigint;
  v_min_qualified_stake bigint;
  v_reward_amount bigint := 0;
  v_reward_result jsonb := '{}'::jsonb;
  v_reward_tx_id uuid;
  v_invite_valid boolean := false;
  v_reward_eligible boolean := false;
  v_start_at timestamptz;
  v_eligible_now boolean := false;
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

  IF v_pool.venue_id IS NULL THEN
    RAISE EXCEPTION 'Pool is missing linked venue';
  END IF;

  SELECT public.pool_scheduled_start(p_pool_id) INTO v_start_at;

  IF v_pool.status <> 'open' THEN
    RAISE EXCEPTION 'Pool is not open for entries';
  END IF;

  IF v_start_at IS NOT NULL AND timezone('utc', now()) >= v_start_at THEN
    RAISE EXCEPTION 'Pool joining deadline has passed';
  END IF;

  SELECT * INTO v_camp
  FROM public.match_pool_camps
  WHERE id = p_camp_id
    AND pool_id = p_pool_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pool camp not found';
  END IF;

  v_amount := COALESCE(p_amount_fet, NULLIF(v_pool.entry_fee_fet, 0), v_pool.stake_min_fet, 1);
  IF v_amount < v_pool.stake_min_fet OR v_amount > v_pool.stake_max_fet THEN
    RAISE EXCEPTION 'Stake amount is outside pool limits';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.match_pool_entries
    WHERE pool_id = p_pool_id
      AND user_id = v_user_id
      AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'User has already joined this pool';
  END IF;

  v_eligible_now := public.user_has_qualifying_order(v_user_id, v_pool.venue_id, v_start_at);

  v_min_qualified_stake := COALESCE(
    CASE
      WHEN COALESCE(v_pool.creator_reward_rules ->> 'min_qualified_stake', '') ~ '^[0-9]+$'
        THEN (v_pool.creator_reward_rules ->> 'min_qualified_stake')::bigint
      ELSE NULL
    END,
    CASE
      WHEN COALESCE(v_pool.rules_json ->> 'min_qualified_stake', '') ~ '^[0-9]+$'
        THEN (v_pool.rules_json ->> 'min_qualified_stake')::bigint
      ELSE NULL
    END,
    public.app_config_bigint('pool_creator_reward_min_qualified_stake', v_pool.stake_min_fet),
    v_pool.stake_min_fet,
    1
  );

  IF p_invite_code IS NOT NULL THEN
    SELECT * INTO v_invite
    FROM public.match_pool_invites
    WHERE pool_id = p_pool_id
      AND invite_code = p_invite_code
    FOR UPDATE;

    v_invite_valid := FOUND
      AND v_invite.status = 'created'
      AND (v_invite.expires_at IS NULL OR v_invite.expires_at > timezone('utc', now()));
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
    source,
    invited_by_user_id,
    metadata
  )
  VALUES (
    p_pool_id,
    p_camp_id,
    v_user_id,
    v_amount,
    CASE WHEN v_invite_valid THEN 'invite_link' ELSE 'direct' END,
    CASE WHEN v_invite_valid AND v_invite.inviter_user_id IS DISTINCT FROM v_user_id THEN v_invite.inviter_user_id ELSE NULL END,
    jsonb_build_object(
      'invite_code', p_invite_code,
      'invite_valid', v_invite_valid,
      'min_qualified_stake', v_min_qualified_stake,
      'eligibility_status', CASE WHEN v_eligible_now THEN 'order_placed_eligible' ELSE 'joined_order_required' END,
      'eligibility_checked_at', timezone('utc', now()),
      'eligibility_start_at', v_start_at
    )
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
      metadata = COALESCE(metadata, '{}'::jsonb)
        || jsonb_build_object(
          'social_card',
          COALESCE(metadata -> 'social_card', '{}'::jsonb)
            || jsonb_build_object(
              'needs_regeneration', true,
              'stats_updated_at', timezone('utc', now())
            )
        ),
      updated_at = timezone('utc', now())
  WHERE id = p_pool_id;

  v_reward_eligible := v_invite_valid
    AND v_invite.inviter_user_id IS DISTINCT FROM v_user_id
    AND v_invite.inviter_user_id = v_pool.creator_user_id
    AND COALESCE(v_pool.creator_reward_fet, 0) > 0
    AND v_amount >= v_min_qualified_stake
    AND NOT EXISTS (
      SELECT 1
      FROM public.match_pool_invites existing
      WHERE existing.pool_id = p_pool_id
        AND existing.invitee_user_id = v_user_id
        AND existing.status = 'rewarded'
    )
    AND NOT EXISTS (
      SELECT 1
      FROM public.fet_wallet_transactions tx
      WHERE tx.pool_id = p_pool_id
        AND tx.user_id = v_invite.inviter_user_id
        AND tx.transaction_type = 'creator_reward'
        AND tx.metadata ->> 'invitee_user_id' = v_user_id::text
    );

  IF v_reward_eligible THEN
    v_reward_amount := GREATEST(
      COALESCE(v_pool.creator_reward_fet, public.app_config_bigint('pool_creator_reward_fet_default', 1), 1),
      0
    );

    IF v_reward_amount > 0 THEN
      v_reward_result := public.wallet_post_transaction(
        p_user_id => v_invite.inviter_user_id,
        p_transaction_type => 'creator_reward',
        p_direction => 'credit',
        p_amount_fet => v_reward_amount,
        p_balance_bucket => 'available',
        p_idempotency_key => 'creator_reward:' || p_pool_id::text || ':' || v_user_id::text,
        p_reference_type => 'match_pool_invite',
        p_reference_id => v_invite.id::text,
        p_title => 'Pool creator reward',
        p_metadata => jsonb_build_object(
          'invite_id', v_invite.id,
          'entry_id', v_entry.id,
          'invitee_user_id', v_user_id,
          'qualified', true,
          'min_qualified_stake', v_min_qualified_stake,
          'stake_amount_fet', v_amount
        ),
        p_match_id => v_pool.match_id,
        p_pool_id => p_pool_id,
        p_entry_id => v_entry.id,
        p_venue_id => v_pool.venue_id
      );
      v_reward_tx_id := (v_reward_result ->> 'transaction_id')::uuid;
    END IF;

    UPDATE public.match_pool_invites
    SET invitee_user_id = v_user_id,
        joined_entry_id = v_entry.id,
        status = 'rewarded',
        reward_tx_id = v_reward_tx_id,
        reward_amount_fet = v_reward_amount,
        joined_at = timezone('utc', now()),
        rewarded_at = timezone('utc', now()),
        updated_at = timezone('utc', now()),
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object('reward_qualified', true)
    WHERE id = v_invite.id;
  ELSIF v_invite_valid THEN
    UPDATE public.match_pool_invites
    SET invitee_user_id = v_user_id,
        joined_entry_id = v_entry.id,
        status = 'joined',
        reward_amount_fet = 0,
        joined_at = timezone('utc', now()),
        updated_at = timezone('utc', now()),
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
          'reward_qualified', false,
          'stake_amount_fet', v_amount,
          'min_qualified_stake', v_min_qualified_stake,
          'self_invite', v_invite.inviter_user_id = v_user_id
        )
    WHERE id = v_invite.id;
  END IF;

  RETURN jsonb_build_object(
    'status', 'joined',
    'entry_id', v_entry.id,
    'pool_id', p_pool_id,
    'creator_reward_tx_id', v_reward_tx_id,
    'creator_reward_amount_fet', v_reward_amount,
    'eligibility_status', CASE WHEN v_eligible_now THEN 'order_placed_eligible' ELSE 'joined_order_required' END
  );
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
  v_settlement public.match_pool_settlements%ROWTYPE;
  v_settlement_key text := 'settle_pool_eligibility:' || p_pool_id::text;
  v_start_at timestamptz;
  v_result_code text;
  v_result_camp_id uuid;
  v_total_entry_stake bigint := 0;
  v_bar_stake bigint := 0;
  v_total_pot bigint := 0;
  v_winning_entries bigint := 0;
  v_eligible_winning_stake bigint := 0;
  v_eligible_winners bigint := 0;
  v_ineligible_winners bigint := 0;
  v_total_paid bigint := 0;
  v_remaining_payout bigint := 0;
  v_loop_index bigint := 0;
  v_payout bigint := 0;
  v_entry record;
  v_match_state text;
BEGIN
  SELECT * INTO v_pool
  FROM public.match_pools
  WHERE id = p_pool_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pool not found';
  END IF;

  IF v_pool.venue_id IS NULL THEN
    RAISE EXCEPTION 'Pool is missing linked venue';
  END IF;

  IF coalesce(auth.role(), '') <> 'service_role'
     AND NOT public.sports_bar_is_admin()
     AND NOT public.venue_user_has_role(v_pool.venue_id, ARRAY['owner', 'manager', 'staff']::public.venue_user_role[]) THEN
    RAISE EXCEPTION 'Only service role or venue staff can settle pools';
  END IF;

  IF v_pool.status = 'settled' THEN
    SELECT *
    INTO v_settlement
    FROM public.match_pool_settlements
    WHERE pool_id = p_pool_id
    ORDER BY completed_at DESC NULLS LAST, started_at DESC
    LIMIT 1;

    RETURN jsonb_build_object(
      'status', 'already_settled',
      'pool_id', p_pool_id,
      'settlement_id', v_settlement.id
    );
  END IF;

  SELECT * INTO v_match
  FROM public.matches
  WHERE id = v_pool.match_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match not found';
  END IF;

  v_start_at := COALESCE(v_match.starts_at, v_match.match_date);
  v_result_code := COALESCE(
    v_match.result_code,
    public.sports_bar_result_code(COALESCE(v_match.home_score, v_match.home_goals), COALESCE(v_match.away_score, v_match.away_goals))
  );

  v_match_state := CASE
    WHEN COALESCE(v_match.status, v_match.match_status) IN ('cancelled', 'postponed') THEN COALESCE(v_match.status, v_match.match_status)
    WHEN v_result_code IS NOT NULL
       OR COALESCE(v_match.status, '') = 'final'
       OR COALESCE(v_match.match_status, '') = 'finished' THEN 'final'
    ELSE COALESCE(v_match.status, v_match.match_status, 'unknown')
  END;

  INSERT INTO public.match_pool_settlements (
    pool_id,
    status,
    idempotency_key,
    match_id,
    metadata
  )
  VALUES (
    p_pool_id,
    'running',
    v_settlement_key,
    v_pool.match_id,
    jsonb_build_object('eligibility_window_minutes', 120, 'started_by', auth.uid())
  )
  ON CONFLICT (idempotency_key)
  DO UPDATE SET
    status = 'running',
    started_at = timezone('utc', now()),
    error_message = NULL,
    metadata = COALESCE(match_pool_settlements.metadata, '{}'::jsonb)
      || jsonb_build_object('retried_at', timezone('utc', now()))
  RETURNING * INTO v_settlement;

  v_bar_stake := CASE
    WHEN COALESCE(v_pool.metadata ->> 'bar_stake_fet', '') ~ '^[0-9]+$'
      THEN (v_pool.metadata ->> 'bar_stake_fet')::bigint
    ELSE 0
  END;

  SELECT COALESCE(sum(amount_fet), 0)
  INTO v_total_entry_stake
  FROM public.match_pool_entries
  WHERE pool_id = p_pool_id
    AND status = 'active';

  IF v_match_state IN ('cancelled', 'postponed') THEN
    FOR v_entry IN
      SELECT *
      FROM public.match_pool_entries
      WHERE pool_id = p_pool_id
        AND status = 'active'
      ORDER BY created_at, id
    LOOP
      PERFORM public.wallet_post_transaction(
        p_user_id => v_entry.user_id,
        p_transaction_type => 'pool_stake_release',
        p_direction => 'debit',
        p_amount_fet => v_entry.amount_fet,
        p_balance_bucket => 'staked',
        p_idempotency_key => 'pool_cancel_stake_release:' || v_entry.id::text,
        p_reference_type => 'match_pool_entry',
        p_reference_id => v_entry.id::text,
        p_title => 'Pool stake released',
        p_match_id => v_pool.match_id,
        p_pool_id => p_pool_id,
        p_entry_id => v_entry.id,
        p_settlement_id => v_settlement.id,
        p_venue_id => v_pool.venue_id
      );

      PERFORM public.wallet_post_transaction(
        p_user_id => v_entry.user_id,
        p_transaction_type => 'pool_refund',
        p_direction => 'credit',
        p_amount_fet => v_entry.amount_fet,
        p_balance_bucket => 'available',
        p_idempotency_key => 'pool_cancel_refund:' || v_entry.id::text,
        p_reference_type => 'match_pool_entry',
        p_reference_id => v_entry.id::text,
        p_title => 'Pool stake refund',
        p_match_id => v_pool.match_id,
        p_pool_id => p_pool_id,
        p_entry_id => v_entry.id,
        p_settlement_id => v_settlement.id,
        p_venue_id => v_pool.venue_id
      );

      UPDATE public.match_pool_entries
      SET status = 'refunded',
          payout_fet = v_entry.amount_fet,
          metadata = COALESCE(metadata, '{}'::jsonb)
            || jsonb_build_object('settlement_status', 'refunded', 'settlement_id', v_settlement.id),
          updated_at = timezone('utc', now())
      WHERE id = v_entry.id;

      v_total_paid := v_total_paid + v_entry.amount_fet;
    END LOOP;

    IF v_bar_stake > 0 THEN
      PERFORM public.venue_wallet_post_transaction(
        p_venue_id => v_pool.venue_id,
        p_transaction_type => 'venue_pool_stake_release',
        p_direction => 'debit',
        p_amount_fet => v_bar_stake,
        p_balance_bucket => 'staked',
        p_idempotency_key => 'venue_pool_cancel_stake_release:' || p_pool_id::text,
        p_reference_type => 'match_pool',
        p_reference_id => p_pool_id::text,
        p_title => 'Venue pool stake released',
        p_pool_id => p_pool_id,
        p_created_by => auth.uid()
      );

      PERFORM public.venue_wallet_post_transaction(
        p_venue_id => v_pool.venue_id,
        p_transaction_type => 'venue_pool_refund',
        p_direction => 'credit',
        p_amount_fet => v_bar_stake,
        p_balance_bucket => 'available',
        p_idempotency_key => 'venue_pool_cancel_refund:' || p_pool_id::text,
        p_reference_type => 'match_pool',
        p_reference_id => p_pool_id::text,
        p_title => 'Venue pool stake refund',
        p_pool_id => p_pool_id,
        p_created_by => auth.uid()
      );
    END IF;

    UPDATE public.match_pool_settlements
    SET status = 'completed',
        result_camp_id = NULL,
        winners_count = 0,
        losing_stake_fet = 0,
        total_paid_fet = v_total_paid,
        payout_per_winner_fet = 0,
        completed_at = timezone('utc', now()),
        metadata = COALESCE(metadata, '{}'::jsonb)
          || jsonb_build_object('outcome', v_match_state, 'bar_stake_refunded_fet', v_bar_stake)
    WHERE id = v_settlement.id;

    UPDATE public.match_pools
    SET status = 'cancelled',
        settled_at = timezone('utc', now()),
        updated_at = timezone('utc', now()),
        metadata = COALESCE(metadata, '{}'::jsonb)
          || jsonb_build_object('settlement_status', 'refunded', 'settlement_id', v_settlement.id)
    WHERE id = p_pool_id;

    RETURN jsonb_build_object(
      'status', 'refunded',
      'reason', CASE WHEN v_match_state = 'cancelled' THEN 'match_cancelled' ELSE 'match_postponed' END,
      'pool_id', p_pool_id,
      'settlement_id', v_settlement.id,
      'refunded_fet', v_total_paid,
      'bar_stake_refunded_fet', v_bar_stake
    );
  END IF;

  IF v_match_state <> 'final' OR v_result_code IS NULL THEN
    UPDATE public.match_pool_settlements
    SET status = 'failed',
        error_message = 'Match is not final',
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object('match_state', v_match_state)
    WHERE id = v_settlement.id;
    RAISE EXCEPTION 'Match is not final';
  END IF;

  SELECT id INTO v_result_camp_id
  FROM public.match_pool_camps
  WHERE pool_id = p_pool_id
    AND result_code = v_result_code
  LIMIT 1;

  IF v_result_camp_id IS NULL THEN
    UPDATE public.match_pool_settlements
    SET status = 'failed',
        error_message = 'Result camp not found'
    WHERE id = v_settlement.id;
    RAISE EXCEPTION 'Result camp not found';
  END IF;

  v_total_pot := v_total_entry_stake + v_bar_stake;

  SELECT count(*)::bigint
  INTO v_winning_entries
  FROM public.match_pool_entries e
  WHERE e.pool_id = p_pool_id
    AND e.status = 'active'
    AND e.camp_id = v_result_camp_id;

  IF v_winning_entries = 0 THEN
    FOR v_entry IN
      SELECT *
      FROM public.match_pool_entries
      WHERE pool_id = p_pool_id
        AND status = 'active'
      ORDER BY created_at, id
    LOOP
      PERFORM public.wallet_post_transaction(
        p_user_id => v_entry.user_id,
        p_transaction_type => 'pool_stake_release',
        p_direction => 'debit',
        p_amount_fet => v_entry.amount_fet,
        p_balance_bucket => 'staked',
        p_idempotency_key => 'pool_no_winner_stake_release:' || v_entry.id::text,
        p_reference_type => 'match_pool_entry',
        p_reference_id => v_entry.id::text,
        p_title => 'Pool stake released',
        p_match_id => v_pool.match_id,
        p_pool_id => p_pool_id,
        p_entry_id => v_entry.id,
        p_settlement_id => v_settlement.id,
        p_venue_id => v_pool.venue_id
      );

      PERFORM public.wallet_post_transaction(
        p_user_id => v_entry.user_id,
        p_transaction_type => 'pool_refund',
        p_direction => 'credit',
        p_amount_fet => v_entry.amount_fet,
        p_balance_bucket => 'available',
        p_idempotency_key => 'pool_no_winner_refund:' || v_entry.id::text,
        p_reference_type => 'match_pool_entry',
        p_reference_id => v_entry.id::text,
        p_title => 'Pool stake refund',
        p_match_id => v_pool.match_id,
        p_pool_id => p_pool_id,
        p_entry_id => v_entry.id,
        p_settlement_id => v_settlement.id,
        p_venue_id => v_pool.venue_id
      );

      UPDATE public.match_pool_entries
      SET status = 'refunded',
          payout_fet = v_entry.amount_fet,
          metadata = COALESCE(metadata, '{}'::jsonb)
            || jsonb_build_object('settlement_status', 'refunded_no_winning_entries', 'settlement_id', v_settlement.id),
          updated_at = timezone('utc', now())
      WHERE id = v_entry.id;

      v_total_paid := v_total_paid + v_entry.amount_fet;
    END LOOP;

    IF v_bar_stake > 0 THEN
      PERFORM public.venue_wallet_post_transaction(
        p_venue_id => v_pool.venue_id,
        p_transaction_type => 'venue_pool_stake_release',
        p_direction => 'debit',
        p_amount_fet => v_bar_stake,
        p_balance_bucket => 'staked',
        p_idempotency_key => 'venue_pool_no_winner_stake_release:' || p_pool_id::text,
        p_reference_type => 'match_pool',
        p_reference_id => p_pool_id::text,
        p_title => 'Venue pool stake released',
        p_pool_id => p_pool_id,
        p_created_by => auth.uid()
      );

      PERFORM public.venue_wallet_post_transaction(
        p_venue_id => v_pool.venue_id,
        p_transaction_type => 'venue_pool_refund',
        p_direction => 'credit',
        p_amount_fet => v_bar_stake,
        p_balance_bucket => 'available',
        p_idempotency_key => 'venue_pool_no_winner_refund:' || p_pool_id::text,
        p_reference_type => 'match_pool',
        p_reference_id => p_pool_id::text,
        p_title => 'Venue pool stake refund',
        p_pool_id => p_pool_id,
        p_created_by => auth.uid()
      );
    END IF;

    UPDATE public.match_pool_camps
    SET is_winning_camp = (id = v_result_camp_id),
        updated_at = timezone('utc', now())
    WHERE pool_id = p_pool_id;

    UPDATE public.match_pool_settlements
    SET status = 'completed',
        result_camp_id = v_result_camp_id,
        winners_count = 0,
        losing_stake_fet = 0,
        total_paid_fet = v_total_paid,
        payout_per_winner_fet = 0,
        completed_at = timezone('utc', now()),
        metadata = COALESCE(metadata, '{}'::jsonb)
          || jsonb_build_object(
            'outcome', 'no_winning_entries',
            'result_code', v_result_code,
            'bar_stake_refunded_fet', v_bar_stake,
            'total_entry_stake_fet', v_total_entry_stake,
            'eligibility_window_minutes', 120
          )
    WHERE id = v_settlement.id
    RETURNING * INTO v_settlement;

    UPDATE public.match_pools
    SET status = 'settled',
        result_camp_id = v_result_camp_id,
        settled_at = timezone('utc', now()),
        updated_at = timezone('utc', now()),
        metadata = COALESCE(metadata, '{}'::jsonb)
          || jsonb_build_object(
            'settlement_status', 'refunded_no_winning_entries',
            'settlement_id', v_settlement.id
          )
    WHERE id = p_pool_id;

    RETURN jsonb_build_object(
      'status', 'refunded',
      'reason', 'no_winning_entries',
      'pool_id', p_pool_id,
      'settlement_id', v_settlement.id,
      'refunded_fet', v_total_paid,
      'bar_stake_refunded_fet', v_bar_stake
    );
  END IF;

  SELECT COALESCE(sum(e.amount_fet), 0),
         count(*)::bigint
  INTO v_eligible_winning_stake,
       v_eligible_winners
  FROM public.match_pool_entries e
  WHERE e.pool_id = p_pool_id
    AND e.status = 'active'
    AND e.camp_id = v_result_camp_id
    AND public.user_has_qualifying_order(e.user_id, v_pool.venue_id, v_start_at);

  SELECT count(*)::bigint
  INTO v_ineligible_winners
  FROM public.match_pool_entries e
  WHERE e.pool_id = p_pool_id
    AND e.status = 'active'
    AND e.camp_id = v_result_camp_id
    AND NOT public.user_has_qualifying_order(e.user_id, v_pool.venue_id, v_start_at);

  FOR v_entry IN
    SELECT e.*,
           (e.camp_id = v_result_camp_id) AS picked_winner,
           public.user_has_qualifying_order(e.user_id, v_pool.venue_id, v_start_at) AS is_eligible
    FROM public.match_pool_entries e
    WHERE e.pool_id = p_pool_id
      AND e.status = 'active'
    ORDER BY e.created_at, e.id
  LOOP
    PERFORM public.wallet_post_transaction(
      p_user_id => v_entry.user_id,
      p_transaction_type => 'pool_stake_release',
      p_direction => 'debit',
      p_amount_fet => v_entry.amount_fet,
      p_balance_bucket => 'staked',
      p_idempotency_key => 'pool_settle_stake_release:' || v_entry.id::text,
      p_reference_type => 'match_pool_entry',
      p_reference_id => v_entry.id::text,
      p_title => 'Pool stake settled',
      p_match_id => v_pool.match_id,
      p_pool_id => p_pool_id,
      p_entry_id => v_entry.id,
      p_settlement_id => v_settlement.id,
      p_venue_id => v_pool.venue_id
    );

    IF v_entry.picked_winner AND v_entry.is_eligible AND v_eligible_winning_stake > 0 THEN
      v_loop_index := v_loop_index + 1;
      IF v_loop_index = v_eligible_winners THEN
        v_payout := v_remaining_payout;
      ELSE
        v_payout := floor((v_total_pot::numeric * v_entry.amount_fet::numeric) / v_eligible_winning_stake::numeric)::bigint;
      END IF;

      v_remaining_payout := CASE
        WHEN v_remaining_payout = 0 AND v_loop_index = 1 THEN v_total_pot - v_payout
        ELSE v_remaining_payout - v_payout
      END;

      IF v_loop_index = 1 AND v_eligible_winners = 1 THEN
        v_payout := v_total_pot;
        v_remaining_payout := 0;
      END IF;

      IF v_payout > 0 THEN
        PERFORM public.wallet_post_transaction(
          p_user_id => v_entry.user_id,
          p_transaction_type => 'pool_win',
          p_direction => 'credit',
          p_amount_fet => v_payout,
          p_balance_bucket => 'available',
          p_idempotency_key => 'pool_settle_win:' || v_entry.id::text,
          p_reference_type => 'match_pool_settlement',
          p_reference_id => v_settlement.id::text,
          p_title => 'Pool winnings',
          p_metadata => jsonb_build_object(
            'eligibility_status', 'won_settled',
            'qualifying_order_required', true,
            'bar_stake_included_fet', v_bar_stake
          ),
          p_match_id => v_pool.match_id,
          p_pool_id => p_pool_id,
          p_entry_id => v_entry.id,
          p_settlement_id => v_settlement.id,
          p_venue_id => v_pool.venue_id
        );
      END IF;

      UPDATE public.match_pool_entries
      SET status = 'won',
          payout_fet = v_payout,
          metadata = COALESCE(metadata, '{}'::jsonb)
            || jsonb_build_object(
              'settlement_status', 'won_settled',
              'eligibility_status', 'won_settled',
              'settlement_id', v_settlement.id
            ),
          updated_at = timezone('utc', now())
      WHERE id = v_entry.id;

      v_total_paid := v_total_paid + v_payout;
    ELSIF v_entry.picked_winner THEN
      UPDATE public.match_pool_entries
      SET status = 'won',
          payout_fet = 0,
          metadata = COALESCE(metadata, '{}'::jsonb)
            || jsonb_build_object(
              'settlement_status', 'won_ineligible_no_qualifying_order',
              'eligibility_status', 'won_ineligible_no_qualifying_order',
              'settlement_id', v_settlement.id
            ),
          updated_at = timezone('utc', now())
      WHERE id = v_entry.id;
    ELSE
      UPDATE public.match_pool_entries
      SET status = 'lost',
          payout_fet = 0,
          metadata = COALESCE(metadata, '{}'::jsonb)
            || jsonb_build_object(
              'settlement_status', 'lost',
              'eligibility_status', 'lost',
              'settlement_id', v_settlement.id
            ),
          updated_at = timezone('utc', now())
      WHERE id = v_entry.id;
    END IF;
  END LOOP;

  IF v_bar_stake > 0 THEN
    PERFORM public.venue_wallet_post_transaction(
      p_venue_id => v_pool.venue_id,
      p_transaction_type => CASE WHEN v_eligible_winners > 0 THEN 'venue_pool_stake_settled' ELSE 'venue_pool_stake_release' END,
      p_direction => 'debit',
      p_amount_fet => v_bar_stake,
      p_balance_bucket => 'staked',
      p_idempotency_key => 'venue_pool_settle_stake_release:' || p_pool_id::text,
      p_reference_type => 'match_pool',
      p_reference_id => p_pool_id::text,
      p_title => CASE WHEN v_eligible_winners > 0 THEN 'Venue pool stake settled' ELSE 'Venue pool stake released' END,
      p_pool_id => p_pool_id,
      p_created_by => auth.uid()
    );

    IF v_eligible_winners = 0 THEN
      PERFORM public.venue_wallet_post_transaction(
        p_venue_id => v_pool.venue_id,
        p_transaction_type => 'venue_pool_refund',
        p_direction => 'credit',
        p_amount_fet => v_bar_stake,
        p_balance_bucket => 'available',
        p_idempotency_key => 'venue_pool_no_eligible_refund:' || p_pool_id::text,
        p_reference_type => 'match_pool',
        p_reference_id => p_pool_id::text,
        p_title => 'Venue pool stake refund',
        p_pool_id => p_pool_id,
        p_created_by => auth.uid()
      );
    END IF;
  END IF;

  UPDATE public.match_pool_camps
  SET is_winning_camp = (id = v_result_camp_id),
      updated_at = timezone('utc', now())
  WHERE pool_id = p_pool_id;

  UPDATE public.match_pool_settlements
  SET status = 'completed',
      result_camp_id = v_result_camp_id,
      winners_count = v_eligible_winners,
      losing_stake_fet = GREATEST(v_total_pot - v_eligible_winning_stake, 0),
      total_paid_fet = v_total_paid,
      payout_per_winner_fet = CASE WHEN v_eligible_winners > 0 THEN floor(v_total_paid::numeric / v_eligible_winners::numeric)::bigint ELSE 0 END,
      completed_at = timezone('utc', now()),
      metadata = COALESCE(metadata, '{}'::jsonb)
        || jsonb_build_object(
          'result_code', v_result_code,
          'eligible_winners_count', v_eligible_winners,
          'ineligible_winners_count', v_ineligible_winners,
          'total_entry_stake_fet', v_total_entry_stake,
          'bar_stake_fet', v_bar_stake,
          'total_pot_fet', v_total_pot,
          'eligibility_window_minutes', 120
        )
  WHERE id = v_settlement.id
  RETURNING * INTO v_settlement;

  UPDATE public.match_pools
  SET status = 'settled',
      result_camp_id = v_result_camp_id,
      settled_at = timezone('utc', now()),
      updated_at = timezone('utc', now()),
      metadata = COALESCE(metadata, '{}'::jsonb)
        || jsonb_build_object(
          'settlement_status', 'completed',
          'settlement_id', v_settlement.id,
          'eligible_winners_count', v_eligible_winners,
          'ineligible_winners_count', v_ineligible_winners
        )
  WHERE id = p_pool_id;

  RETURN jsonb_build_object(
    'status', 'settled',
    'pool_id', p_pool_id,
    'settlement_id', v_settlement.id,
    'result_code', v_result_code,
    'eligible_winners_count', v_eligible_winners,
    'ineligible_winners_count', v_ineligible_winners,
    'total_paid_fet', v_total_paid,
    'total_pot_fet', v_total_pot
  );
EXCEPTION
  WHEN OTHERS THEN
    UPDATE public.match_pool_settlements
    SET status = 'failed',
        error_message = SQLERRM,
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object('failed_at', timezone('utc', now()))
    WHERE id = v_settlement.id;
    RAISE;
END;
$$;

CREATE OR REPLACE FUNCTION public.venue_settle_match_pool(p_pool_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_venue_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT venue_id
  INTO v_venue_id
  FROM public.match_pools
  WHERE id = p_pool_id;

  IF v_venue_id IS NULL THEN
    RAISE EXCEPTION 'Pool not found or missing linked venue';
  END IF;

  IF NOT public.venue_user_has_role(v_venue_id, ARRAY['owner', 'manager', 'staff']::public.venue_user_role[]) THEN
    RAISE EXCEPTION 'Only venue staff can settle this pool';
  END IF;

  RETURN public.settle_match_pool(p_pool_id);
END;
$$;

-- ---------------------------------------------------------------------------
-- Centralized entertainment game sessions, first-correct validation, and TV.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.game_templates (
  id text PRIMARY KEY,
  name text NOT NULL,
  category text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT game_templates_category_check CHECK (category = ANY (ARRAY['trivia', 'music_bingo', 'song_guess']))
);

INSERT INTO public.game_templates (id, name, category, is_active)
VALUES
  ('bar_trivia', 'Bar Trivia', 'trivia', true),
  ('fan_trivia', 'Fan Trivia', 'trivia', true),
  ('music_bingo', 'Music Bingo', 'music_bingo', true),
  ('song_guess', 'Song Guess', 'song_guess', true)
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    category = EXCLUDED.category,
    is_active = EXCLUDED.is_active,
    updated_at = timezone('utc', now());

CREATE TABLE IF NOT EXISTS public.game_questions (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  template_id text NOT NULL REFERENCES public.game_templates(id) ON DELETE CASCADE,
  category text,
  prompt text NOT NULL,
  options jsonb NOT NULL DEFAULT '[]'::jsonb,
  correct_answer text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  approved_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS game_questions_template_active_idx
  ON public.game_questions (template_id, is_active, approved_at);

CREATE TABLE IF NOT EXISTS public.game_sessions (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  venue_id uuid NOT NULL REFERENCES public.venues(id) ON DELETE CASCADE,
  template_id text NOT NULL REFERENCES public.game_templates(id),
  status text NOT NULL DEFAULT 'scheduled',
  scheduled_start_at timestamptz NOT NULL,
  started_at timestamptz,
  ended_at timestamptz,
  reward_fet bigint NOT NULL DEFAULT 0,
  selected_question_count integer NOT NULL DEFAULT 0,
  current_question_ordinal integer,
  created_by uuid DEFAULT auth.uid(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT game_sessions_status_check CHECK (status = ANY (ARRAY['scheduled', 'lobby', 'live', 'ended', 'settled', 'cancelled'])),
  CONSTRAINT game_sessions_reward_nonnegative CHECK (reward_fet >= 0),
  CONSTRAINT game_sessions_selected_question_count_check CHECK (selected_question_count >= 0)
);

CREATE INDEX IF NOT EXISTS game_sessions_venue_status_start_idx
  ON public.game_sessions (venue_id, status, scheduled_start_at);

CREATE TABLE IF NOT EXISTS public.game_session_questions (
  session_id uuid NOT NULL REFERENCES public.game_sessions(id) ON DELETE CASCADE,
  question_id uuid NOT NULL REFERENCES public.game_questions(id) ON DELETE RESTRICT,
  ordinal integer NOT NULL,
  snapshot jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (session_id, question_id),
  CONSTRAINT game_session_questions_ordinal_positive CHECK (ordinal > 0),
  CONSTRAINT game_session_questions_snapshot_object CHECK (jsonb_typeof(snapshot) = 'object')
);

CREATE UNIQUE INDEX IF NOT EXISTS game_session_questions_session_ordinal_idx
  ON public.game_session_questions (session_id, ordinal);

CREATE TABLE IF NOT EXISTS public.game_teams (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.game_sessions(id) ON DELETE CASCADE,
  venue_id uuid NOT NULL REFERENCES public.venues(id) ON DELETE CASCADE,
  name text NOT NULL,
  created_by_user_id uuid DEFAULT auth.uid(),
  score_fet bigint NOT NULL DEFAULT 0,
  invite_code text NOT NULL DEFAULT lower(substr(replace(extensions.gen_random_uuid()::text, '-', ''), 1, 10)),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT game_teams_name_check CHECK (char_length(trim(name)) BETWEEN 2 AND 80),
  CONSTRAINT game_teams_score_nonnegative CHECK (score_fet >= 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS game_teams_session_name_idx
  ON public.game_teams (session_id, lower(name));

CREATE UNIQUE INDEX IF NOT EXISTS game_teams_invite_code_idx
  ON public.game_teams (invite_code);

CREATE TABLE IF NOT EXISTS public.game_team_members (
  team_id uuid NOT NULL REFERENCES public.game_teams(id) ON DELETE CASCADE,
  session_id uuid NOT NULL REFERENCES public.game_sessions(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'member',
  joined_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (team_id, user_id),
  CONSTRAINT game_team_members_role_check CHECK (role = ANY (ARRAY['captain', 'member']))
);

CREATE UNIQUE INDEX IF NOT EXISTS game_team_members_one_team_per_session_idx
  ON public.game_team_members (session_id, user_id);

CREATE TABLE IF NOT EXISTS public.game_answers (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.game_sessions(id) ON DELETE CASCADE,
  question_id uuid NOT NULL REFERENCES public.game_questions(id) ON DELETE RESTRICT,
  team_id uuid NOT NULL REFERENCES public.game_teams(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  answer_text text NOT NULL,
  is_correct boolean NOT NULL DEFAULT false,
  is_first_correct boolean NOT NULL DEFAULT false,
  awarded_fet bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT game_answers_awarded_nonnegative CHECK (awarded_fet >= 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS game_answers_team_question_idx
  ON public.game_answers (session_id, question_id, team_id);

CREATE UNIQUE INDEX IF NOT EXISTS game_answers_first_correct_once_idx
  ON public.game_answers (session_id, question_id)
  WHERE is_first_correct;

CREATE TABLE IF NOT EXISTS public.music_bingo_cards (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.game_sessions(id) ON DELETE CASCADE,
  team_id uuid NOT NULL REFERENCES public.game_teams(id) ON DELETE CASCADE,
  card jsonb NOT NULL,
  marks jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT music_bingo_cards_card_object CHECK (jsonb_typeof(card) = 'object')
);

CREATE UNIQUE INDEX IF NOT EXISTS music_bingo_cards_team_session_idx
  ON public.music_bingo_cards (session_id, team_id);

CREATE TABLE IF NOT EXISTS public.music_bingo_claims (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.game_sessions(id) ON DELETE CASCADE,
  card_id uuid NOT NULL REFERENCES public.music_bingo_cards(id) ON DELETE CASCADE,
  team_id uuid NOT NULL REFERENCES public.game_teams(id) ON DELETE CASCADE,
  submitted_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'submitted',
  verified_by uuid,
  verified_at timestamptz,
  awarded_fet bigint NOT NULL DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT music_bingo_claims_status_check CHECK (status = ANY (ARRAY['submitted', 'verified', 'rejected'])),
  CONSTRAINT music_bingo_claims_awarded_nonnegative CHECK (awarded_fet >= 0)
);

CREATE TABLE IF NOT EXISTS public.venue_screen_states (
  venue_id uuid PRIMARY KEY REFERENCES public.venues(id) ON DELETE CASCADE,
  mode text NOT NULL DEFAULT 'welcome',
  active_pool_id uuid REFERENCES public.match_pools(id) ON DELETE SET NULL,
  active_game_session_id uuid REFERENCES public.game_sessions(id) ON DELETE SET NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_by uuid,
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT venue_screen_states_mode_check CHECK (mode = ANY (ARRAY['welcome', 'qr', 'pool', 'game_lobby', 'game_question', 'leaderboard', 'winners', 'menu', 'promo']))
);

ALTER TABLE public.game_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_session_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.music_bingo_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.music_bingo_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.venue_screen_states ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS game_templates_select_active ON public.game_templates;
CREATE POLICY game_templates_select_active
ON public.game_templates
FOR SELECT
TO anon, authenticated
USING (is_active = true OR public.sports_bar_is_admin());

DROP POLICY IF EXISTS game_questions_select_staff ON public.game_questions;
CREATE POLICY game_questions_select_staff
ON public.game_questions
FOR SELECT
TO authenticated
USING (
  public.sports_bar_is_admin()
  OR EXISTS (
    SELECT 1
    FROM public.game_sessions s
    WHERE s.template_id = game_questions.template_id
      AND public.venue_user_has_role(s.venue_id)
  )
);

DROP POLICY IF EXISTS game_sessions_select_public ON public.game_sessions;
CREATE POLICY game_sessions_select_public
ON public.game_sessions
FOR SELECT
TO anon, authenticated
USING (status <> 'cancelled' OR public.sports_bar_is_admin() OR public.venue_user_has_role(venue_id));

DROP POLICY IF EXISTS game_teams_select_public ON public.game_teams;
CREATE POLICY game_teams_select_public
ON public.game_teams
FOR SELECT
TO anon, authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.game_sessions s
    WHERE s.id = game_teams.session_id
      AND s.status <> 'cancelled'
  )
  OR public.sports_bar_is_admin()
  OR public.venue_user_has_role(venue_id)
);

DROP POLICY IF EXISTS game_team_members_select_participants ON public.game_team_members;
CREATE POLICY game_team_members_select_participants
ON public.game_team_members
FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
  OR public.sports_bar_is_admin()
  OR EXISTS (
    SELECT 1
    FROM public.game_sessions s
    WHERE s.id = game_team_members.session_id
      AND public.venue_user_has_role(s.venue_id)
  )
);

DROP POLICY IF EXISTS game_answers_select_restricted ON public.game_answers;
CREATE POLICY game_answers_select_restricted
ON public.game_answers
FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
  OR public.sports_bar_is_admin()
  OR EXISTS (
    SELECT 1
    FROM public.game_sessions s
    WHERE s.id = game_answers.session_id
      AND public.venue_user_has_role(s.venue_id)
  )
);

DROP POLICY IF EXISTS music_bingo_cards_select_team ON public.music_bingo_cards;
CREATE POLICY music_bingo_cards_select_team
ON public.music_bingo_cards
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.game_team_members m
    WHERE m.team_id = music_bingo_cards.team_id
      AND m.user_id = auth.uid()
  )
  OR public.sports_bar_is_admin()
  OR EXISTS (
    SELECT 1
    FROM public.game_sessions s
    WHERE s.id = music_bingo_cards.session_id
      AND public.venue_user_has_role(s.venue_id)
  )
);

DROP POLICY IF EXISTS music_bingo_claims_select_team ON public.music_bingo_claims;
CREATE POLICY music_bingo_claims_select_team
ON public.music_bingo_claims
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.game_team_members m
    WHERE m.team_id = music_bingo_claims.team_id
      AND m.user_id = auth.uid()
  )
  OR public.sports_bar_is_admin()
  OR EXISTS (
    SELECT 1
    FROM public.game_sessions s
    WHERE s.id = music_bingo_claims.session_id
      AND public.venue_user_has_role(s.venue_id)
  )
);

DROP POLICY IF EXISTS venue_screen_states_select_safe ON public.venue_screen_states;
CREATE POLICY venue_screen_states_select_safe
ON public.venue_screen_states
FOR SELECT
TO anon, authenticated
USING (true);

CREATE OR REPLACE FUNCTION public.create_game_session(
  p_venue_id uuid,
  p_template_id text,
  p_scheduled_start_at timestamptz,
  p_reward_fet bigint DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_template public.game_templates%ROWTYPE;
  v_session public.game_sessions%ROWTYPE;
  v_required_questions integer := 0;
  v_selected_count integer := 0;
  v_reward bigint := GREATEST(COALESCE(p_reward_fet, 0), 0);
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT public.venue_user_has_role(p_venue_id, ARRAY['owner', 'manager']::public.venue_user_role[]) THEN
    RAISE EXCEPTION 'Only venue owners or managers can create game sessions';
  END IF;

  SELECT * INTO v_template
  FROM public.game_templates
  WHERE id = p_template_id
    AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active game template not found';
  END IF;

  IF v_template.category IN ('trivia', 'song_guess') THEN
    v_required_questions := 20;
  END IF;

  IF v_required_questions > 0 THEN
    SELECT count(*)::integer
    INTO v_selected_count
    FROM public.game_questions q
    WHERE q.template_id = p_template_id
      AND q.is_active = true
      AND q.approved_at IS NOT NULL;

    IF v_selected_count < v_required_questions THEN
      RAISE EXCEPTION 'Not enough active approved questions for this game template';
    END IF;
  END IF;

  INSERT INTO public.game_sessions (
    venue_id,
    template_id,
    status,
    scheduled_start_at,
    reward_fet,
    selected_question_count,
    created_by,
    metadata
  )
  VALUES (
    p_venue_id,
    p_template_id,
    'scheduled',
    p_scheduled_start_at,
    v_reward,
    0,
    auth.uid(),
    jsonb_build_object('template_category', v_template.category, 'eligibility_window_minutes', 120)
  )
  RETURNING * INTO v_session;

  IF v_required_questions > 0 THEN
    WITH selected AS (
      SELECT q.*
      FROM public.game_questions q
      WHERE q.template_id = p_template_id
        AND q.is_active = true
        AND q.approved_at IS NOT NULL
      ORDER BY random()
      LIMIT v_required_questions
    ),
    chosen AS (
      SELECT selected.*,
             (row_number() OVER ())::integer AS ordinal
      FROM selected
    )
    INSERT INTO public.game_session_questions (session_id, question_id, ordinal, snapshot)
    SELECT v_session.id,
           c.id,
           c.ordinal,
           jsonb_build_object(
             'prompt', c.prompt,
             'options', c.options,
             'correct_answer', c.correct_answer,
             'template_id', c.template_id,
             'question_created_at', c.created_at
           )
    FROM chosen c;

    UPDATE public.game_sessions
    SET selected_question_count = v_required_questions,
        updated_at = timezone('utc', now())
    WHERE id = v_session.id
    RETURNING * INTO v_session;
  END IF;

  IF v_reward > 0 THEN
    PERFORM public.venue_wallet_post_transaction(
      p_venue_id => p_venue_id,
      p_transaction_type => 'game_reward_pool',
      p_direction => 'debit',
      p_amount_fet => v_reward,
      p_balance_bucket => 'available',
      p_idempotency_key => 'game_reward_available:' || v_session.id::text,
      p_reference_type => 'game_session',
      p_reference_id => v_session.id::text,
      p_title => 'Game reward pool',
      p_game_session_id => v_session.id,
      p_created_by => auth.uid()
    );

    PERFORM public.venue_wallet_post_transaction(
      p_venue_id => p_venue_id,
      p_transaction_type => 'game_reward_pool',
      p_direction => 'credit',
      p_amount_fet => v_reward,
      p_balance_bucket => 'staked',
      p_idempotency_key => 'game_reward_locked:' || v_session.id::text,
      p_reference_type => 'game_session',
      p_reference_id => v_session.id::text,
      p_title => 'Game reward pool locked',
      p_game_session_id => v_session.id,
      p_created_by => auth.uid()
    );
  END IF;

  RETURN jsonb_build_object(
    'status', 'created',
    'game_session_id', v_session.id,
    'venue_id', v_session.venue_id,
    'template_id', v_session.template_id,
    'selected_question_count', v_session.selected_question_count,
    'reward_fet', v_session.reward_fet
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.create_game_team(
  p_session_id uuid,
  p_name text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_session public.game_sessions%ROWTYPE;
  v_team public.game_teams%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_session
  FROM public.game_sessions
  WHERE id = p_session_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Game session not found';
  END IF;

  IF v_session.status NOT IN ('scheduled', 'lobby') THEN
    RAISE EXCEPTION 'Teams can only be created before the game starts';
  END IF;

  INSERT INTO public.game_teams (session_id, venue_id, name, created_by_user_id)
  VALUES (p_session_id, v_session.venue_id, trim(p_name), auth.uid())
  RETURNING * INTO v_team;

  INSERT INTO public.game_team_members (team_id, session_id, user_id, role)
  VALUES (v_team.id, p_session_id, auth.uid(), 'captain');

  RETURN jsonb_build_object(
    'status', 'created',
    'team_id', v_team.id,
    'session_id', p_session_id,
    'invite_code', v_team.invite_code
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.join_game_team(p_team_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_team public.game_teams%ROWTYPE;
  v_session public.game_sessions%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_team
  FROM public.game_teams
  WHERE id = p_team_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Game team not found';
  END IF;

  SELECT * INTO v_session
  FROM public.game_sessions
  WHERE id = v_team.session_id;

  IF v_session.status NOT IN ('scheduled', 'lobby') THEN
    RAISE EXCEPTION 'Teams can only be joined before the game starts';
  END IF;

  INSERT INTO public.game_team_members (team_id, session_id, user_id, role)
  VALUES (p_team_id, v_team.session_id, auth.uid(), 'member')
  ON CONFLICT (team_id, user_id) DO NOTHING;

  RETURN jsonb_build_object('status', 'joined', 'team_id', p_team_id, 'session_id', v_team.session_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.start_game_session(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_session public.game_sessions%ROWTYPE;
  v_team_count integer;
  v_template_category text;
BEGIN
  SELECT * INTO v_session
  FROM public.game_sessions
  WHERE id = p_session_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Game session not found';
  END IF;

  IF NOT public.venue_user_has_role(v_session.venue_id, ARRAY['owner', 'manager', 'staff']::public.venue_user_role[]) THEN
    RAISE EXCEPTION 'Only venue staff can start games';
  END IF;

  SELECT count(*)::integer INTO v_team_count
  FROM public.game_teams
  WHERE session_id = p_session_id;

  IF v_team_count < 2 THEN
    RAISE EXCEPTION 'At least two teams are required to start a game';
  END IF;

  SELECT category INTO v_template_category
  FROM public.game_templates
  WHERE id = v_session.template_id;

  IF v_template_category IN ('trivia', 'song_guess') AND v_session.selected_question_count <> 20 THEN
    RAISE EXCEPTION 'Trivia and Song Guess sessions require exactly 20 selected questions';
  END IF;

  UPDATE public.game_sessions
  SET status = 'live',
      started_at = COALESCE(started_at, timezone('utc', now())),
      current_question_ordinal = CASE WHEN v_template_category IN ('trivia', 'song_guess') THEN 1 ELSE NULL END,
      updated_at = timezone('utc', now())
  WHERE id = p_session_id
  RETURNING * INTO v_session;

  RETURN jsonb_build_object('status', 'live', 'game_session_id', v_session.id);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_game_session_question(
  p_session_id uuid,
  p_ordinal integer
)
RETURNS TABLE(
  session_id uuid,
  question_id uuid,
  ordinal integer,
  prompt text,
  options jsonb
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT q.session_id,
         q.question_id,
         q.ordinal,
         q.snapshot ->> 'prompt' AS prompt,
         COALESCE(q.snapshot -> 'options', '[]'::jsonb) AS options
  FROM public.game_session_questions q
  JOIN public.game_sessions s ON s.id = q.session_id
  WHERE q.session_id = p_session_id
    AND q.ordinal = p_ordinal
    AND (
      s.status = 'live'
      OR public.sports_bar_is_admin()
      OR public.venue_user_has_role(s.venue_id)
      OR EXISTS (
        SELECT 1
        FROM public.game_team_members m
        WHERE m.session_id = s.id
          AND m.user_id = auth.uid()
      )
    );
$$;

CREATE OR REPLACE FUNCTION public.submit_game_answer(
  p_session_id uuid,
  p_question_id uuid,
  p_team_id uuid,
  p_answer text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_session public.game_sessions%ROWTYPE;
  v_question public.game_session_questions%ROWTYPE;
  v_answer public.game_answers%ROWTYPE;
  v_correct boolean := false;
  v_award bigint := 0;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_session
  FROM public.game_sessions
  WHERE id = p_session_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Game session not found';
  END IF;

  IF v_session.status <> 'live' THEN
    RAISE EXCEPTION 'Game session is not live';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.game_team_members m
    WHERE m.session_id = p_session_id
      AND m.team_id = p_team_id
      AND m.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'User is not a member of this team';
  END IF;

  SELECT * INTO v_question
  FROM public.game_session_questions
  WHERE session_id = p_session_id
    AND question_id = p_question_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Question is not part of this game session';
  END IF;

  v_correct := lower(trim(p_answer)) = lower(trim(v_question.snapshot ->> 'correct_answer'));

  INSERT INTO public.game_answers (
    session_id,
    question_id,
    team_id,
    user_id,
    answer_text,
    is_correct,
    is_first_correct,
    awarded_fet,
    metadata
  )
  VALUES (
    p_session_id,
    p_question_id,
    p_team_id,
    auth.uid(),
    trim(p_answer),
    v_correct,
    false,
    0,
    '{}'::jsonb
  )
  RETURNING * INTO v_answer;

  IF v_correct THEN
    BEGIN
      v_award := GREATEST(
        CASE
          WHEN COALESCE(v_session.metadata ->> 'question_reward_fet', '') ~ '^[0-9]+$'
            THEN (v_session.metadata ->> 'question_reward_fet')::bigint
          ELSE 1
        END,
        1
      );

      UPDATE public.game_answers
      SET is_first_correct = true,
          awarded_fet = v_award,
          metadata = metadata || jsonb_build_object('validation', 'first_correct_team')
      WHERE id = v_answer.id
        AND NOT EXISTS (
          SELECT 1
          FROM public.game_answers existing
          WHERE existing.session_id = p_session_id
            AND existing.question_id = p_question_id
            AND existing.is_first_correct = true
            AND existing.id <> v_answer.id
        )
      RETURNING * INTO v_answer;

      IF v_answer.is_first_correct THEN
        UPDATE public.game_teams
        SET score_fet = score_fet + v_award,
            updated_at = timezone('utc', now())
        WHERE id = p_team_id;
      ELSE
        v_award := 0;
      END IF;
    EXCEPTION
      WHEN unique_violation THEN
        v_award := 0;
        UPDATE public.game_answers
        SET is_first_correct = false,
            awarded_fet = 0,
            metadata = metadata || jsonb_build_object('validation', 'late_correct')
        WHERE id = v_answer.id
        RETURNING * INTO v_answer;
    END;
  END IF;

  RETURN jsonb_build_object(
    'status', 'recorded',
    'answer_id', v_answer.id,
    'is_correct', v_answer.is_correct,
    'is_first_correct', v_answer.is_first_correct,
    'awarded_fet', COALESCE(v_answer.awarded_fet, 0)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_music_bingo_claim(
  p_card_id uuid,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_card public.music_bingo_cards%ROWTYPE;
  v_claim public.music_bingo_claims%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_card
  FROM public.music_bingo_cards
  WHERE id = p_card_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bingo card not found';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.game_team_members m
    WHERE m.team_id = v_card.team_id
      AND m.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'User is not a member of this team';
  END IF;

  INSERT INTO public.music_bingo_claims (
    session_id,
    card_id,
    team_id,
    submitted_by,
    metadata
  )
  VALUES (
    v_card.session_id,
    v_card.id,
    v_card.team_id,
    auth.uid(),
    COALESCE(p_metadata, '{}'::jsonb)
  )
  RETURNING * INTO v_claim;

  RETURN jsonb_build_object('status', 'submitted', 'claim_id', v_claim.id);
END;
$$;

CREATE OR REPLACE FUNCTION public.verify_music_bingo_claim(
  p_claim_id uuid,
  p_approved boolean,
  p_award_fet bigint DEFAULT 1,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_claim public.music_bingo_claims%ROWTYPE;
  v_session public.game_sessions%ROWTYPE;
  v_award bigint := GREATEST(COALESCE(p_award_fet, 0), 0);
BEGIN
  SELECT * INTO v_claim
  FROM public.music_bingo_claims
  WHERE id = p_claim_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bingo claim not found';
  END IF;

  SELECT * INTO v_session
  FROM public.game_sessions
  WHERE id = v_claim.session_id;

  IF NOT public.venue_user_has_role(v_session.venue_id, ARRAY['owner', 'manager', 'staff']::public.venue_user_role[]) THEN
    RAISE EXCEPTION 'Only venue staff can verify bingo claims';
  END IF;

  IF v_claim.status <> 'submitted' THEN
    RAISE EXCEPTION 'Bingo claim has already been reviewed';
  END IF;

  IF p_approved AND v_award > 0 THEN
    UPDATE public.game_teams
    SET score_fet = score_fet + v_award,
        updated_at = timezone('utc', now())
    WHERE id = v_claim.team_id;
  ELSE
    v_award := 0;
  END IF;

  UPDATE public.music_bingo_claims
  SET status = CASE WHEN p_approved THEN 'verified' ELSE 'rejected' END,
      verified_by = auth.uid(),
      verified_at = timezone('utc', now()),
      awarded_fet = v_award,
      metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object('note', nullif(trim(coalesce(p_note, '')), '')),
      updated_at = timezone('utc', now())
  WHERE id = p_claim_id
  RETURNING * INTO v_claim;

  RETURN jsonb_build_object(
    'status', v_claim.status,
    'claim_id', v_claim.id,
    'awarded_fet', v_claim.awarded_fet
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.set_venue_screen_state(
  p_venue_id uuid,
  p_mode text,
  p_active_pool_id uuid DEFAULT NULL,
  p_active_game_session_id uuid DEFAULT NULL,
  p_payload jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_state public.venue_screen_states%ROWTYPE;
BEGIN
  IF NOT public.venue_user_has_role(p_venue_id, ARRAY['owner', 'manager', 'staff']::public.venue_user_role[]) THEN
    RAISE EXCEPTION 'Only venue staff can control the TV screen';
  END IF;

  IF p_active_pool_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.match_pools p WHERE p.id = p_active_pool_id AND p.venue_id = p_venue_id
  ) THEN
    RAISE EXCEPTION 'Pool does not belong to this venue';
  END IF;

  IF p_active_game_session_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.game_sessions s WHERE s.id = p_active_game_session_id AND s.venue_id = p_venue_id
  ) THEN
    RAISE EXCEPTION 'Game session does not belong to this venue';
  END IF;

  INSERT INTO public.venue_screen_states (
    venue_id,
    mode,
    active_pool_id,
    active_game_session_id,
    payload,
    updated_by,
    updated_at
  )
  VALUES (
    p_venue_id,
    p_mode,
    p_active_pool_id,
    p_active_game_session_id,
    COALESCE(p_payload, '{}'::jsonb),
    auth.uid(),
    timezone('utc', now())
  )
  ON CONFLICT (venue_id)
  DO UPDATE SET
    mode = EXCLUDED.mode,
    active_pool_id = EXCLUDED.active_pool_id,
    active_game_session_id = EXCLUDED.active_game_session_id,
    payload = EXCLUDED.payload,
    updated_by = EXCLUDED.updated_by,
    updated_at = timezone('utc', now())
  RETURNING * INTO v_state;

  RETURN jsonb_build_object(
    'status', 'updated',
    'venue_id', v_state.venue_id,
    'mode', v_state.mode,
    'active_pool_id', v_state.active_pool_id,
    'active_game_session_id', v_state.active_game_session_id
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Grants.
-- ---------------------------------------------------------------------------

REVOKE ALL ON FUNCTION public.venue_wallet_post_transaction(uuid, text, text, bigint, text, text, text, text, text, jsonb, uuid, uuid, text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.venue_wallet_post_transaction(uuid, text, text, bigint, text, text, text, text, text, jsonb, uuid, uuid, text, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.request_venue_fet_top_up(uuid, bigint, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_venue_fet_wallet(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pool_scheduled_start(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.user_has_qualifying_order(uuid, uuid, timestamptz) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_pool(text, text, uuid, uuid, text, bigint, bigint, bigint, jsonb, boolean) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_match_pool(text, public.match_pool_scope, text, uuid, text, bigint, bigint, bigint, boolean) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_venue_official_match_pool(uuid, text, text, bigint, bigint, bigint, bigint, bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.join_match_pool(uuid, uuid, bigint, text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.settle_match_pool(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.settle_match_pool(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.venue_settle_match_pool(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_game_session(uuid, text, timestamptz, bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_game_team(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.join_game_team(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.start_game_session(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_game_session_question(uuid, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.submit_game_answer(uuid, uuid, uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.submit_music_bingo_claim(uuid, jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.verify_music_bingo_claim(uuid, boolean, bigint, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.set_venue_screen_state(uuid, text, uuid, uuid, jsonb) TO authenticated, service_role;

GRANT SELECT ON TABLE public.game_templates TO anon, authenticated, service_role;
GRANT SELECT ON TABLE public.game_sessions TO anon, authenticated, service_role;
GRANT SELECT ON TABLE public.game_teams TO anon, authenticated, service_role;
GRANT SELECT ON TABLE public.venue_screen_states TO anon, authenticated, service_role;
