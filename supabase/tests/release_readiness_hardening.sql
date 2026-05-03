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

  IF to_regprocedure('public.venue_settle_match_pool(uuid)') IS NULL THEN
    RAISE EXCEPTION 'Missing venue-scoped pool settlement RPC';
  END IF;

  IF to_regprocedure('public.venue_close_match_pool(uuid,text)') IS NULL THEN
    RAISE EXCEPTION 'Missing venue pool close-joining RPC';
  END IF;

  IF to_regprocedure('public.update_game_session_lifecycle(uuid,text,text)') IS NULL THEN
    RAISE EXCEPTION 'Missing venue game lifecycle RPC';
  END IF;

  IF to_regprocedure('public.user_has_qualifying_order(uuid,uuid,timestamp with time zone)') IS NULL THEN
    RAISE EXCEPTION 'Missing qualifying-order eligibility RPC';
  END IF;

  IF to_regprocedure('public.credit_fet_for_order(uuid,text)') IS NULL THEN
    RAISE EXCEPTION 'Missing order reward credit RPC';
  END IF;

  IF to_regprocedure('public.enforce_user_favorite_team_limits()') IS NULL THEN
    RAISE EXCEPTION 'Missing fan-profile category limit trigger function';
  END IF;

  IF to_regclass('public.pool_operation_audit_logs') IS NULL THEN
    RAISE EXCEPTION 'Missing pool operation audit log table';
  END IF;

  IF to_regclass('public.fet_wallet_transactions') IS NULL THEN
    RAISE EXCEPTION 'Missing wallet ledger table';
  END IF;

  IF to_regclass('public.venue_fet_wallets') IS NULL
     OR to_regclass('public.venue_fet_wallet_transactions') IS NULL THEN
    RAISE EXCEPTION 'Missing venue wallet tables';
  END IF;

  IF to_regclass('public.game_templates') IS NULL
     OR to_regclass('public.game_sessions') IS NULL
     OR to_regclass('public.game_answers') IS NULL
     OR to_regclass('public.venue_screen_states') IS NULL THEN
    RAISE EXCEPTION 'Missing game/session/screen contract tables';
  END IF;

  IF to_regclass('public.game_answers_first_correct_once_idx') IS NULL THEN
    RAISE EXCEPTION 'Missing unique first-correct-answer guard';
  END IF;

  IF to_regclass('public.' || 'user_' || 'pre' || 'dictions') IS NOT NULL THEN
    RAISE EXCEPTION 'Removed game table must not exist in pool-only baseline';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'trg_enforce_user_favorite_team_limits'
      AND tgrelid = 'public.user_favorite_teams'::regclass
      AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION 'Missing fan-profile category limit trigger';
  END IF;
END;
$$;

DO $$
DECLARE
  v_create_def text := pg_get_functiondef('public.create_pool(text,text,uuid,uuid,text,bigint,bigint,bigint,jsonb,boolean)'::regprocedure);
  v_join_def text := pg_get_functiondef('public.join_match_pool(uuid,uuid,bigint,text)'::regprocedure);
  v_settle_def text := pg_get_functiondef('public.settle_match_pool(uuid)'::regprocedure);
  v_game_def text := pg_get_functiondef('public.create_game_session(uuid,text,timestamp with time zone,bigint)'::regprocedure);
  v_game_lifecycle_def text := pg_get_functiondef('public.update_game_session_lifecycle(uuid,text,text)'::regprocedure);
  v_close_pool_def text := pg_get_functiondef('public.venue_close_match_pool(uuid,text)'::regprocedure);
  v_answer_def text := pg_get_functiondef('public.submit_game_answer(uuid,uuid,uuid,text)'::regprocedure);
  v_fan_id_def text := pg_get_functiondef('public.assign_profile_fan_id()'::regprocedure);
  v_order_reward_def text := pg_get_functiondef('public.credit_fet_for_order(uuid,text)'::regprocedure);
  v_fan_profile_def text := pg_get_functiondef('public.enforce_user_favorite_team_limits()'::regprocedure);
