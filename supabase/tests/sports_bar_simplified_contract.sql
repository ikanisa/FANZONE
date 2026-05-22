\pset tuples_only on
\pset pager off

\echo 'Verifying simplified sports-bar product contract...'

DO $$
DECLARE
  v_object text;
  v_function text;
BEGIN
  FOREACH v_object IN ARRAY ARRAY[
    'public.countries',
    'public.venues',
    'public.venue_tables',
    'public.menu_categories',
    'public.menu_items',
    'public.orders',
    'public.order_items',
    'public.order_state_events',
    'public.competitions',
    'public.teams',
    'public.matches',
    'public.curated_matches',
    'public.pools',
    'public.pool_camps',
    'public.pool_entries',
    'public.fet_wallets',
    'public.fet_ledger',
    'public.reward_rules',
    'public.settlement_runs',
    'public.audit_logs'
  ] LOOP
    IF to_regclass(v_object) IS NULL THEN
      RAISE EXCEPTION 'Missing required sports-bar object: %', v_object;
    END IF;
  END LOOP;

  FOREACH v_function IN ARRAY ARRAY[
    'public.create_pool(text,text,uuid,uuid,text,bigint,bigint,bigint,jsonb,boolean)',
    'public.join_pool(uuid,uuid,bigint,text,text)',
    'public.stake_fet(uuid,uuid,bigint,text,text)',
    'public.lock_pool_for_match_start(text)',
    'public.update_match_live_score(text,integer,integer,text,text)',
    'public.settle_pool(uuid,text)',
    'public.credit_order_fet(uuid,bigint)',
    'public.spend_fet_on_order(uuid,bigint,text)',
    'public.reconcile_wallet(uuid)',
    'public.generate_pool_share_card(uuid,text,jsonb)',
    'public.admin_curate_match(text,text,uuid,integer,text,jsonb,timestamp with time zone,timestamp with time zone,boolean)',
    'public.venue_endorse_pool(uuid,uuid)',
    'public.manual_mark_order_paid(uuid,text,text)',
    'public.venue_transition_order_status(uuid,text,text,jsonb)',
    'public.refund_pool_for_cancelled_match(uuid)',
    'public.reverse_or_refund_pool_if_match_cancelled(uuid)'
  ] LOOP
    IF to_regprocedure(v_function) IS NULL THEN
      RAISE EXCEPTION 'Missing required sports-bar RPC: %', v_function;
    END IF;
  END LOOP;

  IF to_regclass('public.predictions') IS NOT NULL
    OR to_regclass('public.prediction_entries') IS NOT NULL
    OR to_regclass('public.fantasy_teams') IS NOT NULL THEN
    RAISE EXCEPTION 'Retired prediction/fantasy tables are present in public schema';
  END IF;
END $$;

\echo 'Simplified sports-bar product contract verified.'
