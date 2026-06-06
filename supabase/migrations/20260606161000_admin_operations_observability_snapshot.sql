-- Admin-only operations snapshot for release observability dashboards.
-- This is read-only and aggregates launch signals without exposing raw
-- telemetry, order, payment, or ledger rows to client roles.

CREATE OR REPLACE FUNCTION public.admin_operations_observability_snapshot()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_claim_role text := current_setting('request.jwt.claim.role', true);
  v_now timestamptz := timezone('utc', now());
  v_runtime_1h bigint;
  v_runtime_24h bigint;
  v_runtime_top jsonb;
  v_product_1h bigint;
  v_product_24h bigint;
  v_orders_1h bigint;
  v_orders_24h bigint;
  v_orders_open bigint;
  v_orders_disputed bigint;
  v_manual_payment_pending bigint;
  v_manual_payment_confirmed_24h bigint;
  v_fet_credit_24h bigint;
  v_fet_debit_24h bigint;
  v_pool_open bigint;
  v_pool_locked bigint;
  v_pool_settled_24h bigint;
  v_staff_calls_1h bigint;
  v_staff_calls_open bigint;
  v_notifications_24h bigint;
  v_push_tokens_active bigint;
  v_latest_live_sync timestamptz;
  v_live_review_required bigint;
BEGIN
  IF coalesce(v_claim_role, '') <> 'service_role'
     AND (v_actor IS NULL OR NOT public.is_admin_manager(v_actor)) THEN
    RAISE EXCEPTION 'Admin operations observability snapshot requires a platform admin';
  END IF;

  SELECT count(*)
  INTO v_runtime_1h
  FROM public.app_runtime_errors
  WHERE created_at >= v_now - interval '1 hour';

  SELECT count(*)
  INTO v_runtime_24h
  FROM public.app_runtime_errors
  WHERE created_at >= v_now - interval '24 hours';

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object('reason', reason, 'count', error_count)
      ORDER BY error_count DESC, reason
    ),
    '[]'::jsonb
  )
  INTO v_runtime_top
  FROM (
    SELECT reason, count(*) AS error_count
    FROM public.app_runtime_errors
    WHERE created_at >= v_now - interval '24 hours'
    GROUP BY reason
    ORDER BY error_count DESC, reason
    LIMIT 8
  ) top_runtime;

  SELECT count(*)
  INTO v_product_1h
  FROM public.product_events
  WHERE created_at >= v_now - interval '1 hour';

  SELECT count(*)
  INTO v_product_24h
  FROM public.product_events
  WHERE created_at >= v_now - interval '24 hours';

  SELECT count(*)
  INTO v_orders_1h
  FROM public.orders
  WHERE created_at >= v_now - interval '1 hour';

  SELECT count(*)
  INTO v_orders_24h
  FROM public.orders
  WHERE created_at >= v_now - interval '24 hours';

  SELECT count(*)
  INTO v_orders_open
  FROM public.orders
  WHERE status::text IN ('placed', 'received', 'submitted', 'accepted', 'preparing', 'ready', 'served');

  SELECT count(*)
  INTO v_orders_disputed
  FROM public.orders
  WHERE status::text = 'disputed';

  SELECT count(*)
  INTO v_manual_payment_pending
  FROM public.orders
  WHERE payment_method::text IN ('cash', 'momo', 'revolut')
    AND payment_status::text IN ('pending', 'submitted', 'awaiting_confirmation');

  SELECT count(*)
  INTO v_manual_payment_confirmed_24h
  FROM public.payment_events
  WHERE created_at >= v_now - interval '24 hours'
    AND provider::text IN ('cash', 'momo', 'revolut')
    AND status::text IN ('confirmed', 'paid', 'settled', 'completed');

  SELECT coalesce(sum(amount_fet) FILTER (WHERE direction = 'credit'), 0),
         coalesce(sum(amount_fet) FILTER (WHERE direction = 'debit'), 0)
  INTO v_fet_credit_24h, v_fet_debit_24h
  FROM public.fet_wallet_transactions
  WHERE created_at >= v_now - interval '24 hours'
    AND status = 'posted';

  SELECT count(*)
  INTO v_pool_open
  FROM public.match_pools
  WHERE status::text = 'open';

  SELECT count(*)
  INTO v_pool_locked
  FROM public.match_pools
  WHERE status::text = 'locked';

  SELECT count(*)
  INTO v_pool_settled_24h
  FROM public.match_pools
  WHERE status::text = 'settled'
    AND settled_at >= v_now - interval '24 hours';

  SELECT count(*)
  INTO v_staff_calls_1h
  FROM public.bell_requests
  WHERE created_at >= v_now - interval '1 hour';

  SELECT count(*)
  INTO v_staff_calls_open
  FROM public.bell_requests
  WHERE acknowledged_at IS NULL;

  SELECT count(*)
  INTO v_notifications_24h
  FROM public.notification_log
  WHERE sent_at >= v_now - interval '24 hours';

  SELECT count(*)
  INTO v_push_tokens_active
  FROM public.device_tokens
  WHERE is_active IS TRUE;

  SELECT max(last_live_checked_at),
         count(*) FILTER (WHERE last_live_review_required IS TRUE)
  INTO v_latest_live_sync, v_live_review_required
  FROM public.matches;

  RETURN jsonb_build_object(
    'generated_at', v_now,
    'windows', jsonb_build_object(
      'runtime_1h', v_runtime_1h,
      'runtime_24h', v_runtime_24h,
      'product_events_1h', v_product_1h,
      'product_events_24h', v_product_24h,
      'orders_1h', v_orders_1h,
      'orders_24h', v_orders_24h
    ),
    'surfaces', jsonb_build_object(
      'flutter_app', jsonb_build_object(
        'provider', 'supabase_app_runtime_errors',
        'runtime_errors_1h', v_runtime_1h,
        'runtime_errors_24h', v_runtime_24h,
        'top_reasons_24h', v_runtime_top
      ),
      'supabase_database', jsonb_build_object(
        'provider', 'postgres_release_views',
        'runtime_rows_24h', v_runtime_24h,
        'analytics_rows_24h', v_product_24h,
        'latest_live_sync_at', v_latest_live_sync
      ),
      'scheduler', jsonb_build_object(
        'provider', 'supabase_edge_cron',
        'latest_livescore_sync_at', v_latest_live_sync,
        'live_review_required', v_live_review_required
      )
    ),
    'signals', jsonb_build_object(
      'auth', jsonb_build_object(
        'runtime_errors_24h', v_runtime_24h,
        'product_events_24h', v_product_24h
      ),
      'ordering', jsonb_build_object(
        'orders_1h', v_orders_1h,
        'orders_24h', v_orders_24h,
        'open_orders', v_orders_open,
        'disputed_orders', v_orders_disputed
      ),
      'manual_payments', jsonb_build_object(
        'pending_manual_payments', v_manual_payment_pending,
        'confirmed_manual_payments_24h', v_manual_payment_confirmed_24h
      ),
      'fet_ledger', jsonb_build_object(
        'posted_credit_fet_24h', v_fet_credit_24h,
        'posted_debit_fet_24h', v_fet_debit_24h
      ),
      'pools', jsonb_build_object(
        'open_pools', v_pool_open,
        'locked_pools', v_pool_locked,
        'settled_pools_24h', v_pool_settled_24h
      ),
      'rewards', jsonb_build_object(
        'posted_reward_fet_24h', v_fet_credit_24h
      ),
      'admin', jsonb_build_object(
        'runtime_errors_24h', v_runtime_24h
      ),
      'tv_display', jsonb_build_object(
        'latest_live_sync_at', v_latest_live_sync,
        'live_review_required', v_live_review_required
      ),
      'edge_functions', jsonb_build_object(
        'runtime_errors_24h', v_runtime_24h
      ),
      'scheduler', jsonb_build_object(
        'latest_livescore_sync_at', v_latest_live_sync,
        'live_review_required', v_live_review_required
      ),
      'database_health', jsonb_build_object(
        'orders_24h', v_orders_24h,
        'runtime_rows_24h', v_runtime_24h,
        'analytics_rows_24h', v_product_24h
      ),
      'push_notifications', jsonb_build_object(
        'notifications_sent_24h', v_notifications_24h,
        'active_device_tokens', v_push_tokens_active
      ),
      'staff_calls', jsonb_build_object(
        'staff_calls_1h', v_staff_calls_1h,
        'open_staff_calls', v_staff_calls_open
      )
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_operations_observability_snapshot()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_operations_observability_snapshot()
  TO authenticated, service_role;

COMMENT ON FUNCTION public.admin_operations_observability_snapshot()
  IS 'Admin-only aggregate operations snapshot for launch observability dashboards. Raw rows stay protected by RLS/table grants.';