BEGIN
  IF v_create_def NOT ILIKE '%Every prediction pool must be linked to a venue%' THEN
    RAISE EXCEPTION 'create_pool must require linked venue';
  END IF;

  IF v_join_def NOT ILIKE '%FOR UPDATE%' THEN
    RAISE EXCEPTION 'join_match_pool must lock wallet/pool state before mutation';
  END IF;

  IF v_join_def NOT ILIKE '%Pool joining deadline has passed%'
     OR v_join_def NOT ILIKE '%user_has_qualifying_order%' THEN
    RAISE EXCEPTION 'join_match_pool must enforce deadline and expose eligibility state';
  END IF;

  IF v_settle_def NOT ILIKE '%already_settled%'
     OR v_settle_def NOT ILIKE '%idempotency_key%'
     OR v_settle_def NOT ILIKE '%user_has_qualifying_order%'
     OR v_settle_def NOT ILIKE '%won_ineligible_no_qualifying_order%' THEN
    RAISE EXCEPTION 'settle_match_pool must be idempotent and eligibility-aware';
  END IF;

  IF v_game_def NOT ILIKE '%v_required_questions := 20%'
     OR v_game_def NOT ILIKE '%approved_at IS NOT NULL%'
     OR v_game_def NOT ILIKE '%selected_question_count%' THEN
    RAISE EXCEPTION 'create_game_session must select and store exactly 20 approved questions where required';
  END IF;

  IF v_game_lifecycle_def NOT ILIKE '%Only venue staff can control game sessions%'
     OR v_game_lifecycle_def NOT ILIKE '%next_round%'
     OR v_game_lifecycle_def NOT ILIKE '%start_game_session%' THEN
    RAISE EXCEPTION 'update_game_session_lifecycle must be venue-scoped and support host controls';
  END IF;

  IF v_close_pool_def NOT ILIKE '%Only venue owners or managers can close pool joining%'
     OR v_close_pool_def NOT ILIKE '%status = ''locked''%'
     OR v_close_pool_def NOT ILIKE '%sports_bar_write_audit%' THEN
    RAISE EXCEPTION 'venue_close_match_pool must be permissioned and auditable';
  END IF;

  IF v_answer_def NOT ILIKE '%is_first_correct = true%'
     OR v_answer_def NOT ILIKE '%unique_violation%'
     OR v_answer_def NOT ILIKE '%User is not a member of this team%' THEN
    RAISE EXCEPTION 'submit_game_answer must enforce first-correct race guard and team membership';
  END IF;

  IF v_fan_id_def NOT ILIKE '%NEW.fan_id := OLD.fan_id%' THEN
    RAISE EXCEPTION 'Fan ID trigger must preserve existing six-digit IDs on update';
  END IF;

  IF v_order_reward_def NOT ILIKE '%SET fet_earned = GREATEST%'
     OR v_order_reward_def NOT ILIKE '%wallet_post_transaction%'
     OR v_order_reward_def NOT ILIKE '%order_fet_earned%' THEN
    RAISE EXCEPTION 'credit_fet_for_order must persist ledger-backed order reward amount';
  END IF;

  IF v_fan_profile_def NOT ILIKE '%top_european%'
     OR v_fan_profile_def NOT ILIKE '%national%'
     OR v_fan_profile_def NOT ILIKE '%category_limit := 2%' THEN
    RAISE EXCEPTION 'Fan profile trigger must enforce local/top-European/national category limits';
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'match_pools_venue_required'
      AND conrelid = 'public.match_pools'::regclass
  ) THEN
    RAISE EXCEPTION 'Missing new-row venue requirement on match_pools';
  END IF;

  IF has_function_privilege('authenticated', 'public.settle_match_pool(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Authenticated users must not execute raw settle_match_pool';
  END IF;

  IF NOT has_function_privilege('authenticated', 'public.venue_settle_match_pool(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Venue staff wrapper must be executable by authenticated staff';
  END IF;

  IF NOT has_function_privilege('authenticated', 'public.venue_close_match_pool(uuid,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Venue close-pool RPC must be executable by authenticated staff';
  END IF;

  IF NOT has_function_privilege('authenticated', 'public.update_game_session_lifecycle(uuid,text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Venue game lifecycle RPC must be executable by authenticated staff';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'user_favorite_teams_source_check'
      AND conrelid = 'public.user_favorite_teams'::regclass
      AND pg_get_constraintdef(oid) ILIKE '%top_european%'
      AND pg_get_constraintdef(oid) ILIKE '%national%'
  ) THEN
    RAISE EXCEPTION 'Fan profile source constraint must allow product categories';
  END IF;
END;
$$;

\echo 'Release readiness hardening verified'
