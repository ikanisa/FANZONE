-- Remote lint hardening for pre-cleanup projects. These wrappers preserve the
-- current sports-bar product behavior while removing stale references to
-- retired helper names.

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS fet_earned bigint DEFAULT 0,
  ADD COLUMN IF NOT EXISTS fet_spent bigint DEFAULT 0;

UPDATE public.orders
SET fet_earned = coalesce(fet_earned, 0),
    fet_spent = coalesce(fet_spent, payment_fet_amount, 0)
WHERE fet_earned IS NULL OR fet_spent IS NULL;

ALTER TABLE public.orders
  ALTER COLUMN fet_earned SET DEFAULT 0,
  ALTER COLUMN fet_earned SET NOT NULL,
  ALTER COLUMN fet_spent SET DEFAULT 0,
  ALTER COLUMN fet_spent SET NOT NULL;

CREATE OR REPLACE FUNCTION public.dinein_is_venue_member(
  p_venue_id uuid,
  p_allowed_roles public.venue_user_role[] DEFAULT ARRAY['owner'::public.venue_user_role, 'manager'::public.venue_user_role, 'staff'::public.venue_user_role]
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT public.venue_user_has_role(p_venue_id, p_allowed_roles);
$$;

DROP FUNCTION IF EXISTS public.lock_pool_for_match_start(text);

CREATE FUNCTION public.lock_pool_for_match_start(p_match_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_count bigint := 0;
BEGIN
  UPDATE public.match_pools
  SET status = 'locked',
      locked_at = coalesce(locked_at, timezone('utc', now())),
      updated_at = timezone('utc', now())
  WHERE match_id = p_match_id
    AND status = 'open';

  GET DIAGNOSTICS v_count = ROW_COUNT;

  RETURN jsonb_build_object('status', 'locked', 'match_id', p_match_id, 'pool_count', coalesce(v_count, 0));
END;
$$;

CREATE OR REPLACE FUNCTION public.settle_pool(
  p_pool_id uuid,
  p_idempotency_key text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  RETURN public.settle_match_pool(p_pool_id)
    || jsonb_build_object('idempotency_key', p_idempotency_key);
END;
$$;

CREATE OR REPLACE FUNCTION public.reverse_or_refund_pool_if_match_cancelled(p_pool_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_pool public.match_pools%ROWTYPE;
  v_entry record;
  v_refunded bigint := 0;
BEGIN
  SELECT *
  INTO v_pool
  FROM public.match_pools
  WHERE id = p_pool_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pool not found';
  END IF;

  IF v_pool.status = 'settled' THEN
    RETURN jsonb_build_object('status', 'skipped', 'reason', 'already_settled', 'pool_id', p_pool_id);
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
      p_transaction_type => 'pool_refund',
      p_direction => 'debit',
      p_amount_fet => v_entry.amount_fet,
      p_balance_bucket => 'staked',
      p_idempotency_key => 'pool_cancel_stake_release:' || v_entry.id::text,
      p_reference_type => 'match_pool_refund',
      p_reference_id => v_entry.id::text,
      p_title => 'Pool stake refunded',
      p_match_id => v_pool.match_id,
      p_pool_id => p_pool_id,
      p_entry_id => v_entry.id,
      p_venue_id => v_pool.venue_id
    );

    PERFORM public.wallet_post_transaction(
      p_user_id => v_entry.user_id,
      p_transaction_type => 'pool_refund',
      p_direction => 'credit',
      p_amount_fet => v_entry.amount_fet,
      p_balance_bucket => 'available',
      p_idempotency_key => 'pool_cancel_refund:' || v_entry.id::text,
      p_reference_type => 'match_pool_refund',
      p_reference_id => v_entry.id::text,
      p_title => 'Pool stake refunded',
      p_match_id => v_pool.match_id,
      p_pool_id => p_pool_id,
      p_entry_id => v_entry.id,
      p_venue_id => v_pool.venue_id
    );

    UPDATE public.match_pool_entries
    SET status = 'refunded',
        payout_fet = v_entry.amount_fet,
        updated_at = timezone('utc', now())
    WHERE id = v_entry.id;

    v_refunded := v_refunded + 1;
  END LOOP;

  UPDATE public.match_pools
  SET status = 'cancelled',
      updated_at = timezone('utc', now()),
      metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
        'cancelled_at', timezone('utc', now()),
        'refund_reason', 'match_cancelled_or_admin_cancelled'
      )
  WHERE id = p_pool_id;

  INSERT INTO public.match_pool_settlements (
    pool_id,
    match_id,
    status,
    idempotency_key,
    completed_at,
    metadata
  )
  VALUES (
    p_pool_id,
    v_pool.match_id,
    'completed',
    'pool-cancel-refund-' || p_pool_id::text,
    timezone('utc', now()),
    jsonb_build_object('refunded_entries', v_refunded)
  )
  ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO UPDATE
  SET completed_at = coalesce(public.match_pool_settlements.completed_at, excluded.completed_at),
      metadata = public.match_pool_settlements.metadata || excluded.metadata;

  RETURN jsonb_build_object('status', 'refunded', 'pool_id', p_pool_id, 'refunded_entries', v_refunded);
END;
$$;

CREATE OR REPLACE FUNCTION public.sports_bar_write_audit(
  p_action text,
  p_entity_type text,
  p_entity_id text DEFAULT NULL::text,
  p_before_json jsonb DEFAULT NULL::jsonb,
  p_after_json jsonb DEFAULT NULL::jsonb,
  p_actor_user_id uuid DEFAULT NULL::uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_id uuid;
  v_actor uuid := coalesce(p_actor_user_id, auth.uid());
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'audit_logs'
      AND column_name = 'actor_user_id'
  ) THEN
    EXECUTE $audit$
      INSERT INTO public.audit_logs (
        actor_user_id,
        actor_role,
        action,
        entity_type,
        entity_id,
        before_json,
        after_json
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING id
    $audit$
    INTO v_id
    USING
      v_actor,
      coalesce(auth.role(), current_user),
      p_action,
      p_entity_type,
      p_entity_id,
      p_before_json,
      p_after_json;
  ELSE
    EXECUTE $audit$
      INSERT INTO public.audit_logs (
        actor_type,
        actor_id,
        action,
        details_json
      )
      VALUES ($1, $2, $3, $4)
      RETURNING id
    $audit$
    INTO v_id
    USING
      CASE WHEN v_actor IS NULL THEN 'system' ELSE 'user' END,
      coalesce(v_actor::text, current_user),
      p_action,
      jsonb_build_object(
        'entity_type', p_entity_type,
        'entity_id', p_entity_id,
        'before_json', coalesce(p_before_json, '{}'::jsonb),
        'after_json', coalesce(p_after_json, '{}'::jsonb),
        'source', 'sports_bar_write_audit'
      );
  END IF;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_risk_signals(p_limit integer DEFAULT 100)
RETURNS TABLE(
  signal_type text,
  severity text,
  entity_type text,
  entity_id text,
  message text,
  created_at timestamp with time zone,
  metadata jsonb
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
BEGIN
  PERFORM public.require_active_admin_user();

  RETURN QUERY
  SELECT signals.signal_type,
         signals.severity,
         signals.entity_type,
         signals.entity_id,
         signals.message,
         signals.created_at,
         signals.metadata
  FROM (
    SELECT
      'suspicious_pool_creation'::text AS signal_type,
      'warning'::text AS severity,
      'pool'::text AS entity_type,
      p.id::text AS entity_id,
      'User-created or pending endorsement pool requires review.'::text AS message,
      p.created_at,
      jsonb_build_object(
        'scope', p.scope::text,
        'venue_id', p.venue_id,
        'creator_user_id', p.creator_user_id,
        'endorsement_status', p.metadata ->> 'endorsement_status'
      ) AS metadata
    FROM public.match_pools p
    WHERE p.is_official = false
       OR p.metadata ->> 'endorsement_status' IN ('pending', 'rejected')

    UNION ALL

    SELECT
      'repeated_self_invite'::text,
      'critical'::text,
      'pool_invite'::text,
      i.id::text,
      'Invite creator and invitee are the same user.'::text,
      i.created_at,
      jsonb_build_object('pool_id', i.pool_id, 'user_id', i.inviter_user_id)
    FROM public.match_pool_invites i
    WHERE i.invitee_user_id IS NOT NULL
      AND i.inviter_user_id = i.invitee_user_id

    UNION ALL

    SELECT
      'abnormal_creator_reward'::text,
      'warning'::text,
      'pool'::text,
      p.id::text,
      'Creator reward is unusually high relative to pool stake limits.'::text,
      p.created_at,
      jsonb_build_object(
        'creator_reward_fet', p.creator_reward_fet,
        'stake_max_fet', p.stake_max_fet,
        'total_members', p.total_members
      )
    FROM public.match_pools p
    WHERE p.creator_reward_fet > greatest(p.stake_max_fet, 1000)

    UNION ALL

    SELECT
      'duplicate_account_signal'::text,
      'info'::text,
      'user_cluster'::text,
      md5(coalesce(nullif(trim(u.phone), ''), nullif(lower(trim(u.email)), '')))::text,
      'Multiple auth accounts share the same phone or email fingerprint.'::text,
      max(u.created_at),
      jsonb_build_object('account_count', count(*))
    FROM auth.users u
    WHERE coalesce(nullif(trim(u.phone), ''), nullif(lower(trim(u.email)), '')) IS NOT NULL
    GROUP BY coalesce(nullif(trim(u.phone), ''), nullif(lower(trim(u.email)), ''))
    HAVING count(*) > 1
  ) signals
  ORDER BY
    CASE signals.severity WHEN 'critical' THEN 0 WHEN 'warning' THEN 1 ELSE 2 END,
    signals.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 100), 500));
END;
$$;

GRANT EXECUTE ON FUNCTION public.dinein_is_venue_member(uuid, public.venue_user_role[]) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.lock_pool_for_match_start(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.settle_pool(uuid, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.reverse_or_refund_pool_if_match_cancelled(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sports_bar_write_audit(text, text, text, jsonb, jsonb, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_risk_signals(integer) TO authenticated, service_role;
