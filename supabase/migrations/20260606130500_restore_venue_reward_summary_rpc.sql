-- Restore the venue rewards summary RPC used by the venue operations PWA.
-- The linked project had the config/update RPCs but not this read summary.

CREATE OR REPLACE FUNCTION public.get_venue_fet_reward_summary(
  p_venue_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_today timestamptz := date_trunc('day', timezone('utc', now()));
  v_order_earned bigint := 0;
  v_order_spent bigint := 0;
  v_pending_settlements bigint := 0;
BEGIN
  IF NOT (
    coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role'
    OR coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb ->> 'role' = 'service_role'
    OR public.venue_user_has_role(p_venue_id)
    OR public.is_admin_manager(v_actor)
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT
    coalesce(sum(amount_fet) FILTER (
      WHERE direction = 'credit'
        AND coalesce(transaction_type, tx_type) = 'order_earn'
        AND created_at >= v_today
    ), 0)::bigint,
    coalesce(sum(amount_fet) FILTER (
      WHERE direction = 'debit'
        AND coalesce(transaction_type, tx_type) = 'order_spend'
        AND created_at >= v_today
    ), 0)::bigint,
    coalesce(sum(amount_fet) FILTER (
      WHERE balance_bucket = 'pending'
        AND status <> 'voided'
    ), 0)::bigint
  INTO v_order_earned, v_order_spent, v_pending_settlements
  FROM public.fet_wallet_transactions
  WHERE venue_id = p_venue_id;

  RETURN jsonb_build_object(
    'venue_id', p_venue_id,
    'order_earned_today_fet', v_order_earned,
    'order_spent_today_fet', v_order_spent,
    'pending_settlements_fet', v_pending_settlements
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_venue_fet_reward_summary(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_venue_fet_reward_summary(uuid) TO authenticated, service_role;
