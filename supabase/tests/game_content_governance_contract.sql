\pset tuples_only on
\pset pager off

\echo 'Verifying game content governance contract...'

DO $$
DECLARE
  v_create_run regprocedure := to_regprocedure(
    'public.admin_create_game_content_run(date,text[],integer,integer,text,text,jsonb)'
  );
  v_upsert_pack regprocedure := to_regprocedure(
    'public.admin_upsert_game_content_pack(uuid,text,text,text,jsonb,text,text[],jsonb)'
  );
  v_review_pack regprocedure := to_regprocedure(
    'public.admin_set_game_content_pack_status(uuid,text,text)'
  );
  v_assign regprocedure := to_regprocedure(
    'public.admin_assign_weekly_game_packs(date,text[],integer,text)'
  );
  v_override regprocedure := to_regprocedure(
    'public.admin_override_venue_game_assignment(uuid,text,text)'
  );
BEGIN
  IF to_regclass('public.game_content_generation_runs') IS NULL THEN
    RAISE EXCEPTION 'Missing game_content_generation_runs table';
  END IF;
  IF to_regclass('public.game_content_packs') IS NULL THEN
    RAISE EXCEPTION 'Missing game_content_packs table';
  END IF;
  IF to_regclass('public.venue_game_assignments') IS NULL THEN
    RAISE EXCEPTION 'Missing venue_game_assignments table';
  END IF;
  IF to_regclass('public.admin_game_content_pack_summary') IS NULL THEN
    RAISE EXCEPTION 'Missing admin_game_content_pack_summary view';
  END IF;
  IF to_regclass('public.admin_venue_game_assignment_summary') IS NULL THEN
    RAISE EXCEPTION 'Missing admin_venue_game_assignment_summary view';
  END IF;

  IF v_create_run IS NULL THEN
    RAISE EXCEPTION 'Missing admin_create_game_content_run RPC';
  END IF;
  IF v_upsert_pack IS NULL THEN
    RAISE EXCEPTION 'Missing admin_upsert_game_content_pack RPC';
  END IF;
  IF v_review_pack IS NULL THEN
    RAISE EXCEPTION 'Missing admin_set_game_content_pack_status RPC';
  END IF;
  IF v_assign IS NULL THEN
    RAISE EXCEPTION 'Missing admin_assign_weekly_game_packs RPC';
  END IF;
  IF v_override IS NULL THEN
    RAISE EXCEPTION 'Missing admin_override_venue_game_assignment RPC';
  END IF;

  IF has_table_privilege('anon', 'public.game_content_generation_runs', 'SELECT')
     OR has_table_privilege('anon', 'public.game_content_packs', 'SELECT')
     OR has_table_privilege('anon', 'public.venue_game_assignments', 'SELECT') THEN
    RAISE EXCEPTION 'Anonymous users must not read game governance tables';
  END IF;

  IF has_table_privilege('anon', 'public.game_content_generation_runs', 'INSERT')
     OR has_table_privilege('anon', 'public.game_content_packs', 'INSERT')
     OR has_table_privilege('anon', 'public.venue_game_assignments', 'INSERT') THEN
    RAISE EXCEPTION 'Anonymous users must not write game governance tables';
  END IF;

  IF has_function_privilege('anon', v_create_run, 'EXECUTE')
     OR has_function_privilege('anon', v_upsert_pack, 'EXECUTE')
     OR has_function_privilege('anon', v_review_pack, 'EXECUTE')
     OR has_function_privilege('anon', v_assign, 'EXECUTE')
     OR has_function_privilege('anon', v_override, 'EXECUTE') THEN
    RAISE EXCEPTION 'Anonymous users must not execute game governance RPCs';
  END IF;

  IF NOT has_function_privilege('authenticated', v_create_run, 'EXECUTE')
     OR NOT has_function_privilege('authenticated', v_upsert_pack, 'EXECUTE')
     OR NOT has_function_privilege('authenticated', v_review_pack, 'EXECUTE')
     OR NOT has_function_privilege('authenticated', v_assign, 'EXECUTE')
     OR NOT has_function_privilege('authenticated', v_override, 'EXECUTE') THEN
    RAISE EXCEPTION 'Authenticated admin app role must be able to execute game governance RPCs';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'game_content_generation_runs_markets_check'
  ) THEN
    RAISE EXCEPTION 'Missing Malta/Rwanda generation-run market constraint';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'game_content_packs_questions_count_check'
  ) THEN
    RAISE EXCEPTION 'Missing exact 20-question pack constraint';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'venue_game_assignments_unique_rank'
  ) THEN
    RAISE EXCEPTION 'Missing per-venue weekly assignment rank uniqueness';
  END IF;
END $$;

SELECT 'game_content_governance_contract_passed' AS result;
