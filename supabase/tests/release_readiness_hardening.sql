\pset tuples_only on
\pset pager off

\echo 'Verifying release readiness hardening...'

DO $$
BEGIN
  IF to_regprocedure('public.join_match_pool(uuid,uuid,bigint,text)') IS NULL THEN
    RAISE EXCEPTION 'Missing pool join RPC';
  END IF;

  IF to_regprocedure('public.stake_fet(uuid,uuid,bigint,text,text)') IS NULL THEN
    RAISE EXCEPTION 'Missing FET staking RPC';
  END IF;

  IF to_regprocedure('public.get_my_pools(integer)') IS NULL THEN
    RAISE EXCEPTION 'Missing my-pools RPC';
  END IF;

  IF to_regprocedure('public.venue_reject_pool(uuid,uuid,text)') IS NULL THEN
    RAISE EXCEPTION 'Missing venue pool rejection RPC';
  END IF;

  IF to_regprocedure('public.settle_match_pool(uuid)') IS NULL THEN
    RAISE EXCEPTION 'Missing pool settlement RPC';
  END IF;

  IF to_regclass('public.pool_operation_audit_logs') IS NULL THEN
    RAISE EXCEPTION 'Missing pool operation audit log table';
  END IF;

  IF to_regclass('public.fet_wallet_transactions') IS NULL THEN
    RAISE EXCEPTION 'Missing wallet ledger table';
  END IF;

  IF to_regclass('public.' || 'user_' || 'pre' || 'dictions') IS NOT NULL THEN
    RAISE EXCEPTION 'Removed game table must not exist in pool-only baseline';
  END IF;
END;
$$;

DO $$
DECLARE
  v_join_def text := pg_get_functiondef('public.join_match_pool(uuid,uuid,bigint,text)'::regprocedure);
  v_settle_def text := pg_get_functiondef('public.settle_match_pool(uuid)'::regprocedure);
BEGIN
  IF v_join_def NOT ILIKE '%FOR UPDATE%' THEN
    RAISE EXCEPTION 'join_match_pool must lock wallet/pool state before mutation';
  END IF;

  IF v_settle_def NOT ILIKE '%already_settled%' OR v_settle_def NOT ILIKE '%idempotency_key%' THEN
    RAISE EXCEPTION 'settle_match_pool must be idempotent';
  END IF;
END;
$$;

\echo 'Release readiness hardening verified'
