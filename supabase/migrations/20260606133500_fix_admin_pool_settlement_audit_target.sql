-- Keep admin batch settlement auditable without violating admin_audit_logs.target_id.
CREATE OR REPLACE FUNCTION public.admin_run_pool_settlement(p_limit integer DEFAULT 50)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_user_id uuid := public.require_active_admin_user();
  v_count integer := 0;
  v_failed_count bigint := 0;
  v_pending_count bigint := 0;
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 250));
BEGIN
  v_count := public.settle_finished_match_pools(v_limit);

  SELECT count(*)::bigint
  INTO v_failed_count
  FROM public.match_pool_settlements
  WHERE status::text = 'failed';

  SELECT count(*)::bigint
  INTO v_pending_count
  FROM public.match_pool_settlements
  WHERE status::text = 'pending';

  INSERT INTO public.pool_operation_audit_logs (
    actor_user_id,
    action,
    metadata
  )
  VALUES (
    v_user_id,
    'admin_run_pool_settlement',
    jsonb_build_object(
      'limit', v_limit,
      'settled_pools', v_count,
      'failed_settlements', v_failed_count,
      'pending_settlements', v_pending_count
    )
  );

  PERFORM public.admin_log_action(
    'run_pool_settlement',
    'pools',
    'match_pool_settlement_batch',
    'batch:' || timezone('utc', now())::date::text,
    NULL,
    jsonb_build_object(
      'settled_pools', v_count,
      'failed_settlements', v_failed_count,
      'pending_settlements', v_pending_count
    ),
    jsonb_build_object('limit', v_limit)
  );

  RETURN jsonb_build_object(
    'status', 'completed',
    'settled_pools', v_count,
    'failed_settlements', v_failed_count,
    'pending_settlements', v_pending_count,
    'limit', v_limit
  );
END;
$$;
